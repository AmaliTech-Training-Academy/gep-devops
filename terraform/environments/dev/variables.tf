# terraform/environments/dev/variables.tf
# ==============================================================================
# Development Environment Variables
# ==============================================================================
# Updated to test pipeline trigger - skip ACM module validation

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
  default     = "dev"
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive CloudWatch alerts"
  type        = list(string)
  default     = [] # Or provide actual email addresses
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a"]
}

variable "domain_name" {
  description = "Base domain name"
  type        = string
  default     = "sankofagrid.com"
}

variable "frontend_domain" {
  description = "Frontend domain name"
  type        = string
  default     = "www.sankofagrid.com"
}

variable "backend_domain" {
  description = "Backend API domain name"
  type        = string
  default     = "api.sankofagrid.com"
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

