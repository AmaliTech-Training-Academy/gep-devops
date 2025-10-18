# terraform/modules/route53/main.tf
# ==============================================================================
# Route53 Module - DNS Management
# ==============================================================================

# Route53 Hosted Zone (optional - only if creating new zone)
resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0

  name    = var.domain_name
  comment = "Hosted zone for ${var.project_name} ${var.environment}"

  tags = merge(
    var.common_tags,
    {
      Name        = var.domain_name
      Environment = var.environment
    }
  )
}

# Data source for existing hosted zone
data "aws_route53_zone" "existing" {
  count = var.create_hosted_zone ? 0 : 1

  name         = var.domain_name
  private_zone = false
}

locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

# A Record for ALB (API subdomain)
resource "aws_route53_record" "alb" {
  count = var.create_alb_records ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.api_subdomain != "" ? "${var.api_subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# AAAA Record for ALB (IPv6)
resource "aws_route53_record" "alb_ipv6" {
  count = var.create_alb_records && var.enable_ipv6 ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.api_subdomain != "" ? "${var.api_subdomain}.${var.domain_name}" : var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# A Record for CloudFront (Frontend)
resource "aws_route53_record" "cloudfront" {
  count = var.create_cloudfront_records ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.frontend_subdomain != "" ? "${var.frontend_subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# AAAA Record for CloudFront (IPv6)
resource "aws_route53_record" "cloudfront_ipv6" {
  count = var.create_cloudfront_records && var.enable_ipv6 ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.frontend_subdomain != "" ? "${var.frontend_subdomain}.${var.domain_name}" : var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# WWW CNAME Record (redirect to main domain)
resource "aws_route53_record" "www" {
  count = var.create_www_record ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}

# Health Check for ALB
resource "aws_route53_health_check" "alb" {
  count = var.enable_health_checks && var.create_alb_records ? 1 : 0

  fqdn              = var.api_subdomain != "" ? "${var.api_subdomain}.${var.domain_name}" : var.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_interval

  measure_latency = true

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-alb-health-check"
      Environment = var.environment
    }
  )
}

# CloudWatch Alarm for Health Check
resource "aws_cloudwatch_metric_alarm" "health_check" {
  count = var.enable_health_checks && var.create_alb_records ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-route53-health-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Route53 health check failed for ${var.project_name}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb[0].id
  }

  tags = var.common_tags
}

# TXT Record for Domain Verification (e.g., for Google, etc.)
resource "aws_route53_record" "verification" {
  for_each = var.verification_records

  zone_id = local.hosted_zone_id
  name    = each.value.name != "" ? "${each.value.name}.${var.domain_name}" : var.domain_name
  type    = "TXT"
  ttl     = 300
  records = [each.value.value]
}

# MX Records for Email
resource "aws_route53_record" "mx" {
  count = length(var.mx_records) > 0 ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 3600
  records = var.mx_records
}

# SPF Record
resource "aws_route53_record" "spf" {
  count = var.spf_record != "" ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = [var.spf_record]
}

# DKIM Records for Email Authentication
resource "aws_route53_record" "dkim" {
  for_each = var.dkim_records

  zone_id = local.hosted_zone_id
  name    = each.value.name
  type    = "CNAME"
  ttl     = 300
  records = [each.value.value]
}

# DMARC Record
resource "aws_route53_record" "dmarc" {
  count = var.dmarc_record != "" ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = [var.dmarc_record]
}

# CAA Records for Certificate Authority Authorization
resource "aws_route53_record" "caa" {
  count = length(var.caa_records) > 0 ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "CAA"
  ttl     = 300
  records = var.caa_records
}