# Grafana Monitoring Module

This module provisions Grafana on EC2 for monitoring dashboards accessible to non-engineering teams without AWS console access.

## Architecture

```
Users → ALB (existing) → /monitoring/* → EC2 Grafana → CloudWatch API
                                                     → RDS (read-only)
```

## Features

- **EC2 Instance**: t3.small (2 vCPU, 2GB RAM) in private subnet
- **IAM Role**: CloudWatch read permissions for metrics and logs
- **Security Groups**: Minimal access (ALB → Grafana, Grafana → RDS/CloudWatch)
- **ALB Integration**: Path-based routing on `/monitoring/*`
- **Auto-Installation**: User data script installs and configures Grafana
- **Health Checks**: ALB monitors Grafana availability
- **CloudWatch Alarms**: CPU and health monitoring

## Usage

```hcl
module "grafana_monitor" {
  source = "../../modules/grafana-monitor"

  project_name = "event-planner"
  environment  = "dev"

  vpc_id                   = module.vpc.vpc_id
  private_subnet_id        = module.vpc.private_app_subnet_ids[0]
  alb_security_group_id    = module.security_groups.alb_security_group_id
  rds_security_group_id    = module.security_groups.rds_security_group_id
  alb_listener_arn         = module.alb.https_listener_arn
  alb_arn_suffix           = module.alb.alb_arn_suffix
  alb_domain_name          = "api.sankofagrid.com"

  grafana_admin_password   = var.grafana_admin_password
  listener_rule_priority   = 1

  alarm_actions = [module.cloudwatch.sns_topic_arn]
  tags          = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name prefix | string | - | yes |
| environment | Environment name | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| private_subnet_id | Private subnet ID | string | - | yes |
| alb_security_group_id | ALB security group ID | string | - | yes |
| rds_security_group_id | RDS security group ID | string | - | yes |
| alb_listener_arn | ALB HTTPS listener ARN | string | - | yes |
| alb_arn_suffix | ALB ARN suffix | string | - | yes |
| alb_domain_name | ALB domain name | string | - | yes |
| grafana_admin_password | Grafana admin password | string | - | yes |
| instance_type | EC2 instance type | string | t3.small | no |
| volume_size | EBS volume size (GB) | number | 20 | no |
| listener_rule_priority | ALB rule priority | number | 1 | no |
| alarm_actions | SNS topic ARNs for alarms | list(string) | [] | no |

## Outputs

| Name | Description |
|------|-------------|
| grafana_instance_id | EC2 instance ID |
| grafana_instance_private_ip | Private IP address |
| grafana_security_group_id | Security group ID |
| grafana_iam_role_arn | IAM role ARN |
| grafana_target_group_arn | Target group ARN |
| grafana_url | Grafana access URL |

## Post-Deployment Steps

### 1. Access Grafana
```
URL: https://api.sankofagrid.com/monitoring/
Username: admin
Password: <grafana_admin_password>
```

### 2. Configure CloudWatch Data Source
1. Go to Configuration → Data Sources → Add data source
2. Select "CloudWatch"
3. Configure:
   - Name: `AWS CloudWatch`
   - Authentication Provider: `AWS SDK Default`
   - Default Region: `eu-west-1`
4. Save & Test

### 3. Configure PostgreSQL Data Source
First, create read-only user in RDS:
```sql
CREATE USER grafana_reader WITH PASSWORD '<strong-password>';
GRANT CONNECT ON DATABASE eventplannerdb TO grafana_reader;

GRANT USAGE ON SCHEMA auth_schema TO grafana_reader;
GRANT USAGE ON SCHEMA event_schema TO grafana_reader;
GRANT USAGE ON SCHEMA booking_schema TO grafana_reader;
GRANT USAGE ON SCHEMA payment_schema TO grafana_reader;
GRANT USAGE ON SCHEMA audit_schema TO grafana_reader;

GRANT SELECT ON ALL TABLES IN SCHEMA auth_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA event_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA booking_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA payment_schema TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA audit_schema TO grafana_reader;
```

Then add data source in Grafana:
1. Go to Configuration → Data Sources → Add data source
2. Select "PostgreSQL"
3. Configure:
   - Name: `EventPlanner Database`
   - Host: `<rds-endpoint>:5432`
   - Database: `eventplannerdb`
   - User: `grafana_reader`
   - SSL Mode: `require`

### 4. Create Dashboards
Import or create dashboards for:
- Executive metrics (events, bookings, revenue)
- Infrastructure (ECS, RDS, ElastiCache)
- Performance (latency, errors)
- Security (failed auth, audit logs)

## Security

- Grafana runs in private subnet (no direct internet access)
- IAM role with read-only CloudWatch permissions
- RDS access via read-only database user
- SSL/TLS enforced via ALB
- User sign-up disabled
- Anonymous access disabled
- Session Manager for SSH access (no SSH keys needed)

## Cost Estimate

| Resource | Cost/Month |
|----------|------------|
| EC2 t3.small | $15 |
| EBS 20GB gp3 | $2 |
| Data Transfer | $1 |
| **Total** | **~$18/month** |

## Troubleshooting

### Cannot access Grafana
- Check ALB listener rule priority
- Verify target group health
- Check security group rules

### CloudWatch data not showing
- Verify IAM role permissions
- Check AWS region configuration
- Test data source connection

### Database queries failing
- Verify read-only user permissions
- Check security group rules
- Test database connectivity from EC2

### Logs Location
- Grafana logs: `/var/log/grafana/grafana.log`
- System logs: `sudo journalctl -u grafana-server -f`

## Maintenance

### Update Grafana
```bash
sudo yum update grafana -y
sudo systemctl restart grafana-server
```

### Backup Grafana
```bash
sudo cp /var/lib/grafana/grafana.db /backup/grafana_$(date +%Y%m%d).db
```

## Notes

- Grafana installation happens via user data script on first boot
- Allow 2-3 minutes for Grafana to be fully operational
- Use Session Manager to access EC2 instance (no SSH keys needed)
- Listener rule priority 1 ensures Grafana routes before other services
