# terraform/modules/cloudwatch/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "alert_email_addresses" {
  description = "List of email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = ""
}

variable "alb_arn" {
  description = "ALB ARN"
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix"
  type        = string
  default     = ""
}

variable "rds_instance_id" {
  description = "RDS instance ID"
  type        = string
  default     = ""
}

variable "elasticache_cluster_id" {
  description = "ElastiCache cluster ID"
  type        = string
  default     = ""
}

# Alarm Thresholds
variable "ecs_cpu_threshold" {
  description = "ECS CPU utilization threshold (%)"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "ECS memory utilization threshold (%)"
  type        = number
  default     = 80
}

variable "alb_5xx_threshold" {
  description = "ALB 5XX error count threshold"
  type        = number
  default     = 10
}

variable "alb_response_time_threshold" {
  description = "ALB response time threshold (seconds)"
  type        = number
  default     = 2
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization threshold (%)"
  type        = number
  default     = 80
}

variable "rds_storage_threshold_bytes" {
  description = "RDS free storage threshold (bytes)"
  type        = number
  default     = 5368709120 # 5 GB
}

variable "rds_connections_threshold" {
  description = "RDS database connections threshold"
  type        = number
  default     = 80
}

variable "elasticache_cpu_threshold" {
  description = "ElastiCache CPU utilization threshold (%)"
  type        = number
  default     = 75
}

variable "elasticache_memory_threshold" {
  description = "ElastiCache memory utilization threshold (%)"
  type        = number
  default     = 90
}

variable "elasticache_evictions_threshold" {
  description = "ElastiCache evictions threshold"
  type        = number
  default     = 1000
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

