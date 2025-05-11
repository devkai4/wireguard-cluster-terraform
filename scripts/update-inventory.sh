#!/bin/bash
# Script to update Ansible inventory from Terraform outputs

set -e

ENVIRONMENT=${1:-dev}
TERRAFORM_DIR="terraform/environments/${ENVIRONMENT}"
INVENTORY_FILE="ansible/inventory/${ENVIRONMENT}/hosts.yml"

echo "Updating Ansible inventory for environment: ${ENVIRONMENT}"

# Get VPN server IP from Terraform output
cd "$(dirname "$0")/.."
VPN_PUBLIC_IP=$(cd $TERRAFORM_DIR && terraform output -raw vpn_server_public_ip)

# Update inventory file
mkdir -p "ansible/inventory/${ENVIRONMENT}"

cat > "${INVENTORY_FILE}" << EOF
---
all:
  children:
    vpn_servers:
      hosts:
        vpn-server-1:
          ansible_host: ${VPN_PUBLIC_IP}
          ansible_user: ubuntu
          ansible_ssh_private_key_file: "~/.ssh/vpn-cluster-key.pem"
  vars:
    ansible_python_interpreter: /usr/bin/python3
EOF

echo "Updated inventory file at: ${INVENTORY_FILE}"
echo "VPN Server IP: ${VPN_PUBLIC_IP}"