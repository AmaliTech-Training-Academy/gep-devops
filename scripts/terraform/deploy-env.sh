# ==============================================================================
# scripts/terraform/deploy-env.sh
# ==============================================================================
# Deploy Environment
# ==============================================================================
# This script deploys or updates a Terraform environment (dev/prod).
#
# Usage:
#   ./scripts/terraform/deploy-env.sh <environment>
#   Example: ./scripts/terraform/deploy-env.sh dev
# ==============================================================================

#!/bin/bash
set -e

ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
    echo "Error: Environment not specified"
    echo "Usage: ./scripts/terraform/deploy-env.sh <environment>"
    exit 1
fi

echo "===================================="
echo "Deploying $ENVIRONMENT Environment"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validate environment
if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}Error: Invalid environment. Use 'dev' or 'prod'${NC}"
    exit 1
fi

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Load environment variables if .env exists
ENV_FILE="terraform/environments/$ENVIRONMENT/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Loading environment variables from $ENV_FILE${NC}"
    source "$ENV_FILE"
fi

# Navigate to environment directory
cd "terraform/environments/$ENVIRONMENT"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Environment: $ENVIRONMENT"
echo ""

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Validate
echo ""
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan
echo ""
echo -e "${YELLOW}Planning infrastructure changes...${NC}"
terraform plan -out=tfplan

# Show plan summary
echo ""
echo -e "${YELLOW}Plan Summary:${NC}"
terraform show -json tfplan | jq -r '.resource_changes[] | "\(.change.actions[0]): \(.address)"'

# Confirm
echo ""
read -p "Do you want to apply these changes? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Apply
echo ""
echo -e "${YELLOW}Applying infrastructure changes...${NC}"
terraform apply tfplan

# Show outputs
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Key Outputs:"
terraform output

echo ""
echo -e "${GREEN}Environment deployed successfully!${NC}"