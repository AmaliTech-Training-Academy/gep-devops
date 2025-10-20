# ==============================================================================
# Outputs
# ==============================================================================

output "replication_group_id" {
  description = "The ID of the ElastiCache Replication Group"
  value       = var.cluster_mode_enabled ? try(aws_elasticache_replication_group.cluster_mode[0].id, "") : try(aws_elasticache_replication_group.single_node[0].id, "")
}

output "replication_group_arn" {
  description = "The ARN of the ElastiCache Replication Group"
  value       = var.cluster_mode_enabled ? try(aws_elasticache_replication_group.cluster_mode[0].arn, "") : try(aws_elasticache_replication_group.single_node[0].arn, "")
}

output "configuration_endpoint_address" {
  description = "The configuration endpoint address to allow host discovery"
  value       = var.cluster_mode_enabled ? try(aws_elasticache_replication_group.cluster_mode[0].configuration_endpoint_address, "") : null
}

output "primary_endpoint_address" {
  description = "The address of the endpoint for the primary node in the replication group"
  value       = var.cluster_mode_enabled ? null : try(aws_elasticache_replication_group.single_node[0].primary_endpoint_address, "")
}

output "reader_endpoint_address" {
  description = "The address of the endpoint for the reader node in the replication group"
  value       = var.cluster_mode_enabled ? null : try(aws_elasticache_replication_group.single_node[0].reader_endpoint_address, "")
}

output "port" {
  description = "The port number on which the cache accepts connections"
  value       = var.redis_port
}

output "subnet_group_name" {
  description = "The name of the ElastiCache subnet group"
  value       = aws_elasticache_subnet_group.main.name
}

output "parameter_group_name" {
  description = "The name of the ElastiCache parameter group"
  value       = aws_elasticache_parameter_group.main.name
}