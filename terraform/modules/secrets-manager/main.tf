# ==============================================================================
# Secrets Manager Module - JWT Secret Generation
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ==============================================================================
# Generate Random JWT Secret
# ==============================================================================

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# ==============================================================================
# Create Secret in AWS Secrets Manager
# ==============================================================================

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}-${var.environment}-jwt-secret"
  description             = "JWT signing secret for ${var.project_name} ${var.environment} auth service"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-jwt-secret"
      Service = "auth-service"
    }
  )
}

# ==============================================================================
# Store JWT Secret Value
# ==============================================================================

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    JWT_SECRET = random_password.jwt_secret.result
  })
}

# ==============================================================================
# AWS Credentials Secret for ECS Services
# ==============================================================================

resource "aws_secretsmanager_secret" "aws_credentials" {
  name                    = "${var.project_name}-${var.environment}-aws-credentials"
  description             = "AWS credentials for ECS services in ${var.environment}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aws-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "aws_credentials" {
  secret_id = aws_secretsmanager_secret.aws_credentials.id
  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
  })
}
