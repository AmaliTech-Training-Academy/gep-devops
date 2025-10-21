# # terraform/modules/acm/main.tf
# # ==============================================================================
# # ACM Module - SSL/TLS Certificate Management
# # ==============================================================================

# # Declare that this module accepts provider configurations
# terraform {
#   required_version = ">= 1.5.0"
  
#   required_providers {
#     aws = {
#       source                = "hashicorp/aws"
#       version               = "~> 5.0"
#       configuration_aliases = [aws.eu_west_1]
#     }
#   }
# }

# # ACM Certificate for ALB (Regional)
# resource "aws_acm_certificate" "alb" {
#   count = var.create_alb_certificate ? 1 : 0

#   domain_name               = var.domain_name
#   subject_alternative_names = var.subject_alternative_names
#   validation_method         = var.validation_method

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-alb-cert"
#       Environment = var.environment
#       Purpose     = "ALB SSL Certificate"
#     }
#   )
# }

# # ACM Certificate for CloudFront (must be in eu-west-1)
# resource "aws_acm_certificate" "cloudfront" {
#   count = var.create_cloudfront_certificate ? 1 : 0

#   provider = aws.us_east_1

#   domain_name               = var.cloudfront_domain_name != "" ? var.cloudfront_domain_name : var.domain_name
#   subject_alternative_names = var.cloudfront_subject_alternative_names
#   validation_method         = var.validation_method

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-cloudfront-cert"
#       Environment = var.environment
#       Purpose     = "CloudFront SSL Certificate"
#     }
#   )
# }

# # Route53 DNS validation records for ALB certificate
# resource "aws_route53_record" "alb_validation" {
#   for_each = var.create_alb_certificate && var.validation_method == "DNS" && var.route53_zone_id != "" ? {
#     for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   } : {}

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = var.route53_zone_id
# }

# # Route53 DNS validation records for CloudFront certificate
# resource "aws_route53_record" "cloudfront_validation" {
#   for_each = var.create_cloudfront_certificate && var.validation_method == "DNS" && var.route53_zone_id != "" ? {
#     for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   } : {}

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = var.route53_zone_id
# }

# # FIX: Certificate validation for ALB - increased timeout to 45 minutes
# resource "aws_acm_certificate_validation" "alb" {
#   count = var.create_alb_certificate && var.validation_method == "DNS" && var.route53_zone_id != "" ? 1 : 0

#   certificate_arn         = aws_acm_certificate.alb[0].arn
#   validation_record_fqdns = [for record in aws_route53_record.alb_validation : record.fqdn]

#   timeouts {
#     create = "45m"  # Increased from 10m to 45m for DNS propagation
#   }

#   depends_on = [aws_route53_record.alb_validation]
# }

# # FIX: Certificate validation for CloudFront - increased timeout to 45 minutes
# resource "aws_acm_certificate_validation" "cloudfront" {
#   count = var.create_cloudfront_certificate && var.validation_method == "DNS" && var.route53_zone_id != "" ? 1 : 0

#   provider = aws.eu_west_1

#   certificate_arn         = aws_acm_certificate.cloudfront[0].arn
#   validation_record_fqdns = [for record in aws_route53_record.cloudfront_validation : record.fqdn]

#   timeouts {
#     create = "45m"  # Increased from 10m to 45m for DNS propagation
#   }

#   depends_on = [aws_route53_record.cloudfront_validation]
# }

# # CloudWatch Metric Alarm for certificate expiration (ALB)
# resource "aws_cloudwatch_metric_alarm" "alb_cert_expiration" {
#   count = var.create_alb_certificate && var.enable_expiration_alarms ? 1 : 0

#   alarm_name          = "${var.project_name}-${var.environment}-alb-cert-expiration"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "DaysToExpiry"
#   namespace           = "AWS/CertificateManager"
#   period              = "86400" # 1 day
#   statistic           = "Minimum"
#   threshold           = var.expiration_days_threshold
#   alarm_description   = "ALB certificate expiring in ${var.expiration_days_threshold} days"
#   alarm_actions       = var.alarm_actions
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     CertificateArn = aws_acm_certificate.alb[0].arn
#   }

#   tags = var.common_tags
# }

# # CloudWatch Metric Alarm for certificate expiration (CloudFront)
# resource "aws_cloudwatch_metric_alarm" "cloudfront_cert_expiration" {
#   count = var.create_cloudfront_certificate && var.enable_expiration_alarms ? 1 : 0

#   provider = aws.eu_west_1

#   alarm_name          = "${var.project_name}-${var.environment}-cloudfront-cert-expiration"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "DaysToExpiry"
#   namespace           = "AWS/CertificateManager"
#   period              = "86400"
#   statistic           = "Minimum"
#   threshold           = var.expiration_days_threshold
#   alarm_description   = "CloudFront certificate expiring in ${var.expiration_days_threshold} days"
#   alarm_actions       = var.alarm_actions
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     CertificateArn = aws_acm_certificate.cloudfront[0].arn
#   }

#   tags = var.common_tags
# }