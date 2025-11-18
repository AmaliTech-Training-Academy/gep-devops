# Frontend Environment Variables Configuration Guide

## Overview

Angular environment variables for the Event Planner frontend are configured in **GitHub Actions Secrets** in the `get-devops` repository, not in the frontend repository itself.

---

## Required Environment Variables

```bash
NG_APP_DEV_API=https://api.sankofagrid.com
NG_APP_PROD_API=https://api.sankofagrid.com
NG_APP_GOOGLE_MAPS_KEY=your-google-maps-api-key-here
```

---

## Where to Set Them

### Option 1: GitHub Repository Secrets (Recommended) ✅

**Location:** `get-devops` repository → Settings → Secrets and variables → Actions

**Steps:**
1. Go to: https://github.com/YOUR_ORG/get-devops/settings/secrets/actions
2. Click "New repository secret"
3. Add each secret:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `NG_APP_DEV_API` | `https://api.sankofagrid.com` | Development API endpoint |
| `NG_APP_PROD_API` | `https://api.sankofagrid.com` | Production API endpoint |
| `NG_APP_GOOGLE_MAPS_KEY` | `AIza...` | Google Maps API key |

---

## How They're Used

### 1. In GitHub Actions Workflows

**Development Workflow:**
```yaml
# .github/workflows/frontend-dev-deploy.yml
- uses: ./.github/actions/frontend-build
  with:
    environment: dev
    api-url: ${{ secrets.NG_APP_DEV_API }}
```

**Production Workflow:**
```yaml
# .github/workflows/frontend-prod-blue-green.yml
- uses: ./.github/actions/frontend-build
  with:
    environment: prod
    api-url: ${{ secrets.NG_APP_PROD_API }}
```

### 2. In Build Action

**File:** `.github/actions/frontend-build/action.yml`

```yaml
- name: Build
  shell: bash
  working-directory: frontend
  run: |
    npm run build:${{ inputs.environment }}
  env:
    NG_APP_PROD_API: ${{ inputs.api-url }}
    NG_APP_GOOGLE_MAPS_KEY: ${{ inputs.google-maps-key }}
```

### 3. In Frontend Code

**File:** `frontend/src/environments/environment.ts`

```typescript
export const environment = {
  production: false,
  apiUrl: process.env['NG_APP_DEV_API'] || 'http://localhost:8080',
  googleMapsKey: process.env['NG_APP_GOOGLE_MAPS_KEY'] || ''
};
```

**File:** `frontend/src/environments/environment.prod.ts`

```typescript
export const environment = {
  production: true,
  apiUrl: process.env['NG_APP_PROD_API'] || 'https://api.sankofagrid.com',
  googleMapsKey: process.env['NG_APP_GOOGLE_MAPS_KEY'] || ''
};
```

---

## Current Configuration Status

### ✅ Already Configured

The workflows already reference these secrets:

**Production Workflow:**
```yaml
# Line 67 in frontend-prod-blue-green.yml
- uses: ./.github/actions/frontend-build
  with:
    environment: prod
    api-url: ${{ secrets.NG_APP_PROD_API }}
```

**Build Action:**
```yaml
# frontend-build/action.yml
env:
  NG_APP_PROD_API: ${{ inputs.api-url }}
```

### ⚠️ Needs to be Added

You need to **add the actual secret values** in GitHub:

1. `NG_APP_DEV_API` → Not yet added
2. `NG_APP_PROD_API` → Referenced but value not set
3. `NG_APP_GOOGLE_MAPS_KEY` → Not yet added

---

## How to Add Secrets

### Via GitHub Web Interface

1. Navigate to: https://github.com/YOUR_ORG/get-devops
2. Click: **Settings** → **Secrets and variables** → **Actions**
3. Click: **New repository secret**
4. Enter:
   - **Name:** `NG_APP_DEV_API`
   - **Secret:** `https://api.sankofagrid.com`
5. Click: **Add secret**
6. Repeat for other secrets

### Via GitHub CLI

```bash
# Install GitHub CLI if not already installed
# brew install gh

# Authenticate
gh auth login

# Add secrets
gh secret set NG_APP_DEV_API --body "https://api.sankofagrid.com" --repo YOUR_ORG/get-devops
gh secret set NG_APP_PROD_API --body "https://api.sankofagrid.com" --repo YOUR_ORG/get-devops
gh secret set NG_APP_GOOGLE_MAPS_KEY --body "YOUR_GOOGLE_MAPS_KEY" --repo YOUR_ORG/get-devops
```

---

## Updating the Build Action

To ensure Google Maps key is passed, update the build action:

**File:** `.github/actions/frontend-build/action.yml`

```yaml
name: 'Frontend Build'
description: 'Build frontend application'
inputs:
  environment:
    description: 'Environment to build for'
    required: true
  api-url:
    description: 'API URL'
    required: false
  google-maps-key:
    description: 'Google Maps API Key'
    required: false
runs:
  using: 'composite'
  steps:
    - name: Build
      shell: bash
      working-directory: frontend
      run: |
        npm run build:${{ inputs.environment }}
      env:
        NG_APP_DEV_API: ${{ inputs.api-url }}
        NG_APP_PROD_API: ${{ inputs.api-url }}
        NG_APP_GOOGLE_MAPS_KEY: ${{ inputs.google-maps-key }}
```

---

## Updating Workflows

### Development Workflow

```yaml
- uses: ./.github/actions/frontend-build
  with:
    environment: dev
    api-url: ${{ secrets.NG_APP_DEV_API }}
    google-maps-key: ${{ secrets.NG_APP_GOOGLE_MAPS_KEY }}
```

### Production Workflow

```yaml
- uses: ./.github/actions/frontend-build
  with:
    environment: prod
    api-url: ${{ secrets.NG_APP_PROD_API }}
    google-maps-key: ${{ secrets.NG_APP_GOOGLE_MAPS_KEY }}
```

---

## Verification

### 1. Check Secrets are Set

```bash
# List secrets (won't show values)
gh secret list --repo YOUR_ORG/get-devops
```

Expected output:
```
NG_APP_DEV_API          Updated 2025-11-17
NG_APP_PROD_API         Updated 2025-11-17
NG_APP_GOOGLE_MAPS_KEY  Updated 2025-11-17
```

### 2. Test Build Locally

```bash
# In frontend repository
export NG_APP_DEV_API="https://api.sankofagrid.com"
export NG_APP_GOOGLE_MAPS_KEY="your-key"
npm run build:dev
```

### 3. Check Build Output

After GitHub Actions runs, check the build logs:
```
Building with environment: dev
API URL: https://api.sankofagrid.com
Google Maps Key: AIza****** (masked)
```

---

## Security Best Practices

### ✅ DO:
- Store all sensitive values in GitHub Secrets
- Use different API keys for dev/prod
- Rotate Google Maps API key regularly
- Restrict Google Maps API key to specific domains

### ❌ DON'T:
- Commit API keys to git
- Share secrets in plain text
- Use production keys in development
- Expose secrets in build logs

---

## Google Maps API Key Setup

### 1. Get API Key

1. Go to: https://console.cloud.google.com/
2. Create project: "Event Planner"
3. Enable: **Maps JavaScript API**
4. Create credentials: **API Key**

### 2. Restrict API Key

**Application restrictions:**
- HTTP referrers (websites)
- Add: `https://events.sankofagrid.com/*`
- Add: `https://*.sankofagrid.com/*`

**API restrictions:**
- Restrict key
- Select: Maps JavaScript API

### 3. Add to GitHub Secrets

```bash
gh secret set NG_APP_GOOGLE_MAPS_KEY \
  --body "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
  --repo YOUR_ORG/get-devops
```

---

## Troubleshooting

### Issue: Environment variables not available in Angular

**Solution:** Ensure `process.env` is properly configured in Angular

**File:** `frontend/angular.json`

```json
{
  "projects": {
    "event-planner": {
      "architect": {
        "build": {
          "configurations": {
            "production": {
              "fileReplacements": [
                {
                  "replace": "src/environments/environment.ts",
                  "with": "src/environments/environment.prod.ts"
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

### Issue: API URL not working

**Check:**
1. Secret is set in GitHub
2. Workflow passes secret to build action
3. Build action sets environment variable
4. Frontend code reads from `process.env`

### Issue: Google Maps not loading

**Check:**
1. API key is valid
2. Maps JavaScript API is enabled
3. Domain is whitelisted
4. Billing is enabled in Google Cloud

---

## Summary

**Where to set:**
- ✅ GitHub Secrets in `get-devops` repository

**What to set:**
```
NG_APP_DEV_API=https://api.sankofagrid.com
NG_APP_PROD_API=https://api.sankofagrid.com
NG_APP_GOOGLE_MAPS_KEY=AIza...
```

**How they flow:**
```
GitHub Secrets 
  → Workflow (frontend-deploy.yml)
    → Build Action (frontend-build/action.yml)
      → Environment Variables
        → Angular Build Process
          → Compiled Application
```

---

**Last Updated:** November 17, 2025  
**Status:** Configuration guide complete  
**Action Required:** Add secret values in GitHub
