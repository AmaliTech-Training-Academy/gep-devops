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
# ==============================================================================
# Resource Tagging
# ==============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources for cost tracking, organization, and compliance"
  type        = map(string)
  default = {
    CostCenter = "Engineering" # For cost allocation reports
    Owner      = "DevOps Team" # Team responsible for infrastructure
  }
}

# ==============================================================================
# Grafana Configuration
# ==============================================================================

variable "grafana_admin_password" {
  description = "Admin password for Grafana dashboard access"
  type        = string
  sensitive   = true
}