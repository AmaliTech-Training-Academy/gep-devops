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

# AWS credentials removed - services use IAM roles for AWS access

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

# ==============================================================================
# Paystack Credentials Secret (for payment service)
# ==============================================================================

resource "aws_secretsmanager_secret" "paystack_credentials" {
  name                    = "${var.project_name}/${var.environment}/paystack-credentials"
  description             = "Paystack API credentials for payment service"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-paystack-credentials"
      Service = "payment-service"
    }
  )
}

# Paystack secret version - managed externally for security
# The secret must be manually populated with actual credentials
resource "aws_secretsmanager_secret_version" "paystack_credentials" {
  secret_id = aws_secretsmanager_secret.paystack_credentials.id
  secret_string = jsonencode({
    PAYSTACK_SECRET = "PLACEHOLDER_PAYSTACK_SECRET"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ==============================================================================
# Redis Auth Token Secret (for ElastiCache authentication)
# ==============================================================================

resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "redis_credentials" {
  name                    = "${var.project_name}/${var.environment}/redis-credentials"
  description             = "Redis authentication token for ElastiCache"
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = aws_secretsmanager_secret.redis_credentials.id
  secret_string = jsonencode({
    REDIS_AUTH_TOKEN = random_password.redis_auth_token.result
  })
}
