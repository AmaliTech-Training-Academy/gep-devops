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

output "aws_credentials_secret_arn" {
  description = "ARN of the AWS credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.aws_credentials.arn
}

output "aws_credentials_secret_name" {
  description = "Name of the AWS credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.aws_credentials.name
}
