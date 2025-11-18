# Event Planner Platform - DevOps Infrastructure Documentation

## Part 5: Monitoring, Security, and Operations

**Author:** DevOps Team  
**Last Updated:** November 18, 2025  
**Version:** 1.0.0

---

## Overview

This document explains external monitoring setup on Grafana. It is a unique monitoring solution for stakeholders who do not have access to AWS console.
It details the Grafana setup, backup and restoration of dashboard configuration, technical guide, and usage guide.
For DevOps engineer interested in setup and configuration, refer to [Grafana Monitoring Setup](#grafana-monitoring-setup) section
For Usage guideline, refer to [Grafana Monitoring Usage](#grafana-monitoring-usage-guidelines) section

## Grafana Monitoring Setup

### Setup Overview

Grafana monitoring infrastructure provides a centralized, web-based dashboarding solution accessible to all stakeholders without requiring AWS Console access. The solution is deployed as a containerized monitoring system on EC2, integrated with the existing ALB via path-based routing at `/monitoring/*`.

**Key Benefits:**

- **No AWS Console Access Required**: Non-DevOps stakeholders can view metrics without AWS credentials
- **Multi-Audience Dashboard**: Executive, Infrastructure, Performance, and Security dashboards tailored to different teams
- **Cost-Effective**: Single t3.micro instance (~$18/month) replaces dedicated monitoring infrastructure
- **Read-Only Database Access**: PostgreSQL read-only user for database metrics and audit logs
- **Secure Path Integration**: Leverages existing ALB with HTTPS/SSL termination

### Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                     Internet Users (HTTPS)                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │ HTTPS Port 443
                              ▼
                      ┌───────────────────┐
                      │  ALB (Existing)   │
                      │ api.sankofagrid   │
                      └────────┬──────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
           /api/*         /monitoring/*   (other routes)
                │              │              │
                ▼              ▼              ▼
         ┌─────────────┐  ┌──────────┐  (services)
         │ ECS Services│  │ Grafana  │
         └─────────────┘  │ EC2      │
                          │(3000)    │
                          └────┬─────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
          ┌──────────┐   ┌──────────┐   ┌──────────┐
          │CloudWatch│   │   RDS    │   │ CloudWatch│
          │  Metrics │   │ PostgreSQL│   │  Logs    │
          └──────────┘   └──────────┘   └──────────┘
```

### Infrastructure Components

#### 1. EC2 Instance

**Specifications:**

- **Instance Type**: t3.micro (or t3.small for production)
- **vCPU**: 2
- **Memory**: 1GB RAM
- **Operating System**: Amazon Linux 2023
- **Storage**: 20GB gp3 EBS (encrypted)
- **Network**: Private Application Subnet (no direct internet access)
- **Access Method**: AWS Systems Manager Session Manager (no SSH keys required)

**Instance Configuration:**

```bash
# SSH into instance via Session Manager (no keys needed)
aws ssm start-session --target <instance-id>

# Check Grafana service status
sudo systemctl status grafana-server

# View Grafana logs
sudo tail -f /var/log/grafana/grafana.log
```

#### 2. IAM Role & Permissions

**Role Name**: `<project>-<environment>-grafana-role`

**Attached Policies:**

The following IAM policies are attached to the Grafana EC2 role:

##### CloudWatch Read Access

```json
{
  "Effect": "Allow",
  "Action": [
    "cloudwatch:DescribeAlarmsForMetric",
    "cloudwatch:DescribeAlarmHistory",
    "cloudwatch:DescribeAlarms",
    "cloudwatch:ListMetrics",
    "cloudwatch:GetMetricStatistics",
    "cloudwatch:GetMetricData",
    "cloudwatch:GetInsightRuleReport"
  ],
  "Resource": "*"
}
```

##### CloudWatch Logs Access

```json
{
  "Effect": "Allow",
  "Action": [
    "logs:DescribeLogGroups",
    "logs:GetLogGroupFields",
    "logs:StartQuery",
    "logs:StopQuery",
    "logs:GetQueryResults",
    "logs:GetLogEvents"
  ],
  "Resource": "*"
}
```

##### EC2 Metadata and Tagging

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeTags",
    "ec2:DescribeInstances",
    "ec2:DescribeRegions",
    "ec2:DescribeVolumes"
  ],
  "Resource": "*"
}
```

##### ECS Cluster Information

```json
{
  "Effect": "Allow",
  "Action": [
    "ecs:ListClusters",
    "ecs:ListServices",
    "ecs:ListTasks",
    "ecs:DescribeClusters",
    "ecs:DescribeServices",
    "ecs:DescribeTasks",
    "ecs:DescribeContainerInstances",
    "ecs:DescribeTaskDefinition"
  ],
  "Resource": "*"
}
```

##### AWS Systems Manager Session Manager

```text
AmazonSSMManagedInstanceCore (AWS Managed Policy)
```

**Why These Permissions?**

- **CloudWatch**: Metrics, alarms, and logs for all infrastructure components
- **ECS**: Service and task metrics for application monitoring
- **EC2**: Instance metadata and resource information
- **SSM**: Session Manager access without SSH keys (security best practice)

#### 3. Security Groups

**Grafana Security Group** (`grafana-sg`):

| Direction | Port | Protocol | Source/Destination | Purpose |
|-----------|------|----------|-------------------|---------|
| **Inbound** | 3000 | TCP | ALB Security Group | Grafana web interface from ALB |
| **Outbound** | 443 | TCP | 0.0.0.0/0 | CloudWatch API & SSM calls |
| **Outbound** | 5432 | TCP | RDS Security Group | PostgreSQL database access |
| **Outbound** | 587 | TCP | 0.0.0.0/0 | SMTP (Gmail for email alerts) |
| **Outbound** | 465 | TCP | 0.0.0.0/0 | SMTP SSL (Gmail for email alerts) |

**Related Security Group Updates:**

- **RDS Security Group**: Add inbound rule for port 5432 from Grafana SG
- **ALB Security Group**: Add outbound rule for port 3000 to Grafana SG

#### 4. ALB Integration

**Target Group Configuration:**

- **Name**: `grafana-monitoring-tg`
- **Type**: Instance-based
- **Protocol**: HTTP (ALB handles HTTPS termination)
- **Port**: 3000
- **VPC**: Same as ALB
- **Health Check Path**: `/api/health`
- **Health Check Interval**: 30 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 3 consecutive failures
- **Timeout**: 5 seconds

**Listener Rule Configuration:**

- **ALB Listener**: HTTPS (Port 443)
- **Rule Path Pattern**: `/monitoring/*`
- **Action**: Forward to Grafana target group
- **Priority**: 1 (highest priority - evaluated first)
- **Domain**: `api.sankofagrid.com`

**Final URL**: `https://api.sankofagrid.com/monitoring/`

**Why Path-Based Routing?**

- No additional domain or certificate needed
- Leverages existing ALB infrastructure
- Secure path segregation from API services
- Easy to update rules without ALB downtime

#### 5. Database Access

**PostgreSQL Read-Only User Setup:**

```sql
-- Connect to RDS database as admin
psql -h <rds-endpoint> -U dbadmin -d eventplannerdb

-- Create read-only user
CREATE USER grafana_reader WITH PASSWORD '<strong-password>';
GRANT CONNECT ON DATABASE eventplannerdb TO grafana_reader;

-- Grant access to all schemas
GRANT USAGE ON SCHEMA auth_schema TO grafana_reader;
GRANT USAGE ON SCHEMA event_schema TO grafana_reader;
GRANT USAGE ON SCHEMA booking_schema TO grafana_reader;
GRANT USAGE ON SCHEMA payment_schema TO grafana_reader;
GRANT USAGE ON SCHEMA audit_schema TO grafana_reader;

-- Grant SELECT on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA auth_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA event_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA booking_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA payment_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA audit_schema TO grafana_reader;

-- Grant SELECT on future tables (default privileges)
ALTER DEFAULT PRIVILEGES IN SCHEMA auth_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA event_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA booking_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA payment_schema GRANT SELECT ON TABLES TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit_schema GRANT SELECT ON TABLES TO grafana_reader;
```

**Data Source Configuration in Grafana:**

1. Go to **Configuration → Data Sources → Add data source**
2. Select **PostgreSQL**
3. Configure:
   - **Name**: `EventPlanner Database`
   - **Host**: `<rds-endpoint>:5432`
   - **Database**: `eventplannerdb`
   - **User**: `grafana_reader`
   - **Password**: `<password-set-above>`
   - **SSL Mode**: `require`
   - **Search Path**: `auth_schema,event_schema,booking_schema,payment_schema,audit_schema`
4. Click **Save & Test**

### Deployment Using Terraform IaC

**Module Location**: `terraform/grafana-monitoring-iac/modules/grafana-monitor/`

**Module Files:**

- `main.tf` - Core infrastructure (EC2, IAM, Security Groups, ALB integration)
- `variables.tf` - Input variables and configurations
- `outputs.tf` - Output values (URLs, instance IDs, etc.)
- `README.md` - Detailed module documentation
- `DEPLOYMENT.md` - Step-by-step deployment guide

**Module Integration in Environments:**

The module is integrated in `terraform/environments/<env>/main.tf`:

```hcl
module "grafana_monitor" {
  source = "../../grafana-monitoring-iac/modules/grafana-monitor"

  # Basic configuration
  project_name = var.project_name
  environment  = var.environment
  ami_id       = data.aws_ami.amazon_linux_2023.id

  # Network configuration
  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.private_app_subnet_ids[0]
  alb_security_group_id = module.security_groups.alb_security_group_id
  rds_security_group_id = module.security_groups.rds_security_group_id

  # ALB configuration
  alb_listener_arn = module.alb.https_listener_arn
  alb_arn_suffix   = module.alb.alb_arn_suffix
  alb_domain_name  = "api.sankofagrid.com"

  # Grafana configuration
  grafana_admin_password = var.grafana_admin_password
  instance_type          = var.grafana_instance_type
  volume_size            = var.grafana_volume_size

  # ALB listener rule priority
  listener_rule_priority = 1

  # Alarms
  alarm_actions = [module.cloudwatch.sns_topic_arn]

  # Tags
  tags = local.common_tags

  depends_on = [module.vpc, module.alb, module.security_groups]
}
```

**Key Input Variables:**

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_name` | Yes | - | Project name for resource naming |
| `environment` | Yes | - | Environment (dev, staging, prod) |
| `vpc_id` | Yes | - | VPC ID for Grafana deployment |
| `private_subnet_id` | Yes | - | Private subnet for EC2 instance |
| `alb_security_group_id` | Yes | - | ALB security group ID |
| `rds_security_group_id` | Yes | - | RDS security group ID |
| `alb_listener_arn` | Yes | - | ALB HTTPS listener ARN |
| `alb_arn_suffix` | Yes | - | ALB ARN suffix for alarms |
| `alb_domain_name` | Yes | - | ALB domain (e.g., api.sankofagrid.com) |
| `grafana_admin_password` | Yes | - | Admin password (store in AWS Secrets Manager) |
| `instance_type` | No | t3.micro | EC2 instance type |
| `volume_size` | No | 20 | EBS volume size in GB |
| `listener_rule_priority` | No | 1 | ALB listener rule priority |
| `alarm_actions` | No | [] | SNS topic ARNs for alarms |
| `tags` | No | {} | Additional tags for resources |

**Module Outputs:**

```bash
# Get these after deployment
terraform output grafana_url                    # https://api.sankofagrid.com/monitoring/
terraform output grafana_instance_id            # EC2 instance ID
terraform output grafana_instance_private_ip    # Private IP address
terraform output grafana_security_group_id      # Security group ID
terraform output grafana_target_group_arn       # ALB target group ARN
```

### Deployment Steps

#### Step 1: Prerequisites

**Before deploying, ensure:**

- [ ] Core infrastructure (VPC, ALB, RDS, Security Groups) already deployed
- [ ] ALB has HTTPS listener on port 443 configured
- [ ] RDS database exists with necessary schemas
- [ ] Strong admin password generated (minimum 16 characters, mixed case, numbers, special chars)

**Store Admin Password Securely:**

```bash
# Option 1: AWS Secrets Manager (Recommended)
aws secretsmanager create-secret \
  --name grafana/admin-password \
  --secret-string "YourStrongPassword123!"

# Option 2: AWS Systems Manager Parameter Store
aws ssm put-parameter \
  --name /grafana/admin-password \
  --value "YourStrongPassword123!" \
  --type SecureString
```

#### Step 2: Set Terraform Variables

```bash
cd terraform/environments/dev

# Create/update terraform.tfvars
cat >> terraform.tfvars <<EOF
grafana_admin_password      = "YourStrongPassword123!"
grafana_instance_type       = "t3.micro"
grafana_volume_size         = 20
EOF

# Or export as environment variable
export TF_VAR_grafana_admin_password="YourStrongPassword123!"
```

#### Step 3: Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform (if not already done)
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Get Grafana URL
terraform output grafana_url
# Output: https://api.sankofagrid.com/monitoring/
```

#### Step 4: Configure Data Sources

**CloudWatch Data Source (Automatic via IAM Role):**

1. Login to Grafana: `https://api.sankofagrid.com/monitoring/`
   - Username: `admin`
   - Password: `<your-password>`
2. Go to **Configuration → Data Sources → Add data source**
3. Select **CloudWatch**
4. Configure:
   - **Name**: `AWS CloudWatch`
   - **Authentication Provider**: `AWS SDK Default` (uses IAM role automatically)
   - **Default Region**: `eu-west-1` (or your region)
5. Click **Save & Test**

**PostgreSQL Data Source:**

1. Go to **Configuration → Data Sources → Add data source**
2. Select **PostgreSQL**
3. Enter configuration from [Database Access section](#5-database-access)
4. Click **Save & Test**

#### Step 5: Verify Deployment

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw grafana_target_group_arn) \
  --region eu-west-1

# Expected: TargetHealth.State = healthy

# Check Grafana service
aws ssm start-session --target $(terraform output -raw grafana_instance_id)
sudo systemctl status grafana-server

# Check connectivity
curl -I http://localhost:3000/api/health
# Expected: HTTP/1.0 200 OK
```

### Post-Deployment Configuration

#### Immediate Tasks

- [ ] **Change Admin Password**
  - Login to Grafana
  - Click profile icon → Change password
  - Set strong password (different from initial)

- [ ] **Configure CloudWatch Data Source**
  - Verify it's connected and showing metrics
  - Test with sample query

- [ ] **Create PostgreSQL Read-Only User**
  - Run SQL commands from [Database Access section](#5-database-access)
  - Note credentials for Grafana configuration

- [ ] **Configure PostgreSQL Data Source**
  - Add to Grafana
  - Test connection with sample query

#### Phase 1 Tasks

- [ ] **Create Executive Dashboard**
  - Total events (today, this week, this month)
  - Total bookings and conversion rates
  - Revenue metrics
  - Active users

- [ ] **Create Infrastructure Dashboard**
  - ECS CPU/Memory utilization
  - RDS connections and IOPS
  - ElastiCache hit rates
  - ALB request counts

- [ ] **Create Performance Dashboard**
  - API latency (p50, p95, p99)
  - Error rates by service
  - Database query performance
  - Cache metrics

- [ ] **Set Up Email Notifications**
  - Go to **Configuration → Alerting → Contact Points**
  - Add email addresses for team notifications

#### Phase 2 Tasks

- [ ] **Create User Accounts**
  - Go to **Administration → Users**
  - Create accounts for team members
  - Assign roles: Admin (engineers) / Viewer (stakeholders)

- [ ] **Create Security Dashboard**
  - Failed authentication attempts
  - Suspicious activities from audit logs
  - Error rates and anomalies

- [ ] **Document Dashboards**
  - Create internal wiki with dashboard guides
  - Explain metrics and interpretation
  - List contact info for issues

- [ ] **Train Team**
  - Demo for engineering team
  - Demo for business stakeholders
  - Gather feedback for improvements

### Example Dashboard Queries

#### Executive Dashboard - SQL Queries

**Total Events (Today):**

```sql
SELECT COUNT(*) as total_events
FROM event_schema.events
WHERE DATE(created_at) = CURRENT_DATE;
```

**Total Revenue (This Month):**

```sql
SELECT 
  SUM(amount) as total_revenue,
  COUNT(*) as total_transactions
FROM payment_schema.payments
WHERE status = 'completed'
  AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE);
```

**Active Users:**

```sql
SELECT COUNT(DISTINCT user_id) as active_users
FROM auth_schema.users
WHERE is_active = true;
```

**Booking Conversion Rate:**

```sql
SELECT 
  COUNT(DISTINCT bookings.user_id) as users_who_booked,
  COUNT(DISTINCT events.user_id) as users_who_viewed,
  ROUND(100.0 * COUNT(DISTINCT bookings.user_id) / 
    NULLIF(COUNT(DISTINCT events.user_id), 0), 2) as conversion_rate_percent
FROM event_schema.events
LEFT JOIN booking_schema.bookings ON bookings.event_id = events.id
WHERE DATE(events.created_at) = CURRENT_DATE;
```

#### Infrastructure Dashboard - CloudWatch Metrics

**ECS CPU Utilization:**

- Namespace: `AWS/ECS`
- Metric: `CPUUtilization`
- Dimensions: `ServiceName=auth-service`, `ClusterName=event-planner-dev-cluster`

**RDS Connections:**

- Namespace: `AWS/RDS`
- Metric: `DatabaseConnections`
- Dimension: `DBInstanceIdentifier=event-planner-dev-auth-db`

**ElastiCache Hit Rate:**

- Namespace: `AWS/ElastiCache`
- Metric: `CacheHitRate`
- Dimension: `ReplicationGroupId=event-planner-dev-redis`

**ALB Request Count:**

- Namespace: `AWS/ApplicationELB`
- Metric: `RequestCount`
- Dimension: `LoadBalancer=<alb-name>`

### Maintenance & Operations

#### Regular Monitoring Tasks

**Weekly:**

- Review dashboard accuracy
- Check for any data source connection issues
- Monitor Grafana instance resource usage (CPU, memory, disk)

**Monthly:**

- Review and update dashboard queries
- Check Grafana logs for errors
- Update alert thresholds based on trends
- Review user access and permissions

#### Updating Grafana

```bash
# SSH into instance
aws ssm start-session --target <instance-id>

# Check current version
grafana-server -v

# Update Grafana
sudo yum update grafana -y

# Restart service
sudo systemctl restart grafana-server

# Verify health
curl http://localhost:3000/api/health
```

#### Backing Up Grafana Configuration

```bash
# SSH into instance
aws ssm start-session --target <instance-id>

# Manual backup
sudo cp /var/lib/grafana/grafana.db /tmp/grafana_backup_$(date +%Y%m%d).db

# Upload to S3
aws s3 cp /tmp/grafana_backup_*.db s3://your-backup-bucket/grafana/

# View logs
sudo tail -f /var/log/grafana/grafana.log
```

#### Restoring from Backup

```bash
# Copy backup file to Grafana data directory
sudo cp /path/to/grafana_backup_YYYYMMDD.db /var/lib/grafana/grafana.db

# Set proper permissions
sudo chown grafana:grafana /var/lib/grafana/grafana.db

# Restart Grafana
sudo systemctl restart grafana-server
```

### Cost Analysis

**Monthly Cost Breakdown (Development Environment):**

| Resource | Unit Cost | Quantity | Monthly Cost |
|----------|-----------|----------|-------------|
| EC2 t3.micro | $0.0104/hour | 730 hours | $7.59 |
| EBS gp3 (20GB) | $0.10/GB | 20GB | $2.00 |
| Data Transfer | ~$0.01 | 1 | $0.01 |
| **Total** | - | - | **~$10/month** |

**Production Environment (t3.small):**

| Resource | Unit Cost | Quantity | Monthly Cost |
|----------|-----------|----------|-------------|
| EC2 t3.small | $0.0208/hour | 730 hours | $15.18 |
| EBS gp3 (30GB) | $0.10/GB | 30GB | $3.00 |
| Data Transfer | ~$0.01 | 1 | $0.01 |
| **Total** | - | - | **~$18/month** |

**Cost Savings vs Alternatives:**

- Eliminates dedicated monitoring instances for each service
- No additional domain/certificate costs (leverages existing ALB)
- Single consolidated database vs multiple instances: **~$140/month savings**

### Security Best Practices

#### Access Control

1. **No SSH Keys**: Use AWS Systems Manager Session Manager
   - Requires IAM permissions only
   - All sessions logged in CloudTrail
   - No key management overhead

2. **IAM Role Least Privilege**
   - Read-only access to CloudWatch and Logs
   - No EC2, RDS, or S3 modification permissions
   - Scoped to necessary AWS services only

3. **Network Isolation**
   - Private subnet (no direct internet access)
   - Security group restricted to ALB traffic only
   - Outbound restricted to CloudWatch, RDS, and SMTP

#### Grafana Security

1. **Authentication**
   - Strong admin password (minimum 16 characters)
   - HTTPS enforced via ALB
   - User sign-up disabled
   - Anonymous access disabled

2. **Authorization**
   - Multiple user roles (Admin, Editor, Viewer)
   - Database user read-only permissions
   - Separate credentials for PostgreSQL access

3. **Data Protection**
   - EBS encryption enabled
   - HTTPS/TLS for all traffic
   - No sensitive data stored in dashboards
   - Database passwords in AWS Secrets Manager

#### Audit & Compliance

- CloudTrail logs all IAM actions
- Session Manager logs all console sessions
- Grafana audit logs available (enable in settings)
- Regular backup testing and validation

### Troubleshooting

#### Cannot Access Grafana

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region eu-west-1

# Expected: TargetHealth.State = healthy
# If unhealthy, check:
# - Security group rules
# - Grafana service status
# - ALB listener rule priority

# Check ALB listener rule
aws elbv2 describe-rules \
  --listener-arn <listener-arn> \
  --region eu-west-1

# Verify rule priority is correct (lower = higher priority)
```

#### CloudWatch Metrics Not Showing

```bash
# Verify IAM role
aws iam get-role --role-name <grafana-role-name>

# Test CloudWatch API access
aws cloudwatch list-metrics \
  --namespace AWS/ECS \
  --region eu-west-1

# If error, check:
# - IAM policy attached to role
# - Correct AWS region configured in Grafana
# - IAM role assigned to EC2 instance
```

#### Database Connection Failed

```bash
# SSH into Grafana instance
aws ssm start-session --target <instance-id>

# Test RDS connectivity
psql -h <rds-endpoint> -U grafana_reader -d eventplannerdb

# If connection fails, check:
# - Security group rules (port 5432)
# - Database user exists and password correct
# - RDS endpoint and port correct
# - VPC routing allows connection
```

#### Grafana Service Issues

```bash
# SSH into instance
aws ssm start-session --target <instance-id>

# Check service status
sudo systemctl status grafana-server

# View recent logs
sudo tail -f /var/log/grafana/grafana.log

# Restart service
sudo systemctl restart grafana-server

# Check system resources
free -h  # memory
df -h    # disk space
top      # CPU usage
```

### File Organization

**Terraform Module Files:**

```text
terraform/grafana-monitoring-iac/
├── bootstrap/
│   ├── main.tf          # S3 and DynamoDB for state
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── environments/
│   ├── dev/
│   │   ├── main.tf      # Module integration
│   │   ├── terraform.tfvars
│   │   └── variables.tf
│   └── prod/
│       ├── main.tf
│       ├── terraform.tfvars
│       └── variables.tf
├── modules/
│   └── grafana-monitor/
│       ├── main.tf           # Core infrastructure
│       ├── variables.tf       # Input variables
│       ├── outputs.tf         # Output values
│       ├── README.md          # Module documentation
│       └── DEPLOYMENT.md      # Deployment guide
└── grafana-config-exports/
    ├── availability-dashboard-*.json
    ├── executive-dashboard-*.json
    ├── infrastructure-dashboard-*.json
    ├── logs-dashboard-*.json
    └── performance-dashboard-*.json
```


## Next Steps

This covers monitoring, security, and operations. Continue with:

- **Part 6**: Cost Optimization and Best Practices
- **Part 7**: Troubleshooting and Runbooks
