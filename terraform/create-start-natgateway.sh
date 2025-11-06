#!/bin/bash
# scripts/utilities/start-nat-gateway.sh

# 1. Allocate new EIP
echo "Allocating new Elastic IP..."
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc \
  --profile gtp-cletus --region eu-west-1 \
  --query 'AllocationId' --output text)
echo "✓ EIP allocated: $EIP_ALLOC"

# 2. Get subnet ID
echo "Finding public subnet..."
SUBNET_ID=$(aws ec2 describe-subnets --profile gtp-cletus --region eu-west-1 \
  --filters "Name=tag:Name,Values=event-planner-dev-public-eu-west-1a" \
  --query 'Subnets[0].SubnetId' --output text)
echo "✓ Subnet found: $SUBNET_ID"

# 3. Create NAT Gateway
echo "Creating NAT Gateway..."
NAT_ID=$(aws ec2 create-nat-gateway --subnet-id $SUBNET_ID \
  --allocation-id $EIP_ALLOC \
  --profile gtp-cletus --region eu-west-1 \
  --query 'NatGateway.NatGatewayId' --output text)
echo "✓ NAT Gateway created: $NAT_ID"

# 4. Wait for NAT Gateway to be available
echo "Waiting for NAT Gateway to become available (2-3 minutes)..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID \
  --profile gtp-cletus --region eu-west-1
echo "✓ NAT Gateway is now available"

# 5. Update route tables - CRITICAL STEP!
ROUTE_TABLES=$(aws ec2 describe-route-tables --profile gtp-cletus --region eu-west-1 \
  --filters "Name=tag:Name,Values=*private-app-rt*" \
  --query 'RouteTables[*].RouteTableId' --output text)

for RT_ID in $ROUTE_TABLES; do
  echo "Updating route table: $RT_ID"
  aws ec2 replace-route --route-table-id $RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_ID \
    --profile gtp-cletus --region eu-west-1
done

echo "Route tables updated with new NAT Gateway"

# 6. Start ECS services
echo "Starting ECS services..."
aws ecs update-service --cluster event-planner-dev-cluster \
  --service notification-service --desired-count 1 \
  --profile gtp-cletus --region eu-west-1 > /dev/null 2>&1

echo "✓ NAT Gateway ready. Services starting..."
echo "✓ Infrastructure is now operational"
