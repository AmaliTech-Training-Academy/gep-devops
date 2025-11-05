# Event Planner Platform - DevOps Infrastructure Documentation
## Part 2: Terraform Infrastructure Deep Dive

**Author:** DevOps Team  
**Last Updated:** January 2025  
**Version:** 2.0.0

---

## Terraform Infrastructure Overview

The infrastructure is built using **15 modular Terraform modules** that create a complete, production-ready AWS environment. The modular approach ensures reusability, maintainability, and consistent deployments across environments.

### Module Architecture

```
terraform/
├── bootstrap/                     # S3 backend setup (one-time)
├── environments/
│   ├── dev/                      # Development environment
│   └── prod/                     # Production environment  
└── modules/                      # Reusable infrastructure modules
    ├── vpc/                      # Network foundation
    ├── security-groups/          # Security rules
    ├── iam/                      # Access management
    ├── rds/                      # PostgreSQL databases
    ├── elasticache/              # Redis caching
    ├── ecs/                      # Container orchestration
    ├── alb/                      # Load balancing
    ├── s3/                       # Object storage
    ├── cloudfront/               # CDN
    ├── route53/                  # DNS management
    ├── acm/                      # SSL certificates
    ├── secrets-manager/          # Secrets storage
    ├── sqs-sns/                  # Messaging
    ├── ecr/                      # Container registry
    ├── cloudwatch/               # Monitoring
    ├── cloudwatch-dashboards/    # Custom dashboards
    └── waf/                      # Web application firewall
```

---

## Current Infrastructure State

### Active Services (Development Environment)

**Running Services:**
- **Auth Service**: Port 8081, 256 CPU, 512MB memory
- **Event Service**: Port 8082, 256 CPU, 512MB memory
- **Notification Service**: Port 8085, 256 CPU, 512MB memory

**Database Configuration:**
- **Single PostgreSQL Instance**: db.t3.medium (upgraded from t3.micro)
- **Multi-Schema Approach**: auth_db, event_schema for cost optimization
- **ElastiCache Redis**: Single node (cache.t3.micro)

**Network Configuration:**
- **Dual-AZ Deployment**: eu-west-1a, eu-west-1b (required by AWS for RDS/ALB)
- **Single NAT Gateway**: Cost-optimized for development
- **VPC Endpoints**: Disabled (S3 Gateway Endpoint only - free)
- **NAT Gateway Strategy**: All AWS service traffic routes through NAT Gateway

---

## Key Infrastructure Modules

### 1. VPC Module (`terraform/modules/vpc/`)

**Purpose**: Creates the network foundation with public/private subnets, NAT gateways, and routing.

**Current Configuration:**
```hcl
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]  # Dual-AZ for AWS requirements
enable_nat_gateway = true                          # Required for SMTP and AWS services
single_nat_gateway = true                          # Cost optimization
enable_vpc_endpoints = false                       # Disabled for cost savings
```

**Network Architecture:**
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (ALB, NAT Gateway)
- **Private App Subnets**: 10.0.10.0/24, 10.0.11.0/24 (ECS containers)
- **Private Data Subnets**: 10.0.20.0/24, 10.0.21.0/24 (RDS, ElastiCache)

**VPC Endpoint Strategy:**
- **S3 Gateway Endpoint**: Active (free, no hourly charges)
- **Interface Endpoints**: Disabled for cost optimization
  - Previously: 7 endpoints (~$154/month)
  - Current: NAT Gateway handles all traffic (~$42-62/month)
  - **Net Savings**: $92-112/month

**NAT Gateway Configuration:**
- Single NAT Gateway in eu-west-1a
- Handles all outbound traffic:
  - SMTP (Gmail port 465, 587)
  - AWS services (ECR, Secrets Manager, CloudWatch, SQS, SNS)
  - External API calls
- Cost: ~$32/month (hourly) + ~$10-30/month (data transfer)

### 2. ECS Module (`terraform/modules/ecs/`)

**Purpose**: Manages containerized microservices with Fargate and AWS Cloud Map service discovery.

**Active Services Configuration:**
```hcl
services = {
  auth = {
    name          = "auth-service"
    port          = 8081
    cpu           = 256
    memory        = 512
    desired_count = 1
  }
  event = {
    name          = "event-service"
    port          = 8082
    cpu           = 256
    memory        = 512
    desired_count = 1
  }
  notification = {
    name          = "notification-service"
    port          = 8085
    cpu           = 256
    memory        = 512
    desired_count = 1
  }
}
```

**Service Discovery (AWS Cloud Map):**
- **Namespace**: eventplanner.local
- **Service Endpoints**:
  - auth-service.eventplanner.local:8081
  - event-service.eventplanner.local:8082
  - notification-service.eventplanner.local:8085

**Container Configuration:**
- **Launch Type**: Fargate (serverless)
- **Platform Version**: LATEST
- **Network Mode**: awsvpc
- **Deployment**: Single-AZ (eu-west-1a) for cost optimization
- **Health Checks**: Spring Boot Actuator (/actuator/health)
- **Startup Grace Period**: 90 seconds

**Auto-Scaling:**
- **CPU Target**: 70%
- **Memory Target**: 75%
- **Scale-in Cooldown**: 300 seconds
- **Scale-out Cooldown**: 60 seconds

### 3. RDS Module (`terraform/modules/rds/`)

**Purpose**: PostgreSQL databases with multi-schema approach for cost optimization.

**Current Configuration:**
```hcl
databases = {
  auth = {
    instance_class        = "db.t3.medium"  # Upgraded from t3.micro
    allocated_storage     = 20
    max_allocated_storage = 100
    port                  = 5432
  }
}
```

**Database Strategy:**
- **Development**: Single PostgreSQL instance with multiple schemas
  - auth_db: User authentication and management
  - event_schema: Event management (used by event service)
- **Production**: Separate RDS instances per service (ready to deploy)

**Features:**
- **Storage**: gp3 (3000 IOPS default)
- **Encryption**: At rest (KMS) and in transit (SSL/TLS)
- **Backups**: 3-day retention (dev), automated daily backups
- **Monitoring**: CloudWatch Logs (postgresql, upgrade)
- **IAM Authentication**: Enabled for enhanced security
- **Multi-AZ**: Disabled (dev), enabled (prod)

**Cost Optimization:**
- Single instance vs multiple databases: ~$60-80/month savings
- No read replicas in development
- Short backup retention (3 days)

### 4. ElastiCache Module (`terraform/modules/elasticache/`)

**Purpose**: Redis cluster for caching and session management.

**Current Configuration:**
```hcl
redis_version           = "7.1"
node_type               = "cache.t3.micro"
cluster_mode_enabled    = false
num_cache_nodes         = 1
automatic_failover      = false
multi_az_enabled        = false
```

**Features:**
- **Encryption**: At rest and in transit
- **Backups**: 3-day snapshot retention
- **Monitoring**: CloudWatch alarms (CPU, memory, evictions)
- **Parameter Group**: Custom (maxmemory-policy: allkeys-lru)

### 5. ALB Module (`terraform/modules/alb/`)

**Purpose**: Application Load Balancer for intelligent traffic routing.

**Active Services Routing:**
```hcl
services = {
  auth = {
    path_pattern = "/api/v1/auth/*"
    port         = 8081
    priority     = 100
  }
  event = {
    path_pattern = "/api/v1/events*"
    port         = 8082
    priority     = 200
  }
  notification = {
    path_pattern = "/api/v1/notifications/*"
    port         = 8085
    priority     = 500
  }
}
```

**Additional Routes:**
- Swagger UI: /swagger-ui/*, /swagger-ui.html, /v3/api-docs*
- Users API: /api/v1/users* (auth service)
- Event Invitations: /api/v1/event-invitations*
- Event Types: /api/v1/event_types*, /api/v1/event_meeting_types*
- Tickets: /api/v1/tickets*
- Timezones: /api/v1/timezones*

**Configuration:**
- **SSL/TLS**: ACM certificate (api.sankofagrid.com)
- **SSL Policy**: ELBSecurityPolicy-TLS-1-2-2017-01
- **HTTP to HTTPS**: Automatic redirect (301)
- **Health Checks**: 30s interval, 5s timeout, 2/3 threshold
- **Access Logs**: Enabled (S3 bucket)

### 6. Security Groups Module (`terraform/modules/security-groups/`)

**Purpose**: Implements least-privilege network access controls.

**Security Groups:**

**ALB Security Group:**
- Inbound: HTTPS (443), HTTP (80) from 0.0.0.0/0
- Outbound: All traffic to ECS security group

**ECS Security Group:**
- Inbound: Ports 8081, 8082, 8085 from ALB
- Inbound: All traffic from self (inter-service communication)
- Outbound: PostgreSQL (5432) to RDS
- Outbound: Redis (6379) to ElastiCache
- Outbound: HTTPS (443) to 0.0.0.0/0 (AWS APIs)
- Outbound: SMTP SSL (465) to 0.0.0.0/0 (Gmail)
- Outbound: SMTP STARTTLS (587) to 0.0.0.0/0 (Gmail)

**RDS Security Group:**
- Inbound: PostgreSQL (5432) from ECS only
- Outbound: None (databases don't initiate connections)

**ElastiCache Security Group:**
- Inbound: Redis (6379) from ECS only
- Outbound: None

### 7. SQS-SNS Module (`terraform/modules/sqs-sns/`)

**Purpose**: Event-driven messaging for microservices communication.

**SNS Topics:**
- event-topic: Event publishing
- booking-topic: Booking events
- payment-topic: Payment events

**Active SQS Queues:**
- user_registration: Auth service
- user_login: Auth service
- password_reset: Auth service
- event_created: Event service
- event_updated: Event service
- event_created_notification: Notification service
- notifications: Notification service
- event_invitation: Event service
- ticket_purchased_event: Event service
- payment_processing_event: Event service
- payment_completed_event: Event service

**Features:**
- **Dead Letter Queues**: 3 retries before DLQ
- **Message Retention**: 3 days (259200 seconds)
- **Long Polling**: 20 seconds
- **Encryption**: KMS encryption at rest
- **Monitoring**: CloudWatch alarms for DLQ and message age

### 8. Secrets Manager Module (`terraform/modules/secrets-manager/`)

**Purpose**: Secure storage and management of application secrets.

**Secrets Managed:**
- **JWT Secret**: JWT_SECRET for auth and event services
- **Database Credentials**: Auto-generated per database
- **AWS Credentials**: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
- **Google Credentials**: GOOGLE_USER, GOOGLE_PASSWORD (SMTP)

**Features:**
- **Recovery Window**: 7 days
- **Encryption**: KMS encryption
- **Rotation**: Supported (not enabled in dev)
- **Access**: ECS task roles via IAM policies

### 9. CloudFront Module (`terraform/modules/cloudfront/`)

**Purpose**: Global CDN for Angular frontend application.

**Configuration:**
- **Domain**: events.sankofagrid.com
- **Certificate**: Manual ACM certificate (us-east-1)
- **Origin**: S3 bucket (event-planner-dev-assets)
- **Origin Access**: Origin Access Control (OAC)
- **Price Class**: PriceClass_100 (US, Canada, Europe)
- **Caching**: 5 minutes default (dev), 1 hour max
- **Compression**: Enabled (gzip)

**Custom Error Responses:**
- 403 → 200 (index.html) - SPA routing
- 404 → 200 (index.html) - SPA routing

### 10. S3 Module (`terraform/modules/s3/`)

**Purpose**: Object storage for frontend assets and logs.

**Buckets:**
- **Assets Bucket**: event-planner-dev-assets (Angular app)
- **Logs Bucket**: event-planner-dev-logs (ALB, CloudFront logs)

**Features:**
- **Versioning**: Disabled (dev)
- **Encryption**: AES256
- **CORS**: Enabled for events.sankofagrid.com
- **Lifecycle Rules**: Enabled (90 days → IA, 180 days → Glacier)
- **Access**: CloudFront OAC policy

---

## Environment-Specific Configurations

### Development Environment

**Network:**
- Dual-AZ: eu-west-1a, eu-west-1b (AWS requirement)
- Single NAT Gateway (cost optimization)
- VPC Endpoints: Disabled (except S3 Gateway)

**Compute:**
- 3 ECS services (auth, event, notification)
- 256 CPU, 512MB memory per service
- Single task per service
- No auto-scaling (min=max=1)

**Database:**
- Single PostgreSQL (db.t3.medium)
- Multi-schema approach
- No read replicas
- 3-day backup retention

**Caching:**
- Single Redis node (cache.t3.micro)
- No replicas
- No Multi-AZ

**Cost Estimate:**
- 24/7 operation: ~$126-157/month
- Weekday-only: ~$75-95/month

### Production Environment (Ready to Deploy)

**Network:**
- Multi-AZ: eu-west-1a, eu-west-1b
- NAT Gateway per AZ (high availability)
- VPC Endpoints: Optional (cost vs latency trade-off)

**Compute:**
- 5 ECS services (all microservices)
- 512 CPU, 1024MB memory per service
- 2-4 tasks per service
- Auto-scaling enabled

**Database:**
- Separate RDS per service
- db.t4g.medium instances
- Multi-AZ enabled
- 2 read replicas per database
- 7-day backup retention

**Caching:**
- Redis cluster mode
- 3 node groups
- 2 replicas per shard
- Multi-AZ enabled

**Cost Estimate:**
- ~$2,500-3,000/month

---

## Infrastructure Deployment Process

### 1. Bootstrap Setup (One-Time)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### 2. Environment Deployment

```bash
cd terraform/environments/dev
terraform init \
  -backend-config="bucket=event-planner-terraform-state-dev" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=eu-west-1"

terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Service Activation

To activate additional services:
1. Uncomment service blocks in `terraform/modules/ecs/main.tf`
2. Uncomment database blocks in `terraform/modules/rds/main.tf`
3. Update ALB routing in `terraform/modules/alb/main.tf`
4. Run `terraform apply`

---

## Cost Optimization Features

### 1. NAT Gateway Strategy

**Current Approach:**
- Single NAT Gateway handles all traffic
- Cost: ~$42-62/month
- Savings vs VPC Endpoints: $92-112/month

**Trade-offs:**
- Slight latency increase (internet routing vs AWS backbone)
- Single point of failure (acceptable for dev)
- Maintained security (encrypted traffic, private subnets)

### 2. Multi-Schema Database

**Strategy:**
- Single PostgreSQL instance with multiple schemas
- auth_db, event_schema in same instance
- Savings: ~$60-80/month vs separate databases

### 3. Selective Service Deployment

**Active Services:**
- Only 3 services running (auth, event, notification)
- Booking and payment services ready but commented out
- Savings: ~$20-30/month per unused service

### 4. Minimal Resource Allocation

**Development:**
- 256 CPU, 512MB memory per service
- Single task per service
- No auto-scaling
- Short log retention (3 days)

---

## Security Implementation

### 1. Network Security

- Private subnets for all application and data tiers
- Security groups with least-privilege access
- No direct internet access for applications
- NAT Gateway for controlled outbound access

### 2. Data Encryption

**At Rest:**
- RDS: KMS encryption
- ElastiCache: Encryption enabled
- S3: AES256 encryption
- Secrets Manager: KMS encryption

**In Transit:**
- RDS: SSL/TLS enforced
- ElastiCache: TLS enabled
- ALB: HTTPS only (HTTP redirects)
- CloudFront: HTTPS only

### 3. Access Control

- IAM roles with minimal permissions
- Secrets Manager for credential storage
- No hardcoded credentials
- ECS task roles per service

---

## Monitoring and Observability

### 1. CloudWatch Integration

**Logs:**
- ECS container logs: 3-day retention
- RDS logs: postgresql, upgrade
- VPC Flow Logs: All traffic (3-day retention)
- ALB access logs: S3 bucket

**Metrics:**
- ECS: CPU, memory, task count
- RDS: CPU, storage, connections
- ElastiCache: CPU, memory, evictions
- ALB: Response time, 5XX errors, unhealthy targets

**Alarms:**
- ECS: High CPU/memory
- RDS: High CPU, low storage, high connections
- ElastiCache: High CPU/memory, evictions
- ALB: High response time, 5XX errors
- SQS: DLQ messages, message age

### 2. Custom Dashboards

- Service-specific dashboards (auth, event)
- Infrastructure overview dashboard
- Cost monitoring dashboard

---

## Disaster Recovery

### 1. Automated Backups

**RDS:**
- Daily automated backups
- 3-day retention (dev), 7-day (prod)
- Backup window: 03:00-04:00 UTC
- Point-in-time recovery enabled

**ElastiCache:**
- Daily snapshots
- 3-day retention
- Snapshot window: 03:00-04:00 UTC

**S3:**
- Versioning: Disabled (dev), enabled (prod)
- Lifecycle policies: 90 days → IA, 180 days → Glacier

### 2. High Availability (Production)

- Multi-AZ deployment
- Read replicas for databases
- Auto-scaling for ECS services
- Multiple NAT Gateways

---

## Next Steps

Continue with:
- **Part 3**: CI/CD Pipeline Implementation
- **Part 4**: Deployment Workflows and Automation
- **Part 5**: Monitoring, Security, and Operations
- **Part 6**: Cost Optimization and Best Practices
