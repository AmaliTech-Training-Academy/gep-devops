# terraform/modules/acm/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_domain_name" {
  description = "Domain name for ALB certificate (e.g., api.sankofagrid.com)"
  type        = string
}

variable "alb_subject_alternative_names" {
  description = "List of SANs for ALB certificate"
  type        = list(string)
  default     = []
}

variable "cloudfront_domain_name" {
  description = "Domain name for CloudFront certificate (e.g., events.sankofagrid.com)"
  type        = string
}

variable "cloudfront_subject_alternative_names" {
  description = "List of SANs for CloudFront certificate"
  type        = list(string)
  default     = []
}

variable "create_alb_certificate" {
  description = "Create ACM certificate for ALB"
  type        = bool
  default     = true
}

variable "create_cloudfront_certificate" {
  description = "Create ACM certificate for CloudFront"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
