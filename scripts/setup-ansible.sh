#!/bin/bash
set -e

echo "Setting up Ansible for Event Planner Configuration Management"

# Install Ansible and dependencies
echo "Installing Ansible..."
pip install ansible boto3 botocore

# Install required collections
echo "Installing Ansible collections..."
cd ansible
ansible-galaxy collection install -r requirements.yml

# Verify installation
echo "Verifying Ansible installation..."
ansible --version

# Test AWS connectivity
echo "Testing AWS connectivity..."
aws sts get-caller-identity

# Test inventory
echo "Testing dynamic inventory..."
ansible-inventory -i inventories/dev/hosts.yml --list

echo "✅ Ansible setup complete!"
echo ""
echo "Next steps:"
echo "1. Run: ansible-playbook -i inventories/dev playbooks/deploy-services.yml"
echo "2. Run: ansible-playbook -i inventories/dev playbooks/configure-monitoring.yml"
