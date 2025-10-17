# terraform/modules/acm/providers.tf
# Provider configuration for us-east-1 (required for CloudFront certificates)
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# terraform/modules/acm/outputs.tf
output "alb_certificate_arn" {
  description = "ARN of the ALB certificate"
  value       = var.create_alb_certificate ? aws_acm_certificate.alb[0].arn : null
}

output "alb_certificate_status" {
  description = "Status of the ALB certificate"
  value       = var.create_alb_certificate ? aws_acm_certificate.alb[0].status : null
}

output "alb_certificate_domain_validation_options" {
  description = "Domain validation options for ALB certificate"
  value       = var.create_alb_certificate ? aws_acm_certificate.alb[0].domain_validation_options : null
}

output "cloudfront_certificate_arn" {
  description = "ARN of the CloudFront certificate"
  value       = var.create_cloudfront_certificate ? aws_acm_certificate.cloudfront[0].arn : null
}

output "cloudfront_certificate_status" {
  description = "Status of the CloudFront certificate"
  value       = var.create_cloudfront_certificate ? aws_acm_certificate.cloudfront[0].status : null
}

output "cloudfront_certificate_domain_validation_options" {
  description = "Domain validation options for CloudFront certificate"
  value       = var.create_cloudfront_certificate ? aws_acm_certificate.cloudfront[0].domain_validation_options : null
}