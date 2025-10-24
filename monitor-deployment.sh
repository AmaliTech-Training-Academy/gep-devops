#!/bin/bash

CLUSTER="event-planner-dev-cluster"
REGION="eu-west-1"

echo "=========================================="
echo "Monitoring ECS Deployment"
echo "=========================================="
echo ""

echo "📊 Current Service Status:"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services auth-service event-service \
  --region $REGION \
  --query 'services[*].{Service:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status}' \
  --output table

echo ""
echo "📝 Recent Events (auth-service):"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services auth-service \
  --region $REGION \
  --query 'services[0].events[:3].[createdAt,message]' \
  --output table

echo ""
echo "📝 Recent Events (event-service):"
aws ecs describe-services \
  --cluster $CLUSTER \
  --services event-service \
  --region $REGION \
  --query 'services[0].events[:3].[createdAt,message]' \
  --output table

echo ""
echo "🎯 Target Group Health:"
echo ""

# Auth service target group
AUTH_TG=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[?contains(TargetGroupName, 'auth')].TargetGroupArn" \
  --output text 2>/dev/null)

if [ -n "$AUTH_TG" ]; then
  echo "Auth Service Targets:"
  aws elbv2 describe-target-health \
    --target-group-arn $AUTH_TG \
    --region $REGION \
    --output table 2>/dev/null || echo "No targets registered yet"
fi

echo ""

# Event service target group
EVENT_TG=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[?contains(TargetGroupName, 'event')].TargetGroupArn" \
  --output text 2>/dev/null)

if [ -n "$EVENT_TG" ]; then
  echo "Event Service Targets:"
  aws elbv2 describe-target-health \
    --target-group-arn $EVENT_TG \
    --region $REGION \
    --output table 2>/dev/null || echo "No targets registered yet"
fi

echo ""
echo "=========================================="
echo "Commands to continue monitoring:"
echo "=========================================="
echo ""
echo "Watch status (auto-refresh every 5 seconds):"
echo "  watch -n 5 'aws ecs describe-services --cluster $CLUSTER --services auth-service event-service --region $REGION --query \"services[*].{Service:serviceName,Running:runningCount,Pending:pendingCount}\" --output table'"
echo ""
echo "Stream auth-service logs:"
echo "  aws logs tail /ecs/event-planner/dev/auth-service --follow --region $REGION"
echo ""
echo "Stream event-service logs:"
echo "  aws logs tail /ecs/event-planner/dev/event-service --follow --region $REGION"
echo ""
echo "Check if services are healthy (wait 2-3 minutes):"
echo "  curl -v http://\$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[0].DNSName' --output text)/api/v1/auth/actuator/health"
echo ""
