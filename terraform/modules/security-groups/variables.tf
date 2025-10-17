# ==============================================================================
# terraform/modules/security-groups/variables.tf
# ==============================================================================
# Variable definitions for Security Groups module
# ==============================================================================

# ------------------------------------------------------------------------------
# Required Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}


variable "tags" {
  description = "Additional tags to apply to all security groups"
  type        = map(string)
  default     = {}
}