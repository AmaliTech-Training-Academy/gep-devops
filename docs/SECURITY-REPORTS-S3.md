# Security Reports S3 Upload

## Overview

The frontend CI/CD pipeline now automatically uploads security scan results to S3 for centralized storage and analysis.

## What Gets Uploaded

### 1. NPM Audit Results
- **File**: `audit-results.json`
- **Content**: Vulnerability scan results from `npm audit`
- **Format**: JSON

### 2. SAST Scan Results (Future)
- **File**: `semgrep-results.sarif`
- **Content**: Static analysis security testing results
- **Format**: SARIF (Static Analysis Results Interchange Format)

### 3. Scan Summary
- **File**: `scan-summary.json`
- **Content**: Metadata about the scan (timestamp, environment, commit, actor)
- **Format**: JSON

## S3 Structure

```
s3://event-planner-{env}-security-reports-{account-id}/
└── frontend/
    └── {environment}/
        └── {timestamp}/
            ├── audit-results.json
            ├── semgrep-results.sarif
            └── scan-summary.json
```

### Example Path
```
s3://event-planner-dev-security-reports-123456789012/
└── frontend/
    └── dev/
        └── 20241201-143022/
            ├── audit-results.json
            ├── semgrep-results.sarif
            └── scan-summary.json
```

## Configuration

### 1. GitHub Secrets Required

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=<your-access-key>
AWS_SECRET_ACCESS_KEY=<your-secret-key>
AWS_REGION=eu-west-1

# S3 Bucket Names (per environment)
SECURITY_REPORTS_BUCKET_DEV=event-planner-dev-security-reports-{account-id}
SECURITY_REPORTS_BUCKET_STAGING=event-planner-staging-security-reports-{account-id}
SECURITY_REPORTS_BUCKET_PROD=event-planner-prod-security-reports-{account-id}
```

### 2. Get Bucket Names

Use the helper script to get the actual bucket names:

```bash
./scripts/get-s3-bucket-names.sh
```

Or manually from Terraform:

```bash
cd terraform/environments/dev
terraform output s3_buckets
```

## Pipeline Integration

### When Reports Are Uploaded

- **Trigger**: After every security scan (regardless of success/failure)
- **Condition**: `if: always()` ensures upload even if scans fail
- **Timing**: Before the build-and-test job starts

### Upload Process

1. **Generate Timestamp**: `YYYYMMDD-HHMMSS` format
2. **Determine Bucket**: Based on environment (dev/staging/prod)
3. **Upload Files**: Each file type to organized S3 path
4. **Create Summary**: Metadata about the scan run
5. **Notify**: Success/failure in pipeline logs

## Benefits

### 1. Centralized Storage
- All security scan results in one location
- Easy to access and analyze across environments
- Historical tracking of security posture

### 2. Compliance & Auditing
- Permanent record of security scans
- Audit trail for compliance requirements
- Evidence of security due diligence

### 3. Analysis & Reporting
- Aggregate data across multiple scans
- Trend analysis of vulnerabilities
- Integration with security dashboards

### 4. Retention Management
- Automatic lifecycle policies (90 days retention)
- Cost-optimized storage
- Encrypted at rest

## Security Features

### 1. Encryption
- **At Rest**: AES-256 or KMS encryption
- **In Transit**: HTTPS/TLS for uploads

### 2. Access Control
- **Bucket Policy**: Restricts access to authorized principals
- **IAM**: Least privilege access for CI/CD
- **Private**: No public access allowed

### 3. Versioning
- **Enabled**: Multiple versions of reports retained
- **Lifecycle**: Old versions automatically cleaned up

## Monitoring

### 1. Pipeline Logs
- Upload success/failure logged in GitHub Actions
- File paths and sizes reported

### 2. Slack Notifications
- Security scan summary includes S3 upload status
- Environment and timestamp information

### 3. CloudWatch (Future)
- S3 access logs
- Upload metrics and alarms

## Troubleshooting

### Common Issues

#### 1. Upload Fails - Access Denied
```bash
# Check IAM permissions
aws iam get-user-policy --user-name ci-cd-user --policy-name s3-security-reports

# Verify bucket exists
aws s3 ls s3://event-planner-dev-security-reports-{account-id}/
```

#### 2. Bucket Not Found
```bash
# Get correct bucket name from Terraform
cd terraform/environments/dev
terraform output s3_buckets

# Update GitHub secrets with correct name
```

#### 3. Files Not Generated
```bash
# Check if audit results exist
ls -la frontend/audit-results.json

# Verify npm audit runs successfully
cd frontend && npm audit --json > audit-results.json
```

## Future Enhancements

### 1. Additional Scan Types
- **Dependency Check**: OWASP dependency scanning
- **License Scanning**: License compliance checks
- **Container Scanning**: Docker image vulnerabilities

### 2. Analysis Tools
- **Dashboard**: Web interface for viewing reports
- **Alerts**: Automated notifications for critical issues
- **Trends**: Historical analysis and reporting

### 3. Integration
- **JIRA**: Automatic ticket creation for vulnerabilities
- **Slack**: Rich notifications with scan details
- **Email**: Digest reports for security teams

## Related Files

- **Pipeline**: `.github/workflows/frontend-ci-cd.yml`
- **Terraform**: `terraform/modules/s3/main.tf`
- **Scripts**: `scripts/get-s3-bucket-names.sh`
- **Setup Guide**: `scripts/setup-github-secrets.md`