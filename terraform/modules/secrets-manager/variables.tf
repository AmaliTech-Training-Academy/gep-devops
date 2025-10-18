# ==============================================================================
# Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "database_secrets" {
  description = "Map of database secrets with username and password"
  type = map(object({
    username = string
    password = string
  }))
  default = {}
}

variable "jwt_secret_key" {
  description = "JWT signing secret key"
  type        = string
  sensitive   = true
}

variable "enable_documentdb" {
  description = "Enable DocumentDB secret creation"
  type        = bool
  default     = true
}

variable "documentdb_username" {
  description = "DocumentDB master username"
  type        = string
  default     = "docdbadmin"
}

variable "documentdb_password" {
  description = "DocumentDB master password"
  type        = string
  sensitive   = true
}

variable "elasticache_auth_token" {
  description = "ElastiCache Redis auth token (production only)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}