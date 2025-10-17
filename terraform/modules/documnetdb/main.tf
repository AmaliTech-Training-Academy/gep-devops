# # terraform/modules/documentdb/main.tf
# # ==============================================================================
# # DocumentDB Module - MongoDB-Compatible Database for Audit Logs
# # ==============================================================================

# # DocumentDB Subnet Group
# resource "aws_docdb_subnet_group" "main" {
#   name       = "${var.project_name}-${var.environment}-docdb-subnet-group"
#   subnet_ids = var.subnet_ids

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-${var.environment}-docdb-subnet-group"
#     }
#   )
# }

# # DocumentDB Cluster Parameter Group
# resource "aws_docdb_cluster_parameter_group" "main" {
#   family      = "docdb5.0"
#   name        = "${var.project_name}-${var.environment}-docdb-params"
#   description = "DocumentDB cluster parameter group for ${var.project_name}"

#   parameter {
#     name  = "tls"
#     value = "enabled"
#   }

#   tags = var.tags
# }

# # Random password for DocumentDB
# resource "random_password" "master" {
#   length  = 32
#   special = true
#   override_special = "!#$%&*()-_=+[]{}<>:?"
# }

# # Store password in Secrets Manager
# resource "aws_secretsmanager_secret" "master_password" {
#   name                    = "${var.project_name}/${var.environment}/documentdb/master-password"
#   description             = "Master password for DocumentDB cluster"
#   recovery_window_in_days = 7

#   tags = var.tags
# }

# resource "aws_secretsmanager_secret_version" "master_password" {
#   secret_id = aws_secretsmanager_secret.master_password.id
#   secret_string = jsonencode({
#     username = var.master_username
#     password = random_password.master.result
#     engine   = "docdb"
#     host     = aws_docdb_cluster.main.endpoint
#     port     = 27017
#   })
# }

# # DocumentDB Cluster
# resource "aws_docdb_cluster" "main" {
#   cluster_identifier      = var.cluster_identifier
#   engine                  = "docdb"
#   master_username         = var.master_username
#   master_password         = random_password.master.result
#   backup_retention_period = var.backup_retention_period
#   preferred_backup_window = var.preferred_backup_window
#   skip_final_snapshot     = var.skip_final_snapshot
  
#   db_subnet_group_name            = aws_docdb_subnet_group.main.name
#   db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
#   vpc_security_group_ids          = var.vpc_security_group_ids
  
#   storage_encrypted = true
#   kms_key_id        = var.kms_key_id
  
#   enabled_cloudwatch_logs_exports = ["audit", "profiler"]

#   tags = merge(
#     var.tags,
#     {
#       Name = var.cluster_identifier
#     }
#   )
# }

# # DocumentDB Cluster Instances
# resource "aws_docdb_cluster_instance" "main" {
#   count = var.instance_count

#   identifier         = "${var.cluster_identifier}-${count.index + 1}"
#   cluster_identifier = aws_docdb_cluster.main.id
#   instance_class     = var.instance_class

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.cluster_identifier}-${count.index + 1}"
#     }
#   )
# }

# # terraform/modules/documentdb/variables.tf
# variable "project_name" {
#   description = "Project name"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "cluster_identifier" {
#   description = "DocumentDB cluster identifier"
#   type        = string
# }

# variable "instance_class" {
#   description = "Instance class for DocumentDB"
#   type        = string
#   default     = "db.t3.medium"
# }

# variable "instance_count" {
#   description = "Number of DocumentDB instances"
#   type        = number
#   default     = 1
# }

# variable "master_username" {
#   description = "Master username"
#   type        = string
#   default     = "docdbadmin"
# }

# variable "backup_retention_period" {
#   description = "Backup retention period in days"
#   type        = number
#   default     = 7
# }

# variable "preferred_backup_window" {
#   description = "Preferred backup window"
#   type        = string
#   default     = "03:00-04:00"
# }

# variable "skip_final_snapshot" {
#   description = "Skip final snapshot on deletion"
#   type        = bool
#   default     = false
# }

# variable "vpc_security_group_ids" {
#   description = "List of VPC security group IDs"
#   type        = list(string)
# }

# variable "subnet_ids" {
#   description = "List of subnet IDs"
#   type        = list(string)
# }

# variable "kms_key_id" {
#   description = "KMS key ID for encryption"
#   type        = string
#   default     = null
# }

# variable "master_password_secret_arn" {
#   description = "ARN of the master password secret (if external)"
#   type        = string
#   default     = ""
# }

# variable "tags" {
#   description = "Tags to apply to resources"
#   type        = map(string)
#   default     = {}
# }

# # terraform/modules/documentdb/outputs.tf
# output "cluster_id" {
#   description = "DocumentDB cluster ID"
#   value       = aws_docdb_cluster.main.id
# }

# output "cluster_arn" {
#   description = "DocumentDB cluster ARN"
#   value       = aws_docdb_cluster.main.arn
# }

# output "endpoint" {
#   description = "DocumentDB cluster endpoint"
#   value       = aws_docdb_cluster.main.endpoint
# }

# output "reader_endpoint" {
#   description = "DocumentDB cluster reader endpoint"
#   value       = aws_docdb_cluster.main.reader_endpoint
# }

# output "port" {
#   description = "DocumentDB port"
#   value       = 27017
# }

# output "master_password_secret_arn" {
#   description = "ARN of the master password secret"
#   value       = aws_secretsmanager_secret.master_password.arn
# }