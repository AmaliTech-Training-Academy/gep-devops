# ==============================================================================
# ECS Module Outputs - Container Infrastructure Information
# ==============================================================================
# WHAT THIS FILE PROVIDES:
# Information about our running container infrastructure that other systems need.
# Like providing department contact information and resource locations to other teams.
#
# INFORMATION CATEGORIES:
# - Cluster Details: Main container hosting environment information
# - Service Discovery: How services find and communicate with each other
# - Service Information: Details about each running business application
# - Monitoring: Log locations and health check endpoints
#
# WHO USES THIS INFORMATION:
# - Load balancers: Need service details to route user requests
# - Monitoring systems: Need log locations to track application health
# - Other infrastructure: Need cluster info to deploy additional services
# - Operations team: Need service names and IDs for troubleshooting
# ==============================================================================

# ==============================================================================
# Container Cluster Information
# ==============================================================================

output "cluster_id" {
  description = "Unique identifier of the ECS cluster where all our business applications run. Used by monitoring and deployment tools."
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Human-readable name of the container cluster (e.g., 'event-planner-dev-cluster'). Used in dashboards and operations."
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "Amazon Resource Name of the cluster. Used for IAM policies and cross-account access permissions."
  value       = aws_ecs_cluster.main.arn
}

# ==============================================================================
# Service Communication Information
# ==============================================================================

output "service_discovery_namespace_id" {
  description = "ID of the internal DNS system that allows services to find each other (like an internal phone directory)."
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "service_discovery_namespace_arn" {
  description = "Amazon Resource Name of the service discovery system. Used for security policies and access control."
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "service_discovery_namespace_name" {
  description = "Domain name used for internal service communication (e.g., 'eventplanner.local'). Services use this to talk to each other."
  value       = aws_service_discovery_private_dns_namespace.main.name
}

# ==============================================================================
# Business Application Information
# ==============================================================================

output "service_ids" {
  description = "Map of business service names (auth, event, notification) to their unique ECS identifiers. Used for operations and monitoring."
  value = {
    for service, config in local.services :
    service => aws_ecs_service.services[service].id
  }
}

output "service_names" {
  description = "Map of business service names to their full ECS service names. Used by load balancers and monitoring systems."
  value = {
    for service, config in local.services :
    service => aws_ecs_service.services[service].name
  }
}

output "task_definition_arns" {
  description = "Map of service names to their application configuration templates. Defines how each business service runs (CPU, memory, environment)."
  value = {
    for service, config in local.services :
    service => aws_ecs_task_definition.services[service].arn
  }
}

# ==============================================================================
# Monitoring and Troubleshooting Information
# ==============================================================================

output "log_group_names" {
  description = "Map of service names to their CloudWatch log locations. Operations team uses these to troubleshoot issues and monitor application health."
  value = {
    for service, config in local.services :
    service => aws_cloudwatch_log_group.services[service].name
  }
}