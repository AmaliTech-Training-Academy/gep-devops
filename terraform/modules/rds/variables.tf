# ==============================================================================
# RDS Module Variables - Database Infrastructure Configuration
# ==============================================================================
# WHAT THIS FILE DOES:
# Defines settings for the existing auth-db PostgreSQL instance where all
# microservices store their data using separate schemas.
#
# BUSINESS DATA STORED (Multi-Schema Approach):
# - Auth Service: User accounts and authentication (public schema)
# - Event Service: Event details and scheduling (event_schema)
# - Payment Service: Payment transactions (payment_schema)
# - System audit logs and compliance records
#
# CONFIGURATION CATEGORIES:
# - Database Sizing: Computing power and storage for the shared database
# - Security Settings: Encryption, access controls, and compliance features
# - Backup & Recovery: How we protect against data loss
# - Performance: Speed and reliability optimizations
# - Monitoring: Health checks and alerting for database issues
#
# BUSINESS IMPACT:
# - Cost Optimization: Single database instance instead of multiple
# - Data Loss Prevention: Automated backups and redundancy
# - Performance: Fast response times for user interactions
# - Security: Encrypted storage and secure access controls
# ==============================================================================

# ==============================================================================
# Basic Infrastructure Configuration
# ==============================================================================

variable "project_name" {
  description = "Name of the project (e.g., 'event-planner'). Used to organize and identify all database resources."
  type        = string
}

variable "environment" {
  description = "Environment name that determines database configuration. 'dev' = cost-optimized single instance, 'prod' = high-availability with backups."
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs where databases will be deployed. These are secure network areas with no direct internet access."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID that controls which applications can access the databases. Acts like a digital firewall protecting our data."
  type        = string
}

# ==============================================================================
# Database Sizing Configuration - Computing Power and Storage
# ==============================================================================
# WHAT THESE SETTINGS CONTROL:
# The computing power and storage capacity for each business database.
# Like choosing the right size safe for different types of valuables.
#
# INSTANCE CLASSES EXPLAINED:
# - db.t3.micro: Small (1 vCPU, 1GB RAM) - suitable for light workloads
# - db.t3.medium: Medium (2 vCPU, 4GB RAM) - good for moderate traffic
# - db.t3.large: Large (2 vCPU, 8GB RAM) - handles high traffic volumes
#
# STORAGE AUTO-SCALING:
# Databases automatically grow when they need more space, up to the maximum limit.
# Prevents running out of storage space during business growth.

# Single Database Configuration (Multi-Schema Approach)
variable "db_instance_class" {
  description = "Computing power for the database. All services connect to this single instance using different schemas."
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Starting storage space for the database (GB). Automatically grows as data increases."
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "Maximum storage limit for the database (GB). Prevents runaway storage costs while allowing growth."
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
# Business Continuity Configuration - Preventing Downtime
# ==============================================================================
# WHAT THESE SETTINGS PROVIDE:
# Protection against database failures that could shut down our business.
# Like having backup generators and multiple office locations.
#
# MULTI-AZ DEPLOYMENT:
# Creates an identical backup database in a different data center.
# If the main database fails, the backup takes over automatically in minutes.
# COST: Doubles database costs but prevents business downtime.
#
# READ REPLICAS:
# Creates additional read-only copies of the database for faster queries.
# Improves performance when many users are browsing events simultaneously.
# COST: Additional database instances but improves user experience.

variable "multi_az" {
  description = "Enable automatic failover to backup database in different data center. Recommended for production to prevent business downtime."
  type        = bool
  default     = false
}

variable "create_read_replicas" {
  description = "Create additional read-only database copies for faster performance. Improves response times when many users browse events."
  type        = bool
  default     = false
}

# ==============================================================================
# Data Protection Configuration - Backup and Recovery
# ==============================================================================
# WHAT THESE SETTINGS PROVIDE:
# Automatic protection against data loss from accidents, corruption, or attacks.
# Like having multiple copies of important business documents in different safes.
#
# BACKUP STRATEGY:
# - Automated daily backups during low-traffic hours
# - Point-in-time recovery (can restore to any minute within retention period)
# - Maintenance during weekend hours to minimize business impact
#
# BUSINESS VALUE:
# - Protects against accidental data deletion
# - Enables recovery from database corruption
# - Supports compliance requirements for data retention
# - Provides disaster recovery capabilities

variable "backup_retention_days" {
  description = "How many days to keep database backups. Longer retention = better recovery options but higher storage costs. 7 days = 1 week of protection."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Time when daily backups occur (UTC timezone). 03:00-04:00 = 3-4 AM UTC when user traffic is lowest."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Time when database updates occur (UTC timezone). Sunday 4-5 AM UTC minimizes impact on business operations."
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
  default     = 5368709120 # 5 GB
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