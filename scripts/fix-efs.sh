#!/bin/bash
# Script to fix EFS mounting on the EC2 instance
# Run this on the EC2 instance

set -e

# Log file
LOG_FILE="/var/log/fix-efs.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== $(date): Starting EFS mount fixing script ==="

# Get EFS ID from Ansible if available, or use direct parameter
EFS_ID="${1:-$(cat /tmp/efs_id 2>/dev/null || echo "")}"

if [ -z "$EFS_ID" ]; then
  echo "Error: EFS ID not provided. Usage: $0 <efs_id>"
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

# Check if already mounted
if mount | grep -q "$MOUNT_POINT"; then
  echo "EFS is already mounted at $MOUNT_POINT"
else
  echo "Attempting to mount EFS..."
  
  # Get region
  REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\" -f4)
  echo "Region: $REGION"
  
  # Try mounting with efs-utils
  echo "Trying to mount with efs-utils..."
  mount -t efs -o tls "$EFS_ID":/ "$MOUNT_POINT" || true
  
  # Check if mount succeeded
  if ! mount | grep -q "$MOUNT_POINT"; then
    echo "efs-utils mount failed, trying NFS mount..."
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS_ID.efs.$REGION.amazonaws.com":/ "$MOUNT_POINT" || true
  fi
  
  # Final check
  if mount | grep -q "$MOUNT_POINT"; then
    echo "EFS mounted successfully"
  else
    echo "Failed to mount EFS. Check security groups and network connectivity."
    
    # Network connectivity debug
    echo "Testing network connectivity..."
    ping -c 2 "$EFS_ID.efs.$REGION.amazonaws.com" || true
    
    echo "Testing NFS port..."
    nc -zv "$EFS_ID.efs.$REGION.amazonaws.com" 2049 || true
    
    exit 1
  fi
fi

# Setup directories
echo "Setting up WireGuard directories on EFS..."
mkdir -p "$MOUNT_POINT/wireguard/clients"
chmod -R 700 "$MOUNT_POINT/wireguard"

# Check if WireGuard is already configured
WIREGUARD_PATH="/etc/wireguard"
if [ -f "$WIREGUARD_PATH/wg0.conf" ] && [ ! -L "$WIREGUARD_PATH" ]; then
  echo "Found existing WireGuard configuration, copying to EFS..."
  
  # Check if EFS already has WireGuard config
  if [ ! -f "$MOUNT_POINT/wireguard/wg0.conf" ]; then
    cp -a "$WIREGUARD_PATH"/* "$MOUNT_POINT/wireguard/"
    echo "Copied WireGuard configuration to EFS"
  else
    echo "EFS already has WireGuard configuration, using that"
  fi
  
  # Stop WireGuard service
  echo "Stopping WireGuard service..."
  systemctl stop wg-quick@wg0 || true
  
  # Backup existing directory
  BACKUP_DIR="$WIREGUARD_PATH.bak.$(date +%s)"
  echo "Backing up existing WireGuard directory to $BACKUP_DIR..."
  mv "$WIREGUARD_PATH" "$BACKUP_DIR"
  
  # Create symlink
  echo "Creating symlink to EFS..."
  ln -sf "$MOUNT_POINT/wireguard" "$WIREGUARD_PATH"
  
  # Start WireGuard service
  echo "Starting WireGuard service..."
  systemctl start wg-quick@wg0 || true
fi

# Add to fstab for persistence
if ! grep -q "$EFS_ID" /etc/fstab; then
  echo "Adding EFS mount to fstab..."
  echo "$EFS_ID.efs.$REGION.amazonaws.com:/ $MOUNT_POINT nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
fi

# Create mount service for early boot
echo "Creating boot-time mount service..."
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
wg show || true

# Update client configs to use NLB if available
if [ -f "$WIREGUARD_PATH/nlb_endpoint" ]; then
  NLB_ENDPOINT=$(cat "$WIREGUARD_PATH/nlb_endpoint")
  if [ -n "$NLB_ENDPOINT" ]; then
    echo "Updating client configs to use NLB endpoint: $NLB_ENDPOINT"
    
    for CONFIG in "$WIREGUARD_PATH/clients"/*.conf; do
      if [ -f "$CONFIG" ]; then
        CURRENT_ENDPOINT=$(grep "Endpoint =" "$CONFIG" | awk '{print $3}')
        CURRENT_PORT=$(echo "$CURRENT_ENDPOINT" | cut -d ':' -f2)
        
        if [ -n "$CURRENT_PORT" ]; then
          NEW_ENDPOINT="$NLB_ENDPOINT:$CURRENT_PORT"
          sed -i "s|Endpoint = .*|Endpoint = $NEW_ENDPOINT|" "$CONFIG"
          echo "Updated endpoint in $CONFIG to $NEW_ENDPOINT"
          
          # Regenerate QR code if needed
          if command -v qrencode &> /dev/null; then
            qrencode -t ansiutf8 < "$CONFIG" > "${CONFIG}.qrcode.txt"
          fi
        fi
      fi
    done
  fi
fi

echo "=== $(date): EFS mount fixing completed ==="