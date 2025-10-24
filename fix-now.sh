#!/bin/bash
set -e

echo "🔧 Fixing ECS Task Failures..."
echo ""

cd terraform/environments/dev

echo "Step 1: Applying Terraform changes (updated health checks)..."
terraform apply -auto-approve

echo ""
echo "Step 2: Forcing new deployment for both services..."
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

echo ""
echo "✅ Deployment triggered!"
echo ""
echo "Monitor with:"
echo "  watch -n 5 'aws ecs describe-services --cluster event-planner-dev-cluster --services auth-service event-service --region eu-west-1 --query \"services[*].{Service:serviceName,Running:runningCount,Pending:pendingCount}\" --output table'"
echo ""
echo "View logs:"
echo "  aws logs tail /ecs/event-planner/dev/auth-service --follow --region eu-west-1"
