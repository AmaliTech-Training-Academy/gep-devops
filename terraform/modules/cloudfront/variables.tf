# terraform/modules/cloudfront/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "s3_bucket_id" {
  description = "S3 bucket ID for origin"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  type        = string
}

variable "alb_domain_name" {
  description = "ALB domain name for API origin"
  type        = string
  default     = ""
}

variable "domain_aliases" {
  description = "List of domain aliases (CNAMEs)"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = ""
}

variable "default_root_object" {
  description = "Default root object"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "default_ttl" {
  description = "Default TTL in seconds"
  type        = number
  default     = 86400
}

variable "max_ttl" {
  description = "Maximum TTL in seconds"
  type        = number
  default     = 31536000
}

variable "min_ttl" {
  description = "Minimum TTL in seconds"
  type        = number
  default     = 0
}

variable "forward_cookies" {
  description = "Forward cookies to origin"
  type        = bool
  default     = false
}

variable "forward_query_strings" {
  description = "Forward query strings to origin"
  type        = bool
  default     = true
}

variable "forward_headers_enabled" {
  description = "Enable forwarding specific headers"
  type        = bool
  default     = false
}

variable "forward_headers" {
  description = "List of headers to forward"
  type        = list(string)
  default     = []
}

variable "enable_origin_shield" {
  description = "Enable Origin Shield"
  type        = bool
  default     = false
}

variable "origin_shield_region" {
  description = "Origin Shield region"
  type        = string
  default     = "us-east-1"
}

variable "geo_restriction_type" {
  description = "Geo restriction type (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  type        = string
  default     = ""
}

variable "enable_logging" {
  description = "Enable access logging"
  type        = bool
  default     = true
}

variable "logging_bucket" {
  description = "S3 bucket for logs"
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Log prefix"
  type        = string
  default     = "cloudfront/"
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "content_security_policy" {
  description = "Content Security Policy header value"
  type        = string
  default     = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:;"
}

variable "enable_url_rewrite" {
  description = "Enable URL rewrite function for SPA"
  type        = bool
  default     = true
}

variable "custom_error_responses" {
  description = "Custom error responses"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

