# Event Planner Infrastructure - Complete Deployment Guide

## Prerequisites

### 1. Install Required Tools

```bash
# Terraform (>= 1.5.0)
brew install terraform

# AWS CLI (>= 2.0)
brew install awscli

# jq (for JSON processing)
brew install jq
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 3. Register Domain (sankofagrid.com)

Ensure you have registered the domain and have access to DNS management.

## Step-by-Step Deployment

### Phase 1: Initialize Backend (One-Time Setup)

```bash
# 1. Navigate to project root
cd gep_devops

# 2. Make scripts executable
chmod +x scripts/terraform/*.sh

# 3. Initialize Terraform backend
./scripts/terraform/init-backend.sh

# 4. Note the S3 bucket and DynamoDB table names
# Update backend.tf in each environment with these values
```

### Phase 2: Setup Secrets

```bash
# 1. Create AWS Secrets Manager secrets
./scripts/terraform/setup-secrets.sh dev

# 2. Verify secrets were created
aws secretsmanager list-secrets --region us-east-1

# 3. Save the secret ARNs for later reference
```

### Phase 3: Deploy Development Environment

```bash
# 1. Navigate to dev environment
cd terraform/environments/dev

# 2. Create .env file from example
cp .env.example .env

# 3. Edit .env with your values
nano .env

# 4. Load environment variables
source .env

# 5. Initialize Terraform with backend
terraform init \
  -backend-config="bucket=YOUR_S3_BUCKET" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_DYNAMODB_TABLE"

# 6. Review planned changes
terraform plan

# 7. Deploy infrastructure
terraform apply

# 8. Save outputs
terraform output > infrastructure-outputs.txt
```

### Phase 4: Configure Domain DNS

```bash
# 1. Get Route53 nameservers
terraform output route53_nameservers

# 2. Update domain registrar with these nameservers
# This delegates DNS management to Route53

# 3. Wait for DNS propagation (up to 48 hours)
# Verify: dig NS sankofagrid.com
```

### Phase 5: Deploy Frontend (Angular)

```bash
# 1. Build Angular application
cd event-planner-frontend
npm install
npm run build --prod

# 2. Get S3 bucket name
S3_BUCKET=$(cd ../../gep_devops/terraform/environments/dev && terraform output -raw frontend_bucket_name)

# 3. Upload to S3
aws s3 sync dist/ s3://$S3_BUCKET/ --delete

# 4. Get CloudFront distribution ID
CLOUDFRONT_ID=$(cd ../../gep_devops/terraform/environments/dev && terraform output -raw cloudfront_distribution_id)

# 5. Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_ID \
  --paths "/*"

# 6. Access frontend
# https://www.sankofagrid.com
```

### Phase 6: Deploy Backend (Microservices)

```bash
# 1. Create ECR repositories
aws ecr create-repository --repository-name event-planner/auth-service
aws ecr create-repository --repository-name event-planner/event-service
aws ecr create-repository --repository-name event-planner/booking-service
aws ecr create-repository --repository-name event-planner/payment-service
aws ecr create-repository --repository-name event-planner/notification-service

# 2. Build and push Docker images
cd gep-backend/services/auth-service
docker build -t event-planner/auth-service:latest .

# 3. Tag and push to ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker tag event-planner/auth-service:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/event-planner/auth-service:latest

docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/event-planner/auth-service:latest

# 4. Repeat for all microservices

# 5. Update ECS task definitions with actual endpoints
cd gep_devops/ecs/task-definitions
# Edit each JSON file with actual database endpoints from Terraform outputs

# 6. Register task definitions
aws ecs register-task-definition --cli-input-json file://auth-service.json

# 7. Create ECS services
aws ecs create-service \
  --cluster event-planner-dev-cluster \
  --service-name auth-service \
  --task-definition event-planner-dev-auth-service \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=DISABLED}"

# 8. Access backend
# https://api.sankofagrid.com
```

### Phase 7: Verify Deployment

```bash
# 1. Check frontend
curl -I https://www.sankofagrid.com

# 2. Check backend health
curl https://api.sankofagrid.com/actuator/health

# 3. Check ECS services
aws ecs list-services --cluster event-planner-dev-cluster
aws ecs describe-services --cluster event-planner-dev-cluster --services auth-service

# 4. Check RDS instances
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]'

# 5. View logs
aws logs tail /ecs/event-planner/auth-service --follow
```

## Cost Management

### Development Environment Cost Optimization

```bash
# Stop ECS services (when not in use)
aws ecs update-service --cluster event-planner-dev-cluster --service auth-service --desired-count 0

# Stop RDS instances
aws rds stop-db-instance --db-instance-identifier event-planner-dev-auth-db

# Restart services when needed
aws ecs update-service --cluster event-planner-dev-cluster --service auth-service --desired-count 1
aws rds start-db-instance --db-instance-identifier event-planner-dev-auth-db
```

### Estimated Costs

- **24/7 Operation**: ~$248/month
- **Weekday Only (8am-6pm)**: ~$75-95/month

## Troubleshooting

### Issue: Cannot connect to database

```bash
# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxx

# Check ECS task logs
aws logs tail /ecs/event-planner/auth-service --since 10m
```

### Issue: Frontend not accessible

```bash
# Check CloudFront distribution status
aws cloudfront get-distribution --id $CLOUDFRONT_ID

# Check S3 bucket policy
aws s3api get-bucket-policy --bucket $S3_BUCKET

# Create CloudFront invalidation
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
```

### Issue: Backend not responding

```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# Check ECS task status
aws ecs describe-tasks --cluster event-planner-dev-cluster --tasks task-id

# Check service discovery
aws servicediscovery list-services --namespace-id ns-xxx
```

## Next Steps

1. Set up CI/CD pipelines in GitHub Actions
2. Configure monitoring and alerting
3. Implement backup and disaster recovery testing
4. Set up staging environment
5. Prepare for production deployment

