# ==============================================================================
# ECS Module - Fargate Cluster with AWS Cloud Map Service Discovery
# ==============================================================================
# This module creates:
# - ECS Fargate cluster
# - AWS Cloud Map namespace for service discovery
# - Capacity providers
# - Container Insights
# - Auto-scaling policies
#
# Service Discovery:
# - Services communicate via: service-name.eventplanner.local
# - AWS Cloud Map handles DNS-based service discovery
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # Microservices configuration
  # COST OPTIMIZATION: Commented out services not yet needed by developers
  # To re-enable: Uncomment the service blocks below and run terraform apply
  services = {
    auth = {
      name          = "auth-service"
      port          = 8081
      cpu           = var.environment == "dev" ? 256 : 512
      memory        = var.environment == "dev" ? 512 : 1024
      desired_count = var.environment == "dev" ? 1 : 2
      min_capacity  = var.environment == "dev" ? 1 : 2
      max_capacity  = var.environment == "dev" ? 2 : 4
    }
    # TEMPORARILY DISABLED: Event service not yet ready
    # Uncomment when developers are ready to deploy
    # event = {
    #   name          = "event-service"
    #   port          = 8082
    #   cpu           = var.environment == "dev" ? 256 : 512
    #   memory        = var.environment == "dev" ? 512 : 1024
    #   desired_count = var.environment == "dev" ? 1 : 2
    #   min_capacity  = var.environment == "dev" ? 1 : 2
    #   max_capacity  = var.environment == "dev" ? 2 : 4
    # }
    # TEMPORARILY DISABLED: Booking service not yet ready
    # Uncomment when developers are ready to deploy
    # booking = {
    #   name          = "booking-service"
    #   port          = 8083
    #   cpu           = var.environment == "dev" ? 256 : 512
    #   memory        = var.environment == "dev" ? 512 : 1024
    #   desired_count = var.environment == "dev" ? 1 : 2
    #   min_capacity  = var.environment == "dev" ? 1 : 2
    #   max_capacity  = var.environment == "dev" ? 2 : 4
    # }
    # TEMPORARILY DISABLED: Payment service not yet ready
    # Uncomment when developers are ready to deploy
    # payment = {
    #   name          = "payment-service"
    #   port          = 8084
    #   cpu           = var.environment == "dev" ? 256 : 512
    #   memory        = var.environment == "dev" ? 512 : 1024
    #   desired_count = var.environment == "dev" ? 1 : 2
    #   min_capacity  = var.environment == "dev" ? 1 : 2
    #   max_capacity  = var.environment == "dev" ? 2 : 4
    # }
    # TEMPORARILY DISABLED: Notification service not yet ready
    # Uncomment when developers are ready to deploy
    # notification = {
    #   name          = "notification-service"
    #   port          = 8085
    #   cpu           = var.environment == "dev" ? 256 : 512
    #   memory        = var.environment == "dev" ? 512 : 1024
    #   desired_count = var.environment == "dev" ? 1 : 2
    #   min_capacity  = var.environment == "dev" ? 1 : 1
    #   max_capacity  = var.environment == "dev" ? 2 : 3
    # }
  }

  common_tags = merge(
    var.tags,
    {
      Module      = "ecs"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# ECS Cluster
# ==============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  # Enable Container Insights for monitoring
  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-cluster"
    }
  )
}

# ==============================================================================
# ECS Cluster Capacity Providers
# ==============================================================================

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = var.enable_fargate_spot ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.enable_fargate_spot ? 70 : 100
    base              = 1
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = var.enable_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = 30
      base              = 0
    }
  }
}

# ==============================================================================
# AWS Cloud Map - Service Discovery Namespace
# ==============================================================================
# Services will communicate via DNS: service-name.eventplanner.local

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.service_discovery_namespace
  description = "Private DNS namespace for ${var.project_name} ${var.environment} service discovery"
  vpc         = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-service-discovery"
    }
  )
}

# ==============================================================================
# CloudWatch Log Groups
# ==============================================================================

# Create log group for each service
resource "aws_cloudwatch_log_group" "services" {
  for_each = local.services

  name              = "/ecs/${var.project_name}/${var.environment}/${each.value.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-logs"
      Service = each.value.name
    }
  )
}

# ==============================================================================
# ECS Task Definitions
# ==============================================================================

# Register task definitions
resource "aws_ecs_task_definition" "services" {
  for_each = local.services

  family                   = "${var.project_name}-${var.environment}-${each.value.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = lookup(var.task_role_arns, each.value.name, null)

  # Container definitions
  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = "${var.ecr_repository_urls[each.value.name]}:${var.image_tag}"
      cpu       = each.value.cpu
      memory    = each.value.memory
      essential = true

      portMappings = [
        {
          containerPort = each.value.port
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]

      environment = concat([
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.environment
        },
        {
          name  = "SERVICE_NAME"
          value = each.value.name
        },
        {
          name  = "SERVICE_PORT"
          value = tostring(each.value.port)
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "SPRING_DATA_REDIS_HOST"
          value = var.redis_endpoint
        },
        {
          name  = "SPRING_DATA_REDIS_PORT"
          value = "6379"
        },
        {
          name  = "SPRING_DATA_REDIS_SSL_ENABLED"
          value = "true"
        },
        {
          name  = "MANAGEMENT_HEALTH_MONGO_ENABLED"
          value = "false"
        },
        {
          name  = "SERVICE_DISCOVERY_NAMESPACE"
          value = var.service_discovery_namespace
        },
        {
          name  = "AUTH_SERVICE_URL"
          value = "http://auth-service.${var.service_discovery_namespace}:8081"
        },
        {
          name  = "EVENT_SERVICE_URL"
          value = "http://event-service.${var.service_discovery_namespace}:8082"
        }
      ],
      [
        # TEMPORARILY DISABLED: Service URLs for services not yet deployed
        # Uncomment when booking, payment, and notification services are ready
        # {
        #   name  = "BOOKING_SERVICE_URL"
        #   value = "http://booking-service.${var.service_discovery_namespace}:8083"
        # },
        # {
        #   name  = "PAYMENT_SERVICE_URL"
        #   value = "http://payment-service.${var.service_discovery_namespace}:8084"
        # },
        # {
        #   name  = "NOTIFICATION_SERVICE_URL"
        #   value = "http://notification-service.${var.service_discovery_namespace}:8085"
        # }
        # JWT configuration for auth service
      ],
      each.key == "auth" ? [
        {
          name  = "JWT_ACCESS_EXPIRATION"
          value = tostring(var.jwt_access_expiration)
        },
        {
          name  = "JWT_REFRESH_EXPIRATION"
          value = tostring(var.jwt_refresh_expiration)
        }
      ] : [],
      # SQS configuration - only for services that need it
      each.key == "auth" ? [
        {
          name  = "SQS_ENDPOINT"
          value = "https://sqs.${var.aws_region}.amazonaws.com"
        },
        {
          name  = "USER_REGISTRATION_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "user_registration", "")
        },
        {
          name  = "USER_LOGIN_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "user_login", "")
        },
        {
          name  = "USER_REGISTRATION_QUEUE"
          value = lookup(var.sqs_queue_urls, "user_registration", "")
        },
        {
          name  = "USER_LOGIN_QUEUE"
          value = lookup(var.sqs_queue_urls, "user_login", "")
        },
        {
          name  = "PASSWORD_RESET_QUEUE"
          value = lookup(var.sqs_queue_urls, "password_reset", "")
        }
      ] : [],
      each.key == "event" ? [
        {
          name  = "SQS_ENDPOINT"
          value = "https://sqs.${var.aws_region}.amazonaws.com"
        },
        {
          name  = "EVENT_CREATED_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "event-created", "")
        },
        {
          name  = "EVENT_UPDATED_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "event-updated", "")
        }
      ] : [],
      each.key == "booking" ? [
        {
          name  = "SQS_ENDPOINT"
          value = "https://sqs.${var.aws_region}.amazonaws.com"
        },
        {
          name  = "BOOKING_CREATED_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "booking-created", "")
        },
        {
          name  = "BOOKING_CANCELLED_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "booking-cancelled", "")
        }
      ] : [],
      each.key == "payment" ? [
        {
          name  = "SQS_ENDPOINT"
          value = "https://sqs.${var.aws_region}.amazonaws.com"
        },
        {
          name  = "PAYMENT_PROCESSED_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "payment-processed", "")
        }
      ] : [],
      each.key == "notification" ? [
        {
          name  = "SQS_ENDPOINT"
          value = "https://sqs.${var.aws_region}.amazonaws.com"
        },
        {
          name  = "EMAIL_QUEUE_NAME"
          value = lookup(var.sqs_queue_names, "email-notifications", "")
        }
      ] : []
      )

      secrets = concat(
        # AWS Credentials from Secrets Manager
        var.aws_credentials_secret_arn != null ? [
          {
            name      = "AWS_ACCESS_KEY_ID"
            valueFrom = "${var.aws_credentials_secret_arn}:AWS_ACCESS_KEY_ID::"
          },
          {
            name      = "AWS_SECRET_ACCESS_KEY"
            valueFrom = "${var.aws_credentials_secret_arn}:AWS_SECRET_ACCESS_KEY::"
          }
        ] : [],
        # Service-specific database credentials - use each.key (auth, event) not each.value.name (auth-service)
        each.key == "auth" && lookup(var.db_secret_arns, each.key, null) != null ? [
          {
            name      = "AUTH_SERVICE_DB_URL"
            valueFrom = "${var.db_secret_arns[each.key]}:url::"
          },
          {
            name      = "AUTH_SERVICE_DB_USER"
            valueFrom = "${var.db_secret_arns[each.key]}:username::"
          },
          {
            name      = "AUTH_SERVICE_DB_PASSWORD"
            valueFrom = "${var.db_secret_arns[each.key]}:password::"
          }
        ] : [],
        each.key == "event" && lookup(var.db_secret_arns, each.key, null) != null ? [
          {
            name      = "EVENT_SERVICE_DB_URL"
            valueFrom = "${var.db_secret_arns[each.key]}:url::"
          },
          {
            name      = "EVENT_SERVICE_DB_USER"
            valueFrom = "${var.db_secret_arns[each.key]}:username::"
          },
          {
            name      = "EVENT_SERVICE_DB_PASSWORD"
            valueFrom = "${var.db_secret_arns[each.key]}:password::"
          }
        ] : [],
        # JWT secret for auth service
        each.key == "auth" && var.jwt_secret_arn != null ? [
          {
            name      = "JWT_SECRET"
            valueFrom = "${var.jwt_secret_arn}:JWT_SECRET::"
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.port}/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    }
  ])
#############################################
  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-task"
      Service = each.value.name
    }
  )
}

# ==============================================================================
# Service Discovery Services
# ==============================================================================

resource "aws_service_discovery_service" "services" {
  for_each = local.services

  name = each.value.name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-discovery"
      Service = each.value.name
    }
  )
}

# ==============================================================================
# ECS Services
# ==============================================================================

resource "aws_ecs_service" "services" {
  for_each = local.services

  name             = each.value.name
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.services[each.key].arn
  desired_count    = each.value.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # Network configuration - Deploy in first AZ only for dev cost optimization
  network_configuration {
    subnets          = [var.private_subnet_ids[0]]
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  # Load balancer configuration
  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = each.value.name
    container_port   = each.value.port
  }

  # Service discovery configuration (AWS Cloud Map)
  service_registries {
    registry_arn = aws_service_discovery_service.services[each.key].arn
  }

  # Deployment configuration
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Enable ECS managed tags
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  # Health check grace period (allow time for Spring Boot startup)
  health_check_grace_period_seconds = 180

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}"
      Service = each.value.name
    }
  )

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ==============================================================================
# Auto Scaling
# ==============================================================================

# Auto scaling target
resource "aws_appautoscaling_target" "services" {
  for_each = local.services

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU-based auto scaling policy
resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.services

  name               = "${var.project_name}-${var.environment}-${each.value.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Memory-based auto scaling policy
resource "aws_appautoscaling_policy" "memory" {
  for_each = local.services

  name               = "${var.project_name}-${var.environment}-${each.value.name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.memory_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}



