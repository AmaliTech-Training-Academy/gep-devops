# Grafana Monitoring - Deployment Summary

## Overview

Grafana monitoring infrastructure has been provisioned in the `grafana-monitor` Terraform module. This provides monitoring dashboards accessible to non-engineering teams without AWS console access.

## What Was Created

### Infrastructure Components

1. **EC2 Instance**
   - Type: t3.small (2 vCPU, 2GB RAM)
   - Location: Private application subnet
   - OS: Amazon Linux 2023
   - Storage: 20GB gp3 EBS (encrypted)
   - Auto-installed: Grafana via user data script

2. **IAM Role & Permissions**
   - CloudWatch read access (metrics, logs, alarms)
   - EC2 describe permissions
   - SSM Session Manager access (no SSH keys needed)

3. **Security Groups**
   - Grafana SG: Allows port 3000 from ALB
   - Updated RDS SG: Allows port 5432 from Grafana
   - Outbound: HTTPS (CloudWatch API), PostgreSQL (RDS)

4. **ALB Integration**
   - Target Group: `grafana-monitoring-tg`
   - Health Check: `/api/health` every 30s
   - Listener Rule: `/monitoring/*` → Grafana (Priority 1)

5. **CloudWatch Alarms**
   - Grafana CPU > 80%
   - Unhealthy target detection

## Module Location

```
terraform/modules/grafana-monitor/
├── main.tf          # Main infrastructure configuration
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── README.md        # Module documentation
└── DEPLOYMENT.md    # Deployment guide
```

## Integration in Dev Environment

The module is integrated in `terraform/environments/dev/main.tf`:

```hcl
module "grafana_monitor" {
  source = "../../modules/grafana-monitor"

  project_name = var.project_name
  environment  = var.environment

  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.private_app_subnet_ids[0]
  alb_security_group_id = module.security_groups.alb_security_group_id
  rds_security_group_id = module.security_groups.rds_security_group_id

  alb_listener_arn = module.alb.https_listener_arn
  alb_arn_suffix   = module.alb.alb_arn_suffix
  alb_domain_name  = "api.sankofagrid.com"

  grafana_admin_password = var.grafana_admin_password
  listener_rule_priority = 1

  alarm_actions = [module.cloudwatch.sns_topic_arn]
  tags          = local.common_tags
}
```

## Deployment Steps

### 1. Set Admin Password
```bash
export TF_VAR_grafana_admin_password="YourStrongPassword123!"
```

### 2. Deploy Infrastructure
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Access Grafana
```bash
# Get URL
terraform output grafana_url

# Output: https://api.sankofagrid.com/monitoring/
```

Login:
- Username: `admin`
- Password: `<your-password>`

### 4. Configure Data Sources

**CloudWatch:**
- Name: `AWS CloudWatch`
- Auth: `AWS SDK Default`
- Region: `eu-west-1`

**PostgreSQL:**
- Name: `EventPlanner Database`
- Host: `<rds-endpoint>:5432`
- Database: `eventplannerdb`
- User: `grafana_reader` (create first)
- SSL Mode: `require`

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────────┬────────────────────────────────┘
                             │ HTTPS
                             ▼
                    ┌────────────────┐
                    │   ALB (443)    │
                    │  api.sankofagrid│
                    └────────┬───────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
         /api/v1/auth/*  /monitoring/*   │
                │            │            │
                ▼            ▼            ▼
         ┌──────────┐  ┌──────────┐  (other services)
         │   ECS    │  │ Grafana  │
         │  Tasks   │  │   EC2    │
         └──────────┘  └────┬─────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
                ▼           ▼           ▼
         ┌──────────┐ ┌──────────┐ ┌──────────┐
         │CloudWatch│ │   RDS    │ │   Logs   │
         │   API    │ │(read-only)│ │          │
         └──────────┘ └──────────┘ └──────────┘
```

## Key Features

### 1. Path-Based Routing
- `/monitoring/*` routes to Grafana
- Priority 1 (higher than service routes)
- No conflict with existing API routes

### 2. Security
- Private subnet (no direct internet access)
- IAM role with read-only permissions
- SSL/TLS via ALB
- No SSH keys (Session Manager access)
- User sign-up disabled
- Anonymous access disabled

### 3. Monitoring Capabilities
- **CloudWatch Metrics**: ECS, RDS, ElastiCache, ALB, SQS, SNS
- **CloudWatch Logs**: Application logs, audit logs
- **Database Queries**: Multi-schema PostgreSQL access
- **Custom Dashboards**: Executive, Infrastructure, Performance, Security

### 4. Cost Optimization
- Single t3.small instance: $15/month
- 20GB EBS storage: $2/month
- Minimal data transfer: $1/month
- **Total: ~$18/month**

## Post-Deployment Tasks

### Immediate (Day 1)
- [ ] Access Grafana and change admin password
- [ ] Configure CloudWatch data source
- [ ] Create read-only database user
- [ ] Configure PostgreSQL data source
- [ ] Test data source connections

### Week 1
- [ ] Create Executive Dashboard (events, bookings, revenue)
- [ ] Create Infrastructure Dashboard (CPU, memory, connections)
- [ ] Create Performance Dashboard (latency, errors)
- [ ] Set up email notifications
- [ ] Create critical alerts (service down, high errors)

### Week 2
- [ ] Create user accounts for team members
- [ ] Assign appropriate roles (Admin/Editor/Viewer)
- [ ] Document dashboard usage
- [ ] Train team on dashboard interpretation

### Month 1
- [ ] Review dashboard effectiveness
- [ ] Gather user feedback
- [ ] Add custom application metrics
- [ ] Optimize queries for performance

## Database User Setup

Create read-only user for Grafana:

```sql
-- Connect to RDS
psql -h <rds-endpoint> -U dbadmin -d eventplannerdb

-- Create user
CREATE USER grafana_reader WITH PASSWORD '<strong-password>';
GRANT CONNECT ON DATABASE eventplannerdb TO grafana_reader;

-- Grant schema access
GRANT USAGE ON SCHEMA auth_schema TO grafana_reader;
GRANT USAGE ON SCHEMA event_schema TO grafana_reader;
GRANT USAGE ON SCHEMA booking_schema TO grafana_reader;
GRANT USAGE ON SCHEMA payment_schema TO grafana_reader;
GRANT USAGE ON SCHEMA audit_schema TO grafana_reader;

-- Grant SELECT on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA auth_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA event_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA booking_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA payment_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA audit_schema TO grafana_reader;

-- Grant SELECT on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA auth_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA event_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA booking_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA payment_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit_schema GRANT SELECT ON TABLES TO grafana_reader;
```

## Dashboard Examples

### Executive Dashboard Queries

**Total Events (Today):**
```sql
SELECT COUNT(*) 
FROM event_schema.events 
WHERE DATE(created_at) = CURRENT_DATE;
```

**Total Revenue (This Month):**
```sql
SELECT SUM(amount) 
FROM payment_schema.payments 
WHERE status = 'completed' 
  AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE);
```

**Active Users:**
```sql
SELECT COUNT(DISTINCT user_id) 
FROM auth_schema.users 
WHERE is_active = true;
```

### Infrastructure Dashboard Metrics

**ECS CPU Utilization:**
- Namespace: `AWS/ECS`
- Metric: `CPUUtilization`
- Dimension: `ClusterName=event-planner-dev-cluster`

**RDS Connections:**
- Namespace: `AWS/RDS`
- Metric: `DatabaseConnections`
- Dimension: `DBInstanceIdentifier=event-planner-dev-auth-db`

**ElastiCache Hit Rate:**
- Namespace: `AWS/ElastiCache`
- Metric: `CacheHitRate`
- Dimension: `ReplicationGroupId=event-planner-dev-redis`

## Troubleshooting

### Cannot Access Grafana
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw grafana_target_group_arn)

# Check Grafana service
aws ssm start-session --target $(terraform output -raw grafana_instance_id)
sudo systemctl status grafana-server
```

### CloudWatch Data Not Showing
```bash
# Verify IAM permissions
aws iam get-role-policy \
  --role-name <grafana-role> \
  --policy-name cloudwatch-access

# Test CloudWatch API
aws cloudwatch list-metrics --namespace AWS/ECS
```

### Database Connection Failed
```bash
# Test connectivity
aws ssm start-session --target $(terraform output -raw grafana_instance_id)
psql -h <rds-endpoint> -U grafana_reader -d eventplannerdb
```

## Maintenance

### Update Grafana
```bash
aws ssm start-session --target $(terraform output -raw grafana_instance_id)
sudo yum update grafana -y
sudo systemctl restart grafana-server
```

### Backup Grafana
```bash
aws ssm start-session --target $(terraform output -raw grafana_instance_id)
sudo cp /var/lib/grafana/grafana.db /tmp/grafana_backup_$(date +%Y%m%d).db
```

### View Logs
```bash
aws ssm start-session --target $(terraform output -raw grafana_instance_id)
sudo tail -f /var/log/grafana/grafana.log
sudo journalctl -u grafana-server -f
```

## Outputs

After deployment, Terraform provides:

```bash
# Grafana URL
terraform output grafana_url

# Instance details
terraform output grafana_instance_id
terraform output grafana_instance_private_ip

# Security group
terraform output grafana_security_group_id
```

## Files Created

1. **Module Files:**
   - `terraform/modules/grafana-monitor/main.tf`
   - `terraform/modules/grafana-monitor/variables.tf`
   - `terraform/modules/grafana-monitor/outputs.tf`
   - `terraform/modules/grafana-monitor/README.md`
   - `terraform/modules/grafana-monitor/DEPLOYMENT.md`

2. **Environment Integration:**
   - Updated: `terraform/environments/dev/main.tf`
   - Updated: `terraform/environments/dev/variables.tf`
   - Updated: `terraform/environments/dev/outputs.tf`

3. **Documentation:**
   - This file: `GRAFANA-DEPLOYMENT-SUMMARY.md`

## Next Steps

1. **Deploy the infrastructure:**
   ```bash
   cd terraform/environments/dev
   export TF_VAR_grafana_admin_password="YourPassword"
   terraform apply
   ```

2. **Access Grafana:**
   - URL: https://api.sankofagrid.com/monitoring/
   - Login with admin credentials

3. **Configure data sources:**
   - CloudWatch (automatic via IAM)
   - PostgreSQL (create grafana_reader user first)

4. **Create dashboards:**
   - Executive metrics
   - Infrastructure monitoring
   - Performance tracking
   - Security auditing

5. **Set up users and alerts:**
   - Create team member accounts
   - Configure email notifications
   - Set up critical alerts

## Support

For detailed deployment instructions, see:
- `terraform/modules/grafana-monitor/DEPLOYMENT.md`
- `terraform/modules/grafana-monitor/README.md`
- Original plan: `GRAFANA-MONITORING-PLAN.md`

For issues:
- Check CloudWatch alarms
- Review Grafana logs
- Contact DevOps team
