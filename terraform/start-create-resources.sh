#!/bin/bash
set -e

AWS_PROFILE="${AWS_PROFILE:-$(aws configure list-profiles | head -1)}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
PROJECT="${PROJECT:-event-planner}"
ENV="${ENV:-dev}"

export AWS_PROFILE

echo "Using AWS Profile: $AWS_PROFILE"
echo "Region: $AWS_REGION | Environment: $ENV"

echo "Starting Event Planner Infrastructure..."

# Start RDS
DB_INSTANCE="${PROJECT}-${ENV}-auth-db"
DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE --region $AWS_REGION --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "None")
if [ "$DB_STATUS" == "stopped" ]; then
  aws rds start-db-instance --db-instance-identifier $DB_INSTANCE --region $AWS_REGION >/dev/null 2>&1
  echo "  ✓ RDS starting"
fi

# Start EC2 instances
for INSTANCE_ID in i-0f02a33916afba233 i-0c4ff653a58cd4c27; do
  STATE=$(aws ec2 describe-instances --region $AWS_REGION --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "None")
  if [ "$STATE" == "stopped" ]; then
    aws ec2 start-instances --instance-ids $INSTANCE_ID --region $AWS_REGION >/dev/null 2>&1
    echo "  ✓ EC2 $INSTANCE_ID starting"
  fi
done

# Create NAT Gateway
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=${PROJECT}-${ENV}-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ "$VPC_ID" != "None" ]; then
  NAT_ID=$(aws ec2 describe-nat-gateways --region $AWS_REGION --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available,pending" --query 'NatGateways[0].NatGatewayId' --output text 2>/dev/null || echo "None")
  
  if [ "$NAT_ID" == "None" ]; then
    PUBLIC_SUBNET=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-public-*" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "None")
    if [ "$PUBLIC_SUBNET" != "None" ]; then
      EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --region $AWS_REGION --query 'AllocationId' --output text 2>/dev/null || echo "None")
      if [ "$EIP_ALLOC" != "None" ]; then
        NAT_ID=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET --allocation-id $EIP_ALLOC --region $AWS_REGION --query 'NatGateway.NatGatewayId' --output text 2>/dev/null || echo "None")
        if [ "$NAT_ID" != "None" ]; then
          aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID --region $AWS_REGION 2>/dev/null || sleep 120
          echo "  ✓ NAT Gateway created: $NAT_ID"
        else
          aws ec2 release-address --allocation-id $EIP_ALLOC --region $AWS_REGION >/dev/null 2>&1
        fi
      fi
    fi
  fi
  
  if [ "$NAT_ID" != "None" ]; then
    PRIVATE_RT_IDS=$(aws ec2 describe-route-tables --region $AWS_REGION --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" --query 'RouteTables[*].RouteTableId' --output text 2>/dev/null || echo "")
    for RT_ID in $PRIVATE_RT_IDS; do
      ROUTE_EXISTS=$(aws ec2 describe-route-tables --region $AWS_REGION --route-table-ids $RT_ID --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId' --output text 2>/dev/null || echo "")
      [ -z "$ROUTE_EXISTS" ] && aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_ID --region $AWS_REGION >/dev/null 2>&1
    done
  fi
fi

# Scale up ECS services
CLUSTER="${PROJECT}-${ENV}-cluster"
if aws ecs describe-clusters --clusters $CLUSTER --region $AWS_REGION >/dev/null 2>&1; then
  for SERVICE in auth-service event-service payment-service notification-service; do
    if aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION --query 'services[0].serviceName' --output text 2>/dev/null | grep -q "$SERVICE"; then
      aws application-autoscaling register-scalable-target \
        --service-namespace ecs --scalable-dimension ecs:service:DesiredCount \
        --resource-id "service/$CLUSTER/$SERVICE" \
        --suspended-state DynamicScalingInSuspended=false,DynamicScalingOutSuspended=false \
        --region $AWS_REGION >/dev/null 2>&1
      aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 1 --region $AWS_REGION >/dev/null 2>&1
      echo "  ✓ $SERVICE scaled to 1"
    fi
  done
fi

echo "Infrastructure started successfully"
