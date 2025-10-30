# Event Planner Platform - DevOps Infrastructure Documentation
## Part 7: Troubleshooting and Runbooks

**Author:** DevOps Team  
**Last Updated:** October 30, 2025  
**Version:** 1.0.0

---

## Troubleshooting Guide

This section provides comprehensive troubleshooting procedures for common issues encountered in the Event Planner Platform infrastructure and deployment processes.

---

## Common Infrastructure Issues

### 1. Terraform State Lock Issues

**Symptom**: `Error acquiring the state lock`

**Cause**: Previous Terraform operation was interrupted, leaving a lock in DynamoDB

**Solution**:
```bash
# 1. List current locks
aws dynamodb scan \
  --table-name event-planner-terraform-locks \
  --region eu-west-1

# 2. Identify the lock ID from the output
# 3. Force unlock (use with caution)
terraform force-unlock <LOCK_ID>

# 4. If force-unlock fails, manually delete from DynamoDB
aws dynamodb delete-item \
  --table-name event-planner-terraform-locks \
  --key '{"LockID":{"S":"<LOCK_ID>"}}'
```

**Prevention**:
- Always use `terraform plan` before `terraform apply`
- Don't interrupt Terraform operations
- Use proper CI/CD pipelines instead of manual runs

### 2. ECS Service Deployment Failures

**Symptom**: ECS service fails to reach stable state

**Diagnosis Steps**:
```bash
# 1. Check service status
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Deployments:deployments[*].{Status:status,TaskDef:taskDefinition}}'

# 2. Check recent service events
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service \
  --query 'services[0].events[:10]'

# 3. Check task failures
TASK_ARNS=$(aws ecs list-tasks \
  --cluster event-planner-dev-cluster \
  --service-name auth-service \
  --desired-status STOPPED \
  --query 'taskArns' \
  --output text)

if [ -n "$TASK_ARNS" ]; then
  aws ecs describe-tasks \
    --cluster event-planner-dev-cluster \
    --tasks $TASK_ARNS \
    --query 'tasks[*].{TaskArn:taskArn,LastStatus:lastStatus,StoppedReason:stoppedReason,ExitCode:containers[0].exitCode}'
fi
```

**Common Causes and Solutions**:

#### A. Container Health Check Failures
```bash
# Check container logs
aws logs tail /ecs/event-planner/dev/auth-service --follow

# Common issues:
# - Database connection failures
# - Missing environment variables
# - Application startup errors
```

#### B. Resource Constraints
```bash
# Check if tasks are being killed due to memory limits
aws ecs describe-tasks \
  --cluster event-planner-dev-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[0].containers[0].reason'

# If "OutOfMemory", increase memory allocation in Terraform
```

#### C. Security Group Issues
```bash
# Verify security group rules
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxxx \
  --query 'SecurityGroups[0].IpPermissions'

# Check if ECS security group allows ALB traffic on service ports
```

### 3. Database Connection Issues

**Symptom**: Applications cannot connect to RDS

**Diagnosis**:
```bash
# 1. Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier event-planner-dev-auth-db \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}'

# 2. Test connectivity from ECS subnet
# (Run from a test EC2 instance in the same subnet)
telnet <RDS_ENDPOINT> 5432

# 3. Check security group rules
aws ec2 describe-security-groups \
  --group-ids <RDS_SECURITY_GROUP_ID> \
  --query 'SecurityGroups[0].IpPermissions'
```

**Common Solutions**:
- Verify security group allows ECS security group on port 5432
- Check if RDS is in the correct subnet group
- Verify database credentials in Secrets Manager
- Ensure RDS is not stopped (development environment)

### 4. Load Balancer Health Check Failures

**Symptom**: ALB shows unhealthy targets

**Diagnosis**:
```bash
# 1. Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>

# 2. Check ALB access logs (if enabled)
aws s3 ls s3://event-planner-dev-logs/alb/ --recursive

# 3. Test health check endpoint directly
curl -v http://<ECS_TASK_IP>:8081/actuator/health
```

**Common Causes**:
- Health check path incorrect (`/actuator/health`)
- Service not listening on expected port
- Health check timeout too short for Spring Boot startup
- Security group blocking health check traffic

---

## CI/CD Pipeline Issues

### 1. Maven Build Failures

**Symptom**: Java compilation errors in CI/CD pipeline

**Common Issues and Solutions**:

#### A. Java Version Mismatch
```yaml
# Ensure correct Java version is set
- name: Verify Java Environment
  run: |
    echo "Java version:"
    java --version
    echo "JAVA_HOME: $JAVA_HOME"
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    echo "Updated JAVA_HOME: $JAVA_HOME"
```

#### B. Maven Repository Issues
```yaml
# Clear and rebuild Maven cache
- name: Clear Maven Cache
  run: |
    rm -rf ~/.m2/repository
    mvn dependency:resolve -T 1C
```

#### C. Memory Issues
```yaml
# Increase Maven memory allocation
- name: Build with Increased Memory
  run: |
    export MAVEN_OPTS="-Xmx2048m -XX:MaxPermSize=512m"
    mvn clean package -DskipTests -T 1C --batch-mode
```

### 2. Docker Build Failures

**Symptom**: Docker image build fails in CI/CD

**Diagnosis**:
```bash
# Check Docker daemon status on runner
docker info

# Check available disk space
df -h

# Check Docker build context size
du -sh services/auth-service/
```

**Common Solutions**:
```dockerfile
# Optimize Dockerfile for faster builds
FROM openjdk:21-jre-slim

# Use multi-stage builds to reduce image size
FROM maven:3.9-openjdk-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:21-jre-slim
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### 3. ECR Push Failures

**Symptom**: Cannot push Docker image to ECR

**Diagnosis**:
```bash
# Check ECR login status
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <ECR_REGISTRY>

# Check ECR repository exists
aws ecr describe-repositories --repository-names event-planner-dev-auth-service

# Check image size (ECR has limits)
docker images | grep auth-service
```

**Solutions**:
```bash
# Create ECR repository if missing
aws ecr create-repository --repository-name event-planner-dev-auth-service

# Re-authenticate with ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <ECR_REGISTRY>

# Optimize image size
docker build --compress -t <IMAGE_NAME> .
```

### 4. Service Discovery Issues

**Symptom**: Services cannot communicate with each other

**Diagnosis**:
```bash
# Check Cloud Map service registration
aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=<NAMESPACE_ID>

# Check service instances
aws servicediscovery list-instances \
  --service-id <SERVICE_ID>

# Test DNS resolution from within ECS task
nslookup auth-service.eventplanner.local
```

**Solutions**:
- Verify service discovery configuration in ECS service
- Check if services are registering with correct health status
- Ensure DNS resolution is working in VPC

---

## Operational Runbooks

### 1. Service Restart Runbook

**When to Use**: Service is unresponsive but infrastructure is healthy

**Steps**:
```bash
#!/bin/bash
# Restart ECS service

SERVICE_NAME="auth-service"
CLUSTER_NAME="event-planner-dev-cluster"

echo "🔄 Restarting $SERVICE_NAME..."

# 1. Force new deployment
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --force-new-deployment

# 2. Wait for service to stabilize
echo "⏳ Waiting for service to stabilize..."
aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME"

# 3. Verify service health
echo "🔍 Checking service health..."
curl -f https://api.sankofagrid.com/auth/actuator/health

echo "✅ Service restart completed"
```

### 2. Database Failover Runbook (Production)

**When to Use**: Primary database is unresponsive

**Steps**:
```bash
#!/bin/bash
# Database failover procedure

DB_IDENTIFIER="event-planner-prod-auth-db"
REPLICA_IDENTIFIER="event-planner-prod-auth-db-replica-1"

echo "🚨 Initiating database failover..."

# 1. Promote read replica to primary
aws rds promote-read-replica \
  --db-instance-identifier "$REPLICA_IDENTIFIER"

# 2. Wait for promotion to complete
aws rds wait db-instance-available \
  --db-instance-identifier "$REPLICA_IDENTIFIER"

# 3. Update application configuration
# (This would typically be automated via service discovery)

# 4. Verify application connectivity
echo "🔍 Testing database connectivity..."
# Application-specific health checks

echo "✅ Database failover completed"
```

### 3. Scale-Up Runbook

**When to Use**: High load detected, need to scale services

**Steps**:
```bash
#!/bin/bash
# Scale up services during high load

CLUSTER_NAME="event-planner-prod-cluster"
SERVICES=("auth-service" "event-service" "notification-service")

echo "📈 Scaling up services for high load..."

for service in "${SERVICES[@]}"; do
  echo "Scaling $service to 4 tasks..."
  
  aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$service" \
    --desired-count 4
done

# Wait for all services to scale
for service in "${SERVICES[@]}"; do
  echo "⏳ Waiting for $service to stabilize..."
  aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$service"
done

echo "✅ Scale-up completed"
```

### 4. Emergency Rollback Runbook

**When to Use**: Critical issue with latest deployment

**Steps**:
```bash
#!/bin/bash
# Emergency rollback procedure

SERVICE_NAME="auth-service"
CLUSTER_NAME="event-planner-prod-cluster"

echo "🔄 Initiating emergency rollback for $SERVICE_NAME..."

# 1. Get current deployments
DEPLOYMENTS=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].deployments[*].{Status:status,TaskDef:taskDefinition,CreatedAt:createdAt}' \
  --output table)

echo "Current deployments:"
echo "$DEPLOYMENTS"

# 2. Get previous stable task definition
PREVIOUS_TASK_DEF=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].deployments[?status==`PRIMARY`].taskDefinition' \
  --output text | head -1)

if [ -z "$PREVIOUS_TASK_DEF" ]; then
  echo "❌ No previous task definition found"
  exit 1
fi

echo "📋 Rolling back to: $PREVIOUS_TASK_DEF"

# 3. Update service to use previous task definition
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --task-definition "$PREVIOUS_TASK_DEF"

# 4. Wait for rollback to complete
echo "⏳ Waiting for rollback to complete..."
aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME"

# 5. Verify service health
echo "🔍 Verifying service health..."
curl -f https://api.sankofagrid.com/auth/actuator/health

echo "✅ Emergency rollback completed"
```

---

## Monitoring and Alerting Runbooks

### 1. High CPU Alert Response

**Alert**: ECS service CPU > 80%

**Response Steps**:
```bash
#!/bin/bash
# High CPU alert response

SERVICE_NAME="$1"
CLUSTER_NAME="event-planner-dev-cluster"

echo "🚨 High CPU alert for $SERVICE_NAME"

# 1. Check current metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value="$SERVICE_NAME" Name=ClusterName,Value="$CLUSTER_NAME" \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# 2. Check if auto-scaling is working
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids "service/$CLUSTER_NAME/$SERVICE_NAME"

# 3. Manual scale if needed
CURRENT_COUNT=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].desiredCount')

if [ "$CURRENT_COUNT" -lt 3 ]; then
  echo "📈 Manually scaling up to 3 tasks..."
  aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --desired-count 3
fi

echo "✅ High CPU alert response completed"
```

### 2. Database Connection Alert Response

**Alert**: Database connection failures detected

**Response Steps**:
```bash
#!/bin/bash
# Database connection alert response

DB_IDENTIFIER="event-planner-dev-auth-db"

echo "🚨 Database connection alert"

# 1. Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query 'DBInstances[0].{Status:DBInstanceStatus,MultiAZ:MultiAZ,Engine:Engine}'

# 2. Check recent events
aws rds describe-events \
  --source-identifier "$DB_IDENTIFIER" \
  --source-type db-instance \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)

# 3. Check connection count
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value="$DB_IDENTIFIER" \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# 4. Restart database if needed (development only)
if [[ "$DB_IDENTIFIER" == *"dev"* ]]; then
  echo "🔄 Restarting development database..."
  aws rds reboot-db-instance --db-instance-identifier "$DB_IDENTIFIER"
fi

echo "✅ Database connection alert response completed"
```

---

## Security Incident Response

### 1. Suspicious Activity Detection

**Alert**: Unusual API access patterns detected

**Response Steps**:
```bash
#!/bin/bash
# Security incident response

echo "🚨 Security incident detected"

# 1. Check ALB access logs for suspicious patterns
aws s3 cp s3://event-planner-dev-logs/alb/ . --recursive --exclude "*" --include "*$(date +%Y/%m/%d)*"

# 2. Analyze recent CloudTrail events
aws logs filter-log-events \
  --log-group-name CloudTrail/event-planner \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern '{ $.errorCode = "*" || $.errorMessage = "*" }'

# 3. Check for failed authentication attempts
aws logs filter-log-events \
  --log-group-name /ecs/event-planner/dev/auth-service \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern '"authentication failed"'

# 4. Temporarily block suspicious IPs (if WAF is enabled)
# aws wafv2 update-ip-set --scope CLOUDFRONT --id <IP_SET_ID> --addresses <SUSPICIOUS_IP>

echo "✅ Security incident response completed"
```

### 2. Data Breach Response

**Alert**: Potential data breach detected

**Immediate Actions**:
1. **Isolate affected systems**
2. **Preserve evidence**
3. **Notify stakeholders**
4. **Begin forensic analysis**

```bash
#!/bin/bash
# Data breach response

echo "🚨 CRITICAL: Data breach response initiated"

# 1. Create forensic snapshots
aws rds create-db-snapshot \
  --db-instance-identifier event-planner-prod-auth-db \
  --db-snapshot-identifier "forensic-snapshot-$(date +%Y%m%d-%H%M%S)"

# 2. Enable detailed logging
aws rds modify-db-instance \
  --db-instance-identifier event-planner-prod-auth-db \
  --cloudwatch-logs-exports postgresql \
  --apply-immediately

# 3. Rotate all secrets immediately
aws secretsmanager rotate-secret \
  --secret-id event-planner/prod/auth-db/master-password \
  --force-rotate-immediately

# 4. Document incident
echo "Incident documented at: $(date)" >> security-incident-log.txt

echo "✅ Immediate breach response completed - Continue with full incident response plan"
```

---

## Performance Troubleshooting

### 1. Slow API Response Times

**Symptom**: API response times > 2 seconds

**Diagnosis**:
```bash
# 1. Check ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<ALB_NAME> \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# 2. Check database performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReadLatency \
  --dimensions Name=DBInstanceIdentifier,Value=event-planner-dev-auth-db \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# 3. Check application logs for slow queries
aws logs filter-log-events \
  --log-group-name /ecs/event-planner/dev/auth-service \
  --start-time $(date -d '30 minutes ago' +%s)000 \
  --filter-pattern '"slow query"'
```

### 2. Memory Issues

**Symptom**: ECS tasks being killed due to memory

**Solutions**:
```bash
# 1. Check memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=auth-service Name=ClusterName,Value=event-planner-dev-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# 2. Increase memory allocation in Terraform
# Update terraform/modules/ecs/main.tf:
# memory = var.environment == "dev" ? 1024 : 2048

# 3. Apply changes
cd terraform/environments/dev
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Disaster Recovery Procedures

### 1. Complete Environment Recovery

**Scenario**: Entire environment needs to be rebuilt

**Steps**:
```bash
#!/bin/bash
# Complete environment recovery

ENVIRONMENT="dev"
echo "🚨 Starting complete environment recovery for $ENVIRONMENT"

# 1. Restore infrastructure from Terraform
cd terraform/environments/$ENVIRONMENT
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Restore database from latest snapshot
LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
  --db-instance-identifier event-planner-$ENVIRONMENT-auth-db \
  --query 'DBSnapshots | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier' \
  --output text)

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier event-planner-$ENVIRONMENT-auth-db-restored \
  --db-snapshot-identifier "$LATEST_SNAPSHOT"

# 3. Deploy applications
gh workflow run backend-ci-cd.yml \
  --ref dev \
  -f environment=$ENVIRONMENT \
  -f services='["auth-service", "notification-service"]'

# 4. Verify recovery
curl -f https://api.sankofagrid.com/auth/actuator/health

echo "✅ Environment recovery completed"
```

---

## Contact Information

### Escalation Matrix

| Severity | Contact | Response Time |
|----------|---------|---------------|
| Critical | DevOps Team Lead | 15 minutes |
| High | DevOps Engineer | 1 hour |
| Medium | Development Team | 4 hours |
| Low | Ticket System | 24 hours |

### Key Contacts

- **DevOps Team Lead**: DevOps Team
- **AWS Account Admin**: [Admin Contact]
- **Security Team**: [Security Contact]
- **Database Admin**: [DBA Contact]

---

## Documentation Updates

This troubleshooting guide should be updated whenever:
- New issues are discovered and resolved
- Infrastructure changes are made
- New services are added
- Procedures are improved

**Last Updated**: October 30, 2025  
**Next Review**: November 30, 2025