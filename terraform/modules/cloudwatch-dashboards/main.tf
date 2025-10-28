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
          title = "📨 Queue Messages"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.project_name}-${var.environment}-user-registration-queue", { stat = "Average", label = "User Registration Queue" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-user-login-queue", { stat = "Average", label = "User Login Queue" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-password-reset-queue", { stat = "Average", label = "Password Reset Queue" }]
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
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", "${var.project_name}-${var.environment}-user-registration-queue", { stat = "Maximum", label = "User Registration" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-user-login-queue", { stat = "Maximum", label = "User Login" }],
            [".", ".", ".", "${var.project_name}-${var.environment}-password-reset-queue", { stat = "Maximum", label = "Password Reset" }]
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
