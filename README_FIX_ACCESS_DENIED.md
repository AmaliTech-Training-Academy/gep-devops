# 🔴 URGENT: Fix CloudFront Access Denied

## Current Problem
Your CloudFront URL returns: **Access Denied**
```
https://d2atd3vdxzjhxk.cloudfront.net
```

## Why This Happens
The S3 bucket policy that allows CloudFront to read files **doesn't exist yet** in your AWS account.

I've already added the code to create it, but you need to **apply** it.

---

## ✅ SOLUTION (3 Simple Steps)

### Step 1: Apply Terraform
```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev
terraform apply -auto-approve
```

**What this does:** Creates the S3 bucket policy that allows CloudFront to access your S3 bucket.

**Expected output:**
```
aws_s3_bucket_policy.cloudfront_access: Creating...
aws_s3_bucket_policy.cloudfront_access: Creation complete
```

---

### Step 2: Upload Test File
```bash
# Still in terraform/environments/dev directory
BUCKET=$(terraform output -raw assets_bucket_id)

# Create and upload test file
echo '<!DOCTYPE html><html><body><h1>✅ Success!</h1></body></html>' > /tmp/index.html
aws s3 cp /tmp/index.html s3://$BUCKET/index.html
```

**What this does:** Puts an index.html file in your S3 bucket so CloudFront has something to serve.

---

### Step 3: Clear CloudFront Cache
```bash
# Still in terraform/environments/dev directory
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
```

**What this does:** Tells CloudFront to forget its old cached "Access Denied" response and fetch fresh content from S3.

---

### Step 4: Test (Wait 2 Minutes First)
```bash
# Wait for changes to propagate
sleep 120

# Test
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
curl -I https://$CLOUDFRONT_URL
```

**Expected result:**
```
HTTP/2 200 
content-type: text/html
```

✅ **If you see HTTP/2 200, it's working!**

❌ **If you still see 403, wait another 2 minutes and try again.**

---

## 🚀 Quick One-Liner (All Steps Combined)

```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev && \
terraform apply -auto-approve && \
BUCKET=$(terraform output -raw assets_bucket_id) && \
echo '<!DOCTYPE html><html><body><h1>✅ Success!</h1></body></html>' > /tmp/index.html && \
aws s3 cp /tmp/index.html s3://$BUCKET/index.html && \
DIST_ID=$(terraform output -raw cloudfront_distribution_id) && \
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" && \
echo "Waiting 2 minutes..." && sleep 120 && \
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name) && \
curl -I https://$CLOUDFRONT_URL
```

---

## 🔍 Verify It Worked

### Check 1: Bucket Policy Exists
```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev
BUCKET=$(terraform output -raw assets_bucket_id)
aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text | jq
```

You should see `"Service": "cloudfront.amazonaws.com"` in the output.

### Check 2: File in S3
```bash
aws s3 ls s3://$BUCKET/
```

You should see `index.html`.

### Check 3: CloudFront Returns 200
```bash
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
curl -I https://$CLOUDFRONT_URL 2>&1 | grep "HTTP"
```

You should see `HTTP/2 200`.

---

## 🐛 Troubleshooting

### Problem: "terraform apply" fails with "No changes"

**Solution:** The bucket policy code might not be in main.tf. Check:
```bash
grep -A 10 "aws_s3_bucket_policy" main.tf
```

If you don't see it, the file wasn't saved. Re-apply my changes.

### Problem: Still getting 403 after 5 minutes

**Possible causes:**
1. Bucket policy wasn't created
2. Wrong CloudFront distribution ARN in policy
3. Files not in S3

**Debug:**
```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev

# Check if policy exists
terraform state show aws_s3_bucket_policy.cloudfront_access

# If error "No instance found", the policy wasn't created
# Run: terraform apply -auto-approve
```

### Problem: AWS CLI errors

**Error:** "The config profile could not be found"

**Solution:**
```bash
# Set AWS profile
export AWS_PROFILE=your-profile-name

# Or configure default
aws configure
```

---

## 📋 What I Changed in Your Code

### File: `terraform/environments/dev/main.tf`

**Added after CloudFront module:**
```hcl
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = module.s3.assets_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipal"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${module.s3.assets_bucket_arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = module.cloudfront.distribution_arn
        }
      }
    }]
  })

  depends_on = [module.cloudfront, module.s3]
}
```

This policy says: "Allow cloudfront.amazonaws.com to read (s3:GetObject) any file in the S3 bucket, but only if the request comes from this specific CloudFront distribution."

---

## ✅ Success Checklist

- [ ] Ran `terraform apply -auto-approve`
- [ ] Saw "aws_s3_bucket_policy.cloudfront_access: Creation complete"
- [ ] Uploaded index.html to S3
- [ ] Created CloudFront invalidation
- [ ] Waited 2-3 minutes
- [ ] Tested with curl - got HTTP 200
- [ ] Opened in browser - saw content

---

## 🎯 Bottom Line

**You MUST run `terraform apply` to create the bucket policy.**

Without it, CloudFront has no permission to access S3, which is why you get "Access Denied".

The code is ready. Just apply it.

```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev
terraform apply -auto-approve
```

That's it. That's the fix.
