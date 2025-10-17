# # terraform/modules/rds/main.tf
# # ==============================================================================
# # RDS PostgreSQL Module
# # ==============================================================================
# # This module creates RDS PostgreSQL instances with the following features:
# # - Multi-AZ deployment (optional, for production)
# # - Read replicas (optional, for production)
# # - Automated backups with configurable retention
# # - KMS encryption at rest
# # - SSL/TLS encryption in transit
# # - CloudWatch monitoring and logging
# # - Parameter group for PostgreSQL optimization
# # - Option group for additional features
# # - Subnet group for VPC placement
# # ==============================================================================

# terraform {
#   required_version = ">= 1.5.0"
  
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# # ==============================================================================
# # Data Sources
# # ==============================================================================

# # Retrieve database password from Secrets Manager
# data "aws_secretsmanager_secret_version" "master_password" {
#   secret_id = var.master_password_secret_arn
# }

# # Get current AWS region
# data "aws_region" "current" {}

# # ==============================================================================
# # Local Variables
# # ==============================================================================

# locals {
#   # Identifier for RDS instance
#   db_identifier = "${var.project_name}-${var.environment}-${var.database_name}-db"
  
#   # Master password from Secrets Manager
#   master_password = jsondecode(data.aws_secretsmanager_secret_version.master_password.secret_string)
  
#   # Common tags
#   common_tags = merge(
#     var.tags,
#     {
#       Module       = "rds"
#       Environment  = var.environment
#       DatabaseName = var.database_name
#     }
#   )
# }

# # ==============================================================================
# # DB Subnet Group
# # ==============================================================================

# # Create DB subnet group for RDS placement
# resource "aws_db_subnet_group" "main" {
#   name_prefix = "${local.db_identifier}-"
#   description = "Subnet group for ${local.db_identifier}"
#   subnet_ids  = var.subnet_ids
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.db_identifier}-subnet-group"
#     }
#   )
  
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ==============================================================================
# # DB Parameter Group
# # ==============================================================================

# # Create parameter group for PostgreSQL configuration
# resource "aws_db_parameter_group" "main" {
#   name_prefix = "${local.db_identifier}-"
#   description = "Parameter group for ${local.db_identifier}"
#   family      = var.parameter_group_family
  
#   # Enable SSL connections
#   parameter {
#     name  = "rds.force_ssl"
#     value = "1"
#   }
  
#   # Set log settings
#   parameter {
#     name  = "log_connections"
#     value = "1"
#   }
  
#   parameter {
#     name  = "log_disconnections"
#     value = "1"
#   }
  
#   parameter {
#     name  = "log_duration"
#     value = "1"
#   }
  
#   # Set shared_preload_libraries for performance
#   parameter {
#     name  = "shared_preload_libraries"
#     value = "pg_stat_statements"
#   }
  
#   # Enable query performance insights
#   parameter {
#     name  = "pg_stat_statements.track"
#     value = "ALL"
#   }
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.db_identifier}-parameter-group"
#     }
#   )
  
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ==============================================================================
# # DB Option Group
# # ==============================================================================

# # Create option group for additional features
# resource "aws_db_option_group" "main" {
#   name_prefix          = "${local.db_identifier}-"
#   option_group_description = "Option group for ${local.db_identifier}"
#   engine_name          = "postgres"
#   major_engine_version = var.major_engine_version
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.db_identifier}-option-group"
#     }
#   )
  
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # ==============================================================================
# # KMS Key for Encryption
# # ==============================================================================

# # Create KMS key for RDS encryption (optional, can use default AWS key)
# resource "aws_kms_key" "rds" {
#   count = var.create_kms_key ? 1 : 0
  
#   description             = "KMS key for ${local.db_identifier} encryption"
#   deletion_window_in_days = 10
#   enable_key_rotation     = true
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.db_identifier}-kms-key"
#     }
#   )
# }

# resource "aws_kms_alias" "rds" {
#   count = var.create_kms_key ? 1 : 0
  
#   name          = "alias/${local.db_identifier}"
#   target_key_id = aws_kms_key.rds[0].key_id
# }

# # ==============================================================================
# # RDS Instance (Primary)
# # ==============================================================================

# # Create RDS PostgreSQL instance
# resource "aws_db_instance" "primary" {
#   # Instance configuration
#   identifier     = local.db_identifier
#   engine         = "postgres"
#   engine_version = var.engine_version
#   instance_class = var.instance_class
  
#   # Database configuration
#   db_name  = var.database_name
#   username = var.master_username
#   password = local.master_password
#   port     = 5432
  
#   # Storage configuration
#   allocated_storage     = var.allocated_storage
#   max_allocated_storage = var.max_allocated_storage
#   storage_type          = var.storage_type
#   storage_encrypted     = true
#   kms_key_id            = var.create_kms_key ? aws_kms_key.rds[0].arn : null
#   iops                  = var.storage_type == "io1" ? var.iops : null
  
#   # High availability
#   multi_az = var.multi_az
  
#   # Network configuration
#   db_subnet_group_name   = aws_db_subnet_group.main.name
#   vpc_security_group_ids = var.vpc_security_group_ids
#   publicly_accessible    = false
  
#   # Parameter and option groups
#   parameter_group_name = aws_db_parameter_group.main.name
#   option_group_name    = aws_db_option_group.main.name
  
#   # Backup configuration
#   backup_retention_period = var.backup_retention_period
#   backup_window           = var.backup_window
#   maintenance_window      = var.maintenance_window
#   copy_tags_to_snapshot   = true
#   skip_final_snapshot     = var.skip_final_snapshot
#   final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.db_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
#   # Monitoring configuration
#   enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
#   monitoring_interval             = var.monitoring_interval
#   monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
#   # Performance Insights
#   performance_insights_enabled    = var.performance_insights_enabled
#   performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
#   performance_insights_kms_key_id = var.performance_insights_enabled && var.create_kms_key ? aws_kms_key.rds[0].arn : null
  
#   # Auto minor version upgrade
#   auto_minor_version_upgrade = var.auto_minor_version_upgrade
  
#   # Deletion protection
#   deletion_protection = var.deletion_protection
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = local.db_identifier
#       Type = "Primary"
#     }
#   )
  
#   lifecycle {
#     ignore_changes = [
#       password,  # Managed by Secrets Manager rotation
#       final_snapshot_identifier
#     ]
#   }
  
#   depends_on = [aws_db_subnet_group.main]
# }

# # ==============================================================================
# # RDS Read Replicas
# # ==============================================================================

# # Create read replicas for read-heavy workloads
# resource "aws_db_instance" "replica" {
#   count = var.create_read_replicas ? var.read_replica_count : 0
  
#   # Replica configuration
#   identifier              = "${local.db_identifier}-replica-${count.index + 1}"
#   replicate_source_db     = aws_db_instance.primary.identifier
#   instance_class          = var.replica_instance_class != null ? var.replica_instance_class : var.instance_class
  
#   # Storage configuration (inherited from primary)
#   storage_encrypted = true
  
#   # Network configuration
#   availability_zone          = var.replica_availability_zones != null ? var.replica_availability_zones[count.index] : null
#   vpc_security_group_ids     = var.vpc_security_group_ids
#   publicly_accessible        = false
  
#   # Monitoring
#   monitoring_interval = var.monitoring_interval
#   monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
#   # Performance Insights
#   performance_insights_enabled    = var.performance_insights_enabled
#   performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  
#   # Auto minor version upgrade
#   auto_minor_version_upgrade = var.auto_minor_version_upgrade
  
#   # Deletion protection
#   deletion_protection = var.deletion_protection
  
#   # Skip final snapshot for replicas
#   skip_final_snapshot = true
  
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.db_identifier}-replica-${count.index + 1}"
#       Type = "ReadReplica"
#     }
#   )
# }

# # ==============================================================================
# # IAM Role for Enhanced Monitoring
# # ==============================================================================

# # Create IAM role for RDS enhanced monitoring
# resource "aws_iam_role" "rds_monitoring" {
#   count = var.monitoring_interval > 0 ? 1 : 0
  
#   name_prefix = "${local.db_identifier}-monitoring-"
  
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "monitoring.rds.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
  
#   tags = local.common_tags
# }

# # Attach AWS managed policy for RDS enhanced monitoring
# resource "aws_iam_role_policy_attachment" "rds_monitoring" {
#   count = var.monitoring_interval > 0 ? 1 : 0
  
#   role       = aws_iam_role.rds_monitoring[0].name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
# }

# # ==============================================================================
# # CloudWatch Alarms
# # ==============================================================================

# # CPU utilization alarm
# resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
#   count = var.create_cloudwatch_alarms ? 1 : 0
  
#   alarm_name          = "${local.db_identifier}-cpu-utilization"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "2"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/RDS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = var.cpu_alarm_threshold
#   alarm_description   = "This metric monitors RDS CPU utilization"
#   alarm_actions       = var.alarm_actions
  
#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.primary.id
#   }
  
#   tags = local.common_tags
# }

# # Free storage space alarm
# resource "aws_cloudwatch_metric_alarm" "free_storage_space" {
#   count = var.create_cloudwatch_alarms ? 1 : 0
  
#   alarm_name          = "${local.db_identifier}-free-storage-space"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "FreeStorageSpace"
#   namespace           = "AWS/RDS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = var.free_storage_space_threshold
#   alarm_description   = "This metric monitors RDS free storage space"
#   alarm_actions       = var.alarm_actions
  
#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.primary.id
#   }
  
#   tags = local.common_tags
# }

# # Database connections alarm
# resource "aws_cloudwatch_metric_alarm" "database_connections" {
#   count = var.create_cloudwatch_alarms ? 1 : 0
  
#   alarm_name          = "${local.db_identifier}-database-connections"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "2"
#   metric_name         = "DatabaseConnections"
#   namespace           = "AWS/RDS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = var.database_connections_threshold
#   alarm_description   = "This metric monitors RDS database connections"
#   alarm_actions       = var.alarm_actions
  
#   dimensions = {
#     DBInstanceIdentifier = aws_db_instance.primary.id
#   }
  
#   tags = local.common_tags
# }

