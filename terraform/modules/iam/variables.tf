# ==============================================================================
# terraform/modules/iam/variables.tf
# ==============================================================================
# Variable definitions for IAM module
# ==============================================================================


variable "project_name" {
  description = "Name of the project (used for IAM role naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "db_secrets_arns" {
  description = "List of ARNs for database secrets (RDS, DocumentDB, ElastiCache) that ECS tasks need to access"
  type        = list(string)
}

variable "frontend_bucket_arn" {
  description = "ARN of the S3 bucket for frontend assets (used by auth and event services)"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all IAM roles"
  type        = map(string)
  default     = {}
}
