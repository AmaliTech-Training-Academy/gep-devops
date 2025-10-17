# ==============================================================================
# scripts/terraform/setup-secrets.sh
# ==============================================================================
# Setup AWS Secrets Manager Secrets
# ==============================================================================
# This script creates all required secrets in AWS Secrets Manager.
#
# Usage:
#   ./scripts/terraform/setup-secrets.sh <environment>
# ==============================================================================

#!/bin/bash
set -e

ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
    echo "Error: Environment not specified"
    echo "Usage: ./scripts/terraform/setup-secrets.sh <environment>"
    exit 1
fi

echo "===================================="
echo "Setting up Secrets for $ENVIRONMENT"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_NAME="event-planner"
AWS_REGION="us-east-1"

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to create secret
create_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    echo -e "${YELLOW}Creating secret: $secret_name${NC}"
    
    # Check if secret already exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &>/dev/null; then
        echo -e "${YELLOW}Secret already exists. Updating...${NC}"
        aws secretsmanager put-secret-value \
            --secret-id "$secret_name" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION"
    else
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$description" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION"
    fi
    
    echo -e "${GREEN}✓ Created/Updated: $secret_name${NC}"
    echo ""
}

# Generate passwords
echo -e "${YELLOW}Generating secure passwords...${NC}"
AUTH_DB_PASSWORD=$(generate_password)
EVENT_DB_PASSWORD=$(generate_password)
BOOKING_DB_PASSWORD=$(generate_password)
PAYMENT_DB_PASSWORD=$(generate_password)
DOCUMENTDB_PASSWORD=$(generate_password)
JWT_SECRET=$(openssl rand -base64 64)

echo -e "${GREEN}Passwords generated${NC}"
echo ""

# Create RDS secrets
create_secret \
    "$PROJECT_NAME/$ENVIRONMENT/rds/auth-db/master-password" \
    "$AUTH_DB_PASSWORD" \
    "Auth database master password"

create_secret \
    "$PROJECT_NAME/$ENVIRONMENT/rds/event-db/master-password" \
    "$EVENT_DB_PASSWORD" \
    "Event database master password"

create_secret \
    "$PROJECT_NAME/$ENVIRONMENT/rds/booking-db/master-password" \
    "$BOOKING_DB_PASSWORD" \
    "Booking database master password"

create_secret \
    "$PROJECT_NAME/$ENVIRONMENT/rds/payment-db/master-password" \
    "$PAYMENT_DB_PASSWORD" \
    "Payment database master password"

# Create DocumentDB secret
create_secret \
    "$PROJECT_NAME/$ENVIRONMENT/documentdb/master-password" \
    "{\"username\":\"docdbadmin\",\"password\":\"$DOCUMENTDB_PASSWORD\"}" \
    "DocumentDB master credentials"

# Create JWT secret
create_secret \
    "$PROJECT_NAME/$ENVIRONMENT/jwt/signing-key" \
    "{\"secret\":\"$JWT_SECRET\"}" \
    "JWT signing key for authentication"

echo ""
echo -e "${GREEN}All secrets created successfully!${NC}"
echo ""
echo "Secret ARNs:"
echo "  Auth DB: arn:aws:secretsmanager:$AWS_REGION:ACCOUNT_ID:secret:$PROJECT_NAME/$ENVIRONMENT/rds/auth-db/master-password"
echo "  Event DB: arn:aws:secretsmanager:$AWS_REGION:ACCOUNT_ID:secret:$PROJECT_NAME/$ENVIRONMENT/rds/event-db/master-password"
echo "  Booking DB: arn:aws:secretsmanager:$AWS_REGION:ACCOUNT_ID:secret:$PROJECT_NAME/$ENVIRONMENT/rds/booking-db/master-password"
echo "  Payment DB: arn:aws:secretsmanager:$AWS_REGION:ACCOUNT_ID:secret:$PROJECT_NAME/$ENVIRONMENT/rds/payment-db/master-password"
echo "  DocumentDB: arn:aws:secretsmanager:$AWS_REGION:ACCOUNT_ID:secret:$PROJECT_NAME/$ENVIRONMENT/documentdb/master-password"
echo "  JWT: arn:aws:secretsmanager:$AWS_REGION:ACCOUNT_ID:secret:$PROJECT_NAME/$ENVIRONMENT/jwt/signing-key"
echo ""
echo -e "${YELLOW}Note: Replace ACCOUNT_ID with your actual AWS account ID${NC}"
