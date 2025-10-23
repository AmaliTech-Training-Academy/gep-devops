# ALB Certificate Setup Guide

## What Was Added

1. **ACM Module** - Creates SSL certificate for `api.sankofagrid.com`
2. **ALB Configuration** - Updated to use the certificate for HTTPS
3. **Outputs** - Added certificate ARN and validation records

## Deploy the Certificate

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

## Get Validation Records

After `terraform apply`:

```bash
terraform output acm_alb_validation_records
```

**Example output:**
```json
{
  "api.sankofagrid.com" = {
    "name"  = "_abc123def456.api.sankofagrid.com"
    "type"  = "CNAME"
    "value" = "_xyz789.acm-validations.aws."
  }
}
```

## Add DNS Record in Cloudflare

1. Go to **Cloudflare Dashboard** → **sankofagrid.com** → **DNS**
2. Click **Add record**
3. Configure:
   - **Type**: CNAME
   - **Name**: `_abc123def456.api` (copy from terraform output, remove `.sankofagrid.com`)
   - **Target**: `_xyz789.acm-validations.aws.` (copy from terraform output)
   - **Proxy status**: DNS only (gray cloud)
   - **TTL**: Auto
4. Click **Save**

## Check Certificate Status

```bash
# Check status
terraform output acm_alb_certificate_status

# Or via AWS CLI
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_alb_certificate_arn) \
  --region eu-west-1 \
  --query 'Certificate.Status' \
  --output text
```

**Wait 5-30 minutes** for status to change from `PENDING_VALIDATION` to `ISSUED`.

## Verify HTTPS Works

Once certificate is `ISSUED`:

```bash
# Get ALB DNS
terraform output alb_dns_name

# Test HTTPS (will fail until DNS is configured)
curl -I https://api.sankofagrid.com
```

## Add Traffic Routing DNS Record

After certificate is issued, add CNAME for actual traffic:

1. Go to **Cloudflare** → **DNS**
2. Add record:
   - **Type**: CNAME
   - **Name**: `api`
   - **Target**: `event-20251021192925875500000007-464541125.eu-west-1.elb.amazonaws.com` (from terraform output)
   - **Proxy status**: DNS only (gray cloud)
   - **TTL**: Auto

## Test Complete Setup

```bash
# Test HTTPS
curl -I https://api.sankofagrid.com/health

# Should return 200 OK with HTTPS
```

## Troubleshooting

### Certificate Stuck in PENDING_VALIDATION
- Verify CNAME record is correct in Cloudflare
- Check Proxy status is "DNS only" (gray cloud)
- Wait up to 30 minutes

### HTTPS Not Working
- Verify certificate status is `ISSUED`
- Check ALB listener has certificate attached
- Verify DNS CNAME points to ALB

### Check ALB Listeners
```bash
aws elbv2 describe-listeners \
  --load-balancer-arn $(terraform output -raw alb_arn) \
  --region eu-west-1
```

Should show both HTTP (port 80) and HTTPS (port 443) listeners.
