# Main CloudWatch Dashboard Updates

## Changes Applied

### 1. Fixed ECS Metrics
**Problem:** Dashboard used `RunningTaskCount` metric which doesn't exist in AWS/ECS namespace.

**Solution:** Replaced with actual ECS metrics:
- Changed from `RunningTaskCount` to `CPUUtilization` and `MemoryUtilization`
- Created separate widgets for each service (Auth, Event, Notification, Payment)
- Each widget shows both CPU and Memory on dual Y-axes

### 2. Added Payment Service
**New Widget:** Payment Service - Resource Utilization
- CPU Utilization (left Y-axis)
- Memory Utilization (right Y-axis)
- Position: x=12, y=6

### 3. Reorganized Dashboard Layout
**New Structure:**
- Row 1 (y=0): Auth Service (left), Event Service (right)
- Row 2 (y=6): Notification Service (left), Payment Service (right)
- Row 3 (y=12): ALB Request Metrics (left), ALB Response Time (right)
- Row 4 (y=18): RDS Metrics (left), ElastiCache Metrics (right)
- Row 5 (y=24): CloudFront Metrics (left), SQS Queue Metrics (right)

### 4. Fixed ALB Metrics
**Changes:**
- Split ALB metrics into two widgets for better visibility
- Widget 1: Request Count & HTTP Status Codes (2XX, 4XX, 5XX)
- Widget 2: Response Time (Average and P99)

### 5. Fixed ElastiCache Metrics
**Problem:** Used incorrect CacheClusterId format.

**Solution:**
- Dashboard: Changed from `var.elasticache_cluster_id` to `"${var.elasticache_cluster_id}-001"`
- Alarms: Updated all ElastiCache alarms to use `-001` suffix
- CPU Metric: Changed from `CPUUtilization` to `EngineCPUUtilization`

### 6. Fixed SQS Queue Names
**Problem:** Queue names were missing `-queue` suffix.

**Solution:**
- `user-registration` → `user-registration-queue`
- `user-login` → `user-login-queue`
- `password-reset` → `password-reset-queue`
- `event-created-notification` → `notifications-queue`

### 7. Fixed Metric Names
- ElastiCache CPU: `CPUUtilization` → `EngineCPUUtilization`
- SQS Messages: `ApproximateNumberOfMessages` → `ApproximateNumberOfMessagesVisible`

## Dashboard Widgets Summary

| Widget | Position | Metrics | Status |
|--------|----------|---------|--------|
| Auth Service Resources | (0,0) | CPU, Memory | ✅ Working when service running |
| Event Service Resources | (12,0) | CPU, Memory | ✅ Working when service running |
| Notification Service Resources | (0,6) | CPU, Memory | ✅ Working when service running |
| Payment Service Resources | (12,6) | CPU, Memory | ✅ Working when service running |
| ALB Request Metrics | (0,12) | RequestCount, 2XX, 4XX, 5XX | ⚠️ Requires traffic |
| ALB Response Time | (12,12) | Avg, P99 | ⚠️ Requires traffic |
| RDS Database | (0,18) | CPU, Connections, Memory, Latency | ✅ Working when RDS running |
| ElastiCache Redis | (12,18) | CPU, Memory, Connections, Evictions | ✅ Working when cache running |
| CloudFront CDN | (0,24) | Requests, Bytes, Error Rates | ✅ Always working |
| SQS Queues | (12,24) | Message counts for 4 queues | ✅ Always working |

## Alarms Updated

### ElastiCache Alarms Fixed
1. **elasticache-cpu-high**
   - Metric: `EngineCPUUtilization`
   - Dimension: `CacheClusterId = "${var.elasticache_cluster_id}-001"`

2. **elasticache-memory-high**
   - Metric: `DatabaseMemoryUsagePercentage`
   - Dimension: `CacheClusterId = "${var.elasticache_cluster_id}-001"`

3. **elasticache-evictions**
   - Metric: `Evictions`
   - Dimension: `CacheClusterId = "${var.elasticache_cluster_id}-001"`

## Services Included

1. **Auth Service** - Authentication and user management
2. **Event Service** - Event creation and management
3. **Notification Service** - Email and SMS notifications
4. **Payment Service** - Payment processing (NEW)

## Metrics That Require Traffic

These metrics will show "no data" until services receive requests:
- ALB RequestCount
- ALB TargetResponseTime
- ALB HTTPCode_Target_2XX/4XX/5XX_Count

## Metrics That Require Running Services

These metrics will show "no data" when services are scaled to 0:
- ECS CPUUtilization
- ECS MemoryUtilization

## Metrics That Require Running Infrastructure

These metrics will show "no data" when infrastructure is stopped:
- RDS metrics (when database is stopped)
- ElastiCache metrics (when cache is stopped)

## Always Available Metrics

These metrics always have data:
- CloudFront Requests, BytesDownloaded, Error Rates
- SQS ApproximateNumberOfMessagesVisible

## Testing the Dashboard

To see all metrics populated:

1. **Start Infrastructure:**
   ```bash
   # Start RDS
   aws rds start-db-instance --db-instance-identifier event-planner-dev-auth-db --region eu-west-1 --profile gtp-cletus
   ```

2. **Scale Services:**
   ```bash
   # Scale all services to 1 task
   for service in auth-service event-service notification-service payment-service; do
     aws ecs update-service --cluster event-planner-dev-cluster --service $service --desired-count 1 --region eu-west-1 --profile gtp-cletus
   done
   ```

3. **Generate Traffic:**
   - Access frontend: https://events.sankofagrid.com
   - Make API calls: https://api.sankofagrid.com/api/v1/auth/health

4. **Wait 5-10 minutes** for metrics to populate

## Dashboard Access

**AWS Console:**
CloudWatch → Dashboards → `event-planner-dev-dashboard`

**Direct Link:**
https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=event-planner-dev-dashboard
