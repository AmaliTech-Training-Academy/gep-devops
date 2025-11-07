#!/bin/bash
# Force redeploy notification service with latest ECR image

set -e

PROFILE="gtp-cletus"
REGION="eu-west-1"
CLUSTER="event-planner-dev-cluster"
SERVICE="notification-service"
TASK_FAMILY="event-planner-dev-notification-service"

echo "🔄 Force redeploying notification service with latest image..."

# 1. Get latest image from ECR
echo "📦 Fetching latest ECR image..."
LATEST_IMAGE=$(aws ecr describe-images \
  --repository-name event-planner/notification-service \
  --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]' \
  --output text \
  --profile $PROFILE --region $REGION)

if [ "$LATEST_IMAGE" == "None" ] || [ -z "$LATEST_IMAGE" ]; then
  echo "❌ No images found in ECR"
  exit 1
fi

ECR_IMAGE=$(aws ecr describe-repositories \
  --repository-names event-planner/notification-service \
  --query 'repositories[0].repositoryUri' \
  --output text \
  --profile $PROFILE --region $REGION)

FULL_IMAGE="$ECR_IMAGE:$LATEST_IMAGE"
echo "✓ Latest image: $FULL_IMAGE"

# 2. Stop all running tasks (clears cache)
echo "🛑 Stopping all running tasks..."
TASK_ARNS=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --query 'taskArns[]' \
  --output text \
  --profile $PROFILE --region $REGION)

if [ ! -z "$TASK_ARNS" ]; then
  for TASK_ARN in $TASK_ARNS; do
    aws ecs stop-task \
      --cluster $CLUSTER \
      --task $TASK_ARN \
      --profile $PROFILE --region $REGION > /dev/null 2>&1
  done
  echo "✓ Tasks stopped"
  sleep 10
fi

# 3. Get current task definition
echo "📋 Creating new task definition..."
aws ecs describe-task-definition \
  --task-definition $TASK_FAMILY \
  --profile $PROFILE --region $REGION \
  --query 'taskDefinition' > /tmp/task-def.json

# 4. Update image in task definition
jq --arg img "$FULL_IMAGE" \
  '.containerDefinitions[0].image = $img | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' \
  /tmp/task-def.json > /tmp/new-task-def.json

# 5. Register new task definition
echo "📝 Registering new task definition..."
NEW_REVISION=$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/new-task-def.json \
  --profile $PROFILE --region $REGION \
  --query 'taskDefinition.revision' \
  --output text)

echo "✓ New revision: $NEW_REVISION"

# 6. Force new deployment with new task definition
echo "🚀 Forcing new deployment..."
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition "$TASK_FAMILY:$NEW_REVISION" \
  --force-new-deployment \
  --profile $PROFILE --region $REGION > /dev/null

echo "✓ Deployment initiated"

# 7. Wait for deployment to stabilize
echo "⏳ Waiting for service to stabilize (this may take 2-3 minutes)..."
aws ecs wait services-stable \
  --cluster $CLUSTER \
  --services $SERVICE \
  --profile $PROFILE --region $REGION

echo ""
echo "✅ Notification service redeployed successfully!"
echo "📊 Image: $FULL_IMAGE"
echo "📊 Revision: $NEW_REVISION"

# Cleanup
rm -f /tmp/task-def.json /tmp/new-task-def.json
