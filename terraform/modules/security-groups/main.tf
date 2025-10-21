# terraform/modules/security-groups/main.tf

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  common_tags = merge(var.tags, {
    Module = "SecurityGroups"
  })
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-gep-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-gep-alb-sg"
    Component = "LoadBalancer"
  })
}

# ALB Ingress Rules
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"
  
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "allow-https-inbound"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet (redirect to HTTPS)"
  
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "allow-http-inbound"
  }
}

# ALB Egress Rules
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow traffic to ECS tasks"
  
  from_port                    = 8080
  to_port                      = 8085
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-to-ecs"
  }
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name        = "${var.environment}-gep-ecs-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-gep-ecs-sg"
    Component = "ECS"
  })
}

# ECS Ingress Rules
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow traffic from ALB"
  
  from_port                    = 8080
  to_port                      = 8085
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
  
  tags = {
    Name = "allow-from-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_inter_service" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow inter-service communication"
  
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-inter-service"
  }
}

# ECS Egress Rules
resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow traffic to RDS PostgreSQL"
  
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
  
  tags = {
    Name = "allow-to-rds"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_redis" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow traffic to ElastiCache Redis"
  
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.redis.id
  
  tags = {
    Name = "allow-to-redis"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_docdb" {
  count             = var.enable_docdb ? 1 : 0
  security_group_id = aws_security_group.ecs.id
  description       = "Allow traffic to DocumentDB"
  
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.docdb[0].id
  
  tags = {
    Name = "allow-to-docdb"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_internet" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow HTTPS to internet (AWS APIs, external services)"
  
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Name = "allow-https-outbound"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.environment}-gep-rds-sg"
  description = "Security group for RDS PostgreSQL instances"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-gep-rds-sg"
    Component = "RDS"
  })
}

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

# ElastiCache Redis Security Group
resource "aws_security_group" "redis" {
  name        = "${var.environment}-gep-redis-sg"
  description = "Security group for ElastiCache Redis cluster"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-gep-redis-sg"
    Component = "ElastiCache"
  })
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs" {
  security_group_id = aws_security_group.redis.id
  description       = "Allow Redis from ECS tasks"
  
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-redis-from-ecs"
  }
}

# DocumentDB Security Group
resource "aws_security_group" "docdb" {
  count       = var.enable_docdb ? 1 : 0
  name        = "${var.environment}-gep-docdb-sg"
  description = "Security group for DocumentDB cluster"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-gep-docdb-sg"
    Component = "DocumentDB"
  })
}

resource "aws_vpc_security_group_ingress_rule" "docdb_from_ecs" {
  count             = var.enable_docdb ? 1 : 0
  security_group_id = aws_security_group.docdb[0].id
  description       = "Allow MongoDB from ECS tasks"
  
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
  
  tags = {
    Name = "allow-mongodb-from-ecs"
  }
}