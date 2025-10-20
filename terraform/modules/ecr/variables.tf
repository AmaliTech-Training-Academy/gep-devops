# ==============================================================================
# ECR Module Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "enable_image_scanning" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for repository encryption"
  type        = string
  default     = null
}

variable "max_image_count" {
  description = "Maximum number of tagged images to retain"
  type        = number
  default     = 30
}

variable "untagged_image_retention_days" {
  description = "Number of days to retain untagged images"
  type        = number
  default     = 7
}

variable "enable_cross_account_access" {
  description = "Enable cross-account access to ECR repositories"
  type        = bool
  default     = false
}

variable "allowed_account_ids" {
  description = "List of AWS account IDs allowed to access ECR repositories"
  type        = list(string)
  default     = []
}

variable "enable_replication" {
  description = "Enable cross-region replication for DR"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "AWS region for replication"
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Additional tags for ECR repositories"
  type        = map(string)
  default     = {}
}