#!/bin/bash
# ECS Auth Service Quick Diagnostic Script
# Run this to gather all diagnostic information

set -e

REGION="eu-west-1"
CLUSTER="event-planner-dev-cluster"
SERVICE="auth-service"
LOG_GROUP="/ecs/event-planner/dev/auth-service"

echo "======================================"
echo "ECS Auth Service Diagnostic Report"
echo "======================================"
echo "Timestamp: $(date)"
echo ""

# 1. Service Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. SERVICE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount,Deployments:deployments[0].status}' \
  --output table

# 2. Most Recent Failed Task
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. MOST RECENT FAILED TASK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
STOPPED_TASK=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --desired-status STOPPED \
  --region $REGION \
  --max-items 1 \
  --query 'taskArns[0]' \
  --output text)

if [ "$STOPPED_TASK" != "None" ] && [ ! -z "$STOPPED_TASK" ]; then
  echo "Task ARN: $STOPPED_TASK"
  echo ""
  aws ecs describe-tasks \
    --cluster $CLUSTER \
    --tasks $STOPPED_TASK \
    --region $REGION \
    --query 'tasks[0].{StoppedReason:stoppedReason,ExitCode:containers[0].exitCode,Status:containers[0].lastStatus,StoppedAt:stoppedAt}' \
    --output table
else
  echo "No stopped tasks found"
fi

# 3. CloudWatch Logs - Last 50 lines
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. RECENT CLOUDWATCH LOGS (Last 50 lines)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Fetching logs from last 2 hours..."
echo ""

aws logs tail $LOG_GROUP \
  --region $REGION \
  --since 2h \
  --format short 2>/dev/null | tail -50 || echo "No logs found or error accessing logs"

# 4. Environment Variables
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. ENVIRONMENT VARIABLES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --region $REGION \
  --query 'taskDefinition.containerDefinitions[0].environment' \
  --output table

# 5. Secrets Configuration
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. SECRETS CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --region $REGION \
  --query 'taskDefinition.containerDefinitions[0].secrets' \
  --output table 2>/dev/null || echo "No secrets configured"

# 6. Network Configuration
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. NETWORK CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION \
  --query 'services[0].networkConfiguration.awsvpcConfiguration.{Subnets:subnets,SecurityGroups:securityGroups,AssignPublicIp:assignPublicIp}' \
  --output table

# 7. Health Check Configuration
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. HEALTH CHECK CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TG_ARN=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[?contains(TargetGroupName, 'auth')].TargetGroupArn" \
  --output text | head -1)

if [ ! -z "$TG_ARN" ]; then
  aws elbv2 describe-target-groups \
    --region $REGION \
    --target-group-arns $TG_ARN \
    --query 'TargetGroups[0].{Path:HealthCheckPath,Interval:HealthCheckIntervalSeconds,Timeout:HealthCheckTimeoutSeconds,HealthyThreshold:HealthyThresholdCount,UnhealthyThreshold:UnhealthyThresholdCount}' \
    --output table
  
  echo ""
  echo "Target Health Status:"
  aws elbv2 describe-target-health \
    --region $REGION \
    --target-group-arn $TG_ARN \
    --output table 2>/dev/null || echo "No targets registered"
else
  echo "Target group not found"
fi

# 8. Check for common issues
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. COMMON ISSUES CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if SQS_ENDPOINT is set (should not be in production)
SQS_ENDPOINT=$(aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --region $REGION \
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`SQS_ENDPOINT`].value' \
  --output text)

if [ ! -z "$SQS_ENDPOINT" ] && [ "$SQS_ENDPOINT" != "None" ]; then
  echo "⚠️  WARNING: SQS_ENDPOINT is set to: $SQS_ENDPOINT"
  echo "   This should be removed for AWS deployment (only needed for LocalStack)"
fi

# Check required environment variables
echo ""
echo "Checking required environment variables:"
REQUIRED_VARS=("ACTIVE_PROFILE" "AWS_REGION" "REDIS_HOST" "REDIS_PORT")
for var in "${REQUIRED_VARS[@]}"; do
  VALUE=$(aws ecs describe-task-definition \
    --task-definition event-planner-dev-auth-service \
    --region $REGION \
    --query "taskDefinition.containerDefinitions[0].environment[?name=='$var'].value" \
    --output text)
  if [ -z "$VALUE" ] || [ "$VALUE" == "None" ]; then
    echo "❌ Missing: $var"
  else
    echo "✓ Found: $var = $VALUE"
  fi
done

# Check required secrets
echo ""
echo "Checking required secrets:"
REQUIRED_SECRETS=("AUTH_SERVICE_DB_URL" "AUTH_SERVICE_DB_USER" "AUTH_SERVICE_DB_PASSWORD" "JWT_SECRET")
for secret in "${REQUIRED_SECRETS[@]}"; do
  VALUE=$(aws ecs describe-task-definition \
    --task-definition event-planner-dev-auth-service \
    --region $REGION \
    --query "taskDefinition.containerDefinitions[0].secrets[?name=='$secret'].valueFrom" \
    --output text)
  if [ -z "$VALUE" ] || [ "$VALUE" == "None" ]; then
    echo "❌ Missing: $secret"
  else
    echo "✓ Found: $secret (from Secrets Manager)"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. RECOMMENDATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Based on the diagnostics above:"
echo ""
echo "1. Check CloudWatch Logs (section 3) for the actual error message"
echo "2. Ensure all required environment variables and secrets are set"
echo "3. If database connection errors, check:"
echo "   - Security group rules allow ECS -> RDS/DocumentDB"
echo "   - Database endpoints are correct"
echo "   - Credentials in Secrets Manager are valid"
echo "4. If health check failures, verify:"
echo "   - Your Spring Boot app exposes /actuator/health endpoint"
echo "   - Health check grace period is at least 300 seconds"
echo "5. Remove SQS_ENDPOINT if present (only for LocalStack)"
echo ""
echo "Run: cat ~/ecs_troubleshooting_guide.md for detailed fixes"
echo ""
echo "======================================"
echo "End of Diagnostic Report"
echo "======================================"