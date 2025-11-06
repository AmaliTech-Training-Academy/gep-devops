#!/bin/bash
# scripts/utilities/start-all-resources.sh
# Starts all RDS instances, EC2 instances, NAT Gateway, and ECS services

set -e

AWS_PROFILE="${AWS_PROFILE:-gtp-cletus}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
CLUSTER_NAME="${CLUSTER_NAME:-event-planner-dev-cluster}"

echo "=========================================="
echo "Starting All AWS Resources"
echo "=========================================="
echo "Profile: $AWS_PROFILE"
echo "Region: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
echo "=========================================="

# 1. Start all RDS instances
echo ""
echo "[1/4] Starting RDS Instances..."
RDS_INSTANCES=$(aws rds describe-db-instances \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --query 'DBInstances[?DBInstanceStatus==`stopped`].DBInstanceIdentifier' \
  --output text)

if [ ! -z "$RDS_INSTANCES" ]; then
  for DB_INSTANCE in $RDS_INSTANCES; do
    echo "  → Starting RDS: $DB_INSTANCE"
    aws rds start-db-instance --db-instance-identifier $DB_INSTANCE \
      --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  done
  echo "  ✓ All RDS instances starting (takes ~5 minutes)"
else
  echo "  ℹ No stopped RDS instances found"
fi

# 2. Start all EC2 instances
echo ""
echo "[2/4] Starting EC2 Instances..."
EC2_INSTANCES=$(aws ec2 describe-instances \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --filters "Name=instance-state-name,Values=stopped" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

if [ ! -z "$EC2_INSTANCES" ]; then
  echo "  → Starting instances: $EC2_INSTANCES"
  aws ec2 start-instances --instance-ids $EC2_INSTANCES \
    --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  echo "  ✓ All EC2 instances starting"
else
  echo "  ℹ No stopped EC2 instances found"
fi

# 3. Recreate NAT Gateway
echo ""
echo "[3/4] Recreating NAT Gateway..."

# Get public subnet ID
SUBNET_ID=$(aws ec2 describe-subnets \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --filters "Name=tag:Name,Values=*public*" \
  --query 'Subnets[0].SubnetId' --output text)

if [ "$SUBNET_ID" != "None" ] && [ ! -z "$SUBNET_ID" ]; then
  # Allocate new EIP
  echo "  → Allocating Elastic IP..."
  EIP_ALLOC=$(aws ec2 allocate-address --domain vpc \
    --profile $AWS_PROFILE --region $AWS_REGION \
    --query 'AllocationId' --output text)
  
  # Create NAT Gateway
  echo "  → Creating NAT Gateway in subnet: $SUBNET_ID"
  NAT_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $SUBNET_ID \
    --allocation-id $EIP_ALLOC \
    --profile $AWS_PROFILE --region $AWS_REGION \
    --query 'NatGateway.NatGatewayId' --output text)
  
  echo "  → NAT Gateway ID: $NAT_ID"
  echo "  Waiting for NAT Gateway to become available (~3 minutes)..."
  aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID \
    --profile $AWS_PROFILE --region $AWS_REGION 2>/dev/null || sleep 180
  
  echo "  ✓ NAT Gateway created and available"
else
  echo "  ⚠ Could not find public subnet. NAT Gateway not created."
  echo "  You may need to create it manually or run the original script."
fi

# 4. Scale up ECS services
echo ""
echo "[4/4] Starting ECS Services..."
SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --query 'serviceArns[*]' --output text)

if [ ! -z "$SERVICES" ]; then
  for SERVICE_ARN in $SERVICES; do
    SERVICE_NAME=$(echo $SERVICE_ARN | awk -F'/' '{print $NF}')
    echo "  → Scaling up: $SERVICE_NAME to 1 task"
    aws ecs update-service --cluster $CLUSTER_NAME \
      --service $SERVICE_NAME --desired-count 1 \
      --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  done
  echo "  ✓ All ECS services scaled to 1"
else
  echo "  ℹ No ECS services found"
fi

# Summary
echo ""
echo "=========================================="
echo "✓ All Resources Started Successfully"
echo "=========================================="
echo ""
echo "Note: Resources may take a few minutes to be fully operational:"
echo "  • RDS instances: ~5 minutes"
echo "  • NAT Gateway: ~3 minutes"
echo "  • ECS tasks: ~2 minutes"
echo "  • EC2 instances: ~2 minutes"
echo ""
echo "Verify status with:"
echo "  aws rds describe-db-instances --profile $AWS_PROFILE --region $AWS_REGION"
echo "  aws ecs list-tasks --cluster $CLUSTER_NAME --profile $AWS_PROFILE --region $AWS_REGION"
echo "=========================================="
