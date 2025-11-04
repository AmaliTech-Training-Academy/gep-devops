# terraform/modules/iam/main.tf
# ==============================================================================
# IAM Module - Digital Identity and Access Management (Employee ID Badges)
# ==============================================================================
# WHAT THIS MODULE DOES:
# Creates digital identity badges and permission sets for our applications,
# controlling exactly what each service can and cannot access in AWS.
# Think of it like creating employee ID badges with specific access levels
# for different departments in our company.
#
# BUSINESS PURPOSE:
# - Security: Prevents unauthorized access to sensitive data and systems
# - Compliance: Meets regulatory requirements for access control
# - Audit Trail: Tracks who accessed what resources and when
# - Risk Management: Limits damage if a service is compromised
#
# PERMISSION STRATEGY:
# "Least Privilege Principle" - Each service gets only the minimum permissions
# needed to do its job, nothing more. Like giving each employee only the keys
# they need for their specific role.
#
# ROLES CREATED:
# 1. Task Execution Role: Master key for AWS to manage containers
# 2. Auth Service Role: Permissions for user management and email
# 3. Event Service Role: Permissions for event management and notifications
# 4. Booking Service Role: Permissions for reservation processing
# 5. Payment Service Role: Permissions for payment processing
# 6. Notification Service Role: Permissions for email and SMS sending
#
# BUSINESS IMPACT:
# - Protects customer data from unauthorized access
# - Enables secure communication between services
# - Supports compliance with data protection regulations
# - Reduces security risks and potential data breaches
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
# ECS Task Execution Role - Master Container Management Badge
# ==============================================================================
# WHAT THIS ROLE DOES:
# Provides AWS with the permissions needed to manage our application containers.
# Like giving the building manager a master key to start/stop office equipment,
# turn on lights, and access utility systems for all departments.
#
# PERMISSIONS GRANTED:
# - Pull application images from our private container registry
# - Write application logs to CloudWatch for monitoring
# - Retrieve database passwords and API keys from secure storage
# - Start and stop application containers as needed
#
# SECURITY NOTE:
# This role is used by AWS infrastructure, not by our applications directly.
# It's like the building management company having access to building systems
# but not to individual office files and documents.

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
      Name      = "${var.project_name}-${var.environment}-ecs-execution-role"
      Service   = "ecs"
      Component = "task-execution"
      Purpose   = "container-runtime"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy for Secrets Manager access (DB secrets + JWT secret + AWS credentials)
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
        Resource = concat(
          var.db_secrets_arns,
          var.jwt_secret_arn != null ? [var.jwt_secret_arn] : [],
          [
            "arn:aws:secretsmanager:*:*:secret:event-planner/*/aws-credentials-*",
            "arn:aws:secretsmanager:*:*:secret:event-planner/*/google-credentials-*"
          ]
        )
      }
    ]
  })
}

# ==============================================================================
# Service-Specific Roles - Department Access Badges
# ==============================================================================
# WHAT THESE ROLES DO:
# Provide each business service with specific permissions needed for their function.
# Like giving each department head access only to their department's resources
# and the shared services they need to do their job.
#
# PERMISSION PHILOSOPHY:
# Each service gets exactly what it needs, nothing more:
# - Auth Service: Can send emails and manage user files
# - Event Service: Can publish notifications and manage event files
# - Booking Service: Can process reservations and send confirmations
# - Payment Service: Can process payments and send receipts
# - Notification Service: Can send emails, SMS, and manage message queues

# Auth Service Role - User Management Department Badge
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
      Name      = "${var.project_name}-${var.environment}-auth-service-task-role"
      Service   = "auth-service"
      Component = "task-role"
      Purpose   = "service-permissions"
    }
  )
}

# Auth Service Permissions - What the User Management Department Can Do
resource "aws_iam_role_policy" "auth_service_task" {
  name_prefix = "auth-service-permissions-"
  role        = aws_iam_role.auth_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",      # Send welcome emails to new users
          "ses:SendRawEmail"    # Send password reset emails
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
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = "arn:aws:sqs:*:*:event-planner-*"
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
      Name      = "${var.project_name}-${var.environment}-event-service-task-role"
      Service   = "event-service"
      Component = "task-role"
      Purpose   = "service-permissions"
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
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = "arn:aws:sqs:*:*:event-planner-*"
      }
    ]
  })
}

# Booking Service Task Role
resource "aws_iam_role" "booking_service_task" {
  name_prefix = "${var.project_name}-${var.environment}-booking-task-"

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
      Name      = "${var.project_name}-${var.environment}-booking-service-task-role"
      Service   = "booking-service"
      Component = "task-role"
      Purpose   = "service-permissions"
    }
  )
}

resource "aws_iam_role_policy" "booking_service_task" {
  name_prefix = "booking-service-permissions-"
  role        = aws_iam_role.booking_service_task.id

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
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = "arn:aws:sqs:*:*:event-planner-*"
      }
    ]
  })
}

# Payment Service Task Role
resource "aws_iam_role" "payment_service_task" {
  name_prefix = "${var.project_name}-${var.environment}-payment-task-"

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
      Name      = "${var.project_name}-${var.environment}-payment-service-task-role"
      Service   = "payment-service"
      Component = "task-role"
      Purpose   = "service-permissions"
    }
  )
}

resource "aws_iam_role_policy" "payment_service_task" {
  name_prefix = "payment-service-permissions-"
  role        = aws_iam_role.payment_service_task.id

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
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = "arn:aws:sqs:*:*:event-planner-*"
      }
    ]
  })
}

# Notification Service Task Role
resource "aws_iam_role" "notification_service_task" {
  name_prefix = "${var.project_name}-${var.environment}-notification-task-"

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
      Name      = "${var.project_name}-${var.environment}-notification-service-task-role"
      Service   = "notification-service"
      Component = "task-role"
      Purpose   = "service-permissions"
    }
  )
}

resource "aws_iam_role_policy" "notification_service_task" {
  name_prefix = "notification-service-permissions-"
  role        = aws_iam_role.notification_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EmailAndSMSPermissions"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail",
          "ses:GetSendQuota",
          "sns:Publish",
          "sns:Subscribe",
          "sns:Unsubscribe"
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSPermissions"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility",
          "sqs:CreateQueue",
          "sqs:ListQueues"
        ]
        Resource = "arn:aws:sqs:*:*:event-planner-*"
      },
      {
        Sid    = "CloudWatchLogsPermissions"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/ecs/*"
      }
    ]
  })
}

