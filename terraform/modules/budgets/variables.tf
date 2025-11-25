# ==============================================================================
# AWS Budgets Module - Variables
# ==============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
}

variable "anomaly_threshold" {
  description = "Dollar amount threshold for anomaly detection alerts"
  type        = string
  default     = "25"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
