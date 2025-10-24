# Cost Optimization Changes - Services Temporarily Disabled

## Summary

To reduce costs while developers are still building the application, the following infrastructure services have been temporarily disabled by commenting them out in the Terraform code.

## Services Disabled

### 1. ECS Services (3 services)
**Location:** `terraform/modules/ecs/main.tf`

- ❌ **Booking Service** (Port 8083)
- ❌ **Payment Service** (Port 8084)  
- ❌ **Notification Service** (Port 8085)

**Services Still Running:**
- ✅ **Auth Service** (Port 8081)
- ✅ **Event Service** (Port 8082)

**Cost Savings:** ~$3-5/month (Fargate compute costs)

### 2. RDS PostgreSQL Databases (2 databases)
**Location:** `terraform/modules/rds/main.tf`

- ❌ **Booking Database** (booking-db)
- ❌ **Payment Database** (payment-db)

**Databases Still Running:**
- ✅ **Auth Database** (auth-db)
- ✅ **Event Database** (event-db)

**Cost Savings:** ~$30/month (2 x db.t3.micro instances @ ~$15/month each)

### 3. DocumentDB Cluster (All instances)
**Location:** `terraform/environments/dev/main.tf`

- ❌ **DocumentDB Cluster** (1 x db.t3.medium instance)
- Used for audit logs (not critical for development)

**Cost Savings:** ~$60/month (db.t3.medium instance)

## Total Monthly Cost Savings

| Service | Monthly Cost | Status |
|---------|--------------|--------|
| Booking ECS Service | ~$1-2 | ❌ Disabled |
| Payment ECS Service | ~$1-2 | ❌ Disabled |
| Notification ECS Service | ~$1-2 | ❌ Disabled |
| Booking RDS Database | ~$15 | ❌ Disabled |
| Payment RDS Database | ~$15 | ❌ Disabled |
| DocumentDB Cluster | ~$60 | ❌ Disabled |
| **Total Savings** | **~$93-99/month** | **40% reduction** |

## New Monthly Cost Estimate

**Before Optimization:** ~$248/month  
**After Optimization:** ~$149-155/month  
**Savings:** ~$93-99/month (40% reduction)

## Services Still Running (Active Infrastructure)

### Compute & Networking
- ✅ VPC with subnets, NAT Gateway, Internet Gateway
- ✅ ECS Fargate Cluster (2 services: auth, event)
- ✅ Application Load Balancer
- ✅ CloudFront CDN
- ✅ S3 Buckets (frontend, logs, backups)

### Data Layer
- ✅ RDS PostgreSQL (2 databases: auth, event)
- ✅ ElastiCache Redis (caching & sessions)

### Supporting Services
- ✅ Route53 (DNS)
- ✅ ECR (Container Registry - all 5 repositories)
- ✅ SQS/SNS (Messaging)
- ✅ CloudWatch (Monitoring & Logging)
- ✅ Secrets Manager
- ✅ IAM Roles & Policies

## How to Re-Enable Services

When developers are ready to deploy the disabled services, follow these steps:

### Step 1: Re-enable ECS Services

**File:** `terraform/modules/ecs/main.tf`

1. Find the `locals` block with `services = {`
2. Uncomment the booking, payment, and notification service blocks:

```hcl
booking = {
  name          = "booking-service"
  port          = 8083
  cpu           = var.environment == "dev" ? 256 : 512
  memory        = var.environment == "dev" ? 512 : 1024
  desired_count = var.environment == "dev" ? 1 : 2
  min_capacity  = var.environment == "dev" ? 1 : 2
  max_capacity  = var.environment == "dev" ? 2 : 4
}
payment = {
  name          = "payment-service"
  port          = 8084
  cpu           = var.environment == "dev" ? 256 : 512
  memory        = var.environment == "dev" ? 512 : 1024
  desired_count = var.environment == "dev" ? 1 : 2
  min_capacity  = var.environment == "dev" ? 1 : 2
  max_capacity  = var.environment == "dev" ? 2 : 4
}
notification = {
  name          = "notification-service"
  port          = 8085
  cpu           = var.environment == "dev" ? 256 : 512
  memory        = var.environment == "dev" ? 512 : 1024
  desired_count = var.environment == "dev" ? 1 : 2
  min_capacity  = var.environment == "dev" ? 1 : 1
  max_capacity  = var.environment == "dev" ? 2 : 3
}
```

3. Uncomment the service URL environment variables (search for "BOOKING_SERVICE_URL", "PAYMENT_SERVICE_URL", "NOTIFICATION_SERVICE_URL")

### Step 2: Re-enable RDS Databases

**File:** `terraform/modules/rds/main.tf`

1. Find the `locals` block with `databases = {`
2. Uncomment the booking and payment database blocks:

```hcl
booking = {
  instance_class        = var.booking_db_instance_class
  allocated_storage     = var.booking_db_allocated_storage
  max_allocated_storage = var.booking_db_max_allocated_storage
  read_replica_count    = var.create_read_replicas ? 2 : 0
  port                  = 5432
}
payment = {
  instance_class        = var.payment_db_instance_class
  allocated_storage     = var.payment_db_allocated_storage
  max_allocated_storage = var.payment_db_max_allocated_storage
  read_replica_count    = var.create_read_replicas ? 2 : 0
  port                  = 5432
}
```

### Step 3: Re-enable DocumentDB (Optional)

**File:** `terraform/environments/dev/main.tf`

1. Find the commented DocumentDB module block
2. Uncomment the entire `module "documentdb" {` block
3. In the ECS module call, uncomment the real docdb_endpoint line:

```hcl
docdb_endpoint = module.documentdb.cluster_endpoint
```

4. Comment out or remove the placeholder line:

```hcl
# docdb_endpoint = "localhost" # Remove this line
```

### Step 4: Apply Changes

```bash
cd terraform/environments/dev

# Review what will be created
terraform plan

# Apply the changes
terraform apply

# Verify services are running
aws ecs list-services --cluster event-planner-dev-cluster
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]'
```

### Step 5: Deploy Application Code

Once infrastructure is ready:

```bash
# Build and push Docker images to ECR
docker build -t booking-service:latest ./booking-service
docker tag booking-service:latest <account-id>.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-booking-service:latest
docker push <account-id>.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-booking-service:latest

# ECS will automatically pull and deploy
```

## Important Notes

### 1. ECR Repositories Still Exist
All 5 ECR repositories are still created and available:
- event-planner-dev-auth-service ✅
- event-planner-dev-event-service ✅
- event-planner-dev-booking-service ✅ (ready for images)
- event-planner-dev-payment-service ✅ (ready for images)
- event-planner-dev-notification-service ✅ (ready for images)

Developers can push images anytime, but ECS won't deploy them until services are re-enabled.

### 2. ALB Target Groups Still Exist
All target groups are created and configured:
- auth-service (port 8081) ✅
- event-service (port 8082) ✅
- booking-service (port 8083) ✅ (no targets)
- payment-service (port 8084) ✅ (no targets)
- notification-service (port 8085) ✅ (no targets)

When services are re-enabled, they'll automatically register with their target groups.

### 3. Security Groups Allow All Services
Security group rules allow traffic for all 5 services (ports 8081-8085), so no security group changes needed when re-enabling.

### 4. Service Discovery Namespace Ready
AWS Cloud Map namespace (eventplanner.local) is created and ready. When services are re-enabled, they'll automatically register their DNS names.

### 5. IAM Roles Exist for All Services
All IAM task roles are created for all 5 services, so no permission changes needed.

## Monitoring Disabled Services

### CloudWatch Logs
Log groups for disabled services still exist but won't receive new logs:
- `/ecs/event-planner/dev/booking-service` (empty)
- `/ecs/event-planner/dev/payment-service` (empty)
- `/ecs/event-planner/dev/notification-service` (empty)

These can be safely deleted to save a few cents/month:

```bash
aws logs delete-log-group --log-group-name /ecs/event-planner/dev/booking-service
aws logs delete-log-group --log-group-name /ecs/event-planner/dev/payment-service
aws logs delete-log-group --log-group-name /ecs/event-planner/dev/notification-service
```

They'll be recreated automatically when services are re-enabled.

### CloudWatch Alarms
Alarms for disabled databases won't trigger (no data):
- booking-db CPU/storage/connections alarms (no data)
- payment-db CPU/storage/connections alarms (no data)
- DocumentDB alarms (no data)

## Testing After Re-enabling

### 1. Verify ECS Services
```bash
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services booking-service payment-service notification-service \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]'
```

### 2. Verify Databases
```bash
aws rds describe-db-instances \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `booking`) || contains(DBInstanceIdentifier, `payment`)].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]'
```

### 3. Verify Service Discovery
```bash
aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=<namespace-id> \
  --query 'Services[*].[Name,Id]'
```

### 4. Test Connectivity
```bash
# From within VPC (e.g., from auth-service container)
curl http://booking-service.eventplanner.local:8083/actuator/health
curl http://payment-service.eventplanner.local:8084/actuator/health
curl http://notification-service.eventplanner.local:8085/actuator/health
```

## Rollback Plan

If you need to disable services again:

```bash
cd terraform/environments/dev

# Comment out the services in the code (reverse the steps above)

# Plan the destruction
terraform plan

# Apply to remove resources
terraform apply

# Verify services are stopped
aws ecs list-services --cluster event-planner-dev-cluster
```

## Questions?

- **Q: Will this break existing services?**  
  A: No. Auth and Event services continue running normally. They just won't be able to call the disabled services.

- **Q: What happens to data when databases are disabled?**  
  A: Final snapshots are created (unless skip_final_snapshot=true). Data can be restored when re-enabling.

- **Q: Can I enable just one service?**  
  A: Yes. Uncomment only the service you need and run terraform apply.

- **Q: Do I need to update application code?**  
  A: No code changes needed. Services will automatically discover each other when re-enabled.

- **Q: What about the cost of keeping ECR repositories?**  
  A: ECR repositories cost ~$0.10/GB/month for storage. Empty repositories cost nothing.

## Cost Optimization Tips

While services are disabled, consider:

1. **Stop dev environment after hours:**
   ```bash
   # Stop ECS services at 6 PM
   aws ecs update-service --cluster event-planner-dev-cluster --service auth-service --desired-count 0
   aws ecs update-service --cluster event-planner-dev-cluster --service event-service --desired-count 0
   
   # Start at 8 AM
   aws ecs update-service --cluster event-planner-dev-cluster --service auth-service --desired-count 1
   aws ecs update-service --cluster event-planner-dev-cluster --service event-service --desired-count 1
   ```

2. **Use Fargate Spot for additional 70% savings:**
   In `terraform/environments/dev/main.tf`, set:
   ```hcl
   enable_fargate_spot = true
   ```

3. **Reduce RDS instance sizes:**
   Change from db.t3.micro to db.t3.micro (already smallest)

4. **Delete old CloudWatch Logs:**
   ```bash
   aws logs delete-log-group --log-group-name /aws/vpc/flowlogs
   ```

---

**Last Updated:** January 2025  
**Maintained By:** DevOps Team  
**Estimated Savings:** $93-99/month (40% reduction)
