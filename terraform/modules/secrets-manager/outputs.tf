# ==============================================================================
# Secrets Manager Module Outputs
# ==============================================================================

output "jwt_secret_arn" {
  description = "ARN of the JWT secret in Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "jwt_secret_name" {
  description = "Name of the JWT secret in Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

# AWS credentials outputs removed - services use IAM roles

output "google_credentials_secret_arn" {
  description = "ARN of the Google credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.google_credentials.arn
}

output "google_credentials_secret_name" {
  description = "Name of the Google credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.google_credentials.name
}

output "paystack_credentials_secret_arn" {
  description = "ARN of the Paystack credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.paystack_credentials.arn
}

output "paystack_credentials_secret_name" {
  description = "Name of the Paystack credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.paystack_credentials.name
}

output "redis_credentials_secret_arn" {
  description = "ARN of the Redis credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.redis_credentials.arn
}

output "redis_credentials_secret_name" {
  description = "Name of the Redis credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.redis_credentials.name
}

output "redis_auth_token" {
  description = "Redis authentication token (for ElastiCache configuration)"
  value       = random_password.redis_auth_token.result
  sensitive   = true
}
