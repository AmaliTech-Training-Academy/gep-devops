# ==============================================================================
# Outputs
# ==============================================================================

output "cluster_id" {
  description = "DocumentDB cluster identifier"
  value       = aws_docdb_cluster.main.id
}

output "cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "DocumentDB cluster reader endpoint"
  value       = aws_docdb_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "DocumentDB cluster port"
  value       = aws_docdb_cluster.main.port
}

output "cluster_arn" {
  description = "DocumentDB cluster ARN"
  value       = aws_docdb_cluster.main.arn
}

output "instance_ids" {
  description = "List of DocumentDB instance identifiers"
  value       = concat([aws_docdb_cluster_instance.primary.id], aws_docdb_cluster_instance.replicas[*].id)
}

output "secret_arn" {
  description = "ARN of Secrets Manager secret containing credentials"
  value       = aws_secretsmanager_secret.docdb_credentials.arn
}

output "cluster_resource_id" {
  description = "DocumentDB cluster resource ID"
  value       = aws_docdb_cluster.main.cluster_resource_id
}