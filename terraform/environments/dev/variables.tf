# ==============================================================================
# terraform/environments/dev/variables.tf
# ==============================================================================
# Development Environment Variables
# ==============================================================================
# This file defines all input variables for the development environment.
# Variables can be overridden via:
# - terraform.tfvars file
# - Command line: terraform apply -var="variable_name=value"
# - Environment variables: TF_VAR_variable_name
# ==============================================================================

# ==============================================================================
# AWS Configuration
# ==============================================================================

variable "aws_region" {
  description = "AWS region where all infrastructure will be deployed (e.g., eu-west-1, us-east-1)"
  type        = string
  default     = "eu-west-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1, eu-west-1)."
  }
}

# ==============================================================================
# Project Identification
# ==============================================================================

variable "project_name" {
  description = "Project name used as prefix for all resource names (e.g., event-planner-dev-vpc)"
  type        = string
  default     = "event-planner"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod) - used for resource naming and configuration"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ==============================================================================
# Monitoring & Alerting
# ==============================================================================

variable "alert_email_addresses" {
  description = "List of email addresses to receive CloudWatch alarm notifications (e.g., high CPU, database issues)"
  type        = list(string)
  default     = [] # Add email addresses like: ["devops@example.com", "alerts@example.com"]
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC (10.0.0.0/16 provides 65,536 IP addresses)"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones for resource deployment. Dev uses 1 AZ for cost savings, Prod uses 2+ for high availability"
  type        = list(string)
  default     = ["eu-west-1a"] # Single AZ for dev environment (cost-optimized)
  
  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone must be specified."
  }
}

# ==============================================================================
# Domain Configuration
# ==============================================================================

variable "domain_name" {
  description = "Base domain name for the application (e.g., sankofagrid.com). Subdomains will be created: www.sankofagrid.com (frontend), api.sankofagrid.com (backend)"
  type        = string
  default     = "sankofagrid.com"
}

# Commented out - subdomains are constructed dynamically in main.tf
# variable "frontend_domain" {
#   description = "Frontend domain name (e.g., www.sankofagrid.com)"
#   type        = string
#   default     = "www.sankofagrid.com"
# }

# variable "backend_domain" {
#   description = "Backend API domain name (e.g., api.sankofagrid.com)"
#   type        = string
#   default     = "api.sankofagrid.com"
# }

# ==============================================================================
# VPC Features
# ==============================================================================

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic analysis and security monitoring. Logs are sent to CloudWatch"
  type        = bool
  default     = true # Recommended for security and troubleshooting
}

# ==============================================================================
# JWT Configuration
# ==============================================================================

variable "jwt_access_expiration" {
  description = "JWT access token expiration time in milliseconds (default: 3600000 = 1 hour)"
  type        = number
  default     = 3600000
}

variable "jwt_refresh_expiration" {
  description = "JWT refresh token expiration time in milliseconds (default: 86400000 = 24 hours)"
  type        = number
  default     = 86400000
}

# ==============================================================================
# Resource Tagging
# ==============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources for cost tracking, organization, and compliance"
  type        = map(string)
  default = {
    CostCenter = "Engineering"  # For cost allocation reports
    Owner      = "DevOps Team"  # Team responsible for infrastructure
  }
}

# ==============================================================================
# AWS Credentials
# ==============================================================================

variable "aws_access_key_id" {
  description = "AWS Access Key ID for services to access AWS resources (SQS, S3, etc.)"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for services to access AWS resources"
  type        = string
  sensitive   = true
}

