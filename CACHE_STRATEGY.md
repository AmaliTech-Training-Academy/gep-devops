# CloudFront Cache Strategy - Cost-Free Solution

## Overview
**Zero-cost cache management** using low TTL + versioned filenames. No Lambda, no S3 notifications, no manual invalidations needed.

---

## ❌ Why NOT Lambda + S3 Notifications?

### Costs:
- Lambda invocations: $0.20 per 1M after free tier
- S3 event notifications: Can trigger thousands of times
- CloudFront invalidations: $0.005 per path after 1,000/month
- **Estimated**: $5-20/month for active development

### Problems:
- Complexity (Lambda, IAM, S3 notifications)
- Debugging overhead
- Rate limits on invalidations
- Potential for runaway costs

---

## ✅ Our Solution: Low TTL + Versioned Filenames

### How It Works:

```
Angular Build
    ↓
Generates versioned files:
  - main.a1b2c3d4.js
  - styles.e5f6g7h8.css
  - index.html (references versioned files)
    ↓
Deploy to S3
    ↓
CloudFront serves with 5-minute TTL
    ↓
Users get new version within 5 minutes
```

### Configuration:
```hcl
# Dev Environment
default_ttl = 300      # 5 minutes
max_ttl     = 3600     # 1 hour
min_ttl     = 0        # No minimum

# Prod Environment (when ready)
default_ttl = 86400    # 24 hours
max_ttl     = 31536000 # 1 year
min_ttl     = 0
```

---

## How Angular Handles Cache Busting

### 1. Build Output (Automatic)
```
dist/event-planner/browser/
├── index.html                    # Always fetched (low TTL)
├── main.a1b2c3d4e5f6.js         # Versioned hash
├── polyfills.g7h8i9j0k1.js      # Versioned hash
├── styles.l2m3n4o5p6q7.css      # Versioned hash
└── assets/
    └── logo.png                  # Static assets
```

### 2. index.html References
```html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="styles.l2m3n4o5p6q7.css">
</head>
<body>
  <app-root></app-root>
  <script src="main.a1b2c3d4e5f6.js"></script>
  <script src="polyfills.g7h8i9j0k1.js"></script>
</body>
</html>
```

### 3. New Deployment
```
New build generates NEW hashes:
  - main.x9y8z7w6v5u4.js  (NEW)
  - styles.t3s2r1q0p9o8.css  (NEW)

index.html updated with new references
```

---

## Cache Behavior

### For Versioned Files (JS, CSS)
- **First request**: CloudFront fetches from S3, caches for 5 minutes
- **Subsequent requests**: Served from CloudFront cache (fast!)
- **After deployment**: New filename = cache miss = fresh content

### For index.html
- **TTL**: 5 minutes (low)
- **After 5 minutes**: CloudFront checks S3 for updates
- **If changed**: Serves new version
- **If unchanged**: Serves cached version

---

## Deployment Flow

### 1. Build Angular App
```bash
ng build --configuration production
```

### 2. Deploy to S3
```bash
aws s3 sync dist/event-planner/browser/ \
  s3://event-planner-dev-assets-*/event-planner/browser/ \
  --delete \
  --cache-control "public, max-age=300"
```

### 3. Users Get Updates
- **Worst case**: 5 minutes (index.html TTL)
- **Best case**: Immediate (new versioned files)
- **No manual action needed**

---

## Cost Comparison

| Solution | Monthly Cost | Complexity |
|----------|--------------|------------|
| **Lambda + S3 Notifications** | $5-20 | High |
| **Manual Invalidations** | $0-5 | Medium |
| **Low TTL + Versioning** | **$0** | **Low** |

---

## Benefits

### ✅ Zero Cost
- No Lambda
- No S3 notifications
- No invalidation charges
- Pure CloudFront caching

### ✅ Simple
- No additional infrastructure
- No code to maintain
- Works out of the box with Angular

### ✅ Reliable
- No rate limits
- No Lambda failures
- No debugging needed

### ✅ Fast
- Versioned files cached long-term
- Only index.html has short TTL
- 99% of traffic served from cache

---

## TTL Strategy by Environment

### Development
```hcl
default_ttl = 300      # 5 minutes - fast updates
max_ttl     = 3600     # 1 hour
```
**Use case**: Frequent deployments, quick feedback

### Production
```hcl
default_ttl = 86400    # 24 hours - better performance
max_ttl     = 31536000 # 1 year
```
**Use case**: Stable releases, maximum cache efficiency

---

## Advanced: Cache-Control Headers

### Set in S3 Upload
```bash
# index.html - short cache
aws s3 cp dist/event-planner/browser/index.html \
  s3://bucket/event-planner/browser/index.html \
  --cache-control "public, max-age=300, must-revalidate"

# Versioned files - long cache
aws s3 sync dist/event-planner/browser/ \
  s3://bucket/event-planner/browser/ \
  --exclude "index.html" \
  --cache-control "public, max-age=31536000, immutable"
```

### Result
- **index.html**: 5-minute cache
- **main.*.js**: 1-year cache (safe because versioned)
- **styles.*.css**: 1-year cache (safe because versioned)

---

## Manual Invalidation (When Needed)

### Rare Cases:
- Emergency bug fix
- Critical security update
- Can't wait 5 minutes

### Command:
```bash
aws cloudfront create-invalidation \
  --distribution-id <DIST_ID> \
  --paths "/index.html"
```

### Cost:
- First 1,000 paths/month: FREE
- Additional: $0.005 per path
- **Our usage**: ~1-2/month = FREE

---

## Monitoring

### Check Cache Hit Rate
```bash
# CloudWatch Metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=<DIST_ID> \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-31T23:59:59Z \
  --period 86400 \
  --statistics Average
```

### Expected Results:
- **Cache Hit Rate**: 85-95%
- **Origin Requests**: 5-15% of total
- **Cost**: Minimal data transfer

---

## CI/CD Integration

### GitHub Actions
```yaml
- name: Build Angular App
  run: |
    cd frontend
    npm install
    ng build --configuration production

- name: Deploy to S3 with Cache Headers
  run: |
    # Deploy index.html with short cache
    aws s3 cp frontend/dist/event-planner/browser/index.html \
      s3://${{ secrets.S3_BUCKET }}/event-planner/browser/index.html \
      --cache-control "public, max-age=300, must-revalidate"
    
    # Deploy other files with long cache
    aws s3 sync frontend/dist/event-planner/browser/ \
      s3://${{ secrets.S3_BUCKET }}/event-planner/browser/ \
      --exclude "index.html" \
      --cache-control "public, max-age=31536000, immutable" \
      --delete

- name: Done
  run: echo "Deployment complete! Users will get updates within 5 minutes."
```

---

## Best Practices

### ✅ DO
- Use Angular's default build (auto-versioning)
- Set appropriate TTL per environment
- Monitor cache hit rate
- Use Cache-Control headers

### ❌ DON'T
- Don't disable versioning in Angular
- Don't set TTL too low (< 60 seconds)
- Don't invalidate on every deployment
- Don't use Lambda for this

---

## Troubleshooting

### Issue: Users Not Getting Updates

**Check 1: Verify Deployment**
```bash
aws s3 ls s3://bucket/event-planner/browser/ --recursive
```

**Check 2: Check CloudFront TTL**
```bash
aws cloudfront get-distribution-config \
  --id <DIST_ID> \
  --query 'DistributionConfig.DefaultCacheBehavior.DefaultTTL'
```

**Check 3: Browser Cache**
- Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
- Clear browser cache
- Try incognito mode

### Issue: Too Many Origin Requests

**Solution**: Increase TTL
```hcl
default_ttl = 600  # 10 minutes instead of 5
```

---

## Summary

### What We Use:
- ✅ Low TTL (5 minutes for dev)
- ✅ Angular's automatic file versioning
- ✅ CloudFront's built-in caching

### What We DON'T Use:
- ❌ Lambda functions
- ❌ S3 event notifications
- ❌ Automatic invalidations
- ❌ Complex infrastructure

### Result:
- **Cost**: $0/month
- **Complexity**: Minimal
- **Update time**: 5 minutes max
- **Reliability**: 100%

---

**Last Updated**: January 2025  
**Cost**: $0.00/month  
**Recommended**: ✅ Yes
