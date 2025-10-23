# terraform/modules/acm/main.tf
# ==============================================================================
# ACM Module - SSL/TLS Certificate Management (Manual DNS Validation)
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ACM Certificate for ALB (Regional - eu-west-1)
resource "aws_acm_certificate" "alb" {
  count = var.create_alb_certificate ? 1 : 0

  domain_name               = var.alb_domain_name
  subject_alternative_names = var.alb_subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-alb-cert"
      Environment = var.environment
      Purpose     = "ALB SSL Certificate"
      Domain      = var.alb_domain_name
    }
  )
}

# ACM Certificate for CloudFront (MUST be in us-east-1)
resource "aws_acm_certificate" "cloudfront" {
  count = var.create_cloudfront_certificate ? 1 : 0

  provider = aws.us_east_1

  domain_name               = var.cloudfront_domain_name
  subject_alternative_names = var.cloudfront_subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-cloudfront-cert"
      Environment = var.environment
      Purpose     = "CloudFront SSL Certificate"
      Domain      = var.cloudfront_domain_name
    }
  )
}
