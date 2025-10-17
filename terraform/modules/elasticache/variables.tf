# # terraform/modules/elasticache/variables.tf
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

# variable "private_subnet_ids" {
#   description = "List of private subnet IDs for ElastiCache"
#   type        = list(string)
# }

# variable "ecs_security_group_ids" {
#   description = "List of ECS security group IDs"
#   type        = list(string)
# }

# variable "redis_engine_version" {
#   description = "Redis engine version"
#   type        = string
#   default     = "7.1"
# }

# variable "redis_node_type" {
#   description = "ElastiCache node type"
#   type        = string
#   default     = "cache.t4g.micro"
# }

# variable "num_cache_nodes" {
#   description = "Number of cache nodes (for non-cluster mode)"
#   type        = number
#   default     = 2
# }

# variable "enable_cluster_mode" {
#   description = "Enable Redis cluster mode"
#   type        = bool
#   default     = false
# }

# variable "num_node_groups" {
#   description = "Number of node groups (shards) for cluster mode"
#   type        = number
#   default     = 1
# }

# variable "replicas_per_node_group" {
#   description = "Number of replica nodes per shard"
#   type        = number
#   default     = 1
# }

# variable "redis_parameter_group_family" {
#   description = "Redis parameter group family"
#   type        = string
#   default     = "redis7"
# }

# variable "redis_parameters" {
#   description = "List of Redis parameters"
#   type = list(object({
#     name  = string
#     value = string
#   }))
#   default = [
#     {
#       name  = "maxmemory-policy"
#       value = "allkeys-lru"
#     },
#     {
#       name  = "timeout"
#       value = "300"
#     }
#   ]
# }

# variable "automatic_failover_enabled" {
#   description = "Enable automatic failover"
#   type        = bool
#   default     = true
# }

# variable "multi_az_enabled" {
#   description = "Enable Multi-AZ"
#   type        = bool
#   default     = false
# }

# variable "enable_encryption_at_rest" {
#   description = "Enable encryption at rest"
#   type        = bool
#   default     = true
# }

# variable "enable_encryption_in_transit" {
#   description = "Enable encryption in transit"
#   type        = bool
#   default     = true
# }

# variable "enable_auth_token" {
#   description = "Enable auth token (password)"
#   type        = bool
#   default     = true
# }

# variable "snapshot_retention_limit" {
#   description = "Number of days to retain snapshots"
#   type        = number
#   default     = 7
# }

# variable "snapshot_window" {
#   description = "Snapshot window"
#   type        = string
#   default     = "03:00-05:00"
# }

# variable "maintenance_window" {
#   description = "Maintenance window"
#   type        = string
#   default     = "sun:05:00-sun:07:00"
# }

# variable "auto_minor_version_upgrade" {
#   description = "Enable automatic minor version upgrades"
#   type        = bool
#   default     = true
# }

# variable "apply_immediately" {
#   description = "Apply changes immediately"
#   type        = bool
#   default     = false
# }

# variable "skip_final_snapshot" {
#   description = "Skip final snapshot on deletion"
#   type        = bool
#   default     = false
# }

# variable "kms_key_arn" {
#   description = "KMS key ARN for encryption"
#   type        = string
#   default     = null
# }

# variable "sns_topic_arn" {
#   description = "SNS topic ARN for notifications"
#   type        = string
#   default     = null
# }

# variable "log_retention_days" {
#   description = "CloudWatch log retention in days"
#   type        = number
#   default     = 30
# }

# variable "secret_recovery_window_days" {
#   description = "Recovery window in days for secrets"
#   type        = number
#   default     = 7
# }

# variable "common_tags" {
#   description = "Common tags"
#   type        = map(string)
#   default     = {}
# }