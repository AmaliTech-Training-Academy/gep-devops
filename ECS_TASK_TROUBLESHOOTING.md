# ECS Task Troubleshooting Guide

## Issue: Auth-Service Deployed But No Tasks Running

### ✅ Fixes Applied

#### 1. **Health Check Timing Increased**
**Problem:** Spring Boot applications take 60-90 seconds to start, but health checks were failing after 60 seconds.

**Fix Applied:**
- Container health check `startPeriod`: 60s → **120s**
- ECS service `health_check_grace_period`: 60s → **180s**

**File:** `terraform/modules/ecs/main.tf`

This gives the application enough time to:
1. Pull Docker image from ECR (~10-20s)
2. Start Spring Boot (~40-60s)
3. Initialize database connections (~10-20s)
4. Become healthy and respond to health checks

---

## 🔍 Diagnostic Steps

### Step 1: Run Diagnostic Script
```bash
./scripts/diagnose-ecs-tasks.sh auth-service
```

This script checks:
- ✅ Service exists
- ✅ Service status (desired vs running count)
- ✅ Recent service events
- ✅ Task definition and image
- ✅ Stopped tasks (failures)
- ✅ Target group health
- ✅ CloudWatch logs
- ✅ Network configuration

### Step 2: Check Service Status Manually
```bash
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service \
  --region eu-west-1 \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Events:events[:3]}'
```

### Step 3: Check for Stopped Tasks (Failures)
```bash
# List stopped tasks
aws ecs list-tasks \
  --cluster event-planner-dev-cluster \
  --service-name auth-service \
  --desired-status STOPPED \
  --region eu-west-1

# Describe the most recent stopped task
aws ecs describe-tasks \
  --cluster event-planner-dev-cluster \
  --tasks <TASK_ARN> \
  --region eu-west-1 \
  --query 'tasks[0].{StoppedReason:stoppedReason,Containers:containers[0].{ExitCode:exitCode,Reason:reason}}'
```

### Step 4: Check CloudWatch Logs
```bash
# Tail logs in real-time
aws logs tail /ecs/event-planner/dev/auth-service --follow --region eu-west-1

# Get last 50 log entries
aws logs tail /ecs/event-planner/dev/auth-service --since 10m --region eu-west-1
```

---

## 🚨 Common Issues & Solutions

### Issue 1: Image Not Found in ECR
**Symptom:** Task stops immediately with "CannotPullContainerError"

**Check:**
```bash
aws ecr describe-images \
  --repository-name event-planner-dev-auth-service \
  --region eu-west-1
```

**Solution:**
```bash
# Build and push image using CI/CD pipeline
# Or manually:
cd path/to/auth-service
docker build -t auth-service .
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com
docker tag auth-service:latest <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-auth-service:latest
docker push <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-auth-service:latest
```

### Issue 2: Health Check Failures
**Symptom:** Task starts but stops after 2-3 minutes with "Task failed ELB health checks"

**Check logs for:**
- Application startup errors
- Database connection failures
- Missing environment variables
- Port binding issues

**Solution:**
```bash
# Check if /actuator/health endpoint works
# Get task private IP
TASK_ARN=$(aws ecs list-tasks --cluster event-planner-dev-cluster --service-name auth-service --region eu-west-1 --query 'taskArns[0]' --output text)
TASK_IP=$(aws ecs describe-tasks --cluster event-planner-dev-cluster --tasks $TASK_ARN --region eu-west-1 --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' --output text)

# From a bastion host or another container in the VPC:
curl http://$TASK_IP:8081/actuator/health
```

### Issue 3: Missing Secrets
**Symptom:** Application crashes with "Could not resolve placeholder" errors

**Check:**
```bash
# Verify JWT secret exists
aws secretsmanager get-secret-value \
  --secret-id event-planner-dev-jwt-secret \
  --region eu-west-1

# Verify database secrets exist
aws secretsmanager get-secret-value \
  --secret-id event-planner/dev/rds/auth-db/credentials \
  --region eu-west-1

# Check IAM permissions
aws iam get-role-policy \
  --role-name event-planner-dev-ecs-task-execution-role \
  --policy-name secrets-manager-access \
  --region eu-west-1
```

**Solution:**
```bash
# If JWT secret missing, apply Terraform
cd terraform/environments/dev
terraform apply -target=aws_secretsmanager_secret.jwt_secret
```

### Issue 4: VPC Endpoint Issues (No NAT Gateway)
**Symptom:** Task stops with "ResourceInitializationError" or "CannotPullContainerError"

**Check VPC Endpoints:**
```bash
aws ec2 describe-vpc-endpoints \
  --region eu-west-1 \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'VpcEndpoints[*].{Service:ServiceName,State:State}'
```

**Required endpoints:**
- ✅ com.amazonaws.eu-west-1.ecr.api
- ✅ com.amazonaws.eu-west-1.ecr.dkr
- ✅ com.amazonaws.eu-west-1.logs
- ✅ com.amazonaws.eu-west-1.secretsmanager
- ✅ com.amazonaws.eu-west-1.s3 (gateway)

**Solution:**
```bash
# VPC endpoints should already be created by Terraform
# If missing, check terraform/modules/vpc/main.tf
cd terraform/environments/dev
terraform apply -target=module.vpc
```

### Issue 5: Security Group Rules
**Symptom:** Target group shows "unhealthy" but container is running

**Check security groups:**
```bash
# ECS security group should allow traffic from ALB
aws ec2 describe-security-groups \
  --group-ids <ECS_SG_ID> \
  --region eu-west-1 \
  --query 'SecurityGroups[0].IpPermissions'
```

**Required rules:**
- ALB → ECS: Port 8081 (auth-service)
- ALB → ECS: Port 8082 (event-service)
- ECS → RDS: Port 5432
- ECS → ElastiCache: Port 6379
- ECS → VPC Endpoints: Port 443

### Issue 6: Target Group Configuration
**Symptom:** Service deployed but ALB returns 503

**Check target group:**
```bash
# Find target group
aws elbv2 describe-target-groups \
  --region eu-west-1 \
  --query "TargetGroups[?contains(TargetGroupName, 'auth')].{Name:TargetGroupName,ARN:TargetGroupArn}"

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region eu-west-1
```

**Expected output:**
```json
{
  "TargetHealthDescriptions": [
    {
      "Target": {
        "Id": "10.0.x.x",
        "Port": 8081
      },
      "HealthCheckPort": "8081",
      "TargetHealth": {
        "State": "healthy"
      }
    }
  ]
}
```

---

## 🔧 Quick Fixes

### Force New Deployment
```bash
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --force-new-deployment \
  --region eu-west-1
```

### Update Task Definition (After Terraform Changes)
```bash
cd terraform/environments/dev
terraform apply -target=module.ecs
```

### Restart Service
```bash
# Scale down to 0
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --desired-count 0 \
  --region eu-west-1

# Wait 30 seconds
sleep 30

# Scale back up to 1
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --desired-count 1 \
  --region eu-west-1
```

### Check Task Definition
```bash
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --region eu-west-1 \
  --query 'taskDefinition.{CPU:cpu,Memory:memory,Image:containerDefinitions[0].image,Environment:containerDefinitions[0].environment,Secrets:containerDefinitions[0].secrets}'
```

---

## 📊 Monitoring Commands

### Watch Service Status
```bash
watch -n 5 'aws ecs describe-services --cluster event-planner-dev-cluster --services auth-service --region eu-west-1 --query "services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}" --output table'
```

### Stream Logs
```bash
aws logs tail /ecs/event-planner/dev/auth-service --follow --region eu-west-1
```

### Check All Services
```bash
aws ecs list-services \
  --cluster event-planner-dev-cluster \
  --region eu-west-1 \
  --query 'serviceArns' \
  --output table
```

---

## ✅ Deployment Checklist

Before deploying, ensure:

- [ ] Docker image exists in ECR
- [ ] JWT secret exists in Secrets Manager
- [ ] Database secrets exist in Secrets Manager
- [ ] RDS database is running and accessible
- [ ] ElastiCache is running and accessible
- [ ] VPC endpoints are active
- [ ] Security groups allow required traffic
- [ ] Target groups are created
- [ ] ALB listener rules are configured
- [ ] Task definition has correct environment variables
- [ ] IAM roles have necessary permissions

---

## 🚀 Next Steps After Fixing

1. **Apply Terraform changes:**
   ```bash
   cd terraform/environments/dev
   terraform apply
   ```

2. **Wait for deployment:**
   ```bash
   aws ecs wait services-stable \
     --cluster event-planner-dev-cluster \
     --services auth-service \
     --region eu-west-1
   ```

3. **Verify health:**
   ```bash
   curl https://api.sankofagrid.com/api/v1/auth/actuator/health
   ```

4. **Check logs:**
   ```bash
   ./scripts/diagnose-ecs-tasks.sh auth-service
   ```

---

## 📞 Still Having Issues?

Run the comprehensive diagnostic:
```bash
./scripts/diagnose-ecs-tasks.sh auth-service
```

This will provide a detailed report of:
- Service status
- Recent events
- Stopped tasks and reasons
- Target group health
- CloudWatch logs
- Network configuration
- Actionable recommendations

---

**Last Updated:** January 2025  
**Status:** Health check timings fixed, diagnostic tools provided
