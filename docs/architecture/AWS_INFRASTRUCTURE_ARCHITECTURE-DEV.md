# AWS Infrastructure Architecture - Development Environment
## Event Planner Platform

**Version:** 3.0  
**Last Updated:** November 2025  
**Environment:** Development  
**Deployment Model:** Single-AZ, Cost-Optimized

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
11. [Cost Optimization](#cost-optimization)

---

## 1. Executive Summary

Development environment for Event Planner Platform optimized for cost and simplicity.

**Key Characteristics:**
- **Single-AZ Deployment** - eu-west-1a only
- **4 Active Microservices** - Auth, Event, Payment, Notification
- **Consolidated Database** - Single PostgreSQL with multi-schema
- **Minimal Resources** - 1 task per service, smallest instance types
- **Cost Target** - ~$150-200/month

**Architecture Decisions:**
- ALB with path-based routing (no API Gateway)
- AWS Cloud Map for service discovery (no Discovery service)
- PostgreSQL JSONB for audit logs (no DocumentDB)
- Single-node Redis cache
- SQS/SNS for messaging

---

## 2. Architecture Overview

### 2.1 Active Services

| Service | Port | Purpose | Tasks |
|---------|------|---------|-------|
| Auth Service | 8081 | Authentication & user management | 1 |
| Event Service | 8082 | Event creation & management | 1 |
| Payment Service | 8088 | Payment processing (Paystack) | 1 |
| Notification Service | 8085 | Email/SMS notifications | 1 |

### 2.2 Service Discovery

**AWS Cloud Map** - `eventplanner.local` namespace
- `auth-service.eventplanner.local:8081`
- `event-service.eventplanner.local:8082`
- `payment-service.eventplanner.local:8088`
- `notification-service.eventplanner.local:8085`

### 2.3 Data Stores

**PostgreSQL RDS** - Single instance with schemas:
- `auth_schema` - User authentication data
- `event_schema` - Event management data
- `payment_schema` - Payment transactions
- `audit_schema` - JSONB audit logs

**ElastiCache Redis** - Single node for caching

### 2.4 External Access

- **Frontend**: `events.sankofagrid.com` → CloudFront → S3
- **Backend API**: `api.sankofagrid.com` → ALB → ECS Services
- **DNS**: Managed by Cloudflare

---

## 3. Network Architecture

### 3.1 VPC Configuration

**VPC CIDR:** `10.0.0.0/16`  
**Region:** eu-west-1  
**Availability Zone:** eu-west-1a (Single-AZ)

### 3.2 Subnets

| Subnet | CIDR | Purpose |
|--------|------|---------|
| Public | `10.0.1.0/24` | ALB, NAT Gateway |
| Private App | `10.0.10.0/24` | ECS Fargate tasks |
| Private Data | `10.0.20.0/24` | RDS, ElastiCache |

### 3.3 Network Components

**Internet Gateway** - Public internet access  
**NAT Gateway** - Single gateway for outbound traffic  
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

**Cluster:** `event-planner-dev-cluster`  
**Launch Type:** Fargate  
**Capacity:** 1 task per service (4 total)

### 4.2 Service Configuration

| Service | vCPU | Memory | Min | Max | Auto-Scale Target |
|---------|------|--------|-----|-----|-------------------|
| Auth | 0.25 | 512 MB | 1 | 2 | 80% CPU |
| Event | 0.25 | 512 MB | 1 | 2 | 80% CPU |
| Payment | 0.25 | 512 MB | 1 | 2 | 80% CPU |
| Notification | 0.25 | 512 MB | 1 | 2 | 80% CPU |

### 4.3 Container Configuration

**Base Image:** `amazoncorretto:17-alpine`  
**Health Check:** `/actuator/health` (30s interval)  
**Logging:** CloudWatch Logs (7-day retention)  
**Environment:** Injected via Secrets Manager

---

## 5. Data Layer

### 5.1 PostgreSQL RDS

**Instance:** `db.t3.micro` (Single-AZ)  
**Storage:** 20 GB gp3  
**Engine:** PostgreSQL 15  
**Backup:** Daily, 3-day retention

**Multi-Schema Design:**
```sql
-- Separate schemas for each service
auth_schema     -- User accounts, roles, permissions
event_schema    -- Events, invitations
payment_schema  -- Transactions, withdrawals
audit_schema    -- JSONB audit logs
```

**Connection Pooling:**
- HikariCP with max 5 connections per service
- Connection timeout: 30 seconds

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
```

**Benefits:**
- No separate DocumentDB ($70/month savings)
- Flexible document storage
- Fast queries with GIN indexes
- Unified backup strategy

### 5.3 ElastiCache Redis

**Node:** `cache.t3.micro` (Single node)  
**Engine:** Redis 7.x  
**Backup:** Daily snapshots, 7-day retention

**Use Cases:**
- OTP storage (5-minute TTL)
- Session management (30-minute TTL)
- API response caching (15-minute TTL)

---

## 6. Messaging Architecture

### 6.1 SQS/SNS Configuration

**SNS Topics:**
- `event-planner-dev-event-topic`
- `event-planner-dev-payment-topic`

**SQS Queues:**

| Queue | Subscriber | Retention | DLQ |
|-------|------------|-----------|-----|
| user-registration-queue | Auth | 4 days | Yes |
| user-login-queue | Auth | 4 days | Yes |
| event-created-queue | Event | 4 days | Yes |
| event-invitation-queue | Notification | 4 days | Yes |
| payment-processing-queue | Payment | 4 days | Yes |
| payment-status-queue | Event | 4 days | Yes |
| notification-queue | Notification | 4 days | Yes |
| withdrawal-notification-queue | Notification | 4 days | Yes |
| webhook-event-queue | Payment | 4 days | Yes |

**Dead Letter Queues:**
- Max receive count: 3
- Retention: 14 days
- CloudWatch alarm on messages > 0

### 6.2 Message Flow

```
Auth Service → SNS → SQS → Notification Service
Event Service → SNS → SQS → Notification Service
Payment Service → SNS → SQS → Event/Notification Services
```

---

## 7. Caching Strategy

### 7.1 Redis Cache Patterns

**OTP Storage:**
```
Key: otp:{userId}
TTL: 5 minutes
```

**Session Data:**
```
Key: session:{sessionId}
TTL: 30 minutes (sliding)
```

**Event Cache:**
```
Key: event:{eventId}
TTL: 15 minutes
```

### 7.2 Cache Invalidation

Event-driven invalidation via SQS messages:
- `event.updated` → Invalidate event cache
- `payment.completed` → Invalidate related caches

---

## 8. Load Balancing

### 8.1 Application Load Balancer

**Configuration:**
- Internet-facing in public subnet
- HTTPS listener (ACM certificate)
- HTTP → HTTPS redirect

**Path-Based Routing:**

| Path | Target Service | Health Check |
|------|---------------|--------------|
| `/api/auth/*` | Auth Service | `/actuator/health` |
| `/api/events/*` | Event Service | `/actuator/health` |
| `/api/payments/*` | Payment Service | `/actuator/health` |
| `/api/notifications/*` | Notification Service | `/actuator/health` |

**Target Groups:**
- Deregistration delay: 30 seconds
- Health check interval: 30 seconds
- Healthy threshold: 2
- Unhealthy threshold: 3

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

### 9.2 Secrets Management

**AWS Secrets Manager:**
- `event-planner/dev/jwt-secret`
- `event-planner/dev/google-credentials`
- `event-planner/dev/paystack-credentials`
- `event-planner/dev/redis-credentials`
- `event-planner/dev/db-credentials`

### 9.3 Encryption

**At Rest:**
- RDS: KMS encryption
- ElastiCache: Encryption enabled
- S3: SSE-S3

**In Transit:**
- ALB to clients: TLS 1.2+
- ECS to RDS: SSL/TLS
- ECS to Redis: TLS enabled

---

## 10. Monitoring

### 10.1 CloudWatch Dashboards

**Service-Specific Dashboards:**
- Auth Service Dashboard
- Event Service Dashboard
- Payment Service Dashboard
- Notification Service Dashboard

**Metrics:**
- ECS: CPU, memory, task count
- ALB: Request count, latency, errors
- RDS: Connections, CPU, storage
- ElastiCache: CPU, memory, cache hit rate
- SQS: Queue depth, message age

### 10.2 CloudWatch Alarms

**Critical Alarms:**
- ECS CPU > 80% for 5 minutes
- ECS Memory > 85% for 5 minutes
- ALB 5xx errors > 10/min
- RDS connections > 80%
- SQS DLQ messages > 0

### 10.3 Log Groups

- `/ecs/event-planner/dev/auth-service`
- `/ecs/event-planner/dev/event-service`
- `/ecs/event-planner/dev/payment-service`
- `/ecs/event-planner/dev/notification-service`

**Retention:** 7 days

### 10.4 Grafana Monitoring

**Access:** `https://api.sankofagrid.com/monitoring/`

**Data Sources:**
- CloudWatch metrics
- PostgreSQL audit logs
- Application metrics

**Dashboards:**
- Executive Dashboard (business KPIs)
- Infrastructure Dashboard (system health)
- Performance Dashboard (API latency)
- Security Dashboard (auth failures, security events)

---

## 11. Cost Optimization

### 11.1 Monthly Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| ECS Fargate | 4 services × 1 task × 0.25 vCPU × 512 MB | ~$50-70 |
| RDS PostgreSQL | db.t3.micro, 20 GB, Single-AZ | ~$30-40 |
| ElastiCache | cache.t3.micro, Single node | ~$15-20 |
| ALB | 1 ALB + minimal traffic | ~$20-25 |
| NAT Gateway | 1 gateway + data transfer | ~$30-35 |
| SQS/SNS | ~1M requests/month | ~$1-2 |
| CloudWatch | Basic monitoring, 7-day logs | ~$10-15 |

**Total: ~$150-200/month**

### 11.2 Cost Savings Strategies

**VPC Endpoints:**
- S3 Gateway Endpoint (free)
- Interface endpoints for ECR, CloudWatch, Secrets Manager
- Reduces NAT Gateway data transfer costs

**Single-AZ Deployment:**
- No cross-AZ data transfer charges
- Single NAT Gateway
- No standby RDS instance

**Minimal Resources:**
- Smallest instance types
- 1 task per service
- No read replicas
- Basic monitoring only

**Stop When Not in Use:**
- Stop ECS services: Save ~50%
- Weekday-only (160 hrs/month): Save ~78%
- **Weekday-only cost: ~$75-95/month**

### 11.3 Architecture Simplifications

**Removed Components (Savings):**
- API Gateway → ALB path-based routing (Save ~$30/month)
- Discovery Service → AWS Cloud Map (Save ~$15/month)
- DocumentDB → PostgreSQL JSONB (Save ~$70/month)
- **Total Savings: ~$115/month**

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

---

## Appendix B: Disaster Recovery

**Strategy:** Backup and Restore  
**RTO:** 15 minutes  
**RPO:** 24 hours

**Backup Configuration:**
- RDS: Daily automated backups (3-day retention)
- ElastiCache: Daily snapshots (7-day retention)
- Manual snapshots before major deployments

**Recovery Process:**
1. Deploy infrastructure via Terraform
2. Restore RDS from latest snapshot (~10 min)
3. Restore ElastiCache from snapshot (~5 min)
4. Deploy ECS services (~3 min)
5. Verify health checks

---

**Document Version:** 3.0  
**Last Updated:** November 2025  
**Maintained By:** DevOps Team
