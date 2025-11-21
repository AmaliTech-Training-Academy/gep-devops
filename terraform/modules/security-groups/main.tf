# terraform/modules/security-groups/main.tf
# ==============================================================================
# Security Groups Module - Digital Firewall Rules
# ==============================================================================
# WHAT THIS MODULE DOES:
# Creates digital firewall rules that control who can talk to what in our network.
# Think of it like security guards at different building entrances, each with
# specific instructions about who they should let through.
#
# BUSINESS PURPOSE:
# - Prevents unauthorized access to our applications and data
# - Ensures only legitimate traffic reaches our services
# - Protects customer data and business operations
# - Meets security compliance requirements
#
# SECURITY GROUPS CREATED:
# 1. ALB Security Group: Front door security (internet → load balancer)
# 2. ECS Security Group: Application floor security (load balancer → apps)
# 3. RDS Security Group: Database vault security (apps → databases)
# 4. ElastiCache Security Group: Cache room security (apps → cache)
#
# SECURITY PRINCIPLE:
# "Least Privilege" - Each service gets only the minimum access it needs.
# Like giving each employee only the keys they need for their job.
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
# Local Variables - Configuration Settings
# ==============================================================================
# WHAT THIS SECTION DEFINES:
# Standard settings and port numbers used throughout the security configuration.
# Like a reference sheet that security guards use to know which doors to watch.
#
# MICROSERVICE PORT ASSIGNMENTS:
# Each of our business services runs on a specific port number:
# - Auth Service (8081): Handles user login and registration
# - Event Service (8082): Manages event creation and updates

# - Payment Service (8084): Handles payment transactions
# - Notification Service (8085): Sends emails and notifications
#
# WHY DIFFERENT PORTS MATTER:
# - Allows precise control over which services can be accessed
# - Enables monitoring and logging of specific service traffic
# - Supports load balancing and health checks per service

locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "security-groups"
      Environment = var.environment
    }
  )

  # Port numbers for each microservice (like apartment numbers in our building)
  microservice_ports = {
    auth_service         = 8081  # User authentication and management
    event_service        = 8082  # Event creation and management
    payment_service      = 8088  # Payment processing
    notification_service = 8085  # Email and SMS notifications
  }
}

# ==============================================================================
# ALB Security Group - Front Door Security Guard
# ==============================================================================
# WHAT THIS CREATES:
# Security rules for our Application Load Balancer (ALB) - the front door
# that receives all user requests from the internet.
#
# BUSINESS FUNCTION:
# - First point of contact for all website visitors
# - Distributes user requests across multiple application servers
# - Handles SSL certificates for secure HTTPS connections
# - Protects against basic internet attacks
#
# SECURITY RULES:
# - ALLOWS: HTTPS (port 443) and HTTP (port 80) from anywhere on internet
# - ALLOWS: Outbound traffic to application servers only
# - BLOCKS: All other traffic types and ports
#
# WHY THESE RULES:
# - Users need HTTPS access to use our event planning website
# - HTTP is redirected to HTTPS for security
# - Load balancer only talks to our apps, nothing else

# Create security group for Application Load Balancer (front door)
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security firewall for Application Load Balancer - controls internet access to our website"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# INBOUND RULE: Allow secure website traffic from internet users
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS traffic from internet users to access our event planning website securely"

  from_port   = 443  # HTTPS port (secure web traffic)
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"  # Allow from anywhere on the internet

  tags = {
    Name = "allow-https-from-internet"
  }
}

# INBOUND RULE: Allow regular web traffic (will be redirected to secure HTTPS)
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP traffic from internet (automatically redirected to secure HTTPS for user safety)"

  from_port   = 80   # HTTP port (regular web traffic)
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"  # Allow from anywhere on the internet

  tags = {
    Name = "allow-http-from-internet"
  }
}

# OUTBOUND RULE: Allow load balancer to forward requests to our application servers
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow load balancer to forward user requests to our application servers (ECS containers)"

  ip_protocol                  = "-1"  # All protocols and ports
  referenced_security_group_id = aws_security_group.ecs.id  # Only to our app servers

  tags = {
    Name = "allow-all-to-ecs"
  }
}

# ==============================================================================
# ECS Security Group - Application Floor Security Guard
# ==============================================================================
# WHAT THIS CREATES:
# Security rules for our application servers (ECS containers) where our
# business logic runs (auth, events, payments, notifications).
#
# BUSINESS FUNCTION:
# - Runs our core business services (user management, event planning, etc.)
# - Processes user requests forwarded from the load balancer
# - Communicates with databases and external services
# - Handles business logic and data processing
#
# SECURITY RULES:
# - ALLOWS: Traffic from load balancer on specific service ports
# - ALLOWS: Inter-service communication (services talking to each other)
# - ALLOWS: Outbound to databases (PostgreSQL port 5432)
# - ALLOWS: Outbound to cache (Redis port 6379)
# - ALLOWS: Outbound HTTPS for AWS services and external APIs
# - ALLOWS: Outbound email ports for sending notifications
# - BLOCKS: Direct internet access (inbound)
#
# WHY THESE RULES:
# - Apps need to receive requests from load balancer
# - Services need to share data and coordinate operations
# - Apps need database access to store/retrieve business data
# - Apps need to send emails and access external services
# - No direct internet access prevents attacks

# Create security group for application servers (ECS containers)
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-"
  description = "Security firewall for application servers - controls access to our business services"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow traffic from ALB on application ports
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  for_each = local.microservice_ports

  security_group_id = aws_security_group.ecs.id
  description       = "Allow ${each.key} traffic from ALB"

  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "allow-${each.key}-from-alb"
  }
}

# Allow inter-service communication within ECS
resource "aws_vpc_security_group_ingress_rule" "ecs_internal" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow inter-service communication within ECS"

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "allow-ecs-internal"
  }
}

# Allow outbound to RDS
resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow PostgreSQL to RDS"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id

  tags = {
    Name = "allow-postgres-to-rds"
  }
}

# Allow outbound to ElastiCache
resource "aws_vpc_security_group_egress_rule" "ecs_to_elasticache" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow Redis to ElastiCache"

  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.elasticache.id

  tags = {
    Name = "allow-redis-to-elasticache"
  }
}

# Allow outbound HTTPS for AWS APIs and external services
resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow HTTPS for AWS APIs and external services"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-https-outbound"
  }
}

# Allow outbound SMTP SSL for email sending (Gmail port 465)
resource "aws_vpc_security_group_egress_rule" "ecs_smtp_ssl" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow SMTP SSL for email sending via Gmail (port 465)"

  from_port   = 465
  to_port     = 465
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-smtp-ssl-outbound"
  }
}

# Allow outbound SMTP STARTTLS for email sending (Gmail port 587)
resource "aws_vpc_security_group_egress_rule" "ecs_smtp_starttls" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow SMTP STARTTLS for email sending via Gmail (port 587)"

  from_port   = 587
  to_port     = 587
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "allow-smtp-starttls-outbound"
  }
}

# ==============================================================================
# RDS Security Group
# ==============================================================================

# Security group for RDS instances
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Security group for RDS PostgreSQL databases"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow PostgreSQL from ECS only
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow PostgreSQL from ECS tasks"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "allow-postgres-from-ecs"
  }
}

# No outbound rules (databases don't initiate connections)



# ==============================================================================
# ElastiCache Security Group
# ==============================================================================

# Security group for ElastiCache cluster
resource "aws_security_group" "elasticache" {
  name_prefix = "${var.project_name}-${var.environment}-elasticache-"
  description = "Security group for ElastiCache Redis cluster"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-elasticache-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow Redis from ECS only
resource "aws_vpc_security_group_ingress_rule" "elasticache_from_ecs" {
  security_group_id = aws_security_group.elasticache.id
  description       = "Allow Redis from ECS tasks"

  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name = "allow-redis-from-ecs"
  }
}



