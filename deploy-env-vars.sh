#!/bin/bash

# ==============================================================================
# Deploy Environment Variables and Secrets Script
# ==============================================================================
# This script deploys the updated environment variables and secrets configuration
# for the Event Planner microservices.
#
# Changes Applied:
# - Added missing SQS queues (ticket-purchased, payment-processing, etc.)
# - Added environment variables with AWS resource references
# - Updated ECS task definitions with proper database connections
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="dev"
TERRAFORM_DIR="terraform/environments/${ENVIRONMENT}"
AWS_REGION="eu-west-1"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Event Planner Environment Variables Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured or expired${NC}"
    echo "Please run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account: $ACCOUNT_ID${NC}"
echo ""

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

echo -e "${YELLOW}Planning infrastructure changes...${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}The following changes will be applied:${NC}"
echo "1. Add new SQS queues:"
echo "   - event-invitation-queue"
echo "   - ticket-purchased-event-queue" 
echo "   - payment-processing-event-queue"
echo "   - payment-completed-event-queue"
echo ""
echo "2. Update ECS task definitions with environment variables:"
echo "   - VIRTUAL_TICKET_VERIFICATION_URL (ALB endpoint)"
echo "   - EVENT_SERVICE_DB_URL (auth database connection)"
echo "   - EVENT_SERVICE_DB_USER (auth database user)"
echo "   - EVENT_SERVICE_DB_PASSWORD (auth database password)"
echo "   - SQS_ENDPOINT (AWS SQS endpoint)"
echo "   - All SQS queue URLs (from AWS)"
echo "   - AWS_S3_BUCKET (from AWS S3)"
echo "   - ALB_BASE_URL (ALB DNS name)"
echo "   - FRONTEND_BASE_URL (CloudFront domain)"
echo ""

read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Applying changes...${NC}"
    terraform apply tfplan
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Deployment Successful!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${GREEN}✓ SQS queues created${NC}"
        echo -e "${GREEN}✓ Environment variables updated${NC}"
        echo -e "${GREEN}✓ ECS services will restart with new configuration${NC}"
        echo ""
        
        echo -e "${YELLOW}Getting resource information...${NC}"
        
        # Get ALB DNS name
        ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")
        echo "ALB DNS Name: $ALB_DNS"
        
        # Get S3 bucket name
        S3_BUCKET=$(terraform output -raw s3_assets_bucket_name 2>/dev/null || echo "Not available")
        echo "S3 Bucket: $S3_BUCKET"
        
        # Get SQS queue URLs
        echo ""
        echo "SQS Queue URLs:"
        aws sqs list-queues --region $AWS_REGION --query 'QueueUrls[?contains(@, `event-planner-dev`)]' --output table
        
        echo ""
        echo -e "${BLUE}Next Steps:${NC}"
        echo "1. Services will automatically restart with new environment variables"
        echo "2. Event service can now connect to auth database using event_schema"
        echo "3. All services have access to the correct SQS queues and S3 bucket"
        echo "4. Virtual ticket verification URL points to ALB endpoint"
        echo ""
        echo -e "${YELLOW}Monitor service health:${NC}"
        echo "aws ecs describe-services --cluster event-planner-dev-cluster --services auth-service event-service notification-service --region $AWS_REGION"
        
    else
        echo -e "${RED}Deployment failed!${NC}"
        exit 1
    fi
else
    echo "Deployment cancelled."
    rm -f tfplan
fi