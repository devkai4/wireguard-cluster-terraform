#!/bin/bash
# Script to update Ansible inventory from Terraform outputs and ASG instances

set -e

ENVIRONMENT=${1:-dev}
SSH_KEY=${2:-"~/.ssh/vpn-cluster-new-key.pem"}
TERRAFORM_DIR="terraform/environments/${ENVIRONMENT}"
INVENTORY_FILE="ansible/inventory/${ENVIRONMENT}/hosts.yml"

echo "Updating Ansible inventory for environment: ${ENVIRONMENT}"

# Move to project root directory
cd "$(dirname "$0")/.."

# Get outputs from Terraform
echo "Getting Terraform outputs..."
if [ -d "$TERRAFORM_DIR" ]; then
  cd $TERRAFORM_DIR
  
  # First try to get ASG name (for HA setup)
  ASG_NAME=$(terraform output -raw asg_name 2>/dev/null || echo "")
  NLB_DNS=$(terraform output -raw nlb_dns_name 2>/dev/null || echo "")
  
  # Fallback to legacy single instance output if ASG doesn't exist
  if [ -z "$ASG_NAME" ]; then
    echo "No ASG found, trying to get single instance IP..."
    VPN_PUBLIC_IP=$(terraform output -raw vpn_server_public_ip 2>/dev/null || echo "")
  fi
  
  cd - > /dev/null
else
  echo "Terraform directory not found: $TERRAFORM_DIR"
  exit 1
fi

# Create inventory directory if it doesn't exist
mkdir -p "ansible/inventory/${ENVIRONMENT}"

# Start creating hosts.yml file
cat > "${INVENTORY_FILE}" << EOF
---
all:
  children:
    vpn_servers:
      hosts:
EOF

# If we have an ASG name, get all instances in it
if [ -n "$ASG_NAME" ]; then
  echo "Found Auto Scaling Group: $ASG_NAME"
  echo "Getting instances from ASG..."
  
  # Get instance IDs from ASG (only InService instances)
  INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" \
    --output text)
  
  if [ -z "$INSTANCE_IDS" ]; then
    echo "No running instances found in ASG $ASG_NAME"
    exit 1
  fi
  
  # Get public IPs for each instance and add to inventory
  COUNTER=1
  for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Getting public IP for instance $INSTANCE_ID..."
    PUBLIC_IP=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[0].Instances[0].PublicIpAddress" \
      --output text)
    
    if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
      echo "  Instance $INSTANCE_ID: $PUBLIC_IP"
      
      cat >> "${INVENTORY_FILE}" << EOF
        vpn-server-$COUNTER:
          ansible_host: $PUBLIC_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: "${SSH_KEY}"
EOF
      COUNTER=$((COUNTER+1))
    else
      echo "  Warning: Instance $INSTANCE_ID has no public IP"
    fi
  done
  
  echo "Added $((COUNTER-1)) instances to inventory"
  
# Fall back to single instance if no ASG
elif [ -n "$VPN_PUBLIC_IP" ]; then
  echo "No ASG found, using single instance IP: $VPN_PUBLIC_IP"
  
  cat >> "${INVENTORY_FILE}" << EOF
        vpn-server-1:
          ansible_host: $VPN_PUBLIC_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: "${SSH_KEY}"
EOF

else
  echo "Error: Could not determine VPN server IP or instances"
  exit 1
fi

# Add variables section
cat >> "${INVENTORY_FILE}" << EOF
  vars:
    ansible_python_interpreter: /usr/bin/python3
EOF

# Add NLB DNS if available
if [ -n "$NLB_DNS" ]; then
  echo "Adding NLB DNS: $NLB_DNS"
  
  cat >> "${INVENTORY_FILE}" << EOF
    nlb_endpoint: "$NLB_DNS"
EOF
fi

echo "Updated inventory file at: ${INVENTORY_FILE}"

# Print summary
if [ -n "$ASG_NAME" ]; then
  echo "VPN Server ASG: $ASG_NAME"
  echo "NLB DNS: $NLB_DNS"
else
  echo "VPN Server IP: $VPN_PUBLIC_IP"
fi

# Print the inventory for verification
echo "============= Inventory Content ============="
cat "${INVENTORY_FILE}"
echo "============================================="