# Troubleshooting Runbooks

**Last Updated:** November 2025  
**Version:** 2.0.0

## Overview

This document provides step-by-step troubleshooting procedures for common issues in the Event Planner Platform infrastructure and applications.

## ECS Service Issues

### Service Not Starting

**Symptoms:**
- ECS service shows 0 running tasks
- Tasks fail to start
- Continuous task replacement

**Diagnosis:**
```bash
# Check service events
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service \
  --query 'services[0].events[0:10]'

# Check task status
aws ecs list-tasks \
  --cluster event-planner-dev-cluster \
  --service-name auth-service

# Describe stopped tasks
aws ecs describe-tasks \
  --cluster event-planner-dev-cluster \
  --tasks <task-id>
```

**Common Causes:**

1. **Image Pull Errors:**
```bash
# Verify ECR repository
aws ecr describe-repositories --repository-names auth-service

# Check image exists
aws ecr list-images --repository-name auth-service

# Verify IAM permissions
aws iam get-role-policy \
  --role-name event-planner-ecs-execution-role \
  --policy-name ecr-access
```

2. **Secrets Not Available:**
```bash
# Verify secret exists
aws secretsmanager describe-secret \
  --secret-id event-planner/dev/jwt-secret

# Check IAM permissions
aws iam get-role-policy \
  --role-name event-planner-ecs-execution-role \
  --policy-name secrets-access
```

3. **Health Check Failures:**
```bash
# Check application logs
aws logs tail /ecs/event-planner/dev/auth-service --follow

# Test health endpoint locally
curl http://localhost:8081/actuator/health
```

**Resolution:**
- Fix IAM permissions
- Verify secrets exist
- Check application configuration
- Review security group rules
- Increase health check grace period

### High CPU/Memory Usage

**Symptoms:**
- Service performance degradation
- Slow response times
- Tasks being killed

**Diagnosis:**
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=auth-service \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Average,Maximum

# Check memory metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=auth-service \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Average,Maximum
```

**Resolution:**
- Increase CPU/memory allocation
- Enable auto-scaling
- Optimize application code
- Add caching layer
- Review database queries

### Service Deployment Failures

**Symptoms:**
- Deployment stuck in progress
- Rollback triggered
- Health checks failing

**Diagnosis:**
```bash
# Check deployment status
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service \
  --query 'services[0].deployments'

# Check task definition
aws ecs describe-task-definition \
  --task-definition auth-service:latest
```

**Resolution:**
- Verify new task definition is valid
- Check health check configuration
- Review application logs
- Rollback to previous version if needed
- Increase deployment timeout

## Database Issues

### Connection Failures

**Symptoms:**
- Application cannot connect to database
- Connection timeout errors
- Too many connections error

**Diagnosis:**
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier event-planner-dev-auth-db

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <rds-security-group-id>

# Test connection from ECS task
aws ecs execute-command \
  --cluster event-planner-dev-cluster \
  --task <task-id> \
  --command "nc -zv <rds-endpoint> 5432"
```

**Common Causes:**

1. **Security Group Misconfiguration:**
```bash
# Verify inbound rules allow ECS security group
aws ec2 describe-security-groups \
  --group-ids <rds-security-group-id> \
  --query 'SecurityGroups[0].IpPermissions'
```

2. **Connection Pool Exhaustion:**
```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity;

-- Check connection limit
SHOW max_connections;

-- Kill idle connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' 
AND state_change < NOW() - INTERVAL '10 minutes';
```

**Resolution:**
- Fix security group rules
- Increase connection pool size
- Optimize connection usage
- Increase max_connections parameter
- Add read replicas for read traffic

### High CPU Usage

**Symptoms:**
- Slow query performance
- Database unresponsive
- Connection timeouts

**Diagnosis:**
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=event-planner-dev-auth-db \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Average,Maximum

# Check slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

**Resolution:**
- Identify and optimize slow queries
- Add missing indexes
- Increase instance size
- Enable query caching
- Optimize application queries

### Storage Full

**Symptoms:**
- Database write failures
- Application errors
- Storage alarm triggered

**Diagnosis:**
```bash
# Check storage metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=event-planner-dev-auth-db \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Average,Minimum

# Check database size
SELECT pg_size_pretty(pg_database_size('eventplannerdb'));

# Check table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
```

**Resolution:**
- Increase storage allocation
- Enable storage auto-scaling
- Archive old data
- Vacuum and analyze tables
- Delete unnecessary data

## Load Balancer Issues

### High 5XX Error Rate

**Symptoms:**
- Increased 5XX errors
- Service unavailable errors
- Timeout errors

**Diagnosis:**
```bash
# Check ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=<alb-arn-suffix> \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 60 \
  --statistics Sum

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

**Resolution:**
- Check target health
- Review application logs
- Verify security group rules
- Increase task count
- Check database connectivity

### Unhealthy Targets

**Symptoms:**
- Targets marked unhealthy
- Traffic not reaching services
- Health check failures

**Diagnosis:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Check health check configuration
aws elbv2 describe-target-groups \
  --target-group-arns <target-group-arn> \
  --query 'TargetGroups[0].HealthCheckPath'

# Test health endpoint
curl http://<task-ip>:8081/actuator/health
```

**Resolution:**
- Fix health check endpoint
- Adjust health check thresholds
- Increase health check interval
- Fix application issues
- Check security group rules

## Cache Issues

### High Eviction Rate

**Symptoms:**
- Poor cache performance
- High database load
- Slow response times

**Diagnosis:**
```bash
# Check eviction metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name Evictions \
  --dimensions Name=CacheClusterId,Value=event-planner-dev-redis \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Sum

# Check memory usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name DatabaseMemoryUsagePercentage \
  --dimensions Name=CacheClusterId,Value=event-planner-dev-redis \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

**Resolution:**
- Increase cache node size
- Optimize cache key strategy
- Adjust TTL values
- Add more cache nodes
- Review caching patterns

### Connection Failures

**Symptoms:**
- Application cannot connect to Redis
- Connection timeout errors
- Authentication failures

**Diagnosis:**
```bash
# Check ElastiCache status
aws elasticache describe-cache-clusters \
  --cache-cluster-id event-planner-dev-redis

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <elasticache-security-group-id>

# Test connection
redis-cli -h <redis-endpoint> -p 6379 --tls ping
```

**Resolution:**
- Fix security group rules
- Verify auth token
- Check TLS configuration
- Restart cache cluster if needed

## Message Queue Issues

### Dead Letter Queue Messages

**Symptoms:**
- Messages in DLQ
- Processing failures
- Alarm triggered

**Diagnosis:**
```bash
# Check DLQ messages
aws sqs get-queue-attributes \
  --queue-url <dlq-url> \
  --attribute-names ApproximateNumberOfMessages

# Receive messages from DLQ
aws sqs receive-message \
  --queue-url <dlq-url> \
  --max-number-of-messages 10
```

**Resolution:**
- Investigate message content
- Fix processing logic
- Reprocess messages manually
- Adjust retry policy
- Update message format

### High Message Age

**Symptoms:**
- Messages not being processed
- Queue backlog growing
- Processing delays

**Diagnosis:**
```bash
# Check message age
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS \
  --metric-name ApproximateAgeOfOldestMessage \
  --dimensions Name=QueueName,Value=user-registration-queue \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Maximum

# Check queue depth
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages
```

**Resolution:**
- Scale up consumers
- Optimize processing logic
- Increase visibility timeout
- Add more workers
- Check for processing errors

## Network Issues

### NAT Gateway Failures

**Symptoms:**
- Services cannot reach internet
- External API calls failing
- SMTP connection failures

**Diagnosis:**
```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways \
  --nat-gateway-ids <nat-gateway-id>

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<vpc-id>"

# Test connectivity from ECS task
aws ecs execute-command \
  --cluster event-planner-dev-cluster \
  --task <task-id> \
  --command "curl -I https://www.google.com"
```

**Resolution:**
- Verify NAT Gateway is available
- Check route table configuration
- Verify security group rules
- Check network ACLs
- Restart NAT Gateway if needed

### DNS Resolution Failures

**Symptoms:**
- Service discovery not working
- Cannot resolve service names
- Connection failures between services

**Diagnosis:**
```bash
# Check Cloud Map namespace
aws servicediscovery list-namespaces

# Check service registration
aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=<namespace-id>

# Test DNS resolution
nslookup auth-service.eventplanner.local
```

**Resolution:**
- Verify Cloud Map configuration
- Check service registration
- Verify VPC DNS settings
- Restart services to re-register
- Check security group rules

## Deployment Issues

### Terraform State Lock

**Symptoms:**
- Terraform operations fail
- State lock error message
- Cannot run terraform commands

**Diagnosis:**
```bash
# Check DynamoDB lock table
aws dynamodb scan \
  --table-name event-planner-terraform-locks

# Get lock details
aws dynamodb get-item \
  --table-name event-planner-terraform-locks \
  --key '{"LockID":{"S":"<lock-id>"}}'
```

**Resolution:**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>

# Or delete lock from DynamoDB
aws dynamodb delete-item \
  --table-name event-planner-terraform-locks \
  --key '{"LockID":{"S":"<lock-id>"}}'
```

### CI/CD Pipeline Failures

**Symptoms:**
- GitHub Actions workflow fails
- Deployment not completing
- Build errors

**Diagnosis:**
- Review GitHub Actions logs
- Check AWS credentials
- Verify IAM permissions
- Check resource quotas

**Resolution:**
- Fix code/configuration issues
- Update AWS credentials
- Adjust IAM permissions
- Request quota increases
- Retry workflow

## Emergency Procedures

### Complete Service Outage

**Immediate Actions:**
1. Check AWS Service Health Dashboard
2. Verify all services status
3. Check CloudWatch alarms
4. Review recent changes
5. Notify stakeholders

**Recovery Steps:**
1. Identify root cause
2. Implement immediate fix
3. Verify service restoration
4. Monitor for stability
5. Conduct post-mortem

### Data Loss Prevention

**Immediate Actions:**
1. Stop all write operations
2. Create immediate snapshots
3. Isolate affected resources
4. Assess data integrity
5. Notify management

**Recovery Steps:**
1. Restore from latest backup
2. Verify data integrity
3. Resume operations
4. Document incident
5. Implement preventive measures

## Escalation Procedures

### Severity Levels

**Critical (P1):**
- Complete service outage
- Data breach
- Immediate escalation to on-call engineer

**High (P2):**
- Partial service degradation
- Security vulnerability
- Escalate within 30 minutes

**Medium (P3):**
- Minor service issues
- Performance degradation
- Escalate within 2 hours

**Low (P4):**
- Informational issues
- Non-urgent improvements
- Handle during business hours

### Contact Information

**On-Call Engineer:**
- Primary: Check PagerDuty
- Secondary: Check PagerDuty
- Escalation: Team Lead

**AWS Support:**
- Support Level: Business/Enterprise
- Case Priority: Based on severity
- Phone: Available 24/7
