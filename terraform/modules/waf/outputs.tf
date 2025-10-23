# terraform/modules/waf/outputs.tf

# CloudFront WAF outputs
output "cloudfront_web_acl_id" {
  description = "ID of the CloudFront WAF Web ACL"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].id : ""
}

output "cloudfront_web_acl_arn" {
  description = "ARN of the CloudFront WAF Web ACL"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].arn : ""
}

# ALB WAF outputs
output "alb_web_acl_id" {
  description = "ID of the ALB WAF Web ACL"
  value       = var.enable_alb_waf ? aws_wafv2_web_acl.alb[0].id : ""
}

output "alb_web_acl_arn" {
  description = "ARN of the ALB WAF Web ACL"
  value       = var.enable_alb_waf ? aws_wafv2_web_acl.alb[0].arn : ""
}

# Legacy outputs (for backward compatibility)
output "web_acl_id" {
  description = "ID of the CloudFront WAF Web ACL (deprecated - use cloudfront_web_acl_id)"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].id : ""
}

output "web_acl_arn" {
  description = "ARN of the CloudFront WAF Web ACL (deprecated - use cloudfront_web_acl_arn)"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].arn : ""
}
