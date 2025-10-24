# terraform/modules/waf/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# CloudFront WAF
variable "enable_cloudfront_waf" {
  description = "Enable WAF for CloudFront"
  type        = bool
  default     = false
}

variable "rate_limit" {
  description = "Rate limit per 5 minutes per IP for CloudFront"
  type        = number
  default     = 2000
}

# ALB WAF
variable "enable_alb_waf" {
  description = "Enable WAF for ALB"
  type        = bool
  default     = false
}

variable "alb_arn" {
  description = "ARN of the ALB to associate with WAF"
  type        = string
  default     = ""
}

variable "alb_rate_limit" {
  description = "Rate limit per 5 minutes per IP for ALB (more aggressive)"
  type        = number
  default     = 1000
}

variable "enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
