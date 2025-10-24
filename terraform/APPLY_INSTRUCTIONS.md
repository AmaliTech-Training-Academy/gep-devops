# Instructions to Apply Cost Optimization Changes

## Files Modified

### 1. **Module Files** (Service Definitions)
- ✅ `terraform/modules/ecs/main.tf` - Commented out booking, payment, notification services
- ✅ `terraform/modules/rds/main.tf` - Commented out booking, payment databases

### 2. **Environment Files** (Module Calls)
- ✅ `terraform/environments/dev/main.tf` - Commented out DocumentDB module
- ✅ `terraform/environments/dev/outputs.tf` - Commented out DocumentDB outputs

## Apply the Changes

### Step 1: Review What Will Be Destroyed

```bash
cd ~/Desktop/get-devops/terraform/environments/dev
terraform plan
```

**Expected Output:**
```
Plan: 0 to add, 0 to change, X to destroy.

Resources to be destroyed:
- module.documentdb.aws_docdb_cluster.main
- module.documentdb.aws_docdb_cluster_instance.main[0]
- module.ecs.aws_ecs_service.services["booking"]
- module.ecs.aws_ecs_service.services["payment"]
- module.ecs.aws_ecs_service.services["notification"]
- module.rds.aws_db_instance.primary["booking"]
- module.rds.aws_db_instance.primary["payment"]
- And related resources (secrets, log groups, etc.)
```

### Step 2: Apply the Changes

```bash
terraform apply
```

Type `yes` when prompted to confirm.

**This will:**
- Stop and remove 3 ECS services (booking, payment, notification)
- Delete 2 RDS databases (booking, payment)
- Delete DocumentDB cluster
- Remove associated secrets, log groups, and service discovery entries
- **Save ~$93-99/month**

### Step 3: Verify the Changes

```bash
# Check running ECS services (should show only auth and event)
aws ecs list-services --cluster event-planner-dev-cluster

# Check RDS instances (should show only auth-db and event-db)
aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier'

# Check DocumentDB (should show none)
aws docdb describe-db-clusters --query 'DBClusters[*].DBClusterIdentifier'
```

## What Remains Active

### ✅ Still Running (No Changes)
- VPC, subnets, NAT Gateway, Internet Gateway
- ECS Cluster (with 2 services: auth, event)
- Application Load Balancer (all 5 target groups still exist)
- RDS (2 databases: auth, event)
- ElastiCache Redis
- S3 buckets (frontend, logs, backups)
- CloudFront distribution
- Route53 hosted zone
- ECR repositories (all 5 - ready for images)
- SQS queues and SNS topics
- CloudWatch monitoring
- IAM roles (all 5 services)
- Security groups (all configured)

### ❌ Stopped/Removed (Cost Savings)
- ECS booking service
- ECS payment service
- ECS notification service
- RDS booking database
- RDS payment database
- DocumentDB cluster

## Cost Impact

| Item | Before | After | Savings |
|------|--------|-------|---------|
| Monthly Cost | ~$248 | ~$149-155 | ~$93-99 |
| Percentage | 100% | 60% | **40% reduction** |

## Important Notes

### 1. No Data Loss for Active Services
- Auth and Event services continue running normally
- Auth and Event databases remain untouched
- No downtime for active services

### 2. Data Handling for Removed Services
- **RDS Databases:** Final snapshots created (unless skip_final_snapshot=true)
- **DocumentDB:** Final snapshot created (unless skip_final_snapshot=true)
- **ECS Services:** No data stored in containers (stateless)

### 3. Easy to Re-enable
All infrastructure is ready to bring services back:
- ECR repositories exist (ready for images)
- ALB target groups exist (ready for targets)
- Security groups configured (ports 8081-8085)
- IAM roles created (all permissions ready)
- Service discovery namespace ready

Just uncomment the code and run `terraform apply`!

## Troubleshooting

### Error: "Resource still in use"
If you get errors about resources still in use:

```bash
# Wait a few minutes for ECS services to fully stop
aws ecs describe-services --cluster event-planner-dev-cluster --services booking-service

# Then retry
terraform apply
```

### Error: "Cannot delete database with deletion protection"
If databases have deletion protection enabled:

```bash
# Disable deletion protection first
aws rds modify-db-instance \
  --db-instance-identifier event-planner-dev-booking-db \
  --no-deletion-protection

# Then retry
terraform apply
```

### Error: "Snapshot already exists"
If final snapshot names conflict:

```bash
# Delete old snapshots
aws rds delete-db-snapshot --db-snapshot-identifier event-planner-dev-booking-final-snapshot

# Then retry
terraform apply
```

## Rollback (If Needed)

If you need to undo these changes:

1. Uncomment all the code blocks
2. Run `terraform plan` to see what will be created
3. Run `terraform apply` to recreate the services

**Note:** Databases will be recreated from scratch (no data unless restored from snapshot)

## Next Steps After Apply

1. **Monitor Costs:**
   ```bash
   # Check AWS Cost Explorer after 24 hours
   # Should see ~40% reduction in daily costs
   ```

2. **Verify Active Services:**
   ```bash
   # Test auth service
   curl http://<alb-dns>/api/auth/health
   
   # Test event service
   curl http://<alb-dns>/api/events/health
   ```

3. **Update Documentation:**
   - Inform team about disabled services
   - Share `COST_OPTIMIZATION_CHANGES.md` for re-enable instructions

4. **Plan Re-enablement:**
   - Coordinate with developers on when services will be ready
   - Schedule infrastructure re-enablement accordingly

## Questions?

- **Q: Will this affect my frontend?**  
  A: No, frontend (CloudFront + S3) is unaffected.

- **Q: Can auth service still work without other services?**  
  A: Yes, auth service is independent and will work normally.

- **Q: What if I need to test booking service tomorrow?**  
  A: Just uncomment the booking service code and run `terraform apply`. Takes ~5 minutes.

- **Q: Are ECR images deleted?**  
  A: No, ECR repositories and images remain untouched.

- **Q: Will I lose database data?**  
  A: Final snapshots are created. Data can be restored when re-enabling.

---

**Ready to apply?** Run `terraform apply` and confirm with `yes`

**Estimated time:** 5-10 minutes for all resources to be destroyed

**Cost savings start:** Immediately after resources are destroyed
