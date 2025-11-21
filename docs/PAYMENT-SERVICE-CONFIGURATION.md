# Payment Service Configuration

## Status: ✅ ENABLED

The payment service has been uncommented and fully configured in the infrastructure.

## Configuration Summary

### 1. ECS Service Configuration
**File:** `terraform/modules/ecs/main.tf`

- **Service Name:** payment-service
- **Port:** 8088
- **CPU:** 256 (dev) / 512 (prod)
- **Memory:** 512MB (dev) / 1024MB (prod)
- **Desired Count:** 1 (dev) / 2 (prod)
- **Auto-scaling:** Min 1, Max 2 (dev) / Min 2, Max 4 (prod)

### 2. Database Configuration
**Database:** Connects to `authdb` (same as event-service)
**Schema:** `payment_schema`

**Environment Variables:**
```
PAYMENT_SERVICE_DB_SCHEMA=payment_schema
SPRING_JPA_PROPERTIES_HIBERNATE_DEFAULT_SCHEMA=payment_schema
DATABASE_SCHEMA=payment_schema
SPRING_DATASOURCE_SCHEMA_SEARCH_PATH=payment_schema,public
SPRING_JPA_HIBERNATE_DDL_AUTO=update
SPRING_JPA_DATABASE_PLATFORM=org.hibernate.dialect.PostgreSQLDialect
```

**Database Credentials (from Secrets Manager):**
- SPRING_DATASOURCE_URL
- SPRING_DATASOURCE_USERNAME
- SPRING_DATASOURCE_PASSWORD
- PAYMENT_SERVICE_DB_URL
- PAYMENT_SERVICE_DB_USER
- PAYMENT_SERVICE_DB_PASSWORD

### 3. SQS Queue Configuration

**Queues:**
- `payment_processing_event` - For incoming payment requests
- `payment_completed_event` - For completed payments
- `ticket_purchased_event` - For ticket purchase events

**Environment Variables:**
```
SQS_ENDPOINT=https://sqs.eu-west-1.amazonaws.com
PAYMENT_PROCESSING_EVENT_QUEUE_NAME
PAYMENT_PROCESSING_EVENT_QUEUE_URL
PAYMENT_COMPLETED_EVENT_QUEUE_NAME
PAYMENT_COMPLETED_EVENT_QUEUE_URL
TICKET_PURCHASED_EVENT_QUEUE_NAME
TICKET_PURCHASED_EVENT_QUEUE_URL
```

### 4. Service Discovery
**DNS Name:** `payment-service.eventplanner.local:8088`

**Environment Variable:**
```
PAYMENT_SERVICE_URL=http://payment-service.eventplanner.local:8088
```

### 5. ALB Configuration
**File:** `terraform/modules/alb/main.tf`

- **Path Pattern:** `/api/v1/payments/*`
- **Priority:** 400
- **Health Check:** `/actuator/health`
- **Target Group:** payment-service-tg

### 6. IAM Permissions
**File:** `terraform/modules/iam/main.tf`

**Role:** `payment-service-task-role`

**Permissions:**
- SQS: Send/Receive messages from payment queues
- Secrets Manager: Read database credentials and JWT secrets
- S3: Read/Write to backend files bucket
- CloudWatch: Write logs

### 7. ECR Repository
**File:** `terraform/modules/ecr/main.tf`

**Repository:** `payment-service`
**Image Tag:** `latest`

### 8. Redis Configuration

**Environment Variables:**
```
SPRING_DATA_REDIS_HOST=<elasticache-endpoint>
SPRING_DATA_REDIS_PORT=6379
SPRING_DATA_REDIS_SSL_ENABLED=true
SPRING_DATA_REDIS_TIMEOUT=10000
```

### 9. JWT Configuration

**Environment Variables:**
```
JWT_SECRET=<from-secrets-manager>
JWT_ACCESS_EXPIRATION=3600000
JWT_REFRESH_EXPIRATION=86400000
```

### 10. Service Integration

**Connected Services:**
- **Auth Service:** `http://auth-service.eventplanner.local:8081`
- **Event Service:** `http://event-service.eventplanner.local:8082`
- **Notification Service:** `http://notification-service.eventplanner.local:8085`

## Deployment Steps

1. **Build Docker Image:**
   ```bash
   cd payment-service
   docker build -t payment-service:latest .
   ```

2. **Push to ECR:**
   ```bash
   aws ecr get-login-password --region eu-west-1 --profile gtp-cletus | docker login --username AWS --password-stdin 904570587823.dkr.ecr.eu-west-1.amazonaws.com
   
   docker tag payment-service:latest 904570587823.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-payment-service:latest
   
   docker push 904570587823.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-payment-service:latest
   ```

3. **Apply Terraform:**
   ```bash
   cd terraform/environments/dev
   terraform apply
   ```

4. **Verify Deployment:**
   ```bash
   # Check ECS service
   aws ecs describe-services --cluster event-planner-dev-cluster --services payment-service --region eu-west-1 --profile gtp-cletus
   
   # Check target health
   aws elbv2 describe-target-health --target-group-arn <payment-tg-arn> --region eu-west-1 --profile gtp-cletus
   
   # Test health endpoint
   curl https://api.sankofagrid.com/api/v1/payments/actuator/health
   ```

## Database Schema Setup

The payment service will automatically create its schema on first startup due to:
```
SPRING_JPA_HIBERNATE_DDL_AUTO=update
```

**Schema Name:** `payment_schema`

**Tables will be created in:** `authdb.payment_schema.*`

## Monitoring

**CloudWatch Dashboard:** `event-planner-dev-dashboard`
- Payment service CPU/Memory metrics
- Request count and response time
- Error rates

**CloudWatch Logs:** `/ecs/event-planner/dev/payment-service`

**Service Discovery:** Check DNS resolution
```bash
dig payment-service.eventplanner.local
```

## Security

1. ✅ Database credentials stored in Secrets Manager
2. ✅ JWT secret stored in Secrets Manager
3. ✅ IAM role with least privilege permissions
4. ✅ Network isolation in private subnets
5. ✅ HTTPS only via ALB
6. ✅ Redis SSL/TLS enabled

## Cost Impact

**Development Environment:**
- ECS Task: ~$10/month (1 task, 0.25 vCPU, 512MB)
- ALB Target Group: Included in ALB cost
- CloudWatch Logs: ~$1/month
- **Total Additional Cost:** ~$11/month

**Production Environment:**
- ECS Tasks: ~$40/month (2 tasks, 0.5 vCPU, 1GB each)
- **Total Additional Cost:** ~$41/month

## Next Steps

1. Develop payment service application
2. Build and push Docker image to ECR
3. Run `terraform apply` to deploy infrastructure
4. Test payment endpoints
5. Monitor logs and metrics
6. Scale as needed

## Troubleshooting

**Service won't start:**
- Check CloudWatch logs: `/ecs/event-planner/dev/payment-service`
- Verify database connectivity
- Check Secrets Manager permissions

**Health check failing:**
- Ensure `/actuator/health` endpoint is implemented
- Check security group allows ALB → ECS on port 8084
- Verify Spring Boot actuator dependency

**Database connection issues:**
- Verify `payment_schema` exists in authdb
- Check database credentials in Secrets Manager
- Ensure security group allows ECS → RDS on port 5432

## Configuration Complete ✅

All infrastructure components for payment service are now configured and ready for deployment.
