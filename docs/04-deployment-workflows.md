# Deployment Workflows

**Last Updated:** November 2025  
**Version:** 2.0.0

## Overview

This document outlines step-by-step deployment procedures for infrastructure, backend services, and frontend applications across different environments.

## Prerequisites

### Required Tools
- AWS CLI v2.0+
- Terraform v1.5.0+
- Git
- GitHub account with Actions enabled

### Required Access
- AWS account with appropriate permissions
- GitHub repository access
- Cloudflare DNS access (for domain management)

### GitHub Secrets Configuration

Navigate to repository Settings → Secrets and variables → Actions:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
TF_STATE_BUCKET
TF_STATE_DYNAMODB_TABLE
PAYMENT_SERVICE_URL
SLACK_WEBHOOK_URL
```

## Infrastructure Deployment

### Initial Infrastructure Setup

**Step 1: Configure AWS Credentials**

```bash
aws configure
# Enter AWS Access Key ID
# Enter AWS Secret Access Key
# Default region: eu-west-1
```

**Step 2: Initialize Terraform Backend**

```bash
cd terraform/environments/dev
terraform init
```

**Step 3: Review Infrastructure Plan**

```bash
terraform plan -out=tfplan
```

**Step 4: Apply Infrastructure**

```bash
terraform apply tfplan
```

**Step 5: Verify Deployment**

```bash
# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=event-planner-dev-vpc"

# Check ECS cluster
aws ecs list-clusters

# Check RDS instance
aws rds describe-db-instances
```

### Infrastructure Updates

**Automated Deployment (Recommended)**

1. Make changes to Terraform files
2. Commit and push to main branch
3. GitHub Actions automatically triggers
4. Monitor workflow in Actions tab

**Manual Deployment**

```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

### Infrastructure Rollback

```bash
# Revert to previous state
terraform apply -target=<resource>

# Or restore from backup
terraform state pull > backup.tfstate
terraform state push backup.tfstate
```

## Backend Service Deployment

### Automated Deployment

**Step 1: Trigger Deployment**

Push changes to backend repository:

```bash
git add .
git commit -m "Update service"
git push origin main
```

**Step 2: Monitor Pipeline**

- Navigate to GitHub Actions
- Watch backend-ci-cd workflow
- Review build logs

**Step 3: Verify Deployment**

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service event-service payment-service notification-service

# Test service health
curl https://api.sankofagrid.com/api/v1/auth/actuator/health
curl https://api.sankofagrid.com/api/v1/events/actuator/health
curl https://api.sankofagrid.com/api/v1/payments/actuator/health
curl https://api.sankofagrid.com/api/v1/notifications/actuator/health
```

### Manual Service Deployment

**Step 1: Build Docker Image**

```bash
cd backend-service
mvn clean package
docker build -t auth-service:latest .
```

**Step 2: Push to ECR**

```bash
# Login to ECR
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-1.amazonaws.com

# Tag image
docker tag auth-service:latest <account-id>.dkr.ecr.eu-west-1.amazonaws.com/auth-service:latest

# Push image
docker push <account-id>.dkr.ecr.eu-west-1.amazonaws.com/auth-service:latest
```

**Step 3: Update ECS Service**

```bash
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --force-new-deployment
```

### Service Rollback

```bash
# Rollback to previous task definition
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --task-definition auth-service:previous-revision
```

## Frontend Deployment

### Automated Deployment

**Step 1: Trigger Deployment**

Push changes to frontend repository:

```bash
git add .
git commit -m "Update frontend"
git push origin main
```

**Step 2: Monitor Pipeline**

- Navigate to GitHub Actions
- Watch frontend-ci-cd workflow
- Review build logs

**Step 3: Verify Deployment**

```bash
# Check S3 bucket
aws s3 ls s3://event-planner-dev-assets/

# Test frontend
curl https://events.sankofagrid.com
```

### Manual Frontend Deployment

**Step 1: Build Application**

```bash
cd frontend
npm install
ng build --configuration=production
```

**Step 2: Deploy to S3**

```bash
aws s3 sync dist/event-planner s3://event-planner-dev-assets/ --delete
```

**Step 3: Invalidate CloudFront Cache**

```bash
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

### Frontend Rollback

```bash
# Restore previous version from S3 versioning
aws s3api list-object-versions \
  --bucket event-planner-dev-assets \
  --prefix index.html

# Restore specific version
aws s3api copy-object \
  --bucket event-planner-dev-assets \
  --copy-source event-planner-dev-assets/index.html?versionId=<version-id> \
  --key index.html
```

## Environment-Specific Deployments

### Development Environment

**Deployment Frequency:** Continuous (on every push)

**Process:**
1. Push to main branch
2. Automatic pipeline trigger
3. No approval required
4. Fast deployment (5-10 minutes)

**Verification:**
```bash
# Check all services
curl https://api.sankofagrid.com/actuator/health
```

### Production Environment

**Deployment Frequency:** Scheduled releases

**Process:**
1. Create release branch
2. Manual workflow trigger
3. Required approval from reviewers
4. Blue-green deployment
5. Smoke tests
6. Traffic switch
7. Monitor for 24 hours

**Verification:**
```bash
# Check production services
curl https://api.sankofagrid.com/actuator/health

# Monitor CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=auth-service \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average
```

## Secrets Management

### Creating Secrets

```bash
# JWT Secret
aws secretsmanager create-secret \
  --name event-planner/dev/jwt-secret \
  --secret-string '{"JWT_SECRET":"your-secret-key"}'

# Database Credentials
aws secretsmanager create-secret \
  --name event-planner/dev/rds/auth-db \
  --secret-string '{"username":"admin","password":"secure-password"}'

# Google SMTP Credentials
aws secretsmanager create-secret \
  --name event-planner/dev/google-credentials \
  --secret-string '{"GOOGLE_USER":"email","GOOGLE_PASSWORD":"password"}'

# Paystack API Key
aws secretsmanager create-secret \
  --name event-planner/dev/paystack-credentials \
  --secret-string '{"PAYSTACK_SECRET":"your-key"}'

# Redis Auth Token
aws secretsmanager create-secret \
  --name event-planner/dev/redis-credentials \
  --secret-string '{"REDIS_AUTH_TOKEN":"your-token"}'
```

### Updating Secrets

```bash
aws secretsmanager update-secret \
  --secret-id event-planner/dev/jwt-secret \
  --secret-string '{"JWT_SECRET":"new-secret-key"}'
```

## DNS Configuration

### Cloudflare Setup

**Frontend (CloudFront):**
- Type: CNAME
- Name: events
- Target: <cloudfront-distribution>.cloudfront.net
- Proxy: Enabled

**Backend (ALB):**
- Type: CNAME
- Name: api
- Target: <alb-dns-name>.eu-west-1.elb.amazonaws.com
- Proxy: Disabled (for SSL passthrough)

## Health Checks

### Service Health Endpoints

```bash
# Auth Service
curl https://api.sankofagrid.com/api/v1/auth/actuator/health

# Event Service
curl https://api.sankofagrid.com/api/v1/events/actuator/health

# Payment Service
curl https://api.sankofagrid.com/api/v1/payments/actuator/health

# Notification Service
curl https://api.sankofagrid.com/api/v1/notifications/actuator/health
```

### Infrastructure Health

```bash
# ECS Services
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service

# RDS Instance
aws rds describe-db-instances \
  --db-instance-identifier event-planner-dev-auth-db

# ElastiCache
aws elasticache describe-cache-clusters \
  --cache-cluster-id event-planner-dev-redis
```

## Monitoring Deployments

### CloudWatch Logs

```bash
# View ECS logs
aws logs tail /ecs/event-planner/dev/auth-service --follow

# View specific time range
aws logs tail /ecs/event-planner/dev/auth-service \
  --since 1h \
  --format short
```

### Deployment Metrics

```bash
# ECS deployment status
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service \
  --query 'services[0].deployments'

# Task status
aws ecs list-tasks \
  --cluster event-planner-dev-cluster \
  --service-name auth-service
```

## Emergency Procedures

### Service Failure

1. Check CloudWatch logs
2. Review ECS service events
3. Verify security group rules
4. Check secrets availability
5. Rollback if necessary

### Database Issues

1. Check RDS status
2. Review database logs
3. Verify security group rules
4. Check connection pool settings
5. Restore from backup if needed

### Complete Rollback

```bash
# Infrastructure
terraform apply -target=<previous-state>

# Backend Services
aws ecs update-service --task-definition <previous-revision>

# Frontend
aws s3 sync s3://backup-bucket/ s3://event-planner-dev-assets/
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

## Post-Deployment Checklist

- [ ] All services healthy
- [ ] Health endpoints responding
- [ ] Database connections working
- [ ] Redis cache accessible
- [ ] SQS/SNS queues processing
- [ ] CloudWatch logs flowing
- [ ] No error alarms triggered
- [ ] Frontend accessible
- [ ] API endpoints responding
- [ ] SSL certificates valid
