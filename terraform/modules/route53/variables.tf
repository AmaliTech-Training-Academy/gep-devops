# # terraform/modules/route53/variables.tf
# variable "project_name" {
#   description = "Name of the project"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "domain_name" {
#   description = "Domain name"
#   type        = string
# }

# variable "create_hosted_zone" {
#   description = "Create a new hosted zone"
#   type        = bool
#   default     = false
# }

# variable "api_subdomain" {
#   description = "API subdomain (e.g., 'api' for api.example.com)"
#   type        = string
#   default     = "api"
# }

# variable "frontend_subdomain" {
#   description = "Frontend subdomain (empty for root domain)"
#   type        = string
#   default     = ""
# }

# variable "alb_dns_name" {
#   description = "ALB DNS name"
#   type        = string
#   default     = ""
# }

# variable "alb_zone_id" {
#   description = "ALB hosted zone ID"
#   type        = string
#   default     = ""
# }

# variable "cloudfront_domain_name" {
#   description = "CloudFront distribution domain name"
#   type        = string
#   default     = ""
# }

# variable "cloudfront_zone_id" {
#   description = "CloudFront hosted zone ID"
#   type        = string
#   default     = "Z2FDTNDATAQYW2" # CloudFront zone ID (constant)
# }

# variable "enable_ipv6" {
#   description = "Enable IPv6 (AAAA) records"
#   type        = bool
#   default     = true
# }

# variable "create_www_record" {
#   description = "Create www CNAME record"
#   type        = bool
#   default     = true
# }

# variable "enable_health_checks" {
#   description = "Enable Route53 health checks"
#   type        = bool
#   default     = true
# }

# variable "health_check_path" {
#   description = "Health check path"
#   type        = string
#   default     = "/api/health"
# }

# variable "health_check_failure_threshold" {
#   description = "Health check failure threshold"
#   type        = number
#   default     = 3
# }

# variable "health_check_interval" {
#   description = "Health check interval in seconds (10 or 30)"
#   type        = number
#   default     = 30
# }

# variable "alarm_actions" {
#   description = "List of ARNs for alarm actions"
#   type        = list(string)
#   default     = []
# }

# variable "verification_records" {
#   description = "Map of verification TXT records"
#   type = map(object({
#     name  = string
#     value = string
#   }))
#   default = {}
# }

# variable "mx_records" {
#   description = "List of MX records"
#   type        = list(string)
#   default     = []
# }

# variable "spf_record" {
#   description = "SPF record value"
#   type        = string
#   default     = ""
# }

# variable "dkim_records" {
#   description = "Map of DKIM CNAME records"
#   type = map(object({
#     name  = string
#     value = string
#   }))
#   default = {}
# }

# variable "dmarc_record" {
#   description = "DMARC record value"
#   type        = string
#   default     = ""
# }

# variable "caa_records" {
#   description = "List of CAA records"
#   type        = list(string)
#   default     = []
# }

# variable "common_tags" {
#   description = "Common tags"
#   type        = map(string)
#   default     = {}
# }