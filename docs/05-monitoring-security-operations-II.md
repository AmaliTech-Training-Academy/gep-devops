# Monitoring & Security Operations II

**Last Updated:** November 2025  
**Version:** 2.0.0

## Overview

This document covers security operations, best practices, and compliance procedures for the Event Planner Platform.

## Security Architecture

### Network Security

**VPC Isolation:**
- Private subnets for applications and databases
- Public subnets only for ALB and NAT Gateway
- No direct internet access for applications
- Controlled outbound access via NAT Gateway

**Security Groups:**
- Least-privilege access rules
- Service-specific security groups
- No overly permissive rules
- Regular security group audits

**Network ACLs:**
- Default allow for simplicity
- Stateless firewall rules
- Subnet-level protection

### Data Encryption

**At Rest:**
- RDS: KMS encryption enabled
- ElastiCache: Encryption enabled
- S3: AES256 encryption
- Secrets Manager: KMS encryption
- EBS volumes: Encrypted

**In Transit:**
- RDS: SSL/TLS enforced
- ElastiCache: TLS enabled
- ALB: HTTPS only (HTTP redirects to HTTPS)
- CloudFront: HTTPS only
- Internal services: TLS recommended

### Access Control

**IAM Roles:**
- ECS task execution role (minimal permissions)
- Service-specific task roles
- No long-term credentials in containers
- Regular permission audits

**Secrets Management:**
- AWS Secrets Manager for all credentials
- No hardcoded secrets
- Automatic secret rotation (production)
- Audit logging for secret access

**Authentication:**
- JWT-based authentication
- Token expiration enforced
- Refresh token rotation
- Multi-factor authentication (production)

## Security Monitoring

### CloudWatch Security Metrics

**Failed Authentication Attempts:**
- Monitor login failures
- Track brute force attempts
- Alert on suspicious patterns

**API Rate Limiting:**
- Monitor request rates per IP
- Track rate limit violations
- Block abusive clients

**Database Access:**
- Monitor connection attempts
- Track failed connections
- Alert on unusual patterns

### Security Alarms

**Unauthorized Access Attempts**
- Threshold: > 10 failed attempts/minute
- Action: Block IP, notify security team

**Unusual API Activity**
- Threshold: > 1000 requests/minute from single IP
- Action: Rate limit, investigate

**Database Connection Failures**
- Threshold: > 5 failures/minute
- Action: Check credentials, notify team

## Compliance & Auditing

### Audit Logging

**Events Logged:**
- User authentication (success/failure)
- Data access and modifications
- Administrative actions
- Configuration changes
- Security events

**Audit Log Storage:**
- PostgreSQL JSONB format
- Immutable audit trail
- Long-term retention
- Regular backup

**Audit Log Analysis:**
```sql
-- Failed authentication attempts
SELECT 
  audit_log_data_json->>'userId' as user_id,
  COUNT(*) as failed_attempts
FROM audit_schema.audit_log_jsonb
WHERE audit_log_data_json->>'action' = 'login'
  AND audit_log_data_json->>'status' = 'failed'
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY user_id
HAVING COUNT(*) > 5;
```

### Compliance Requirements

**Data Protection:**
- GDPR compliance for EU users
- Data encryption at rest and in transit
- Right to be forgotten implementation
- Data breach notification procedures

**Access Control:**
- Role-based access control (RBAC)
- Principle of least privilege
- Regular access reviews
- Audit trail for all access

**Backup & Recovery:**
- Regular automated backups
- Tested recovery procedures
- Backup encryption
- Off-site backup storage

## Security Best Practices

### Application Security

**Input Validation:**
- Validate all user inputs
- Sanitize data before storage
- Prevent SQL injection
- Prevent XSS attacks

**API Security:**
- Rate limiting enabled
- CORS properly configured
- JWT token validation
- API versioning

**Dependency Management:**
- Regular dependency updates
- Vulnerability scanning
- Security patch management
- Dependency pinning

### Infrastructure Security

**Patch Management:**
- Regular OS updates
- Security patch application
- Automated patching (non-critical)
- Change management for critical patches

**Configuration Management:**
- Infrastructure as Code (Terraform)
- Version control for all configurations
- Peer review for changes
- Automated compliance checks

**Secrets Rotation:**
- Regular password rotation
- Automated secret rotation (production)
- No shared credentials
- Secure secret distribution

## Incident Response

### Incident Classification

**Severity Levels:**

**Critical (P1):**
- Complete service outage
- Data breach
- Security compromise
- Data loss

**High (P2):**
- Partial service outage
- Performance degradation
- Security vulnerability
- Failed backups

**Medium (P3):**
- Minor service issues
- Non-critical errors
- Configuration issues
- Capacity warnings

**Low (P4):**
- Informational alerts
- Planned maintenance
- Documentation updates
- Minor improvements

### Incident Response Procedures

**Detection:**
1. Monitor alerts and dashboards
2. Investigate anomalies
3. Confirm incident
4. Classify severity

**Response:**
1. Notify on-call team
2. Assess impact
3. Implement mitigation
4. Communicate status

**Resolution:**
1. Identify root cause
2. Implement fix
3. Verify resolution
4. Document incident

**Post-Incident:**
1. Conduct post-mortem
2. Document lessons learned
3. Implement preventive measures
4. Update runbooks

## Security Scanning

### Infrastructure Scanning

**Terraform Security Scanning:**
- Checkov for policy compliance
- tfsec for security issues
- Automated scanning in CI/CD
- Block deployments on critical issues

**Container Scanning:**
- ECR image scanning
- Vulnerability detection
- Base image updates
- Scan on push

### Application Scanning

**Dependency Scanning:**
- Maven dependency check
- npm audit
- Automated vulnerability alerts
- Regular dependency updates

**Code Scanning:**
- Static code analysis
- Security linting
- Code review requirements
- Automated checks in CI/CD

## Access Management

### User Access

**Principles:**
- Least privilege access
- Role-based access control
- Regular access reviews
- Immediate revocation on termination

**Access Levels:**
- Read-only: Monitoring and logs
- Developer: Code and deployments
- Admin: Infrastructure changes
- Security: All access with audit

### Service Access

**Service Accounts:**
- Unique credentials per service
- No shared service accounts
- Regular credential rotation
- Audit logging for all access

**API Keys:**
- Unique keys per integration
- Key rotation schedule
- Usage monitoring
- Immediate revocation capability

## Security Hardening

### Operating System

**ECS Fargate:**
- AWS-managed OS updates
- Minimal attack surface
- No SSH access
- Immutable infrastructure

**Database:**
- Latest PostgreSQL version
- Security patches applied
- Minimal extensions
- Restricted network access

### Application

**Spring Boot Security:**
- Security headers enabled
- CSRF protection
- XSS protection
- Secure session management

**Angular Security:**
- Content Security Policy
- XSS prevention
- Secure HTTP headers
- Input sanitization

## Disaster Recovery

### Backup Strategy

**RDS Backups:**
- Automated daily backups
- 3-day retention (dev), 7-day (prod)
- Point-in-time recovery
- Cross-region backup (prod)

**ElastiCache Backups:**
- Daily snapshots
- 3-day retention
- Manual snapshots before changes

**S3 Backups:**
- Versioning enabled (prod)
- Lifecycle policies
- Cross-region replication (prod)

### Recovery Procedures

**Database Recovery:**
```bash
# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier event-planner-restored \
  --db-snapshot-identifier snapshot-id

# Point-in-time recovery
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier event-planner-db \
  --target-db-instance-identifier event-planner-restored \
  --restore-time 2025-01-01T12:00:00Z
```

**Service Recovery:**
```bash
# Rollback ECS service
aws ecs update-service \
  --cluster event-planner-cluster \
  --service auth-service \
  --task-definition auth-service:previous-revision

# Restore S3 objects
aws s3 sync s3://backup-bucket/ s3://production-bucket/
```

## Security Monitoring Tools

### AWS Security Services

**AWS GuardDuty:**
- Threat detection
- Anomaly detection
- Continuous monitoring
- Automated alerts

**AWS Security Hub:**
- Centralized security view
- Compliance checks
- Security findings aggregation
- Automated remediation

**AWS Config:**
- Configuration tracking
- Compliance monitoring
- Change detection
- Automated remediation

### Third-Party Tools

**Grafana:**
- Security dashboard
- Real-time monitoring
- Custom alerts
- Audit log visualization

**CloudWatch:**
- Log analysis
- Metric monitoring
- Alarm management
- Dashboard creation

## Security Training

### Team Training

**Topics:**
- Security best practices
- Incident response procedures
- Compliance requirements
- Tool usage

**Frequency:**
- Quarterly security training
- Annual compliance training
- Ad-hoc training for new tools
- Incident-based training

### Documentation

**Security Runbooks:**
- Incident response procedures
- Recovery procedures
- Security scanning procedures
- Access management procedures

**Security Policies:**
- Password policy
- Access control policy
- Data classification policy
- Incident response policy

## Continuous Improvement

### Security Reviews

**Regular Reviews:**
- Weekly security dashboard review
- Monthly security audit
- Quarterly penetration testing
- Annual security assessment

### Metrics Tracking

**Security Metrics:**
- Mean time to detect (MTTD)
- Mean time to respond (MTTR)
- Number of security incidents
- Vulnerability remediation time
- Compliance score

### Process Improvement

**Continuous Improvement:**
- Post-incident reviews
- Security metrics analysis
- Tool evaluation
- Process optimization
- Documentation updates
