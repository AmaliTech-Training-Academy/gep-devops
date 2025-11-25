# terraform/environments/prod/variables.tf
# ==============================================================================
# Production Environment Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "event-planner"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive CloudWatch alerts"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "domain_name" {
  description = "Base domain name"
  type        = string
  default     = "sankofagrid.com"
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default = {
    CostCenter = "Engineering"
    Owner      = "DevOps Team"
  }
}

variable "payment_service_url" {
  description = "Payment service URL for webhooks"
  type        = string
  default     = "https://api.sankofagrid.com"
}

variable "jwt_access_expiration" {
  description = "JWT access token expiration in milliseconds"
  type        = number
  default     = 3600000
}

variable "jwt_refresh_expiration" {
  description = "JWT refresh token expiration in milliseconds"
  type        = number
  default     = 86400000
}

