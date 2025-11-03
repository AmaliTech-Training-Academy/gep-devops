# Event Planner Platform - DevOps Infrastructure Documentation
## Part 5: Monitoring, Security, and Operations

**Author:** DevOps Team  
**Last Updated:** October 30, 2025  
**Version:** 1.0.0

---

## Monitoring Architecture

The Event Planner Platform implements **comprehensive monitoring** across infrastructure, applications, and business metrics using AWS CloudWatch, custom dashboards, and automated alerting.
There are also monitoring dashboards built on Grafana accessible to non-engineering teams without AWS console access. 

For Engineers who wants the technical documentation on the grafana dashboards. Refer to [Grafana Monitoring Plan](./GRAFANA-MONITORING-PLAN.md) and [Grafana Deployment Summary](./GRAFANA-DEPLOYMENT-SUMMARY.md)

For Non-engineers, refer to the [Grafana Dashboard User Guide](./GRAFANA-DASHBOARD-USER-GUIDE.md), then [Click Here](https://api.sankofagrid.com/monitoring/) to access the dashboards.

### Monitoring Stack

```
Monitoring Layer:
├── CloudWatch Metrics      # Infrastructure & application metrics
├── CloudWatch Logs         # Centralized logging
├── CloudWatch Alarms       # Automated alerting
├── Custom Dashboards       # Service-specific visualizations
├── X-Ray Tracing          # Distributed tracing (planned)
└── Container Insights      # ECS container monitoring
```

---

## Infrastructure Monitoring

### 1. ECS Cluster Monitoring

**Container Insights**: Enabled for comprehensive ECS monitoring

```hcl
# ECS cluster with Container Insights
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
```

**Key Metrics Monitored**:
- **CPU Utilization**: Per service and cluster-wide
- **Memory Utilization**: Container memory usage patterns
- **Task Count**: Running vs desired task counts
- **Service Events**: Deployment and scaling events

### 2. Database Monitoring

**RDS CloudWatch Integration**:

```hcl
# RDS monitoring configuration
enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
performance_insights_enabled = var.enable_performance_insights
```

**Database Alarms**:

```hcl
# CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name = "${var.project_name}-${var.environment}-${each.key}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  threshold = var.cpu_alarm_threshold
  metric_name = "CPUUtilization"
  namespace = "AWS/RDS"
}

# Storage space alarm
resource "aws_cloudwatch_metric_alarm" "storage_low" {
  alarm_name = "${var.project_name}-${var.environment}-${each.key}-db-storage-low"
  comparison_operator = "LessThanThreshold"
  threshold = var.storage_alarm_threshold_bytes
  metric_name = "FreeStorageSpace"
}
```

### 3. Load Balancer Monitoring

**ALB Metrics**:
- **Request Count**: Total requests per minute
- **Response Time**: Average response latency
- **HTTP 5xx Errors**: Server error rate
- **Target Health**: Healthy vs unhealthy targets

```hcl
# ALB response time alarm
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name = "${var.project_name}-${var.environment}-alb-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  threshold = var.response_time_alarm_threshold
  metric_name = "TargetResponseTime"
  namespace = "AWS/ApplicationELB"
}
```

### 4. Cache Monitoring

**ElastiCache Redis Monitoring**:

```hcl
# Redis CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name = "${var.project_name}-${var.environment}-redis-cpu-high"
  threshold = var.cpu_utilization_threshold
  metric_name = "CPUUtilization"
  namespace = "AWS/ElastiCache"
}

# Memory utilization alarm
resource "aws_cloudwatch_metric_alarm" "redis_memory_high" {
  alarm_name = "${var.project_name}-${var.environment}-redis-memory-high"
  threshold = var.memory_utilization_threshold
  metric_name = "DatabaseMemoryUsagePercentage"
}
```

---

## Application Monitoring

### 1. Service Health Monitoring

**Health Check Endpoints**: All services expose Spring Boot Actuator endpoints

```yaml
# Container health check configuration
healthCheck = {
  command = [
    "CMD-SHELL",
    "curl -f http://localhost:${each.value.port}/actuator/health || exit 1"
  ]
  interval = 30
  timeout = 5
  retries = 3
  startPeriod = 90
}
```

**Health Check Endpoints**:
- `/actuator/health` - Overall service health
- `/actuator/metrics` - Application metrics
- `/actuator/info` - Service information
- `/actuator/prometheus` - Prometheus metrics (planned)

### 2. Centralized Logging

**CloudWatch Log Groups**: Separate log groups per service

```hcl
resource "aws_cloudwatch_log_group" "services" {
  for_each = local.services
  
  name = "/ecs/${var.project_name}/${var.environment}/${each.value.name}"
  retention_in_days = var.log_retention_days
  kms_key_id = var.kms_key_arn
}
```

**Log Configuration**:
- **Development**: 3-day retention for cost optimization
- **Production**: 30-day retention for compliance
- **Structured logging**: JSON format for better parsing
- **Log aggregation**: Centralized via CloudWatch Logs

### 3. Custom Dashboards

**Service-Specific Dashboards**: Created via Terraform

```hcl
# Auth service dashboard
resource "aws_cloudwatch_dashboard" "auth_service" {
  dashboard_name = "${var.project_name}-${var.environment}-auth-service"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "auth-service"],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "auth-service"]
          ]
          period = 300
          stat = "Average"
          region = var.aws_region
          title = "Auth Service - CPU & Memory"
        }
      }
    ]
  })
}
```

**Dashboard Categories**:
- **Infrastructure Overview**: High-level system health
- **Service Dashboards**: Per-service metrics and logs
- **Database Performance**: RDS metrics and slow queries
- **Cost Monitoring**: Resource utilization and costs

---

## Security Monitoring

### 1. Security Scanning Pipeline

**Trivy Security Scanning**: Integrated into CI/CD pipeline

```yaml
- name: Security Scan (Trivy)
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: 'services/${{ matrix.service }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
```

**Security Monitoring Workflow** (`security-monitoring.yml`):

```yaml
name: Security Monitoring

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  vulnerability-scan:
    runs-on: [self-hosted, backend]
    steps:
      - name: Container Vulnerability Scan
        run: |
          # Scan all ECR repositories for vulnerabilities
          for repo in $(aws ecr describe-repositories --query 'repositories[].repositoryName' --output text); do
            aws ecr describe-image-scan-findings --repository-name $repo
          done
```

### 2. Access Monitoring

**CloudTrail Integration**: All API calls logged and monitored

```hcl
# CloudTrail for API monitoring (planned)
resource "aws_cloudtrail" "main" {
  name = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket
  
  event_selector {
    read_write_type = "All"
    include_management_events = true
  }
}
```

### 3. Network Security Monitoring

**VPC Flow Logs**: Network traffic monitoring

```hcl
# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}
```

**Security Group Monitoring**:
- **Ingress rule changes**: Automated alerts for security group modifications
- **Unusual traffic patterns**: Monitoring for suspicious network activity
- **Failed connection attempts**: Tracking blocked connections

---

## Alerting and Notifications

### 1. SNS Topic Configuration

**Centralized Alerting**: Single SNS topic for all alerts

```hcl
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  
  delivery_policy = jsonencode({
    "http" = {
      "defaultHealthyRetryPolicy" = {
        "minDelayTarget" = 20
        "maxDelayTarget" = 20
        "numRetries" = 3
      }
    }
  })
}
```

### 2. Slack Integration

**Real-Time Notifications**: Slack webhook integration

```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  with:
    status: custom
    custom_payload: |
      {
        "text": "🚨 Alert: High CPU Usage Detected",
        "attachments": [{
          "color": "danger",
          "fields": [
            {
              "title": "Service",
              "value": "auth-service",
              "short": true
            },
            {
              "title": "CPU Usage",
              "value": "85%",
              "short": true
            }
          ]
        }]
      }
```

### 3. Alert Categories

**Critical Alerts** (Immediate Response):
- Service down or unhealthy
- Database connection failures
- High error rates (>5%)
- Security incidents

**Warning Alerts** (Monitor):
- High resource utilization (>80%)
- Slow response times (>2s)
- Storage space low (<20%)
- Deployment failures

**Info Alerts** (FYI):
- Successful deployments
- Scaling events
- Scheduled maintenance

---

## Operational Procedures

### 1. Health Monitoring Workflow

**Automated Health Checks** (`health-monitoring.yml`):

```yaml
name: Health Monitoring

on:
  schedule:
    - cron: '*/15 * * * *'  # Every 15 minutes

jobs:
  health-check:
    runs-on: [self-hosted, backend]
    steps:
      - name: Check Service Health
        run: |
          # Check all service endpoints
          SERVICES=("auth-service" "notification-service")
          
          for service in "${SERVICES[@]}"; do
            echo "Checking $service health..."
            
            # Check ECS service status
            aws ecs describe-services \
              --cluster "$ECS_CLUSTER" \
              --services "$service" \
              --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
            
            # Check HTTP endpoint
            curl -f "https://api.sankofagrid.com/$service/actuator/health" || {
              echo "❌ $service health check failed"
              # Send alert
            }
          done
```

### 2. Performance Monitoring

**Performance Monitoring Workflow** (`performance-monitoring.yml`):

```yaml
name: Performance Monitoring

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

jobs:
  performance-test:
    runs-on: [self-hosted, backend]
    steps:
      - name: Load Testing with K6
        run: |
          # Run load tests against API endpoints
          k6 run --vus 10 --duration 5m performance-tests/api-load-test.js
          
      - name: Lighthouse Audit
        run: |
          # Frontend performance audit
          lighthouse https://events.sankofagrid.com \
            --output json \
            --output-path lighthouse-report.json
```

### 3. Incident Response

**Incident Response Playbook**:

1. **Detection**: Automated alerts or manual discovery
2. **Assessment**: Determine severity and impact
3. **Response**: Execute appropriate response procedures
4. **Communication**: Update stakeholders via Slack
5. **Resolution**: Fix the issue and verify resolution
6. **Post-Mortem**: Document lessons learned

**Automated Incident Response**:

```yaml
# Example: Auto-scale on high CPU
- name: Auto-Scale on High Load
  run: |
    CPU_USAGE=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/ECS \
      --metric-name CPUUtilization \
      --dimensions Name=ServiceName,Value=auth-service \
      --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
      --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
      --period 300 \
      --statistics Average \
      --query 'Datapoints[0].Average')
    
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
      echo "High CPU detected ($CPU_USAGE%). Scaling up..."
      aws ecs update-service \
        --cluster "$ECS_CLUSTER" \
        --service auth-service \
        --desired-count 2
    fi
```

---

## Security Operations

### 1. Secrets Management

**AWS Secrets Manager Integration**:

```hcl
# Database credentials with automatic rotation
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}/${var.environment}/${each.key}-db-credentials"
  description = "Database credentials for ${each.key} service"
  
  # Enable automatic rotation
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn
  rotation_rules {
    automatically_after_days = 30
  }
}
```

**Secret Rotation Process**:
1. **Generate new credentials** in Secrets Manager
2. **Update database** with new credentials
3. **Update ECS services** to use new credentials
4. **Verify connectivity** with new credentials
5. **Remove old credentials** from database

### 2. Network Security

**Security Group Rules**: Least privilege access

```hcl
# ECS security group - only allow ALB traffic
resource "aws_security_group_rule" "ecs_ingress_alb" {
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8085
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs.id
}

# RDS security group - only allow ECS traffic
resource "aws_security_group_rule" "rds_ingress_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.rds.id
}
```

### 3. Compliance Monitoring

**Security Compliance Checks**:
- **SSL/TLS enforcement**: All connections encrypted
- **Database encryption**: At rest and in transit
- **Access logging**: All API calls logged
- **Vulnerability scanning**: Regular container scans
- **Secrets rotation**: Automated credential rotation

---

## Cost Monitoring

### 1. Cost Allocation Tags

**Comprehensive Tagging Strategy**:

```hcl
default_tags {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
    Team        = "DevOps"
    Compliance  = "Standard"
  }
}
```

### 2. Cost Optimization Monitoring

**Resource Utilization Tracking**:
- **ECS task utilization**: Right-sizing containers
- **RDS performance**: Identifying over-provisioned databases
- **ElastiCache hit rates**: Cache efficiency monitoring
- **S3 storage classes**: Lifecycle policy effectiveness

### 3. Budget Alerts

```hcl
# Cost budget with alerts
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.environment == "dev" ? "100" : "3000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters = {
    Tag = {
      Project = [var.project_name]
      Environment = [var.environment]
    }
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.alert_email_addresses
  }
}
```

---

## Operational Metrics

### Key Performance Indicators (KPIs)

**System Reliability**:
- **Uptime**: 99.9% target (dev), 99.99% target (prod)
- **Mean Time to Recovery (MTTR)**: <15 minutes
- **Mean Time Between Failures (MTBF)**: >720 hours

**Performance Metrics**:
- **API Response Time**: <500ms (95th percentile)
- **Database Query Time**: <100ms (average)
- **Cache Hit Rate**: >90%

**Deployment Metrics**:
- **Deployment Frequency**: 3-5 times/day (dev)
- **Deployment Success Rate**: >95%
- **Rollback Rate**: <5%

---

## Next Steps

This covers monitoring, security, and operations. Continue with:

- **Part 6**: Cost Optimization and Best Practices
- **Part 7**: Troubleshooting and Runbooks