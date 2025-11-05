# ==============================================================================
# ALB Module - Application Load Balancer (Smart Traffic Director)
# ==============================================================================
# WHAT THIS MODULE DOES:
# Creates a smart traffic director that receives all user requests from the internet
# and routes them to the correct business service based on what the user wants to do.
# Think of it like a smart receptionist who knows exactly which department to send
# each visitor to based on their needs.
#
# BUSINESS FUNCTION:
# - Receives all website traffic from users around the world
# - Routes login requests to the authentication service
# - Routes event browsing to the event management service
# - Routes booking requests to the booking service
# - Routes payment processing to the payment service
# - Routes notifications to the notification service
#
# SMART ROUTING RULES:
# - /api/v1/auth/* → Authentication Service (user login/registration)
# - /api/v1/events/* → Event Service (event browsing/creation)
# - /api/v1/bookings/* → Booking Service (event reservations)
# - /api/v1/payments/* → Payment Service (payment processing)
# - /api/v1/notifications/* → Notification Service (emails/SMS)
#
# BUSINESS BENEFITS:
# - High Availability: If one server fails, traffic goes to healthy servers
# - Performance: Distributes load across multiple servers for faster response
# - Security: Handles SSL certificates and encrypts all user traffic
# - Monitoring: Tracks performance and alerts on issues
# - Scalability: Automatically adds/removes servers based on demand
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
# Service Configuration - Business Department Directory
# ==============================================================================
# WHAT THIS SECTION DEFINES:
# Configuration for each business service including where to route requests
# and how to check if each service is healthy and responding to users.
# Like maintaining a company directory with department locations and phone numbers.
#
# SERVICE ROUTING STRATEGY:
# Each business function gets its own URL path and port number:
# - Authentication: Handles user accounts and security
# - Events: Manages event creation, updates, and browsing
# - Notifications: Sends emails and SMS messages to users
# - Bookings: Processes event reservations (ready to deploy)
# - Payments: Handles payment transactions (ready to deploy)
#
# HEALTH CHECK STRATEGY:
# Each service provides a health endpoint (/actuator/health) that reports:
# - Service status (healthy/unhealthy)
# - Database connectivity
# - System resource usage
# - Dependency availability

locals {
  # Business services configuration (active services)
  services = {
    auth = {
      name              = "auth-service"                    # User authentication and account management
      port              = 8081                             # Network port where service listens
      path_pattern      = "/api/v1/auth/*"                 # URL pattern for routing user login/registration requests
      health_check_path = "/actuator/health"               # Endpoint to check if service is healthy
      priority          = 100                              # Routing priority (lower = higher priority)
    }
    event = {
      name              = "event-service"                   # Event creation and management
      port              = 8082                             # Network port for event operations
      path_pattern      = "/api/v1/events/*"               # URL pattern for event browsing/creation requests
      health_check_path = "/actuator/health"               # Health monitoring endpoint
      priority          = 200                              # Second priority for routing
    }
    notification = {
      name              = "notification-service"            # Email and SMS notifications
      port              = 8085                             # Network port for notification operations
      path_pattern      = "/api/v1/notifications/*"        # URL pattern for notification requests
      health_check_path = "/actuator/health"               # Service health check endpoint
      priority          = 500                              # Lower priority routing
    }
  }

  # Swagger documentation routes (separate from API routes)
  swagger_routes = {
    event_swagger_ui = {
      service_key  = "event"
      path_pattern = "/swagger-ui/*"
      priority     = 90
    }
    event_swagger_html = {
      service_key  = "event"
      path_pattern = "/swagger-ui.html"
      priority     = 91
    }
    event_api_docs = {
      service_key  = "event"
      path_pattern = "/v3/api-docs*"
      priority     = 92
    }
    auth_users = {
      service_key  = "auth"
      path_pattern = "/api/v1/users*"
      priority     = 93
    }
    event_invitations = {
      service_key  = "event"
      path_pattern = "/api/v1/event-invitations*"
      priority     = 94
    }
    event_meeting_types = {
      service_key  = "event"
      path_pattern = "/api/v1/event_meeting_types*"
      priority     = 95
    }
    event_types = {
      service_key  = "event"
      path_pattern = "/api/v1/event_types*"
      priority     = 96
    }
    tickets = {
      service_key  = "event"
      path_pattern = "/api/v1/tickets*"
      priority     = 97
    }
    timezones = {
      service_key  = "event"
      path_pattern = "/api/v1/timezones*"
      priority     = 98
    }
  }

  # booking = {
  #   name              = "booking-service"
  #   port              = 8083
  #   path_pattern      = "/api/v1/bookings/*"
  #   health_check_path = "/actuator/health"
  #   priority          = 300
  # }
  # payment = {
  #   name              = "payment-service"
  #   port              = 8084
  #   path_pattern      = "/api/v1/payments/*"
  #   health_check_path = "/actuator/health"
  #   priority          = 400
  # }
  # notification = {
  #   name              = "notification-service"
  #   port              = 8085
  #   path_pattern      = "/api/v1/notifications/*"
  #   health_check_path = "/actuator/health"
  #   priority          = 500
  # }

  common_tags = merge(
    var.tags,
    {
      Module      = "alb"
      Environment = var.environment
    }
  )
  lb_prefix = substr(replace(var.project_name, "-", ""), 0, 5)
}

# ==============================================================================
# Application Load Balancer
# ==============================================================================

resource "aws_lb" "main" {
  name_prefix        = "${local.lb_prefix}-"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # Enable deletion protection in production
  enable_deletion_protection = var.enable_deletion_protection

  # Enable cross-zone load balancing
  enable_cross_zone_load_balancing = true

  # Enable HTTP/2
  enable_http2 = true

  # Drop invalid headers
  drop_invalid_header_fields = true

  # Access logs to S3
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# ==============================================================================
# Target Groups
# ==============================================================================

# Create target group for each microservice
resource "aws_lb_target_group" "services" {
  for_each = local.services

  name_prefix = substr(each.value.name, 0, 6)
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  # Health check configuration
  health_check {
    enabled             = true
    path                = each.value.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    matcher             = "200-299"
  }

  # Deregistration delay (connection draining)
  deregistration_delay = var.deregistration_delay

  # Stickiness (disabled for stateless services)
  stickiness {
    type            = "lb_cookie"
    enabled         = false
    cookie_duration = 86400
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-tg"
      Service = each.value.name
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# HTTPS Listener (Port 443)
# ==============================================================================

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Default action: Return 404 for unknown paths
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        error   = "Not Found"
        message = "The requested resource was not found"
      })
      status_code = "404"
    }
  }

  tags = local.common_tags
}

# ==============================================================================
# HTTPS Listener Rules (Path-Based Routing)
# ==============================================================================

# Create listener rule for each microservice
resource "aws_lb_listener_rule" "service_routing" {
  for_each = var.certificate_arn != "" ? local.services : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-rule"
      Service = each.value.name
    }
  )
}

# ==============================================================================
# HTTPS Listener Rules - Swagger Documentation Routes
# ==============================================================================

resource "aws_lb_listener_rule" "swagger_routing" {
  for_each = var.certificate_arn != "" ? local.swagger_routes : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.value.service_key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}-swagger-rule"
    }
  )
}

# ==============================================================================
# HTTP Listener (Port 80) - Redirect to HTTPS
# ==============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Redirect to HTTPS when certificate exists
  dynamic "default_action" {
    for_each = var.certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  # Fixed response when no certificate
  dynamic "default_action" {
    for_each = var.certificate_arn == "" ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "ALB is running - Certificate not configured"
        status_code  = "200"
      }
    }
  }

  tags = local.common_tags
}

# HTTP Listener Rules for services (when no HTTPS)
resource "aws_lb_listener_rule" "http_service_routing" {
  for_each = var.certificate_arn == "" ? local.services : {}

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.value.name}-http-rule"
      Service = each.value.name
    }
  )
}

# HTTP Listener Rules - Swagger Documentation Routes (when no HTTPS)
resource "aws_lb_listener_rule" "http_swagger_routing" {
  for_each = var.certificate_arn == "" ? local.swagger_routes : {}

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.value.service_key].arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}-http-swagger-rule"
    }
  )
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

# Target response time alarm
resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.response_time_alarm_threshold
  alarm_description   = "ALB target response time is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

# 5XX error rate alarm
resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_5xx_alarm_threshold
  alarm_description   = "ALB 5XX error rate is too high"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

# Unhealthy target count alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  for_each = local.services

  alarm_name          = "${var.project_name}-${var.environment}-${each.value.name}-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "Unhealthy targets detected for ${each.value.name}"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.services[each.key].arn_suffix
  }

  tags = local.common_tags
}
