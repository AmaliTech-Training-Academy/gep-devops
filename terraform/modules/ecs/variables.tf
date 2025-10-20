# ==============================================================================
# ECS Module Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default = "eu-west-1"
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

# ==============================================================================
# Load Balancer Configuration
# ==============================================================================

variable "target_group_arns" {
  description = "Map of service names to ALB target group ARNs"
  type        = map(string)
}

variable "alb_listener_arn" {
  description = "ARN of the ALB HTTPS listener"
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
}

variable "memory_target_value" {
  description = "Target memory utilization for auto scaling (%)"
  type        = number
  default     = 75
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