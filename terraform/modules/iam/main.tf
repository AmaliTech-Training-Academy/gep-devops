# terraform/modules/iam/main.tf
# ==============================================================================
# IAM Module - Roles and Policies
# ==============================================================================
# This module creates IAM roles and policies for ECS tasks following the
# principle of least privilege.
#
# Roles Created:
# - ECS Task Execution Role (pull images, write logs, read secrets)
# - ECS Task Roles per microservice (service-specific permissions)
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
# ECS Task Execution Role
# ==============================================================================
# This role is used by ECS to pull container images, write logs, and retrieve
# secrets. It's the same for all services.

resource "aws_iam_role" "ecs_task_execution" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-execution-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-execution-role"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name_prefix = "secrets-access-"
  role        = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.db_secrets_arns
      }
    ]
  })
}

# ==============================================================================
# ECS Task Roles (Service-Specific)
# ==============================================================================

# Auth Service Task Role
resource "aws_iam_role" "auth_service_task" {
  name_prefix = "${var.project_name}-${var.environment}-auth-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-auth-service-task-role"
    }
  )
}

resource "aws_iam_role_policy" "auth_service_task" {
  name_prefix = "auth-service-permissions-"
  role        = aws_iam_role.auth_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${var.frontend_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Event Service Task Role
resource "aws_iam_role" "event_service_task" {
  name_prefix = "${var.project_name}-${var.environment}-event-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-event-service-task-role"
    }
  )
}

resource "aws_iam_role_policy" "event_service_task" {
  name_prefix = "event-service-permissions-"
  role        = aws_iam_role.event_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:*:*:event-planner-*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.frontend_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Similar roles for other services (booking, payment, notification)
# ... (following same pattern)

