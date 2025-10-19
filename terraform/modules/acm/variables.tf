# # terraform/modules/acm/variables.tf
# variable "project_name" {
#   description = "Name of the project"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "domain_name" {
#   description = "Primary domain name for the certificate"
#   type        = string
# }

# variable "subject_alternative_names" {
#   description = "List of subject alternative names (SANs) for ALB certificate"
#   type        = list(string)
#   default     = []
# }

# variable "cloudfront_domain_name" {
#   description = "Domain name for CloudFront certificate"
#   type        = string
#   default     = ""
# }

# variable "cloudfront_subject_alternative_names" {
#   description = "List of subject alternative names for CloudFront certificate"
#   type        = list(string)
#   default     = []
# }

# variable "create_alb_certificate" {
#   description = "Create ACM certificate for ALB"
#   type        = bool
#   default     = true
# }

# variable "create_cloudfront_certificate" {
#   description = "Create ACM certificate for CloudFront"
#   type        = bool
#   default     = true
# }

# variable "validation_method" {
#   description = "Certificate validation method (DNS or EMAIL)"
#   type        = string
#   default     = "DNS"

#   validation {
#     condition     = contains(["DNS", "EMAIL"], var.validation_method)
#     error_message = "Validation method must be either DNS or EMAIL."
#   }
# }

# variable "route53_zone_id" {
#   description = "Route53 hosted zone ID for DNS validation"
#   type        = string
#   default     = ""
# }

# variable "enable_expiration_alarms" {
#   description = "Enable CloudWatch alarms for certificate expiration"
#   type        = bool
#   default     = true
# }

# variable "expiration_days_threshold" {
#   description = "Number of days before expiration to trigger alarm"
#   type        = number
#   default     = 30
# }

# variable "alarm_actions" {
#   description = "List of ARNs for alarm actions (SNS topics)"
#   type        = list(string)
#   default     = []
# }

# variable "common_tags" {
#   description = "Common tags to apply to all resources"
#   type        = map(string)
#   default     = {}
# }

