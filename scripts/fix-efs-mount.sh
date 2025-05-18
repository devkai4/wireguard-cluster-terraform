#!/bin/bash
# Script to diagnose and fix EFS mount issues
# ハイアベイラビリティVPNクラスタ用EFSマウント問題診断・修正スクリプト

set -e

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform/environments/dev"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Log function
log() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

log "EFS自動マウント問題診断・修正スクリプトを開始します..."

# Check if running with sudo
if [ "$EUID" -eq 0 ]; then
  warn "このスクリプトはsudoなしで実行することをお勧めします。AWSの認証情報がルートユーザーのものに置き換わる可能性があります。"
  read -p "続行しますか？ (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check requirements
log "必要なツールの確認..."
MISSING_TOOLS=()

if ! command -v aws >/dev/null 2>&1; then
  MISSING_TOOLS+=("aws")
fi

if ! command -v jq >/dev/null 2>&1; then
  MISSING_TOOLS+=("jq")
fi

if ! command -v terraform >/dev/null 2>&1; then
  MISSING_TOOLS+=("terraform")
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  MISSING_TOOLS+=("ansible")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  error "以下のツールがインストールされていません: ${MISSING_TOOLS[*]}"
  if [[ " ${MISSING_TOOLS[*]} " =~ " jq " ]]; then
    echo "jqをインストールするには: sudo apt-get install jq"
  fi
  exit 1
fi

# Check AWS credentials
log "AWS認証情報の確認..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  error "AWS認証情報が設定されていないか無効です。AWS CLIの設定を確認してください。"
  exit 1
fi

# Step 1: Check Terraform state and outputs
log "Terraformの状態とEFS設定を確認しています..."

# Check terraform state
if [ ! -d "${TERRAFORM_DIR}/.terraform" ]; then
  warn "Terraformが初期化されていません。初期化します..."
  (cd "$TERRAFORM_DIR" && terraform init)
fi

# Check if EFS is created
log "EFSの状態を確認しています..."
if ! (cd "$TERRAFORM_DIR" && terraform state list | grep -q "module.efs"); then
  warn "EFSモジュールがTerraform状態に見つかりません。enable_shared_storageがtrueに設定されているか確認します..."
  
  # Check enable_shared_storage variable
  if [ -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
    if grep -q "enable_shared_storage.*=.*false" "${TERRAFORM_DIR}/terraform.tfvars"; then
      warn "enable_shared_storageがfalseに設定されています。trueに変更します..."
      sed -i 's/enable_shared_storage.*=.*false/enable_shared_storage = true/g' "${TERRAFORM_DIR}/terraform.tfvars"
      
      log "Terraformを適用してEFSを作成します..."
      (cd "$TERRAFORM_DIR" && terraform apply -auto-approve)
    else
      log "terraform.tfvarsでenable_shared_storageの設定を確認します..."
      if ! grep -q "enable_shared_storage" "${TERRAFORM_DIR}/terraform.tfvars"; then
        log "enable_shared_storageが明示的に設定されていません。追加します..."
        echo "enable_shared_storage = true" >> "${TERRAFORM_DIR}/terraform.tfvars"
        
        log "Terraformを適用してEFSを作成します..."
        (cd "$TERRAFORM_DIR" && terraform apply -auto-approve)
      fi
    fi
  else
    warn "terraform.tfvarsファイルが見つかりません。サンプルファイルからコピーします..."
    if [ -f "${TERRAFORM_DIR}/terraform.tfvars.example" ]; then
      cp "${TERRAFORM_DIR}/terraform.tfvars.example" "${TERRAFORM_DIR}/terraform.tfvars"
      sed -i 's/enable_shared_storage.*=.*false/enable_shared_storage = true/g' "${TERRAFORM_DIR}/terraform.tfvars"
      
      log "Terraformを適用してEFSを作成します..."
      (cd "$TERRAFORM_DIR" && terraform apply -auto-approve)
    else
      error "terraform.tfvars.exampleファイルが見つかりません。手動でterraform.tfvarsを作成し、enable_shared_storage = trueを設定してください。"
      exit 1
    fi
  fi
fi

# Get EFS ID
log "EFS IDを取得しています..."
EFS_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw efs_id 2>/dev/null || echo "")

if [ -z "$EFS_ID" ]; then
  error "EFS IDが取得できませんでした。Terraform構成を確認してください。"
  exit 1
fi

log "EFS ID: ${EFS_ID}"

# Step 2: Check EC2 instance and security groups
log "EC2インスタンスとセキュリティグループを確認しています..."

# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=vpn-cluster" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
  error "実行中のEC2インスタンスが見つかりません。インスタンスが起動しているか確認してください。"
  exit 1
fi

log "EC2インスタンスID: ${INSTANCE_ID}"

# Get instance security groups
INSTANCE_SG_IDS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" --output text)
log "EC2セキュリティグループ: ${INSTANCE_SG_IDS}"

# Get EFS security groups
EFS_MOUNT_TARGETS=$(aws efs describe-mount-targets --file-system-id "$EFS_ID" --query "MountTargets[*]" --output json)
EFS_SG_IDS=$(echo "$EFS_MOUNT_TARGETS" | jq -r '.[0].SecurityGroups[]')

log "EFSセキュリティグループ: ${EFS_SG_IDS}"

# Check if EFS SG allows NFS from EC2 SG
log "セキュリティグループルールを確認しています..."
NEEDS_SG_UPDATE=false

for EFS_SG_ID in $EFS_SG_IDS; do
  # Check rules for port 2049
  SG_RULES=$(aws ec2 describe-security-group-rules --filter "Name=group-id,Values=${EFS_SG_ID}" --query "SecurityGroupRules[?IpProtocol=='tcp' && FromPort==2049 && ToPort==2049]" --output json)
  
  # Get VPC CIDR
  VPC_ID=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].VpcId" --output text)
  VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].CidrBlock" --output text)
  
  log "VPC ID: ${VPC_ID}, CIDR: ${VPC_CIDR}"
  
  # Check if VPC CIDR is allowed
  if ! echo "$SG_RULES" | jq -e ".[] | select(.CidrIpv4==\"$VPC_CIDR\")" > /dev/null; then
    warn "EFSセキュリティグループ ${EFS_SG_ID} はVPC CIDR ${VPC_CIDR} からのNFSトラフィックを許可していません"
    NEEDS_SG_UPDATE=true
    
    log "VPC CIDRからのNFSトラフィックを許可するルールを追加します..."
    aws ec2 authorize-security-group-ingress \
      --group-id "$EFS_SG_ID" \
      --protocol tcp \
      --port 2049 \
      --cidr "$VPC_CIDR" \
      --description "Allow NFS from VPC"
  else
    log "✓ EFSセキュリティグループはVPC CIDRからのNFSトラフィックを許可しています"
  fi
done

# Step 3: Check mount targets
log "EFSマウントターゲットを確認しています..."
MOUNT_TARGETS=$(echo "$EFS_MOUNT_TARGETS" | jq -r '.[] | {Id: .MountTargetId, State: .LifeCycleState, Subnet: .SubnetId, IP: .IpAddress}')
log "マウントターゲット情報: "
echo "$MOUNT_TARGETS" | jq -r '.'

# Get instance subnet
INSTANCE_SUBNET=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].SubnetId" --output text)
log "EC2インスタンスのサブネット: ${INSTANCE_SUBNET}"

# Check if there's a mount target in the instance subnet
if ! echo "$EFS_MOUNT_TARGETS" | jq -e ".[] | select(.SubnetId==\"$INSTANCE_SUBNET\")" > /dev/null; then
  warn "EC2インスタンスのサブネットにEFSマウントターゲットがありません"
  log "インスタンスのサブネットにマウントターゲットを作成します..."
  
  aws efs create-mount-target \
    --file-system-id "$EFS_ID" \
    --subnet-id "$INSTANCE_SUBNET" \
    --security-groups $EFS_SG_IDS
fi

# Step 4: Create and run fix-efs.sh on the instance
log "EFS修正スクリプトを作成しています..."

# Create temp fix-efs.sh
FIX_SCRIPT_PATH="/tmp/fix-efs-${EFS_ID}.sh"
cat > "$FIX_SCRIPT_PATH" << 'EOF'
#!/bin/bash

# EFS fixing script for wireguard-cluster
set -e

# Log file
LOG_FILE="/var/log/fix-efs.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== $(date): Starting EFS mount fixing script ==="

# Get EFS ID
EFS_ID="$1"
if [ -z "$EFS_ID" ]; then
  echo "Error: EFS ID not provided"
  exit 1
fi

echo "Using EFS ID: $EFS_ID"

# Install required packages
echo "Installing required packages..."
apt-get update
apt-get install -y nfs-common amazon-efs-utils

# Create mount point
MOUNT_POINT="/mnt/efs"
mkdir -p "$MOUNT_POINT"

# Get region
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\" -f4)
echo "Region: $REGION"

# Check if already mounted
if mount | grep -q "$MOUNT_POINT"; then
  echo "EFS is already mounted at $MOUNT_POINT"
else
  echo "Attempting to mount EFS..."

  # Try efs-utils mount
  echo "Trying mount with efs-utils..."
  mount -t efs -o tls "$EFS_ID":/ "$MOUNT_POINT"
  
  # Check if mount succeeded
  if ! mount | grep -q "$MOUNT_POINT"; then
    echo "efs-utils mount failed, trying NFS mount..."
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS_ID.efs.$REGION.amazonaws.com":/ "$MOUNT_POINT"
  fi
  
  # Final check
  if mount | grep -q "$MOUNT_POINT"; then
    echo "EFS mounted successfully"
  else
    echo "Failed to mount EFS. Checking network connectivity..."
    
    ping -c 2 "$EFS_ID.efs.$REGION.amazonaws.com" || echo "Cannot ping EFS endpoint"
    nc -zv "$EFS_ID.efs.$REGION.amazonaws.com" 2049 || echo "Cannot connect to NFS port 2049"
    
    # Try forcing NFS version 4.1
    echo "Trying to force NFSv4.1 mount..."
    mount -t nfs4 -o vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "$EFS_ID.efs.$REGION.amazonaws.com":/ "$MOUNT_POINT"
    
    if ! mount | grep -q "$MOUNT_POINT"; then
      echo "All mount attempts failed. Please check network and security group settings."
      exit 1
    fi
  fi
fi

# Setup WireGuard directories
echo "Setting up WireGuard directories on EFS..."
mkdir -p "$MOUNT_POINT/wireguard/clients"
chmod -R 700 "$MOUNT_POINT/wireguard"

# Configure WireGuard to use EFS
WIREGUARD_PATH="/etc/wireguard"
if [ -f "$WIREGUARD_PATH/wg0.conf" ] && [ ! -L "$WIREGUARD_PATH" ]; then
  echo "Found existing WireGuard configuration"
  
  # Check if EFS already has WireGuard config
  if [ ! -f "$MOUNT_POINT/wireguard/wg0.conf" ]; then
    echo "Copying WireGuard configuration to EFS..."
    cp -a "$WIREGUARD_PATH"/* "$MOUNT_POINT/wireguard/"
  else
    echo "EFS already has WireGuard configuration"
  fi
  
  # Stop WireGuard
  echo "Stopping WireGuard service..."
  systemctl stop wg-quick@wg0 || true
  
  # Backup original directory
  BACKUP_DIR="$WIREGUARD_PATH.bak.$(date +%s)"
  echo "Backing up $WIREGUARD_PATH to $BACKUP_DIR..."
  mv "$WIREGUARD_PATH" "$BACKUP_DIR"
  
  # Create symlink
  echo "Creating symlink to EFS..."
  ln -sf "$MOUNT_POINT/wireguard" "$WIREGUARD_PATH"
  
  # Start WireGuard
  echo "Starting WireGuard service..."
  systemctl start wg-quick@wg0 || true
fi

# Add to fstab
if ! grep -q "$EFS_ID" /etc/fstab; then
  echo "Adding EFS mount to fstab..."
  echo "$EFS_ID.efs.$REGION.amazonaws.com:/ $MOUNT_POINT nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
fi

# Create mount service
echo "Creating and enabling mount service..."
cat > /etc/systemd/system/efs-mount.service << EOT
[Unit]
Description=Mount EFS for WireGuard
After=network-online.target
Wants=network-online.target
Before=wg-quick@wg0.service

[Service]
Type=oneshot
ExecStart=/bin/mount $MOUNT_POINT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOT

# Enable service
systemctl daemon-reload
systemctl enable efs-mount.service

# Show WireGuard status
echo "WireGuard status:"
wg show || echo "WireGuard not running"

echo "=== $(date): EFS mount fixing completed ==="
EOF

chmod +x "$FIX_SCRIPT_PATH"

# Get instance public IP
INSTANCE_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" = "None" ]; then
  error "EC2インスタンスのパブリックIPが取得できませんでした"
  exit 1
fi

log "EC2インスタンスIP: ${INSTANCE_IP}"

# Get SSH key name
SSH_KEY_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].KeyName" --output text)
log "SSHキー名: ${SSH_KEY_NAME}"

# Ask for SSH key path
read -p "SSHキーパス (~/.ssh/${SSH_KEY_NAME}.pem または別のパス): " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/${SSH_KEY_NAME}.pem}

if [ ! -f "$SSH_KEY_PATH" ]; then
  error "SSHキーファイルが見つかりません: $SSH_KEY_PATH"
  exit 1
fi

# Copy script to instance
log "修正スクリプトをEC2インスタンスにコピーしています..."
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$FIX_SCRIPT_PATH" ubuntu@${INSTANCE_IP}:/tmp/fix-efs.sh

# Run script on instance
log "スクリプトを実行します..."
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@${INSTANCE_IP} "sudo bash /tmp/fix-efs.sh $EFS_ID"

# Check result
log "EFSマウント状態を確認しています..."
EFS_MOUNT_STATUS=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@${INSTANCE_IP} "mount | grep /mnt/efs || echo 'Not mounted'")

if [[ "$EFS_MOUNT_STATUS" == *"Not mounted"* ]]; then
  error "EFSがマウントされていません。ログを確認してください: ssh -i $SSH_KEY_PATH ubuntu@${INSTANCE_IP} 'sudo cat /var/log/fix-efs.log'"
else
  log "✓ EFSが正常にマウントされました: $EFS_MOUNT_STATUS"
fi

# Check WireGuard status
log "WireGuardの状態を確認しています..."
WG_STATUS=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@${INSTANCE_IP} "sudo wg show || echo 'WireGuard not running'")

if [[ "$WG_STATUS" == *"WireGuard not running"* ]]; then
  warn "WireGuardが実行されていません。手動で開始してください: ssh -i $SSH_KEY_PATH ubuntu@${INSTANCE_IP} 'sudo systemctl start wg-quick@wg0'"
else
  log "✓ WireGuardが正常に実行されています:"
  echo "$WG_STATUS"
fi

log "プロセスが完了しました。EFSが正常にマウントされ、WireGuardが設定されました。"
log "詳細ログは次のコマンドで確認できます: ssh -i $SSH_KEY_PATH ubuntu@${INSTANCE_IP} 'sudo cat /var/log/fix-efs.log'"