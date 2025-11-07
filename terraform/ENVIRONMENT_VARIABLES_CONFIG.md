# Environment Variables Configuration

## Summary
All ECS services are now configured with the required JWT and AWS endpoint environment variables in Terraform.

## Configuration Applied

### All Services (auth, event, notification, booking, payment)

#### JWT Configuration
- `JWT_ACCESS_EXPIRATION`: 3600000 (1 hour)
- `JWT_REFRESH_EXPIRATION`: 86400000 (24 hours)
- `JWT_SECRET`: Retrieved from AWS Secrets Manager

#### AWS Configuration
- `AWS_ENDPOINT`: https://s3.eu-west-1.amazonaws.com
- `AWS_REGION`: eu-west-1

### Service-Specific Details

#### Auth Service
- ✅ JWT_ACCESS_EXPIRATION
- ✅ JWT_REFRESH_EXPIRATION
- ✅ JWT_SECRET (from Secrets Manager)
- ✅ AWS_ENDPOINT

#### Event Service
- ✅ JWT_ACCESS_EXPIRATION
- ✅ JWT_REFRESH_EXPIRATION
- ✅ JWT_SECRET (from Secrets Manager)
- ✅ AWS_ENDPOINT

#### Notification Service
- ✅ JWT_ACCESS_EXPIRATION
- ✅ JWT_REFRESH_EXPIRATION
- ✅ JWT_SECRET (from Secrets Manager)
- ✅ AWS_ENDPOINT

#### Booking Service (Ready for deployment)
- ✅ JWT_ACCESS_EXPIRATION
- ✅ JWT_REFRESH_EXPIRATION
- ✅ JWT_SECRET (from Secrets Manager)
- ✅ AWS_ENDPOINT

#### Payment Service (Ready for deployment)
- ✅ JWT_ACCESS_EXPIRATION
- ✅ JWT_REFRESH_EXPIRATION
- ✅ JWT_SECRET (from Secrets Manager)
- ✅ AWS_ENDPOINT

## Terraform File Location
`/terraform/modules/ecs/main.tf`

## How to Apply Changes

1. Navigate to environment directory:
   ```bash
   cd terraform/environments/dev
   ```

2. Plan the changes:
   ```bash
   terraform plan
   ```

3. Apply the changes:
   ```bash
   terraform apply
   ```

## Current Manual Fixes Applied

### Auth Service
- Task Definition Revision: 39
- Status: Deployed with AWS_ENDPOINT

### Event Service
- Task Definition Revision: 14
- Status: Deployed with JWT variables and AWS_ENDPOINT

## Notes
- All services can now access JWT secrets for token validation
- AWS S3 endpoint is properly configured for all services
- Configuration is region-aware (uses var.aws_region)
- Future deployments via Terraform will automatically include these variables
