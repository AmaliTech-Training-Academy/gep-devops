# # terraform/modules/sqs-sns/main.tf
# # ==============================================================================
# # SQS/SNS Module - Event-Driven Messaging Infrastructure
# # ==============================================================================
# # This module creates the complete pub/sub messaging architecture using
# # SNS topics for publishing and SQS queues for consuming messages
# # ==============================================================================

# # ==============================================================================
# # SNS Topics - Publishers
# # ==============================================================================

# # Event Service SNS Topic
# resource "aws_sns_topic" "event" {
#   name              = "${var.project_name}-${var.environment}-event-topic"
#   display_name      = "Event Service Topic"
#   fifo_topic        = var.enable_fifo
#   content_based_deduplication = var.enable_fifo ? true : null

#   kms_master_key_id = var.kms_key_id

#   tags = merge(
#     var.tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-event-topic"
#       Publisher   = "event-service"
#       Environment = var.environment
#     }
#   )
# }

# # Booking Service SNS Topic
# resource "aws_sns_topic" "booking" {
#   name              = "${var.project_name}-${var.environment}-booking-topic"
#   display_name      = "Booking Service Topic"
#   fifo_topic        = var.enable_fifo
#   content_based_deduplication = var.enable_fifo ? true : null

#   kms_master_key_id = var.kms_key_id

#   tags = merge(
#     var.tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-booking-topic"
#       Publisher   = "booking-service"
#       Environment = var.environment
#     }
#   )
# }

# # Payment Service SNS Topic
# resource "aws_sns_topic" "payment" {
#   name              = "${var.project_name}-${var.environment}-payment-topic"
#   display_name      = "Payment Service Topic"
#   fifo_topic        = var.enable_fifo
#   content_based_deduplication = var.enable_fifo ? true : null

#   kms_master_key_id = var.kms_key_id

#   tags = merge(
#     var.tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-payment-topic"
#       Publisher   = "payment-service"
#       Environment = var.environment
#     }
#   )
# }

# # ==============================================================================
# # SQS Queues - Consumers
# # ==============================================================================

# # Dead Letter Queues (DLQ)
# resource "aws_sqs_queue" "event_created_notification_dlq" {
#   name                      = "${var.project_name}-${var.environment}-event-created-notification-dlq"
#   message_retention_seconds = var.dlq_message_retention_seconds
#   kms_master_key_id        = var.kms_key_id

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-${var.environment}-event-created-notification-dlq"
#       Type = "DLQ"
#     }
#   )
# }

# resource "aws_sqs_queue" "booking_created_notification_dlq" {
#   name                      = "${var.project_name}-${var.environment}-booking-created-notification-dlq"
#   message_retention_seconds = var.dlq_message_retention_seconds
#   kms_master_key_id        = var.kms_key_id

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-${var.environment}-booking-created-notification-dlq"
#       Type = "DLQ"
#     }
#   )
# }

# resource "aws_sqs_queue" "payment_completed_notification_dlq" {
#   name                      = "${var.project_name}-${var.environment}-payment-completed-notification-dlq"
#   message_retention_seconds = var.dlq_message_retention_seconds
#   kms_master_key_id        = var.kms_key_id

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-${var.environment}-payment-completed-notification-dlq"
#       Type = "DLQ"
#     }
#   )
# }

# # Main Queues with DLQ Configuration

# # 1. Event Created → Notification Service
# resource "aws_sqs_queue" "event_created_notification" {
#   name                      = "${var.project_name}-${var.environment}-event-created-notification-queue"
#   visibility_timeout_seconds = var.visibility_timeout_seconds
#   message_retention_seconds = var.message_retention_seconds
#   delay_seconds             = 0
#   max_message_size          = 262144 # 256 KB
#   receive_wait_time_seconds = var.receive_wait_time_seconds
#   kms_master_key_id        = var.kms_key_id

#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.event_created_notification_dlq.arn
#     maxReceiveCount     = var.max_receive_count
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name       = "${var.project_name}-${var.environment}-event-created-notification-queue"
#       Subscriber = "notification-service"
#       Publisher  = "event-service"
#     }
#   )
# }

# # 2. Event Created → Booking Service
# resource "aws_sqs_queue" "event_created_booking" {
#   name                      = "${var.project_name}-${var.environment}-event-created-booking-queue"
#   visibility_timeout_seconds = var.visibility_timeout_seconds
#   message_retention_seconds = var.message_retention_seconds
#   delay_seconds             = 0
#   max_message_size          = 262144
#   receive_wait_time_seconds = var.receive_wait_time_seconds
#   kms_master_key_id        = var.kms_key_id

#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.event_created_notification_dlq.arn
#     maxReceiveCount     = var.max_receive_count
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name       = "${var.project_name}-${var.environment}-event-created-booking-queue"
#       Subscriber = "booking-service"
#       Publisher  = "event-service"
#     }
#   )
# }

# # 3. Booking Created → Notification Service
# resource "aws_sqs_queue" "booking_created_notification" {
#   name                      = "${var.project_name}-${var.environment}-booking-created-notification-queue"
#   visibility_timeout_seconds = var.visibility_timeout_seconds
#   message_retention_seconds = var.message_retention_seconds
#   delay_seconds             = 0
#   max_message_size          = 262144
#   receive_wait_time_seconds = var.receive_wait_time_seconds
#   kms_master_key_id        = var.kms_key_id

#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.booking_created_notification_dlq.arn
#     maxReceiveCount     = var.max_receive_count
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name       = "${var.project_name}-${var.environment}-booking-created-notification-queue"
#       Subscriber = "notification-service"
#       Publisher  = "booking-service"
#     }
#   )
# }

# # 4. Booking Created → Event Service
# resource "aws_sqs_queue" "booking_created_event" {
#   name                      = "${var.project_name}-${var.environment}-booking-created-event-queue"
#   visibility_timeout_seconds = var.visibility_timeout_seconds
#   message_retention_seconds = var.message_retention_seconds
#   delay_seconds             = 0
#   max_message_size          = 262144
#   receive_wait_time_seconds = var.receive_wait_time_seconds
#   kms_master_key_id        = var.kms_key_id

#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.booking_created_notification_dlq.arn
#     maxReceiveCount     = var.max_receive_count
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name       = "${var.project_name}-${var.environment}-booking-created-event-queue"
#       Subscriber = "event-service"
#       Publisher  = "booking-service"
#     }
#   )
# }

# # 5. Payment Completed → Notification Service
# resource "aws_sqs_queue" "payment_completed_notification" {
#   name                      = "${var.project_name}-${var.environment}-payment-completed-notification-queue"
#   visibility_timeout_seconds = var.visibility_timeout_seconds
#   message_retention_seconds = var.message_retention_seconds
#   delay_seconds             = 0
#   max_message_size          = 262144
#   receive_wait_time_seconds = var.receive_wait_time_seconds
#   kms_master_key_id        = var.kms_key_id

#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.payment_completed_notification_dlq.arn
#     maxReceiveCount     = var.max_receive_count
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name       = "${var.project_name}-${var.environment}-payment-completed-notification-queue"
#       Subscriber = "notification-service"
#       Publisher  = "payment-service"
#     }
#   )
# }

# # 6. Payment Completed → Booking Service
# resource "aws_sqs_queue" "payment_completed_booking" {
#   name                      = "${var.project_name}-${var.environment}-payment-completed-booking-queue"
#   visibility_timeout_seconds = var.visibility_timeout_seconds
#   message_retention_seconds = var.message_retention_seconds
#   delay_seconds             = 0
#   max_message_size          = 262144
#   receive_wait_time_seconds = var.receive_wait_time_seconds
#   kms_master_key_id        = var.kms_key_id

#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.payment_completed_notification_dlq.arn
#     maxReceiveCount     = var.max_receive_count
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name       = "${var.project_name}-${var.environment}-payment-completed-booking-queue"
#       Subscriber = "booking-service"
#       Publisher  = "payment-service"
#     }
#   )
# }

# # 7. Payment Failed → Notification Service
# resource "aws_sqs_queue" "payment_failed_notification" {
#   name                      = "${var.project_name}-${var.environment}-payment-failed-notification-queue"
#   visibility_timeout_seconds = var.visibility_timeout_seconds
#   message_retention_seconds = var.message_retention_seconds
#   delay_seconds             = 0
#   max_message_size          = 262144
#   receive_wait_time_seconds = var.receive_wait_time_seconds
#   kms_master_key_id        = var.kms_key_id

#   redrive_policy = jsonencode({
#     deadLetterTargetArn = aws_sqs_queue.payment_completed_notification_dlq.arn
#     maxReceiveCount     = var.max_receive_count
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name       = "${var.project_name}-${var.environment}-payment-failed-notification-queue"
#       Subscriber = "notification-service"
#       Publisher  = "payment-service"
#     }
#   )
# }

# # ==============================================================================
# # SQS Queue Policies - Allow SNS to Send Messages
# # ==============================================================================

# resource "aws_sqs_queue_policy" "event_created_notification" {
#   queue_url = aws_sqs_queue.event_created_notification.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "sns.amazonaws.com"
#         }
#         Action   = "sqs:SendMessage"
#         Resource = aws_sqs_queue.event_created_notification.arn
#         Condition = {
#           ArnEquals = {
#             "aws:SourceArn" = aws_sns_topic.event.arn
#           }
#         }
#       }
#     ]
#   })
# }

# resource "aws_sqs_queue_policy" "event_created_booking" {
#   queue_url = aws_sqs_queue.event_created_booking.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "sns.amazonaws.com"
#         }
#         Action   = "sqs:SendMessage"
#         Resource = aws_sqs_queue.event_created_booking.arn
#         Condition = {
#           ArnEquals = {
#             "aws:SourceArn" = aws_sns_topic.event.arn
#           }
#         }
#       }
#     ]
#   })
# }

# resource "aws_sqs_queue_policy" "booking_created_notification" {
#   queue_url = aws_sqs_queue.booking_created_notification.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "sns.amazonaws.com"
#         }
#         Action   = "sqs:SendMessage"
#         Resource = aws_sqs_queue.booking_created_notification.arn
#         Condition = {
#           ArnEquals = {
#             "aws:SourceArn" = aws_sns_topic.booking.arn
#           }
#         }
#       }
#     ]
#   })
# }

# resource "aws_sqs_queue_policy" "booking_created_event" {
#   queue_url = aws_sqs_queue.booking_created_event.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "sns.amazonaws.com"
#         }
#         Action   = "sqs:SendMessage"
#         Resource = aws_sqs_queue.booking_created_event.arn
#         Condition = {
#           ArnEquals = {
#             "aws:SourceArn" = aws_sns_topic.booking.arn
#           }
#         }
#       }
#     ]
#   })
# }

# resource "aws_sqs_queue_policy" "payment_queues" {
#   for_each = {
#     completed_notification = aws_sqs_queue.payment_completed_notification.id
#     completed_booking      = aws_sqs_queue.payment_completed_booking.id
#     failed_notification    = aws_sqs_queue.payment_failed_notification.id
#   }

#   queue_url = each.value

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "sns.amazonaws.com"
#         }
#         Action   = "sqs:SendMessage"
#         Resource = lookup({
#           completed_notification = aws_sqs_queue.payment_completed_notification.arn
#           completed_booking      = aws_sqs_queue.payment_completed_booking.arn
#           failed_notification    = aws_sqs_queue.payment_failed_notification.arn
#         }, each.key)
#         Condition = {
#           ArnEquals = {
#             "aws:SourceArn" = aws_sns_topic.payment.arn
#           }
#         }
#       }
#     ]
#   })
# }

# # ==============================================================================
# # SNS Subscriptions - Link Topics to Queues
# # ==============================================================================

# # Event Topic Subscriptions
# resource "aws_sns_topic_subscription" "event_to_notification" {
#   topic_arn = aws_sns_topic.event.arn
#   protocol  = "sqs"
#   endpoint  = aws_sqs_queue.event_created_notification.arn

#   filter_policy = jsonencode({
#     event_type = ["event_created", "event_updated"]
#   })
# }

# resource "aws_sns_topic_subscription" "event_to_booking" {
#   topic_arn = aws_sns_topic.event.arn
#   protocol  = "sqs"
#   endpoint  = aws_sqs_queue.event_created_booking.arn

#   filter_policy = jsonencode({
#     event_type = ["event_created"]
#   })
# }

# # Booking Topic Subscriptions
# resource "aws_sns_topic_subscription" "booking_to_notification" {
#   topic_arn = aws_sns_topic.booking.arn
#   protocol  = "sqs"
#   endpoint  = aws_sqs_queue.booking_created_notification.arn

#   filter_policy = jsonencode({
#     event_type = ["booking_created", "booking_cancelled"]
#   })
# }

# resource "aws_sns_topic_subscription" "booking_to_event" {
#   topic_arn = aws_sns_topic.booking.arn
#   protocol  = "sqs"
#   endpoint  = aws_sqs_queue.booking_created_event.arn

#   filter_policy = jsonencode({
#     event_type = ["booking_created"]
#   })
# }

# # Payment Topic Subscriptions
# resource "aws_sns_topic_subscription" "payment_completed_to_notification" {
#   topic_arn = aws_sns_topic.payment.arn
#   protocol  = "sqs"
#   endpoint  = aws_sqs_queue.payment_completed_notification.arn

#   filter_policy = jsonencode({
#     event_type = ["payment_completed"]
#   })
# }

# resource "aws_sns_topic_subscription" "payment_completed_to_booking" {
#   topic_arn = aws_sns_topic.payment.arn
#   protocol  = "sqs"
#   endpoint  = aws_sqs_queue.payment_completed_booking.arn

#   filter_policy = jsonencode({
#     event_type = ["payment_completed"]
#   })
# }

# resource "aws_sns_topic_subscription" "payment_failed_to_notification" {
#   topic_arn = aws_sns_topic.payment.arn
#   protocol  = "sqs"
#   endpoint  = aws_sqs_queue.payment_failed_notification.arn

#   filter_policy = jsonencode({
#     event_type = ["payment_failed"]
#   })
# }

# # ==============================================================================
# # CloudWatch Alarms for DLQ Monitoring
# # ==============================================================================

# resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
#   for_each = {
#     event_notification  = aws_sqs_queue.event_created_notification_dlq.name
#     booking_notification = aws_sqs_queue.booking_created_notification_dlq.name
#     payment_notification = aws_sqs_queue.payment_completed_notification_dlq.name
#   }

#   alarm_name          = "${each.key}-dlq-messages"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "ApproximateNumberOfMessagesVisible"
#   namespace           = "AWS/SQS"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "0"
#   alarm_description   = "Alert when messages appear in ${each.key} DLQ"
#   alarm_actions       = var.alarm_sns_topic_arns

#   dimensions = {
#     QueueName = each.value
#   }

#   tags = var.tags
# }

# # ==============================================================================
# # terraform/modules/sqs-sns/variables.tf
# # ==============================================================================

# variable "project_name" {
#   description = "Project name"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "enable_fifo" {
#   description = "Enable FIFO topics/queues"
#   type        = bool
#   default     = false
# }

# variable "visibility_timeout_seconds" {
#   description = "Visibility timeout for SQS messages"
#   type        = number
#   default     = 30
# }

# variable "message_retention_seconds" {
#   description = "Message retention period"
#   type        = number
#   default     = 345600 # 4 days
# }

# variable "dlq_message_retention_seconds" {
#   description = "DLQ message retention period"
#   type        = number
#   default     = 1209600 # 14 days
# }

# variable "receive_wait_time_seconds" {
#   description = "Long polling wait time"
#   type        = number
#   default     = 20
# }

# variable "max_receive_count" {
#   description = "Max receive count before sending to DLQ"
#   type        = number
#   default     = 3
# }

# variable "kms_key_id" {
#   description = "KMS key ID for encryption"
#   type        = string
#   default     = null
# }

# variable "alarm_sns_topic_arns" {
#   description = "SNS topic ARNs for CloudWatch alarms"
#   type        = list(string)
#   default     = []
# }

# variable "tags" {
#   description = "Tags to apply to resources"
#   type        = map(string)
#   default     = {}
# }

# # ==============================================================================
# # terraform/modules/sqs-sns/outputs.tf
# # ==============================================================================

# output "sns_topic_arns" {
#   description = "Map of SNS topic ARNs"
#   value = {
#     event   = aws_sns_topic.event.arn
#     booking = aws_sns_topic.booking.arn
#     payment = aws_sns_topic.payment.arn
#   }
# }

# output "sns_topic_names" {
#   description = "Map of SNS topic names"
#   value = {
#     event   = aws_sns_topic.event.name
#     booking = aws_sns_topic.booking.name
#     payment = aws_sns_topic.payment.name
#   }
# }

# output "sqs_queue_arns" {
#   description = "Map of SQS queue ARNs"
#   value = {
#     event_created_notification     = aws_sqs_queue.event_created_notification.arn
#     event_created_booking          = aws_sqs_queue.event_created_booking.arn
#     booking_created_notification   = aws_sqs_queue.booking_created_notification.arn
#     booking_created_event          = aws_sqs_queue.booking_created_event.arn
#     payment_completed_notification = aws_sqs_queue.payment_completed_notification.arn
#     payment_completed_booking      = aws_sqs_queue.payment_completed_booking.arn
#     payment_failed_notification    = aws_sqs_queue.payment_failed_notification.arn
#   }
# }

# output "sqs_queue_urls" {
#   description = "Map of SQS queue URLs"
#   value = {
#     event_created_notification     = aws_sqs_queue.event_created_notification.url
#     event_created_booking          = aws_sqs_queue.event_created_booking.url
#     booking_created_notification   = aws_sqs_queue.booking_created_notification.url
#     booking_created_event          = aws_sqs_queue.booking_created_event.url
#     payment_completed_notification = aws_sqs_queue.payment_completed_notification.url
#     payment_completed_booking      = aws_sqs_queue.payment_completed_booking.url
#     payment_failed_notification    = aws_sqs_queue.payment_failed_notification.url
#   }
# }

# output "dlq_arns" {
#   description = "Map of Dead Letter Queue ARNs"
#   value = {
#     event_notification  = aws_sqs_queue.event_created_notification_dlq.arn
#     booking_notification = aws_sqs_queue.booking_created_notification_dlq.arn
#     payment_notification = aws_sqs_queue.payment_completed_notification_dlq.arn
#   }
# }