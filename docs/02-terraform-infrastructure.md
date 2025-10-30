# Event Planner Platform - DevOps Infrastructure Documentation
## Part 2: Terraform Infrastructure Deep Dive

**Author:** DevOps Team  
**Last Updated:** October 30, 2025  
**Version:** 1.0.0

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

## Key Infrastructure Modules

### 1. VPC Module (`terraform/modules/vpc/`)

**Purpose**: Creates the network foundation with public/private subnets, NAT gateways, and VPC endpoints.

**Key Features**:
- Single-AZ (dev) vs Multi-AZ (prod) deployment
- VPC endpoints for cost optimization (~$15/month savings)
- NAT Gateway for external connectivity (required for SMTP)
- Flow logs for network monitoring

**Cost Optimization**:
```hcl
# Development: Single NAT Gateway
single_nat_gateway = true  # Saves ~$32/month per additional NAT

# VPC Endpoints reduce NAT Gateway data transfer costs
enable_vpc_endpoints = true  # Saves ~$15/month on AWS service calls
```

### 2. ECS Module (`terraform/modules/ecs/`)

**Purpose**: Manages containerized microservices with Fargate and service discovery.

**Current Configuration**:
```hcl
services = {
  auth = {
    name          = "auth-service"
    port          = 8081
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
  # event, booking, payment services commented out for cost optimization
}
```

**Service Discovery**:
- AWS Cloud Map namespace: `eventplanner.local`
- Services communicate via: `auth-service.eventplanner.local:8081`
- Automatic service registration/deregistration

### 3. RDS Module (`terraform/modules/rds/`)

**Purpose**: PostgreSQL databases with multi-schema approach for cost optimization.

**Current Setup**:
```hcl
databases = {
  auth = {
    instance_class        = "db.t3.medium"  # Upgraded from t3.micro
    allocated_storage     = 20
    max_allocated_storage = 100
    port                  = 5432
  }
  # event, booking, payment databases commented out
}
```

**Cost Optimization Strategy**:
- **Development**: Single PostgreSQL instance with multiple schemas
- **Production**: Separate RDS instances per service for isolation
- **Savings**: ~$60/month in dev by using single instance

### 4. Security Groups Module (`terraform/modules/security-groups/`)

**Purpose**: Implements least-privilege network access controls.

**Security Groups Created**:
- **ALB Security Group**: HTTPS/HTTP from internet (ports 80, 443)
- **ECS Security Group**: Service ports from ALB only (8081-8085)
- **RDS Security Group**: PostgreSQL from ECS only (port 5432)
- **ElastiCache Security Group**: Redis from ECS only (port 6379)

### 5. Secrets Manager Module (`terraform/modules/secrets-manager/`)

**Purpose**: Secure storage and rotation of application secrets.

**Secrets Managed**:
- Database credentials (auto-generated, rotatable)
- JWT signing keys
- AWS credentials for services
- Google SMTP credentials for notifications
- Redis auth tokens (production)

---

## Environment-Specific Configurations

### Development Environment (`terraform/environments/dev/`)

**Characteristics**:
- **Single-AZ deployment** (eu-west-1a)
- **Minimal resource allocation** for cost optimization
- **2 active services** (auth, notification)
- **Single PostgreSQL** with multi-schema
- **No read replicas** or Multi-AZ

**Key Variables**:
```hcl
environment = "dev"
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a"]  # Single AZ
single_nat_gateway = true            # Cost optimization

# Database configuration
rds_instance_class = "db.t3.medium"
rds_multi_az = false
rds_read_replicas = 0

# ECS configuration  
ecs_task_cpu = "256"
ecs_task_memory = "512"
ecs_min_capacity = 1
ecs_max_capacity = 1
```

### Production Environment (`terraform/environments/prod/`)

**Characteristics**:
- **Multi-AZ deployment** (2 AZs)
- **High availability** configuration
- **All 5 services** active
- **Separate databases** per service
- **Read replicas** and Multi-AZ enabled

**Key Variables**:
```hcl
environment = "prod"
availability_zones = ["eu-west-1a", "eu-west-1b"]  # Multi-AZ
single_nat_gateway = false                          # HA

# Database configuration
rds_instance_class = "db.t4g.medium"
rds_multi_az = true
rds_read_replicas = 2

# ECS configuration
ecs_task_cpu = "512"
ecs_task_memory = "1024"
ecs_min_capacity = 2
ecs_max_capacity = 10
```

---

## Infrastructure Deployment Process

### 1. Bootstrap Setup (One-Time)

```bash
# Initialize S3 backend for state management
cd terraform/bootstrap
terraform init
terraform apply

# Outputs: S3 bucket and DynamoDB table for state locking
```

### 2. Environment Deployment

```bash
# Deploy development environment
cd terraform/environments/dev

# Initialize with S3 backend
terraform init \
  -backend-config="bucket=event-planner-terraform-state-dev" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=eu-west-1"

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Service Activation Process

To activate additional services (event, booking, payment):

1. **Uncomment service blocks** in `terraform/modules/ecs/main.tf`
2. **Uncomment database blocks** in `terraform/modules/rds/main.tf`
3. **Update CI/CD pipeline** in `.github/workflows/backend-ci-cd.yml`
4. **Apply Terraform changes**: `terraform apply`

---

## Cost Optimization Features

### 1. Conditional Resource Creation

```hcl
# Create read replicas only in production
resource "aws_db_instance" "read_replica_1" {
  for_each = var.create_read_replicas ? local.databases : {}
  # ... configuration
}

# Enhanced monitoring only when enabled
monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
```

### 2. Environment-Specific Sizing

```hcl
# CPU/Memory allocation based on environment
cpu    = var.environment == "dev" ? 256 : 512
memory = var.environment == "dev" ? 512 : 1024

# Instance classes scale with environment
instance_class = var.environment == "dev" ? "db.t3.micro" : "db.t4g.medium"
```

### 3. Feature Flags

```hcl
# Optional features controlled by variables
enable_waf = false                    # Disable WAF in dev
enable_enhanced_monitoring = false    # Disable detailed monitoring
enable_performance_insights = false   # Disable PI in dev
```

---

## Security Implementation

### 1. Network Security

- **Private subnets** for all application and data tiers
- **Security groups** with least-privilege access
- **VPC endpoints** to avoid internet traffic for AWS services
- **NAT Gateway** only for required external access (SMTP)

### 2. Data Encryption

```hcl
# RDS encryption at rest
storage_encrypted = true
kms_key_id = var.kms_key_arn

# ElastiCache encryption
at_rest_encryption_enabled = true
transit_encryption_enabled = true

# S3 encryption
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### 3. Access Control

- **IAM roles** with minimal required permissions
- **Secrets Manager** for credential storage and rotation
- **SSL/TLS** enforcement for all database connections
- **HTTPS-only** for all web traffic

---

## Monitoring and Observability

### 1. CloudWatch Integration

```hcl
# Comprehensive logging
enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

# Container Insights for ECS
setting {
  name  = "containerInsights"
  value = "enabled"
}

# Custom metrics and alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name = "${var.project_name}-${var.environment}-cpu-high"
  # ... alarm configuration
}
```

### 2. Custom Dashboards

- **Service-specific dashboards** for each microservice
- **Infrastructure dashboards** for AWS resources
- **Cost monitoring** dashboards with budget alerts

---

## Disaster Recovery Features

### 1. Automated Backups

```hcl
# RDS automated backups
backup_retention_period = 7
backup_window = "03:00-04:00"
copy_tags_to_snapshot = true

# ElastiCache snapshots
snapshot_retention_limit = 3
snapshot_window = "03:00-04:00"
```

### 2. Cross-Region Capabilities

- **S3 cross-region replication** (configurable)
- **ECR replication** to secondary region
- **Snapshot copying** for disaster recovery

---

## Next Steps

This covers the Terraform infrastructure implementation. Continue with:

- **Part 3**: CI/CD Pipeline Implementation
- **Part 4**: Deployment Workflows and Automation
- **Part 5**: Monitoring, Security, and Operations