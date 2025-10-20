# ==============================================================================
# Outputs
# ==============================================================================

output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "service_discovery_namespace_id" {
  description = "Service discovery namespace ID"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "service_discovery_namespace_arn" {
  description = "Service discovery namespace ARN"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "service_discovery_namespace_name" {
  description = "Service discovery namespace name"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_ids" {
  description = "Map of service names to ECS service IDs"
  value = {
    for service, config in local.services :
    service => aws_ecs_service.services[service].id
  }
}

output "service_names" {
  description = "Map of service names to ECS service names"
  value = {
    for service, config in local.services :
    service => aws_ecs_service.services[service].name
  }
}

output "task_definition_arns" {
  description = "Map of service names to task definition ARNs"
  value = {
    for service, config in local.services :
    service => aws_ecs_task_definition.services[service].arn
  }
}

output "log_group_names" {
  description = "Map of service names to CloudWatch log group names"
  value = {
    for service, config in local.services :
    service => aws_cloudwatch_log_group.services[service].name
  }
}