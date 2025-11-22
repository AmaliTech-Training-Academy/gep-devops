# ==============================================================================
# ECS Module Variables - Container Orchestration Configuration
# ==============================================================================
# WHAT THIS FILE DOES:
# Defines all the settings needed to run our business applications in containers.
# Think of it like configuring multiple specialized departments in our office building,
# each with specific requirements for space, resources, and communication.
#
# BUSINESS APPLICATIONS MANAGED:
# - Auth Service: Handles user login and registration
# - Event Service: Manages event creation and updates
# - Notification Service: Sends emails and SMS messages

# - Payment Service: Handles payment transactions (ready to deploy)
#
# CONFIGURATION CATEGORIES:
# - Infrastructure: Where and how to run applications
# - Security: Access controls and credentials
# - Performance: CPU, memory, and scaling settings
# - Communication: How services talk to each other
# - Monitoring: Logging and health tracking
# ==============================================================================

# ==============================================================================
# Basic Project Configuration
# ==============================================================================

variable "project_name" {
  description = "Name of the project (e.g., 'event-planner'). Used as prefix for all container resources to keep them organized."
  type        = string
}

variable "environment" {
  description = "Environment name that determines resource sizing and configuration. 'dev' = cost-optimized, 'prod' = high-availability."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod to ensure proper resource configuration."
  }
}

variable "aws_region" {
  description = "AWS region where containers will run. Affects latency to users and compliance requirements. EU users = eu-west-1, US users = us-east-1."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1, eu-west-1) to ensure proper service deployment."
  }
}

# ==============================================================================
# Network Configuration - Where Containers Run
# ==============================================================================

variable "vpc_id" {
  description = "ID of the Virtual Private Cloud where containers will be deployed. This is our secure network boundary."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where application containers run. These subnets have no direct internet access for security."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID that controls network access to containers. Acts like a firewall protecting our applications."
  type        = string
}

# ==============================================================================
# Security and Access Control Configuration
# ==============================================================================
# WHAT THESE VARIABLES CONTROL:
# Permissions that determine what each container can access in AWS.
# Like employee ID badges that specify which rooms and systems each person can use.

variable "task_execution_role_arn" {
  description = "ARN of the role that allows ECS to start containers, pull images, and write logs. Like a master key for container management."
  type        = string
}

variable "task_role_arns" {
  description = "Map of service-specific roles that control what each application can access (databases, queues, etc.). Each service gets only the permissions it needs."
  type        = map(string)
}

# ==============================================================================
# Service Communication Configuration
# ==============================================================================
# WHAT THIS CONTROLS:
# How our business services find and talk to each other.
# Like an internal phone directory for our applications.

variable "service_discovery_namespace" {
  description = "Internal domain name for service communication (e.g., auth-service.eventplanner.local). Allows services to find each other automatically."
  type        = string
  default     = "eventplanner.local"
}

# ==============================================================================
# Application Deployment Configuration
# ==============================================================================
# WHAT THESE VARIABLES CONTROL:
# Which version of our applications to run and where to find them.
# Like specifying which software version to install on each computer.

variable "ecr_repository_urls" {
  description = "Map of service names to container image locations. Each service (auth, event, notification) has its own packaged application."
  type        = map(string)
}

variable "image_tag" {
  description = "Version tag of the application to deploy (e.g., 'v1.2.3', 'latest'). Controls which version of our software runs."
  type        = string
  default     = "latest"
}

# ==============================================================================
# Database Configuration
# ==============================================================================

variable "db_secret_arns" {
  description = "Map of service names to database secret ARNs"
  type        = map(string)
}

variable "redis_endpoint" {
  description = "Redis endpoint for caching"
  type        = string
}

variable "jwt_secret_arn" {
  description = "ARN of JWT secret in Secrets Manager for auth service"
  type        = string
  default     = null
}

# AWS credentials variable removed - services use IAM roles

variable "google_credentials_secret_arn" {
  description = "ARN of Google credentials secret in Secrets Manager for notification service"
  type        = string
  default     = null
}

variable "paystack_credentials_secret_arn" {
  description = "ARN of Paystack credentials secret in Secrets Manager for payment service"
  type        = string
  default     = null
}

variable "redis_credentials_secret_arn" {
  description = "ARN of Redis credentials secret in Secrets Manager for ElastiCache authentication"
  type        = string
  default     = null
}

variable "jwt_access_expiration" {
  description = "JWT access token expiration time in milliseconds"
  type        = number
  default     = 3600000 # 1 hour
}

variable "jwt_refresh_expiration" {
  description = "JWT refresh token expiration time in milliseconds"
  type        = number
  default     = 86400000 # 24 hours
}

variable "sqs_queue_urls" {
  description = "Map of SQS queue URLs"
  type        = map(string)
  default     = {}
}

variable "sqs_queue_names" {
  description = "Map of SQS queue names"
  type        = map(string)
  default     = {}
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  type        = string
}

variable "s3_backend_files_bucket_name" {
  description = "Name of the S3 bucket for backend user file uploads"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

# ==============================================================================
# Load Balancer Configuration
# ==============================================================================

variable "target_group_arns" {
  description = "Map of service names to ALB target group ARNs"
  type        = map(string)
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener (HTTP or HTTPS)"
  type        = string
}

# ==============================================================================
# ECS Cluster Configuration
# ==============================================================================

variable "enable_container_insights" {
  description = "Enable Container Insights for monitoring"
  type        = bool
  default     = true
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot for cost savings"
  type        = bool
  default     = false
}

# ==============================================================================
# Logging Configuration
# ==============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  type        = string
  default     = null
}

# ==============================================================================
# Auto Scaling Configuration
# ==============================================================================

variable "cpu_target_value" {
  description = "Target CPU utilization for auto scaling (%)"
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_target_value >= 10 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 10 and 100"
  }
}

variable "memory_target_value" {
  description = "Target memory utilization for auto scaling (%)"
  type        = number
  default     = 75

  validation {
    condition     = var.memory_target_value >= 10 && var.memory_target_value <= 100
    error_message = "Memory target value must be between 10 and 100"
  }
}

variable "scale_in_cooldown" {
  description = "Cooldown period for scale in (seconds)"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period for scale out (seconds)"
  type        = number
  default     = 60
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Additional tags for ECS resources"
  type        = map(string)
  default     = {}
}

variable "payment_service_url" {
  description = "Payment service URL for event service"
  type        = string
  default     = "https://api.sankofagrid.com"
}

variable "sns_topic_arns" {
  description = "Map of SNS topic ARNs for event publishing"
  type        = map(string)
  default     = {}
}