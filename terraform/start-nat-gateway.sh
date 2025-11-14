#!/bin/bash
# Start NAT Gateway and Infrastructure
# This script dynamically finds resources using tags and naming conventions

set -e

AWS_PROFILE="gtp-cletus"
AWS_REGION="eu-west-1"
PROJECT="event-planner"
ENV="dev"

export AWS_PROFILE

echo "========================================="
echo "Starting Event Planner Infrastructure"
echo "========================================="

# 1. Start RDS Database
echo ""
echo "1️⃣  Starting RDS Database..."
DB_INSTANCE="${PROJECT}-${ENV}-auth-db"
DB_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE \
  --region $AWS_REGION \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)

if [ "$DB_STATUS" == "stopped" ]; then
  aws rds start-db-instance \
    --db-instance-identifier $DB_INSTANCE \
    --region $AWS_REGION > /dev/null
  echo "✅ Database starting (takes 2-3 minutes)"
elif [ "$DB_STATUS" == "available" ]; then
  echo "✅ Database already running"
else
  echo "⚠️  Database status: $DB_STATUS"
fi

# 2. Create NAT Gateway
echo ""
echo "2️⃣  Creating NAT Gateway..."

# Check if NAT Gateway already exists
EXISTING_NAT=$(aws ec2 describe-nat-gateways \
  --region $AWS_REGION \
  --filter "Name=state,Values=available,pending" "Name=tag:Project,Values=${PROJECT}" "Name=tag:Environment,Values=${ENV}" \
  --query 'NatGateways[0].NatGatewayId' --output text)

if [ "$EXISTING_NAT" != "None" ] && [ -n "$EXISTING_NAT" ]; then
  echo "✅ NAT Gateway already exists: $EXISTING_NAT"
  NAT_ID=$EXISTING_NAT
else
  # Get VPC ID
  VPC_ID=$(aws ec2 describe-vpcs \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=${PROJECT}-${ENV}-vpc" \
    --query 'Vpcs[0].VpcId' --output text)
  
  if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "❌ VPC not found. Please check your infrastructure."
    exit 1
  fi
  echo "   VPC ID: $VPC_ID"

  # Get first public subnet
  PUBLIC_SUBNET=$(aws ec2 describe-subnets \
    --region $AWS_REGION \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Tier,Values=Public" \
    --query 'Subnets[0].SubnetId' --output text)
  
  if [ "$PUBLIC_SUBNET" == "None" ] || [ -z "$PUBLIC_SUBNET" ]; then
    echo "❌ Public subnet not found."
    exit 1
  fi
  echo "   Public Subnet: $PUBLIC_SUBNET"

  # Allocate EIP
  EIP_ALLOC=$(aws ec2 allocate-address \
    --domain vpc \
    --region $AWS_REGION \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${PROJECT}-${ENV}-nat-eip-1},{Key=Project,Value=${PROJECT}},{Key=Environment,Value=${ENV}},{Key=ManagedBy,Value=Terraform}]" \
    --query 'AllocationId' --output text)
  echo "✅ EIP allocated: $EIP_ALLOC"

  # Create NAT Gateway
  NAT_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET \
    --allocation-id $EIP_ALLOC \
    --region $AWS_REGION \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${PROJECT}-${ENV}-nat-1},{Key=Project,Value=${PROJECT}},{Key=Environment,Value=${ENV}},{Key=ManagedBy,Value=Terraform}]" \
    --query 'NatGateway.NatGatewayId' --output text)
  echo "✅ NAT Gateway created: $NAT_ID"

  # Wait for NAT Gateway
  echo "⏳ Waiting for NAT Gateway to become available (2-3 minutes)..."
  aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID --region $AWS_REGION
  echo "✅ NAT Gateway available"
fi

# 3. Update Route Tables
echo ""
echo "3️⃣  Configuring Route Tables..."

# Get all private app route tables
ROUTE_TABLES=$(aws ec2 describe-route-tables \
  --region $AWS_REGION \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" \
  --query 'RouteTables[*].RouteTableId' --output text)

if [ -z "$ROUTE_TABLES" ]; then
  echo "⚠️  No private app route tables found"
else
  for RT_ID in $ROUTE_TABLES; do
    echo "   Updating route table: $RT_ID"
    aws ec2 replace-route \
      --route-table-id $RT_ID \
      --destination-cidr-block 0.0.0.0/0 \
      --nat-gateway-id $NAT_ID \
      --region $AWS_REGION 2>/dev/null || \
    aws ec2 create-route \
      --route-table-id $RT_ID \
      --destination-cidr-block 0.0.0.0/0 \
      --nat-gateway-id $NAT_ID \
      --region $AWS_REGION 2>/dev/null
  done
  echo "✅ All route tables configured"
fi

# 4. Scale Up ECS Services
echo ""
echo "4️⃣  Starting ECS Services..."
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
      --desired-count 1 \
      --region $AWS_REGION > /dev/null
    echo "✅ $SERVICE scaled to 1"
  else
    echo "⚠️  $SERVICE not found (may not be deployed yet)"
  fi
done

echo ""
echo "========================================="
echo "✅ Infrastructure Started Successfully!"
echo "========================================="
echo "NAT Gateway: $NAT_ID"
echo "Database: $DB_INSTANCE"
echo "VPC: $VPC_ID"
echo ""
echo "⏳ Services will be ready in 2-3 minutes"
echo ""
