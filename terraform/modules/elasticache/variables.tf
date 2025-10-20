# ==============================================================================
# ElastiCache Module - Variables
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
  description = "List of subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the cluster"
  type        = list(string)
}

# ==============================================================================
# Redis Configuration
# ==============================================================================

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "redis_port" {
  description = "Port number for Redis"
  type        = number
  default     = 6379
}

variable "node_type" {
  description = "The instance type to use for the cache nodes"
  type        = string
  default     = "cache.t3.micro"
  
  validation {
    condition     = can(regex("^cache\\.", var.node_type))
    error_message = "Node type must start with 'cache.'"
  }
}

# ==============================================================================
# Cluster Configuration
# ==============================================================================

variable "cluster_mode_enabled" {
  description = "Enable cluster mode for Redis"
  type        = bool
  default     = false
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (for cluster mode disabled)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.num_cache_nodes >= 1 && var.num_cache_nodes <= 6
    error_message = "Number of cache nodes must be between 1 and 6."
  }
}

variable "num_node_groups" {
  description = "Number of node groups (shards) for cluster mode"
  type        = number
  default     = 3
  
  validation {
    condition     = var.num_node_groups >= 1 && var.num_node_groups <= 500
    error_message = "Number of node groups must be between 1 and 500."
  }
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes per node group"
  type        = number
  default     = 2
  
  validation {
    condition     = var.replicas_per_node_group >= 0 && var.replicas_per_node_group <= 5
    error_message = "Replicas per node group must be between 0 and 5."
  }
}

# ==============================================================================
# High Availability
# ==============================================================================

variable "automatic_failover_enabled" {
  description = "Enable automatic failover for the replication group"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ support"
  type        = bool
  default     = false
}

# ==============================================================================
# Maintenance & Backup
# ==============================================================================

variable "maintenance_window" {
  description = "Maintenance window (format: ddd:hh24:mi-ddd:hh24:mi)"
  type        = string
  default     = "sun:05:00-sun:06:00"
  
  validation {
    condition     = can(regex("^[a-z]{3}:[0-2][0-9]:[0-5][0-9]-[a-z]{3}:[0-2][0-9]:[0-5][0-9]$", var.maintenance_window))
    error_message = "Maintenance window must be in the format ddd:hh24:mi-ddd:hh24:mi"
  }
}

variable "snapshot_window" {
  description = "Daily time range for backups (format: hh24:mi-hh24:mi)"
  type        = string
  default     = "03:00-04:00"
  
  validation {
    condition     = can(regex("^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$", var.snapshot_window))
    error_message = "Snapshot window must be in the format hh24:mi-hh24:mi"
  }
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain backups"
  type        = number
  default     = 5
  
  validation {
    condition     = var.snapshot_retention_limit >= 0 && var.snapshot_retention_limit <= 35
    error_message = "Snapshot retention limit must be between 0 and 35 days."
  }
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately instead of during maintenance window"
  type        = bool
  default     = false
}

# ==============================================================================
# Security
# ==============================================================================

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Password to use when transit encryption is enabled"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = (
      var.auth_token == null
      || (
        can(length(tostring(var.auth_token)))
        && length(tostring(var.auth_token)) >= 16
        && length(tostring(var.auth_token)) <= 128
      )
    )
    error_message = "Auth token must be null or between 16 and 128 characters if provided."
  }
}


# ==============================================================================
# Parameter Group Settings
# ==============================================================================

variable "maxmemory_policy" {
  description = "Memory eviction policy"
  type        = string
  default     = "allkeys-lru"
  
  validation {
    condition = contains([
      "volatile-lru",
      "allkeys-lru",
      "volatile-lfu",
      "allkeys-lfu",
      "volatile-random",
      "allkeys-random",
      "volatile-ttl",
      "noeviction"
    ], var.maxmemory_policy)
    error_message = "Invalid maxmemory_policy value."
  }
}

variable "timeout" {
  description = "Close connection after client is idle for N seconds (0 to disable)"
  type        = string
  default     = "300"
}

variable "appendonly" {
  description = "Enable Redis persistence using append-only file"
  type        = bool
  default     = false
}

# ==============================================================================
# Logging
# ==============================================================================

variable "slow_log_destination" {
  description = "CloudWatch Log Group name for slow logs"
  type        = string
  default     = null
}

variable "slow_log_destination_type" {
  description = "Destination type for slow logs (cloudwatch-logs or kinesis-firehose)"
  type        = string
  default     = "cloudwatch-logs"
  
  validation {
    condition     = var.slow_log_destination_type == "cloudwatch-logs" || var.slow_log_destination_type == "kinesis-firehose"
    error_message = "Destination type must be either 'cloudwatch-logs' or 'kinesis-firehose'."
  }
}

variable "engine_log_destination" {
  description = "CloudWatch Log Group name for engine logs"
  type        = string
  default     = null
}

variable "engine_log_destination_type" {
  description = "Destination type for engine logs (cloudwatch-logs or kinesis-firehose)"
  type        = string
  default     = "cloudwatch-logs"
  
  validation {
    condition     = var.engine_log_destination_type == "cloudwatch-logs" || var.engine_log_destination_type == "kinesis-firehose"
    error_message = "Destination type must be either 'cloudwatch-logs' or 'kinesis-firehose'."
  }
}

variable "log_format" {
  description = "Log format (json or text)"
  type        = string
  default     = "json"
  
  validation {
    condition     = var.log_format == "json" || var.log_format == "text"
    error_message = "Log format must be either 'json' or 'text'."
  }
}

# ==============================================================================
# Notifications
# ==============================================================================

variable "notification_topic_arn" {
  description = "SNS topic ARN for ElastiCache notifications"
  type        = string
  default     = null
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "cpu_utilization_threshold" {
  description = "CPU utilization threshold for alarm (percentage)"
  type        = number
  default     = 75
  
  validation {
    condition     = var.cpu_utilization_threshold >= 0 && var.cpu_utilization_threshold <= 100
    error_message = "CPU utilization threshold must be between 0 and 100."
  }
}

variable "memory_utilization_threshold" {
  description = "Memory utilization threshold for alarm (percentage)"
  type        = number
  default     = 90
  
  validation {
    condition     = var.memory_utilization_threshold >= 0 && var.memory_utilization_threshold <= 100
    error_message = "Memory utilization threshold must be between 0 and 100."
  }
}

variable "evictions_threshold" {
  description = "Number of evictions threshold for alarm"
  type        = number
  default     = 1000
  
  validation {
    condition     = var.evictions_threshold >= 0
    error_message = "Evictions threshold must be a non-negative number."
  }
}

variable "swap_usage_threshold" {
  description = "Swap usage threshold for alarm (bytes)"
  type        = number
  default     = 52428800  # 50MB
  
  validation {
    condition     = var.swap_usage_threshold >= 0
    error_message = "Swap usage threshold must be a non-negative number."
  }
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}