# ==============================================================================
# AWS Budgets Module - Cost Management and Alerts
# ==============================================================================
# This module creates AWS Budgets for proactive cost management with email
# notifications at multiple thresholds. It also implements Cost Anomaly Detection
# to catch unusual spending patterns using machine learning.
#
# Features:
# - Monthly budget tracking with cost filters by Project and Environment tags
# - Multiple alert thresholds: 80%, 90%, 100% (actual), 100% (forecasted)
# - Email notifications to multiple recipients (requires email confirmation)
# - Cost Anomaly Detection with immediate alerts for unusual spending
# - Zero additional cost (first 2 budgets are FREE, anomaly detection is FREE)
#
# Cost Impact:
# - First 2 AWS Budgets: FREE
# - Additional budgets: $0.02/day (~$0.60/month)
# - Cost Anomaly Detection: FREE (no limits)
# - Email notifications: Included in AWS free tier
#
# Important Notes:
# - Email subscribers must confirm subscription via email before receiving alerts
# - Budget tracking starts from the 1st of the month (time_period_start)
# - Cost filters use Project and Environment tags to track only relevant resources
# - All resources must be tagged properly for accurate cost tracking
# - Anomaly detection learns spending patterns over 7-10 days
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
# Monthly Budget with Multiple Thresholds
# ==============================================================================
# Creates a monthly cost budget with email notifications at multiple thresholds.
# Tracks actual spending and forecasted costs to prevent budget overruns.
#
# Budget Configuration:
# - budget_type: COST (tracks actual AWS spending)
# - limit_amount: Monthly budget limit in USD (e.g., $200 for dev, $1200 for prod)
# - time_unit: MONTHLY (resets on the 1st of each month)
# - time_period_start: Budget start date (format: YYYY-MM-DD_HH:MM)
#
# Cost Filtering:
# - Filters costs by Project and Environment tags
# - Only tracks resources with matching tags
# - Format: user:TagKey$TagValue (e.g., user:Project$event-planner)
# - Ensures accurate cost tracking for this project only
#
# Notification Thresholds:
# 1. 80% - Warning: Review spending, identify cost drivers
# 2. 90% - Critical: Immediate action needed, stop non-essential resources
# 3. 100% (actual) - Budget exceeded: Emergency cost reduction
# 4. 100% (forecasted) - Projected to exceed: Proactive cost management
#
# Email Notification Process:
# 1. AWS sends confirmation email to each subscriber
# 2. Subscriber must click confirmation link
# 3. After confirmation, subscriber receives budget alerts
# 4. Alerts include: budget name, threshold, actual spend, forecasted spend
# ==============================================================================

resource "aws_budgets_budget" "monthly_cost" {
  # Budget name: event-planner-dev-monthly-budget
  name = "${var.project_name}-${var.environment}-monthly-budget"

  # Budget type: COST tracks actual AWS spending (alternatives: USAGE, SAVINGS_PLANS_COVERAGE)
  budget_type = "COST"

  # Monthly budget limit in USD (e.g., 200 for dev, 1200 for prod)
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"

  # Time unit: MONTHLY (budget resets on the 1st of each month)
  time_unit = "MONTHLY"

  # Budget start date (format: YYYY-MM-DD_HH:MM)
  # Budget tracking begins from this date
  time_period_start = "2024-12-01_00:00"

  # Cost filter: Only track costs for resources with matching Project and Environment tags
  # This ensures the budget only tracks costs for this specific project and environment
  # Format: user:TagKey$TagValue (double $ is required for Terraform string interpolation)
  # Example: user:Project$event-planner, user:Environment$dev
  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Project$${var.project_name}",     # Filter by Project tag (e.g., event-planner)
      "user:Environment$${var.environment}"   # Filter by Environment tag (e.g., dev, prod)
    ]
  }

  # ==============================================================================
  # Notification 1: 80% Threshold (Warning)
  # ==============================================================================
  # Triggers when actual spending reaches 80% of the monthly budget
  # Example: $160 of $200 budget
  # Action: Review spending, identify cost drivers, optimize if needed
  notification {
    comparison_operator        = "GREATER_THAN"           # Alert when spending > threshold
    threshold                  = 80                       # 80% of budget limit
    threshold_type             = "PERCENTAGE"            # Percentage of budget (not absolute amount)
    notification_type          = "ACTUAL"                # Based on actual spending (not forecasted)
    subscriber_email_addresses = var.alert_email_addresses  # List of email recipients
  }

  # ==============================================================================
  # Notification 2: 90% Threshold (Critical Warning)
  # ==============================================================================
  # Triggers when actual spending reaches 90% of the monthly budget
  # Example: $180 of $200 budget
  # Action: Immediate action needed, stop non-essential resources, review all costs
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90                       # 90% of budget limit
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email_addresses
  }

  # ==============================================================================
  # Notification 3: 100% Threshold (Budget Exceeded)
  # ==============================================================================
  # Triggers when actual spending reaches or exceeds 100% of the monthly budget
  # Example: $200 of $200 budget (or more)
  # Action: Emergency cost reduction, stop all non-critical resources immediately
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100                      # 100% of budget limit
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email_addresses
  }

  # ==============================================================================
  # Notification 4: 100% Forecasted (Projected to Exceed)
  # ==============================================================================
  # Triggers when AWS forecasts that spending will reach 100% by month-end
  # Based on current spending trends and historical data
  # Example: Spent $120 by day 15, forecasted to reach $210 by month-end
  # Action: Proactive cost management, optimize resources before budget is exceeded
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100                      # 100% of budget limit
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"            # Based on AWS cost forecast
    subscriber_email_addresses = var.alert_email_addresses
  }
}

# ==============================================================================
# Cost Anomaly Detection Monitor
# ==============================================================================
# Creates a machine learning-based cost anomaly monitor that automatically detects
# unusual spending patterns across AWS services.
#
# How It Works:
# 1. Monitors spending by AWS service (ECS, RDS, NAT Gateway, etc.)
# 2. Uses machine learning to learn normal spending patterns (7-10 days)
# 3. Detects anomalies when spending deviates significantly from normal
# 4. Sends immediate email alerts when anomalies are detected
#
# Monitor Types:
# - DIMENSIONAL: Monitors by specific dimension (SERVICE, LINKED_ACCOUNT, etc.)
# - CUSTOM: Custom cost categories
#
# Monitor Dimensions:
# - SERVICE: Monitors each AWS service separately (ECS, RDS, S3, etc.)
# - LINKED_ACCOUNT: Monitors by AWS account (for multi-account setups)
# - USAGE_TYPE: Monitors by usage type (data transfer, compute, storage)
#
# Benefits:
# - Catches misconfigurations (e.g., forgot to stop resources overnight)
# - Detects unexpected cost spikes (e.g., NAT Gateway data transfer surge)
# - No manual threshold configuration needed (ML learns automatically)
# - FREE service with no usage limits
#
# Example Anomalies Detected:
# - NAT Gateway cost jumps from $1/day to $3/day (forgot to stop resources)
# - ECS task count increases from 1 to 10 (auto-scaling misconfiguration)
# - RDS storage grows from 20GB to 50GB (unexpected data growth)
# - S3 data transfer spikes (application bug causing excessive API calls)
# ==============================================================================

resource "aws_ce_anomaly_monitor" "service_monitor" {
  # Monitor name: event-planner-dev-anomaly-monitor
  name = "${var.project_name}-${var.environment}-anomaly-monitor"

  # Monitor type: DIMENSIONAL (monitors by specific dimension like SERVICE)
  monitor_type = "DIMENSIONAL"

  # Monitor dimension: SERVICE (monitors each AWS service separately)
  # This allows detection of anomalies in specific services (e.g., ECS, RDS, NAT Gateway)
  # Note: Cannot use monitor_specification with monitor_dimension (mutually exclusive)
  monitor_dimension = "SERVICE"
}

# ==============================================================================
# Cost Anomaly Detection Subscription
# ==============================================================================
# Creates a subscription to receive email alerts when cost anomalies are detected.
# Subscribers receive immediate notifications when spending anomalies exceed the
# configured threshold.
#
# Subscription Configuration:
# - frequency: IMMEDIATE (send alerts as soon as anomalies are detected)
#   Alternatives: DAILY (daily summary), WEEKLY (weekly summary)
# - monitor_arn_list: List of anomaly monitors to subscribe to
# - subscribers: List of email addresses to receive alerts
#
# Threshold Configuration:
# - ANOMALY_TOTAL_IMPACT_ABSOLUTE: Dollar amount of the anomaly
# - Example: Alert if anomaly > $25 (dev) or $100 (prod)
# - Prevents alert fatigue from small anomalies
#
# Email Notification Process:
# 1. AWS detects cost anomaly using machine learning
# 2. Checks if anomaly exceeds threshold ($25 for dev)
# 3. Sends immediate email to all subscribers
# 4. Email includes: service name, anomaly amount, expected cost, actual cost
#
# Example Email:
# Subject: AWS Cost Anomaly Detected
# Body:
#   Service: NAT Gateway
#   Anomaly Amount: $2.50
#   Expected Cost: $1.00/day
#   Actual Cost: $3.50/day
#   Impact: 250% increase
#
# Threshold Recommendations:
# - Development: $25 (catches significant anomalies, avoids noise)
# - Production: $100 (higher threshold for larger infrastructure)
# - Adjust based on normal spending patterns after 30 days
# ==============================================================================

resource "aws_ce_anomaly_subscription" "anomaly_alerts" {
  # Subscription name: event-planner-dev-anomaly-subscription
  name = "${var.project_name}-${var.environment}-anomaly-subscription"

  # Frequency: DAILY (daily summary of anomalies)
  # Note: IMMEDIATE frequency only supports 1 subscriber, so using DAILY for multiple emails
  # DAILY sends a summary of all anomalies detected in the past 24 hours
  frequency = "DAILY"

  # List of anomaly monitors to subscribe to
  # This subscription receives alerts from the service_monitor created above
  monitor_arn_list = [
    aws_ce_anomaly_monitor.service_monitor.arn
  ]

  # Dynamic block: Create a subscriber for each email address in the list
  # This allows multiple team members to receive anomaly alerts
  # Each subscriber must confirm their email before receiving alerts
  # Note: DAILY frequency supports multiple subscribers (IMMEDIATE only supports 1)
  dynamic "subscriber" {
    for_each = var.alert_email_addresses
    content {
      type    = "EMAIL"              # Notification type (EMAIL or SNS)
      address = subscriber.value     # Email address from the list
    }
  }

  # Threshold expression: Only alert if anomaly exceeds this dollar amount
  # This prevents alert fatigue from small, insignificant anomalies
  threshold_expression {
    dimension {
      # ANOMALY_TOTAL_IMPACT_ABSOLUTE: Dollar amount of the anomaly
      # Example: If NAT Gateway normally costs $1/day but suddenly costs $3/day,
      # the anomaly impact is $2. Alert only if this exceeds the threshold.
      key = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"

      # Threshold value in USD (e.g., "25" for $25)
      # Development: $25 (catches significant anomalies)
      # Production: $100 (higher threshold for larger infrastructure)
      values = [var.anomaly_threshold]

      # Match option: Alert when anomaly >= threshold
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }
}
