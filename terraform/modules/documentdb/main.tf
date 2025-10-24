# ==============================================================================
# DocumentDB Module - MongoDB-Compatible Audit Logs Database
# ==============================================================================
# This module creates a DocumentDB cluster for storing audit logs with:
# - Single instance (dev) or cluster with replicas (prod)
# - Automated backups and point-in-time recovery
# - Encryption at rest and in transit
# - CloudWatch monitoring
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
  common_tags = merge(
    var.tags,
    {
      Module      = "documentdb"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# DB Subnet Group
# ==============================================================================

resource "aws_docdb_subnet_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-docdb-"
  description = "Subnet group for ${var.project_name} ${var.environment} DocumentDB"
  subnet_ids  = var.subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-docdb-subnet-group"
    }
  )
}

# ==============================================================================
# Cluster Parameter Group
# ==============================================================================

resource "aws_docdb_cluster_parameter_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-docdb-"
  family      = var.docdb_family
  description = "Custom parameter group for ${var.project_name} ${var.environment} DocumentDB"

  # TLS enforcement
  parameter {
    name  = "tls"
    value = var.tls_enabled ? "enabled" : "disabled"
  }

  # Audit logs
  parameter {
    name  = "audit_logs"
    value = var.audit_logs_enabled ? "enabled" : "disabled"
  }

  # TTL monitor (for automatic data expiration)
  parameter {
    name  = "ttl_monitor"
    value = var.ttl_monitor_enabled ? "enabled" : "disabled"
  }

  # Profiler
  parameter {
    name  = "profiler"
    value = var.profiler_enabled ? "enabled" : "disabled"
  }

  parameter {
    name  = "profiler_threshold_ms"
    value = var.profiler_threshold_ms
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Secrets Manager - Database Credentials
# ==============================================================================

# Generate random password
resource "random_password" "master_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store credentials in Secrets Manager
resource "aws_secretsmanager_secret" "docdb_credentials" {
  name_prefix             = "${var.project_name}/${var.environment}/documentdb-"
  description             = "DocumentDB master credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.secret_recovery_window_days
  kms_key_id              = var.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-documentdb-secret"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Store credentials
resource "aws_secretsmanager_secret_version" "docdb_credentials" {
  secret_id = aws_secretsmanager_secret.docdb_credentials.id

  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master_password.result
    engine   = "docdb"
    host     = aws_docdb_cluster.main.endpoint
    port     = aws_docdb_cluster.main.port
    dbname   = "audit_logs"
  })
}

# ==============================================================================
# DocumentDB Cluster
# ==============================================================================

resource "aws_docdb_cluster" "main" {
  cluster_identifier     = "${var.project_name}-${var.environment}-docdb"
  engine                 = "docdb"
  engine_version         = var.engine_version
  master_username        = var.master_username
  master_password        = random_password.master_password.result
  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  port                   = var.port

  # Backup configuration
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-docdb-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # CloudWatch Logs
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Cluster parameter group
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Apply changes immediately or during maintenance window
  apply_immediately = var.apply_immediately

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-docdb-cluster"
    }
  )

  lifecycle {
    ignore_changes = [
      master_password,
      final_snapshot_identifier
    ]
  }
}

# ==============================================================================
# DocumentDB Cluster Instances
# ==============================================================================

# Primary instance
resource "aws_docdb_cluster_instance" "primary" {
  identifier         = "${var.project_name}-${var.environment}-docdb-primary"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Apply changes immediately
  apply_immediately = var.apply_immediately

  # Performance Insights
  enable_performance_insights     = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_arn : null

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-docdb-primary"
      Role = "primary"
    }
  )
}

# Read replicas (production only)
resource "aws_docdb_cluster_instance" "replicas" {
  count = var.replica_count

  identifier         = "${var.project_name}-${var.environment}-docdb-replica-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Apply changes immediately
  apply_immediately = var.apply_immediately

  # Performance Insights
  enable_performance_insights     = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_arn : null

  tags = merge(
    local.common_tags,
    {
      Name          = "${var.project_name}-${var.environment}-docdb-replica-${count.index + 1}"
      Role          = "replica"
      ReplicaNumber = count.index + 1
    }
  )
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

# CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-docdb-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "DocumentDB CPU utilization is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.main.id
  }

  tags = local.common_tags
}

# Database connections alarm
resource "aws_cloudwatch_metric_alarm" "connections_high" {
  alarm_name          = "${var.project_name}-${var.environment}-docdb-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/DocDB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.connections_alarm_threshold
  alarm_description   = "DocumentDB connections are too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.main.id
  }

  tags = local.common_tags
}

# Storage space alarm
resource "aws_cloudwatch_metric_alarm" "storage_low" {
  alarm_name          = "${var.project_name}-${var.environment}-docdb-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "VolumeBytesUsed"
  namespace           = "AWS/DocDB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.storage_alarm_threshold_bytes
  alarm_description   = "DocumentDB storage is low"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.main.id
  }

  tags = local.common_tags
}

#######

