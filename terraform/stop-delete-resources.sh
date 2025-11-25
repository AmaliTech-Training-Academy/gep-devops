#!/bin/bash
# ==============================================================================
# STOP/DELETE RESOURCES SCRIPT - Cost Optimization for Non-Working Hours
# ==============================================================================
# PURPOSE:
# This script stops/deletes AWS resources during non-working hours to save costs.
# Designed for development environment cost optimization.
#
# RESOURCES MANAGED:
# . ECS Services - Scale all services (auth, event, payment, notification) to 0
# . RDS Database - Stop the PostgreSQL instance (event-planner-dev-auth-db)
# . NAT Gateway - Delete NAT Gateway and release associated Elastic IP
# . Route Tables - Clean up NAT Gateway routes from private app subnets
# . EC Instances - Stop Actions Runner and Grafana instances
#
# COST SAVINGS:
# - NAT Gateway: ~$/month + data transfer costs
# - RDS Instance: ~$0-0/month when stopped
# - ECS Tasks: ~$0-0/month when scaled to 0
# - EC Instances: Variable based on instance type
# - EIP: ~$.0/month when not attached
#
# USAGE:
# ./stop-delete-resources.sh
#
# PREREQUISITES:
# - AWS CLI configured with appropriate permissions
# - Resources must exist and be tagged properly
# - Script should be run during non-working hours
# ==============================================================================

set -e

# Configuration
AWS_PROFILE="gtp-cletus"
AWS_REGION="eu-west-1"
PROJECT="event-planner"
ENV="dev"

export AWS_PROFILE

echo "========================================="
echo " STOPPING EVENT PLANNER INFRASTRUCTURE"
echo "========================================="
echo "Project: $PROJECT"
echo "Environment: $ENV"
echo "Region: $AWS_REGION"
echo "Profile: $AWS_PROFILE"
echo ""

# ==============================================================================
# . Scale Down ECS Services to 0
# ==============================================================================
echo "  Scaling down ECS Services..."
CLUSTER="${PROJECT}-${ENV}-cluster"

# Check if cluster exists first
CLUSTER_EXISTS=$(aws ecs describe-clusters \
  --clusters $CLUSTER \
  --region $AWS_REGION \
  --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "None")

if [ "$CLUSTER_EXISTS" == "None" ] || [ -z "$CLUSTER_EXISTS" ]; then
  echo "     ECS Cluster $CLUSTER not found - skipping ECS services"
else
  # All active services based on Terraform configuration
  SERVICES=("auth-service" "event-service" "payment-service" "notification-service")
  SERVICES_SCALED=0

  for SERVICE in "${SERVICES[@]}"; do
    echo "   Checking service: $SERVICE"
    
    # Check if service exists and get its status
    SERVICE_INFO=$(aws ecs describe-services \
      --cluster $CLUSTER \
      --services $SERVICE \
      --region $AWS_REGION \
      --query 'services[0].{Name:serviceName,DesiredCount:desiredCount,RunningCount:runningCount,Status:status}' \
      --output json 2>/dev/null || echo '{"Name":"None"}')
    
    SERVICE_NAME=$(echo $SERVICE_INFO | jq -r '.Name // "None"')
    
    if [ "$SERVICE_NAME" != "None" ] && [ "$SERVICE_NAME" != "null" ]; then
      DESIRED_COUNT=$(echo $SERVICE_INFO | jq -r '.DesiredCount // 0')
      RUNNING_COUNT=$(echo $SERVICE_INFO | jq -r '.RunningCount // 0')
      SERVICE_STATUS=$(echo $SERVICE_INFO | jq -r '.Status // "UNKNOWN"')
      
      if [ "$DESIRED_COUNT" -gt 0 ]; then
        echo "   Scaling $SERVICE from $DESIRED_COUNT to 0 (running: $RUNNING_COUNT)"
        aws ecs update-service \
          --cluster $CLUSTER \
          --service $SERVICE \
          --desired-count 0 \
          --region $AWS_REGION > /dev/null
        echo "    $SERVICE scaled to 0"
        SERVICES_SCALED=$((SERVICES_SCALED + 1))
      else
        echo "    $SERVICE already at 0 tasks (status: $SERVICE_STATUS)"
      fi
    else
      echo "     $SERVICE not found (may not be deployed)"
    fi
  done

  if [ $SERVICES_SCALED -gt 0 ]; then
    echo "    Waiting for $SERVICES_SCALED services to stop (0 seconds)..."
    sleep 0
  else
    echo "    All services already stopped - no wait needed"
  fi
fi

# ==============================================================================
# . Stop RDS Database Instance
# ==============================================================================
echo ""
echo "  Stopping RDS Database..."
DB_INSTANCE="${PROJECT}-${ENV}-auth-db"

DB_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE \
  --region $AWS_REGION \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "None")

case "$DB_STATUS" in
  "available")
    echo "   Stopping database $DB_INSTANCE..."
    aws rds stop-db-instance \
      --db-instance-identifier $DB_INSTANCE \
      --region $AWS_REGION > /dev/null
    echo "    Database stopping (takes - minutes)"
    ;;
  "stopped")
    echo "    Database already stopped - skipping"
    ;;
  "stopping")
    echo "    Database already stopping - skipping"
    ;;
  "None")
    echo "     Database $DB_INSTANCE not found - skipping"
    ;;
  *)
    echo "     Database status: $DB_STATUS (cannot stop) - skipping"
    ;;
esac

# ==============================================================================
# . Stop EC Instances (Actions Runner & Grafana)
# ==============================================================================
echo ""
echo "  Stopping EC instances..."

# Specific instances found in the account
ACTIONS_RUNNER_ID="i-0f02a33916afba233"
GRAFANA_INSTANCE_ID="i-0c4ff653a58cd4c27"

# Stop Actions Runner instance
echo "   Checking Actions Runner instance: $ACTIONS_RUNNER_ID"
ACTIONS_RUNNER_STATE=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $ACTIONS_RUNNER_ID \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "None")

case "$ACTIONS_RUNNER_STATE" in
  "running")
    aws ec2 stop-instances \
      --instance-ids $ACTIONS_RUNNER_ID \
      --region $AWS_REGION > /dev/null
    echo "    Actions Runner stopping"
    ;;
  "stopped"|"stopping")
    echo "    Actions Runner already $ACTIONS_RUNNER_STATE - skipping"
    ;;
  "None")
    echo "     Actions Runner instance not found - skipping"
    ;;
  *)
    echo "     Actions Runner state: $ACTIONS_RUNNER_STATE - skipping"
    ;;
esac

# Stop Grafana instance
echo "   Checking Grafana instance: $GRAFANA_INSTANCE_ID"
GRAFANA_STATE=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $GRAFANA_INSTANCE_ID \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "None")

case "$GRAFANA_STATE" in
  "running")
    aws ec2 stop-instances \
      --instance-ids $GRAFANA_INSTANCE_ID \
      --region $AWS_REGION > /dev/null
    echo "    Grafana stopping"
    ;;
  "stopped"|"stopping")
    echo "    Grafana already $GRAFANA_STATE - skipping"
    ;;
  "None")
    echo "     Grafana instance not found - skipping"
    ;;
  *)
    echo "     Grafana state: $GRAFANA_STATE - skipping"
    ;;
esac

# ==============================================================================
# . Get VPC Information
# ==============================================================================
echo ""
echo "  Getting VPC information..."

VPC_ID=$(aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT}-${ENV}-vpc" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
  echo "    VPC not found. Cannot proceed with NAT Gateway deletion."
  exit 1
fi

echo "    VPC ID: $VPC_ID"

# ==============================================================================
# . Delete NAT Gateway and Release EIP
# ==============================================================================
echo ""
echo "  Managing NAT Gateway..."

# Find NAT Gateway in the VPC (check all states)
NAT_INFO=$(aws ec2 describe-nat-gateways \
  --region $AWS_REGION \
  --filter "Name=vpc-id,Values=${VPC_ID}" \
  --query 'NatGateways[0].{Id:NatGatewayId,State:State,EipAlloc:NatGatewayAddresses[0].AllocationId}' \
  --output json 2>/dev/null || echo '{"Id":"None"}')

NAT_ID=$(echo $NAT_INFO | jq -r '.Id // "None"')
NAT_STATE=$(echo $NAT_INFO | jq -r '.State // "None"')
EIP_ALLOC=$(echo $NAT_INFO | jq -r '.EipAlloc // "None"')

case "$NAT_STATE" in
  "available"|"pending")
    echo "   Found NAT Gateway: $NAT_ID (state: $NAT_STATE)"
    
    # First remove routes from private app route tables
    echo "   Removing NAT Gateway routes from private subnets..."
    PRIVATE_APP_RT_IDS=$(aws ec2 describe-route-tables \
      --region $AWS_REGION \
      --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" \
      --query 'RouteTables[*].RouteTableId' --output text 2>/dev/null || echo "")
    
    if [ -n "$PRIVATE_APP_RT_IDS" ] && [ "$PRIVATE_APP_RT_IDS" != "None" ]; then
      ROUTES_REMOVED=0
      for RT_ID in $PRIVATE_APP_RT_IDS; do
        # Check if NAT Gateway route exists
        NAT_ROUTE_EXISTS=$(aws ec2 describe-route-tables \
          --region $AWS_REGION \
          --route-table-ids $RT_ID \
          --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0` && NatGatewayId].NatGatewayId' \
          --output text 2>/dev/null || echo "")
        
        if [ -n "$NAT_ROUTE_EXISTS" ] && [ "$NAT_ROUTE_EXISTS" != "None" ]; then
          echo "   Removing NAT Gateway route from: $RT_ID"
          aws ec2 delete-route \
            --route-table-id $RT_ID \
            --destination-cidr-block 0.0.0.0/0 \
            --region $AWS_REGION >/dev/null 2>&1 && ROUTES_REMOVED=$((ROUTES_REMOVED + 1))
        fi
      done
      echo "   Removed routes from $ROUTES_REMOVED route tables"
    fi
    
    # Now delete NAT Gateway
    echo "   Deleting NAT Gateway..."
    aws ec2 delete-nat-gateway \
      --nat-gateway-id $NAT_ID \
      --region $AWS_REGION > /dev/null
    echo "   NAT Gateway deletion initiated"
    
    # Wait for NAT Gateway to be deleted
    echo "   Waiting for NAT Gateway deletion (2-3 minutes)..."
    aws ec2 wait nat-gateway-deleted \
      --nat-gateway-ids $NAT_ID \
      --region $AWS_REGION 2>/dev/null || sleep 60
    echo "   NAT Gateway deleted"
    
    # Release EIP
    if [ "$EIP_ALLOC" != "None" ] && [ -n "$EIP_ALLOC" ]; then
      echo "   Releasing Elastic IP: $EIP_ALLOC"
      aws ec2 release-address \
        --allocation-id $EIP_ALLOC \
        --region $AWS_REGION > /dev/null
      echo "   EIP released"
    else
      echo "   No EIP found to release"
    fi
    ;;
  "deleting")
    echo "   NAT Gateway already deleting - waiting for completion"
    aws ec2 wait nat-gateway-deleted \
      --nat-gateway-ids $NAT_ID \
      --region $AWS_REGION 2>/dev/null || sleep 60
    echo "   NAT Gateway deletion completed"
    ;;
  "deleted")
    echo "   NAT Gateway already deleted - skipping"
    ;;
  "None")
    echo "   No NAT Gateway found - already deleted or doesn't exist"
    ;;
  *)
    echo "   NAT Gateway state: $NAT_STATE - skipping"
    ;;
esac

# ==============================================================================
# . Clean Up Route Tables
# ==============================================================================
echo ""
echo "  Cleaning up route tables..."

# Get private app route tables (based on Terraform naming convention)
ROUTE_TABLES=$(aws ec2 describe-route-tables \
  --region $AWS_REGION \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" \
  --query 'RouteTables[*].RouteTableId' --output text >/dev/null || echo "")

if [ -n "$ROUTE_TABLES" ] && [ "$ROUTE_TABLES" != "None" ]; then
  ROUTES_CLEANED=0
  for RT_ID in $ROUTE_TABLES; do
    # Check if route exists before trying to delete
    ROUTE_EXISTS=$(aws ec describe-route-tables \
      --region $AWS_REGION \
      --route-table-ids $RT_ID \
      --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0` && NatGatewayId].NatGatewayId' \
      --output text >/dev/null || echo "")
    
    if [ -n "$ROUTE_EXISTS" ] && [ "$ROUTE_EXISTS" != "None" ]; then
      echo "   Removing NAT Gateway route from: $RT_ID"
      aws ec2 delete-route \
        --route-table-id $RT_ID \
        --destination-cidr-block 0.0.0.0/0 \
        --region $AWS_REGION >/dev/null && ROUTES_CLEANED=$((ROUTES_CLEANED + 1))
    else
      echo "    No NAT Gateway route in $RT_ID - already clean"
    fi
  done
  
  if [ $ROUTES_CLEANED -gt 0 ]; then
    echo "    Cleaned $ROUTES_CLEANED route tables"
  else
    echo "    All route tables already clean"
  fi
else
  echo "    No private app route tables found"
fi

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "========================================="
echo " INFRASTRUCTURE STOPPED SUCCESSFULLY!"
echo "========================================="
echo ""
echo " RESOURCES STOPPED/DELETED:"
echo "   • ECS Services: All scaled to 0 tasks"
echo "   • RDS Database: $DB_INSTANCE (stopped)"
echo "   • NAT Gateway: Deleted"
echo "   • Elastic IP: Released"
echo "   • Route Tables: Cleaned"
echo "   • Actions Runner: $ACTIONS_RUNNER_ID (stopped)"
echo "   • Grafana Instance: $GRAFANA_INSTANCE_ID (stopped)"
echo ""
echo " ESTIMATED COST SAVINGS:"
echo "   • NAT Gateway: ~\$.08/night + data transfer"
echo "   • RDS Instance: ~\$.00-.0/night"
echo "   • ECS Tasks: ~\$.0-.0/night"
echo "   • EIP: ~\$0./day (when not attached)"
echo "   • Actions Runner (t.medium): ~\$0.80-.00/night"
echo "   • Grafana (t.micro): ~\$0.0-0./night"
echo ""
echo "    Total estimated savings: ~\$-8/night"
echo ""
echo "  Run start-create-resources.sh when you resume work"
echo ""
echo "  NOTE: Services will be unavailable until resources are restarted"
echo ""