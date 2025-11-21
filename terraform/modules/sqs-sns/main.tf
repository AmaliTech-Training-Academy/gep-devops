# ==============================================================================
# SQS-SNS Module - Message Queuing and Pub/Sub
# ==============================================================================
# This module replaces Kafka with AWS-managed messaging:
# - SNS Topics for event publishing (replaces Kafka topics)
# - SQS Queues for message consumption (replaces Kafka consumer groups)
# - Dead Letter Queues for failed message handling
# - FIFO queues for ordered processing (where needed)
#
# Event Flow:
# Publisher Service → SNS Topic → SQS Queues → Subscriber Services
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
  # SNS topics for event publishing
  topics = {
    event   = "${var.project_name}-${var.environment}-event-topic"
    payment = "${var.project_name}-${var.environment}-payment-topic"
  }

  # SQS queues for event consumption (auth, event, notification services only)
  queues = {
    # Auth service queues
    user_registration = {
      name               = "${var.project_name}-${var.environment}-user-registration-queue"
      topic              = "event"
      filter_policy      = { event_type = ["user.registered"] }
      visibility_timeout = 30
      message_retention  = 259200
    }
    user_login = {
      name               = "${var.project_name}-${var.environment}-user-login-queue"
      topic              = "event"
      filter_policy      = { event_type = ["user.login"] }
      visibility_timeout = 30
      message_retention  = 259200
    }
    password_reset = {
      name               = "${var.project_name}-${var.environment}-password-reset-queue"
      topic              = "event"
      filter_policy      = { event_type = ["password.reset"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Event service queues
    event_created = {
      name               = "${var.project_name}-${var.environment}-event-created-queue"
      topic              = "event"
      filter_policy      = { event_type = ["event.created"] }
      visibility_timeout = 30
      message_retention  = 259200
    }
    event_updated = {
      name               = "${var.project_name}-${var.environment}-event-updated-queue"
      topic              = "event"
      filter_policy      = { event_type = ["event.updated"] }
      visibility_timeout = 30
      message_retention  = 259200
    }
    event_created_notification = {
      name               = "${var.project_name}-${var.environment}-event-created-notification-queue"
      topic              = "event"
      filter_policy      = { event_type = ["event.created"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Notification service queue (handles email, OTP, SMS)
    notifications = {
      name               = "${var.project_name}-${var.environment}-notifications-queue"
      topic              = "event"
      filter_policy      = { event_type = ["notification.email", "notification.otp", "notification.sms", "otp.generate", "otp.verify"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Event invitation queue
    event_invitation = {
      name               = "${var.project_name}-${var.environment}-event-invitation-queue"
      topic              = "event"
      filter_policy      = { event_type = ["event.invitation"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Ticket purchased event queue
    ticket_purchased_event = {
      name               = "${var.project_name}-${var.environment}-ticket-purchased-event-queue"
      topic              = "event"
      filter_policy      = { event_type = ["ticket.purchased"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Payment processing event queue
    payment_processing_event = {
      name               = "${var.project_name}-${var.environment}-payment-processing-event-queue"
      topic              = "payment"
      filter_policy      = { event_type = ["payment.processing"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Payment completed event queue
    payment_completed_event = {
      name               = "${var.project_name}-${var.environment}-payment-completed-event-queue"
      topic              = "payment"
      filter_policy      = { event_type = ["payment.completed"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Event stat queue
    event_stat = {
      name               = "${var.project_name}-${var.environment}-event-stat-queue"
      topic              = "event"
      filter_policy      = { event_type = ["event.stat"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # User invitation queue
    user_invitation = {
      name               = "${var.project_name}-${var.environment}-user-invitation-queue"
      topic              = "event"
      filter_policy      = { event_type = ["user.invitation"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Event creation queue for event service
    event_creation_event = {
      name               = "${var.project_name}-${var.environment}-event-creation-event-queue"
      topic              = "event"
      filter_policy      = { event_type = ["event.creation"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Event creation queue for notification service
    event_creation_notification = {
      name               = "${var.project_name}-${var.environment}-event-creation-notification-queue"
      topic              = "event"
      filter_policy      = { event_type = ["event.creation"] }
      visibility_timeout = 30
      message_retention  = 259200
    }

    # Payment completed queue for payment service
    payment_completed = {
      name               = "${var.project_name}-${var.environment}-payment-completed-queue"
      topic              = "payment"
      filter_policy      = { event_type = ["payment.completed"] }
      visibility_timeout = 30
      message_retention  = 259200
    }
  }

  common_tags = merge(
    var.tags,
    {
      Module      = "sqs-sns"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# SNS Topics
# ==============================================================================

resource "aws_sns_topic" "topics" {
  for_each = local.topics

  name              = each.value
  display_name      = each.value
  kms_master_key_id = var.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name        = each.value
      Type        = "event-topic"
      Service     = "messaging"
      Component   = "sns"
      Purpose     = "event-publishing"
    }
  )
}

# ==============================================================================
# Dead Letter Queues
# ==============================================================================

# Create DLQ for each queue
resource "aws_sqs_queue" "dlq" {
  for_each = local.queues

  name                      = "${each.value.name}-dlq"
  message_retention_seconds = 259200 # 3 days
  kms_master_key_id         = var.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name        = "${each.value.name}-dlq"
      Type        = "dead-letter-queue"
      Service     = "messaging"
      Component   = "sqs"
      Purpose     = "failed-message-handling"
      Retention   = "3-days"
    }
  )
}

# ==============================================================================
# SQS Queues
# ==============================================================================

resource "aws_sqs_queue" "queues" {
  for_each = local.queues

  name                       = each.value.name
  visibility_timeout_seconds = each.value.visibility_timeout
  message_retention_seconds  = each.value.message_retention
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KB
  receive_wait_time_seconds  = 20     # Long polling
  kms_master_key_id          = var.kms_key_arn

  # Dead letter queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 3
  })

  tags = merge(
    local.common_tags,
    {
      Name        = each.value.name
      Type        = "message-queue"
      Topic       = each.value.topic
      Service     = "messaging"
      Component   = "sqs"
      Purpose     = "event-processing"
      Retention   = "3-days"
    }
  )
}

# ==============================================================================
# SQS Queue Policies
# ==============================================================================

resource "aws_sqs_queue_policy" "queues" {
  for_each = local.queues

  queue_url = aws_sqs_queue.queues[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.queues[each.key].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.topics[each.value.topic].arn
          }
        }
      }
    ]
  })
}

# ==============================================================================
# SNS Topic Subscriptions
# ==============================================================================

resource "aws_sns_topic_subscription" "subscriptions" {
  for_each = local.queues

  topic_arn = aws_sns_topic.topics[each.value.topic].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queues[each.key].arn

  # Message filtering
  filter_policy = jsonencode(each.value.filter_policy)

  # Raw message delivery (no SNS wrapper)
  raw_message_delivery = false
}

# ==============================================================================
# CloudWatch Alarms for DLQ
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  for_each = local.queues

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Messages in DLQ for ${each.value.name}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.dlq[each.key].name
  }

  tags = local.common_tags
}

# ==============================================================================
# CloudWatch Alarms for Queue Age
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "queue_age" {
  for_each = local.queues

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-message-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "300" # 5 minutes
  alarm_description   = "Messages aging in ${each.value.name}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.queues[each.key].name
  }

  tags = local.common_tags
}

