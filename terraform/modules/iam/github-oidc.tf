# # ==============================================================================
# # GitHub OIDC Provider for GitHub Actions
# # ==============================================================================

# # OIDC Identity Provider for GitHub
# resource "aws_iam_openid_connect_provider" "github" {
#   url = "https://token.actions.githubusercontent.com"

#   client_id_list = [
#     "sts.amazonaws.com"
#   ]

#   thumbprint_list = [
#     "6938fd4d98bab03faadb97b34396831e3780aea1",
#     "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
#   ]

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-${var.environment}-github-oidc"
#     }
#   )
# }

# # IAM Role for GitHub Actions
# resource "aws_iam_role" "github_actions" {
#   name = "${var.project_name}-${var.environment}-github-actions"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = aws_iam_openid_connect_provider.github.arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
#           }
#           StringLike = {
#             "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
#           }
#         }
#       }
#     ]
#   })

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-${var.environment}-github-actions-role"
#     }
#   )
# }

# # Policy for GitHub Actions (Terraform, ECS, ECR)
# resource "aws_iam_role_policy" "github_actions" {
#   name = "github-actions-permissions"
#   role = aws_iam_role.github_actions.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       # Terraform state management
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket"
#         ]
#         Resource = [
#           var.terraform_state_bucket_arn,
#           "${var.terraform_state_bucket_arn}/*"
#         ]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "dynamodb:GetItem",
#           "dynamodb:PutItem",
#           "dynamodb:DeleteItem"
#         ]
#         Resource = var.terraform_lock_table_arn
#       },
#       # ECR permissions
#       {
#         Effect = "Allow"
#         Action = [
#           "ecr:GetAuthorizationToken",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:PutImage",
#           "ecr:InitiateLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:CompleteLayerUpload"
#         ]
#         Resource = "*"
#       },
#       # ECS deployment permissions
#       {
#         Effect = "Allow"
#         Action = [
#           "ecs:UpdateService",
#           "ecs:DescribeServices",
#           "ecs:DescribeTaskDefinition",
#           "ecs:RegisterTaskDefinition"
#         ]
#         Resource = "*"
#       },
#       # Infrastructure permissions (minimal for Terraform)
#       {
#         Effect = "Allow"
#         Action = [
#           "ec2:Describe*",
#           "rds:Describe*",
#           "elasticache:Describe*",
#           "elbv2:Describe*",
#           "cloudfront:Get*",
#           "route53:Get*",
#           "acm:Describe*",
#           "secretsmanager:DescribeSecret"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }