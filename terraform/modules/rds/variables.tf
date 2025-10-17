# # terraform/modules/rds/variables.tf
# # ==============================================================================
# # RDS Module Variables
# # ==============================================================================

# variable "project_name" {
#   description = "Project name for resource naming"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name (dev, staging, prod)"
#   type        = string
# }

# variable "database_name" {
#   description = "Name of the database (auth, event, booking, payment)"
#   type        = string
# }

# variable "engine_version" {
#   description = "PostgreSQL engine version"
#   type        = string
#   default     = "15.4"
# }

# variable "major_engine_version" {
#   description = "Major engine version for option group"
#   type        = string
#   default     = "15"
# }

# variable "parameter_group_family" {
#   description = "Parameter group family"
#   type        = string
#   default     = "postgres15"
# }

# variable "instance_class" {
#   description = "RDS instance class"
#   type        = string
#   default     = "db.t4g.micro"
# }

# variable "allocated_storage" {
#   description = "Initial allocated storage in GB"
#   type        = number
#   default     = 20
# }

# variable "max_allocated_storage" {
#   description = "Maximum storage for autoscaling"
#   type        = number
#   default     = 100
# }

# variable "storage_type" {
#   description = "Storage type (gp3, gp2, io1)"
#   type        = string
#   default     = "gp3"
# }

# variable "iops" {
#   description = "IOPS for io1 storage type"
#   type        = number
#   default     = null
# }

# variable "master_username" {
#   description = "Master username for database"
#   type        = string
#   default     = "postgres"
# }

# variable "master_password_secret_arn" {
#   description = "ARN of Secrets Manager secret containing master password"
#   type        = string
# }

# variable "multi_az" {
#   description = "Enable Multi-AZ deployment"
#   type        = bool
#   default     = false
# }

# variable "create_read_replicas" {
#   description = "Create read replicas"
#   type        = bool
#   default     = false
# }

# variable "read_replica_count" {
#   description = "Number of read replicas to create"
#   type        = number
#   default     = 0
# }

# variable "replica_instance_class" {
#   description = "Instance class for read replicas (defaults to primary instance class)"
#   type        = string
#   default     = null
# }

# variable "replica_availability_zones" {
#   description = "Availability zones for read replicas"
#   type        = list(string)
#   default     = null
# }

# variable "vpc_id" {
#   description = "VPC ID"
#   type        = string
# }

# variable "subnet_ids" {
#   description = "Subnet IDs for DB subnet group"
#   type        = list(string)
# }

# variable "vpc_security_group_ids" {
#   description = "VPC security group IDs"
#   type        = list(string)
# }

# variable "backup_retention_period" {
#   description = "Backup retention period in days"
#   type        = number
#   default     = 7
# }

# variable "backup_window" {
#   description = "Preferred backup window"
#   type        = string
#   default     = "03:00-04:00"
# }

# variable "maintenance_window" {
#   description = "Preferred maintenance window"
#   type        = string
#   default     = "sun:04:00-sun:05:00"
# }

# variable "skip_final_snapshot" {
#   description = "Skip final snapshot on deletion"
#   type        = bool
#   default     = false
# }

# variable "enabled_cloudwatch_logs_exports" {
#   description = "CloudWatch log types to enable"
#   type        = list(string)
#   default     = ["postgresql"]
# }

# variable "monitoring_interval" {
#   description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
#   type        = number
#   default     = 0
# }

# variable "performance_insights_enabled" {
#   description = "Enable Performance Insights"
#   type        = bool
#   default     = false
# }

# variable "performance_insights_retention_period" {
#   description = "Performance Insights retention period in days"
#   type        = number
#   default     = 7
# }

# variable "auto_minor_version_upgrade" {
#   description = "Enable auto minor version upgrades"
#   type        = bool
#   default     = true
# }

# variable "deletion_protection" {
#   description = "Enable deletion protection"
#   type        = bool
#   default     = true
# }

# variable "create_kms_key" {
#   description = "Create KMS key for encryption"
#   type        = bool
#   default     = false
# }

# variable "create_cloudwatch_alarms" {
#   description = "Create CloudWatch alarms"
#   type        = bool
#   default     = false
# }

# variable "alarm_actions" {
#   description = "SNS topic ARNs for alarm actions"
#   type        = list(string)
#   default     = []
# }

# variable "cpu_alarm_threshold" {
#   description = "CPU utilization alarm threshold (%)"
#   type        = number
#   default     = 80
# }

# variable "free_storage_space_threshold" {
#   description = "Free storage space alarm threshold (bytes)"
#   type        = number
#   default     = 10737418240  # 10 GB
# }

# variable "database_connections_threshold" {
#   description = "Database connections alarm threshold"
#   type        = number
#   default     = 80
# }

# variable "tags" {
#   description = "Additional tags"
#   type        = map(string)
#   default     = {}
# }

