# ==============================================================================
# Outputs
# ==============================================================================

# ==============================================================================
# Container Management Security Information
# ==============================================================================

output "ecs_task_execution_role_arn" {
  description = "Master security role that AWS uses to manage application containers. Container orchestration system needs this to start, stop, and monitor our business applications."
  value       = aws_iam_role.ecs_task_execution.arn
}

# ==============================================================================
# Business Service Security Information
# ==============================================================================

output "ecs_task_role_arns" {
  description = "Security roles for each business service with specific permissions. Each service gets only the access it needs to perform its business function."
  value = {
    auth-service         = aws_iam_role.auth_service_task.arn         # User authentication and account management permissions
    event-service        = aws_iam_role.event_service_task.arn        # Event creation and management permissions
    booking-service      = aws_iam_role.booking_service_task.arn      # Event booking and reservation permissions
    payment-service      = aws_iam_role.payment_service_task.arn      # Payment processing and transaction permissions
    notification-service = aws_iam_role.notification_service_task.arn # Email and SMS notification permissions
  }
}



