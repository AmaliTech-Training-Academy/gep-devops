# # terraform/modules/elasticache/main.tf
# # ==============================================================================
# # ElastiCache Module - Redis Caching Infrastructure
# # ==============================================================================

# # ElastiCache Subnet Group
# resource "aws_elasticache_subnet_group" "main" {
#   name       = "${var.project_name}-${var.environment}-cache-subnet-group"
#   subnet_ids = var.private_subnet_ids

#   tags = merge(
#     var.common_tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-cache-subnet-group"
#       Environment = var.environment
#     }
#   )
# }

# # Security Group for ElastiCache
# resource "aws_security_group" "redis" {
#   name        = "${var.project_name}-${var.environment}-redis-sg"
#   description = "Security group for ElastiCache Redis cluster"
#   vpc_id      = var.vpc_id

#   ingress {
#     description     = "Redis from ECS tasks"
#     from_port       = 6379
#     to_port         = 6379
#     protocol        = "tcp"
#     security_groups = var.ecs_security_group_ids
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name = "${var.project_name}-${var.environment}-redis-sg"
#     }
#   )
# }

# # ElastiCache Parameter Group
# resource "aws_elasticache_parameter_group" "main" {
#   name   = "${var.project_name}-${var.environment}-redis-params"
#   family = var.redis_parameter_group_family

#   dynamic "parameter" {
#     for_each = var.redis_parameters
#     content {
#       name  = parameter.value.name
#       value = parameter.value.value
#     }
#   }

#   tags = var.common_tags
# }

# # Random auth token for Redis
# resource "random_password" "auth_token" {
#   count = var.enable_auth_token ? 1 : 0

#   length  = 32
#   special = false # Redis auth token doesn't support special characters
# }

# # Store auth token in Secrets Manager
# resource "aws_secretsmanager_secret" "redis_auth_token" {
#   count = var.enable_auth_token ? 1 : 0

#   name                    = "${var.project_name}-${var.environment}-redis-auth-token"
#   description             = "Auth token for ${var.project_name} Redis cluster"
#   recovery_window_in_days = var.secret_recovery_window_days

#   tags = var.common_tags
# }

# resource "aws_secretsmanager_secret_version" "redis_auth_token" {
#   count = var.enable_auth_token ? 1 : 0

#   secret_id = aws_secretsmanager_secret.redis_auth_token[0].id
#   secret_string = jsonencode({
#     auth_token            = random_password.auth_token[0].result
#     primary_endpoint      = var.enable_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address
#     reader_endpoint       = var.enable_cluster_mode ? null : aws_elasticache_replication_group.main.reader_endpoint_address
#     port                  = 6379
#     cluster_enabled       = var.enable_cluster_mode
#   })
# }

# # ElastiCache Replication Group (Redis)
# resource "aws_elasticache_replication_group" "main" {
#   replication_group_id       = "${var.project_name}-${var.environment}-redis"
#   replication_group_description = "Redis cluster for ${var.project_name} ${var.environment}"

#   engine               = "redis"
#   engine_version       = var.redis_engine_version
#   node_type            = var.redis_node_type
#   num_cache_clusters   = var.enable_cluster_mode ? null : var.num_cache_nodes
#   num_node_groups      = var.enable_cluster_mode ? var.num_node_groups : null
#   replicas_per_node_group = var.enable_cluster_mode ? var.replicas_per_node_group : null

#   port                       = 6379
#   parameter_group_name       = aws_elasticache_parameter_group.main.name
#   subnet_group_name          = aws_elasticache_subnet_group.main.name
#   security_group_ids         = [aws_security_group.redis.id]

#   # High availability
#   automatic_failover_enabled = var.automatic_failover_enabled
#   multi_az_enabled           = var.multi_az_enabled

#   # Security
#   at_rest_encryption_enabled = var.enable_encryption_at_rest
#   transit_encryption_enabled = var.enable_encryption_in_transit
#   auth_token                 = var.enable_auth_token ? random_password.auth_token[0].result : null
#   kms_key_id                 = var.enable_encryption_at_rest ? var.kms_key_arn : null

#   # Backup
#   snapshot_retention_limit   = var.snapshot_retention_limit
#   snapshot_window            = var.snapshot_window
#   final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-redis-final-snapshot"

#   # Maintenance
#   maintenance_window         = var.maintenance_window
#   auto_minor_version_upgrade = var.auto_minor_version_upgrade
#   apply_immediately          = var.apply_immediately

#   # Notifications
#   notification_topic_arn     = var.sns_topic_arn

#   # Logging
#   log_delivery_configuration {
#     destination      = aws_cloudwatch_log_group.slow_log.name
#     destination_type = "cloudwatch-logs"
#     log_format       = "json"
#     log_type         = "slow-log"
#   }

#   log_delivery_configuration {
#     destination      = aws_cloudwatch_log_group.engine_log.name
#     destination_type = "cloudwatch-logs"
#     log_format       = "json"
#     log_type         = "engine-log"
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-redis-cluster"
#       Environment = var.environment
#     }
#   )
# }

# # CloudWatch Log Groups for Redis logs
# resource "aws_cloudwatch_log_group" "slow_log" {
#   name              = "/aws/elasticache/${var.project_name}-${var.environment}/slow-log"
#   retention_in_days = var.log_retention_days

#   tags = var.common_tags
# }

# resource "aws_cloudwatch_log_group" "engine_log" {
#   name              = "/aws/elasticache/${var.project_name}-${var.environment}/engine-log"
#   retention_in_days = var.log_retention_days

#   tags = var.common_tags
# }



