# Immediate Fix Steps - 503 Error & 0 Tasks Running

## Current Status
- ✅ Services deployed: auth-service, event-service
- ❌ Tasks running: 0/2 (auth), 0/1 (event)
- ❌ Deployment status: Failed
- ❌ Result: 503 Service Temporarily Unavailable

---

## Step 1: Diagnose the Problem

Run the diagnostic script:
```bash
./diagnose-and-fix.sh
```

This will show you:
- Service status and events
- Why tasks stopped (failure reason)
- CloudWatch logs with errors
- Recommended actions

---

## Step 2: Common Issues & Quick Fixes

### Issue A: Docker Images Don't Exist in ECR

**Check:**
```bash
aws ecr describe-images \
  --repository-name event-planner-dev-auth-service \
  --region eu-west-1

aws ecr describe-images \
  --repository-name event-planner-dev-event-service \
  --region eu-west-1
```

**If no images found, you need to build and push:**
```bash
# This is likely your issue if you see "CannotPullContainerError"
# You need to build and push Docker images first
```

**Fix:** Build and push images using your CI/CD pipeline or manually

---

### Issue B: Health Check Timing (Already Fixed in Code)

**What we fixed:**
- Container health check startPeriod: 60s → 120s
- ECS service grace period: 60s → 180s

**Apply the fix:**
```bash
cd terraform/environments/dev
terraform apply
```

This will update task definitions with longer health check periods.

---

### Issue C: Missing JWT Secret

**Check:**
```bash
aws secretsmanager describe-secret \
  --secret-id event-planner-dev-jwt-secret \
  --region eu-west-1
```

**If not found:**
```bash
cd terraform/environments/dev
terraform apply -target=module.secrets_manager
```

---

### Issue D: VPC Endpoint Issues

**Check VPC endpoints:**
```bash
aws ec2 describe-vpc-endpoints \
  --region eu-west-1 \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --query 'VpcEndpoints[*].{Service:ServiceName,State:State}'
```

**All should be "available":**
- com.amazonaws.eu-west-1.ecr.api
- com.amazonaws.eu-west-1.ecr.dkr
- com.amazonaws.eu-west-1.logs
- com.amazonaws.eu-west-1.secretsmanager
- com.amazonaws.eu-west-1.s3

---

## Step 3: Apply Updated Configuration

```bash
cd terraform/environments/dev

# Apply all changes (including health check fixes)
terraform apply

# Wait for services to stabilize
aws ecs wait services-stable \
  --cluster event-planner-dev-cluster \
  --services auth-service event-service \
  --region eu-west-1
```

---

## Step 4: Force New Deployment (If Needed)

If Terraform apply doesn't trigger new deployment:

```bash
# Force redeploy auth-service
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --force-new-deployment \
  --region eu-west-1

# Force redeploy event-service
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service event-service \
  --force-new-deployment \
  --region eu-west-1
```

---

## Step 5: Monitor Deployment

### Watch service status:
```bash
watch -n 5 'aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service event-service \
  --region eu-west-1 \
  --query "services[*].{Service:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount}" \
  --output table'
```

### Stream logs:
```bash
# Auth service logs
aws logs tail /ecs/event-planner/dev/auth-service --follow --region eu-west-1

# Event service logs (in another terminal)
aws logs tail /ecs/event-planner/dev/event-service --follow --region eu-west-1
```

---

## Step 6: Verify Services Are Healthy

### Check target group health:
```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --region eu-west-1 \
  --query "TargetGroups[?contains(TargetGroupName, 'auth')].TargetGroupArn" \
  --output text)

# Check health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region eu-west-1
```

**Expected:** State should be "healthy"

### Test endpoints:
```bash
# Get ALB DNS
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region eu-west-1 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'event')].DNSName" \
  --output text)

# Test auth service
curl -v http://$ALB_DNS/api/v1/auth/actuator/health

# Test event service
curl -v http://$ALB_DNS/api/v1/events/actuator/health
```

**Expected:** HTTP 200 with `{"status":"UP"}`

---

## Most Likely Issue: No Docker Images

Based on "0 tasks running" and "Failed" status, the most common cause is:

**Docker images don't exist in ECR repositories**

### Quick Check:
```bash
aws ecr describe-repositories --region eu-west-1 --query 'repositories[*].repositoryName'
```

You should see:
- event-planner-dev-auth-service
- event-planner-dev-event-service

### Check if images exist:
```bash
aws ecr describe-images \
  --repository-name event-planner-dev-auth-service \
  --region eu-west-1 \
  --query 'imageDetails[*].imageTags'
```

**If empty or error:** You need to build and push Docker images first!

---

## Build and Push Images (If Missing)

### Option 1: Use CI/CD Pipeline
Trigger your GitHub Actions workflow to build and push images

### Option 2: Manual Build (Example for auth-service)
```bash
# Navigate to auth-service code
cd /path/to/auth-service

# Build Docker image
docker build -t auth-service:latest .

# Get ECR login
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin \
  904570587823.dkr.ecr.eu-west-1.amazonaws.com

# Tag image
docker tag auth-service:latest \
  904570587823.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-auth-service:latest

# Push to ECR
docker push 904570587823.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-auth-service:latest
```

Repeat for event-service.

---

## After Images Are Pushed

```bash
# Force new deployment
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --force-new-deployment \
  --region eu-west-1

aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service event-service \
  --force-new-deployment \
  --region eu-west-1

# Watch deployment
watch -n 5 'aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service event-service \
  --region eu-west-1 \
  --query "services[*].{Service:serviceName,Running:runningCount,Pending:pendingCount}" \
  --output table'
```

---

## Success Indicators

✅ **Tasks Running:**
- auth-service: 1/1 tasks running
- event-service: 1/1 tasks running

✅ **Target Groups:**
- All targets showing "healthy"

✅ **HTTP Responses:**
- `curl http://ALB_DNS/api/v1/auth/actuator/health` returns 200
- `curl http://ALB_DNS/api/v1/events/actuator/health` returns 200

✅ **No 503 Errors:**
- ALB returns proper responses, not 503

---

## Quick Command Summary

```bash
# 1. Diagnose
./diagnose-and-fix.sh

# 2. Check for images
aws ecr describe-images --repository-name event-planner-dev-auth-service --region eu-west-1

# 3. Apply Terraform updates
cd terraform/environments/dev && terraform apply

# 4. Force deployment
aws ecs update-service --cluster event-planner-dev-cluster --service auth-service --force-new-deployment --region eu-west-1
aws ecs update-service --cluster event-planner-dev-cluster --service event-service --force-new-deployment --region eu-west-1

# 5. Watch status
watch -n 5 'aws ecs describe-services --cluster event-planner-dev-cluster --services auth-service event-service --region eu-west-1 --query "services[*].{Service:serviceName,Running:runningCount}" --output table'

# 6. Check logs
aws logs tail /ecs/event-planner/dev/auth-service --follow --region eu-west-1
```

---

**Start with:** `./diagnose-and-fix.sh` to see the exact error!
