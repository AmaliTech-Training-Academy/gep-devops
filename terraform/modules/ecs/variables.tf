# ==============================================================================
# ECS Module Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1, eu-west-1)"
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

# ==============================================================================
# IAM Configuration
# ==============================================================================

variable "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "task_role_arns" {
  description = "Map of service names to task role ARNs"
  type        = map(string)
}

# ==============================================================================
# Service Discovery Configuration
# ==============================================================================

variable "service_discovery_namespace" {
  description = "Service discovery namespace (e.g., eventplanner.local)"
  type        = string
  default     = "eventplanner.local"
}

# ==============================================================================
# Container Configuration
# ==============================================================================

variable "ecr_repository_urls" {
  description = "Map of service names to ECR repository URLs"
  type        = map(string)
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# ==============================================================================
# Database Configuration
# ==============================================================================

variable "db_secret_arns" {
  description = "Map of service names to database secret ARNs"
  type        = map(string)
}

variable "redis_endpoint" {
  description = "Redis endpoint for caching"
  type        = string
}

variable "docdb_endpoint" {
  description = "DocumentDB endpoint for audit logs"
  type        = string
}

variable "jwt_secret_arn" {
  description = "ARN of JWT secret in Secrets Manager for auth service"
  type        = string
  default     = null
}

variable "jwt_access_expiration" {
  description = "JWT access token expiration time in milliseconds"
  type        = number
  default     = 3600000  # 1 hour
}

variable "jwt_refresh_expiration" {
  description = "JWT refresh token expiration time in milliseconds"
  type        = number
  default     = 86400000  # 24 hours
}

variable "sqs_queue_urls" {
  description = "Map of SQS queue URLs"
  type        = map(string)
  default     = {}
}

variable "sqs_queue_names" {
  description = "Map of SQS queue names"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Load Balancer Configuration
# ==============================================================================

variable "target_group_arns" {
  description = "Map of service names to ALB target group ARNs"
  type        = map(string)
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener (HTTP or HTTPS)"
  type        = string
}

# ==============================================================================
# ECS Cluster Configuration
# ==============================================================================

variable "enable_container_insights" {
  description = "Enable Container Insights for monitoring"
  type        = bool
  default     = true
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot for cost savings"
  type        = bool
  default     = false
}

# ==============================================================================
# Logging Configuration
# ==============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  type        = string
  default     = null
}

# ==============================================================================
# Auto Scaling Configuration
# ==============================================================================

variable "cpu_target_value" {
  description = "Target CPU utilization for auto scaling (%)"
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_target_value >= 10 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 10 and 100"
  }
}

variable "memory_target_value" {
  description = "Target memory utilization for auto scaling (%)"
  type        = number
  default     = 75

  validation {
    condition     = var.memory_target_value >= 10 && var.memory_target_value <= 100
    error_message = "Memory target value must be between 10 and 100"
  }
}

variable "scale_in_cooldown" {
  description = "Cooldown period for scale in (seconds)"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period for scale out (seconds)"
  type        = number
  default     = 60
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Additional tags for ECS resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# AWS Credentials Configuration
# ==============================================================================

variable "aws_access_key_id" {
  description = "AWS Access Key ID for services to access AWS resources"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for services to access AWS resources"
  type        = string
  sensitive   = true
}