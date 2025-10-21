# terraform/modules/cloudwatch/main.tf
# ==============================================================================
# CloudWatch Module - Monitoring, Logging, and Alerting
# ==============================================================================

# terraform/modules/cloudwatch/main.tf
# ==============================================================================
# CloudWatch Module - Monitoring, Logging, and Alerting
# ==============================================================================

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-${var.environment}-alerts"
  display_name      = "${var.project_name} ${var.environment} Alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-alerts"
      Environment = var.environment
    }
  )
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email_alerts" {
  for_each = toset(var.alert_email_addresses)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "AllowLambdaToPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # ECS Cluster Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", period = 300 }],
            [".", "MemoryUtilization", { stat = "Average", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Cluster Utilization"
          period  = 300
        }
      },
      # ALB Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average", period = 300 }],
            [".", "RequestCount", { stat = "Sum", period = 300 }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum", period = 300 }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Load Balancer"
          period  = 300
        }
      },
      # RDS Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average", period = 300 }],
            [".", "DatabaseConnections", { stat = "Average", period = 300 }],
            [".", "FreeableMemory", { stat = "Average", period = 300 }],
            [".", "ReadLatency", { stat = "Average", period = 300 }],
            [".", "WriteLatency", { stat = "Average", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Database"
          period  = 300
        }
      },
      # ElastiCache Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", { stat = "Average", period = 300 }],
            [".", "DatabaseMemoryUsagePercentage", { stat = "Average", period = 300 }],
            [".", "CurrConnections", { stat = "Average", period = 300 }],
            [".", "Evictions", { stat = "Sum", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ElastiCache Redis"
          period  = 300
        }
      },
      # CloudFront Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", { stat = "Sum", period = 300 }],
            [".", "BytesDownloaded", { stat = "Sum", period = 300 }],
            [".", "4xxErrorRate", { stat = "Average", period = 300 }],
            [".", "5xxErrorRate", { stat = "Average", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "eu-west-1"
          title   = "CloudFront CDN"
          period  = 300
        }
      }
    ]
  })
}

# ============================================================================
# CloudWatch Alarms - ECS
# ============================================================================

# FIX: Only create alarms if ECS cluster name is provided
# ECS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  count = var.ecs_cluster_name != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.ecs_cpu_threshold
  alarm_description   = "ECS cluster CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  tags = var.common_tags
}

# ECS Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  count = var.ecs_cluster_name != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.ecs_memory_threshold
  alarm_description   = "ECS cluster memory utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  tags = var.common_tags
}

# ============================================================================
# CloudWatch Alarms - ALB
# ============================================================================

# ALB 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.alb_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_description   = "ALB 5XX error rate is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.common_tags
}

# ALB Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  count = var.alb_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alb_response_time_threshold
  alarm_description   = "ALB response time is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.common_tags
}

# ALB Unhealthy Target Alarm
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count = var.alb_arn != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "ALB has unhealthy targets"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.common_tags
}

# ============================================================================
# CloudWatch Alarms - RDS
# ============================================================================

# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.common_tags
}

# RDS Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  count = var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.rds_storage_threshold_bytes
  alarm_description   = "RDS free storage space is low"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.common_tags
}

# RDS Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count = var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.rds_connections_threshold
  alarm_description   = "RDS database connections are too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.common_tags
}

# ============================================================================
# CloudWatch Alarms - ElastiCache
# ============================================================================

# ElastiCache CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_high" {
  count = var.elasticache_cluster_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.elasticache_cpu_threshold
  alarm_description   = "ElastiCache CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = var.elasticache_cluster_id
  }

  tags = var.common_tags
}

# ElastiCache Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "elasticache_memory_high" {
  count = var.elasticache_cluster_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = var.elasticache_memory_threshold
  alarm_description   = "ElastiCache memory utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = var.elasticache_cluster_id
  }

  tags = var.common_tags
}

# ElastiCache Evictions Alarm
resource "aws_cloudwatch_metric_alarm" "elasticache_evictions" {
  count = var.elasticache_cluster_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.elasticache_evictions_threshold
  alarm_description   = "ElastiCache evictions are too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = var.elasticache_cluster_id
  }

  tags = var.common_tags
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

# Application Logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

# Lambda Logs
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}



