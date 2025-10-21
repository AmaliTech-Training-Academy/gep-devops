# ==============================================================================
# ALB Module Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

# ==============================================================================
# SSL/TLS Configuration
# ==============================================================================

variable "certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# ==============================================================================
# Health Check Configuration
# ==============================================================================

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health check successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

# ==============================================================================
# Target Group Configuration
# ==============================================================================

variable "deregistration_delay" {
  description = "Time to wait before deregistering a target (seconds)"
  type        = number
  default     = 30
}

# ==============================================================================
# Access Logs Configuration
# ==============================================================================

variable "enable_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "S3 prefix for ALB access logs"
  type        = string
  default     = "alb"
}

# ==============================================================================
# ALB Configuration
# ==============================================================================

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

# ==============================================================================
# Alarm Configuration
# ==============================================================================

variable "response_time_alarm_threshold" {
  description = "Response time alarm threshold in seconds"
  type        = number
  default     = 2
}

variable "error_5xx_alarm_threshold" {
  description = "5XX error count threshold"
  type        = number
  default     = 10
}

variable "alarm_actions" {
  description = "List of ARNs for alarm actions"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Additional tags for ALB resources"
  type        = map(string)
  default     = {}
}

