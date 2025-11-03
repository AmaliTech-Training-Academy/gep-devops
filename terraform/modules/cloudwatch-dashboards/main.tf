# ==============================================================================
# CloudWatch Service Dashboards Module
# ==============================================================================
# Professional, customized dashboards for each microservice
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
# Auth Service Dashboard
# ==============================================================================

resource "aws_cloudwatch_dashboard" "auth_service" {
  dashboard_name = "${var.project_name}-${var.environment}-auth-service"

  dashboard_body = jsonencode({
    widgets = [
      # Header
      {
        type = "text"
        properties = {
          markdown = "# 🔐 Auth Service Dashboard\n## Real-time monitoring for authentication and user management\n**Environment:** ${upper(var.environment)} | **Region:** ${var.aws_region}"
        }
        x      = 0
        y      = 0
        width  = 24
        height = 2
      },

      # Service Health Overview
      {
        type = "metric"
        properties = {
          title = "📊 Service Health - Task Count"
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ServiceName", "auth-service", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Running Tasks" }]
          ]
          view   = "singleValue"
          region = var.aws_region
          period = 300
        }
        x      = 0
        y      = 2
        width  = 6
        height = 4
      },

      # CPU Utilization
      {
        type = "metric"
        properties = {
          title = "💻 CPU Utilization"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "auth-service", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Average CPU" }],
            ["...", { stat = "Maximum", label = "Max CPU" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
          annotations = {
            horizontal = [
              {
                value = 80
                label = "High CPU Threshold"
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
        x      = 6
        y      = 2
        width  = 9
        height = 6
      },

      # Memory Utilization
      {
        type = "metric"
        properties = {
          title = "🧠 Memory Utilization"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "auth-service", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Average Memory" }],
            ["...", { stat = "Maximum", label = "Max Memory" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
          annotations = {
            horizontal = [
              {
                value = 80
                label = "High Memory Threshold"
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
        x      = 15
        y      = 2
        width  = 9
        height = 6
      },

      # Request Count
      {
        type = "metric"
        properties = {
          title = "📈 Request Volume"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "TargetGroup", var.auth_target_group_arn_suffix, { stat = "Sum", label = "Total Requests" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
        }
        x      = 0
        y      = 8
        width  = 8
        height = 6
      },

      # Response Time
      {
        type = "metric"
        properties = {
          title = "⏱️ Response Time"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", var.auth_target_group_arn_suffix, { stat = "Average", label = "Avg Response Time" }],
            ["...", { stat = "p99", label = "P99 Response Time" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
          yAxis = {
            left = {
              label = "Seconds"
            }
          }
          annotations = {
            horizontal = [
              {
                value = 2
                label = "SLA Threshold (2s)"
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
        x      = 8
        y      = 8
        width  = 8
        height = 6
      },

      # HTTP Status Codes
      {
        type = "metric"
        properties = {
          title = "🚦 HTTP Status Codes"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "TargetGroup", var.auth_target_group_arn_suffix, { stat = "Sum", label = "2XX Success" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4XX Client Error" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5XX Server Error" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.aws_region
          period  = 60
        }
        x      = 16
        y      = 8
        width  = 8
        height = 6
      },

      # Database Section Header
      {
        type = "text"
        properties = {
          markdown = "## 🗄️ Database Performance (Auth DB)"
        }
        x      = 0
        y      = 14
        width  = 24
        height = 1
      },

      # Database CPU
      {
        type = "metric"
        properties = {
          title = "💾 Database CPU"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.auth_db_instance_id, { stat = "Average", label = "DB CPU Usage" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        x      = 0
        y      = 15
        width  = 8
        height = 5
      },

      # Database Connections
      {
        type = "metric"
        properties = {
          title = "🔌 Database Connections"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.auth_db_instance_id, { stat = "Average", label = "Active Connections" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
        }
        x      = 8
        y      = 15
        width  = 8
        height = 5
      },

      # Database Read/Write Latency
      {
        type = "metric"
        properties = {
          title = "⚡ Database Latency"
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", var.auth_db_instance_id, { stat = "Average", label = "Read Latency" }],
            [".", "WriteLatency", ".", ".", { stat = "Average", label = "Write Latency" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          yAxis = {
            left = {
              label = "Seconds"
            }
          }
        }
        x      = 16
        y      = 15
        width  = 8
        height = 5
      },

      # Cache Section Header
      {
        type = "text"
        properties = {
          markdown = "## ⚡ Redis Cache Performance"
        }
        x      = 0
        y      = 20
        width  = 24
        height = 1
      },

      # Redis CPU
      {
        type = "metric"
        properties = {
          title = "🔴 Redis CPU"
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", var.elasticache_cluster_id, { stat = "Average", label = "Cache CPU" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
        }
        x      = 0
        y      = 21
        width  = 8
        height = 5
      },

      # Redis Memory
      {
        type = "metric"
        properties = {
          title = "💾 Redis Memory Usage"
          metrics = [
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", var.elasticache_cluster_id, { stat = "Average", label = "Memory Usage %" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        x      = 8
        y      = 21
        width  = 8
        height = 5
      },

      # Redis Connections & Evictions
      {
        type = "metric"
        properties = {
          title = "🔗 Redis Connections & Evictions"
          metrics = [
            ["AWS/ElastiCache", "CurrConnections", "CacheClusterId", var.elasticache_cluster_id, { stat = "Average", label = "Connections", yAxis = "left" }],
            [".", "Evictions", ".", ".", { stat = "Sum", label = "Evictions", yAxis = "right" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
        }
        x      = 16
        y      = 21
        width  = 8
        height = 5
      },

      # SQS Section Header
      {
        type = "text"
        properties = {
          markdown = "## 📬 Message Queue Metrics"
        }
        x      = 0
        y      = 26
        width  = 24
        height = 1
      },

      # SQS Messages
      {
        type = "metric"
        properties = {
          title = "📨 Auth Service Queues"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.project_name}-${var.environment}-user-registration-queue", { stat = "Average", label = "User Registration", color = "#1f77b4" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-user-login-queue", { stat = "Average", label = "User Login", color = "#2ca02c" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-password-reset-queue", { stat = "Average", label = "Password Reset", color = "#ff7f0e" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
        }
        x      = 0
        y      = 27
        width  = 12
        height = 5
      },

      # SQS Message Age
      {
        type = "metric"
        properties = {
          title = "⏳ Message Age (Oldest)"
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", "${var.project_name}-${var.environment}-user-registration-queue", { stat = "Maximum", label = "Registration", color = "#1f77b4" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-user-login-queue", { stat = "Maximum", label = "Login", color = "#2ca02c" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-password-reset-queue", { stat = "Maximum", label = "Password Reset", color = "#ff7f0e" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          yAxis = {
            left = {
              label = "Seconds"
            }
          }
        }
        x      = 12
        y      = 27
        width  = 12
        height = 5
      },

      # Logs Section
      {
        type = "log"
        properties = {
          title  = "📋 Recent Error Logs"
          region = var.aws_region
          query  = <<-EOQ
            SOURCE '/ecs/${var.project_name}/${var.environment}/auth-service'
            | fields @timestamp, @message
            | filter @message like /ERROR/
            | sort @timestamp desc
            | limit 20
          EOQ
        }
        x      = 0
        y      = 32
        width  = 24
        height = 6
      }
    ]
  })
}

# ==============================================================================
# Notification Service Dashboard
# ==============================================================================

resource "aws_cloudwatch_dashboard" "notification_service" {
  dashboard_name = "${var.project_name}-${var.environment}-notification-service"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text"
        properties = {
          markdown = "# 📧 Notification Service Dashboard\n## Email, SMS, and OTP delivery monitoring\n**Environment:** ${upper(var.environment)} | **Region:** ${var.aws_region}"
        }
        x      = 0
        y      = 0
        width  = 24
        height = 2
      },
      {
        type = "metric"
        properties = {
          title   = "📊 Service Health"
          metrics = [["AWS/ECS", "RunningTaskCount", "ServiceName", "notification-service", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Running Tasks" }]]
          view    = "singleValue"
          region  = var.aws_region
          period  = 300
        }
        x      = 0
        y      = 2
        width  = 6
        height = 4
      },
      {
        type = "metric"
        properties = {
          title = "💻 CPU Utilization"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "notification-service", "ClusterName", var.ecs_cluster_name, { stat = "Average", color = "#1f77b4" }],
            ["...", { stat = "Maximum", color = "#ff7f0e" }]
          ]
          view        = "timeSeries"
          region      = var.aws_region
          period      = 300
          yAxis       = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ value = 80, label = "Threshold", fill = "above", color = "#d62728" }] }
        }
        x      = 6
        y      = 2
        width  = 9
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "🧠 Memory Utilization"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "notification-service", "ClusterName", var.ecs_cluster_name, { stat = "Average", color = "#2ca02c" }],
            ["...", { stat = "Maximum", color = "#d62728" }]
          ]
          view        = "timeSeries"
          region      = var.aws_region
          period      = 300
          yAxis       = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ value = 80, label = "Threshold", fill = "above", color = "#d62728" }] }
        }
        x      = 15
        y      = 2
        width  = 9
        height = 6
      },
      {
        type       = "text"
        properties = { markdown = "## 📬 Message Queue Performance" }
        x          = 0
        y          = 8
        width      = 24
        height     = 1
      },
      {
        type = "metric"
        properties = {
          title = "📨 Notifications Queue Messages"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.project_name}-${var.environment}-notifications-queue", { stat = "Average", label = "Visible", color = "#1f77b4" }],
            [".", "ApproximateNumberOfMessagesNotVisible", ".", ".", { stat = "Average", label = "In Flight", color = "#ff7f0e" }],
            [".", "NumberOfMessagesSent", ".", ".", { stat = "Sum", label = "Sent", color = "#2ca02c" }],
            [".", "NumberOfMessagesReceived", ".", ".", { stat = "Sum", label = "Received", color = "#9467bd" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          period = 60
        }
        x      = 0
        y      = 9
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "⏳ Message Processing Time"
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", "${var.project_name}-${var.environment}-notifications-queue", { stat = "Maximum", label = "Oldest Message Age", color = "#d62728" }]
          ]
          view        = "timeSeries"
          region      = var.aws_region
          period      = 60
          yAxis       = { left = { label = "Seconds" } }
          annotations = { horizontal = [{ value = 300, label = "5 min threshold", fill = "above", color = "#d62728" }] }
        }
        x      = 12
        y      = 9
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "🚨 Dead Letter Queue"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.project_name}-${var.environment}-notifications-queue-dlq", { stat = "Sum", label = "Failed Messages", color = "#d62728" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          period = 300
        }
        x      = 0
        y      = 15
        width  = 12
        height = 5
      },
      {
        type = "metric"
        properties = {
          title = "📊 Queue Throughput"
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", "${var.project_name}-${var.environment}-notifications-queue", { stat = "Sum", label = "Sent", color = "#2ca02c" }],
            [".", "NumberOfMessagesDeleted", ".", ".", { stat = "Sum", label = "Processed", color = "#1f77b4" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          period = 60
        }
        x      = 12
        y      = 15
        width  = 12
        height = 5
      },
      {
        type       = "text"
        properties = { markdown = "## 📧 Email Delivery Metrics (SES)" }
        x          = 0
        y          = 20
        width      = 24
        height     = 1
      },
      {
        type = "metric"
        properties = {
          title = "✉️ Email Send Statistics"
          metrics = [
            ["AWS/SES", "Send", { stat = "Sum", label = "Total Sent", color = "#2ca02c" }],
            [".", "Delivery", { stat = "Sum", label = "Delivered", color = "#1f77b4" }],
            [".", "Bounce", { stat = "Sum", label = "Bounced", color = "#ff7f0e" }],
            [".", "Complaint", { stat = "Sum", label = "Complaints", color = "#d62728" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          period = 300
        }
        x      = 0
        y      = 21
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "📈 Email Delivery Rate"
          metrics = [
            [{ expression = "(m2/m1)*100", label = "Delivery Rate %", color = "#2ca02c" }],
            ["AWS/SES", "Send", { id = "m1", visible = false }],
            [".", "Delivery", { id = "m2", visible = false }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          period = 300
          yAxis  = { left = { min = 0, max = 100 } }
        }
        x      = 12
        y      = 21
        width  = 12
        height = 6
      },
      {
        type = "log"
        properties = {
          title  = "📋 Recent Notification Logs"
          region = var.aws_region
          query  = <<-EOQ
            SOURCE '/ecs/${var.project_name}/${var.environment}/notification-service'
            | fields @timestamp, @message
            | filter @message like /ERROR/ or @message like /OTP/ or @message like /email/
            | sort @timestamp desc
            | limit 20
          EOQ
        }
        x      = 0
        y      = 27
        width  = 24
        height = 6
      }
    ]
  })
}

# ==============================================================================
# Frontend Dashboard (CloudFront + S3)
# ==============================================================================

resource "aws_cloudwatch_dashboard" "frontend" {
  dashboard_name = "${var.project_name}-${var.environment}-frontend"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text"
        properties = {
          markdown = "# 🌐 Frontend Dashboard\n## CloudFront CDN and S3 Static Hosting\n**Environment:** ${upper(var.environment)} | **Region:** ${var.aws_region}"
        }
        x      = 0
        y      = 0
        width  = 24
        height = 2
      },
      {
        type       = "text"
        properties = { markdown = "## ☁️ CloudFront Distribution Metrics" }
        x          = 0
        y          = 2
        width      = 24
        height     = 1
      },
      {
        type = "metric"
        properties = {
          title   = "📊 Total Requests"
          metrics = [["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Sum", label = "Total Requests", color = "#1f77b4" }]]
          view    = "singleValue"
          region  = "us-east-1"
          period  = 300
        }
        x      = 0
        y      = 3
        width  = 6
        height = 4
      },
      {
        type = "metric"
        properties = {
          title   = "📈 Request Rate"
          metrics = [["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Sum", label = "Requests/min", color = "#2ca02c" }]]
          view    = "timeSeries"
          region  = "us-east-1"
          period  = 60
        }
        x      = 6
        y      = 3
        width  = 9
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "⚡ Cache Hit Rate"
          metrics = [
            [{ expression = "(m1/(m1+m2))*100", label = "Cache Hit %", color = "#2ca02c" }],
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { id = "m1", visible = false }],
            [".", "CacheMissRate", ".", ".", ".", ".", { id = "m2", visible = false }]
          ]
          view        = "timeSeries"
          region      = "us-east-1"
          period      = 300
          yAxis       = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ value = 80, label = "Target", color = "#2ca02c" }] }
        }
        x      = 15
        y      = 3
        width  = 9
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "📥 Data Transfer"
          metrics = [
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Sum", label = "Downloaded", color = "#1f77b4" }],
            [".", "BytesUploaded", ".", ".", ".", ".", { stat = "Sum", label = "Uploaded", color = "#ff7f0e" }]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          period = 300
          yAxis  = { left = { label = "Bytes" } }
        }
        x      = 0
        y      = 9
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "🚦 HTTP Status Codes"
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Average", label = "4xx Errors", color = "#ff7f0e" }],
            [".", "5xxErrorRate", ".", ".", ".", ".", { stat = "Average", label = "5xx Errors", color = "#d62728" }]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          period = 300
          yAxis  = { left = { label = "Error Rate %" } }
        }
        x      = 12
        y      = 9
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title   = "⏱️ Origin Latency"
          metrics = [["AWS/CloudFront", "OriginLatency", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Average", label = "Avg Latency", color = "#9467bd" }]]
          view    = "timeSeries"
          region  = "us-east-1"
          period  = 300
          yAxis   = { left = { label = "Milliseconds" } }
        }
        x      = 0
        y      = 15
        width  = 12
        height = 5
      },
      {
        type = "metric"
        properties = {
          title = "🌍 Geographic Distribution"
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Sum", label = "Global" }]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          period = 3600
        }
        x      = 12
        y      = 15
        width  = 12
        height = 5
      },
      {
        type       = "text"
        properties = { markdown = "## 🪣 S3 Bucket Metrics" }
        x          = 0
        y          = 20
        width      = 24
        height     = 1
      },
      {
        type = "metric"
        properties = {
          title   = "📦 Bucket Size"
          metrics = [["AWS/S3", "BucketSizeBytes", "BucketName", var.s3_bucket_name, "StorageType", "StandardStorage", { stat = "Average", label = "Size (Bytes)", color = "#1f77b4" }]]
          view    = "timeSeries"
          region  = var.aws_region
          period  = 86400
          yAxis   = { left = { label = "Bytes" } }
        }
        x      = 0
        y      = 21
        width  = 12
        height = 5
      },
      {
        type = "metric"
        properties = {
          title   = "📄 Object Count"
          metrics = [["AWS/S3", "NumberOfObjects", "BucketName", var.s3_bucket_name, "StorageType", "AllStorageTypes", { stat = "Average", label = "Total Objects", color = "#2ca02c" }]]
          view    = "timeSeries"
          region  = var.aws_region
          period  = 86400
        }
        x      = 12
        y      = 21
        width  = 12
        height = 5
      },
      {
        type = "metric"
        properties = {
          title = "🔄 S3 Requests"
          metrics = [
            ["AWS/S3", "AllRequests", "BucketName", var.s3_bucket_name, { stat = "Sum", label = "All Requests", color = "#1f77b4" }],
            [".", "GetRequests", ".", ".", { stat = "Sum", label = "GET", color = "#2ca02c" }],
            [".", "PutRequests", ".", ".", { stat = "Sum", label = "PUT", color = "#ff7f0e" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          period = 300
        }
        x      = 0
        y      = 26
        width  = 12
        height = 5
      },
      {
        type = "metric"
        properties = {
          title = "⚠️ S3 Errors"
          metrics = [
            ["AWS/S3", "4xxErrors", "BucketName", var.s3_bucket_name, { stat = "Sum", label = "4xx Errors", color = "#ff7f0e" }],
            [".", "5xxErrors", ".", ".", { stat = "Sum", label = "5xx Errors", color = "#d62728" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          period = 300
        }
        x      = 12
        y      = 26
        width  = 12
        height = 5
      }
    ]
  })
}
# ==============================================================================
# Event Service Dashboard
# ==============================================================================

resource "aws_cloudwatch_dashboard" "event_service" {
  dashboard_name = "${var.project_name}-${var.environment}-event-service"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text"
        properties = {
          markdown = "# 🎯 Event Service Dashboard\n## Event management and lifecycle monitoring\n**Environment:** ${upper(var.environment)} | **Region:** ${var.aws_region}"
        }
        x      = 0
        y      = 0
        width  = 24
        height = 2
      },
      {
        type = "metric"
        properties = {
          title     = "📊 Service Health"
          metrics   = [["AWS/ECS", "RunningTaskCount", "ServiceName", "event-service", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Running Tasks" }]]
          view      = "singleValue"
          region    = var.aws_region
          period    = 300
          sparkline = true
        }
        x      = 0
        y      = 2
        width  = 4
        height = 4
      },
      {
        type = "metric"
        properties = {
          title     = "💻 CPU Usage"
          metrics   = [["AWS/ECS", "CPUUtilization", "ServiceName", "event-service", "ClusterName", var.ecs_cluster_name, { stat = "Average" }]]
          view      = "singleValue"
          region    = var.aws_region
          period    = 300
          sparkline = true
        }
        x      = 4
        y      = 2
        width  = 4
        height = 4
      },
      {
        type = "metric"
        properties = {
          title     = "🧠 Memory Usage"
          metrics   = [["AWS/ECS", "MemoryUtilization", "ServiceName", "event-service", "ClusterName", var.ecs_cluster_name, { stat = "Average" }]]
          view      = "singleValue"
          region    = var.aws_region
          period    = 300
          sparkline = true
        }
        x      = 8
        y      = 2
        width  = 4
        height = 4
      },
      {
        type = "metric"
        properties = {
          title   = "📈 Request Rate"
          metrics = var.event_target_group_arn_suffix != "" ? [["AWS/ApplicationELB", "RequestCount", "TargetGroup", var.event_target_group_arn_suffix, { stat = "Sum", label = "Requests/min", color = "#1f77b4" }]] : [["AWS/ECS", "RunningTaskCount", "ServiceName", "event-service", { stat = "Average", label = "No ALB Data" }]]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
          yAxis   = { left = { label = "Requests" } }
        }
        x      = 12
        y      = 2
        width  = 12
        height = 4
      },
      {
        type = "metric"
        properties = {
          title = "🚦 HTTP Status Distribution"
          metrics = var.event_target_group_arn_suffix != "" ? [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "TargetGroup", var.event_target_group_arn_suffix, { stat = "Sum", label = "2XX Success", color = "#2ca02c" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4XX Client Error", color = "#ff7f0e" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5XX Server Error", color = "#d62728" }]
            ] : [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "event-service", { stat = "Average", label = "CPU", color = "#2ca02c" }],
            [".", "MemoryUtilization", ".", ".", { stat = "Average", label = "Memory", color = "#ff7f0e" }],
            [".", "RunningTaskCount", ".", ".", { stat = "Average", label = "Tasks", color = "#1f77b4" }]
          ]
          view   = "pie"
          region = var.aws_region
          period = 300
        }
        x      = 0
        y      = 6
        width  = 8
        height = 6
      },
      {
        type = "metric"
        properties = {
          title = "⏱️ Response Time Analysis"
          metrics = var.event_target_group_arn_suffix != "" ? [
            ["AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", var.event_target_group_arn_suffix, { stat = "Average", label = "Average", color = "#1f77b4" }],
            ["...", { stat = "p50", label = "P50", color = "#2ca02c" }],
            ["...", { stat = "p90", label = "P90", color = "#ff7f0e" }],
            ["...", { stat = "p99", label = "P99", color = "#d62728" }]
            ] : [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "event-service", { stat = "Average", label = "CPU", color = "#1f77b4" }],
            ["...", { stat = "p50", label = "Memory", color = "#2ca02c" }],
            ["...", { stat = "p90", label = "Tasks", color = "#ff7f0e" }],
            ["...", { stat = "p99", label = "Placeholder", color = "#d62728" }]
          ]
          view        = "timeSeries"
          stacked     = false
          region      = var.aws_region
          period      = 300
          yAxis       = { left = { label = "Seconds" } }
          annotations = { horizontal = [{ value = 2, label = "SLA Threshold (2s)", fill = "above", color = "#d62728" }] }
        }
        x      = 8
        y      = 6
        width  = 16
        height = 6
      },
      {
        type       = "text"
        properties = { markdown = "## 📬 Event Message Queues" }
        x          = 0
        y          = 12
        width      = 24
        height     = 1
      },
      {
        type = "metric"
        properties = {
          title = "📨 Queue Messages"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.project_name}-${var.environment}-event-created-queue", { stat = "Average", label = "Event Created" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-event-updated-queue", { stat = "Average", label = "Event Updated" }]
          ]
          view   = "singleValue"
          region = var.aws_region
          period = 300
        }
        x      = 0
        y      = 13
        width  = 8
        height = 4
      },
      {
        type = "metric"
        properties = {
          title = "📊 Message Throughput"
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", "${var.project_name}-${var.environment}-event-created-queue", { stat = "Sum", label = "Created - Sent", color = "#1f77b4" }],
            [".", "NumberOfMessagesReceived", ".", ".", { stat = "Sum", label = "Created - Received", color = "#2ca02c" }],
            [".", "NumberOfMessagesSent", ".", "${var.project_name}-${var.environment}-event-updated-queue", { stat = "Sum", label = "Updated - Sent", color = "#ff7f0e" }],
            [".", "NumberOfMessagesReceived", ".", ".", { stat = "Sum", label = "Updated - Received", color = "#9467bd" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
        }
        x      = 8
        y      = 13
        width  = 16
        height = 4
      },
      {
        type = "log"
        properties = {
          title  = "📋 Recent Event Service Logs"
          region = var.aws_region
          query  = "SOURCE '/ecs/${var.project_name}/${var.environment}/event-service'\n| fields @timestamp, @message\n| filter @message like /ERROR/ or @message like /event/ or @message like /Event/\n| sort @timestamp desc\n| limit 25"
        }
        x      = 0
        y      = 17
        width  = 24
        height = 6
      }
    ]
  })
}
