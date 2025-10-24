# ==============================================================================
# RDS Module - PostgreSQL Databases
# ==============================================================================
# This module creates RDS PostgreSQL instances for microservices:
# - Auth Database (Authentication & User Management)
# - Event Database (Event CRUD operations)
# - Booking Database (Booking Management)
# - Payment Database (Payment Processing)
#
# Features:
# - Multi-AZ deployment (prod) / Single-AZ (dev)
# - Read replicas (prod only)
# - Automated backups with cross-region copy
# - Encryption at rest and in transit
# - Enhanced monitoring and Performance Insights
# - Auto-scaling storage
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # Database configurations
  # COST OPTIMIZATION: Commented out databases for services not yet deployed
  # To re-enable: Uncomment the database blocks below and run terraform apply
  databases = {
    auth = {
      instance_class       = var.auth_db_instance_class
      allocated_storage    = var.auth_db_allocated_storage
      max_allocated_storage = var.auth_db_max_allocated_storage
      read_replica_count   = var.create_read_replicas ? 2 : 0
      port                 = 5432
    }
    # TEMPORARILY DISABLED: Event database not needed yet
    # Uncomment when event service is ready to deploy
    # event = {
    #   instance_class        = var.event_db_instance_class
    #   allocated_storage     = var.event_db_allocated_storage
    #   max_allocated_storage = var.event_db_max_allocated_storage
    #   read_replica_count    = var.create_read_replicas ? 2 : 0
    #   port                  = 5432
    # }
    # TEMPORARILY DISABLED: Booking database not needed yet
    # Uncomment when booking service is ready to deploy
    # booking = {
    #   instance_class        = var.booking_db_instance_class
    #   allocated_storage     = var.booking_db_allocated_storage
    #   max_allocated_storage = var.booking_db_max_allocated_storage
    #   read_replica_count    = var.create_read_replicas ? 2 : 0
    #   port                  = 5432
    # }
    # TEMPORARILY DISABLED: Payment database not needed yet
    # Uncomment when payment service is ready to deploy
    # payment = {
    #   instance_class        = var.payment_db_instance_class
    #   allocated_storage     = var.payment_db_allocated_storage
    #   max_allocated_storage = var.payment_db_max_allocated_storage
    #   read_replica_count    = var.create_read_replicas ? 2 : 0
    #   port                  = 5432
    # }
  }

  common_tags = merge(
    var.tags,
    {
      Module      = "rds"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# DB Subnet Group
# ==============================================================================

# Subnet group for RDS instances
resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-"
  description = "Subnet group for ${var.project_name} ${var.environment} RDS instances"
  subnet_ids  = var.subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-subnet-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# DB Parameter Group
# ==============================================================================

# Parameter group for PostgreSQL
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${var.project_name}-${var.environment}-postgres-"
  family      = var.postgres_family
  description = "Custom parameter group for ${var.project_name} ${var.environment}"

  # Query logging (disable in prod for performance)
  parameter {
    name  = "log_statement"
    value = var.environment == "prod" ? "none" : "all"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = var.environment == "prod" ? "5000" : "1000"
    apply_method = "immediate"
  }

  # SSL enforcement
  parameter {
    name  = "rds.force_ssl"
    value = "1"
    apply_method = "pending-reboot"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Secrets Manager - Database Credentials
# ==============================================================================

# Generate random passwords for databases
resource "random_password" "db_passwords" {
  for_each = local.databases

  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  for_each = local.databases

  name_prefix             = "${var.project_name}/${var.environment}/${each.key}-db-"
  description             = "Database credentials for ${each.key} service"
  recovery_window_in_days = var.secret_recovery_window_days
  kms_key_id              = var.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.key}-db-secret"
      Service = each.key
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Store credentials in secrets
resource "aws_secretsmanager_secret_version" "db_credentials" {
  for_each = local.databases

  secret_id = aws_secretsmanager_secret.db_credentials[each.key].id

  secret_string = jsonencode({
    username = var.master_username
    password = random_password.db_passwords[each.key].result
    engine   = "postgres"
    host     = aws_db_instance.primary[each.key].address
    port     = each.value.port
    dbname   = "${each.key}db"
    url      = "jdbc:postgresql://${aws_db_instance.primary[each.key].address}:${each.value.port}/${each.key}db"
  })
}

# ==============================================================================
# RDS Primary Instances
# ==============================================================================

# Primary RDS instances for each database
resource "aws_db_instance" "primary" {
  for_each = local.databases

  identifier     = "${var.project_name}-${var.environment}-${each.key}-db"
  engine         = "postgres"
  engine_version = var.postgres_version

  # Instance configuration
  instance_class    = each.value.instance_class
  allocated_storage = each.value.allocated_storage
  storage_type      = var.storage_type
  iops              = var.storage_type == "io1" ? var.provisioned_iops : null

  # Storage auto-scaling
  max_allocated_storage = each.value.max_allocated_storage

  # Database configuration
  db_name  = "${each.key}db"
  username = var.master_username
  password = random_password.db_passwords[each.key].result
  port     = each.value.port

  # Enable IAM authentication for enhanced security
  iam_database_authentication_enabled = true

  # High availability
  multi_az = var.multi_az

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Backup configuration
  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-${each.key}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Enable automated backups
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Monitoring
  monitoring_interval             = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn             = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_arn : null
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Apply changes immediately or during maintenance window
  apply_immediately = var.apply_immediately

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-${each.key}-db"
      Service  = each.key
      Role     = "primary"
    }
  )

  lifecycle {
    ignore_changes = [
      password,  # Password managed by Secrets Manager rotation
      final_snapshot_identifier
    ]
  }
}

# ==============================================================================
# RDS Read Replicas (Production Only)
# ==============================================================================

# Read replica 1 (Same AZ as primary)
resource "aws_db_instance" "read_replica_1" {
  for_each = var.create_read_replicas ? local.databases : {}

  identifier              = "${var.project_name}-${var.environment}-${each.key}-replica-1"
  replicate_source_db     = aws_db_instance.primary[each.key].identifier
  instance_class          = each.value.instance_class
  publicly_accessible     = false
  skip_final_snapshot     = true
  vpc_security_group_ids  = [var.security_group_id]
  
  # Use same AZ as primary for low-latency reads
  availability_zone = aws_db_instance.primary[each.key].availability_zone

  # Encryption (inherited from primary)
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Monitoring
  monitoring_interval             = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn             = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_arn : null

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-${each.key}-replica-1"
      Service  = each.key
      Role     = "read_replica"
      ReplicaNumber = "1"
    }
  )
}

# Read replica 2 (Different AZ for high availability)
resource "aws_db_instance" "read_replica_2" {
  for_each = var.create_read_replicas ? local.databases : {}

  identifier              = "${var.project_name}-${var.environment}-${each.key}-replica-2"
  replicate_source_db     = aws_db_instance.primary[each.key].identifier
  instance_class          = each.value.instance_class
  publicly_accessible     = false
  skip_final_snapshot     = true
  vpc_security_group_ids  = [var.security_group_id]
  
  # Place in different AZ for cross-AZ redundancy
  multi_az = false  # Read replicas don't support Multi-AZ

  # Encryption (inherited from primary)
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Monitoring
  monitoring_interval             = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn             = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_arn : null

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-${each.key}-replica-2"
      Service  = each.key
      Role     = "read_replica"
      ReplicaNumber = "2"
    }
  )
}

# ==============================================================================
# IAM Role for Enhanced Monitoring
# ==============================================================================

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Attach AWS managed policy for enhanced monitoring
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

# CPU utilization alarm for primary instances
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each = local.databases

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "CPU utilization is too high for ${each.key} database"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary[each.key].identifier
  }

  tags = local.common_tags
}

# Free storage space alarm
resource "aws_cloudwatch_metric_alarm" "storage_low" {
  for_each = local.databases

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-db-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.storage_alarm_threshold_bytes
  alarm_description   = "Free storage space is low for ${each.key} database"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary[each.key].identifier
  }

  tags = local.common_tags
}

# Database connections alarm
resource "aws_cloudwatch_metric_alarm" "connections_high" {
  for_each = local.databases

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-db-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.connections_alarm_threshold
  alarm_description   = "Database connections are too high for ${each.key} database"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary[each.key].identifier
  }

  tags = local.common_tags
}

