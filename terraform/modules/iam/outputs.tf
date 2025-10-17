# ==============================================================================
# Outputs
# ==============================================================================

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arns" {
  description = "ARNs of the ECS task roles"
  value = {
    auth_service  = aws_iam_role.auth_service_task.arn
    event_service = aws_iam_role.event_service_task.arn
  }
}