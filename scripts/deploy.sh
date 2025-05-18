#!/bin/bash
# scripts/deploy.sh
# Deployment script for VPN Server Cluster

set -e

# Default values
ENVIRONMENT="dev"
ACTION="apply"
VERBOSE=false
UPDATE_INVENTORY=true
CONFIGURE_SERVERS=true
HA_MODE=true

# Help function
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -e, --environment ENV   Environment to deploy (dev, staging, prod) [default: dev]"
  echo "  -a, --action ACTION     Terraform action (plan, apply, destroy) [default: apply]"
  echo "  -v, --verbose           Enable verbose output"
  echo "  --skip-inventory        Skip updating Ansible inventory"
  echo "  --skip-configure        Skip server configuration with Ansible"
  echo "  --no-ha                 Disable high availability mode"
  echo "  -h, --help              Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -e|--environment)
      ENVIRONMENT="$2"
      shift
      shift
      ;;
    -a|--action)
      ACTION="$2"
      shift
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    --skip-inventory)
      UPDATE_INVENTORY=false
      shift
      ;;
    --skip-configure)
      CONFIGURE_SERVERS=false
      shift
      ;;
    --no-ha)
      HA_MODE=false
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
ANSIBLE_INVENTORY_DIR="$PROJECT_ROOT/ansible/inventory/$ENVIRONMENT"

# Enable verbose mode if requested
if [ "$VERBOSE" = true ]; then
  set -x
fi

echo "======================================================"
echo "Deploying VPN Server Cluster for environment: $ENVIRONMENT"
echo "======================================================"

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "Error: Terraform directory for environment '$ENVIRONMENT' does not exist."
  exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
  echo "Warning: terraform.tfvars file not found in $TERRAFORM_DIR"
  echo "Creating from example file..."
  
  if [ -f "$TERRAFORM_DIR/terraform.tfvars.example" ]; then
    cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TERRAFORM_DIR/terraform.tfvars"
    echo "Created terraform.tfvars from example file. Please edit it with your values."
    echo "Press Enter to continue or Ctrl+C to abort..."
    read
  else
    echo "Error: terraform.tfvars.example file not found."
    exit 1
  fi
fi

# Execute Terraform
cd "$TERRAFORM_DIR"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Set ha_mode variable for Terraform
if [ "$HA_MODE" = true ]; then
  HA_VAR="-var=enable_shared_storage=true"
  
  # Update desired capacity if in HA mode
  if ! grep -q "asg_desired_capacity" terraform.tfvars; then
    echo "asg_desired_capacity = 2" >> terraform.tfvars
    echo "Added asg_desired_capacity = 2 to terraform.tfvars"
  fi
else
  HA_VAR="-var=enable_shared_storage=false"
  
  # Update desired capacity if not in HA mode
  if ! grep -q "asg_desired_capacity" terraform.tfvars; then
    echo "asg_desired_capacity = 1" >> terraform.tfvars
    echo "Added asg_desired_capacity = 1 to terraform.tfvars"
  fi
fi

# Execute the requested Terraform action
case "$ACTION" in
  plan)
    echo "Planning Terraform deployment..."
    terraform plan $HA_VAR
    ;;
  apply)
    echo "Applying Terraform changes..."
    terraform apply $HA_VAR -auto-approve
    ;;
  destroy)
    echo "Destroying Terraform resources..."
    terraform destroy $HA_VAR -auto-approve
    ;;
  *)
    echo "Error: Unknown action '$ACTION'. Use 'plan', 'apply' or 'destroy'."
    exit 1
    ;;
esac

# Stop if action was destroy or plan
if [ "$ACTION" = "destroy" ] || [ "$ACTION" = "plan" ]; then
  echo "Deployment script completed."
  exit 0
fi

# Update Ansible inventory
if [ "$UPDATE_INVENTORY" = true ]; then
  echo "Updating Ansible inventory..."
  
  # Create inventory directory if it doesn't exist
  mkdir -p "$ANSIBLE_INVENTORY_DIR"
  
  # Get NLB DNS name
  NLB_DNS=$(terraform output -raw nlb_dns_name 2>/dev/null)
  
  # Get VPN endpoint (NLB DNS name with port)
  VPN_ENDPOINT=$(terraform output -raw vpn_endpoint 2>/dev/null)
  
  # Create hosts.yml file
  cat > "$ANSIBLE_INVENTORY_DIR/hosts.yml" << EOF
---
all:
  children:
    vpn_servers:
      hosts:
EOF

  # In HA mode, we need to get IPs of all instances in the Auto Scaling Group
  if [ "$HA_MODE" = true ]; then
    echo "Retrieving Auto Scaling Group instance IPs..."
    
    # Get ASG details using AWS CLI directly
    # Get a list of all ASGs
    ASG_LIST=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(Tags[?Key=='Project'].Value, 'vpn-cluster')].AutoScalingGroupName" --output text 2>/dev/null)
    
    if [ -n "$ASG_LIST" ]; then
      # Find the most recent ASG for our project
      for ASG_NAME in $ASG_LIST; do
        echo "Found ASG: $ASG_NAME"
        
        # Get instance IDs from ASG
        INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG_NAME" --query "AutoScalingGroups[0].Instances[*].InstanceId" --output text)
        
        if [ -n "$INSTANCE_IDS" ]; then
          echo "Found instances in ASG: $ASG_NAME"
          break
        fi
      done
      
      # Loop through instance IDs and get their public IPs
      COUNTER=1
      for INSTANCE_ID in $INSTANCE_IDS; do
        PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
        
        if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
          cat >> "$ANSIBLE_INVENTORY_DIR/hosts.yml" << EOF
        vpn-server-$COUNTER:
          ansible_host: $PUBLIC_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: "~/.ssh/vpn-cluster-key.pem"
EOF
          COUNTER=$((COUNTER+1))
        fi
      done
    else
      echo "Warning: Could not find any ASGs, using legacy instance method..."
      
      # Fallback to legacy method
      VPN_PUBLIC_IP=$(terraform output -raw vpn_server_public_ip 2>/dev/null || echo "")
      
      if [ -n "$VPN_PUBLIC_IP" ]; then
        cat >> "$ANSIBLE_INVENTORY_DIR/hosts.yml" << EOF
        vpn-server-1:
          ansible_host: $VPN_PUBLIC_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: "~/.ssh/vpn-cluster-key.pem"
EOF
      fi
    fi
  else
    # Legacy method for non-HA mode
    VPN_PUBLIC_IP=$(terraform output -raw vpn_server_public_ip 2>/dev/null || echo "")
    
    if [ -n "$VPN_PUBLIC_IP" ]; then
      cat >> "$ANSIBLE_INVENTORY_DIR/hosts.yml" << EOF
        vpn-server-1:
          ansible_host: $VPN_PUBLIC_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: "~/.ssh/vpn-cluster-key.pem"
EOF
    fi
  fi
  
  # Add NLB DNS name as a variable if available
  if [ -n "$NLB_DNS" ]; then
    cat >> "$ANSIBLE_INVENTORY_DIR/hosts.yml" << EOF
  vars:
    ansible_python_interpreter: /usr/bin/python3
    nlb_endpoint: "$NLB_DNS"
EOF
  else
    cat >> "$ANSIBLE_INVENTORY_DIR/hosts.yml" << EOF
  vars:
    ansible_python_interpreter: /usr/bin/python3
EOF
  fi
  
  echo "Ansible inventory updated at: $ANSIBLE_INVENTORY_DIR/hosts.yml"
fi

# Configure VPN servers with Ansible
if [ "$CONFIGURE_SERVERS" = true ]; then
  echo "Configuring VPN servers with Ansible..."
  
  # Wait for instances to be ready
  echo "Waiting for instances to be ready..."
  sleep 30
  
  # Run Ansible playbook
  if [ "$HA_MODE" = true ]; then
    echo "Running WireGuard setup in HA mode..."
    ansible-playbook -i "$ANSIBLE_INVENTORY_DIR" "$PROJECT_ROOT/ansible/playbooks/setup-wireguard-ha.yml"
  else
    echo "Running WireGuard setup in standard mode..."
    ansible-playbook -i "$ANSIBLE_INVENTORY_DIR" "$PROJECT_ROOT/ansible/playbooks/setup-wireguard.yml"
  fi
fi

echo "========================================"
echo "Deployment completed successfully!"
echo "========================================"

if [ -n "$VPN_ENDPOINT" ]; then
  echo "VPN Endpoint: $VPN_ENDPOINT"
  echo "Use this endpoint in your WireGuard client configuration."
fi

echo "To generate client configurations, connect to one of the VPN servers and run:"
echo "sudo /usr/local/bin/gen-client-config.sh <client_name> <client_ip>"
echo "Example: sudo /usr/local/bin/gen-client-config.sh my-laptop 10.8.0.10/24"