# Grafana Monitoring Deployment Guide

This guide walks through deploying the Grafana monitoring infrastructure.

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured
- Existing infrastructure deployed (VPC, ALB, RDS, ECS)
- Strong password for Grafana admin user

## Step 1: Set Grafana Admin Password

You have three options to provide the Grafana admin password:

### Option A: Environment Variable (Recommended)
```bash
export TF_VAR_grafana_admin_password="YourStrongPassword123!"
```

### Option B: terraform.tfvars (Not Recommended - Security Risk)
```hcl
# terraform/environments/dev/terraform.tfvars
grafana_admin_password = "YourStrongPassword123!"
```

### Option C: AWS Secrets Manager (Best Practice)
```bash
# Store password in Secrets Manager
aws secretsmanager create-secret \
  --name event-planner/dev/grafana-admin-password \
  --secret-string "YourStrongPassword123!" \
  --region eu-west-1

# Reference in Terraform (requires data source modification)
```

## Step 2: Initialize and Plan

```bash
cd terraform/environments/dev

# Initialize Terraform (if not already done)
terraform init

# Review the changes
terraform plan
```

Expected resources to be created:
- 1 EC2 instance (t3.small)
- 1 IAM role + instance profile
- 1 Security group
- 2 Security group rules (ingress/egress)
- 1 ALB target group
- 1 ALB listener rule
- 2 CloudWatch alarms

## Step 3: Deploy

```bash
terraform apply
```

Review the plan and type `yes` to confirm.

Deployment takes approximately 3-5 minutes:
- EC2 instance launch: ~1 minute
- Grafana installation (user data): ~2-3 minutes
- Health checks: ~1 minute

## Step 4: Verify Deployment

### Check EC2 Instance Status
```bash
# Get instance ID from Terraform output
terraform output grafana_instance_id

# Check instance status
aws ec2 describe-instance-status \
  --instance-ids $(terraform output -raw grafana_instance_id) \
  --region eu-west-1
```

### Check Target Group Health
```bash
# Get target group ARN
terraform output -json | jq -r '.grafana_target_group_arn.value'

# Check health status
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region eu-west-1
```

Expected output:
```json
{
  "TargetHealthDescriptions": [
    {
      "Target": {
        "Id": "i-xxxxx",
        "Port": 3000
      },
      "HealthCheckPort": "3000",
      "TargetHealth": {
        "State": "healthy"
      }
    }
  ]
}
```

### Check Grafana Logs (via Session Manager)
```bash
# Connect to instance
aws ssm start-session \
  --target $(terraform output -raw grafana_instance_id) \
  --region eu-west-1

# Inside the instance
sudo journalctl -u grafana-server -f
sudo tail -f /var/log/grafana/grafana.log
```

## Step 5: Access Grafana

```bash
# Get Grafana URL
terraform output grafana_url
```

Open the URL in your browser:
```
https://api.sankofagrid.com/monitoring/
```

Login credentials:
- Username: `admin`
- Password: `<your-grafana-admin-password>`

## Step 6: Configure Data Sources

### CloudWatch Data Source

1. Navigate to: Configuration → Data Sources → Add data source
2. Select: **CloudWatch**
3. Configure:
   - **Name**: `AWS CloudWatch`
   - **Authentication Provider**: `AWS SDK Default` (uses IAM role)
   - **Default Region**: `eu-west-1`
   - **Namespaces**: Select all (ECS, RDS, ElastiCache, ALB, etc.)
4. Click **Save & Test**

Expected result: ✅ "Data source is working"

### PostgreSQL Data Source

First, create a read-only database user:

```bash
# Connect to RDS instance
psql -h <rds-endpoint> -U dbadmin -d eventplannerdb

# Create read-only user
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

Then configure in Grafana:

1. Navigate to: Configuration → Data Sources → Add data source
2. Select: **PostgreSQL**
3. Configure:
   - **Name**: `EventPlanner Database`
   - **Host**: `<rds-endpoint>:5432`
   - **Database**: `eventplannerdb`
   - **User**: `grafana_reader`
   - **Password**: `<grafana-reader-password>`
   - **SSL Mode**: `require`
   - **Version**: `15.x`
4. Click **Save & Test**

Expected result: ✅ "Database Connection OK"

## Step 7: Import Dashboards

### Option A: Create Custom Dashboards
Follow the Grafana documentation to create dashboards for:
- Executive metrics (events, bookings, revenue)
- Infrastructure (ECS, RDS, ElastiCache)
- Performance (latency, errors)
- Security (failed auth, audit logs)

### Option B: Import Pre-built Dashboards
```bash
# AWS CloudWatch dashboards
# Dashboard ID: 11099 (AWS ECS)
# Dashboard ID: 707 (AWS RDS)
```

1. Navigate to: Dashboards → Import
2. Enter Dashboard ID
3. Select CloudWatch data source
4. Click **Import**

## Step 8: Configure Alerting (Optional)

### Email Notifications

1. Navigate to: Alerting → Contact points → New contact point
2. Configure:
   - **Name**: `DevOps Team`
   - **Integration**: `Email`
   - **Addresses**: `devops@sankofagrid.com`
3. Click **Save contact point**

### Create Alert Rules

Example: High CPU Alert
1. Navigate to: Alerting → Alert rules → New alert rule
2. Configure:
   - **Query**: CloudWatch metric for ECS CPU
   - **Condition**: `avg() > 80`
   - **Evaluation**: Every 5 minutes for 10 minutes
   - **Contact point**: DevOps Team
3. Click **Save**

## Troubleshooting

### Issue: Cannot access Grafana URL

**Check ALB listener rule:**
```bash
aws elbv2 describe-rules \
  --listener-arn $(terraform output -raw alb_listener_arn) \
  --region eu-west-1
```

Verify `/monitoring/*` rule exists with priority 1.

**Check security groups:**
```bash
# ALB → Grafana
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$(terraform output -raw grafana_security_group_id)" \
  --region eu-west-1
```

### Issue: Target is unhealthy

**Check Grafana service:**
```bash
# Connect via Session Manager
aws ssm start-session --target $(terraform output -raw grafana_instance_id)

# Check service status
sudo systemctl status grafana-server

# Check logs
sudo journalctl -u grafana-server -n 50
```

**Common fixes:**
```bash
# Restart Grafana
sudo systemctl restart grafana-server

# Check configuration
sudo cat /etc/grafana/grafana.ini

# Test health endpoint
curl http://localhost:3000/api/health
```

### Issue: CloudWatch data not showing

**Verify IAM permissions:**
```bash
# Get instance profile
aws iam get-instance-profile \
  --instance-profile-name $(terraform output -raw grafana_instance_id | xargs -I {} aws ec2 describe-instances --instance-ids {} --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text | cut -d'/' -f2)

# Check attached policies
aws iam list-attached-role-policies --role-name <role-name>
aws iam list-role-policies --role-name <role-name>
```

**Test CloudWatch access from instance:**
```bash
# Connect via Session Manager
aws ssm start-session --target $(terraform output -raw grafana_instance_id)

# Test CloudWatch API
aws cloudwatch list-metrics --namespace AWS/ECS --region eu-west-1
```

### Issue: Database connection fails

**Check security group rules:**
```bash
# Grafana → RDS
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$(terraform output -raw rds_security_group_id)" \
  --region eu-west-1
```

**Test database connectivity:**
```bash
# Connect via Session Manager
aws ssm start-session --target $(terraform output -raw grafana_instance_id)

# Install PostgreSQL client
sudo yum install postgresql15 -y

# Test connection
psql -h <rds-endpoint> -U grafana_reader -d eventplannerdb
```

## Maintenance

### Update Grafana
```bash
# Connect via Session Manager
aws ssm start-session --target $(terraform output -raw grafana_instance_id)

# Update Grafana
sudo yum update grafana -y
sudo systemctl restart grafana-server

# Verify version
grafana-server -v
```

### Backup Grafana
```bash
# Connect via Session Manager
aws ssm start-session --target $(terraform output -raw grafana_instance_id)

# Backup database
sudo cp /var/lib/grafana/grafana.db /tmp/grafana_backup_$(date +%Y%m%d).db

# Download backup (from local machine)
aws ssm start-session \
  --target $(terraform output -raw grafana_instance_id) \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["22"],"localPortNumber":["2222"]}'

# In another terminal
scp -P 2222 ec2-user@localhost:/tmp/grafana_backup_*.db ./
```

### Change Admin Password
```bash
# Connect via Session Manager
aws ssm start-session --target $(terraform output -raw grafana_instance_id)

# Reset password
sudo grafana-cli admin reset-admin-password <new-password>
```

## Cleanup

To remove Grafana infrastructure:

```bash
cd terraform/environments/dev

# Remove Grafana module from main.tf
# Comment out or delete the grafana_monitor module block

# Apply changes
terraform apply

# Or destroy specific resources
terraform destroy -target=module.grafana_monitor
```

## Cost Monitoring

Monitor Grafana costs:
```bash
# Get instance cost
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://filter.json

# filter.json
{
  "Tags": {
    "Key": "Name",
    "Values": ["event-planner-grafana-dev"]
  }
}
```

Expected monthly cost: ~$18
- EC2 t3.small: $15
- EBS 20GB gp3: $2
- Data transfer: $1

## Next Steps

1. Create custom dashboards for your application metrics
2. Set up alerting rules for critical metrics
3. Configure user accounts for team members
4. Document dashboard usage for non-technical users
5. Schedule regular backups
6. Consider migration to Amazon Managed Grafana for production

## Support

For issues or questions:
- Check Grafana logs: `/var/log/grafana/grafana.log`
- Review CloudWatch alarms
- Contact DevOps team: devops@sankofagrid.com
