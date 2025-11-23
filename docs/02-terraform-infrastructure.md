# Terraform Infrastructure

**Last Updated:** November 2025  
**Version:** 2.0.0

## Overview

The infrastructure is built using modular Terraform modules that create a complete, production-ready AWS environment. This modular approach ensures reusability, maintainability, and consistent deployments across environments.

## Module Architecture

```
terraform/
├── modules/
│   ├── vpc/                      # Network foundation
│   ├── security-groups/          # Security rules
│   ├── iam/                      # Access management
│   ├── rds/                      # PostgreSQL databases
│   ├── elasticache/              # Redis caching
│   ├── ecs/                      # Container orchestration
│   ├── alb/                      # Load balancing
│   ├── s3/                       # Object storage
│   ├── cloudfront/               # CDN
│   ├── acm/                      # SSL certificates
│   ├── secrets-manager/          # Secrets storage
│   ├── sqs-sns/                  # Messaging
│   ├── ecr/                      # Container registry
│   ├── cloudwatch/               # Monitoring
│   └── cloudwatch-dashboards/    # Custom dashboards
└── environments/
    ├── dev/                      # Development
    └── prod/                     # Production
```

## Core Infrastructure Modules

### VPC Module

Creates network foundation with public/private subnets, NAT gateway, and routing.

**Configuration:**
- VPC CIDR: 10.0.0.0/16
- Availability Zones: eu-west-1a, eu-west-1b
- Public Subnets: 10.0.1.0/24, 10.0.2.0/24
- Private App Subnets: 10.0.10.0/24, 10.0.11.0/24
- Private Data Subnets: 10.0.20.0/24, 10.0.21.0/24
- Single NAT Gateway (dev), Multiple (prod)
- VPC Endpoints for AWS services

### ECS Module

Manages containerized microservices with Fargate and AWS Cloud Map.

**Active Services:**
- auth-service: Port 8081, 256 CPU, 512MB memory
- event-service: Port 8082, 256 CPU, 512MB memory
- payment-service: Port 8088, 256 CPU, 512MB memory
- notification-service: Port 8085, 256 CPU, 512MB memory

**Service Discovery:**
- Namespace: eventplanner.local
- DNS-based service resolution
- Automatic registration/deregistration

**Features:**
- Fargate serverless containers
- Auto-scaling based on CPU/memory
- Health checks via Spring Boot Actuator
- CloudWatch logging

### RDS Module

PostgreSQL databases with multi-schema approach for cost optimization.

**Configuration:**
- Instance Class: db.t3.medium (dev), db.t4g.medium (prod)
- Storage: gp3 with auto-scaling
- Schemas: auth_schema, event_schema, payment_schema
- Encryption: At rest (KMS) and in transit (SSL/TLS)
- Backups: 3-day retention (dev), 7-day (prod)
- Multi-AZ: Disabled (dev), Enabled (prod)

### ElastiCache Module

Redis cluster for caching and session management.

**Configuration:**
- Version: Redis 7.1
- Node Type: cache.t3.micro (dev), cache.t4g.medium (prod)
- Single node (dev), Cluster mode (prod)
- Encryption at rest and in transit
- Automated backups with 3-day retention

### ALB Module

Application Load Balancer for intelligent traffic routing.

**Configuration:**
- HTTPS listener with ACM certificate
- Path-based routing to services
- Health checks: 30s interval, 5s timeout
- Access logs to S3
- SSL Policy: TLS 1.2+

**Routing Rules:**
- /api/v1/auth/* → auth-service:8081
- /api/v1/events* → event-service:8082
- /api/v1/payments/* → payment-service:8088
- /api/v1/notifications/* → notification-service:8085

### Security Groups Module

Implements least-privilege network access controls.

**ALB Security Group:**
- Inbound: HTTPS (443), HTTP (80) from internet
- Outbound: Service ports to ECS

**ECS Security Group:**
- Inbound: Service ports from ALB
- Outbound: PostgreSQL (5432), Redis (6379), HTTPS (443), SMTP (465, 587)

**RDS Security Group:**
- Inbound: PostgreSQL (5432) from ECS only

**ElastiCache Security Group:**
- Inbound: Redis (6379) from ECS only

### SQS/SNS Module

Event-driven messaging for microservices communication.

**SNS Topics:**
- event-topic: Event publishing
- payment-topic: Payment events

**SQS Queues:**
- User registration/login queues
- Event creation/invitation queues
- Payment processing/status queues
- Notification queues
- Withdrawal notification queue
- Webhook event queue

**Features:**
- Dead Letter Queues with 3 retries
- Message retention: 3 days
- Long polling: 20 seconds
- KMS encryption
- CloudWatch alarms

### Secrets Manager Module

Secure storage and management of application secrets.

**Secrets Managed:**
- JWT signing keys
- Database credentials
- Google SMTP credentials
- Paystack API keys
- Redis auth tokens

**Features:**
- 7-day recovery window
- KMS encryption
- IAM-based access control
- ECS task role integration

### CloudFront Module

Global CDN for Angular frontend application.

**Configuration:**
- Domain: events.sankofagrid.com
- Origin: S3 bucket
- Origin Access Control (OAC)
- Price Class: US, Canada, Europe
- Caching: 5 minutes default, 1 hour max
- Compression: Enabled
- Custom error responses for SPA routing

### S3 Module

Object storage for frontend assets and logs.

**Buckets:**
- Assets bucket: Angular application
- Logs bucket: ALB and CloudFront logs

**Features:**
- AES256 encryption
- CORS enabled
- Lifecycle policies
- CloudFront OAC access

### IAM Module

Access management with least-privilege principles.

**Roles Created:**
- ECS task execution role
- Service-specific task roles
- SNS/SQS permissions
- Secrets Manager access

### CloudWatch Module

Monitoring and logging infrastructure.

**Features:**
- Log groups with 3-day retention
- Custom metrics and alarms
- Service-specific dashboards
- Infrastructure dashboards

## Environment Configurations

### Development Environment

**Network:**
- Single-AZ deployment (cost optimized)
- Single NAT Gateway
- VPC endpoints for AWS services

**Compute:**
- 4 ECS services
- 256 CPU, 512MB memory per service
- Single task per service

**Database:**
- Single PostgreSQL with multi-schema
- No read replicas
- 3-day backup retention

**Cost:** ~$150-200/month

### Production Environment

**Network:**
- Multi-AZ deployment
- Multiple NAT Gateways
- VPC endpoints enabled

**Compute:**
- 4 ECS services
- 512 CPU, 1024MB memory per service
- 2-4 tasks per service
- Auto-scaling enabled

**Database:**
- Multi-AZ enabled
- Read replicas
- 7-day backup retention

**Cost:** ~$800-1200/month

## Deployment Process

### Initial Setup

```bash
# Navigate to environment
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

### Update Infrastructure

```bash
# Make changes to Terraform files
# Review changes
terraform plan

# Apply changes
terraform apply
```

## Security Implementation

### Network Security
- Private subnets for applications and data
- Security groups with least-privilege
- NAT Gateway for controlled outbound access

### Data Encryption
- RDS: KMS encryption at rest, SSL/TLS in transit
- ElastiCache: Encryption enabled
- S3: AES256 encryption
- Secrets Manager: KMS encryption

### Access Control
- IAM roles with minimal permissions
- No hardcoded credentials
- ECS task roles per service

## Monitoring

### CloudWatch Logs
- ECS container logs
- RDS logs
- VPC Flow Logs
- ALB access logs

### CloudWatch Metrics
- ECS: CPU, memory, task count
- RDS: CPU, storage, connections
- ElastiCache: CPU, memory, evictions
- ALB: Response time, errors

### Alarms
- High CPU/memory usage
- Database connection issues
- Cache evictions
- Application errors
- Dead letter queue messages

## Disaster Recovery

### Automated Backups
- RDS: Daily backups, 3-day retention (dev)
- ElastiCache: Daily snapshots
- S3: Lifecycle policies

### High Availability (Production)
- Multi-AZ deployment
- Read replicas
- Auto-scaling
- Multiple NAT Gateways

## Cost Optimization

### Development
- Single-AZ deployment
- Minimal instance sizes
- No read replicas
- Single NAT Gateway
- Short backup retention

### Strategies
- Multi-schema database approach
- VPC endpoints for AWS services
- Selective service deployment
- Auto-scaling based on demand
