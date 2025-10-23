# terraform/modules/acm/outputs.tf
output "alb_certificate_arn" {
  description = "ARN of the ALB certificate"
  value       = var.create_alb_certificate ? aws_acm_certificate.alb[0].arn : ""
}

output "alb_certificate_status" {
  description = "Status of ALB certificate"
  value       = var.create_alb_certificate ? aws_acm_certificate.alb[0].status : ""
}

output "alb_validation_records" {
  description = "DNS validation records for ALB certificate - ADD TO CLOUDFLARE"
  value = var.create_alb_certificate ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
    }
  } : {}
}

output "cloudfront_certificate_arn" {
  description = "ARN of the CloudFront certificate"
  value       = var.create_cloudfront_certificate ? aws_acm_certificate.cloudfront[0].arn : ""
}

output "cloudfront_certificate_status" {
  description = "Status of CloudFront certificate"
  value       = var.create_cloudfront_certificate ? aws_acm_certificate.cloudfront[0].status : ""
}

output "cloudfront_validation_records" {
  description = "DNS validation records for CloudFront certificate - ADD TO CLOUDFLARE"
  value = var.create_cloudfront_certificate ? {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
    }
  } : {}
}
