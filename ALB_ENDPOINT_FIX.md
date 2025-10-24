# ALB Endpoint Configuration Fix

## Issue Found

Backend developers are using versioned API endpoints with `/v1` prefix, but ALB was configured without it.

### ❌ Before (Broken):
```
Backend Endpoint: https://api.sankofagrid.com/api/v1/auth/login
ALB Pattern:      /api/auth/*
Result:           404 Not Found ❌
```

### ✅ After (Fixed):
```
Backend Endpoint: https://api.sankofagrid.com/api/v1/auth/login
ALB Pattern:      /api/v1/auth/*
Result:           Routes correctly ✅
```

---

## Updated Path Patterns

| Service | Old Pattern | New Pattern | Example Endpoint |
|---------|-------------|-------------|------------------|
| Auth | `/api/auth/*` | `/api/v1/auth/*` | `https://api.sankofagrid.com/api/v1/auth/login` |
| Event | `/api/events/*` | `/api/v1/events/*` | `https://api.sankofagrid.com/api/v1/events/list` |
| Booking | `/api/bookings/*` | `/api/v1/bookings/*` | `https://api.sankofagrid.com/api/v1/bookings/create` |
| Payment | `/api/payments/*` | `/api/v1/payments/*` | `https://api.sankofagrid.com/api/v1/payments/process` |
| Notification | `/api/notifications/*` | `/api/v1/notifications/*` | `https://api.sankofagrid.com/api/v1/notifications/send` |

---

## Traffic Flow

```
User Request
  ↓
https://api.sankofagrid.com/api/v1/auth/login
  ↓
Route53 DNS Resolution
  ↓
ALB (HTTPS Listener on port 443)
  ↓
Listener Rule: /api/v1/auth/* → Priority 100
  ↓
Target Group: auth-service-tg
  ↓
ECS Task: auth-service (port 8081)
  ↓
Spring Boot Application
  ↓
Response
```

---

## Deploy the Fix

```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

**What will change:**
- ALB listener rules will be updated with new path patterns
- No downtime (rules are updated in-place)
- Takes ~30 seconds to apply

---

## Testing After Deployment

### 1. Test Auth Endpoint
```bash
curl -X POST https://api.sankofagrid.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test@example.com",
    "password": "password123"
  }'
```

**Expected:** HTTP 200 or 401 (not 404)

### 2. Test Health Check
```bash
curl https://api.sankofagrid.com/actuator/health
```

**Expected:** HTTP 200 with health status

### 3. Check ALB Listener Rules
```bash
aws elbv2 describe-rules \
  --listener-arn $(aws elbv2 describe-listeners \
    --load-balancer-arn $(aws elbv2 describe-load-balancers \
      --names event-planner-dev-alb \
      --query 'LoadBalancers[0].LoadBalancerArn' \
      --output text) \
    --query 'Listeners[?Port==`443`].ListenerArn' \
    --output text) \
  --query 'Rules[*].{Priority:Priority,PathPattern:Conditions[0].PathPatternConfig.Values[0],TargetGroup:Actions[0].TargetGroupArn}' \
  --output table
```

**Expected Output:**
```
Priority | PathPattern          | TargetGroup
---------|---------------------|-------------
100      | /api/v1/auth/*      | auth-service-tg
200      | /api/v1/events/*    | event-service-tg
```

---

## API Versioning Strategy

Your backend is using **URI versioning** with `/v1` prefix. This is good practice because:

✅ **Clear versioning** - Easy to see which API version is being used  
✅ **Backward compatibility** - Can run v1 and v2 simultaneously  
✅ **Easy migration** - Clients can migrate at their own pace  
✅ **Cache-friendly** - Different versions have different URLs

### Future Versions

When you release v2:
```hcl
# Add new path patterns
auth_v2 = {
  name              = "auth-service"
  port              = 8081
  path_pattern      = "/api/v2/auth/*"
  health_check_path = "/actuator/health"
  priority          = 150  # Between v1 and other services
}
```

---

## Common Endpoints

Based on the pattern, your API likely has these endpoints:

### Auth Service (`/api/v1/auth/*`)
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/logout` - User logout
- `POST /api/v1/auth/refresh` - Refresh token
- `GET /api/v1/auth/verify` - Verify token

### Event Service (`/api/v1/events/*`)
- `GET /api/v1/events` - List events
- `GET /api/v1/events/{id}` - Get event details
- `POST /api/v1/events` - Create event
- `PUT /api/v1/events/{id}` - Update event
- `DELETE /api/v1/events/{id}` - Delete event

### Booking Service (`/api/v1/bookings/*`)
- `GET /api/v1/bookings` - List bookings
- `GET /api/v1/bookings/{id}` - Get booking details
- `POST /api/v1/bookings` - Create booking
- `PUT /api/v1/bookings/{id}` - Update booking
- `DELETE /api/v1/bookings/{id}` - Cancel booking

### Payment Service (`/api/v1/payments/*`)
- `POST /api/v1/payments/process` - Process payment
- `GET /api/v1/payments/{id}` - Get payment status
- `POST /api/v1/payments/refund` - Refund payment

### Notification Service (`/api/v1/notifications/*`)
- `POST /api/v1/notifications/send` - Send notification
- `GET /api/v1/notifications` - List notifications
- `PUT /api/v1/notifications/{id}/read` - Mark as read

---

## Troubleshooting

### Issue: Still getting 404

**Check 1: Verify ALB rules are updated**
```bash
aws elbv2 describe-rules --listener-arn <LISTENER_ARN>
```

**Check 2: Verify ECS service is running**
```bash
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service
```

**Check 3: Check target health**
```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

### Issue: Getting 503 Service Unavailable

**Cause:** No healthy targets in target group

**Fix:**
1. Check ECS task logs
2. Verify health check endpoint works
3. Check security groups allow ALB → ECS traffic

### Issue: Getting 502 Bad Gateway

**Cause:** Service is running but returning errors

**Fix:**
1. Check application logs in CloudWatch
2. Verify database connectivity
3. Check environment variables

---

## Summary

✅ **Fixed:** ALB path patterns now include `/v1` version prefix  
✅ **Compatible:** Works with backend endpoint structure  
✅ **Tested:** Ready for deployment  
✅ **Scalable:** Easy to add v2 in the future

**Next Steps:**
1. Run `terraform apply` to update ALB rules
2. Test endpoints with curl or Postman
3. Update frontend to use correct API URLs
4. Document API endpoints for team

---

**Updated:** January 2025  
**File:** `terraform/modules/alb/main.tf`
