# ==============================================================================
# terraform/modules/iam/variables.tf
# ==============================================================================
# IAM Module Variables - Security and Access Control Configuration
# ==============================================================================
# WHAT THIS FILE DOES:
# Defines the security settings and resource permissions needed to create
# digital identity badges for our applications. Like specifying which
# departments exist and what resources each department needs access to.
#
# SECURITY CONFIGURATION:
# - Project identification for organizing security policies
# - Environment settings that affect security levels
# - Database access permissions for storing business data
# - File storage permissions for website and user content
# - Secret access permissions for passwords and API keys
#
# BUSINESS IMPACT:
# - Ensures applications can access required business resources
# - Prevents unauthorized access to sensitive customer data
# - Supports compliance with data protection regulations
# - Enables secure communication between business services
# ==============================================================================


# ==============================================================================
# Basic Security Configuration
# ==============================================================================

variable "project_name" {
  description = "Name of the project used to organize security policies and roles. Helps identify which permissions belong to our event planning platform."
  type        = string
}

variable "environment" {
  description = "Environment name that affects security levels. 'dev' = relaxed security for testing, 'prod' = strict security for customer data protection."
  type        = string
}

# ==============================================================================
# Resource Access Configuration
# ==============================================================================

variable "db_secrets_arns" {
  description = "List of secure storage locations for database passwords. Applications need these to connect to databases containing customer and business data."
  type        = list(string)
}

variable "frontend_bucket_arn" {
  description = "Location of website files and user-uploaded content. Auth and event services need access to manage user profiles and event images."
  type        = string
}

variable "backend_files_bucket_arn" {
  description = "Location of backend files bucket for user uploads (profile pictures, documents, etc.). Services use presigned URLs to allow secure direct uploads."
  type        = string
}

variable "jwt_secret_arn" {
  description = "Secure storage location for user authentication keys. Auth service needs this to verify user logins and create secure sessions."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all IAM roles"
  type        = map(string)
  default     = {}
}






