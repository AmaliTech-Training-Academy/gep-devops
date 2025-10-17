# # terraform/modules/ecs/variables.tf
# variable "project_name" {
#   description = "Name of the project"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name (dev, staging, prod)"
#   type        = string
# }

# variable "vpc_id" {
#   description = "VPC ID where ECS cluster will be created"
#   type        = string
# }

# variable "private_subnet_ids" {
#   description = "List of private subnet IDs for ECS tasks"
#   type        = list(string)
# }

# variable "alb_security_group_ids" {
#   description = "List of ALB security group IDs"
#   type        = list(string)
# }

# variable "enable_container_insights" {
#   description = "Enable CloudWatch Container Insights"
#   type        = bool
#   default     = true
# }

# variable "use_spot_instances" {
#   description = "Use Fargate Spot instances for cost optimization"
#   type        = bool
#   default     = false
# }

# variable "log_retention_days" {
#   description = "CloudWatch log retention in days"
#   type        = number
#   default     = 30
# }

# variable "s3_bucket_arns" {
#   description = "List of S3 bucket ARNs for task access"
#   type        = list(string)
#   default     = []
# }

# variable "sns_topic_arns" {
#   description = "List of SNS topic ARNs for task access"
#   type        = list(string)
#   default     = []
# }

# variable "sqs_queue_arns" {
#   description = "List of SQS queue ARNs for task access"
#   type        = list(string)
#   default     = []
# }

# variable "enable_service_discovery" {
#   description = "Enable AWS Cloud Map service discovery"
#   type        = bool
#   default     = true
# }

# variable "common_tags" {
#   description = "Common tags to apply to all resources"
#   type        = map(string)
#   default     = {}
# }