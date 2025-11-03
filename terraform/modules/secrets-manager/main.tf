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
# AWS Credentials Secret (for services to access AWS resources)
# ==============================================================================

resource "aws_secretsmanager_secret" "aws_credentials" {
  name                    = "${var.project_name}/${var.environment}/aws-credentials"
  description             = "AWS credentials for ECS services to access AWS resources"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aws-credentials"
    }
  )
}

# AWS credentials secret version - managed externally
# The secret already exists with proper credentials
resource "aws_secretsmanager_secret_version" "aws_credentials" {
  secret_id = aws_secretsmanager_secret.aws_credentials.id
  secret_string = jsonencode({
    access_key = "PLACEHOLDER_ACCESS_KEY"
    secret_key = "PLACEHOLDER_SECRET_KEY"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ==============================================================================
# Google Email Credentials Secret (for notification service)
# ==============================================================================

resource "aws_secretsmanager_secret" "google_credentials" {
  name                    = "${var.project_name}/${var.environment}/google-credentials"
  description             = "Google email credentials for notification service"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-google-credentials"
      Service = "notification-service"
    }
  )
}

# Google credentials secret version - managed externally
# The secret must be manually populated with actual credentials
resource "aws_secretsmanager_secret_version" "google_credentials" {
  secret_id = aws_secretsmanager_secret.google_credentials.id
  secret_string = jsonencode({
    GOOGLE_USER     = "PLACEHOLDER_GOOGLE_USER"
    GOOGLE_PASSWORD = "PLACEHOLDER_GOOGLE_PASSWORD"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
