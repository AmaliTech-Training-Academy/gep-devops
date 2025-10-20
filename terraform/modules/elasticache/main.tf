# ==============================================================================
# ElastiCache Module - Redis Cluster
# ==============================================================================
# This module creates an ElastiCache Redis cluster for caching with:
# - Single node (dev) or cluster mode (prod)
# - Encryption at rest and in transit
# - Automated backups
# - Multi-AZ with automatic failover (prod)
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
      Module      = "elasticache"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# Subnet Group
# ==============================================================================

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-redis-subnet-group"
  description = "Subnet group for ${var.project_name} ${var.environment} ElastiCache"
  subnet_ids  = var.subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-subnet-group"
    }
  )
}

# ==============================================================================
# Parameter Group
# ==============================================================================

resource "aws_elasticache_parameter_group" "main" {
  name        = "${var.project_name}-${var.environment}-redis-params"
  family      = var.redis_family
  description = "Custom parameter group for ${var.project_name} ${var.environment}"

  # Memory management
  parameter {
    name  = "maxmemory-policy"
    value = var.maxmemory_policy
  }

  # Timeout settings
  parameter {
    name  = "timeout"
    value = var.timeout
  }

  # Append only file
  parameter {
    name  = "appendonly"
    value = var.appendonly ? "yes" : "no"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Replication Group (Cluster Mode Disabled) - Development/Single Node
# ==============================================================================

resource "aws_elasticache_replication_group" "single_node" {
  count = var.cluster_mode_enabled ? 0 : 1

  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Redis cluster for ${var.project_name} ${var.environment}"
  
  engine               = "redis"
  engine_version       = var.redis_version
  port                 = var.redis_port
  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = var.security_group_ids

  # Node configuration
  node_type          = var.node_type
  num_cache_clusters = var.num_cache_nodes
  
  # Multi-AZ (only valid when cluster mode is disabled)
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled          = var.multi_az_enabled

  # Maintenance
  maintenance_window         = var.maintenance_window
  snapshot_window           = var.snapshot_window
  snapshot_retention_limit  = var.snapshot_retention_limit
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately         = var.apply_immediately

  # Security
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                = var.transit_encryption_enabled ? var.auth_token : null

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # Logging - Dynamic blocks to handle optional log destinations
  dynamic "log_delivery_configuration" {
    for_each = var.slow_log_destination != null ? [1] : []
    content {
      destination      = var.slow_log_destination
      destination_type = var.slow_log_destination_type
      log_format       = var.log_format
      log_type         = "slow-log"
    }
  }

  dynamic "log_delivery_configuration" {
    for_each = var.engine_log_destination != null ? [1] : []
    content {
      destination      = var.engine_log_destination
      destination_type = var.engine_log_destination_type
      log_format       = var.log_format
      log_type         = "engine-log"
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-redis"
    }
  )
}

# ==============================================================================
# Replication Group (Cluster Mode Enabled) - Production
# ==============================================================================

resource "aws_elasticache_replication_group" "cluster_mode" {
  count = var.cluster_mode_enabled ? 1 : 0

  replication_group_id          = "${var.project_name}-${var.environment}-redis"
  description                   = "Redis cluster for ${var.project_name} ${var.environment}"
  
  engine               = "redis"
  engine_version       = var.redis_version
  port                 = var.redis_port
  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = var.security_group_ids

  # Node configuration
  node_type = var.node_type

  # Cluster mode configuration
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  # Automatic failover (multi-AZ is implicit with cluster mode and replicas)
  automatic_failover_enabled = true

  # Maintenance
  maintenance_window         = var.maintenance_window
  snapshot_window           = var.snapshot_window
  snapshot_retention_limit  = var.snapshot_retention_limit
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately         = var.apply_immediately

  # Security
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                = var.transit_encryption_enabled ? var.auth_token : null

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # Logging - Dynamic blocks to handle optional log destinations
  dynamic "log_delivery_configuration" {
    for_each = var.slow_log_destination != null ? [1] : []
    content {
      destination      = var.slow_log_destination
      destination_type = var.slow_log_destination_type
      log_format       = var.log_format
      log_type         = "slow-log"
    }
  }

  dynamic "log_delivery_configuration" {
    for_each = var.engine_log_destination != null ? [1] : []
    content {
      destination      = var.engine_log_destination
      destination_type = var.engine_log_destination_type
      log_format       = var.log_format
      log_type         = "engine-log"
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-cluster"
    }
  )
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_utilization_threshold
  alarm_description   = "This metric monitors ElastiCache CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = var.cluster_mode_enabled ? null : try(aws_elasticache_replication_group.single_node[0].id, "")
    ReplicationGroupId = var.cluster_mode_enabled ? try(aws_elasticache_replication_group.cluster_mode[0].id, "") : null
  }

  tags = local.common_tags
}

# Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "database_memory_usage" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-redis-memory-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_utilization_threshold
  alarm_description   = "This metric monitors ElastiCache memory utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = var.cluster_mode_enabled ? null : try(aws_elasticache_replication_group.single_node[0].id, "")
    ReplicationGroupId = var.cluster_mode_enabled ? try(aws_elasticache_replication_group.cluster_mode[0].id, "") : null
  }

  tags = local.common_tags
}

# Evictions Alarm
resource "aws_cloudwatch_metric_alarm" "evictions" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-redis-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.evictions_threshold
  alarm_description   = "This metric monitors ElastiCache evictions"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = var.cluster_mode_enabled ? null : try(aws_elasticache_replication_group.single_node[0].id, "")
    ReplicationGroupId = var.cluster_mode_enabled ? try(aws_elasticache_replication_group.cluster_mode[0].id, "") : null
  }

  tags = local.common_tags
}

# Swap Usage Alarm
resource "aws_cloudwatch_metric_alarm" "swap_usage" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-redis-swap-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SwapUsage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.swap_usage_threshold
  alarm_description   = "This metric monitors ElastiCache swap usage"
  alarm_actions       = var.alarm_actions

  dimensions = {
    CacheClusterId = var.cluster_mode_enabled ? null : try(aws_elasticache_replication_group.single_node[0].id, "")
    ReplicationGroupId = var.cluster_mode_enabled ? try(aws_elasticache_replication_group.cluster_mode[0].id, "") : null
  }

  tags = local.common_tags
}