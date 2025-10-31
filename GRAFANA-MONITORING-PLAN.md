# Grafana Monitoring Setup Plan

## Overview
Deploy Grafana on EC2 to provide monitoring dashboards accessible to non-engineering teams without AWS console access. Grafana will be integrated with the existing ALB using path-based routing.

---

## Architecture

```
Users → ALB (existing) → /monitoring/* → EC2 Grafana → CloudWatch API
                                                     → RDS (read-only, multi-schema)
```

---

## Phase 1: EC2 Instance Setup

### 1.1 Launch EC2 Instance
**Instance Configuration:**
- AMI: Amazon Linux 2023
- Instance Type: `t3.micro` (2 vCPU, 1GB RAM)
- Subnet: Private Application Subnet (`10.0.10.0/24`)
- Storage: 20GB gp3 EBS
- Name: `eventplanner-grafana-dev`

### 1.2 Create IAM Role
**Role Name:** `grafana-cloudwatch-role`

**Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
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
    },
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
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "tag:GetResources"
      ],
      "Resource": "*"
    }
  ]
}
```

**Attach to EC2 instance**

### 1.3 Security Group Configuration
**Security Group Name:** `grafana-sg`

**Inbound Rules:**
- Port 3000, Source: ALB Security Group (for Grafana traffic)
- Port 22, Source: Your IP (for SSH access)

**Outbound Rules:**
- Port 443, Destination: 0.0.0.0/0 (CloudWatch API)
- Port 5432, Destination: RDS Security Group (database queries)

### 1.4 Update Existing Security Groups
**ALB Security Group:**
- No changes needed (already allows 443 from internet)

**RDS Security Group:**
- Add: Port 5432 from `grafana-sg`

---

## Phase 2: Grafana Installation

### 2.1 Install Grafana
SSH into EC2 instance and run:

```bash
# Update system
sudo yum update -y

# Add Grafana repository
sudo tee /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Grafana
sudo yum install grafana -y

# Start and enable Grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

### 2.2 Configure Grafana
Edit `/etc/grafana/grafana.ini`:

```ini
[server]
protocol = http
http_port = 3000
domain = your-alb-domain.com
root_url = https://your-alb-domain.com/monitoring/
serve_from_sub_path = true

[security]
admin_user = admin
admin_password = <CHANGE-THIS-STRONG-PASSWORD>
disable_gravatar = true
cookie_secure = true
cookie_samesite = strict

[auth]
disable_login_form = false
disable_signout_menu = false

[auth.anonymous]
enabled = false

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer

[log]
mode = console file
level = info
```

Restart Grafana:
```bash
sudo systemctl restart grafana-server
```

---

## Phase 3: ALB Integration

### 3.1 Create Target Group
**Name:** `grafana-monitoring-tg`
**Configuration:**
- Target type: Instance
- Protocol: HTTP
- Port: 3000
- VPC: Same as existing ALB
- Health check path: `/api/health`
- Health check interval: 30 seconds
- Healthy threshold: 2
- Unhealthy threshold: 3
- Timeout: 5 seconds

**Register Target:**
- Add EC2 Grafana instance

### 3.2 Add ALB Listener Rule
**Existing ALB Listener (Port 443):**

Add new rule with **higher priority** than existing rules:
- **Path pattern:** `/monitoring/*`
- **Action:** Forward to `grafana-monitoring-tg`
- **Priority:** 1 (before other rules)

**Existing rules should be:**
- Priority 2: `/api/auth/*` → auth-service-tg
- Priority 3: `/api/events/*` → event-service-tg
- Priority 4: `/api/bookings/*` → booking-service-tg
- Priority 5: `/api/payments/*` → payment-service-tg
- Priority 6: `/api/notifications/*` → notification-service-tg

---

## Phase 4: Data Source Configuration

### 4.1 CloudWatch Data Source
Login to Grafana: `https://your-alb-domain.com/monitoring/`

**Add Data Source:**
1. Go to Configuration → Data Sources → Add data source
2. Select "CloudWatch"
3. Configure:
   - Name: `AWS CloudWatch`
   - Authentication Provider: `AWS SDK Default`
   - Default Region: `us-east-1` (or your region)
   - Namespaces: Select all relevant (ECS, RDS, ElastiCache, ALB, SQS, SNS)
4. Save & Test

### 4.2 PostgreSQL Data Source (Read-Only)
Create read-only database user with access to all schemas:

```sql
-- Connect to the consolidated database
CREATE USER grafana_reader WITH PASSWORD '<strong-password>';
GRANT CONNECT ON DATABASE eventplannerdb TO grafana_reader;

-- Grant access to all schemas
GRANT USAGE ON SCHEMA auth_schema TO grafana_reader;
GRANT USAGE ON SCHEMA event_schema TO grafana_reader;
GRANT USAGE ON SCHEMA booking_schema TO grafana_reader;
GRANT USAGE ON SCHEMA payment_schema TO grafana_reader;
GRANT USAGE ON SCHEMA audit_schema TO grafana_reader;

-- Grant SELECT on all tables in all schemas
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

**Add Data Source in Grafana:**
1. PostgreSQL (Consolidated DB)
   - Name: `EventPlanner Database`
   - Host: `eventplannerdb.xxxxx.eu-west-1.rds.amazonaws.com:5432`
   - Database: `eventplannerdb`
   - User: `grafana_reader`
   - SSL Mode: `require`
   - Search Path: `auth_schema,event_schema,booking_schema,payment_schema,audit_schema`

### 4.3 Audit Logs Queries
Audit logs are now stored in PostgreSQL JSONB format. Example queries:

```sql
-- Recent audit logs
SELECT 
  id,
  audit_log_data_json->>'service' as service,
  audit_log_data_json->>'action' as action,
  audit_log_data_json->>'userId' as user_id,
  created_at
FROM audit_schema.audit_log_jsonb
ORDER BY created_at DESC
LIMIT 100;

-- Audit logs by service
SELECT 
  audit_log_data_json->>'service' as service,
  COUNT(*) as count
FROM audit_schema.audit_log_jsonb
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY service;

-- Failed actions
SELECT *
FROM audit_schema.audit_log_jsonb
WHERE audit_log_data_json->>'status' = 'failed'
ORDER BY created_at DESC;
```

---

## Phase 5: Dashboard Creation

### 5.1 Executive Dashboard
**Metrics:**
- Total events created (today, this week, this month)
- Total bookings made
- Total revenue (from payments)
- Active users (from auth_schema)
- Conversion rate (bookings/events)
- Audit log activity by service

**Panels:**
- Single stat panels for totals
- Time series for trends
- Pie chart for event categories
- Bar chart for top events

### 5.2 Infrastructure Dashboard
**Metrics:**
- ECS CPU utilization (all services)
- ECS memory utilization (all services)
- ECS task count (running vs desired)
- RDS CPU utilization
- RDS database connections
- RDS read/write IOPS
- ElastiCache CPU utilization
- ElastiCache cache hit rate
- ElastiCache evictions

**Panels:**
- Time series for CPU/Memory
- Gauge for current utilization
- Table for service health

### 5.3 Performance Dashboard
**Metrics:**
- ALB request count
- ALB target response time (p50, p95, p99)
- ALB HTTP 4xx/5xx errors
- API latency by service
- Database query performance
- Cache hit/miss ratio

**Panels:**
- Time series for latency percentiles
- Heatmap for response time distribution
- Bar chart for error rates

### 5.4 Security Dashboard
**Metrics:**
- Failed authentication attempts (from audit_schema)
- WAF blocked requests (if configured)
- Suspicious activity patterns (from audit_schema JSONB queries)
- API rate limit violations
- Database connection failures
- Audit log anomalies

**Panels:**
- Time series for failed auth
- Table for recent security events
- Geo map for request origins

### 5.5 Availability Dashboard
**Metrics:**
- Service uptime (healthy targets)
- Database availability
- Cache availability
- SQS queue depth
- DLQ message count
- Error rates by service

**Panels:**
- Status panel for service health
- Time series for queue depths
- Alert list for active issues

### 5.6 Cost Dashboard
**Metrics:**
- ECS Fargate costs (estimated)
- RDS costs (single consolidated instance)
- VPC Endpoint costs (~$50/month)
- Data transfer costs
- Daily/monthly spend trends
- Cost savings from consolidation

**Panels:**
- Single stat for current month spend
- Time series for daily costs
- Pie chart for cost breakdown by service

---

## Phase 6: Alerting Configuration

### 6.1 Configure Notification Channels
**Email:**
- Settings → Alerting → Contact points
- Add email addresses for engineering team

**Slack (Optional):**
- Create Slack webhook
- Add Slack contact point

### 6.2 Create Alert Rules
**Critical Alerts:**
1. Service Down
   - Condition: Healthy targets = 0 for 2 minutes
   - Notification: Email + Slack

2. High Error Rate
   - Condition: 5xx errors > 10/min for 5 minutes
   - Notification: Email + Slack

3. Database CPU High
   - Condition: RDS CPU > 80% for 10 minutes
   - Notification: Email

4. DLQ Messages
   - Condition: DLQ depth > 0 for 1 minute
   - Notification: Email + Slack

**Warning Alerts:**
1. High CPU
   - Condition: ECS CPU > 70% for 10 minutes
   - Notification: Email

2. Low Cache Hit Rate
   - Condition: Cache hit rate < 80% for 15 minutes
   - Notification: Email

3. Slow API Response
   - Condition: p95 latency > 500ms for 10 minutes
   - Notification: Email

---

## Phase 7: User Management

### 7.1 Create User Accounts
**Admin Users (Engineering Team):**
- Role: Admin
- Can edit dashboards, data sources, users

**Viewer Users (Product, Operations, Business):**
- Role: Viewer
- Can only view dashboards
- Cannot edit or create

**Editor Users (DevOps, SRE):**
- Role: Editor
- Can create/edit dashboards
- Cannot manage users or data sources

### 7.2 User Creation Process
1. Go to Configuration → Users
2. Click "Invite"
3. Enter email, name, username
4. Assign role (Admin/Editor/Viewer)
5. Send credentials securely

---

## Phase 8: Backup & Maintenance

### 8.1 Grafana Backup
**Automated Backup Script:**
```bash
#!/bin/bash
# /home/ec2-user/backup-grafana.sh

BACKUP_DIR="/home/ec2-user/grafana-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup Grafana database
sudo cp /var/lib/grafana/grafana.db $BACKUP_DIR/grafana_$DATE.db

# Backup configuration
sudo cp /etc/grafana/grafana.ini $BACKUP_DIR/grafana_$DATE.ini

# Upload to S3 (optional)
aws s3 cp $BACKUP_DIR/grafana_$DATE.db s3://your-backup-bucket/grafana/

# Keep only last 7 days
find $BACKUP_DIR -name "grafana_*.db" -mtime +7 -delete
```

**Cron Job:**
```bash
# Run daily at 2 AM
0 2 * * * /home/ec2-user/backup-grafana.sh
```

### 8.2 Grafana Updates
**Monthly Update Process:**
```bash
# Check current version
grafana-server -v

# Update Grafana
sudo yum update grafana -y

# Restart service
sudo systemctl restart grafana-server

# Verify
curl http://localhost:3000/api/health
```

### 8.3 Monitoring Grafana Itself
**CloudWatch Agent (Optional):**
- Install CloudWatch agent on EC2
- Monitor Grafana process health
- Track EC2 CPU/Memory/Disk

---

## Phase 9: Documentation & Training

### 9.1 User Documentation
Create internal wiki page with:
- How to access Grafana
- Dashboard overview
- How to interpret metrics
- Who to contact for issues

### 9.2 Team Training
- Demo session for each team
- Walk through relevant dashboards
- Q&A session

---

## Cost Estimate

| Resource | Cost/Month |
|----------|------------|
| EC2 t3.small | $15 |
| EBS 20GB gp3 | $2 |
| Data Transfer (minimal) | $1 |
| **Total** | **~$18/month** |

**Note:** No additional ALB cost (reusing existing)

**Architecture Cost Savings:**
- Consolidated RDS: Saves $34/month (4 instances → 1 instance)
- No DocumentDB: Saves $70/month
- No NAT Gateway: Saves $37/month
- **Total Infrastructure Savings: $141/month**

---

## Security Checklist

- [ ] Strong admin password set
- [ ] IAM role with least privilege attached
- [ ] Security groups properly configured
- [ ] RDS read-only user created with multi-schema access
- [ ] SSL/TLS enforced (via ALB)
- [ ] User sign-up disabled
- [ ] Anonymous access disabled
- [ ] Regular backups configured
- [ ] CloudTrail logging enabled
- [ ] SSH key pair secured

---

## Testing Checklist

- [ ] Grafana accessible at `https://your-alb-domain.com/monitoring/`
- [ ] Login with admin credentials works
- [ ] CloudWatch data source connected
- [ ] RDS data sources connected
- [ ] Sample dashboard displays metrics
- [ ] Alerts trigger correctly
- [ ] Email notifications received
- [ ] Health check passing in target group
- [ ] ALB routing to Grafana works
- [ ] Non-admin users can view dashboards

---

## Rollback Plan

If issues occur:
1. Remove ALB listener rule for `/monitoring/*`
2. Deregister EC2 from target group
3. Stop Grafana service: `sudo systemctl stop grafana-server`
4. Terminate EC2 instance
5. Delete target group
6. Revert security group changes

---

## Next Steps After Deployment

1. **Week 1:** Monitor Grafana performance and stability
2. **Week 2:** Gather feedback from users, refine dashboards
3. **Month 1:** Add custom application metrics from Spring Boot Actuator
4. **Month 2:** Integrate with incident management tools (PagerDuty, Opsgenie)
5. **Month 3:** Consider migration to Amazon Managed Grafana for production

---

## Support & Troubleshooting

**Common Issues:**

1. **Cannot access Grafana**
   - Check ALB listener rule priority
   - Verify target group health
   - Check security group rules

2. **CloudWatch data not showing**
   - Verify IAM role permissions
   - Check AWS region configuration
   - Test data source connection

3. **Database queries failing**
   - Verify read-only user has access to all schemas
   - Check search_path configuration
   - Verify security group rules
   - Test database connectivity from EC2
   - Ensure JSONB queries use proper syntax

4. **High EC2 CPU**
   - Reduce dashboard refresh rates
   - Optimize queries
   - Consider upgrading to t3.medium

**Logs Location:**
- Grafana logs: `/var/log/grafana/grafana.log`
- System logs: `sudo journalctl -u grafana-server -f`

---

## Conclusion

This plan provides a complete, cost-effective monitoring solution that democratizes access to system metrics without requiring AWS console access. The setup leverages existing infrastructure (ALB) and uses Grafana's built-in authentication for simplicity.
