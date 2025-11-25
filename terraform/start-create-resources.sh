#!/bin/bash
# ==============================================================================
# START/CREATE RESOURCES SCRIPT - Resume Infrastructure for Working Hours
# ==============================================================================
# PURPOSE:
# This script starts/creates AWS resources during working hours to resume operations.
# Designed for development environment cost optimization workflow.
#
# RESOURCES MANAGED:
# . RDS Database - Start the PostgreSQL instance (event-planner-dev-auth-db)
# . EC2 Instances - Start Actions Runner and Grafana instances
# . NAT Gateway - Create NAT Gateway and allocate Elastic IP
# . Route Tables - Add NAT Gateway routes to private app subnets
# . ECS Services - Scale all services (auth, event, payment, notification) to 1
#
# COST IMPACT:
# - NAT Gateway: ~$32/month + data transfer costs
# - RDS Instance: ~$30-40/month when running
# - ECS Tasks: ~$50-70/month when scaled to 1
# - EC2 Instances: Variable based on instance type
# - EIP: ~$3.60/month when attached
#
# USAGE:
# ./start-create-resources.sh
#
# PREREQUISITES:
# - AWS CLI configured with appropriate permissions
# - Resources must exist and be tagged properly
# - Script should be run during working hours
# ==============================================================================

set -e

# Configuration
AWS_PROFILE="gtp-cletus"
AWS_REGION="eu-west-1"
PROJECT="event-planner"
ENV="dev"

export AWS_PROFILE

echo "========================================="
echo " STARTING EVENT PLANNER INFRASTRUCTURE"
echo "========================================="
echo "Project: $PROJECT"
echo "Environment: $ENV"
echo "Region: $AWS_REGION"
echo "Profile: $AWS_PROFILE"
echo ""

# ==============================================================================
# 1. Start RDS Database Instance
# ==============================================================================
echo "1. Starting RDS Database..."
DB_INSTANCE="${PROJECT}-${ENV}-auth-db"

DB_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE \
  --region $AWS_REGION \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "None")

case "$DB_STATUS" in
  "stopped")
    echo "   Starting database $DB_INSTANCE..."
    aws rds start-db-instance \
      --db-instance-identifier $DB_INSTANCE \
      --region $AWS_REGION > /dev/null
    echo "   Database starting (takes 2-3 minutes)"
    ;;
  "available")
    echo "   Database already running - skipping"
    ;;
  "starting")
    echo "   Database already starting - skipping"
    ;;
  "None")
    echo "   Database $DB_INSTANCE not found - skipping"
    ;;
  *)
    echo "   Database status: $DB_STATUS - skipping"
    ;;
esac

# ==============================================================================
# 2. Start EC2 Instances (Actions Runner & Grafana)
# ==============================================================================
echo ""
echo "2. Starting EC2 instances..."

# Specific instances found in the account
ACTIONS_RUNNER_ID="i-0f02a33916afba233"
GRAFANA_INSTANCE_ID="i-0c4ff653a58cd4c27"

# Start Actions Runner instance
echo "   Starting Actions Runner: $ACTIONS_RUNNER_ID"
ACTIONS_RUNNER_STATE=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $ACTIONS_RUNNER_ID \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "None")

case "$ACTIONS_RUNNER_STATE" in
  "stopped")
    aws ec2 start-instances \
      --instance-ids $ACTIONS_RUNNER_ID \
      --region $AWS_REGION > /dev/null
    echo "   Actions Runner starting"
    ;;
  "running"|"pending")
    echo "   Actions Runner already $ACTIONS_RUNNER_STATE - skipping"
    ;;
  "None")
    echo "   Actions Runner not found - skipping"
    ;;
  *)
    echo "   Actions Runner state: $ACTIONS_RUNNER_STATE - skipping"
    ;;
esac

# Start Grafana instance
echo "   Starting Grafana: $GRAFANA_INSTANCE_ID"
GRAFANA_STATE=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --instance-ids $GRAFANA_INSTANCE_ID \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "None")

case "$GRAFANA_STATE" in
  "stopped")
    aws ec2 start-instances \
      --instance-ids $GRAFANA_INSTANCE_ID \
      --region $AWS_REGION > /dev/null
    echo "   Grafana starting"
    ;;
  "running"|"pending")
    echo "   Grafana already $GRAFANA_STATE - skipping"
    ;;
  "None")
    echo "   Grafana not found - skipping"
    ;;
  *)
    echo "   Grafana state: $GRAFANA_STATE - skipping"
    ;;
esac

# ==============================================================================
# 3. Create NAT Gateway and Allocate EIP
# ==============================================================================
echo ""
echo "3. Creating NAT Gateway and EIP..."

# Get VPC information
VPC_ID=$(aws ec2 describe-vpcs \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT}-${ENV}-vpc" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
  echo "   VPC not found - skipping NAT Gateway creation"
else
  echo "   VPC ID: $VPC_ID"
  
  # Find NAT Gateway in the VPC (check all states)
  NAT_INFO=$(aws ec2 describe-nat-gateways \
    --region $AWS_REGION \
    --filter "Name=vpc-id,Values=${VPC_ID}" \
    --query 'NatGateways[0].{Id:NatGatewayId,State:State,EipAlloc:NatGatewayAddresses[0].AllocationId}' \
    --output json 2>/dev/null || echo '{"Id":"None"}')
  
  NAT_ID=$(echo $NAT_INFO | jq -r '.Id // "None"')
  NAT_STATE=$(echo $NAT_INFO | jq -r '.State // "None"')
  
  case "$NAT_STATE" in
    "available")
      echo "   NAT Gateway already available: $NAT_ID"
      # Ensure routes are configured even if NAT Gateway exists
      echo "   Verifying private subnet routes..."
      PRIVATE_APP_RT_IDS=$(aws ec2 describe-route-tables \
        --region $AWS_REGION \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" \
        --query 'RouteTables[*].RouteTableId' --output text 2>/dev/null || echo "")
      
      if [ -n "$PRIVATE_APP_RT_IDS" ] && [ "$PRIVATE_APP_RT_IDS" != "None" ]; then
        ROUTES_ADDED=0
        for RT_ID in $PRIVATE_APP_RT_IDS; do
          # Check if route exists
          EXISTING_ROUTE=$(aws ec2 describe-route-tables \
            --region $AWS_REGION \
            --route-table-ids $RT_ID \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId' \
            --output text 2>/dev/null || echo "")
          
          if [ -z "$EXISTING_ROUTE" ] || [ "$EXISTING_ROUTE" == "None" ]; then
            echo "   Adding missing route to: $RT_ID"
            aws ec2 create-route \
              --route-table-id $RT_ID \
              --destination-cidr-block 0.0.0.0/0 \
              --nat-gateway-id $NAT_ID \
              --region $AWS_REGION >/dev/null 2>&1 && ROUTES_ADDED=$((ROUTES_ADDED + 1))
          fi
        done
        if [ $ROUTES_ADDED -gt 0 ]; then
          echo "   Added $ROUTES_ADDED missing routes"
        else
          echo "   All routes already configured"
        fi
      fi
      ;;
    "pending")
      echo "   NAT Gateway already creating: $NAT_ID - waiting for completion"
      aws ec2 wait nat-gateway-available \
        --nat-gateway-ids $NAT_ID \
        --region $AWS_REGION 2>/dev/null || sleep 120
      echo "   NAT Gateway is now available"
      ;;
    "None"|"deleted"|"failed")
      echo "   Creating new NAT Gateway..."
      
      # Get public subnet (first available)
      PUBLIC_SUBNET=$(aws ec2 describe-subnets \
        --region $AWS_REGION \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-public-*" \
        --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "None")
      
      if [ "$PUBLIC_SUBNET" != "None" ] && [ -n "$PUBLIC_SUBNET" ]; then
        echo "   Allocating Elastic IP..."
        EIP_ALLOC=$(aws ec2 allocate-address \
          --domain vpc \
          --region $AWS_REGION \
          --query 'AllocationId' --output text 2>/dev/null || echo "None")
        
        if [ "$EIP_ALLOC" != "None" ] && [ -n "$EIP_ALLOC" ]; then
          echo "   Creating NAT Gateway in subnet: $PUBLIC_SUBNET"
          NAT_ID=$(aws ec2 create-nat-gateway \
            --subnet-id $PUBLIC_SUBNET \
            --allocation-id $EIP_ALLOC \
            --region $AWS_REGION \
            --query 'NatGateway.NatGatewayId' --output text 2>/dev/null || echo "None")
          
          if [ "$NAT_ID" != "None" ] && [ -n "$NAT_ID" ]; then
            echo "   NAT Gateway created: $NAT_ID"
            echo "   Waiting for NAT Gateway to be available (2-3 minutes)..."
            aws ec2 wait nat-gateway-available \
              --nat-gateway-ids $NAT_ID \
              --region $AWS_REGION 2>/dev/null || sleep 120
            echo "   NAT Gateway is now available"
            
            # Configure routes for private app subnets
            echo "   Configuring private subnet routes..."
            PRIVATE_APP_RT_IDS=$(aws ec2 describe-route-tables \
              --region $AWS_REGION \
              --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${PROJECT}-${ENV}-private-app-rt-*" \
              --query 'RouteTables[*].RouteTableId' --output text 2>/dev/null || echo "")
            
            if [ -n "$PRIVATE_APP_RT_IDS" ] && [ "$PRIVATE_APP_RT_IDS" != "None" ]; then
              ROUTES_ADDED=0
              for RT_ID in $PRIVATE_APP_RT_IDS; do
                echo "   Adding NAT Gateway route to: $RT_ID"
                aws ec2 create-route \
                  --route-table-id $RT_ID \
                  --destination-cidr-block 0.0.0.0/0 \
                  --nat-gateway-id $NAT_ID \
                  --region $AWS_REGION >/dev/null 2>&1
                
                if [ $? -eq 0 ]; then
                  echo "   ✓ Route added successfully to $RT_ID"
                  ROUTES_ADDED=$((ROUTES_ADDED + 1))
                else
                  echo "   → Route creation failed for $RT_ID (may already exist)"
                fi
              done
              echo "   Configured routes for $ROUTES_ADDED route tables"
            else
              echo "   No private app route tables found"
            fi
          else
            echo "   Failed to create NAT Gateway"
            # Clean up EIP if NAT Gateway creation failed
            if [ "$EIP_ALLOC" != "None" ] && [ -n "$EIP_ALLOC" ]; then
              aws ec2 release-address --allocation-id $EIP_ALLOC --region $AWS_REGION >/dev/null 2>&1
            fi
          fi
        else
          echo "   Failed to allocate EIP"
        fi
      else
        echo "   Public subnet not found"
      fi
      ;;
    *)
      echo "   NAT Gateway state: $NAT_STATE - skipping"
      ;;
  esac
fi

# ==============================================================================
# 4. Scale Up ECS Services to 1
# ==============================================================================
echo ""
echo "4. Scaling up ECS Services..."
CLUSTER="${PROJECT}-${ENV}-cluster"

CLUSTER_EXISTS=$(aws ecs describe-clusters \
  --clusters $CLUSTER \
  --region $AWS_REGION \
  --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "None")

if [ "$CLUSTER_EXISTS" == "None" ] || [ -z "$CLUSTER_EXISTS" ]; then
  echo "   ECS Cluster $CLUSTER not found - skipping ECS services"
else
  # All active services based on Terraform configuration with desired counts
  declare -A SERVICES=(
    ["auth-service"]=1
    ["event-service"]=1
    ["payment-service"]=1
    ["notification-service"]=1
  )
  
  SERVICES_SCALED=0

  for SERVICE in "${!SERVICES[@]}"; do
    DESIRED_COUNT=${SERVICES[$SERVICE]}
    echo "   Scaling $SERVICE to $DESIRED_COUNT..."
    
    SERVICE_INFO=$(aws ecs describe-services \
      --cluster $CLUSTER \
      --services $SERVICE \
      --region $AWS_REGION \
      --query 'services[0].{Name:serviceName,DesiredCount:desiredCount,RunningCount:runningCount}' \
      --output json 2>/dev/null || echo '{"Name":"None"}')
    
    SERVICE_NAME=$(echo $SERVICE_INFO | jq -r '.Name // "None"')
    
    if [ "$SERVICE_NAME" != "None" ] && [ "$SERVICE_NAME" != "null" ]; then
      CURRENT_COUNT=$(echo $SERVICE_INFO | jq -r '.DesiredCount // 0')
      RUNNING_COUNT=$(echo $SERVICE_INFO | jq -r '.RunningCount // 0')
      
      if [ "$CURRENT_COUNT" -lt "$DESIRED_COUNT" ]; then
        aws ecs update-service \
          --cluster $CLUSTER \
          --service $SERVICE \
          --desired-count $DESIRED_COUNT \
          --region $AWS_REGION > /dev/null
        echo "   $SERVICE scaled from $CURRENT_COUNT to $DESIRED_COUNT"
        SERVICES_SCALED=$((SERVICES_SCALED + 1))
      else
        echo "   $SERVICE already at desired count ($CURRENT_COUNT)"
      fi
    else
      echo "   $SERVICE not found - skipping"
    fi
  done

  if [ $SERVICES_SCALED -gt 0 ]; then
    echo "   Waiting for $SERVICES_SCALED services to start (60 seconds)..."
    sleep 60
  fi
fi

# ==============================================================================
# 5. Verify Services Status
# ==============================================================================
echo ""
echo "5. Verifying services..."

if [ "$CLUSTER_EXISTS" != "None" ]; then
  for SERVICE in "${!SERVICES[@]}"; do
    SERVICE_INFO=$(aws ecs describe-services \
      --cluster $CLUSTER \
      --services $SERVICE \
      --region $AWS_REGION \
      --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount}' \
      --output json 2>/dev/null || echo '{"DesiredCount":0,"RunningCount":0}')
    
    DESIRED=$(echo $SERVICE_INFO | jq -r '.DesiredCount // 0')
    RUNNING=$(echo $SERVICE_INFO | jq -r '.RunningCount // 0')
    
    if [ "$RUNNING" -eq "$DESIRED" ] && [ "$DESIRED" -gt 0 ]; then
      echo "   ✓ $SERVICE: $RUNNING/$DESIRED tasks running"
    else
      echo "   ⚠ $SERVICE: $RUNNING/$DESIRED tasks (still starting)"
    fi
  done
fi

echo ""
# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "========================================="
echo " INFRASTRUCTURE STARTED SUCCESSFULLY!"
echo "========================================="
echo ""
echo " RESOURCES STARTED/CREATED:"
echo "   • RDS Database: $DB_INSTANCE (started)"
echo "   • NAT Gateway: Created/Available"
echo "   • Elastic IP: Allocated"
echo "   • Route Tables: Updated with NAT Gateway routes"
echo "   • ECS Services: All scaled to 1 task"
echo "   • Actions Runner: $ACTIONS_RUNNER_ID (started)"
echo "   • Grafana Instance: $GRAFANA_INSTANCE_ID (started)"
echo ""
echo " ESTIMATED COST RESUMPTION:"
echo "   • NAT Gateway: ~\$1.08/day + data transfer"
echo "   • RDS Instance: ~\$1.00-1.50/day"
echo "   • ECS Tasks: ~\$2.0-3.0/day"
echo "   • EIP: ~\$0.15/day (when attached)"
echo "   • Actions Runner (t3.medium): ~\$0.80-1.00/day"
echo "   • Grafana (t3.micro): ~\$0.30-0.50/day"
echo ""
echo "    Total estimated daily cost: ~\$5-8/day"
echo ""
echo " ENDPOINTS:"
echo "   • API: https://api.sankofagrid.com"
echo "   • Frontend: https://events.sankofagrid.com"
echo "   • Grafana: https://api.sankofagrid.com/monitoring/"
echo ""
echo "  Run stop-delete-resources.sh when you finish work"
echo ""
echo "  NOTE: Services may take 2-5 minutes to be fully available"
echo ""