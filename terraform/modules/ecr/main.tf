# # terraform/modules/ecr/main.tf
# # ==============================================================================
# # ECR Module - Elastic Container Registry
# # ==============================================================================
# # This module creates ECR repositories for all microservices with:
# # - Image scanning on push (security)
# # - Lifecycle policies (cost optimization)
# # - Cross-region replication (DR)
# # - Encryption at rest
# # - IAM policies for CI/CD access
# # ==============================================================================

# terraform {
#   required_version = ">= 1.5.0"

#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# # ==============================================================================
# # Local Variables
# # ==============================================================================

# locals {
#   # List of all microservices that need ECR repositories
#   microservices = [
#     "auth-service",
#     "event-service",
#     "booking-service",
#     "payment-service",
#     "notification-service"
#   ]

#   # Common tags
#   common_tags = merge(
#     var.tags,
#     {
#       Module      = "ecr"
#       Environment = var.environment
#     }
#   )
# }

# # ==============================================================================
# # ECR Repositories
# # ==============================================================================

# # Create ECR repository for each microservice
# resource "aws_ecr_repository" "services" {
#   for_each = toset(local.microservices)

#   name                 = "${var.project_name}/${each.value}"
#   image_tag_mutability = "MUTABLE"

#   # Enable image scanning for security vulnerabilities
#   image_scanning_configuration {
#     scan_on_push = true
#   }

#   # Enable encryption at rest
#   encryption_configuration {
#     encryption_type = "AES256"  # Use KMS for production
#   }

#   tags = merge(
#     local.common_tags,
#     {
#       Name    = "${var.project_name}/${each.value}"
#       Service = each.value
#     }
#   )
# }

# # ==============================================================================
# # Lifecycle Policies (Cost Optimization)
# # ==============================================================================

# # Lifecycle policy to clean up old images
# resource "aws_ecr_lifecycle_policy" "services" {
#   for_each   = aws_ecr_repository.services
#   repository = each.value.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 10 images"
#         selection = {
#           tagStatus     = "tagged"
#           tagPrefixList = ["v"]
#           countType     = "imageCountMoreThan"
#           countNumber   = 10
#         }
#         action = {
#           type = "expire"
#         }
#       },
#       {
#         rulePriority = 2
#         description  = "Remove untagged images after 7 days"
#         selection = {
#           tagStatus   = "untagged"
#           countType   = "sinceImagePushed"
#           countUnit   = "days"
#           countNumber = 7
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }

# # ==============================================================================
# # Repository Policies (CI/CD Access)
# # ==============================================================================

# # Allow GitHub Actions to push images
# resource "aws_ecr_repository_policy" "services" {
#   for_each   = aws_ecr_repository.services
#   repository = each.value.name

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowPushPull"
#         Effect = "Allow"
#         Principal = {
#           AWS = var.cicd_role_arns
#         }
#         Action = [
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:PutImage",
#           "ecr:InitiateLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:CompleteLayerUpload",
#           "ecr:DescribeRepositories",
#           "ecr:GetRepositoryPolicy",
#           "ecr:ListImages",
#           "ecr:DescribeImages"
#         ]
#       }
#     ]
#   })
# }

# # ==============================================================================
# # Cross-Region Replication (DR - Optional)
# # ==============================================================================

# # Replication configuration for disaster recovery
# resource "aws_ecr_replication_configuration" "main" {
#   count = var.enable_replication ? 1 : 0

#   replication_configuration {
#     rule {
#       destination {
#         region      = var.replication_region
#         registry_id = data.aws_caller_identity.current.account_id
#       }

#       repository_filter {
#         filter      = "${var.project_name}/*"
#         filter_type = "PREFIX_MATCH"
#       }
#     }
#   }
# }

# # ==============================================================================
# # Data Sources
# # ==============================================================================

# data "aws_caller_identity" "current" {}

# data "aws_region" "current" {}

