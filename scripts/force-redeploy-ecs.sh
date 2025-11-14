#!/bin/bash
# Force redeploy all ECS services with latest images and clear caches

set -e

CLUSTER="event-planner-dev-cluster"
REGION="eu-west-1"
AWS_PROFILE="${AWS_PROFILE:-Cletus1}"

export AWS_PROFILE

echo "🔄 Force redeploying all ECS services with latest images..."
echo "Cluster: $CLUSTER"
echo "Region: $REGION"
echo ""

# Services to redeploy
SERVICES=("auth-service" "event-service" "notification-service")

for SERVICE in "${SERVICES[@]}"; do
    echo "📦 Redeploying: $SERVICE"
    
    aws ecs update-service \
        --cluster $CLUSTER \
        --service $SERVICE \
        --force-new-deployment \
        --region $REGION \
        --output json > /dev/null 2>&1 && \
        echo "✅ $SERVICE redeployment initiated" || \
        echo "⚠️  $SERVICE not found or error occurred"
done

echo ""
echo "🧹 Redis Cache Flush Instructions:"
echo "   Redis endpoint: event-planner-dev-redis.xxxxxx.0001.euw1.cache.amazonaws.com:6379"
echo "   To flush cache, run from within VPC (ECS task or bastion):"
echo "   redis-cli -h <redis-endpoint> -p 6379 FLUSHALL"
echo ""
echo "📊 Monitor deployment:"
echo "   aws ecs describe-services --cluster $CLUSTER --services ${SERVICES[*]} --region $REGION"
echo ""
echo "✅ Done!"
