# ==============================================================================
# DocumentDB Module - Variables
# ==============================================================================

# ==============================================================================
# Required Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DocumentDB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID to associate with the DocumentDB cluster"
  type        = string
}

# ==============================================================================
# DocumentDB Configuration
# ==============================================================================

variable "engine_version" {
  description = "DocumentDB engine version"
  type        = string
  default     = "5.0.0"
  
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.engine_version))
    error_message = "Engine version must be in format X.Y.Z (e.g., 5.0.0)"
  }
}

variable "docdb_family" {
  description = "DocumentDB parameter group family"
  type        = string
  default     = "docdb5.0"
}

variable "port" {
  description = "Port number for DocumentDB"
  type        = number
  default     = 27017
  
  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "Port must be between 1024 and 65535"
  }
}

variable "instance_class" {
  description = "Instance class for DocumentDB cluster instances"
  type        = string
  default     = "db.t3.medium"
  
  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "Instance class must start with 'db.'"
  }
}

variable "replica_count" {
  description = "Number of read replicas to create"
  type        = number
  default     = 0
  
  validation {
    condition     = var.replica_count >= 0 && var.replica_count <= 15
    error_message = "Replica count must be between 0 and 15"
  }
}

# ==============================================================================
# Authentication
# ==============================================================================

variable "master_username" {
  description = "Master username for DocumentDB cluster"
  type        = string
  default     = "docdbadmin"
  
  validation {
    condition     = length(var.master_username) >= 1 && length(var.master_username) <= 63
    error_message = "Master username must be between 1 and 63 characters"
  }
}

# ==============================================================================
# Backup Configuration
# ==============================================================================

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days"
  }
}

variable "backup_window" {
  description = "Daily time range for backups (format: hh24:mi-hh24:mi UTC)"
  type        = string
  default     = "03:00-04:00"
  
  validation {
    condition     = can(regex("^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$", var.backup_window))
    error_message = "Backup window must be in format hh24:mi-hh24:mi"
  }
}

variable "maintenance_window" {
  description = "Weekly maintenance window (format: ddd:hh24:mi-ddd:hh24:mi UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
  
  validation {
    condition     = can(regex("^[a-z]{3}:[0-2][0-9]:[0-5][0-9]-[a-z]{3}:[0-2][0-9]:[0-5][0-9]$", var.maintenance_window))
    error_message = "Maintenance window must be in format ddd:hh24:mi-ddd:hh24:mi"
  }
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when cluster is deleted"
  type        = bool
  default     = false
}

# ==============================================================================
# Security & Encryption
# ==============================================================================

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
  default     = null
}

variable "tls_enabled" {
  description = "Enable TLS for connections"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "secret_recovery_window_days" {
  description = "Number of days to retain deleted secrets"
  type        = number
  default     = 7
  
  validation {
    condition     = var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30
    error_message = "Secret recovery window must be between 7 and 30 days"
  }
}

# ==============================================================================
# Parameter Group Settings
# ==============================================================================

variable "audit_logs_enabled" {
  description = "Enable audit logs"
  type        = bool
  default     = true
}

variable "ttl_monitor_enabled" {
  description = "Enable TTL monitor for automatic data expiration"
  type        = bool
  default     = true
}

variable "profiler_enabled" {
  description = "Enable profiler for slow query logging"
  type        = bool
  default     = true
}

variable "profiler_threshold_ms" {
  description = "Profiler threshold in milliseconds"
  type        = string
  default     = "100"
  
  validation {
    condition     = can(tonumber(var.profiler_threshold_ms))
    error_message = "Profiler threshold must be a valid number"
  }
}

# ==============================================================================
# Monitoring & Logging
# ==============================================================================

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch Logs"
  type        = list(string)
  default     = ["audit", "profiler"]
  
  validation {
    condition = alltrue([
      for log_type in var.enabled_cloudwatch_logs_exports :
      contains(["audit", "profiler"], log_type)
    ])
    error_message = "Valid log types are 'audit' and 'profiler'"
  }
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarm (percentage)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cpu_alarm_threshold >= 0 && var.cpu_alarm_threshold <= 100
    error_message = "CPU alarm threshold must be between 0 and 100"
  }
}

variable "connections_alarm_threshold" {
  description = "Database connections threshold for alarm"
  type        = number
  default     = 100
  
  validation {
    condition     = var.connections_alarm_threshold > 0
    error_message = "Connections alarm threshold must be greater than 0"
  }
}

variable "storage_alarm_threshold_bytes" {
  description = "Storage space threshold for alarm (bytes)"
  type        = number
  default     = 10737418240  # 10GB
  
  validation {
    condition     = var.storage_alarm_threshold_bytes > 0
    error_message = "Storage alarm threshold must be greater than 0"
  }
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Operational Settings
# ==============================================================================

variable "apply_immediately" {
  description = "Apply changes immediately instead of during maintenance window"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}