# ==============================================================================
# Outputs
# ==============================================================================

output "topic_arns" {
  description = "Map of topic names to SNS topic ARNs"
  value = {
    for topic, name in local.topics :
    topic => aws_sns_topic.topics[topic].arn
  }
}

output "queue_urls" {
  description = "Map of queue names to SQS queue URLs"
  value = {
    for queue, config in local.queues :
    queue => aws_sqs_queue.queues[queue].url
  }
}

output "queue_arns" {
  description = "Map of queue names to SQS queue ARNs"
  value = {
    for queue, config in local.queues :
    queue => aws_sqs_queue.queues[queue].arn
  }
}

output "dlq_arns" {
  description = "Map of queue names to DLQ ARNs"
  value = {
    for queue, config in local.queues :
    queue => aws_sqs_queue.dlq[queue].arn
  }
}

