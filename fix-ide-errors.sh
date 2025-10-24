#!/bin/bash
# ==============================================================================
# Fix IDE Terraform Errors
# ==============================================================================
# This script fixes IDE caching issues with Terraform modules
# ==============================================================================

echo "🔧 Fixing IDE Terraform errors..."
echo ""

cd terraform/environments/dev

echo "1. Cleaning Terraform cache..."
rm -rf .terraform
rm -f .terraform.lock.hcl

echo "2. Reinitializing Terraform..."
terraform init -upgrade

echo "3. Validating configuration..."
terraform validate

echo ""
echo "✅ Done!"
echo ""
echo "If you're using VS Code:"
echo "1. Press Ctrl+Shift+P (Cmd+Shift+P on Mac)"
echo "2. Type 'Reload Window'"
echo "3. Press Enter"
echo ""
echo "Or simply restart your IDE."
