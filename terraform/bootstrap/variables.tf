# terraform/bootstrap/variables.tf
# ==============================================================================
# Terraform Bootstrap Variables
# ==============================================================================
# This file defines all input variables used in the bootstrap module.
# These variables control region, project naming, alerts, and table settings.
# ==============================================================================

variable "aws_region" {
  description = "AWS region to deploy the Terraform backend resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for naming S3 bucket, DynamoDB table, and other resources"
  type        = string
}

variable "enable_dynamodb_pitr" {
  description = "Enable DynamoDB point-in-time recovery for Terraform lock table"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address to receive SNS alerts for backend monitoring. Leave empty to disable."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Owner       = "DevOps"
    Environment = "bootstrap"
  }
}
