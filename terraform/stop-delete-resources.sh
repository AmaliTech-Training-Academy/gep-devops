#!/bin/bash
set -e

AWS_PROFILE="${AWS_PROFILE:-$(aws configure list-profiles | head -1)}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
PROJECT="${PROJECT:-event-planner}"
ENV="${ENV:-dev}"

export AWS_PROFILE

echo "Using AWS Profile: $AWS_PROFILE"
echo "Region: $AWS_REGION | Environment: $ENV"

echo "Stopping Event Planner Infrastructure..."

# Scale down ECS services
CLUSTER="${PROJECT}-${ENV}-cluster"
if aws ecs describe-clusters --clusters $CLUSTER --region $AWS_REGION >/dev/null 2>&1; then
  for SERVICE in auth-service event-service payment-service notification-service; do
    if aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION --query 'services[0].serviceName' --output text 2>/dev/null | grep -q "$SERVICE"; then
      aws application-autoscaling register-scalable-target \
        --service-namespace ecs --scalable-dimension ecs:service:DesiredCount \
        --resource-id "service/$CLUSTER/$SERVICE" \
        --suspended-state DynamicScalingInSuspended=true,DynamicScalingOutSuspended=true \
        --region $AWS_REGION >/dev/null 2>&1
      aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 0 --region $AWS_REGION >/dev/null 2>&1
      echo "  ✓ $SERVICE scaled to 0"
    fi
  done
fi

# Stop RDS
DB_INSTANCE="${PROJECT}-${ENV}-auth-db"
DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE --region $AWS_REGION --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "None")
if [ "$DB_STATUS" == "available" ]; then
  aws rds stop-db-instance --db-instance-identifier $DB_INSTANCE --region $AWS_REGION >/dev/null 2>&1
  echo "  ✓ RDS stopping"
fi

# Stop EC2 instances
for INSTANCE_ID in i-0f02a33916afba233 i-0c4ff653a58cd4c27; do
  STATE=$(aws ec2 describe-instances --region $AWS_REGION --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "None")
  if [ "$STATE" == "running" ]; then
    aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $AWS_REGION >/dev/null 2>&1
    echo "  ✓ EC2 $INSTANCE_ID stopping"
  fi
done

# Delete NAT Gateway and release EIPs
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=${PROJECT}-${ENV}-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ "$VPC_ID" != "None" ]; then
  NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --region $AWS_REGION --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available,pending" --query 'NatGateways[*].{Id:NatGatewayId,EipAlloc:NatGatewayAddresses[0].AllocationId}' --output json 2>/dev/null || echo '[]')
  NAT_COUNT=$(echo $NAT_GATEWAYS | jq '. | length')
  
  if [ "$NAT_COUNT" -gt 0 ]; then
    PRIVATE_RT_IDS=$(aws ec2 describe-route-tables --region $AWS_REGION --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" --query 'RouteTables[*].RouteTableId' --output text 2>/dev/null || echo "")
    for RT_ID in $PRIVATE_RT_IDS; do
      aws ec2 delete-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --region $AWS_REGION >/dev/null 2>&1
    done
    
    EIP_ALLOCS=()
    for row in $(echo $NAT_GATEWAYS | jq -r '.[] | @base64'); do
      NAT_ID=$(echo $row | base64 -d | jq -r '.Id')
      EIP_ALLOC=$(echo $row | base64 -d | jq -r '.EipAlloc // ""')
      aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID --region $AWS_REGION >/dev/null 2>&1
      [ -n "$EIP_ALLOC" ] && EIP_ALLOCS+=("$EIP_ALLOC")
    done
    
    sleep 60
    for EIP_ALLOC in "${EIP_ALLOCS[@]}"; do
      aws ec2 release-address --allocation-id $EIP_ALLOC --region $AWS_REGION >/dev/null 2>&1
    done
    echo "  ✓ NAT Gateway deleted, EIPs released"
  fi
  
  UNATTACHED_EIPS=$(aws ec2 describe-addresses --region $AWS_REGION --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId==`null`].AllocationId' --output text 2>/dev/null || echo "")
  for EIP in $UNATTACHED_EIPS; do
    aws ec2 release-address --allocation-id $EIP --region $AWS_REGION >/dev/null 2>&1
  done
fi

echo "Infrastructure stopped successfully"
