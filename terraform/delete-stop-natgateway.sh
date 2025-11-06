#!/bin/bash
# scripts/utilities/stop-nat-gateway.sh

echo "Stopping NAT Gateway to save costs..."

# 1. Scale down ECS services first
echo "Scaling down ECS services..."
aws ecs update-service --cluster event-planner-dev-cluster \
  --service notification-service --desired-count 0 \
  --profile gtp-cletus --region eu-west-1 > /dev/null 2>&1
echo "✓ Service scaled to 0"

# Wait for tasks to stop
echo "Waiting for tasks to stop..."
sleep 60

# 2. Get NAT Gateway ID
NAT_ID=$(aws ec2 describe-nat-gateways --profile gtp-cletus --region eu-west-1 \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[0].NatGatewayId' --output text)

if [ "$NAT_ID" == "None" ] || [ -z "$NAT_ID" ]; then
  echo "No NAT Gateway found. Already deleted?"
  exit 0
fi

echo "Deleting NAT Gateway: $NAT_ID"

# 3. Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID \
  --profile gtp-cletus --region eu-west-1 > /dev/null 2>&1
echo "✓ NAT Gateway deletion initiated"

# 4. Wait for NAT Gateway to be deleted
echo "Waiting for NAT Gateway deletion (this takes ~2 minutes)..."
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID \
  --profile gtp-cletus --region eu-west-1 2>/dev/null || sleep 120

# 5. Get and release EIP
EIP_ID=$(aws ec2 describe-addresses --profile gtp-cletus --region eu-west-1 \
  --filters "Name=domain,Values=vpc" \
  --query 'Addresses[?AssociationId==`null`].AllocationId' --output text | head -1)

if [ ! -z "$EIP_ID" ] && [ "$EIP_ID" != "None" ]; then
  echo "Releasing EIP: $EIP_ID"
  aws ec2 release-address --allocation-id $EIP_ID \
    --profile gtp-cletus --region eu-west-1 > /dev/null 2>&1
  echo "✓ EIP released"
else
  echo "No unattached EIP found to release"
fi

echo "✓ NAT Gateway stopped. Estimated savings: \$1.08 for tonight + \$0.12 for EIP"
echo "✓ Run create-start-natgateway.sh when you resume work"
