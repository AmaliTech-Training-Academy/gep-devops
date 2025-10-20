# terraform/modules/s3/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN for bucket policy"
  type        = string
  default     = ""
}

variable "enable_versioning" {
  description = "Enable S3 versioning"
  type        = bool
  default     = true
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules"
  type        = bool
  default     = true
}

variable "transition_to_ia_days" {
  description = "Days before transitioning to Infrequent Access"
  type        = number
  default     = 90
}

variable "transition_to_glacier_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 180
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent versions"
  type        = number
  default     = 30
}

variable "enable_cors" {
  description = "Enable CORS configuration"
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "Allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "enable_access_logging" {
  description = "Enable access logging"
  type        = bool
  default     = true
}

variable "logs_expiration_days" {
  description = "Days to retain access logs"
  type        = number
  default     = 90
}

variable "backup_retention_days" {
  description = "Days to retain backups"
  type        = number
  default     = 365
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

