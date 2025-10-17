# # ==============================================================================
# # Outputs
# # ==============================================================================

# output "instance_id" {
#   description = "ID of the RDS instance"
#   value       = aws_db_instance.primary.id
# }

# output "instance_arn" {
#   description = "ARN of the RDS instance"
#   value       = aws_db_instance.primary.arn
# }

# output "endpoint" {
#   description = "Endpoint of the RDS instance"
#   value       = aws_db_instance.primary.endpoint
# }

# output "address" {
#   description = "Address of the RDS instance"
#   value       = aws_db_instance.primary.address
# }

# output "port" {
#   description = "Port of the RDS instance"
#   value       = aws_db_instance.primary.port
# }

# output "database_name" {
#   description = "Name of the database"
#   value       = aws_db_instance.primary.db_name
# }

# output "master_username" {
#   description = "Master username"
#   value       = aws_db_instance.primary.username
# }

# output "replica_endpoints" {
#   description = "Endpoints of read replicas"
#   value       = aws_db_instance.replica[*].endpoint
# }

# output "replica_instance_ids" {
#   description = "IDs of read replicas"
#   value       = aws_db_instance.replica[*].id
# }

# output "kms_key_id" {
#   description = "KMS key ID for encryption"
#   value       = var.create_kms_key ? aws_kms_key.rds[0].id : null
# }

# output "monitoring_role_arn" {
#   description = "ARN of the monitoring IAM role"
#   value       = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
# }