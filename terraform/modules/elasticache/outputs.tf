# # terraform/modules/elasticache/outputs.tf
# output "replication_group_id" {
#   description = "ElastiCache replication group ID"
#   value       = aws_elasticache_replication_group.main.id
# }

# output "replication_group_arn" {
#   description = "ElastiCache replication group ARN"
#   value       = aws_elasticache_replication_group.main.arn
# }

# output "primary_endpoint_address" {
#   description = "Primary endpoint address"
#   value       = var.enable_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address
# }

# output "reader_endpoint_address" {
#   description = "Reader endpoint address (non-cluster mode only)"
#   value       = var.enable_cluster_mode ? null : aws_elasticache_replication_group.main.reader_endpoint_address
# }

# output "port" {
#   description = "Redis port"
#   value       = 6379
# }

# output "security_group_id" {
#   description = "Redis security group ID"
#   value       = aws_security_group.redis.id
# }

# output "auth_token_secret_arn" {
#   description = "ARN of the Secrets Manager secret containing Redis auth token"
#   value       = var.enable_auth_token ? aws_secretsmanager_secret.redis_auth_token[0].arn : null
# }