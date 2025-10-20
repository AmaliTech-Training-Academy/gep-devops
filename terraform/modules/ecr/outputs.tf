# ==============================================================================
# Outputs
# ==============================================================================

output "repository_urls" {
  description = "Map of service names to ECR repository URLs"
  value = {
    for service in local.microservices :
    service => aws_ecr_repository.microservices[service].repository_url
  }
}

output "repository_arns" {
  description = "Map of service names to ECR repository ARNs"
  value = {
    for service in local.microservices :
    service => aws_ecr_repository.microservices[service].arn
  }
}

output "repository_names" {
  description = "Map of service names to ECR repository names"
  value = {
    for service in local.microservices :
    service => aws_ecr_repository.microservices[service].name
  }
}