# terraform/modules/s3/outputs.tf
output "assets_bucket_id" {
  description = "Assets bucket ID"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_arn" {
  description = "Assets bucket ARN"
  value       = aws_s3_bucket.assets.arn
}

output "assets_bucket_domain_name" {
  description = "Assets bucket domain name"
  value       = aws_s3_bucket.assets.bucket_domain_name
}

output "assets_bucket_regional_domain_name" {
  description = "Assets bucket regional domain name"
  value       = aws_s3_bucket.assets.bucket_regional_domain_name
}

output "backups_bucket_id" {
  description = "Backups bucket ID"
  value       = aws_s3_bucket.backups.id
}

output "backups_bucket_arn" {
  description = "Backups bucket ARN"
  value       = aws_s3_bucket.backups.arn
}

output "logs_bucket_id" {
  description = "Logs bucket ID"
  value       = var.enable_access_logging ? aws_s3_bucket.logs[0].id : null
}

output "logs_bucket_arn" {
  description = "Logs bucket ARN"
  value       = var.enable_access_logging ? aws_s3_bucket.logs[0].arn : null
}

output "backend_files_bucket_id" {
  description = "Backend files bucket ID"
  value       = aws_s3_bucket.backend_files.id
}

output "backend_files_bucket_arn" {
  description = "Backend files bucket ARN"
  value       = aws_s3_bucket.backend_files.arn
}