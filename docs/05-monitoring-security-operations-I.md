# Monitoring & Security Operations I

**Last Updated:** November 2025  
**Version:** 2.0.0

## Overview

This document covers monitoring setup, configuration, and operational procedures for the Event Planner Platform infrastructure and applications.

## Monitoring Architecture

### CloudWatch Integration

**Log Groups:**
- `/ecs/event-planner/dev/auth-service`
- `/ecs/event-planner/dev/event-service`
- `/ecs/event-planner/dev/payment-service`
- `/ecs/event-planner/dev/notification-service`

**Retention:** 3 days (development), 7 days (production)

### Grafana Dashboard

**Access:** `https://api.sankofagrid.com/monitoring/`

**Data Sources:**
- CloudWatch - Infrastructure and application metrics
- PostgreSQL - Database queries and audit logs
- Audit Logs - JSONB-based audit trail

## CloudWatch Dashboards

### Service-Specific Dashboards

**Auth Service Dashboard**
- Authentication success/failure rates
- User registration metrics
- Login attempts and patterns
- JWT token generation
- Session management

**Event Service Dashboard**
- Event creation rate
- Event updates and deletions
- Ticket sales metrics
- Event invitation statistics
- API response times

**Payment Service Dashboard**
- Payment transaction volume
- Payment success/failure rates
- Paystack integration metrics
- Transaction processing time
- Revenue tracking

**Notification Service Dashboard**
- Email delivery rates
- SMS delivery statistics
- Queue processing metrics
- SMTP connection status
- Notification failures

### Infrastructure Dashboards

**ECS Metrics:**
- CPU utilization per service
- Memory utilization per service
- Task count (running vs desired)
- Service health status
- Container restart count

**ALB Metrics:**
- Request count per service
- Response time (p50, p95, p99)
- HTTP 4xx/5xx error rates
- Healthy/unhealthy target count
- Active connection count

**RDS Metrics:**
- CPU utilization
- Database connections
- Read/write IOPS
- Storage usage
- Replication lag (if applicable)

**ElastiCache Metrics:**
- CPU utilization
- Memory usage
- Cache hit/miss ratio
- Evictions
- Network throughput

## Grafana Monitoring

### Executive Dashboard

**Business Metrics:**
- Total events created
- Total users registered
- Total revenue generated
- Active users count
- Conversion rates

**Visualizations:**
- Time series graphs
- Single stat panels
- Pie charts for distributions
- Bar charts for comparisons

### Infrastructure Dashboard

**System Health:**
- Service availability
- Resource utilization
- Error rates
- Response times
- Queue depths

**Visualizations:**
- Gauge panels for current status
- Time series for trends
- Heatmaps for patterns
- Tables for detailed data

### Performance Dashboard

**API Performance:**
- Request latency by endpoint
- Throughput per service
- Error rates by type
- Database query performance
- Cache performance

**Visualizations:**
- Latency percentiles (p50, p95, p99)
- Request rate graphs
- Error rate trends
- Query execution times

### Security Dashboard

**Security Metrics:**
- Failed authentication attempts
- Suspicious activity patterns
- API rate limit violations
- Database connection failures
- Unauthorized access attempts

**Visualizations:**
- Time series for security events
- Tables for recent incidents
- Alerts for critical events

## CloudWatch Alarms

### ECS Alarms

**High CPU Utilization**
- Threshold: 80%
- Evaluation: 2 consecutive periods
- Period: 5 minutes
- Action: SNS notification

**High Memory Utilization**
- Threshold: 80%
- Evaluation: 2 consecutive periods
- Period: 5 minutes
- Action: SNS notification

**Service Unhealthy**
- Threshold: < 1 healthy task
- Evaluation: 1 period
- Period: 1 minute
- Action: SNS notification + auto-scaling

### ALB Alarms

**High 5XX Error Rate**
- Threshold: > 10 errors/minute
- Evaluation: 2 consecutive periods
- Period: 1 minute
- Action: SNS notification

**High Response Time**
- Threshold: > 2 seconds (p95)
- Evaluation: 3 consecutive periods
- Period: 5 minutes
- Action: SNS notification

**Unhealthy Targets**
- Threshold: < 1 healthy target
- Evaluation: 1 period
- Period: 1 minute
- Action: SNS notification

### RDS Alarms

**High CPU Utilization**
- Threshold: 80%
- Evaluation: 3 consecutive periods
- Period: 5 minutes
- Action: SNS notification

**Low Storage Space**
- Threshold: < 5 GB free
- Evaluation: 1 period
- Period: 5 minutes
- Action: SNS notification

**High Connection Count**
- Threshold: > 80 connections
- Evaluation: 2 consecutive periods
- Period: 5 minutes
- Action: SNS notification

### ElastiCache Alarms

**High CPU Utilization**
- Threshold: 75%
- Evaluation: 2 consecutive periods
- Period: 5 minutes
- Action: SNS notification

**High Memory Usage**
- Threshold: 90%
- Evaluation: 2 consecutive periods
- Period: 5 minutes
- Action: SNS notification

**High Evictions**
- Threshold: > 1000 evictions/minute
- Evaluation: 1 period
- Period: 5 minutes
- Action: SNS notification

### SQS Alarms

**Dead Letter Queue Messages**
- Threshold: > 0 messages
- Evaluation: 1 period
- Period: 1 minute
- Action: SNS notification

**Message Age**
- Threshold: > 5 minutes
- Evaluation: 2 consecutive periods
- Period: 5 minutes
- Action: SNS notification

## Log Management

### Log Aggregation

**CloudWatch Logs Insights Queries:**

**Error Logs:**
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

**Slow Queries:**
```sql
fields @timestamp, @message
| filter @message like /duration/
| parse @message /duration=(?<duration>\d+)/
| filter duration > 1000
| sort duration desc
```

**Authentication Failures:**
```sql
fields @timestamp, @message
| filter @message like /authentication failed/
| stats count() by bin(5m)
```

### Log Retention

**Development:**
- ECS logs: 3 days
- RDS logs: 3 days
- VPC Flow Logs: 3 days
- ALB logs: 7 days

**Production:**
- ECS logs: 7 days
- RDS logs: 7 days
- VPC Flow Logs: 7 days
- ALB logs: 30 days

## Audit Logging

### Database Audit Logs

**Storage:** PostgreSQL JSONB format in audit_schema

**Captured Events:**
- User authentication
- Data modifications
- API requests
- Payment transactions
- Administrative actions

**Query Examples:**

**Recent Audit Logs:**
```sql
SELECT 
  id,
  audit_log_data_json->>'service' as service,
  audit_log_data_json->>'action' as action,
  audit_log_data_json->>'userId' as user_id,
  created_at
FROM audit_schema.audit_log_jsonb
ORDER BY created_at DESC
LIMIT 100;
```

**Failed Actions:**
```sql
SELECT *
FROM audit_schema.audit_log_jsonb
WHERE audit_log_data_json->>'status' = 'failed'
ORDER BY created_at DESC;
```

**Actions by Service:**
```sql
SELECT 
  audit_log_data_json->>'service' as service,
  COUNT(*) as count
FROM audit_schema.audit_log_jsonb
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY service;
```

## Performance Monitoring

### Application Performance

**Metrics Tracked:**
- API response times
- Database query execution times
- Cache hit/miss ratios
- Queue processing times
- External API call latencies

**Tools:**
- CloudWatch Application Insights
- X-Ray tracing (optional)
- Custom application metrics

### Infrastructure Performance

**Metrics Tracked:**
- CPU and memory utilization
- Network throughput
- Disk I/O
- Connection pool usage
- Resource saturation

## Alert Management

### Notification Channels

**Slack Integration:**
- Critical alerts: #alerts-critical
- Warning alerts: #alerts-warning
- Info alerts: #alerts-info

**Email Notifications:**
- On-call team email list
- Management summary emails

**SNS Topics:**
- critical-alerts
- warning-alerts
- info-alerts

### Alert Severity Levels

**Critical:**
- Service completely down
- Database unavailable
- Security breach detected
- Data loss risk

**High:**
- Service degraded
- High error rates
- Resource exhaustion imminent
- Failed backups

**Medium:**
- Performance degradation
- Elevated error rates
- Resource usage high
- Queue backlog

**Low:**
- Minor issues
- Informational alerts
- Scheduled maintenance
- Configuration changes

## Monitoring Best Practices

### Dashboard Design
- Focus on actionable metrics
- Use appropriate visualizations
- Group related metrics
- Include time range selectors
- Add annotations for deployments

### Alert Configuration
- Set meaningful thresholds
- Avoid alert fatigue
- Include context in notifications
- Define clear escalation paths
- Regular review and tuning

### Log Management
- Structured logging format
- Consistent log levels
- Include correlation IDs
- Sanitize sensitive data
- Regular log analysis

## Operational Procedures

### Daily Checks
- Review dashboard for anomalies
- Check alarm status
- Review error logs
- Verify backup completion
- Monitor resource usage

### Weekly Reviews
- Analyze performance trends
- Review capacity planning
- Update alert thresholds
- Review security events
- Document incidents

### Monthly Reviews
- Capacity planning assessment
- Cost optimization review
- Security audit
- Disaster recovery testing
- Documentation updates
