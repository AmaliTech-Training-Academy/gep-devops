# terraform/modules/acm/main.tf
# ==============================================================================
# ACM Module - SSL/TLS Certificate Management (Manual DNS Validation)
# ==============================================================================
# WHAT THIS MODULE DOES:
# Creates SSL/TLS certificates for secure HTTPS connections to our website.
# Like getting a digital security badge that proves our website is legitimate
# and encrypts all data between users and our servers.
#
# BUSINESS PURPOSE:
# - Enables secure HTTPS connections (padlock icon in browser)
# - Protects customer data during transmission
# - Builds trust with users (browsers show "Secure" label)
# - Required for PCI compliance (payment processing)
# - Prevents man-in-the-middle attacks
#
# CERTIFICATES CREATED:
# 1. ALB Certificate (Regional): For backend API (api.sankofagrid.com)
# 2. CloudFront Certificate (us-east-1): For frontend website (events.sankofagrid.com)
#
# VALIDATION METHOD:
# DNS validation - requires adding DNS records to prove domain ownership
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]  # CloudFront certificates MUST be in us-east-1
    }
  }
}

# ==============================================================================
# ALB Certificate - Backend API Security Badge
# ==============================================================================
# WHAT THIS CREATES:
# SSL certificate for our backend API load balancer (api.sankofagrid.com).
# Enables secure HTTPS connections for all API requests from frontend to backend.
#
# REGIONAL REQUIREMENT:
# Created in the same region as the ALB (eu-west-1 for our case).
# Each AWS region requires its own certificate.
#
# VALIDATION:
# Requires adding DNS TXT records to prove we own the domain.
# Certificate status changes from "Pending" to "Issued" after validation.

resource "aws_acm_certificate" "alb" {
  count = var.create_alb_certificate ? 1 : 0  # Only create if enabled

  domain_name               = var.alb_domain_name                # Main domain (api.sankofagrid.com)
  subject_alternative_names = var.alb_subject_alternative_names  # Additional domains (if any)
  validation_method         = "DNS"                              # Prove ownership via DNS records

  # Ensure new certificate is created before destroying old one (zero downtime)
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-alb-cert"
      Environment = var.environment
      Purpose     = "ALB SSL Certificate"  # Backend API security
      Domain      = var.alb_domain_name
    }
  )
}

# ==============================================================================
# CloudFront Certificate - Frontend Website Security Badge
# ==============================================================================
# WHAT THIS CREATES:
# SSL certificate for our frontend website via CloudFront CDN (events.sankofagrid.com).
# Enables secure HTTPS connections for all website visitors globally.
#
# CRITICAL REQUIREMENT:
# MUST be created in us-east-1 region (AWS CloudFront requirement).
# CloudFront is a global service but only accepts certificates from us-east-1.
#
# VALIDATION:
# Requires adding DNS TXT records to prove domain ownership.
# After validation, CloudFront can serve website over HTTPS.

resource "aws_acm_certificate" "cloudfront" {
  count = var.create_cloudfront_certificate ? 1 : 0  # Only create if enabled

  provider = aws.us_east_1  # CRITICAL: CloudFront certificates MUST be in us-east-1

  domain_name               = var.cloudfront_domain_name                # Main domain (events.sankofagrid.com)
  subject_alternative_names = var.cloudfront_subject_alternative_names  # Additional domains (www.sankofagrid.com)
  validation_method         = "DNS"                                     # Prove ownership via DNS records

  # Ensure new certificate is created before destroying old one (zero downtime)
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-cloudfront-cert"
      Environment = var.environment
      Purpose     = "CloudFront SSL Certificate"  # Frontend website security
      Domain      = var.cloudfront_domain_name
    }
  )
}
