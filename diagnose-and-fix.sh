#!/bin/bash
# ==============================================================================
# Diagnose and Fix ECS Task Failures
# ==============================================================================

set -e

CLUSTER="event-planner-dev-cluster"
REGION="eu-west-1"

echo "=========================================="
echo "ECS Task Failure Diagnosis"
echo "=========================================="
echo ""

# Check auth-service
echo "📋 AUTH-SERVICE STATUS:"
echo "----------------------------------------"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services auth-service \
  --region $REGION \
  --query 'services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount,Events:events[:3]}' \
  --output table

echo ""
echo "🔍 AUTH-SERVICE RECENT EVENTS:"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services auth-service \
  --region $REGION \
  --query 'services[0].events[:5].[createdAt,message]' \
  --output table

echo ""
echo "📋 EVENT-SERVICE STATUS:"
echo "----------------------------------------"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services event-service \
  --region $REGION \
  --query 'services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
  --output table

echo ""
echo "🔍 EVENT-SERVICE RECENT EVENTS:"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services event-service \
  --region $REGION \
  --query 'services[0].events[:5].[createdAt,message]' \
  --output table

echo ""
echo "=========================================="
echo "CHECKING FOR STOPPED TASKS (FAILURES)"
echo "=========================================="
echo ""

# Check stopped auth-service tasks
echo "🛑 AUTH-SERVICE STOPPED TASKS:"
STOPPED_AUTH=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name auth-service \
  --desired-status STOPPED \
  --region $REGION \
  --max-items 1 \
  --query 'taskArns[0]' \
  --output text)

if [ "$STOPPED_AUTH" != "None" ] && [ -n "$STOPPED_AUTH" ]; then
  aws ecs describe-tasks \
    --cluster $CLUSTER \
    --tasks $STOPPED_AUTH \
    --region $REGION \
    --query 'tasks[0].{StoppedReason:stoppedReason,StoppedAt:stoppedAt,Container:containers[0].{Name:name,ExitCode:exitCode,Reason:reason}}' \
    --output table
else
  echo "No stopped tasks found"
fi

echo ""
echo "🛑 EVENT-SERVICE STOPPED TASKS:"
STOPPED_EVENT=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name event-service \
  --desired-status STOPPED \
  --region $REGION \
  --max-items 1 \
  --query 'taskArns[0]' \
  --output text)

if [ "$STOPPED_EVENT" != "None" ] && [ -n "$STOPPED_EVENT" ]; then
  aws ecs describe-tasks \
    --cluster $CLUSTER \
    --tasks $STOPPED_EVENT \
    --region $REGION \
    --query 'tasks[0].{StoppedReason:stoppedReason,StoppedAt:stoppedAt,Container:containers[0].{Name:name,ExitCode:exitCode,Reason:reason}}' \
    --output table
else
  echo "No stopped tasks found"
fi

echo ""
echo "=========================================="
echo "CHECKING CLOUDWATCH LOGS"
echo "=========================================="
echo ""

echo "📝 AUTH-SERVICE LOGS (last 20 lines):"
aws logs tail /ecs/event-planner/dev/auth-service \
  --region $REGION \
  --since 1h \
  --format short 2>/dev/null | tail -20 || echo "No logs found or log group doesn't exist"

echo ""
echo "📝 EVENT-SERVICE LOGS (last 20 lines):"
aws logs tail /ecs/event-planner/dev/event-service \
  --region $REGION \
  --since 1h \
  --format short 2>/dev/null | tail -20 || echo "No logs found or log group doesn't exist"

echo ""
echo "=========================================="
echo "RECOMMENDED ACTIONS"
echo "=========================================="
echo ""
echo "Based on the errors above, common fixes:"
echo ""
echo "1. If 'CannotPullContainerError':"
echo "   → Docker image doesn't exist in ECR"
echo "   → Run: aws ecr describe-images --repository-name event-planner-dev-auth-service --region eu-west-1"
echo ""
echo "2. If 'ResourceInitializationError':"
echo "   → VPC endpoints issue or secrets access problem"
echo "   → Check VPC endpoints are active"
echo "   → Verify secrets exist in Secrets Manager"
echo ""
echo "3. If health check failures:"
echo "   → Application is crashing on startup"
echo "   → Check logs above for errors"
echo ""
echo "4. To force new deployment with updated task definition:"
echo "   → cd terraform/environments/dev"
echo "   → terraform apply"
echo ""
echo "5. To manually force deployment:"
echo "   → aws ecs update-service --cluster $CLUSTER --service auth-service --force-new-deployment --region $REGION"
echo "   → aws ecs update-service --cluster $CLUSTER --service event-service --force-new-deployment --region $REGION"
echo ""
