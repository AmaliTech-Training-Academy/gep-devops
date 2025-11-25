# AWS Infrastructure Architecture - Production Environment
## Event Planner Platform

**Version:** 3.0  
**Last Updated:** November 2025  
**Environment:** Production  
**Deployment Model:** Multi-AZ, High Availability

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Network Architecture](#network-architecture)
4. [Compute Layer](#compute-layer)
5. [Data Layer](#data-layer)
6. [Messaging Architecture](#messaging-architecture)
7. [Caching Strategy](#caching-strategy)
8. [Load Balancing](#load-balancing)
9. [Security](#security)
10. [Monitoring](#monitoring)
11. [Disaster Recovery](#disaster-recovery)
12. [Cost Optimization](#cost-optimization)

---

## 1. Executive Summary

Production environment for Event Planner Platform optimized for high availability and performance.

**Key Characteristics:**
- **Multi-AZ Deployment** - 2 Availability Zones
- **4 Active Microservices** - Auth, Event, Payment, Notification
- **Consolidated Database** - Single PostgreSQL with multi-schema and read replicas
- **Auto-Scaling** - Dynamic scaling based on load
- **Cost Target** - ~$800-1200/month

**Architecture Decisions:**
- ALB with path-based routing (no API Gateway)
- AWS Cloud Map for service discovery (no Discovery service)
- PostgreSQL JSONB for audit logs (no DocumentDB)
- Multi-node Redis cluster with replication
- SQS/SNS for messaging
- Blue-Green deployment support

---

## 2. Architecture Overview

### 2.1 Active Services

| Service | Port | Purpose | Min Tasks | Max Tasks |
|---------|------|---------|-----------|-----------|
| Auth Service | 8081 | Authentication & user management | 2 | 8 |
| Event Service | 8082 | Event creation & management | 2 | 10 |
| Payment Service | 8088 | Payment processing (Paystack) | 2 | 8 |
| Notification Service | 8085 | Email/SMS notifications | 2 | 6 |

### 2.2 Service Discovery

**AWS Cloud Map** - `eventplanner.local` namespace
- `auth-service.eventplanner.local:8081`
- `event-service.eventplanner.local:8082`
- `payment-service.eventplanner.local:8088`
- `notification-service.eventplanner.local:8085`

### 2.3 Data Stores

**PostgreSQL RDS** - Multi-AZ with read replicas:
- `auth_schema` - User authentication data
- `event_schema` - Event management data
- `payment_schema` - Payment transactions
- `audit_schema` - JSONB audit logs

**ElastiCache Redis** - Cluster mode with replication

### 2.4 External Access

- **Frontend**: `events.sankofagrid.com` → CloudFront → S3
- **Backend API**: `api.sankofagrid.com` → ALB → ECS Services
- **DNS**: Managed by Cloudflare

---

## 3. Network Architecture

### 3.1 VPC Configuration

**VPC CIDR:** `10.0.0.0/16`  
**Region:** eu-west-1  
**Availability Zones:** eu-west-1a, eu-west-1b (Multi-AZ)

### 3.2 Subnets

| Subnet | CIDR | AZ | Purpose |
|--------|------|----|---------|
| Public AZ-A | `10.0.1.0/24` | eu-west-1a | ALB, NAT Gateway |
| Public AZ-B | `10.0.2.0/24` | eu-west-1b | ALB, NAT Gateway |
| Private App AZ-A | `10.0.10.0/24` | eu-west-1a | ECS Fargate tasks |
| Private App AZ-B | `10.0.11.0/24` | eu-west-1b | ECS Fargate tasks |
| Private Data AZ-A | `10.0.20.0/24` | eu-west-1a | RDS, ElastiCache |
| Private Data AZ-B | `10.0.21.0/24` | eu-west-1b | RDS, ElastiCache |

### 3.3 Network Components

**Internet Gateway** - Public internet access  
**NAT Gateways** - 2 gateways (one per AZ) for high availability  
**VPC Endpoints** - S3, ECR, CloudWatch, Secrets Manager (cost savings)

### 3.4 Security Groups

**ALB Security Group:**
- Inbound: 443 (HTTPS), 80 (HTTP redirect)
- Outbound: 8081-8088 to ECS

**ECS Security Group:**
- Inbound: 8081-8088 from ALB
- Inbound: All from same SG (inter-service)
- Outbound: 5432 to RDS, 6379 to Redis, 443 to internet

**RDS Security Group:**
- Inbound: 5432 from ECS only

**ElastiCache Security Group:**
- Inbound: 6379 from ECS only

---

## 4. Compute Layer

### 4.1 ECS Cluster

**Cluster:** `event-planner-prod-cluster`  
**Launch Type:** Fargate (70% on-demand, 30% Spot)  
**Distribution:** Even across 2 AZs

### 4.2 Service Configuration

| Service | vCPU | Memory | Min | Max | Auto-Scale Target |
|---------|------|--------|-----|-----|-------------------|
| Auth | 0.5 | 1 GB | 2 | 8 | 70% CPU |
| Event | 1 | 2 GB | 2 | 10 | 70% CPU |
| Payment | 1 | 2 GB | 2 | 8 | 70% CPU |
| Notification | 0.5 | 1 GB | 2 | 6 | 70% CPU |

**Task Distribution:**
- Minimum 1 task per AZ per service
- Spread placement strategy across AZs
- Auto-scaling based on CPU and memory

### 4.3 Container Configuration

**Base Image:** `amazoncorretto:17-alpine`  
**Health Check:** `/actuator/health` (30s interval)  
**Logging:** CloudWatch Logs (30-day retention)  
**Environment:** Injected via Secrets Manager

### 4.4 Auto-Scaling

**Target Tracking:**
- CPU: 70% target
- Memory: 75% target
- Scale-out cooldown: 60 seconds
- Scale-in cooldown: 300 seconds

**Step Scaling (rapid spikes):**
- CPU > 80%: Add 50% capacity
- CPU > 90%: Add 100% capacity

---

## 5. Data Layer

### 5.1 PostgreSQL RDS

**Instance:** `db.t4g.large` (Multi-AZ)  
**Storage:** 100 GB gp3  
**Engine:** PostgreSQL 15  
**Backup:** Daily, 7-day retention

**Multi-AZ Configuration:**
- Primary in AZ-A
- Standby in AZ-B (synchronous replication)
- Automatic failover < 60 seconds

**Read Replicas:**
- 2 read replicas (one per AZ)
- Asynchronous replication (< 1 second lag)
- Used for read-heavy operations

**Multi-Schema Design:**
```sql
-- Separate schemas for each service
auth_schema     -- User accounts, roles, permissions
event_schema    -- Events, invitations
payment_schema  -- Transactions, withdrawals
audit_schema    -- JSONB audit logs
```

**Connection Pooling:**
- HikariCP with max 20 connections per service
- Read/write splitting for optimal performance

**Read/Write Splitting:**
```java
// Primary for writes
@Primary
@Bean
public DataSource writeDataSource() {
    // Primary RDS endpoint
}

// Replicas for reads
@Bean
public DataSource readDataSource() {
    // Read replica endpoint (round-robin)
}
```

### 5.2 Audit Logs (PostgreSQL JSONB)

**Schema:** `audit_schema.audit_log_jsonb`

**Table Structure:**
```sql
CREATE TABLE audit_schema.audit_log_jsonb (
    id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    data JSONB NOT NULL
);

CREATE INDEX idx_audit_timestamp ON audit_log_jsonb(timestamp);
CREATE INDEX idx_audit_data_gin ON audit_log_jsonb USING GIN(data);
CREATE INDEX idx_audit_user ON audit_log_jsonb((data->>'userId'));
CREATE INDEX idx_audit_service ON audit_log_jsonb((data->>'service'));
```

**Benefits:**
- No separate DocumentDB ($400/month savings)
- Flexible document storage
- Fast queries with GIN indexes
- Read replicas support audit queries
- Unified backup strategy

### 5.3 ElastiCache Redis

**Configuration:** Cluster mode enabled  
**Nodes:** 3 shards × 2 replicas = 6 nodes  
**Node Type:** `cache.t4g.medium`  
**Distribution:** Across 2 AZs  
**Backup:** Daily snapshots, 7-day retention

**High Availability:**
- Automatic failover
- Multi-AZ replication
- Read replicas for each shard

**Use Cases:**
- OTP storage (5-minute TTL)
- Session management (30-minute TTL)
- API response caching (15-minute TTL)
- Rate limiting data

---

## 6. Messaging Architecture

### 6.1 SQS/SNS Configuration

**SNS Topics:**
- `event-planner-prod-event-topic`
- `event-planner-prod-payment-topic`

**SQS Queues:**

| Queue | Subscriber | Retention | DLQ | Visibility Timeout |
|-------|------------|-----------|-----|-------------------|
| user-registration-queue | Auth | 4 days | Yes | 30s |
| user-login-queue | Auth | 4 days | Yes | 30s |
| event-created-queue | Event | 4 days | Yes | 30s |
| event-invitation-queue | Notification | 4 days | Yes | 30s |
| payment-processing-queue | Payment | 4 days | Yes | 60s |
| payment-status-queue | Event | 4 days | Yes | 30s |
| notification-queue | Notification | 4 days | Yes | 30s |
| withdrawal-notification-queue | Notification | 4 days | Yes | 30s |
| webhook-event-queue | Payment | 4 days | Yes | 60s |

**Dead Letter Queues:**
- Max receive count: 3
- Retention: 14 days
- CloudWatch alarm on messages > 0
- Automated replay mechanism

### 6.2 Message Flow

```
Auth Service → SNS → SQS → Notification Service
Event Service → SNS → SQS → Notification Service
Payment Service → SNS → SQS → Event/Notification Services
```

**FIFO Queues (for critical operations):**
- Payment processing queue (exactly-once delivery)
- Webhook event queue (ordered processing)

---

## 7. Caching Strategy

### 7.1 Redis Cache Patterns

**OTP Storage:**
```
Key: otp:{userId}
TTL: 5 minutes
Shard: Based on userId hash
```

**Session Data:**
```
Key: session:{sessionId}
TTL: 30 minutes (sliding)
Shard: Based on sessionId hash
```

**Event Cache:**
```
Key: event:{eventId}
TTL: 15 minutes
Shard: Based on eventId hash
```

**API Response Cache:**
```
Key: api:{endpoint}:{params}
TTL: 5 minutes
Shard: Based on endpoint hash
```

### 7.2 Cache Invalidation

Event-driven invalidation via SQS messages:
- `event.updated` → Invalidate event cache
- `event.deleted` → Invalidate event cache
- `payment.completed` → Invalidate related caches
- `user.updated` → Invalidate session cache

### 7.3 Cache Monitoring

**Metrics:**
- Cache hit rate (target > 80%)
- Eviction rate
- Memory usage per shard
- Connection count

**Alarms:**
- Cache hit rate < 70%
- Memory usage > 80%
- Evictions > 1000/min

---

## 8. Load Balancing

### 8.1 Application Load Balancer

**Configuration:**
- Internet-facing in public subnets
- Multi-AZ (both AZs)
- HTTPS listener (ACM certificate)
- HTTP → HTTPS redirect
- Cross-zone load balancing enabled

**Path-Based Routing:**

| Path | Target Service | Health Check | Deregistration Delay |
|------|---------------|--------------|---------------------|
| `/api/auth/*` | Auth Service | `/actuator/health` | 30s |
| `/api/events/*` | Event Service | `/actuator/health` | 30s |
| `/api/payments/*` | Payment Service | `/actuator/health` | 60s |
| `/api/notifications/*` | Notification Service | `/actuator/health` | 30s |

**Target Groups:**
- Health check interval: 30 seconds
- Healthy threshold: 2
- Unhealthy threshold: 3
- Timeout: 5 seconds
- Sticky sessions: Disabled (stateless services)

### 8.2 SSL/TLS Configuration

**Certificate:** AWS Certificate Manager (ACM)  
**Protocol:** TLS 1.2+  
**Cipher Suite:** AWS recommended security policy  
**HSTS:** Enabled (max-age=31536000)

---

## 9. Security

### 9.1 IAM Roles

**ECS Task Execution Role:**
- Pull images from ECR
- Write logs to CloudWatch
- Retrieve secrets from Secrets Manager

**ECS Task Roles (per service):**
- Publish to SNS topics
- Poll from SQS queues
- Access specific AWS resources
- Least privilege principle

### 9.2 Secrets Management

**AWS Secrets Manager:**
- `event-planner/prod/jwt-secret` (auto-rotation enabled)
- `event-planner/prod/google-credentials`
- `event-planner/prod/paystack-credentials`
- `event-planner/prod/redis-credentials`
- `event-planner/prod/db-credentials` (auto-rotation enabled)

**Rotation Policy:**
- Database credentials: 30 days
- JWT secrets: 90 days
- API keys: Manual rotation

### 9.3 Encryption

**At Rest:**
- RDS: KMS encryption (customer-managed key)
- ElastiCache: Encryption enabled
- S3: SSE-KMS
- EBS volumes: KMS encryption

**In Transit:**
- ALB to clients: TLS 1.2+
- ECS to RDS: SSL/TLS enforced
- ECS to Redis: TLS enabled
- Inter-service: TLS via Cloud Map

### 9.4 Network Security

**Private Subnets:**
- All application and data resources in private subnets
- No direct internet access
- Outbound via NAT Gateway only

**Security Group Rules:**
- Least privilege access
- No 0.0.0.0/0 inbound except ALB
- Stateful rules
- Regular security group audits

**AWS WAF (Optional):**
- Rate limiting rules
- SQL injection protection
- XSS protection
- Geo-blocking if needed

### 9.5 Compliance

**CloudTrail:** All API calls logged  
**AWS Config:** Compliance monitoring  
**GuardDuty:** Threat detection  
**Security Hub:** Centralized security findings

---

## 10. Monitoring

### 10.1 CloudWatch Dashboards

**Service-Specific Dashboards:**
- Auth Service Dashboard
- Event Service Dashboard
- Payment Service Dashboard
- Notification Service Dashboard

**Infrastructure Dashboard:**
- ECS cluster health
- ALB performance
- RDS metrics
- ElastiCache metrics
- SQS queue depths

**Business Dashboard:**
- Events created (hourly/daily)
- Payments processed
- Active users
- Revenue metrics

### 10.2 CloudWatch Metrics

**ECS Metrics:**
- CPU utilization (per service)
- Memory utilization (per service)
- Task count (running, pending, desired)
- Service deployment status

**ALB Metrics:**
- Request count
- Target response time (p50, p95, p99)
- HTTP 4xx/5xx errors
- Active connections
- Healthy/unhealthy targets

**RDS Metrics:**
- CPU utilization
- Database connections
- Read/Write IOPS
- Replication lag (< 1 second target)
- Free storage space
- Query performance

**ElastiCache Metrics:**
- CPU utilization
- Cache hit rate (> 80% target)
- Evictions
- Memory usage
- Network throughput

**SQS Metrics:**
- Messages visible
- Messages in flight
- Age of oldest message
- DLQ message count

### 10.3 CloudWatch Alarms

**Critical Alarms (PagerDuty):**
- ECS CPU > 80% for 5 minutes
- ECS Memory > 85% for 5 minutes
- ALB 5xx errors > 10/min for 5 minutes
- RDS CPU > 80% for 10 minutes
- RDS connections > 80% of max
- Replication lag > 5 seconds
- SQS DLQ messages > 0
- Payment failures > 5%

**Warning Alarms (Email/Slack):**
- ECS CPU > 70% for 10 minutes
- Cache hit rate < 70%
- Disk space < 20%
- API latency p95 > 500ms

### 10.4 Log Groups

- `/ecs/event-planner/prod/auth-service`
- `/ecs/event-planner/prod/event-service`
- `/ecs/event-planner/prod/payment-service`
- `/ecs/event-planner/prod/notification-service`
- `/aws/rds/instance/eventplannerdb/postgresql`
- `/aws/elasticloadbalancing/app/event-planner-prod-alb`

**Retention:** 30 days  
**Archive:** S3 Glacier after 30 days

### 10.5 Grafana Monitoring

**Access:** `https://api.sankofagrid.com/monitoring/`

**Data Sources:**
- CloudWatch metrics
- PostgreSQL audit logs
- Application metrics (Micrometer)

**Dashboards:**
- Executive Dashboard (business KPIs)
- Infrastructure Dashboard (system health)
- Performance Dashboard (API latency, throughput)
- Security Dashboard (auth failures, security events)
- Cost Dashboard (daily/monthly spend)

**Alerting:**
- Slack integration
- Email notifications
- PagerDuty for critical alerts

### 10.6 X-Ray Tracing (Optional)

**Configuration:**
- Sampling rate: 5% of requests
- 100% of error traces
- Service map visualization
- Performance bottleneck identification

---

## 11. Disaster Recovery

### 11.1 DR Objectives

**RTO:** < 15 minutes  
**RPO:** < 5 minutes

### 11.2 DR Strategy

**Approach:** Warm Standby in secondary region

**Primary Region:** eu-west-1  
**DR Region:** eu-west-2

### 11.3 DR Configuration

**Compute (DR Region):**
- ECS cluster with minimal capacity (1 task per service)
- Can scale up rapidly when activated
- Same container images in ECR (replicated)

**Database (DR Region):**
- RDS Cross-Region Read Replica (asynchronous)
- Replication lag: typically < 5 seconds
- Can be promoted to standalone in DR scenario

**Cache (DR Region):**
- Daily snapshot copy
- Restore time: ~5 minutes

**Data Synchronization:**
- RDS: Continuous replication via read replica
- S3: Cross-region replication enabled
- Secrets Manager: Replicated to DR region

### 11.4 Failover Process

**Automated Failover (Route 53):**
1. Route 53 health check detects primary region failure
2. DNS failover to DR region ALB (TTL: 60 seconds)
3. CloudWatch alarm triggers Lambda function
4. Lambda scales up ECS services in DR region
5. Lambda promotes RDS read replica to primary
6. Services become available in DR region

**Estimated Failover Time:**
- DNS propagation: 1-2 minutes
- ECS scale-up: 3-5 minutes
- RDS promotion: 2-3 minutes
- Cache restore: 5 minutes
- **Total: ~12-15 minutes**

### 11.5 Backup Strategy

**RDS Backups:**
- Automated daily backups
- Retention: 7 days
- Cross-region copy: Daily
- Point-in-time recovery: Up to 7 days
- Manual snapshots before major deployments

**ElastiCache Backups:**
- Daily automated snapshots
- Retention: 7 days
- Cross-region copy: Weekly

**Application Data:**
- S3 versioning enabled
- Cross-region replication
- Lifecycle policy: Archive to Glacier after 90 days

**Configuration Backups:**
- Infrastructure as Code (Terraform) in Git
- ECS task definitions versioned
- Secrets replicated to DR region

### 11.6 DR Testing

**Quarterly DR Drills:**
- Simulate primary region failure
- Execute failover procedures
- Validate RTO/RPO metrics
- Document lessons learned
- Update runbooks

---

## 12. Cost Optimization

### 12.1 Monthly Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| ECS Fargate | 4 services, avg 4 tasks, 70% on-demand, 30% Spot | ~$250-300 |
| RDS PostgreSQL | db.t4g.large, Multi-AZ, 2 read replicas, 100 GB | ~$300-350 |
| ElastiCache | 6 nodes (cache.t4g.medium), Multi-AZ | ~$150-180 |
| ALB | 1 ALB + data transfer | ~$40-50 |
| NAT Gateway | 2 gateways + data transfer | ~$70-90 |
| SQS/SNS | ~10M requests/month | ~$5-10 |
| CloudWatch | Logs, metrics, alarms | ~$50-70 |
| S3 | Frontend hosting + backups | ~$20-30 |
| CloudFront | CDN for frontend | ~$30-40 |
| Secrets Manager | 5 secrets with rotation | ~$10-15 |
| VPC Endpoints | 4 interface endpoints | ~$30-40 |

**Total: ~$800-1200/month**

### 12.2 Cost Optimization Strategies

**Fargate Spot:**
- 30% Spot capacity for non-critical workloads
- Savings: ~$70/month

**Reserved Instances:**
- 1-year RDS reserved instance
- Savings: ~$100/month

**VPC Endpoints:**
- Reduces NAT Gateway data transfer
- Savings: ~$30/month

**Right-Sizing:**
- Monitor actual usage
- Adjust resources based on metrics
- Use AWS Compute Optimizer recommendations

**Architecture Simplifications:**
- No API Gateway (ALB path-based routing): Save ~$100/month
- No Discovery Service (AWS Cloud Map): Save ~$50/month
- No DocumentDB (PostgreSQL JSONB): Save ~$400/month
- **Total Savings: ~$550/month**

### 12.3 Cost Monitoring

**CloudWatch Cost Dashboard:**
- Daily spend by service
- Monthly trend analysis
- Budget alerts at 80% and 100%
- Cost anomaly detection

**AWS Cost Explorer:**
- Service-level cost breakdown
- Reserved instance recommendations
- Savings plan opportunities

---

## Appendix A: Service Endpoints

### Internal (Cloud Map DNS)
- `auth-service.eventplanner.local:8081`
- `event-service.eventplanner.local:8082`
- `payment-service.eventplanner.local:8088`
- `notification-service.eventplanner.local:8085`

### External (Public)
- Frontend: `https://events.sankofagrid.com`
- Backend API: `https://api.sankofagrid.com`
- Monitoring: `https://api.sankofagrid.com/monitoring/`

---

## Appendix B: Deployment Strategy

### Blue-Green Deployment

**Process:**
1. Deploy new version (Green) alongside current (Blue)
2. Run smoke tests on Green environment
3. Gradually shift traffic from Blue to Green (10%, 25%, 50%, 100%)
4. Monitor metrics and error rates
5. Rollback to Blue if issues detected
6. Terminate Blue environment after successful deployment

**Rollback Time:** < 5 minutes

---

## Appendix C: Scaling Limits

| Resource | Current | Limit | Action Threshold |
|----------|---------|-------|------------------|
| ECS Tasks per Service | ~20 | 1000 | 800 |
| RDS Connections | ~100 | 500 | 400 |
| ElastiCache Memory | ~2 GB | 10 GB | 8 GB |
| ALB Target Groups | 4 | 100 | 80 |
| SQS Messages | ~1M/day | Unlimited | N/A |

---

**Document Version:** 3.0  
**Last Updated:** November 2025  
**Maintained By:** DevOps Team
