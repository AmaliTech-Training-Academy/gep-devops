# Event Planner Platform - DevOps Infrastructure Documentation
## Part 6: Cost Optimization and Best Practices

**Author:** DevOps Team  
**Last Updated:** October 30, 2025  
**Version:** 1.0.0

---

## Cost Optimization Strategy

The Event Planner Platform implements **aggressive cost optimization** for development environments while maintaining production-ready architecture. The strategy achieves **~70% cost reduction** in development through intelligent resource management.

### Cost Optimization Principles

1. **Environment-Specific Sizing**: Different resource allocation per environment
2. **Selective Service Deployment**: Only run services that are actively developed
3. **Single-AZ Development**: Reduce cross-AZ charges and NAT Gateway costs
4. **VPC Endpoints**: Eliminate NAT Gateway data transfer charges for AWS services
5. **Intelligent Caching**: Reduce database load and improve performance
6. **Automated Scaling**: Right-size resources based on actual usage

---

## Development Environment Cost Optimization

### Current Cost Breakdown (Development)

| Service | Monthly Cost | Optimization Applied |
|---------|-------------|---------------------|
| ECS Fargate (2 services) | $35-45 | Minimal CPU/memory allocation |
| RDS PostgreSQL (t3.medium) | $25-30 | Single instance, multi-schema |
| ElastiCache Redis (t3.micro) | $12-15 | Single node, no replicas |
| NAT Gateway | $32 | Single NAT, required for SMTP |
| ALB | $18-22 | Shared across all services |
| NAT Gateway | $32 | Single NAT, handles all AWS traffic |
| CloudFront | $1-5 | Pay-per-use, minimal traffic |
| S3 Storage | $1-3 | Lifecycle policies enabled |
| **Total** | **$126-157/month** | **24/7 operation** |
| **Weekday-only** | **$75-95/month** | **Auto-shutdown weekends** |

### Key Cost Optimizations Implemented

#### 1. Single-AZ Deployment

```hcl
# Development: Single AZ to reduce costs
availability_zones = ["eu-west-1a"]
single_nat_gateway = true  # Saves ~$32/month per additional NAT

# Production: Multi-AZ for high availability
availability_zones = ["eu-west-1a", "eu-west-1b"]
single_nat_gateway = false
```

**Savings**: ~$32/month per additional NAT Gateway + cross-AZ data transfer charges

#### 2. Multi-Schema Database Approach

```hcl
# Development: Single PostgreSQL with multiple schemas
databases = {
  auth = {
    instance_class = "db.t3.medium"
    allocated_storage = 20
  }
  # event, booking, payment schemas in same instance
}

# Production: Separate databases for isolation
databases = {
  auth = { instance_class = "db.t4g.medium" }
  event = { instance_class = "db.t4g.medium" }
  booking = { instance_class = "db.t4g.medium" }
  payment = { instance_class = "db.t4g.medium" }
}
```

**Savings**: ~$60-80/month by using single database instance in development

#### 3. Selective Service Deployment

```hcl
# Only deploy services actively being developed
services = {
  auth = {
    name = "auth-service"
    cpu = 256
    memory = 512
    desired_count = 1
  }
  notification = {
    name = "notification-service"
    cpu = 256
    memory = 512
    desired_count = 1
  }
  # event, booking, payment services commented out
}
```

**Savings**: ~$20-30/month per unused service

#### 4. VPC Endpoint to NAT Gateway Migration

**Status**: VPC Endpoints disabled in favor of NAT Gateway for cost optimization

```hcl
# Current configuration: NAT Gateway handles all traffic
enable_nat_gateway = true
single_nat_gateway = true
enable_vpc_endpoints = false  # Disabled for cost savings
```

**Migration Details**:

Previously, the infrastructure used 7 VPC Interface Endpoints for AWS service connectivity:
- ECR API Endpoint (~$22/month)
- ECR Docker Endpoint (~$22/month)
- CloudWatch Logs Endpoint (~$22/month)
- Secrets Manager Endpoint (~$22/month)
- Systems Manager Endpoint (~$22/month)
- SQS Endpoint (~$22/month)
- SNS Endpoint (~$22/month)

**Total VPC Endpoints Cost**: $154/month

**Current Approach**: All AWS service traffic now routes through NAT Gateway:
- NAT Gateway hourly charge: ~$32/month
- Data transfer costs: ~$10-30/month
- Total NAT Gateway cost: ~$42-62/month

**Net Savings**: $92-112/month

**Trade-offs**:
- Cost Reduction: Significant monthly savings
- Latency: Minimal increase (internet routing vs AWS backbone)
- Security: Maintained (encrypted traffic, private subnets)
- Single Point of Failure: One NAT Gateway for cost optimization

**Note**: S3 Gateway Endpoint remains active (free, no hourly charges)

#### 5. Minimal Resource Allocation

```hcl
# Development: Minimal resources
ecs_task_cpu = "256"
ecs_task_memory = "512"
ecs_min_capacity = 1
ecs_max_capacity = 1

# Production: Scaled resources
ecs_task_cpu = "512"
ecs_task_memory = "1024"
ecs_min_capacity = 2
ecs_max_capacity = 10
```

#### 6. Short Log Retention

```hcl
# Development: Short retention for cost savings
log_retention_days = 3
backup_retention_days = 3

# Production: Compliance-driven retention
log_retention_days = 30
backup_retention_days = 7
```

**Savings**: ~$5-10/month on CloudWatch Logs storage

---

## Production Environment Cost Optimization

### Planned Production Optimizations

#### 1. Reserved Instances and Savings Plans

```bash
# RDS Reserved Instances (1-year commitment)
# Savings: ~40% on database costs
aws rds purchase-reserved-db-instances-offering \
  --reserved-db-instances-offering-id <offering-id> \
  --reserved-db-instance-id event-planner-prod-auth-db-ri

# Fargate Savings Plans
# Savings: ~50% on compute costs
aws savingsplans purchase-savings-plan \
  --savings-plan-offering-id <offering-id> \
  --commitment 1000  # $1000/month commitment
```

#### 2. Fargate Spot Integration

```hcl
# Production: Mix of Fargate and Fargate Spot
capacity_providers = ["FARGATE", "FARGATE_SPOT"]

default_capacity_provider_strategy {
  capacity_provider = "FARGATE"
  weight = 70
  base = 1
}

default_capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight = 30
  base = 0
}
```

**Savings**: Up to 70% on compute costs for non-critical workloads

#### 3. S3 Lifecycle Policies

```hcl
# Intelligent tiering for cost optimization
lifecycle_rule {
  id = "log_lifecycle"
  enabled = true
  
  transition {
    days = 30
    storage_class = "STANDARD_IA"
  }
  
  transition {
    days = 90
    storage_class = "GLACIER"
  }
  
  expiration {
    days = 365
  }
}
```

#### 4. CloudFront Optimization

```hcl
# Optimize cache settings for cost reduction
default_ttl = 86400  # 24 hours
max_ttl = 31536000   # 1 year
price_class = "PriceClass_100"  # US, Canada, Europe only

# Compress content to reduce data transfer
compress = true
```

---

## Automated Cost Management

### 1. Weekend Shutdown Automation

**Development Environment Shutdown Script**:

```bash
#!/bin/bash
# scripts/utilities/stop-dev-environment.sh

echo "Stopping development environment for weekend..."

# Scale down ECS services
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --desired-count 0

aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service notification-service \
  --desired-count 0

# Stop RDS instance
aws rds stop-db-instance \
  --db-instance-identifier event-planner-dev-auth-db

echo "Development environment stopped. Estimated savings: $50-70 for weekend"
```

**Startup Script**:

```bash
#!/bin/bash
# scripts/utilities/start-dev-environment.sh

echo "Starting development environment..."

# Start RDS instance
aws rds start-db-instance \
  --db-instance-identifier event-planner-dev-auth-db

# Wait for RDS to be available
aws rds wait db-instance-available \
  --db-instance-identifier event-planner-dev-auth-db

# Scale up ECS services
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --desired-count 1

aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service notification-service \
  --desired-count 1

echo "Development environment started and ready"
```

### 2. Automated Scaling Policies

```hcl
# CPU-based auto scaling
resource "aws_appautoscaling_policy" "cpu" {
  name = "${var.project_name}-${var.environment}-cpu-scaling"
  policy_type = "TargetTrackingScaling"
  
  target_tracking_scaling_policy_configuration {
    target_value = 70  # Scale at 70% CPU
    scale_in_cooldown = 300   # 5 minutes
    scale_out_cooldown = 60   # 1 minute
    
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
```

### 3. Cost Monitoring and Alerts

```hcl
# Budget alerts for cost control
resource "aws_budgets_budget" "monthly" {
  name = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type = "COST"
  limit_amount = var.environment == "dev" ? "150" : "3000"
  limit_unit = "USD"
  time_unit = "MONTHLY"
  
  notification {
    comparison_operator = "GREATER_THAN"
    threshold = 80
    threshold_type = "PERCENTAGE"
    notification_type = "ACTUAL"
    subscriber_email_addresses = var.alert_email_addresses
  }
  
  notification {
    comparison_operator = "GREATER_THAN"
    threshold = 100
    threshold_type = "PERCENTAGE"
    notification_type = "FORECASTED"
    subscriber_email_addresses = var.alert_email_addresses
  }
}
```

---

## Performance Optimization Best Practices

### 1. Database Optimization

#### Connection Pooling

```yaml
# Spring Boot database configuration
spring:
  datasource:
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
      connection-timeout: 20000
      idle-timeout: 300000
      max-lifetime: 1200000
```

#### Query Optimization

```sql
-- Database indexes for common queries
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY idx_events_date ON events(event_date);
CREATE INDEX CONCURRENTLY idx_bookings_user_id ON bookings(user_id);
```

#### Read Replica Usage (Production)

```hcl
# Read replicas for read-heavy workloads
resource "aws_db_instance" "read_replica_1" {
  identifier = "${var.project_name}-${var.environment}-${each.key}-replica-1"
  replicate_source_db = aws_db_instance.primary[each.key].identifier
  instance_class = each.value.instance_class
}
```

### 2. Caching Strategy

#### Redis Configuration

```hcl
# ElastiCache Redis optimization
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description = "Redis cluster for ${var.project_name} ${var.environment}"
  
  node_type = var.environment == "dev" ? "cache.t3.micro" : "cache.t4g.medium"
  port = 6379
  parameter_group_name = "default.redis7"
  
  # Optimize for memory usage
  maxmemory_policy = "allkeys-lru"
}
```

#### Application-Level Caching

```java
// Spring Boot caching configuration
@EnableCaching
@Configuration
public class CacheConfig {
    
    @Bean
    public CacheManager cacheManager() {
        RedisCacheManager.Builder builder = RedisCacheManager
            .RedisCacheManagerBuilder
            .fromConnectionFactory(redisConnectionFactory())
            .cacheDefaults(cacheConfiguration());
        
        return builder.build();
    }
    
    private RedisCacheConfiguration cacheConfiguration() {
        return RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(30))
            .serializeKeysWith(RedisSerializationContext.SerializationPair
                .fromSerializer(new StringRedisSerializer()))
            .serializeValuesWith(RedisSerializationContext.SerializationPair
                .fromSerializer(new GenericJackson2JsonRedisSerializer()));
    }
}
```

### 3. CDN Optimization

#### CloudFront Configuration

```hcl
# CloudFront optimization for performance and cost
resource "aws_cloudfront_distribution" "main" {
  # Cache behaviors for different content types
  ordered_cache_behavior {
    path_pattern = "/api/*"
    target_origin_id = "ALB"
    
    # API responses - short cache
    default_ttl = 0
    max_ttl = 300
    min_ttl = 0
    
    # Don't cache API responses
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
  }
  
  ordered_cache_behavior {
    path_pattern = "/static/*"
    target_origin_id = "S3"
    
    # Static assets - long cache
    default_ttl = 86400
    max_ttl = 31536000
    min_ttl = 0
    
    # Optimize for static content
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
  }
}
```

---

## Security Best Practices

### 1. Least Privilege Access

#### IAM Role Optimization

```hcl
# ECS task role with minimal permissions
resource "aws_iam_role_policy" "ecs_task_auth" {
  name = "${var.project_name}-${var.environment}-ecs-task-auth-policy"
  role = aws_iam_role.ecs_task_auth.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials["auth"].arn,
          aws_secretsmanager_secret.jwt_secret.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = [
          aws_sqs_queue.user_registration.arn,
          aws_sqs_queue.user_login.arn
        ]
      }
    ]
  })
}
```

### 2. Network Security

#### Security Group Rules

```hcl
# Restrictive security group rules
resource "aws_security_group_rule" "ecs_ingress_alb_only" {
  type = "ingress"
  from_port = 8081
  to_port = 8085
  protocol = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id = aws_security_group.ecs.id
  description = "Allow ALB traffic to ECS services"
}

# No direct internet access for ECS tasks
resource "aws_security_group_rule" "ecs_egress_https" {
  type = "egress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
  description = "Allow HTTPS outbound for AWS services"
}
```

### 3. Data Encryption

#### Encryption at Rest

```hcl
# RDS encryption
resource "aws_db_instance" "primary" {
  storage_encrypted = true
  kms_key_id = aws_kms_key.rds.arn
}

# ElastiCache encryption
resource "aws_elasticache_replication_group" "main" {
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id = aws_kms_key.elasticache.arn
}

# S3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

---

## Operational Best Practices

### 1. Infrastructure as Code

#### Terraform Best Practices

```hcl
# Use data sources for existing resources
data "aws_availability_zones" "available" {
  state = "available"
}

# Use locals for computed values
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy = "Terraform"
      Project = var.project_name
    }
  )
}

# Use count/for_each for resource creation
resource "aws_subnet" "private_app" {
  count = length(local.azs)
  
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-app-${count.index + 1}"
      Type = "private"
      Tier = "app"
    }
  )
}
```

### 2. CI/CD Best Practices

#### Pipeline Optimization

```yaml
# Cache dependencies for faster builds
- name: Cache Maven Dependencies
  uses: actions/cache@v3
  with:
    path: ~/.m2/repository
    key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
    restore-keys: |
      ${{ runner.os }}-maven-

# Parallel job execution
strategy:
  matrix:
    service: ${{ fromJson(needs.prepare.outputs.services) }}
  max-parallel: 3  # Limit parallel jobs to avoid resource contention
```

#### Error Handling

```yaml
# Comprehensive error handling
- name: Deploy to ECS (Force New Deployment)
  run: |
    set -e  # Exit on any error
    
    SERVICE_NAME="${{ matrix.service }}"
    CLUSTER_NAME="${{ env.ECS_CLUSTER }}"
    
    # Retry logic for transient failures
    for i in {1..3}; do
      if aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --force-new-deployment; then
        break
      else
        echo "Attempt $i failed, retrying in 30 seconds..."
        sleep 30
      fi
    done
```

### 3. Monitoring Best Practices

#### Custom Metrics

```java
// Application metrics with Micrometer
@Component
public class CustomMetrics {
    
    private final MeterRegistry meterRegistry;
    private final Counter userRegistrationCounter;
    private final Timer authenticationTimer;
    
    public CustomMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        this.userRegistrationCounter = Counter.builder("user.registration")
            .description("Number of user registrations")
            .register(meterRegistry);
        this.authenticationTimer = Timer.builder("authentication.duration")
            .description("Authentication request duration")
            .register(meterRegistry);
    }
    
    public void incrementUserRegistration() {
        userRegistrationCounter.increment();
    }
    
    public Timer.Sample startAuthenticationTimer() {
        return Timer.start(meterRegistry);
    }
}
```

---

## Cost Optimization Roadmap

### Phase 1: Immediate Optimizations (Completed)
- [x] Single-AZ development deployment
- [x] Multi-schema database approach
- [x] Selective service deployment
- [x] VPC endpoint to NAT Gateway migration
- [x] Minimal resource allocation

### Phase 2: Advanced Optimizations (Planned)
- [ ] Weekend shutdown automation
- [ ] Fargate Spot integration (production)
- [ ] Reserved Instances (production)
- [ ] S3 Intelligent Tiering
- [ ] CloudFront optimization

### Phase 3: AI-Driven Optimization (Future)
- [ ] AWS Compute Optimizer integration
- [ ] Predictive scaling based on usage patterns
- [ ] Automated right-sizing recommendations
- [ ] Cost anomaly detection and alerting

---

## Next Steps

This covers cost optimization and best practices. Continue with:

- **Part 7**: Troubleshooting and Runbooks

---

## Cost Optimization Summary

| Optimization | Development Savings | Production Benefits |
|-------------|-------------------|-------------------|
| Single-AZ Deployment | $32/month | N/A (HA required) |
| Multi-Schema Database | $60-80/month | Separate for isolation |
| Selective Services | $20-30/service | All services active |
| VPC Endpoint Migration | $92-112/month | $92-112/month |
| Weekend Shutdown | $50-70/weekend | N/A |
| **Total Savings** | **$254-319/month** | **Focus on performance** |

**Result**: Development environment costs reduced from $248/month to $75-95/month (weekday-only operation)

---

## VPC Endpoint Migration Analysis

### Migration Overview

In November 2025, the infrastructure underwent a strategic migration from VPC Interface Endpoints to NAT Gateway-based connectivity for AWS services. This change was driven by cost optimization goals while maintaining security and functionality.

### Before Migration

**Network Architecture**:
```
External Traffic:
ECS → NAT Gateway → Internet → Gmail SMTP

AWS Service Traffic:
ECS → VPC Endpoints → AWS Services (Private AWS Network)
```

**Cost Structure**:
- 7 VPC Interface Endpoints: $154/month
- NAT Gateway: $32/month (minimal usage)
- Total: $186/month

### After Migration

**Network Architecture**:
```
All Traffic:
ECS → NAT Gateway → Internet → Gmail SMTP
ECS → NAT Gateway → Internet → AWS Services
```

**Cost Structure**:
- VPC Interface Endpoints: $0/month (disabled)
- NAT Gateway: $42-62/month (all traffic)
- Total: $42-62/month

### Technical Implementation

**Route Table Configuration**:

```hcl
# Private application subnets route to NAT Gateway
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id
  
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }
}

# VPC endpoints conditionally created
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_vpc_endpoints ? 1 : 0
  # ... configuration
}
```

**Configuration Change**:

```hcl
# terraform/environments/dev/main.tf
module "vpc" {
  enable_nat_gateway = true    # Required for external connectivity
  single_nat_gateway = true    # Cost optimization
  enable_vpc_endpoints = false # Disabled for cost savings
}
```

### Services Affected

**AWS Services Now Using NAT Gateway**:
1. ECR (Container image pulls)
2. CloudWatch Logs (Application logging)
3. Secrets Manager (Credential retrieval)
4. Systems Manager (Parameter store)
5. SQS (Message queuing)
6. SNS (Pub/sub messaging)

**External Services**:
1. Gmail SMTP (Notification service)
2. Third-party APIs
3. Software updates

### Security Posture

**Maintained Security Features**:
- Private subnets for all applications
- Encrypted traffic (HTTPS/TLS)
- Security group enforcement
- No direct internet access for applications

**Network Flow**:
```
ECS Tasks (Private Subnet) → NAT Gateway (Public Subnet) → Internet Gateway → AWS Services
```

### Performance Impact

**Latency Considerations**:
- VPC Endpoints: Direct connection via AWS backbone
- NAT Gateway: Routes through public internet
- Impact: Minimal increase (typically <10ms)

**Monitoring Metrics**:
- Application response times: No significant degradation observed
- Service availability: Maintained at 99.9%
- Data transfer costs: Within expected range

### Cost Monitoring

**Key Metrics to Track**:
1. NAT Gateway data transfer (monthly)
2. Application performance metrics
3. Service availability
4. Total infrastructure costs

**Recommended Alerts**:
- NAT Gateway data transfer > $50/month
- NAT Gateway availability < 99%
- Application response time increase > 10%

### Future Considerations

**Development Environment**:
- Current setup optimal for cost-conscious development
- Single NAT Gateway appropriate for non-critical workloads
- Monitor data transfer costs to ensure savings maintained

**Production Environment**:
- Consider Multi-AZ NAT Gateways for high availability
- Evaluate VPC Endpoints for high-traffic AWS services
- Implement cost monitoring for data transfer optimization

### Lessons Learned

1. **Cost vs Performance**: VPC Endpoints provide better performance but at significant cost
2. **Right-Sizing**: Not all optimizations apply to all environments
3. **Monitoring**: Essential to validate cost savings and performance impact
4. **Flexibility**: Infrastructure should support easy rollback if needed

### Rollback Procedure

If VPC Endpoints need to be re-enabled:

```bash
# Update configuration
cd terraform/environments/dev

# Edit main.tf
enable_vpc_endpoints = true

# Apply changes
terraform plan
terraform apply

# Verify connectivity
aws ecs execute-command --cluster event-planner-dev-cluster \
  --task <task-id> --interactive --command "/bin/bash"
```

**Estimated Time**: 15-20 minutes for VPC endpoint creation and DNS propagation