# CloudWatch Dashboard Metrics Analysis

## Summary

All dashboards have been updated with:
1. Removed all emojis from titles and headers
2. Fixed Redis metrics to use correct CacheClusterId format (`${replication_group_id}-001`)
3. Verified all metric names are correct

## Metrics Status by Dashboard

### Auth Service Dashboard

**Working Metrics (when service is running):**
- ECS CPU Utilization
- ECS Memory Utilization
- RDS Database CPU
- RDS Database Connections
- RDS Database Latency
- SQS Queue Messages (user-registration, user-login, password-reset)
- SQS Message Age

**Metrics Requiring Traffic:**
- Request Volume (ALB RequestCount)
- Response Time (ALB TargetResponseTime)
- HTTP Status Codes (ALB HTTPCode_Target_2XX/4XX/5XX_Count)

**Redis Metrics (when ElastiCache is running):**
- Redis CPU (EngineCPUUtilization)
- Redis Memory (DatabaseMemoryUsagePercentage)
- Redis Connections (CurrConnections)
- Redis Evictions

### Notification Service Dashboard

**Working Metrics (when service is running):**
- ECS CPU/Memory Utilization
- SQS Notifications Queue Messages
- SQS Message Processing Time
- SQS Dead Letter Queue
- SQS Queue Throughput
- SES Email Send Statistics (when emails are sent)
- SES Email Delivery Rate

### Event Service Dashboard

**Working Metrics (when service is running):**
- ECS CPU/Memory Utilization
- SQS Event Queues (event-created, event-updated)
- SQS Message Throughput

**Metrics Requiring Traffic:**
- Request Rate
- HTTP Status Distribution
- Response Time Analysis

### Frontend CloudFront Dashboard

**Working Metrics (always):**
- CloudFront Requests
- CloudFront Cache Hit Rate
- CloudFront Bytes Downloaded
- CloudFront Origin Latency
- CloudFront Error Rates (4xx, 5xx)
- S3 Bucket Size (daily metric)
- S3 Object Count (daily metric)

**Metrics Requiring Traffic:**
- S3 Requests (AllRequests, GetRequests, PutRequests)
- S3 Errors (4xxErrors, 5xxErrors)

## Why Some Metrics Show "No Data"

### 1. Services Scaled to Zero
When ECS services are scaled to 0 tasks:
- No ECS metrics (CPU, Memory)
- No ALB target metrics (RequestCount, TargetResponseTime, HTTPCode_*)
- No application logs

### 2. Infrastructure Stopped
When RDS/ElastiCache are stopped:
- No database metrics
- No cache metrics

### 3. No Traffic
Even with running services, some metrics need actual requests:
- ALB HTTP status codes only appear when requests are made
- Response time metrics need actual responses
- SES metrics need emails to be sent

### 4. Metric Reporting Delays
Some AWS metrics have delays:
- S3 BucketSizeBytes: Updated daily
- S3 NumberOfObjects: Updated daily
- CloudWatch Logs: Near real-time but can have 1-2 minute delay

## Current Infrastructure State

Based on previous commands:
- **ECS Services**: Scaled to 0 (auth, event, notification)
- **RDS**: Stopped (event-planner-dev-auth-db)
- **ElastiCache**: Running (event-planner-dev-redis)
- **NAT Gateway**: Deleted
- **CloudFront**: Active and serving traffic
- **S3**: Active with static content

## To See All Metrics Populated

1. **Start RDS Instance**:
   ```bash
   aws rds start-db-instance --db-instance-identifier event-planner-dev-auth-db --region eu-west-1 --profile gtp-cletus
   ```

2. **Scale ECS Services**:
   ```bash
   aws ecs update-service --cluster event-planner-dev-cluster --service auth-service --desired-count 1 --region eu-west-1 --profile gtp-cletus
   aws ecs update-service --cluster event-planner-dev-cluster --service notification-service --desired-count 1 --region eu-west-1 --profile gtp-cletus
   aws ecs update-service --cluster event-planner-dev-cluster --service event-service --desired-count 1 --region eu-west-1 --profile gtp-cletus
   ```

3. **Generate Traffic**:
   - Access frontend: https://events.sankofagrid.com
   - Make API calls to: https://api.sankofagrid.com/api/v1/auth/health
   - Trigger notifications, events, etc.

4. **Wait 5-10 minutes** for metrics to populate in CloudWatch

## Metrics Configuration Verification

All metrics are correctly configured:
- ✅ Correct namespace (AWS/ECS, AWS/RDS, AWS/ElastiCache, AWS/ApplicationELB, AWS/SQS, AWS/CloudFront, AWS/S3)
- ✅ Correct metric names
- ✅ Correct dimensions (ServiceName, ClusterName, DBInstanceIdentifier, CacheClusterId, TargetGroup, QueueName, DistributionId, BucketName)
- ✅ Correct statistics (Average, Sum, Maximum, p50, p90, p99)
- ✅ Appropriate periods (60s for real-time, 300s for aggregated)

## Redis Metrics Fix

Changed from:
```hcl
"CacheClusterId", var.elasticache_cluster_id
```

To:
```hcl
"CacheClusterId", "${var.elasticache_cluster_id}-001"
```

This is because ElastiCache replication groups create individual cache nodes with `-001`, `-002` suffixes.
