# # terraform/modules/ecs/outputs.tf
# output "cluster_id" {
#   description = "ECS cluster ID"
#   value       = aws_ecs_cluster.main.id
# }

# output "cluster_name" {
#   description = "ECS cluster name"
#   value       = aws_ecs_cluster.main.name
# }

# output "cluster_arn" {
#   description = "ECS cluster ARN"
#   value       = aws_ecs_cluster.main.arn
# }

# output "task_execution_role_arn" {
#   description = "ECS task execution role ARN"
#   value       = aws_iam_role.ecs_task_execution_role.arn
# }

# output "task_role_arn" {
#   description = "ECS task role ARN"
#   value       = aws_iam_role.ecs_task_role.arn
# }

# output "ecs_tasks_security_group_id" {
#   description = "Security group ID for ECS tasks"
#   value       = aws_security_group.ecs_tasks.id
# }

# output "log_group_name" {
#   description = "CloudWatch log group name"
#   value       = aws_cloudwatch_log_group.ecs.name
# }

# output "service_discovery_namespace_id" {
#   description = "Service discovery namespace ID"
#   value       = var.enable_service_discovery ? aws_service_discovery_private_dns_namespace.main[0].id : null
# }

# output "service_discovery_namespace_name" {
#   description = "Service discovery namespace name"
#   value       = var.enable_service_discovery ? aws_service_discovery_private_dns_namespace.main[0].name : null
# }