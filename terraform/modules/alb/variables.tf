# # terraform/modules/alb/variables.tf
# variable "project_name" {
#   description = "Name of the project"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "vpc_id" {
#   description = "VPC ID"
#   type        = string
# }

# variable "subnet_ids" {
#   description = "List of subnet IDs for ALB"
#   type        = list(string)
# }

# variable "internal" {
#   description = "Whether the load balancer is internal"
#   type        = bool
#   default     = false
# }

# variable "enable_deletion_protection" {
#   description = "Enable deletion protection"
#   type        = bool
#   default     = true
# }

# variable "idle_timeout" {
#   description = "Idle timeout in seconds"
#   type        = number
#   default     = 60
# }

# variable "certificate_arn" {
#   description = "ACM certificate ARN"
#   type        = string
#   default     = ""
# }

# variable "ssl_policy" {
#   description = "SSL policy for HTTPS listener"
#   type        = string
#   default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
# }

# variable "health_check_healthy_threshold" {
#   description = "Number of consecutive health check successes required"
#   type        = number
#   default     = 2
# }

# variable "health_check_unhealthy_threshold" {
#   description = "Number of consecutive health check failures required"
#   type        = number
#   default     = 3
# }

# variable "health_check_interval" {
#   description = "Health check interval in seconds"
#   type        = number
#   default     = 30
# }

# variable "health_check_timeout" {
#   description = "Health check timeout in seconds"
#   type        = number
#   default     = 5
# }

# variable "health_check_matcher" {
#   description = "HTTP response codes for successful health checks"
#   type        = string
#   default     = "200-299"
# }

# variable "deregistration_delay" {
#   description = "Deregistration delay in seconds"
#   type        = number
#   default     = 30
# }

# variable "enable_stickiness" {
#   description = "Enable sticky sessions"
#   type        = bool
#   default     = true
# }

# variable "enable_access_logs" {
#   description = "Enable access logs"
#   type        = bool
#   default     = true
# }

# variable "access_logs_bucket" {
#   description = "S3 bucket for access logs"
#   type        = string
#   default     = ""
# }

# variable "access_logs_prefix" {
#   description = "Prefix for access logs"
#   type        = string
#   default     = "alb"
# }

# variable "waf_web_acl_arn" {
#   description = "WAF Web ACL ARN"
#   type        = string
#   default     = ""
# }

# variable "common_tags" {
#   description = "Common tags"
#   type        = map(string)
#   default     = {}
# }

