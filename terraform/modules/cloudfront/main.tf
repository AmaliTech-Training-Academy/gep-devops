# terraform/modules/cloudfront/main.tf
# ==============================================================================
# CloudFront Module - Content Delivery Network
# ==============================================================================

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-${var.environment}-s3-oac"
  description                       = "OAC for ${var.project_name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Cache Policy
resource "aws_cloudfront_cache_policy" "main" {
  name        = "${var.project_name}-${var.environment}-cache-policy"
  comment     = "Cache policy for ${var.project_name}"
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl
  min_ttl     = var.min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = var.forward_cookies ? "all" : "none"
    }

    headers_config {
      header_behavior = var.forward_headers_enabled ? "whitelist" : "none"

      dynamic "headers" {
        for_each = var.forward_headers_enabled ? [1] : []
        content {
          items = var.forward_headers
        }
      }
    }

    query_strings_config {
      query_string_behavior = var.forward_query_strings ? "all" : "none"
    }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

# Origin Request Policy
resource "aws_cloudfront_origin_request_policy" "main" {
  name    = "${var.project_name}-${var.environment}-origin-request-policy"
  comment = "Origin request policy for ${var.project_name}"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Origin",
        "Access-Control-Request-Method",
        "Access-Control-Request-Headers"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.project_name}-${var.environment}-security-headers"
  comment = "Security headers policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    content_security_policy {
      content_security_policy = var.content_security_policy
      override                = true
    }
  }

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "DELETE"]
    }

    access_control_allow_origins {
      items = var.cors_allowed_origins
    }

    origin_override = true
  }

  custom_headers_config {
    items {
      header   = "X-Application-Name"
      value    = var.project_name
      override = true
    }
    items {
      header   = "X-Environment"
      value    = var.environment
      override = true
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} CDN"
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.domain_aliases
  web_acl_id          = var.waf_web_acl_arn

  # S3 Origin
  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "S3-${var.s3_bucket_id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id

    origin_shield {
      enabled              = var.enable_origin_shield
      origin_shield_region = var.origin_shield_region
    }
  }

  # ALB Origin (for API)
  dynamic "origin" {
    for_each = var.alb_domain_name != "" ? [1] : []
    content {
      domain_name = var.alb_domain_name
      origin_id   = "ALB-${var.project_name}"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      custom_header {
        name  = "X-Custom-Header"
        value = random_password.custom_header.result
      }
    }
  }

  # Default cache behavior (for static assets)
  default_cache_behavior {
    target_origin_id       = "S3-${var.s3_bucket_id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = aws_cloudfront_cache_policy.main.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.main.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    dynamic "function_association" {
      for_each = var.enable_url_rewrite ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.url_rewrite[0].arn
      }
    }
  }

  # API cache behavior
  dynamic "ordered_cache_behavior" {
    for_each = var.alb_domain_name != "" ? [1] : []
    content {
      path_pattern           = "/api/*"
      target_origin_id       = "ALB-${var.project_name}"
      viewer_protocol_policy = "https-only"
      allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true

      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer.id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
    }
  }

  # Custom error responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # SSL/TLS Certificate
  # viewer_certificate {
  #   acm_certificate_arn            = var.acm_certificate_arn
  #   ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
  #   minimum_protocol_version       = "TLSv1.2_2021"
  #   cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : false
  # }
  viewer_certificate {
  acm_certificate_arn            = var.acm_certificate_arn
  ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
  minimum_protocol_version       = var.acm_certificate_arn != "" ? "TLSv1.2_2021" : "TLSv1"
  cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : false
}

  # Geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # Logging
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
      include_cookies = false
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-cdn"
      Environment = var.environment
    }
  )
}

# Random password for custom header (security)
resource "random_password" "custom_header" {
  length  = 32
  special = false
}

# CloudFront Function for URL rewriting (SPA support)
resource "aws_cloudfront_function" "url_rewrite" {
  count = var.enable_url_rewrite ? 1 : 0

  name    = "${var.project_name}-${var.environment}-url-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "URL rewrite for SPA routing"
  publish = true

  code = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // If URI doesn't have a file extension, serve index.html
    if (!uri.match(/\.[a-zA-Z0-9]+$/)) {
        request.uri = '/index.html';
    }
    // If URI ends with /, append index.html
    else if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    
    return request;
}
EOT
}

# Managed AWS Cache Policies (reference)
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

