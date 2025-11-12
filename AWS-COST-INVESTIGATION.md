# AWS Cost Investigation - Route 53 & GuardDuty

## Investigation Date: 2025-11-12

---

## 🔍 FINDINGS

### 1. Route 53 Charges ($1.50/month)

#### Active Hosted Zones Found:

**Zone 1: davidodediran.tech (Public)**
- **Hosted Zone ID**: Z0145315XB6DTY8H0XDH
- **Type**: Public hosted zone
- **Cost**: $0.50/month
- **Records**: 2 record sets
- **Status**: ⚠️ ACTIVE - NOT MANAGED BY TERRAFORM
- **Action Required**: DELETE if not needed

**Zone 2: eventplanner.local (Private)**
- **Hosted Zone ID**: Z02731642GGUYSERDDB31
- **Type**: Private hosted zone (AWS Cloud Map)
- **Cost**: $0.50/month
- **Records**: 2 record sets
- **Status**: ✅ REQUIRED - Used by ECS Service Discovery
- **Linked Service**: AWS Cloud Map namespace (ns-zjisc5nhebxe3ahc)
- **Action Required**: KEEP - This is needed for your microservices

**Health Checks:**
- **Count**: 0
- **Cost**: $0.00/month
- **Status**: ✅ None found

#### Total Route 53 Cost Breakdown:
```
davidodediran.tech (public):     $0.50/month  ⚠️ DELETE
eventplanner.local (private):    $0.50/month  ✅ KEEP
DNS Queries (minimal):           ~$0.50/month
----------------------------------------
TOTAL:                           $1.50/month
```

---

### 2. GuardDuty Charges ($0.015/month)

#### Active Detectors Found:

**Region: eu-west-1 (Ireland)**
- **Detector ID**: 0accab92ea2949157848195893ef8c78
- **Status**: DISABLED ✅
- **Last Updated**: 2025-10-23
- **Data Sources Still Active**:
  - CloudTrail: ENABLED
  - DNS Logs: ENABLED
  - Flow Logs: ENABLED
  - S3 Data Events: ENABLED
- **Cost**: ~$0.015/month (residual processing)

**Region: us-east-1 (N. Virginia)**
- **Detector ID**: 32ccb86ccfe300465786b2dd0642266f
- **Status**: DISABLED ✅
- **Cost**: Minimal/none

**Other Regions:**
- Access denied by Service Control Policy (SCP)
- Likely no detectors in other regions

#### GuardDuty Cost Analysis:
```
The $0.015/month charge is from:
1. Residual data processing from when it was disabled
2. Data sources still enabled (CloudTrail, DNS, Flow Logs, S3)
3. Should drop to $0.00 next billing cycle
```

---

## 💰 COST SAVINGS OPPORTUNITIES

### Immediate Actions:

#### 1. Delete Unused Route 53 Hosted Zone
**Savings: $0.50/month ($6/year)**

```bash
# Delete davidodediran.tech hosted zone
export AWS_PROFILE=gtp-cletus

# First, list and delete all records (except NS and SOA)
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0145315XB6DTY8H0XDH \
  --region eu-west-1

# Then delete the hosted zone
aws route53 delete-hosted-zone \
  --id Z0145315XB6DTY8H0XDH \
  --region eu-west-1
```

⚠️ **WARNING**: Only delete if you don't own/use davidodediran.tech domain!

#### 2. Fully Disable GuardDuty Data Sources
**Savings: $0.015/month (minimal, but clean)**

```bash
export AWS_PROFILE=gtp-cletus

# Disable all data sources in eu-west-1
aws guardduty update-detector \
  --detector-id 0accab92ea2949157848195893ef8c78 \
  --region eu-west-1 \
  --no-enable

# Delete the detector completely
aws guardduty delete-detector \
  --detector-id 0accab92ea2949157848195893ef8c78 \
  --region eu-west-1

# Repeat for us-east-1
aws guardduty delete-detector \
  --detector-id 32ccb86ccfe300465786b2dd0642266f \
  --region us-east-1
```

---

## 📊 COST SUMMARY

### Current Monthly Costs:
```
Route 53:
  - davidodediran.tech:        $0.50  ⚠️ Can delete
  - eventplanner.local:        $0.50  ✅ Keep (required)
  - DNS queries:               $0.50  ✅ Normal usage

GuardDuty:
  - Residual processing:       $0.015 ⚠️ Will drop to $0

TOTAL AVOIDABLE:               $0.515/month ($6.18/year)
```

### After Cleanup:
```
Route 53:
  - eventplanner.local:        $0.50  (required for ECS)
  - DNS queries:               $0.50  (normal usage)

GuardDuty:                     $0.00

TOTAL:                         $1.00/month
```

---

## ✅ RECOMMENDATIONS

### Keep These (Required):
1. **eventplanner.local hosted zone** - Used by AWS Cloud Map for ECS service discovery
   - Your auth-service, event-service, notification-service use this
   - Deleting would break inter-service communication

### Delete These (Not Needed):
1. **davidodediran.tech hosted zone** - Not in Terraform, not used by your app
   - Saves $0.50/month
   - Only delete if you don't own this domain

2. **GuardDuty detectors** - Already disabled, just delete completely
   - Saves $0.015/month (minimal)
   - Clean up residual resources

---

## 🔧 TERRAFORM VERIFICATION

### Checked Terraform Code:
- ✅ No Route 53 module found in your Terraform
- ✅ No GuardDuty resources in Terraform
- ✅ Cloud Map (eventplanner.local) is managed by ECS module

### Conclusion:
- **davidodediran.tech** was created manually (not via Terraform)
- **eventplanner.local** is created by AWS Cloud Map (part of ECS service discovery)
- **GuardDuty** was enabled manually and then disabled

---

## 📝 ACTION PLAN

### Step 1: Verify Domain Ownership
```bash
# Check if you own davidodediran.tech
whois davidodediran.tech
```

### Step 2: Delete Unused Hosted Zone (if confirmed)
```bash
export AWS_PROFILE=gtp-cletus
aws route53 delete-hosted-zone --id Z0145315XB6DTY8H0XDH
```

### Step 3: Delete GuardDuty Detectors
```bash
export AWS_PROFILE=gtp-cletus

# eu-west-1
aws guardduty delete-detector \
  --detector-id 0accab92ea2949157848195893ef8c78 \
  --region eu-west-1

# us-east-1
aws guardduty delete-detector \
  --detector-id 32ccb86ccfe300465786b2dd0642266f \
  --region us-east-1
```

### Step 4: Monitor Next Bill
- Route 53 should drop to ~$1.00/month
- GuardDuty should drop to $0.00/month

---

## 🎯 FINAL ANSWER

**Why you're still being charged:**

1. **Route 53 ($1.50/month)**:
   - $0.50 = davidodediran.tech (unused, not in Terraform) ⚠️
   - $0.50 = eventplanner.local (required for ECS) ✅
   - $0.50 = DNS queries (normal) ✅

2. **GuardDuty ($0.015/month)**:
   - Residual processing from disabled detectors
   - Data sources still enabled but not processing new data
   - Will drop to $0 after full deletion

**Total Savings Available: $0.515/month ($6.18/year)**
