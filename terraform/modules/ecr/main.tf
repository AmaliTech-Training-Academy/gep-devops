# ==============================================================================
# ECR Module - Container Image Registry
# ==============================================================================
# This module creates ECR repositories for all microservices with:
# - Image scanning on push
# - Lifecycle policies for cost optimization
# - Cross-region replication for DR
# - Image tagging immutability
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

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # List of microservices
  microservices = [
    "auth-service",
    "event-service",
    "booking-service",
    "payment-service",
    "notification-service"
  ]

  common_tags = merge(
    var.tags,
    {
      Module      = "ecr"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# ECR Repositories
# ==============================================================================

# Create ECR repository for each microservice
resource "aws_ecr_repository" "microservices" {
  for_each = toset(local.microservices)

  name                 = "${var.project_name}-${var.environment}-${each.value}"
  image_tag_mutability = var.image_tag_mutability

  # Enable image scanning on push for security
  image_scanning_configuration {
    scan_on_push = var.enable_image_scanning
  }

  # Encryption configuration
  encryption_configuration {
    encryption_type = var.kms_key_arn != null ? "KMS" : "AES256"
    kms_key         = var.kms_key_arn
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-${each.value}"
      Service     = each.value
      Environment = var.environment
    }
  )
}

# ==============================================================================
# Lifecycle Policies
# ==============================================================================

# Lifecycle policy to manage image retention
resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each = toset(local.microservices)

  repository = aws_ecr_repository.microservices[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than ${var.untagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ==============================================================================
# Repository Policies (Cross-Account Access)
# ==============================================================================

# Repository policy for CI/CD access
resource "aws_ecr_repository_policy" "microservices" {
  for_each = var.enable_cross_account_access ? toset(local.microservices) : []

  repository = aws_ecr_repository.microservices[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_account_ids
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# ==============================================================================
# Replication Configuration (DR)
# ==============================================================================

# Cross-region replication for disaster recovery
resource "aws_ecr_replication_configuration" "this" {
  count = var.enable_replication ? 1 : 0

  replication_configuration {
    rule {
      destination {
        region      = var.replication_region
        registry_id = data.aws_caller_identity.current.account_id
      }

      # Only replicate tagged images
      repository_filter {
        filter      = "${var.project_name}-${var.environment}-*"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_caller_identity" "current" {}

