# # terraform/modules/ecs/main.tf
# # ==============================================================================
# # ECS Module - Container Orchestration
# # ==============================================================================

# # ECS Cluster
# resource "aws_ecs_cluster" "main" {
#   name = "${var.project_name}-${var.environment}-cluster"

#   setting {
#     name  = "containerInsights"
#     value = var.enable_container_insights ? "enabled" : "disabled"
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-ecs-cluster"
#       Environment = var.environment
#     }
#   )
# }

# # ECS Cluster Capacity Providers
# resource "aws_ecs_cluster_capacity_providers" "main" {
#   cluster_name = aws_ecs_cluster.main.name

#   capacity_providers = ["FARGATE", "FARGATE_SPOT"]

#   default_capacity_provider_strategy {
#     capacity_provider = var.use_spot_instances ? "FARGATE_SPOT" : "FARGATE"
#     weight            = 1
#     base              = 1
#   }
# }

# # ECS Task Execution Role
# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = var.common_tags
# }

# # Attach AWS managed policy for ECS task execution
# resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# # Additional policy for Secrets Manager and Parameter Store access
# resource "aws_iam_role_policy" "ecs_task_execution_secrets_policy" {
#   name = "${var.project_name}-${var.environment}-ecs-secrets-policy"
#   role = aws_iam_role.ecs_task_execution_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "ssm:GetParameters",
#           "kms:Decrypt"
#         ]
#         Resource = ["*"]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = ["*"]
#       }
#     ]
#   })
# }

# # ECS Task Role (for application runtime permissions)
# resource "aws_iam_role" "ecs_task_role" {
#   name = "${var.project_name}-${var.environment}-ecs-task-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = var.common_tags
# }

# # Task role policy for application permissions
# resource "aws_iam_role_policy" "ecs_task_role_policy" {
#   name = "${var.project_name}-${var.environment}-ecs-task-policy"
#   role = aws_iam_role.ecs_task_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket"
#         ]
#         Resource = var.s3_bucket_arns
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "ses:SendEmail",
#           "ses:SendRawEmail"
#         ]
#         Resource = ["*"]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "sns:Publish"
#         ]
#         Resource = var.sns_topic_arns
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "sqs:SendMessage",
#           "sqs:ReceiveMessage",
#           "sqs:DeleteMessage",
#           "sqs:GetQueueAttributes"
#         ]
#         Resource = var.sqs_queue_arns
#       }
#     ]
#   })
# }

# # CloudWatch Log Group for ECS
# resource "aws_cloudwatch_log_group" "ecs" {
#   name              = "/ecs/${var.project_name}-${var.environment}"
#   retention_in_days = var.log_retention_days

#   tags = var.common_tags
# }

# # Security Group for ECS Tasks
# resource "aws_security_group" "ecs_tasks" {
#   name        = "${var.project_name}-${var.environment}-ecs-tasks-sg"
#   description = "Security group for ECS tasks"
#   vpc_id      = var.vpc_id

#   ingress {
#     description     = "Allow traffic from ALB"
#     from_port       = 0
#     to_port         = 65535
#     protocol        = "tcp"
#     security_groups = var.alb_security_group_ids
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
#     }
#   )
# }

# # ECS Service Discovery Namespace
# resource "aws_service_discovery_private_dns_namespace" "main" {
#   count = var.enable_service_discovery ? 1 : 0

#   name        = "${var.environment}.${var.project_name}.local"
#   description = "Service discovery namespace for ${var.project_name}"
#   vpc         = var.vpc_id

#   tags = var.common_tags
# }



