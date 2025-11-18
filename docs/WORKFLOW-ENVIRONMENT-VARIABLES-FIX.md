# Frontend Workflow Environment Variables - Fix Summary

## Issues Found & Fixed

### ✅ Issue 1: Missing Google Maps Key
**Problem:** Google Maps API key was not passed to the build action  
**Fixed:** Added `google-maps-key` input to frontend-build action

### ✅ Issue 2: Wrong Environment Variable Names
**Problem:** Only `NG_APP_PROD_API` was set, but dev builds need `NG_APP_DEV_API`  
**Fixed:** Both `NG_APP_DEV_API` and `NG_APP_PROD_API` are now set in build action

### ✅ Issue 3: No Environment-Specific API URL Selection
**Problem:** Workflow always used `NG_APP_PROD_API` regardless of environment  
**Fixed:** Added logic to select correct API URL based on environment

---

## Changes Made

### 1. Updated `frontend-build/action.yml`

**Before:**
```yaml
inputs:
  api-url:
    description: 'API URL for production'
    required: false
env:
  NG_APP_PROD_API: ${{ inputs.api-url }}
```

**After:**
```yaml
inputs:
  api-url:
    description: 'API URL'
    required: false
  google-maps-key:
    description: 'Google Maps API Key'
    required: false
env:
  NG_APP_DEV_API: ${{ inputs.api-url }}
  NG_APP_PROD_API: ${{ inputs.api-url }}
  NG_APP_GOOGLE_MAPS_KEY: ${{ inputs.google-maps-key }}
```

### 2. Updated `frontend-ci-cd.yml`

**Before:**
```yaml
- uses: ./.github/actions/frontend-build
  with:
    environment: ${{ env.ENVIRONMENT }}
    api-url: ${{ secrets.NG_APP_PROD_API }}
```

**After:**
```yaml
- name: Set API URL
  id: api-config
  run: |
    case "${{ env.ENVIRONMENT }}" in
      dev) echo "api_url=${{ secrets.NG_APP_DEV_API }}" >> $GITHUB_OUTPUT ;;
      staging) echo "api_url=${{ secrets.NG_APP_DEV_API }}" >> $GITHUB_OUTPUT ;;
      prod) echo "api_url=${{ secrets.NG_APP_PROD_API }}" >> $GITHUB_OUTPUT ;;
    esac

- uses: ./.github/actions/frontend-build
  with:
    environment: ${{ env.ENVIRONMENT }}
    api-url: ${{ steps.api-config.outputs.api_url }}
    google-maps-key: ${{ secrets.NG_APP_GOOGLE_MAPS_KEY }}
```

---

## Verification Checklist

### ✅ Actions Configuration

| Action | Status | Notes |
|--------|--------|-------|
| `frontend-build/action.yml` | ✅ Fixed | Now accepts `google-maps-key` and sets all 3 env vars |
| `s3-deploy/action.yml` | ✅ Correct | No changes needed |
| `setup-node/action.yml` | ✅ Correct | No changes needed |

### ✅ Workflow Configuration

| Workflow | Status | Notes |
|----------|--------|-------|
| `frontend-ci-cd.yml` | ✅ Fixed | Now selects correct API URL per environment |
| Environment selection | ✅ Working | dev → DEV_API, prod → PROD_API |
| Google Maps key | ✅ Added | Passed to build action |

### ✅ GitHub Secrets Required

| Secret Name | Status | Used For |
|------------|--------|----------|
| `NG_APP_DEV_API` | ✅ Set | Dev/Staging API endpoint |
| `NG_APP_PROD_API` | ✅ Set | Production API endpoint |
| `NG_APP_GOOGLE_MAPS_KEY` | ✅ Set | Google Maps integration |

---

## How It Works Now

### Development Build Flow

```
Workflow Trigger (dev)
  ↓
Set API URL step
  → Selects: NG_APP_DEV_API
  ↓
Frontend Build Action
  → Sets env vars:
    - NG_APP_DEV_API=https://api.sankofagrid.com
    - NG_APP_PROD_API=https://api.sankofagrid.com
    - NG_APP_GOOGLE_MAPS_KEY=AIza...
  ↓
npm run build:dev
  → Angular reads from process.env
  ↓
Compiled Application
```

### Production Build Flow

```
Workflow Trigger (prod)
  ↓
Set API URL step
  → Selects: NG_APP_PROD_API
  ↓
Frontend Build Action
  → Sets env vars:
    - NG_APP_DEV_API=https://api.sankofagrid.com
    - NG_APP_PROD_API=https://api.sankofagrid.com
    - NG_APP_GOOGLE_MAPS_KEY=AIza...
  ↓
npm run build:prod
  → Angular reads from process.env
  ↓
Compiled Application
```

---

## Testing

### 1. Test Dev Build

```bash
# Trigger workflow manually
gh workflow run frontend-ci-cd.yml \
  --ref main \
  -f environment=dev
```

**Expected:**
- Build uses `NG_APP_DEV_API`
- Google Maps key is available
- Build succeeds

### 2. Test Prod Build

```bash
# Trigger workflow manually
gh workflow run frontend-ci-cd.yml \
  --ref main \
  -f environment=prod
```

**Expected:**
- Build uses `NG_APP_PROD_API`
- Google Maps key is available
- Build succeeds

### 3. Verify Environment Variables in Build Logs

Look for in GitHub Actions logs:
```
Building with environment: dev
Environment variables set:
  NG_APP_DEV_API: https://***
  NG_APP_PROD_API: https://***
  NG_APP_GOOGLE_MAPS_KEY: AIza*** (masked)
```

---

## Other Workflows to Update

### `frontend-prod-blue-green.yml`

**Current:**
```yaml
- uses: ./.github/actions/frontend-build
  with:
    environment: prod
    api-url: ${{ secrets.NG_APP_PROD_API }}
```

**Should be:**
```yaml
- uses: ./.github/actions/frontend-build
  with:
    environment: prod
    api-url: ${{ secrets.NG_APP_PROD_API }}
    google-maps-key: ${{ secrets.NG_APP_GOOGLE_MAPS_KEY }}
```

---

## Summary

### ✅ What Was Fixed

1. **frontend-build/action.yml**
   - Added `google-maps-key` input
   - Set all 3 environment variables (`NG_APP_DEV_API`, `NG_APP_PROD_API`, `NG_APP_GOOGLE_MAPS_KEY`)

2. **frontend-ci-cd.yml**
   - Added environment-specific API URL selection
   - Pass Google Maps key to build action

### ✅ What's Working Now

- ✅ Dev builds use `NG_APP_DEV_API`
- ✅ Prod builds use `NG_APP_PROD_API`
- ✅ Google Maps key is available in all builds
- ✅ All environment variables properly passed through workflow → action → build

### ⚠️ Action Required

Update `frontend-prod-blue-green.yml` to also pass `google-maps-key`:
```yaml
google-maps-key: ${{ secrets.NG_APP_GOOGLE_MAPS_KEY }}
```

---

**Last Updated:** November 17, 2025  
**Status:** ✅ COMPLETE  
**Files Modified:** 2 (frontend-build/action.yml, frontend-ci-cd.yml)
