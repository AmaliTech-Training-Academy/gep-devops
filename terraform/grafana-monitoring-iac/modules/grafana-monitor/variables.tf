# ==============================================================================
# Grafana Monitoring Module - Variables
# ==============================================================================

variable "project_name" {
  description = "Project name used as prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where Grafana will be deployed"
  type        = string
}

variable "private_subnet_id" {
  description = "ID of the private subnet for Grafana EC2 instance"
  type        = string
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group"
  type        = string
}

variable "rds_security_group_id" {
  description = "ID of the RDS security group"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the ALB HTTPS listener"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB for CloudWatch alarms"
  type        = string
}

variable "alb_domain_name" {
  description = "Domain name of the ALB (e.g., api.sankofagrid.com)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Grafana"
  type        = string
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Size of the EBS volume in GB"
  type        = number
  default     = 20
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana (use strong password)"
  type        = string
  sensitive   = true
}

variable "listener_rule_priority" {
  description = "Priority for the ALB listener rule (lower = higher priority)"
  type        = number
  default     = 1
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
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

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for the Grafana EC2 instance"
  type        = string
}
