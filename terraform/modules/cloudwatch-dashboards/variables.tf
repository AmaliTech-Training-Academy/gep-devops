# ==============================================================================
# CloudWatch Dashboards Module Variables
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
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "auth_target_group_arn_suffix" {
  description = "Auth service target group ARN suffix"
  type        = string
}

variable "event_target_group_arn_suffix" {
  description = "Event service target group ARN suffix"
  type        = string
  default     = ""
}

variable "auth_db_instance_id" {
  description = "Auth database instance identifier"
  type        = string
}

variable "elasticache_cluster_id" {
  description = "ElastiCache cluster ID"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  type        = string
  default     = ""
}

variable "s3_bucket_name" {
  description = "S3 bucket name for frontend assets"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
