# ==============================================================================
# ALB Module - Application Load Balancer with Path-Based Routing
# ==============================================================================
# This module creates an Application Load Balancer that routes traffic directly
# to backend microservices based on URL paths (no API Gateway microservice).
#
# Routing Rules:
# - /api/auth/*         → Auth Service (8081)
# - /api/events/*       → Event Service (8082)
# - /api/bookings/*     → Booking Service (8083)
# - /api/payments/*     → Payment Service (8084)
# - /api/notifications/* → Notification Service (8085)
#
# Features:
# - SSL/TLS termination
# - Health checks with auto-scaling triggers
# - Connection draining
# - Access logging to S3
# - CloudWatch metrics and alarms
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
# Local Variables
# ==============================================================================

locals {
  # Microservices configuration
  services = {
    auth = {
      name              = "auth-service"
      port              = 8081
      path_pattern      = "/api/auth/*"
      health_check_path = "/actuator/health"
      priority          = 100
    }
    event = {
      name              = "event-service"
      port              = 8082
      path_pattern      = "/api/events/*"
      health_check_path = "/actuator/health"
      priority          = 200
    }
    booking = {
      name              = "booking-service"
      port              = 8083
      path_pattern      = "/api/bookings/*"
      health_check_path = "/actuator/health"
      priority          = 300
    }
    payment = {
      name              = "payment-service"
      port              = 8084
      path_pattern      = "/api/payments/*"
      health_check_path = "/actuator/health"
      priority          = 400
    }
    notification = {
      name              = "notification-service"
      port              = 8085
      path_pattern      = "/api/notifications/*"
      health_check_path = "/actuator/health"
      priority          = 500
    }
  }

  common_tags = merge(
    var.tags,
    {
      Module      = "alb"
      Environment = var.environment
    }
  )
  lb_prefix = substr(replace(var.project_name, "-", ""), 0, 5)
}

# ==============================================================================
# Application Load Balancer
# ==============================================================================

resource "aws_lb" "main" {
  name_prefix        = "${local.lb_prefix}-"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # Enable deletion protection in production
  enable_deletion_protection = var.enable_deletion_protection

  # Enable cross-zone load balancing
  enable_cross_zone_load_balancing = true

  # Enable HTTP/2
  enable_http2 = true

  # Drop invalid headers
  drop_invalid_header_fields = true

  # Access logs to S3
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# ==============================================================================
# Target Groups
# ==============================================================================

# Create target group for each microservice
resource "aws_lb_target_group" "services" {
  for_each = local.services

  name_prefix = substr(each.value.name, 0, 6)
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  # Health check configuration
  health_check {
    enabled             = true
    path                = each.value.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    matcher             = "200-299"
  }

  # Deregistration delay (connection draining)
  deregistration_delay = var.deregistration_delay

  # Stickiness (disabled for stateless services)
  stickiness {
    type            = "lb_cookie"
    enabled         = false
    cookie_duration = 86400
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-tg"
      Service = each.value.name
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# HTTPS Listener (Port 443)
# ==============================================================================

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Default action: Return 404 for unknown paths
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        error   = "Not Found"
        message = "The requested resource was not found"
      })
      status_code = "404"
    }
  }

  tags = local.common_tags
}

# ==============================================================================
# HTTPS Listener Rules (Path-Based Routing)
# ==============================================================================

# Create listener rule for each microservice
resource "aws_lb_listener_rule" "service_routing" {
  for_each = local.services

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-rule"
      Service = each.value.name
    }
  )
}

# ==============================================================================
# HTTP Listener (Port 80) - Redirect to HTTPS
# ==============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.common_tags
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

# Target response time alarm
resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.response_time_alarm_threshold
  alarm_description   = "ALB target response time is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

# 5XX error rate alarm
resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_5xx_alarm_threshold
  alarm_description   = "ALB 5XX error rate is too high"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

# Unhealthy target count alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  for_each = local.services

  alarm_name          = "${var.project_name}-${var.environment}-${each.value.name}-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "Unhealthy targets detected for ${each.value.name}"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.services[each.key].arn_suffix
  }

  tags = local.common_tags
}
