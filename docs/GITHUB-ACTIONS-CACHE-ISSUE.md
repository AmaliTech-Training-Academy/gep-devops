# GitHub Actions Not Picking Up Changes - Troubleshooting

## Issue
The `setup-node` action was updated with `--legacy-peer-deps` flag, but the workflow is still running the old code.

## Root Cause
GitHub Actions loads composite actions from the **workflow's branch**, not from the checked-out code. If the workflow is triggered from a branch that doesn't have the updated action, it will use the old version.

## Current Situation

### ✅ Changes Made (Committed to `dev` branch)
```yaml
# .github/actions/setup-node/action.yml
- name: Clean npm cache
  run: |
    rm -rf node_modules package-lock.json
    npm cache clean --force

- name: Install Dependencies
  run: npm install --legacy-peer-deps
```

### ❌ Workflow Still Running Old Code
Error log shows:
```
Run if [ -f "package-lock.json" ]; then
  npm ci
else
  npm install
fi
```

This is the OLD code without `--legacy-peer-deps`.

## Why This Happens

GitHub Actions workflow execution:
1. Workflow is triggered from branch X
2. Actions are loaded from branch X (at workflow start)
3. Code is checked out from branch Y (via checkout-frontend action)
4. **Actions remain from branch X** (not updated from branch Y)

## Solutions

### Solution 1: Merge to Main Branch (Recommended)
```bash
# Merge dev to main
git checkout main
git merge dev
git push origin main
```

Then trigger the workflow from `main` branch.

### Solution 2: Trigger Workflow from Dev Branch
If the workflow supports `workflow_dispatch`, trigger it manually from the `dev` branch:
```bash
gh workflow run frontend-ci-cd.yml --ref dev -f environment=dev
```

### Solution 3: Update on All Branches
```bash
# Cherry-pick the fix to main
git checkout main
git cherry-pick 6ad9ea5
git push origin main
```

### Solution 4: Force Workflow to Use Specific Branch
Update the workflow to explicitly use actions from a specific branch:

```yaml
# Instead of:
- uses: ./.github/actions/setup-node

# Use:
- uses: ./.github/actions/setup-node@dev
```

## Verification Steps

### 1. Check Which Branch Workflow Runs From
Look at the GitHub Actions UI:
- Go to Actions tab
- Click on the failed run
- Check "This workflow ran on branch: ???"

### 2. Verify Action Content on That Branch
```bash
# Check action content on main branch
git show main:.github/actions/setup-node/action.yml | grep "legacy-peer-deps"

# Check action content on dev branch
git show dev:.github/actions/setup-node/action.yml | grep "legacy-peer-deps"
```

### 3. Confirm Commit is on Workflow Branch
```bash
# Check if commit 6ad9ea5 is on main
git branch --contains 6ad9ea5
```

## Quick Fix

**Option A: Merge to Main**
```bash
cd /home/cletusmangu/Desktop/event-planner-project/get-devops
git checkout main
git merge dev
git push origin main
```

**Option B: Update Main Directly**
```bash
cd /home/cletusmangu/Desktop/event-planner-project/get-devops
git checkout main
git checkout dev -- .github/actions/setup-node/action.yml
git commit -m "fix: add --legacy-peer-deps to npm install"
git push origin main
```

## Expected Result

After merging to main and re-running the workflow, you should see:
```
Run rm -rf node_modules package-lock.json
npm cache clean --force

Run npm install --legacy-peer-deps
```

Instead of:
```
Run if [ -f "package-lock.json" ]; then
  npm ci
```

---

**Status:** Changes committed to `dev` branch (commit `6ad9ea5`)  
**Action Required:** Merge to `main` or trigger workflow from `dev` branch  
**Last Updated:** November 18, 2025
