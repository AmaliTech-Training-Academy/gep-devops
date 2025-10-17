# terraform/bootstrap/main.tf
# ==============================================================================
# Terraform Backend Bootstrap Configuration
# ==============================================================================
# This module creates the S3 bucket and DynamoDB table required for Terraform
# remote state management. Run this ONCE before deploying any environments.
#
# Purpose:
#   - S3 bucket for storing Terraform state files
#   - DynamoDB table for state locking and consistency
#   - Encryption and versioning for state file security
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform plan
#   terraform apply
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
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Module      = "Bootstrap"
      Purpose     = "State Management"
    }
  }
}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # S3 bucket name must be globally unique
  state_bucket_name = "${var.project_name}-terraform-state-${var.aws_region}-${data.aws_caller_identity.current.account_id}"
  
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

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# ==============================================================================
# S3 Bucket for Terraform State
# ==============================================================================

# Create S3 bucket for Terraform state storage
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
    prevent_destroy = true  # Prevent accidental deletion
  }
}

# Enable versioning for state file history and recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true  # Reduce KMS API calls for cost optimization
  }
}

# Block all public access to the state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable lifecycle policy for old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    
    # Keep only the 10 most recent versions of state files
    noncurrent_version_expiration {
      noncurrent_days = 90
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
    
    # Transition old versions to cheaper storage after 30 days
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
        Sid    = "EnforceTLS"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
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

# Enable logging for security audit
resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "${local.state_bucket_name}-logs"
  
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.state_bucket_name}-logs"
      Description = "Access logs for Terraform state bucket"
    }
  )
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-access-logs/"
}

# ==============================================================================
# DynamoDB Table for State Locking
# ==============================================================================

# Create DynamoDB table for state locking and consistency
resource "aws_dynamodb_table" "terraform_locks" {
  name           = local.lock_table_name
  billing_mode   = "PAY_PER_REQUEST"  # On-demand pricing for cost optimization
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  # Enable point-in-time recovery for production safety
  point_in_time_recovery {
    enabled = var.enable_dynamodb_pitr
  }
  
  # Enable server-side encryption
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
    prevent_destroy = true  # Prevent accidental deletion
  }
}

# ==============================================================================
# CloudWatch Alarms for Monitoring
# ==============================================================================

# Create SNS topic for alerts
resource "aws_sns_topic" "terraform_state_alerts" {
  name = "${var.project_name}-terraform-state-alerts"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-terraform-state-alerts"
    }
  )
}

# Subscribe email to SNS topic
resource "aws_sns_topic_subscription" "terraform_state_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.terraform_state_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarm for excessive DynamoDB read capacity
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


