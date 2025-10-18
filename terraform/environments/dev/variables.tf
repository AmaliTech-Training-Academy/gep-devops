# terraform/environments/dev/variables.tf
# ==============================================================================
# Development Environment Variables
# ==============================================================================
# Updated to test pipeline trigger - fix unzip dependency

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
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

# Secrets variables
variable "db_master_password" {
  description = "Master password for RDS databases"
  type        = string
  sensitive   = true
}

variable "docdb_master_password" {
  description = "Master password for DocumentDB"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT signing secret key"
  type        = string
  sensitive   = true
}

# GitHub OIDC variables
variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "your-org/event-planner"
}
