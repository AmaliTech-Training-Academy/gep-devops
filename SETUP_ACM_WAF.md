# ACM Certificate & WAF Setup Guide

## Changes Made

### 1. ✅ ACM Module Created
- **Location:** `terraform/modules/acm/`
- **Certificates:**
  - ALB Certificate (Regional - eu-west-1): `api.sankofagrid.com`
  - CloudFront Certificate (us-east-1): `events.sankofagrid.com`
- **Validation:** DNS (manual - add records to Cloudflare)

### 2. ✅ WAF Module Created
- **Location:** `terraform/modules/waf/`
- **Rules:**
  - AWS Managed Common Rule Set (SQL injection, XSS protection)
  - Known Bad Inputs protection
  - Rate limiting (2000 requests per 5 min per IP)
  - Optional geo-blocking
- **Scope:** CloudFront (us-east-1)

### 3. ⚠️ Route53 Module - TO BE REMOVED
Since you're using Cloudflare DNS, Route53 is not needed.

### 4. ⚠️ ALB HTTP/HTTPS - TO BE CONFIGURED
Need to enable HTTP redirect to HTTPS when certificate is added.

---

## Step-by-Step Implementation

### STEP 1: Add Provider for us-east-1

Add to `terraform/environments/dev/main.tf` after existing providers:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
    }
  }
}
```

### STEP 2: Add ACM Module

Add after IAM module in `terraform/environments/dev/main.tf`:

```hcl
# ==============================================================================
# ACM Module - SSL/TLS Certificates
# ==============================================================================

module "acm" {
  source = "../../modules/acm"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment

  # ALB Certificate (Regional - eu-west-1)
  create_alb_certificate          = true
  alb_domain_name                 = "api.sankofagrid.com"
  alb_subject_alternative_names   = []

  # CloudFront Certificate (us-east-1)
  create_cloudfront_certificate          = true
  cloudfront_domain_name                 = "events.sankofagrid.com"
  cloudfront_subject_alternative_names   = []

  common_tags = local.common_tags
}
```

### STEP 3: Add WAF Module

Add after ACM module:

```hcl
# ==============================================================================
# WAF Module - Web Application Firewall
# ==============================================================================

module "waf" {
  source = "../../modules/waf"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment

  rate_limit          = 2000  # Requests per 5 min per IP
  enable_geo_blocking = false
  blocked_countries   = []    # e.g., ["CN", "RU"] if needed

  common_tags = local.common_tags
}
```

### STEP 4: Update CloudFront Module

Replace CloudFront module configuration:

```hcl
module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name                   = var.project_name
  environment                    = var.environment
  s3_bucket_id                   = module.s3.assets_bucket_id
  s3_bucket_regional_domain_name = module.s3.assets_bucket_regional_domain_name
  
  alb_domain_name = ""  # Not using ALB origin for now

  # UPDATED: Add custom domain
  domain_aliases      = ["events.sankofagrid.com"]
  acm_certificate_arn = module.acm.cloudfront_certificate_arn

  # UPDATED: Enable WAF
  waf_web_acl_arn = module.waf.web_acl_arn

  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 0

  forward_cookies         = false
  forward_query_strings   = true
  forward_headers_enabled = false

  enable_origin_shield = false
  origin_shield_region = var.aws_region

  geo_restriction_type      = "none"
  geo_restriction_locations = []

  enable_logging = true
  logging_bucket = module.s3.logs_bucket_id != null ? "${module.s3.logs_bucket_id}.s3.amazonaws.com" : ""
  logging_prefix = "cloudfront/"

  cors_allowed_origins = ["*"]

  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:;"

  enable_url_rewrite = true

  custom_error_responses = [
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]

  common_tags = local.common_tags
}
```

### STEP 5: Update ALB Module

Replace ALB module configuration:

```hcl
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id

  # UPDATED: Add certificate
  certificate_arn = module.acm.alb_certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"

  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 3
  health_check_timeout             = 5
  health_check_interval            = 30

  deregistration_delay = 30

  enable_access_logs = true
  access_logs_bucket = module.s3.logs_bucket_id
  access_logs_prefix = "alb"

  enable_deletion_protection = false

  response_time_alarm_threshold = 2
  error_5xx_alarm_threshold     = 10
  alarm_actions                 = [module.cloudwatch.sns_topic_arn]

  tags = local.common_tags
}
```

### STEP 6: Remove Route53 Module

Delete or comment out the entire Route53 module block in `main.tf`.

### STEP 7: Update ALB HTTP Listener to Redirect

In `terraform/modules/alb/main.tf`, update HTTP listener:

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != "" ? "redirect" : "fixed-response"

    # Redirect to HTTPS when certificate exists
    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # Fixed response when no certificate
    dynamic "fixed_response" {
      for_each = var.certificate_arn == "" ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "ALB is running"
        status_code  = "200"
      }
    }
  }

  tags = local.common_tags
}
```

---

## DNS Configuration in Cloudflare

### After Running `terraform apply`

1. **Get DNS Validation Records:**
```bash
cd terraform/environments/dev
terraform output acm_alb_validation_records
terraform output acm_cloudfront_validation_records
```

2. **Add to Cloudflare DNS:**

For **api.sankofagrid.com** (ALB):
```
Type: CNAME
Name: _abc123.api.sankofagrid.com
Value: _xyz456.acm-validations.aws.
TTL: Auto
Proxy: DNS only (gray cloud)
```

For **events.sankofagrid.com** (CloudFront):
```
Type: CNAME
Name: _def789.events.sankofagrid.com
Value: _uvw012.acm-validations.aws.
TTL: Auto
Proxy: DNS only (gray cloud)
```

3. **Add Application Records:**

For **api.sankofagrid.com** → ALB:
```
Type: CNAME
Name: api
Value: <ALB-DNS-NAME>.eu-west-1.elb.amazonaws.com
TTL: Auto
Proxy: DNS only (gray cloud)
```

For **events.sankofagrid.com** → CloudFront:
```
Type: CNAME
Name: events
Value: <CLOUDFRONT-DOMAIN>.cloudfront.net
TTL: Auto
Proxy: DNS only (gray cloud)
```

---

## Outputs to Add

Add to `terraform/environments/dev/outputs.tf`:

```hcl
# ACM Outputs
output "acm_alb_certificate_arn" {
  description = "ARN of ALB certificate"
  value       = module.acm.alb_certificate_arn
}

output "acm_alb_validation_records" {
  description = "DNS validation records for ALB certificate (add to Cloudflare)"
  value       = module.acm.alb_certificate_domain_validation_options
}

output "acm_cloudfront_certificate_arn" {
  description = "ARN of CloudFront certificate"
  value       = module.acm.cloudfront_certificate_arn
}

output "acm_cloudfront_validation_records" {
  description = "DNS validation records for CloudFront certificate (add to Cloudflare)"
  value       = module.acm.cloudfront_certificate_domain_validation_options
}

# WAF Outputs
output "waf_web_acl_arn" {
  description = "ARN of WAF Web ACL"
  value       = module.waf.web_acl_arn
}

# ALB DNS
output "alb_dns_name" {
  description = "DNS name of ALB (add to Cloudflare as CNAME for api.sankofagrid.com)"
  value       = module.alb.alb_dns_name
}

# CloudFront DNS
output "cloudfront_domain_name" {
  description = "CloudFront domain (add to Cloudflare as CNAME for events.sankofagrid.com)"
  value       = module.cloudfront.distribution_domain_name
}
```

---

## Deployment Steps

### 1. Apply Terraform
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 2. Get Validation Records
```bash
terraform output acm_alb_validation_records
terraform output acm_cloudfront_validation_records
```

### 3. Add DNS Records to Cloudflare
- Add validation CNAME records
- Wait 5-30 minutes for validation

### 4. Verify Certificates
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn <ALB-CERT-ARN> --region eu-west-1
aws acm describe-certificate --certificate-arn <CF-CERT-ARN> --region us-east-1
```

### 5. Add Application DNS Records
```bash
# Get DNS names
terraform output alb_dns_name
terraform output cloudfront_domain_name

# Add to Cloudflare:
# api.sankofagrid.com → ALB DNS
# events.sankofagrid.com → CloudFront DNS
```

### 6. Test
```bash
# Test ALB (should redirect HTTP → HTTPS)
curl -I http://api.sankofagrid.com
# Expected: HTTP/1.1 301 Moved Permanently

curl -I https://api.sankofagrid.com/api/auth/health
# Expected: HTTP/2 200

# Test CloudFront
curl -I https://events.sankofagrid.com
# Expected: HTTP/2 200
```

---

## Summary

✅ ACM certificates for both domains  
✅ WAF enabled for CloudFront  
✅ HTTP → HTTPS redirect for ALB  
✅ Both HTTP and HTTPS work on ALB  
✅ Route53 removed (using Cloudflare)  
✅ Manual DNS validation via Cloudflare  

**Cost Impact:**
- ACM Certificates: FREE
- WAF: ~$5-10/month
- No Route53 costs

**Security:**
- SSL/TLS encryption
- WAF protection (SQL injection, XSS, rate limiting)
- HTTPS enforced
