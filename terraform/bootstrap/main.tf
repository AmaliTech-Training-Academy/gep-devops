# terraform/bootstrap/main.tf
# ==============================================================================
# Terraform Backend Bootstrap Configuration - FIXED
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Module    = "Bootstrap"
      Purpose   = "State Management"
    }
  }
}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # S3 bucket name must be globally unique
  state_bucket_name = "${var.project_name}-terraform-state-${var.aws_region}-${data.aws_caller_identity.current.account_id}"

  # Shortened logs bucket name to stay under 63 character limit
  logs_bucket_name = "${var.project_name}-tf-logs-${data.aws_caller_identity.current.account_id}"

  # DynamoDB table for state locking
  lock_table_name = "${var.project_name}-terraform-locks"

  # Common tags for all resources
  common_tags = {
    Environment = "bootstrap"
    Module      = "terraform-backend"
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==============================================================================
# S3 Bucket for Terraform State
# ==============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name        = local.state_bucket_name
      Description = "Terraform state file storage"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# filter {} to lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    # FIX: Added empty filter to satisfy provider requirements
    filter {}

    # Keep only the 10 most recent versions
    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10
    }

    # Delete delete markers
    expiration {
      expired_object_delete_marker = true
    }
  }

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    # FIX: Added empty filter to satisfy provider requirements
    filter {}

    # Transition old versions to cheaper storage
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }
}

# Bucket policy to enforce TLS/HTTPS
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# 🔧 FIXED: Shortened bucket name to stay under 63 character limit
resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = local.logs_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name        = local.logs_bucket_name
      Description = "Access logs for Terraform state bucket"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable lifecycle for logs bucket
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

# Enable logging
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-access-logs/"
}

# ==============================================================================
# DynamoDB Table for State Locking
# ==============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_pitr
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name        = local.lock_table_name
      Description = "Terraform state locking and consistency"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# ==============================================================================
# CloudWatch Alarms for Monitoring
# ==============================================================================

resource "aws_sns_topic" "terraform_state_alerts" {
  name = "${var.project_name}-terraform-state-alerts"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-terraform-state-alerts"
    }
  )
}

resource "aws_sns_topic_subscription" "terraform_state_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.terraform_state_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_high_reads" {
  alarm_name          = "${local.lock_table_name}-high-reads"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors DynamoDB read capacity"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]

  dimensions = {
    TableName = aws_dynamodb_table.terraform_locks.name
  }

  tags = local.common_tags
}