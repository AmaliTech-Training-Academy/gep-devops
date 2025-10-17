# # ==============================================================================
# # Outputs
# # ==============================================================================

# output "repository_urls" {
#   description = "URLs of ECR repositories"
#   value = {
#     for k, v in aws_ecr_repository.services : k => v.repository_url
#   }
# }

# output "repository_arns" {
#   description = "ARNs of ECR repositories"
#   value = {
#     for k, v in aws_ecr_repository.services : k => v.arn
#   }
# }

# output "repository_names" {
#   description = "Names of ECR repositories"
#   value = {
#     for k, v in aws_ecr_repository.services : k => v.name
#   }
# }

# output "registry_id" {
#   description = "Registry ID"
#   value       = data.aws_caller_identity.current.account_id
# }

# output "registry_url" {
#   description = "ECR registry URL"
#   value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
# }

