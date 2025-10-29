# CloudFront Automatic Cache Invalidation

## Overview
Automatic CloudFront cache invalidation ensures users always get the latest frontend content immediately after deployment, without manual intervention.

---

## How It Works

```
┌─────────────────┐
│  Developer      │
│  Deploys to S3  │
└────────┬────────┘
         │
         ↓
┌─────────────────────────────────┐
│  S3 Bucket Event Notification   │
│  (ObjectCreated/ObjectRemoved)  │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  Lambda Function Triggered      │
│  (cloudfront-invalidation)      │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  CloudFront Invalidation API    │
│  CreateInvalidation(paths: /*)  │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  CloudFront Cache Cleared       │
│  Users get latest content       │
└─────────────────────────────────┘
```

---

## Components

### 1. Lambda Function
**Name**: `event-planner-dev-cf-invalidation`
**Runtime**: Python 3.11
**Timeout**: 60 seconds
**Trigger**: S3 bucket events

**Code**:
```python
import json
import boto3
import os
from datetime import datetime

cloudfront = boto3.client('cloudfront')

def handler(event, context):
    distribution_id = os.environ['DISTRIBUTION_ID']
    
    # Create invalidation for all paths
    try:
        response = cloudfront.create_invalidation(
            DistributionId=distribution_id,
            InvalidationBatch={
                'Paths': {
                    'Quantity': 1,
                    'Items': ['/*']
                },
                'CallerReference': f'lambda-{datetime.now().timestamp()}'
            }
        )
        
        print(f"Invalidation created: {response['Invalidation']['Id']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cache invalidation initiated',
                'invalidationId': response['Invalidation']['Id']
            })
        }
    except Exception as e:
        print(f"Error creating invalidation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

### 2. IAM Role & Permissions
**Role**: `event-planner-dev-cf-invalidation-role`

**Permissions**:
- `cloudfront:CreateInvalidation`
- `cloudfront:GetInvalidation`
- `cloudfront:ListInvalidations`
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

### 3. S3 Bucket Notification
**Bucket**: `event-planner-dev-assets-*`
**Events**: 
- `s3:ObjectCreated:*` (PUT, POST, COPY)
- `s3:ObjectRemoved:*` (DELETE)

**Filter**: `event-planner/browser/` (only frontend files)

### 4. CloudWatch Logs
**Log Group**: `/aws/lambda/event-planner-dev-cf-invalidation`
**Retention**: 3 days

---

## Benefits

### ✅ Automatic Updates
- No manual cache invalidation needed
- Users get latest content immediately
- Zero downtime deployments

### ✅ Cost Efficient
- Only invalidates when files change
- Uses Lambda free tier (1M requests/month)
- CloudFront: First 1,000 invalidations/month free

### ✅ Developer Friendly
- Deploy and forget
- No additional steps in CI/CD
- Works with any deployment tool

### ✅ Reliable
- Automatic retries on failure
- CloudWatch logs for debugging
- IAM least privilege access

---

## Deployment Flow

### 1. Frontend Deployment
```bash
# Build Angular app
ng build --configuration production

# Deploy to S3
aws s3 sync dist/event-planner/browser/ \
  s3://event-planner-dev-assets-*/event-planner/browser/ \
  --delete
```

### 2. Automatic Invalidation
```
S3 Upload Complete
    ↓
Lambda Triggered (within seconds)
    ↓
CloudFront Invalidation Created
    ↓
Cache Cleared (5-10 minutes)
    ↓
Users Get Latest Content
```

---

## Monitoring

### Check Invalidation Status
```bash
# List recent invalidations
aws cloudfront list-invalidations \
  --distribution-id <DISTRIBUTION_ID> \
  --max-items 10

# Get specific invalidation
aws cloudfront get-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --id <INVALIDATION_ID>
```

### View Lambda Logs
```bash
# Tail logs
aws logs tail /aws/lambda/event-planner-dev-cf-invalidation \
  --follow \
  --region eu-west-1

# Query recent invocations
aws logs filter-log-events \
  --log-group-name /aws/lambda/event-planner-dev-cf-invalidation \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --region eu-west-1
```

### CloudWatch Metrics
- **Invocations**: Number of times Lambda was triggered
- **Duration**: Time taken to create invalidation
- **Errors**: Failed invalidation attempts
- **Throttles**: Rate limit hits

---

## Cost Analysis

### Lambda Costs
- **Requests**: 1M free/month, then $0.20 per 1M
- **Duration**: 400,000 GB-seconds free/month
- **Typical**: ~100 deployments/month = FREE

### CloudFront Invalidation Costs
- **First 1,000 paths/month**: FREE
- **Additional paths**: $0.005 per path
- **Our setup**: Invalidates `/*` = 1 path per deployment
- **Typical**: ~100 deployments/month = FREE

### Total Monthly Cost
**Estimated**: $0.00 (within free tier)

---

## Troubleshooting

### Issue: Lambda Not Triggering

**Check S3 Notification**:
```bash
aws s3api get-bucket-notification-configuration \
  --bucket event-planner-dev-assets-*
```

**Verify Lambda Permission**:
```bash
aws lambda get-policy \
  --function-name event-planner-dev-cf-invalidation
```

### Issue: Invalidation Fails

**Check Lambda Logs**:
```bash
aws logs tail /aws/lambda/event-planner-dev-cf-invalidation \
  --since 1h
```

**Verify IAM Permissions**:
```bash
aws iam get-role-policy \
  --role-name event-planner-dev-cf-invalidation-role \
  --policy-name cf-invalidation-policy
```

### Issue: Cache Not Clearing

**Check Invalidation Status**:
```bash
aws cloudfront get-invalidation \
  --distribution-id <DIST_ID> \
  --id <INVALIDATION_ID>
```

**Status Values**:
- `InProgress`: Invalidation is being processed (5-10 min)
- `Completed`: Cache cleared successfully
- `Failed`: Check Lambda logs for errors

---

## Manual Invalidation (Backup)

If automatic invalidation fails, manually invalidate:

```bash
# Invalidate all paths
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"

# Invalidate specific paths
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/index.html" "/main.*.js" "/styles.*.css"
```

---

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]
    paths: ['frontend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Angular App
        run: |
          cd frontend
          npm install
          ng build --configuration production
      
      - name: Deploy to S3
        run: |
          aws s3 sync frontend/dist/event-planner/browser/ \
            s3://event-planner-dev-assets-*/event-planner/browser/ \
            --delete
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      
      # No manual invalidation needed - Lambda handles it automatically!
      
      - name: Wait for Invalidation
        run: |
          echo "Cache invalidation triggered automatically"
          echo "Users will get latest content in 5-10 minutes"
```

---

## Best Practices

### ✅ DO
- Monitor Lambda invocations in CloudWatch
- Set up SNS alerts for Lambda failures
- Test invalidation after major deployments
- Keep Lambda timeout at 60 seconds
- Use CloudWatch Insights for log analysis

### ❌ DON'T
- Don't invalidate too frequently (rate limits)
- Don't invalidate during high traffic periods
- Don't delete Lambda logs (needed for debugging)
- Don't modify Lambda code without testing
- Don't remove IAM permissions

---

## Future Enhancements

### Selective Invalidation
Instead of `/*`, invalidate only changed files:
```python
# Parse S3 event to get changed file paths
changed_paths = [record['s3']['object']['key'] for record in event['Records']]
```

### Slack Notifications
Send deployment notifications:
```python
import requests

def notify_slack(invalidation_id):
    webhook_url = os.environ['SLACK_WEBHOOK']
    requests.post(webhook_url, json={
        'text': f'🚀 Frontend deployed! Invalidation: {invalidation_id}'
    })
```

### Invalidation Batching
Batch multiple file changes into single invalidation:
```python
# Wait 30 seconds to collect all changes
# Then create single invalidation
```

---

## Resources

- [CloudFront Invalidation API](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html)
- [S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html)
- [Lambda with S3](https://docs.aws.amazon.com/lambda/latest/dg/with-s3.html)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)

---

**Last Updated**: January 2025  
**Status**: ✅ Implemented  
**Cost**: $0.00/month (free tier)
