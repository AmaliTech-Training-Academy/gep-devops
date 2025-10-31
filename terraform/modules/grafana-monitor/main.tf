# ==============================================================================
# Grafana Monitoring Module
# ==============================================================================
# This module provisions Grafana on EC2 for monitoring dashboards accessible
# to non-engineering teams. Grafana integrates with existing ALB using
# path-based routing (/monitoring/*).
#
# Components:
# - EC2 instance (t3.micro) in private subnet
# - IAM role with CloudWatch/RDS read permissions
# - Security group for Grafana access
# - ALB target group and listener rule
# - User data script for Grafana installation
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================================================
# Data Sources
# ==============================================================================

# Get the latest free-tier eligible Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "grafana-monitor"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# IAM Role for Grafana EC2 Instance
# ==============================================================================

resource "aws_iam_role" "grafana" {
  name_prefix = "${var.project_name}-${var.environment}-grafana-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-role"
    }
  )
}

# CloudWatch read permissions
resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name_prefix = "cloudwatch-access-"
  role        = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:ListTasks",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# SSM permissions for Session Manager access
resource "aws_iam_role_policy_attachment" "grafana_ssm" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "grafana" {
  name_prefix = "${var.project_name}-${var.environment}-grafana-"
  role        = aws_iam_role.grafana.name

  tags = local.common_tags
}

# ==============================================================================
# Security Group for Grafana
# ==============================================================================

resource "aws_security_group" "grafana" {
  name_prefix = "${var.project_name}-${var.environment}-grafana-"
  description = "Security group for Grafana monitoring instance"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow Grafana port from ALB
resource "aws_vpc_security_group_ingress_rule" "grafana_from_alb" {
  security_group_id = aws_security_group.grafana.id
  description       = "Allow Grafana traffic from ALB"

  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.alb_security_group_id

  tags = {
    Name = "allow-grafana-from-alb"
  }
}

# Allow HTTPS outbound for CloudWatch API and SSM
resource "aws_vpc_security_group_egress_rule" "grafana_https" {
  security_group_id = aws_security_group.grafana.id
  description       = "Allow HTTPS for CloudWatch API and SSM"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-https-outbound"
  }
}

# Allow PostgreSQL to RDS
resource "aws_vpc_security_group_egress_rule" "grafana_to_rds" {
  security_group_id = aws_security_group.grafana.id
  description       = "Allow PostgreSQL to RDS"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.rds_security_group_id

  tags = {
    Name = "allow-postgres-to-rds"
  }
}

# ==============================================================================
# Update RDS Security Group to Allow Grafana
# ==============================================================================

resource "aws_vpc_security_group_ingress_rule" "rds_from_grafana" {
  security_group_id = var.rds_security_group_id
  description       = "Allow PostgreSQL from Grafana"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.grafana.id

  tags = {
    Name = "allow-postgres-from-grafana"
  }
}

# ==============================================================================
# Update ALB Security Group to Allow Traffic to Grafana
# ==============================================================================

resource "aws_vpc_security_group_egress_rule" "alb_to_grafana" {
  security_group_id = var.alb_security_group_id
  description       = "Allow traffic to Grafana on port 3000"

  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.grafana.id

  tags = {
    Name = "allow-alb-to-grafana"
  }
}

# ==============================================================================
# User Data Script for Grafana Installation
# ==============================================================================

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    yum update -y
    
    # Install and start SSM Agent
    sudo yum install -y amazon-ssm-agent
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent

    # Install Grafana
    sudo yum install -y https://dl.grafana.com/grafana/release/12.2.1/grafana_12.2.1_18655849634_linux_amd64.rpm
  


    # Configure Grafana
    cat > /etc/grafana/grafana.ini <<'CONFIG'
    [server]
    protocol = http
    http_port = 3000
    domain = ${var.alb_domain_name}
    root_url = https://${var.alb_domain_name}/monitoring/
    serve_from_sub_path = true
    
    [security]
    admin_user = admin
    admin_password = ${var.grafana_admin_password}
    disable_gravatar = true
    cookie_secure = true
    cookie_samesite = strict
    
    [auth]
    disable_login_form = false
    disable_signout_menu = false
    
    [auth.anonymous]
    enabled = false
    
    [users]
    allow_sign_up = false
    allow_org_create = false
    auto_assign_org = true
    auto_assign_org_role = Viewer
    
    [log]
    mode = console file
    level = info
    CONFIG
    
    # Start and enable Grafana
    sudo systemctl daemon-reload
    sudo systemctl enable grafana-server.service
    sudo systemctl start grafana-server.service
    
    # Wait for Grafana to start
    sleep 10
    
    echo "Grafana installation completed"

    # Install postgres15 client for RDS PostgreSQL access
    sudo yum install postgresql15 -y
  EOF
}

# ==============================================================================
# EC2 Instance for Grafana
# ==============================================================================

resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.grafana.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana.name

  user_data = base64encode(local.user_data)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-grafana-${var.environment}"
    }
  )
}

# ==============================================================================
# ALB Target Group for Grafana
# ==============================================================================

resource "aws_lb_target_group" "grafana" {
  name_prefix = "graf-"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/api/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-tg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Register Grafana instance to target group
resource "aws_lb_target_group_attachment" "grafana" {
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = aws_instance.grafana.id
  port             = 3000
}

# ==============================================================================
# ALB Listener Rule for Grafana
# ==============================================================================

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = var.alb_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern {
      values = ["/monitoring/*"]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-rule"
    }
  )
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "grafana_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-grafana-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Grafana EC2 CPU utilization is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.grafana.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "grafana_unhealthy" {
  alarm_name          = "${var.project_name}-${var.environment}-grafana-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "Grafana target is unhealthy"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = aws_lb_target_group.grafana.arn_suffix
  }

  tags = local.common_tags
}
