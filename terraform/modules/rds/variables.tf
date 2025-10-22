# ==============================================================================
# RDS Module Variables
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
  description = "List of subnet IDs for DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS instances"
  type        = string
}

# ==============================================================================
# Database Instance Configuration
# ==============================================================================

# Auth Database
variable "auth_db_instance_class" {
  description = "Instance class for auth database"
  type        = string
  default     = "db.t3.medium"
}

variable "auth_db_allocated_storage" {
  description = "Allocated storage for auth database (GB)"
  type        = number
  default     = 100
}

variable "auth_db_max_allocated_storage" {
  description = "Maximum allocated storage for auth database (GB)"
  type        = number
  default     = 500
}

# Event Database
variable "event_db_instance_class" {
  description = "Instance class for event database"
  type        = string
  default     = "db.t3.medium"
}

variable "event_db_allocated_storage" {
  description = "Allocated storage for event database (GB)"
  type        = number
  default     = 200
}

variable "event_db_max_allocated_storage" {
  description = "Maximum allocated storage for event database (GB)"
  type        = number
  default     = 1000
}

# Booking Database
variable "booking_db_instance_class" {
  description = "Instance class for booking database"
  type        = string
  default     = "db.t3.medium"
}

variable "booking_db_allocated_storage" {
  description = "Allocated storage for booking database (GB)"
  type        = number
  default     = 200
}

variable "booking_db_max_allocated_storage" {
  description = "Maximum allocated storage for booking database (GB)"
  type        = number
  default     = 1000
}

# Payment Database
variable "payment_db_instance_class" {
  description = "Instance class for payment database"
  type        = string
  default     = "db.t3.medium"
}

variable "payment_db_allocated_storage" {
  description = "Allocated storage for payment database (GB)"
  type        = number
  default     = 100
}

variable "payment_db_max_allocated_storage" {
  description = "Maximum allocated storage for payment database (GB)"
  type        = number
  default     = 500
}

# ==============================================================================
# PostgreSQL Configuration
# ==============================================================================

variable "postgres_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.7"
}

variable "postgres_family" {
  description = "PostgreSQL parameter group family"
  type        = string
  default     = "postgres15"
}

variable "master_username" {
  description = "Master username for RDS instances"
  type        = string
  default     = "dbadmin"
}

variable "max_connections" {
  description = "Maximum number of database connections"
  type        = string
  default     = "100"
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "storage_type" {
  description = "Storage type (gp3, gp2, io1)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2", "io1"], var.storage_type)
    error_message = "Storage type must be gp3, gp2, or io1."
  }
}

variable "provisioned_iops" {
  description = "Provisioned IOPS for io1 storage type"
  type        = number
  default     = 3000
}

# ==============================================================================
# High Availability Configuration
# ==============================================================================

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "create_read_replicas" {
  description = "Create read replicas for each database"
  type        = bool
  default     = false
}

# ==============================================================================
# Backup Configuration
# ==============================================================================

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

# ==============================================================================
# Encryption Configuration
# ==============================================================================

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

# ==============================================================================
# Monitoring Configuration
# ==============================================================================

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring"
  type        = bool
  default     = true
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

# ==============================================================================
# Security Configuration
# ==============================================================================

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}

# ==============================================================================
# Secrets Manager Configuration
# ==============================================================================

variable "secret_recovery_window_days" {
  description = "Recovery window for deleted secrets (days)"
  type        = number
  default     = 7
}

# ==============================================================================
# Alarm Configuration
# ==============================================================================

variable "cpu_alarm_threshold" {
  description = "CPU utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "storage_alarm_threshold_bytes" {
  description = "Free storage alarm threshold (bytes)"
  type        = number
  default     = 5368709120  # 5 GB
}

variable "connections_alarm_threshold" {
  description = "Database connections alarm threshold"
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "List of ARNs for alarm actions"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Additional tags for RDS resources"
  type        = map(string)
  default     = {}
}