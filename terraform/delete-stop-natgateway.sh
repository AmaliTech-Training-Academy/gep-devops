#!/bin/bash
# scripts/utilities/stop-nat-gateway.sh

# Set your AWS profile name here
AWS_PROFILE="${AWS_PROFILE:-gtp-cletus}"
AWS_REGION="${AWS_REGION:-eu-west-1}"

echo "Using AWS Profile: $AWS_PROFILE"
echo "Using AWS Region: $AWS_REGION"
echo "Stopping NAT Gateway to save costs..."

# 1. Scale down ECS services first
echo "Scaling down ECS services..."
aws ecs update-service --cluster event-planner-dev-cluster \
  --service auth-service --desired-count 0 \
  --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
echo "✓ auth-service scaled to 0"

aws ecs update-service --cluster event-planner-dev-cluster \
  --service event-service --desired-count 0 \
  --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
echo "✓ event-service scaled to 0"

aws ecs update-service --cluster event-planner-dev-cluster \
  --service notification-service --desired-count 0 \
  --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
echo "✓ notification-service scaled to 0"

# Wait for tasks to stop
echo "Waiting for tasks to stop..."
sleep 60

# 2. Stop RDS database
echo "Checking RDS database status..."
DB_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier event-planner-dev-auth-db \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)

if [ "$DB_STATUS" == "available" ]; then
  echo "Stopping RDS database (authdb)..."
  aws rds stop-db-instance \
    --db-instance-identifier event-planner-dev-auth-db \
    --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  echo "✓ Auth database stopped"
elif [ "$DB_STATUS" == "stopped" ]; then
  echo "✓ Auth database already stopped"
else
  echo "⚠ Auth database status: $DB_STATUS (skipping)"
fi

# 3. Get NAT Gateway ID
NAT_ID=$(aws ec2 describe-nat-gateways --profile $AWS_PROFILE --region $AWS_REGION \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[0].NatGatewayId' --output text)

if [ "$NAT_ID" == "None" ] || [ -z "$NAT_ID" ]; then
  echo "No NAT Gateway found. Already deleted?"
  exit 0
fi

echo "Deleting NAT Gateway: $NAT_ID"

# 4. Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID \
  --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
echo "✓ NAT Gateway deletion initiated"

# 5. Wait for NAT Gateway to be deleted
echo "Waiting for NAT Gateway deletion (this takes ~2 minutes)..."
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID \
  --profile $AWS_PROFILE --region $AWS_REGION 2>/dev/null || sleep 120

# 6. Get and release EIP
EIP_ID=$(aws ec2 describe-addresses --profile $AWS_PROFILE --region $AWS_REGION \
  --filters "Name=domain,Values=vpc" \
  --query 'Addresses[?AssociationId==`null`].AllocationId' --output text | head -1)

if [ ! -z "$EIP_ID" ] && [ "$EIP_ID" != "None" ]; then
  echo "Releasing EIP: $EIP_ID"
  aws ec2 release-address --allocation-id $EIP_ID \
    --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  echo "✓ EIP released"
else
  echo "No unattached EIP found to release"
fi

echo "✓ NAT Gateway stopped. Estimated savings: \$1.08 for tonight + \$0.12 for EIP"
echo "✓ Run create-start-natgateway.sh when you resume work"
