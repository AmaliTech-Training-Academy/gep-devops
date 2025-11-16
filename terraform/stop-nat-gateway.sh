#!/bin/bash
# Stop NAT Gateway and Infrastructure
# This script dynamically finds resources using tags and naming conventions

set -e

AWS_PROFILE="gtp-cletus"
AWS_REGION="eu-west-1"
PROJECT="event-planner"
ENV="dev"

export AWS_PROFILE

echo "========================================="
echo "Stopping Event Planner Infrastructure"
echo "========================================="

# 1. Scale Down ECS Services
echo ""
echo "1️⃣  Scaling down ECS Services..."
CLUSTER="${PROJECT}-${ENV}-cluster"

for SERVICE in auth-service event-service notification-service; do
  # Check if service exists
  SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster $CLUSTER \
    --services $SERVICE \
    --region $AWS_REGION \
    --query 'services[0].serviceName' --output text 2>/dev/null)
  
  if [ "$SERVICE_EXISTS" != "None" ] && [ -n "$SERVICE_EXISTS" ]; then
    aws ecs update-service \
      --cluster $CLUSTER \
      --service $SERVICE \
      --desired-count 0 \
      --region $AWS_REGION > /dev/null
    echo "✅ $SERVICE scaled to 0"
  else
    echo "⚠️  $SERVICE not found"
  fi
done

# Wait for tasks to stop
echo "⏳ Waiting for tasks to stop (60 seconds)..."
sleep 60

# 2. Stop RDS Database
echo ""
echo "2️⃣  Stopping RDS Database..."
DB_INSTANCE="${PROJECT}-${ENV}-auth-db"
DB_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE \
  --region $AWS_REGION \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)

if [ "$DB_STATUS" == "available" ]; then
  aws rds stop-db-instance \
    --db-instance-identifier $DB_INSTANCE \
    --region $AWS_REGION > /dev/null
  echo "✅ Database stopping"
elif [ "$DB_STATUS" == "stopped" ]; then
  echo "✅ Database already stopped"
else
  echo "⚠️  Database status: $DB_STATUS (skipping)"
fi

# 3. Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT}-${ENV}-vpc" \
  --query 'Vpcs[0].VpcId' --output text)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
  echo "⚠️  VPC not found. Exiting."
  exit 0
fi
echo "   VPC ID: $VPC_ID"

# 4. Get NAT Gateway ID
echo ""
echo "3️⃣  Finding NAT Gateway..."
NAT_ID=$(aws ec2 describe-nat-gateways \
  --region $AWS_REGION \
  --filter "Name=state,Values=available,pending" "Name=vpc-id,Values=${VPC_ID}" \
  --query 'NatGateways[0].NatGatewayId' --output text)

if [ "$NAT_ID" == "None" ] || [ -z "$NAT_ID" ]; then
  echo "⚠️  No NAT Gateway found. Already deleted?"
  exit 0
fi

echo "   NAT Gateway: $NAT_ID"

# Get EIP allocation ID before deleting NAT Gateway
EIP_ALLOC=$(aws ec2 describe-nat-gateways \
  --region $AWS_REGION \
  --nat-gateway-ids $NAT_ID \
  --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' --output text)

# 5. Delete NAT Gateway
echo ""
echo "4️⃣  Deleting NAT Gateway..."
aws ec2 delete-nat-gateway \
  --nat-gateway-id $NAT_ID \
  --region $AWS_REGION > /dev/null
echo "✅ NAT Gateway deletion initiated"

# Wait for NAT Gateway to be deleted
echo "⏳ Waiting for NAT Gateway deletion (2-3 minutes)..."
aws ec2 wait nat-gateway-deleted \
  --nat-gateway-ids $NAT_ID \
  --region $AWS_REGION 2>/dev/null || sleep 120
echo "✅ NAT Gateway deleted"

# 6. Release EIP
echo ""
echo "5️⃣  Releasing Elastic IP..."
if [ "$EIP_ALLOC" != "None" ] && [ -n "$EIP_ALLOC" ]; then
  aws ec2 release-address \
    --allocation-id $EIP_ALLOC \
    --region $AWS_REGION > /dev/null 2>&1
  echo "✅ EIP released: $EIP_ALLOC"
else
  echo "⚠️  No EIP found to release"
fi

# 7. Remove routes from route tables
echo ""
echo "6️⃣  Cleaning up route tables..."
ROUTE_TABLES=$(aws ec2 describe-route-tables \
  --region $AWS_REGION \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" \
  --query 'RouteTables[*].RouteTableId' --output text)

if [ -n "$ROUTE_TABLES" ]; then
  for RT_ID in $ROUTE_TABLES; do
    echo "   Removing route from: $RT_ID"
    aws ec2 delete-route \
      --route-table-id $RT_ID \
      --destination-cidr-block 0.0.0.0/0 \
      --region $AWS_REGION 2>/dev/null || echo "   (route already removed)"
  done
  echo "✅ Route tables cleaned"
fi

echo ""
echo "========================================="
echo "✅ Infrastructure Stopped Successfully!"
echo "========================================="
echo "Database: $DB_INSTANCE (stopped)"
echo "NAT Gateway: Deleted"
echo "EIP: Released"
echo "ECS Services: Scaled to 0"
echo ""
echo "💰 Estimated savings: ~\$1.08/night + \$0.12/day for EIP"
echo ""
echo "▶️  Run start-nat-gateway.sh when you resume work"
echo ""
