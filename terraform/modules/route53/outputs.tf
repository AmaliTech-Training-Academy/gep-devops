# # terraform/modules/route53/outputs.tf
# output "hosted_zone_id" {
#   description = "Hosted zone ID"
#   value       = local.hosted_zone_id
# }

# output "hosted_zone_name_servers" {
#   description = "Hosted zone name servers"
#   value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
# }

# output "alb_record_name" {
#   description = "ALB record name"
#   value       = var.alb_dns_name != "" ? aws_route53_record.alb[0].name : null
# }

# output "cloudfront_record_name" {
#   description = "CloudFront record name"
#   value       = var.cloudfront_domain_name != "" ? aws_route53_record.cloudfront[0].name : null
# }

# output "health_check_id" {
#   description = "Health check ID"
#   value       = var.enable_health_checks && var.alb_dns_name != "" ? aws_route53_health_check.alb[0].id : null
# }