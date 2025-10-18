# terraform/modules/security-groups/main.tf
# ==============================================================================
# Security Groups Module
# ==============================================================================
# This module creates security groups for all infrastructure components following
# the principle of least privilege. Each resource type has its own security group
# with minimal required access.
#
# Security Groups:
# - ALB Security Group: HTTPS/HTTP from internet
# - ECS Security Group: Application ports from ALB + inter-service communication
# - RDS Security Group: PostgreSQL from ECS only
# - DocumentDB Security Group: MongoDB from ECS only
# - ElastiCache Security Group: Redis from ECS only
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
  common_tags = merge(
    var.tags,
    {
      Module      = "security-groups"
      Environment = var.environment
    }
  )
  
  # Microservice ports
  microservice_ports = {
    auth_service         = 8081
    event_service        = 8082
    booking_service      = 8083
    payment_service      = 8084
    notification_service = 8085
  }
}

# ==============================================================================
# ALB Security Group
# ==============================================================================

# Security group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security group for Application Load Balancer"
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

# Allow HTTPS from internet
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"
  
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "allow-https-from-internet"
  }
}

# Allow HTTP from internet (redirect to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet (redirect to HTTPS)"
  
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "allow-http-from-internet"
  }
}

# Allow all outbound to ECS
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow all traffic to ECS"
  
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-all-to-ecs"
  }
}

# ==============================================================================
# ECS Security Group
# ==============================================================================

# Security group for ECS tasks
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-"
  description = "Security group for ECS Fargate tasks"
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
  
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow ${each.key} traffic from ALB"
  
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
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow inter-service communication within ECS"
  
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-ecs-internal"
  }
}

# Allow outbound to RDS
resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow PostgreSQL to RDS"
  
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
  
  tags = {
    Name = "allow-postgres-to-rds"
  }
}

# Allow outbound to DocumentDB
resource "aws_vpc_security_group_egress_rule" "ecs_to_documentdb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow MongoDB to DocumentDB"
  
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.documentdb.id
  
  tags = {
    Name = "allow-mongodb-to-documentdb"
  }
}

# Allow outbound to ElastiCache
resource "aws_vpc_security_group_egress_rule" "ecs_to_elasticache" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow Redis to ElastiCache"
  
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
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow PostgreSQL from ECS tasks"
  
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
# DocumentDB Security Group
# ==============================================================================

# Security group for DocumentDB cluster
resource "aws_security_group" "documentdb" {
  name_prefix = "${var.project_name}-${var.environment}-documentdb-"
  description = "Security group for DocumentDB cluster"
  vpc_id      = var.vpc_id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-documentdb-sg"
    }
  )
  
  lifecycle {
    create_before_destroy = true
  }
}

# Allow MongoDB from ECS only
resource "aws_vpc_security_group_ingress_rule" "documentdb_from_ecs" {
  security_group_id            = aws_security_group.documentdb.id
  description                  = "Allow MongoDB from ECS tasks"
  
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-mongodb-from-ecs"
  }
}

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
  security_group_id            = aws_security_group.elasticache.id
  description                  = "Allow Redis from ECS tasks"
  
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-redis-from-ecs"
  }
}



