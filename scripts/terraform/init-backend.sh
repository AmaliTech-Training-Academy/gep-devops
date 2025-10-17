#!/bin/bash
# scripts/terraform/init-backend.sh
# ==============================================================================
# Initialize Terraform Backend
# ==============================================================================
# This script initializes the S3 backend and DynamoDB table for Terraform state.
# Run this ONCE before deploying any environments.
#
# Usage:
#   ./scripts/terraform/init-backend.sh
# ==============================================================================

set -e

echo "===================================="
echo "Terraform Backend Initialization"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""

# Navigate to bootstrap directory
cd terraform/bootstrap

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Plan
echo ""
echo -e "${YELLOW}Planning infrastructure...${NC}"
terraform plan -out=tfplan

# Confirm
echo ""
read -p "Do you want to create the backend infrastructure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Apply
echo ""
echo -e "${YELLOW}Creating backend infrastructure...${NC}"
terraform apply tfplan

# Get outputs
echo ""
echo -e "${GREEN}Backend infrastructure created successfully!${NC}"
echo ""
echo "Copy the following backend configuration to your environment backend.tf files:"
echo ""
terraform output -raw backend_config

echo ""
echo -e "${GREEN}Backend initialization complete!${NC}"




