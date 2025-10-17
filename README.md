# Event Planner - Infrastructure as Code

## Infrastructure Foundation & Database Layer

This repository contains the Terraform infrastructure code for the Event Planner Platform, focusing on core infrastructure, networking, security, and data layer components.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Module Documentation](#module-documentation)
6. [Environment Configuration](#environment-configuration)
7. [Secrets Management](#secrets-management)
8. [Deployment Workflow](#deployment-workflow)
9. [Cost Optimization](#cost-optimization)
10. [Disaster Recovery](#disaster-recovery)
11. [Troubleshooting](#troubleshooting)

## Architecture Overview

### Infrastructure Components

**Frontend Infrastructure:**
- S3 bucket for Angular application hosting
- CloudFront distribution for global content delivery
- Route53 DNS configuration (sankofagrid.com)
- ACM SSL/TLS certificates
- WAF for web application firewall (optional)

**Backend Infrastructure:**
- VPC with public and private subnets across multiple AZs
- ECS Fargate cluster for microservices
- Application Load Balancer (ALB) with HTTPS
- AWS Cloud Map for service discovery
- RDS PostgreSQL (4 databases with read replicas in prod)
- DocumentDB for audit logs
- ElastiCache Redis for caching
- Secrets Manager for credential management

**Network Architecture:**
- Production: Multi-AZ deployment (2 AZs)
- Development: Single-AZ deployment (cost-optimized)
- Private subnets for application and data tiers
- Public subnets for ALB and NAT Gateways
- VPC endpoints for AWS services (S3, ECR, Secrets Manager, etc.)

### Environments

**Development Environment:**
- Single AZ deployment
- Minimal resource allocation (cost-optimized)
- Single database instances (no read replicas)
- 1 ECS task per microservice
- Estimated cost: ~$248/month (24/7) or ~$75-95/month (weekday-only)

**Production Environment:**
- Multi-AZ deployment (2 AZs)
- High availability configuration
- RDS with Multi-AZ and read replicas
- Auto-scaling enabled
- Multiple ECS tasks per microservice
- Estimated cost: ~$2,500-3,000/month

## Repository Structure

```
gep_devops/
├── terraform/
│   ├── bootstrap/                     # S3 backend setup (run once)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── modules/
│   │   ├── vpc/                       # VPC, subnets, route tables, NAT gateways
│   │   ├── security-groups/           # Security group definitions
│   │   ├── iam/                       # IAM roles and policies
│   │   ├── rds/                       # RDS PostgreSQL databases
│   │   ├── documentdb/                # DocumentDB cluster
│   │   ├── elasticache/               # ElastiCache Redis
│   │   ├── ecs/                       # ECS cluster and capacity providers
│   │   ├── alb/                       # Application Load Balancer
│   │   ├── s3/                        # S3 buckets (frontend hosting, logs)
│   │   ├── cloudfront/                # CloudFront distribution
│   │   ├── route53/                   # DNS records
│   │   ├── acm/                       # SSL/TLS certificates
│   │   ├── secrets-manager/           # Secrets management
│   │   └── cloudmap/                  # Service discovery
│   └── environments/
│       ├── dev/                       # Development environment
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── terraform.tfvars
│       │   ├── backend.tf
│       │   └── outputs.tf
│       └── prod/                      # Production environment
│           ├── main.tf
│           ├── variables.tf
│           ├── terraform.tfvars
│           ├── backend.tf
│           └── outputs.tf
├── scripts/
│   └── terraform/
│       ├── init-backend.sh            # Initialize S3 backend
│       ├── deploy-env.sh              # Deploy environment
│       ├── plan-env.sh                # Plan infrastructure changes
│       ├── destroy-env.sh             # Destroy environment
│       └── validate-all.sh            # Validate all Terraform code
└── README.md                          # This file
```

## Prerequisites

### Required Tools

1. **Terraform** (>= 1.5.0)
   ```bash
   # Install via Homebrew (macOS)
   brew install terraform
   
   # Or download from https://www.terraform.io/downloads
   ```

2. **AWS CLI** (>= 2.0)
   ```bash
   # Install via Homebrew (macOS)
   brew install awscli
   
   # Configure AWS credentials
   aws configure
   ```

3. **jq** (for JSON processing in scripts)
   ```bash
   brew install jq
   ```

### AWS Account Requirements

- AWS account with appropriate permissions
- IAM user or role with the following permissions:
  - VPC management
  - EC2 (including ECS, ALB)
  - RDS
  - DocumentDB
  - ElastiCache
  - S3
  - CloudFront
  - Route53
  - ACM
  - Secrets Manager
  - IAM (for role creation)
  - CloudWatch
  - Systems Manager

### Domain Requirements

- Domain name registered (sankofagrid.com)
- Access to domain DNS management
- Ability to create DNS records or delegate nameservers to Route53

## Quick Start

### Step 1: Initialize Terraform Backend

The Terraform state is stored in S3 with DynamoDB locking for team collaboration.

```bash
# Navigate to bootstrap directory
cd terraform/bootstrap

# Initialize and apply bootstrap configuration
terraform init
terraform plan
terraform apply

# Note the S3 bucket and DynamoDB table names from outputs
```

### Step 2: Configure Environment Variables

Create a `.env` file (not committed to git) with sensitive values:

```bash
# Create .env file
cat > terraform/environments/dev/.env << 'EOF'
export TF_VAR_db_master_password="YourSecurePassword123!"
export TF_VAR_docdb_master_password="YourSecureDocDBPassword123!"
export AWS_PROFILE="your-aws-profile"
export AWS_REGION="us-east-1"
EOF

# Load environment variables
source terraform/environments/dev/.env
```

### Step 3: Deploy Development Environment

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Initialize Terraform with S3 backend
terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_DYNAMODB_TABLE"

# Review planned changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

### Step 4: Verify Deployment

```bash
# Check outputs
terraform output

# Verify resources in AWS Console
# - VPC and subnets created
# - RDS databases running
# - ECS cluster created
# - S3 bucket for frontend
# - CloudFront distribution created
```

## Module Documentation

### VPC Module

Creates VPC infrastructure with public and private subnets, NAT gateways, Internet Gateway, and VPC endpoints.

**Inputs:**
- `environment`: Environment name (dev/prod)
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `availability_zones`: List of AZs to use
- `enable_nat_gateway`: Enable NAT Gateway (true/false)
- `single_nat_gateway`: Use single NAT Gateway for cost optimization

**Outputs:**
- `vpc_id`: VPC ID
- `public_subnet_ids`: Public subnet IDs
- `private_app_subnet_ids`: Private application subnet IDs
- `private_data_subnet_ids`: Private data subnet IDs
- `nat_gateway_ids`: NAT Gateway IDs

### Security Groups Module

Manages security groups for all infrastructure components with least privilege access.

**Security Groups Created:**
- ALB Security Group (HTTPS/HTTP from internet)
- ECS Security Group (ports 8081-8085 from ALB)
- RDS Security Group (port 5432 from ECS)
- DocumentDB Security Group (port 27017 from ECS)
- ElastiCache Security Group (port 6379 from ECS)

### IAM Module

Creates IAM roles and policies for ECS tasks, following least privilege principles.

**Roles Created:**
- ECS Task Execution Role (pull images, write logs, read secrets)
- ECS Task Roles per microservice (service-specific permissions)

### RDS Module

Deploys PostgreSQL databases with automatic backups, encryption, and optional Multi-AZ/read replicas.

**Features:**
- Multi-AZ deployment (production)
- Read replicas (production)
- Automated backups with 7-day retention
- KMS encryption at rest
- SSL/TLS encryption in transit
- Enhanced monitoring (production)
- Performance Insights (production)

**Databases Created:**
- Auth Database (user authentication)
- Event Database (event management)
- Booking Database (booking management)
- Payment Database (payment transactions)

### DocumentDB Module

Deploys MongoDB-compatible DocumentDB cluster for audit logs.

**Features:**
- Multi-instance cluster (production)
- Automated backups
- KMS encryption
- TLS connections enforced

### ElastiCache Module

Deploys Redis cluster for caching and session management.

**Features:**
- Cluster mode enabled (production)
- Multi-AZ with automatic failover
- Encryption at rest and in transit
- Automated backups

### ECS Module

Creates ECS cluster with Fargate capacity providers.

**Features:**
- Fargate capacity provider (serverless)
- Fargate Spot support (production, cost optimization)
- Auto-scaling configuration
- Container Insights enabled

### S3 Module

Creates S3 buckets for frontend hosting and logs.

**Buckets:**
- Frontend hosting bucket (Angular application)
- CloudFront logs bucket
- ALB logs bucket

**Features:**
- Versioning enabled
- Server-side encryption
- Bucket policies for CloudFront OAI access
- CORS configuration for frontend

### CloudFront Module

Deploys CloudFront distribution for global content delivery.

**Features:**
- Custom SSL certificate (ACM)
- HTTPS only (redirect HTTP to HTTPS)
- Gzip compression enabled
- Custom error pages
- WAF integration (optional)
- Cache behaviors optimized for Angular SPA

### Route53 Module

Manages DNS records for domain routing.

**Records Created:**
- A record for www.sankofagrid.com (frontend) → CloudFront
- A record for api.sankofagrid.com (backend) → ALB
- Health checks for failover (production)

### ACM Module

Manages SSL/TLS certificates for HTTPS.

**Certificates:**
- *.sankofagrid.com (wildcard certificate)
- Automatic DNS validation via Route53

### Secrets Manager Module

Manages application secrets securely.

**Secrets Stored:**
- Database credentials (with auto-rotation)
- JWT signing keys
- Third-party API keys
- Redis passwords

### CloudMap Module

Configures AWS Cloud Map for service discovery.

**Features:**
- Private DNS namespace (eventplanner.local)
- Automatic service registration/deregistration
- Health checks integrated with ECS

## Environment Configuration

### Development Environment (terraform/environments/dev/terraform.tfvars)

```hcl
# Environment configuration
environment = "dev"
project_name = "event-planner"

# Network configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a"]
single_nat_gateway = true

# Database configuration (cost-optimized)
rds_instance_class = "db.t4g.micro"
rds_allocated_storage = 20
rds_multi_az = false
rds_read_replicas = 0

# DocumentDB configuration
docdb_instance_class = "db.t3.medium"
docdb_instance_count = 1

# ElastiCache configuration
elasticache_node_type = "cache.t3.micro"
elasticache_num_cache_nodes = 1

# ECS configuration
ecs_task_cpu = "256"
ecs_task_memory = "512"
ecs_min_capacity = 1
ecs_max_capacity = 2

# Domain configuration
domain_name = "sankofagrid.com"
frontend_domain = "www.sankofagrid.com"
backend_domain = "api.sankofagrid.com"

# Feature flags
enable_waf = false
enable_x_ray = false
enable_enhanced_monitoring = false
```

### Production Environment (terraform/environments/prod/terraform.tfvars)

```hcl
# Environment configuration
environment = "prod"
project_name = "event-planner"

# Network configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
single_nat_gateway = false

# Database configuration (high availability)
rds_instance_class = "db.t4g.medium"
rds_allocated_storage = 100
rds_multi_az = true
rds_read_replicas = 2

# DocumentDB configuration
docdb_instance_class = "db.t4g.medium"
docdb_instance_count = 3

# ElastiCache configuration
elasticache_node_type = "cache.t4g.medium"
elasticache_num_cache_clusters = 3
elasticache_replicas_per_shard = 2

# ECS configuration
ecs_task_cpu = "512"
ecs_task_memory = "1024"
ecs_min_capacity = 2
ecs_max_capacity = 10

# Domain configuration
domain_name = "sankofagrid.com"
frontend_domain = "www.sankofagrid.com"
backend_domain = "api.sankofagrid.com"

# Feature flags
enable_waf = true
enable_x_ray = true
enable_enhanced_monitoring = true
```

## Secrets Management

### Manual Secrets Setup

Some secrets must be manually created in AWS Secrets Manager before deployment:

#### 1. Database Master Passwords

```bash
# Auth Database Password
aws secretsmanager create-secret \
  --name event-planner/dev/rds/auth-db/master-password \
  --description "Auth database master password" \
  --secret-string "YourSecurePassword123!" \
  --region us-east-1

# Event Database Password
aws secretsmanager create-secret \
  --name event-planner/dev/rds/event-db/master-password \
  --description "Event database master password" \
  --secret-string "YourSecurePassword123!" \
  --region us-east-1

# Booking Database Password
aws secretsmanager create-secret \
  --name event-planner/dev/rds/booking-db/master-password \
  --description "Booking database master password" \
  --secret-string "YourSecurePassword123!" \
  --region us-east-1

# Payment Database Password
aws secretsmanager create-secret \
  --name event-planner/dev/rds/payment-db/master-password \
  --description "Payment database master password" \
  --secret-string "YourSecurePassword123!" \
  --region us-east-1
```

#### 2. DocumentDB Master Password

```bash
aws secretsmanager create-secret \
  --name event-planner/dev/documentdb/master-password \
  --description "DocumentDB master password" \
  --secret-string "YourSecureDocDBPassword123!" \
  --region us-east-1
```

#### 3. JWT Signing Keys

```bash
# Generate a secure random key
JWT_SECRET=$(openssl rand -base64 64)

aws secretsmanager create-secret \
  --name event-planner/dev/jwt/signing-key \
  --description "JWT signing key for authentication" \
  --secret-string "{\"secret\":\"$JWT_SECRET\"}" \
  --region us-east-1
```

#### 4. ElastiCache Auth Token (Production only)

```bash
# Generate a secure auth token (16+ characters)
REDIS_AUTH_TOKEN=$(openssl rand -base64 32)

aws secretsmanager create-secret \
  --name event-planner/prod/elasticache/auth-token \
  --description "ElastiCache Redis auth token" \
  --secret-string "{\"auth_token\":\"$REDIS_AUTH_TOKEN\"}" \
  --region us-east-1
```

### Automatic Secrets Rotation

Database passwords can be automatically rotated using AWS Secrets Manager rotation:

```bash
# Enable rotation for RDS password (30-day rotation)
aws secretsmanager rotate-secret \
  --secret-id event-planner/prod/rds/auth-db/master-password \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRDSPostgreSQLRotation \
  --rotation-rules AutomaticallyAfterDays=30
```

### Runtime Secrets Access

ECS tasks retrieve secrets at runtime via environment variables:

```json
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:event-planner/dev/rds/auth-db/master-password"
    },
    {
      "name": "JWT_SECRET",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:event-planner/dev/jwt/signing-key:secret::"
    }
  ]
}
```

## Deployment Workflow

### Using Helper Scripts

#### 1. Deploy a New Environment

```bash
# Deploy development environment
./scripts/terraform/deploy-env.sh dev

# Deploy production environment
./scripts/terraform/deploy-env.sh prod
```

#### 2. Plan Infrastructure Changes

```bash
# Plan changes for development
./scripts/terraform/plan-env.sh dev

# Plan changes for production
./scripts/terraform/plan-env.sh prod
```

#### 3. Destroy Environment

```bash
# Destroy development environment (with confirmation)
./scripts/terraform/destroy-env.sh dev

# Destroy production environment (with confirmation)
./scripts/terraform/destroy-env.sh prod
```

#### 4. Validate All Terraform Code

```bash
# Validate syntax and configuration
./scripts/terraform/validate-all.sh
```

### Manual Deployment Steps

#### 1. Initialize Backend

```bash
cd terraform/environments/dev

terraform init \
  -backend-config="bucket=event-planner-terraform-state-dev" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=event-planner-terraform-locks"
```

#### 2. Plan Changes

```bash
terraform plan \
  -var-file="terraform.tfvars" \
  -out=tfplan
```

#### 3. Apply Changes

```bash
terraform apply tfplan
```

#### 4. Verify Outputs

```bash
terraform output
```

### CI/CD Integration

The infrastructure deployment is triggered via GitHub Actions:

```yaml
# .github/workflows/terraform-deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches:
      - main
    paths:
      - 'terraform/**'
  pull_request:
    branches:
      - main
    paths:
      - 'terraform/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Init
        run: |
          cd terraform/environments/${{ github.event.inputs.environment }}
          terraform init
      
      - name: Terraform Plan
        run: |
          cd terraform/environments/${{ github.event.inputs.environment }}
          terraform plan -out=tfplan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: |
          cd terraform/environments/${{ github.event.inputs.environment }}
          terraform apply -auto-approve tfplan
```

## Cost Optimization

### Development Environment Optimization

1. **Single-AZ Deployment**
   - Saves ~50% on NAT Gateway costs
   - Eliminates cross-AZ data transfer charges

2. **Minimal Instance Sizes**
   - RDS: db.t4g.micro/small (Graviton2 - 20% cheaper)
   - DocumentDB: db.t3.medium
   - ElastiCache: cache.t3.micro

3. **No Read Replicas**
   - Saves database replication costs

4. **Fargate Cost Optimization**
   - Minimal CPU/memory allocation (0.25 vCPU, 512 MB)
   - 1 task per service

5. **Weekday-Only Usage**
   ```bash
   # Stop non-production environments during off-hours
   # Use AWS Lambda or scheduled scripts
   ./scripts/utilities/stop-dev-environment.sh
   ```

### Production Environment Optimization

1. **Reserved Instances / Savings Plans**
   - 1-year commitment saves ~40% on RDS
   - Fargate Savings Plans save ~50%

2. **Fargate Spot**
   - Use 30% Fargate Spot for non-critical services
   - Saves up to 70% on compute costs

3. **S3 Lifecycle Policies**
   - Transition logs to Glacier after 90 days
   - Delete old logs after 1 year

4. **CloudFront Cache Optimization**
   - Maximize cache hit ratio
   - Reduce origin requests

5. **VPC Endpoints**
   - Eliminates NAT Gateway charges for AWS service traffic
   - Saves ~$0.045/GB on data transfer

### Cost Monitoring

```bash
# Enable AWS Cost Explorer tags
terraform apply -var="enable_cost_allocation_tags=true"

# Tag resources for cost tracking
tags = {
  Environment = "dev"
  Project     = "event-planner"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
}
```

## Disaster Recovery

### Backup Strategy

#### RDS Automated Backups

```hcl
# Configured in RDS module
backup_retention_period = 7
backup_window           = "03:00-04:00"
maintenance_window      = "sun:04:00-sun:05:00"

# Enable point-in-time recovery
enabled_cloudwatch_logs_exports = ["postgresql"]
```

#### Cross-Region Backup

```bash
# Manual cross-region snapshot copy
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:us-east-1:123456789012:snapshot:auth-db-snapshot-2024-01-01 \
  --target-db-snapshot-identifier auth-db-snapshot-2024-01-01-dr \
  --region us-west-2 \
  --kms-key-id arn:aws:kms:us-west-2:123456789012:key/dr-key-id
```

### DR Testing

Quarterly DR drills are recommended:

```bash
# 1. Deploy DR infrastructure in secondary region
cd terraform/environments/prod-dr
terraform apply

# 2. Restore RDS from latest snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier event-planner-auth-db-dr \
  --db-snapshot-identifier arn:aws:rds:us-west-2:123456789012:snapshot:auth-db-snapshot-latest \
  --db-instance-class db.t4g.medium

# 3. Update Route53 health checks to point to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://dr-failover-config.json

# 4. Verify application functionality
curl https://api.sankofagrid.com/health

# 5. Document lessons learned and update runbooks
```

## Troubleshooting

### Common Issues

#### Issue: Terraform State Lock

**Symptom:** "Error acquiring the state lock"

**Solution:**
```bash
# List DynamoDB locks
aws dynamodb scan \
  --table-name event-planner-terraform-locks \
  --region us-east-1

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

#### Issue: Database Connection Timeout

**Symptom:** ECS tasks cannot connect to RDS

**Solution:**
```bash
# 1. Verify security group rules
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID>

# 2. Check VPC endpoint connectivity
aws ec2 describe-vpc-endpoints

# 3. Verify ECS task role has necessary permissions
aws iam get-role-policy \
  --role-name event-planner-ecs-task-role \
  --policy-name database-access
```

#### Issue: CloudFront Distribution Not Updating

**Symptom:** Changes to S3 bucket not reflected in CloudFront

**Solution:**
```bash
# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"

# Check invalidation status
aws cloudfront get-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --id <INVALIDATION_ID>
```

#### Issue: ECS Tasks Failing to Start

**Symptom:** "CannotPullContainerError" or "ResourceInitializationError"

**Solution:**
```bash
# 1. Verify ECR permissions in task execution role
aws iam get-role-policy \
  --role-name event-planner-ecs-execution-role \
  --policy-name ecr-access

# 2. Check VPC endpoints for ECR
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=com.amazonaws.us-east-1.ecr.dkr"

# 3. Verify task definition secrets are accessible
aws secretsmanager get-secret-value \
  --secret-id event-planner/dev/rds/auth-db/master-password
```

### Debugging Commands

```bash
# View Terraform state
terraform show

# List all resources
terraform state list

# Inspect specific resource
terraform state show module.vpc.aws_vpc.main

# View logs
terraform output -raw cloudwatch_log_group_name | xargs -I {} \
  aws logs tail {} --follow

# Check resource dependencies
terraform graph | dot -Tsvg > graph.svg
```


## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

---

**Last Updated:** January 2025  
**Maintained By:** DevOps Team 
**Version:** 1.0.0