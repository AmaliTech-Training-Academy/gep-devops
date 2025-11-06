#!/bin/bash
# scripts/utilities/stop-all-resources.sh
# Stops all ECS tasks, RDS instances, EC2 instances, and NAT Gateway to save costs

set -e

AWS_PROFILE="${AWS_PROFILE:-gtp-cletus}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
CLUSTER_NAME="${CLUSTER_NAME:-event-planner-dev-cluster}"

echo "=========================================="
echo "Stopping All AWS Resources"
echo "=========================================="
echo "Profile: $AWS_PROFILE"
echo "Region: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
echo "=========================================="

# 1. Stop all ECS services
echo ""
echo "[1/4] Stopping ECS Services..."
SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --query 'serviceArns[*]' --output text)

if [ ! -z "$SERVICES" ]; then
  for SERVICE_ARN in $SERVICES; do
    SERVICE_NAME=$(echo $SERVICE_ARN | awk -F'/' '{print $NF}')
    echo "  → Scaling down: $SERVICE_NAME"
    aws ecs update-service --cluster $CLUSTER_NAME \
      --service $SERVICE_NAME --desired-count 0 \
      --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  done
  echo "  ✓ All ECS services scaled to 0"
  echo "  Waiting 30s for tasks to stop..."
  sleep 30
else
  echo "  ℹ No ECS services found"
fi

# 2. Stop all RDS instances
echo ""
echo "[2/4] Stopping RDS Instances..."
RDS_INSTANCES=$(aws rds describe-db-instances \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --query 'DBInstances[?DBInstanceStatus==`available`].DBInstanceIdentifier' \
  --output text)

if [ ! -z "$RDS_INSTANCES" ]; then
  for DB_INSTANCE in $RDS_INSTANCES; do
    echo "  → Stopping RDS: $DB_INSTANCE"
    aws rds stop-db-instance --db-instance-identifier $DB_INSTANCE \
      --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  done
  echo "  ✓ All RDS instances stopped"
else
  echo "  ℹ No running RDS instances found"
fi

# 3. Stop all EC2 instances
echo ""
echo "[3/4] Stopping EC2 Instances..."
EC2_INSTANCES=$(aws ec2 describe-instances \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

if [ ! -z "$EC2_INSTANCES" ]; then
  echo "  → Stopping instances: $EC2_INSTANCES"
  aws ec2 stop-instances --instance-ids $EC2_INSTANCES \
    --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  echo "  ✓ All EC2 instances stopped"
else
  echo "  ℹ No running EC2 instances found"
fi

# 4. Delete NAT Gateway and release EIP
echo ""
echo "[4/4] Deleting NAT Gateway..."
NAT_ID=$(aws ec2 describe-nat-gateways \
  --profile $AWS_PROFILE --region $AWS_REGION \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[0].NatGatewayId' --output text)

if [ "$NAT_ID" != "None" ] && [ ! -z "$NAT_ID" ]; then
  echo "  → Deleting NAT Gateway: $NAT_ID"
  aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID \
    --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  
  echo "  Waiting for NAT Gateway deletion (~2 minutes)..."
  aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID \
    --profile $AWS_PROFILE --region $AWS_REGION 2>/dev/null || sleep 120
  
  # Release Elastic IP
  EIP_ID=$(aws ec2 describe-addresses \
    --profile $AWS_PROFILE --region $AWS_REGION \
    --filters "Name=domain,Values=vpc" \
    --query 'Addresses[?AssociationId==`null`].AllocationId' \
    --output text | head -1)
  
  if [ ! -z "$EIP_ID" ] && [ "$EIP_ID" != "None" ]; then
    echo "  → Releasing EIP: $EIP_ID"
    aws ec2 release-address --allocation-id $EIP_ID \
      --profile $AWS_PROFILE --region $AWS_REGION > /dev/null 2>&1
  fi
  
  echo "  ✓ NAT Gateway deleted and EIP released"
else
  echo "  ℹ No NAT Gateway found"
fi

# Summary
echo ""
echo "=========================================="
echo "✓ All Resources Stopped Successfully"
echo "=========================================="
echo ""
echo "Estimated Cost Savings (per day):"
echo "  • RDS (db.t4g.micro):     ~\$0.40/day"
echo "  • NAT Gateway:            ~\$1.08/day"
echo "  • Elastic IP:             ~\$0.12/day"
echo "  • ECS Fargate:            ~\$0.50/day"
echo "  • EC2 (if any):           varies"
echo "  --------------------------------"
echo "  Total:                    ~\$2.10+/day"
echo ""
echo "To restart resources, run: ./start-all-resources.sh"
echo "=========================================="
