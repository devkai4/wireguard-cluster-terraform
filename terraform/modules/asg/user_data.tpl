#!/bin/bash
# Initial server setup for VPN server in Auto Scaling Group

set -e

# Log setup progress
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting VPN server setup script - $(date)"

# Update and install required packages
apt-get update
apt-get upgrade -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    fail2ban \
    jq \
    unzip \
    wireguard \
    wireguard-tools \
    nfs-common \
    qrencode \
    amazon-efs-utils

# Set up hostname with instance ID for better identification
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
hostnamectl set-hostname ${hostname}-$INSTANCE_ID

echo "Host name set to $(hostname)"

# Configure fail2ban
cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# Restart fail2ban
systemctl restart fail2ban
echo "Fail2ban configured and restarted"

# Setup CloudWatch Agent if needed
if [ "${install_cloudwatch_agent}" = "true" ]; then
    echo "Installing CloudWatch Agent"
    # Install CloudWatch Agent
    curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i amazon-cloudwatch-agent.deb
    
    # Configure CloudWatch Agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWAGENTCONFIG
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}",
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "disk": {
        "measurement": [
          "disk_used_percent"
        ],
        "resources": [
          "/"
        ]
      },
      "net": {
        "measurement": [
          "bytes_sent",
          "bytes_recv",
          "packets_sent",
          "packets_recv"
        ],
        "resources": [
          "*"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/syslog"
          },
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/auth.log"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/user-data"
          },
          {
            "file_path": "/var/log/wireguard.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/wireguard"
          }
        ]
      }
    }
  }
}
CWAGENTCONFIG
    
    # Start CloudWatch Agent
    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
    echo "CloudWatch Agent installed and configured"
fi

# Setup Node Exporter for Prometheus
if [ "${install_node_exporter}" = "true" ]; then
    echo "Installing Node Exporter"
    # Create node exporter user
    useradd --no-create-home --shell /bin/false node_exporter
    
    # Download and extract node exporter
    cd /tmp
    curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
    
    tar xvf node_exporter-*.tar.gz
    cp node_exporter-*/node_exporter /usr/local/bin/
    chown node_exporter:node_exporter /usr/local/bin/node_exporter
    
    # Create systemd service for node exporter
    cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF
    
    # Start node exporter
    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    echo "Node Exporter installed and started"
fi

# WireGuard Installation
if [ "${install_wireguard}" = "true" ]; then
    echo "Setting up WireGuard"
    # Create wireguard log file
    touch /var/log/wireguard.log
    chmod 640 /var/log/wireguard.log
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
    sysctl -p /etc/sysctl.d/99-wireguard.conf
    
    # Setup shared storage if enabled
    if [ "${enable_shared_storage}" = "true" ] && [ ! -z "${efs_id}" ]; then
        echo "Setting up shared storage with EFS ID: ${efs_id}"
        mkdir -p /mnt/efs
        
        # Mount EFS
        echo "${efs_id}:/ /mnt/efs efs _netdev,tls,iam 0 0" >> /etc/fstab
        mount -a
        
        if [ $? -eq 0 ]; then
            echo "EFS mounted successfully"
            mkdir -p /mnt/efs/wireguard
            ln -sf /mnt/efs/wireguard /etc/wireguard
        else
            echo "EFS mount failed, using local storage"
            mkdir -p /etc/wireguard
        fi
    else
        echo "Using local storage for WireGuard config"
        mkdir -p /etc/wireguard
    fi
    
    chmod 700 /etc/wireguard
    
    # Check if we're the first instance to initialize the shared config
    if [ "${enable_shared_storage}" = "true" ] && [ -f "/etc/wireguard/server_private_key" ]; then
        echo "WireGuard configuration already exists, using existing keys"
    else
        echo "Generating new WireGuard keys"
        # Generate server keys
        wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
        chmod 600 /etc/wireguard/server_private_key
        chmod 644 /etc/wireguard/server_public_key
        
        # Create initial WireGuard config
        SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private_key)
        cat > /etc/wireguard/wg0.conf << EOF
# WireGuard Server Configuration
[Interface]
Address = 10.8.0.1/24
ListenPort = ${wireguard_port}
PrivateKey = $SERVER_PRIVATE_KEY

# PostUp rules
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -s ${wireguard_network} -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE

# PostDown rules
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s ${wireguard_network} -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE

# Client configurations will be added below
EOF
        # Create a clients directory
        mkdir -p /etc/wireguard/clients
    fi
    
    # Start WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    echo "WireGuard started successfully"
    
    # Copy the client generation script
    cat > /usr/local/bin/gen-client-config.sh << 'GENCONFIG'
#!/bin/bash
# WireGuard client configuration generator
set -e

# Log output
exec >> /var/log/wireguard.log 2>&1
echo "$(date): Running client config generator"

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "$(date): Error - Usage: $0 <client_name> <client_ip>"
    echo "$(date): Example: $0 laptop 10.8.0.2/24"
    exit 1
fi

CLIENT_NAME="$1"
CLIENT_IP="$2"
CONFIG_DIR="/etc/wireguard/clients"

# Get public IP using multiple methods
get_public_ip() {
    # Try AWS metadata first
    local ip=$(curl -s --connect-timeout 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    if [ -n "$ip" ] && [[ ! "$ip" =~ ^10\. ]] && [[ ! "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && [[ ! "$ip" =~ ^192\.168\. ]]; then
        echo "$ip"
        return 0
    fi
    
    # Try external services
    ip=$(curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null || 
         curl -s --connect-timeout 3 https://api.ipify.org 2>/dev/null ||
         curl -s --connect-timeout 3 https://checkip.amazonaws.com 2>/dev/null)
    
    if [ -n "$ip" ] && [[ ! "$ip" =~ ^10\. ]] && [[ ! "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && [[ ! "$ip" =~ ^192\.168\. ]]; then
        echo "$ip"
        return 0
    fi
    
    # Try to get NLB endpoint if available
    if [ -f "/etc/wireguard/nlb_endpoint" ]; then
        ip=$(cat /etc/wireguard/nlb_endpoint)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi
    
    return 1
}

# Get public IP
SERVER_PUBLIC_IP=$(get_public_ip)

# Check if we got a valid public IP
if [ -z "$SERVER_PUBLIC_IP" ] || [[ "$SERVER_PUBLIC_IP" =~ ^10\. ]] || [[ "$SERVER_PUBLIC_IP" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$SERVER_PUBLIC_IP" =~ ^192\.168\. ]]; then
    echo "$(date): Warning - Could not determine public IP or got private IP: $SERVER_PUBLIC_IP"
    SERVER_PUBLIC_IP="REPLACE_WITH_YOUR_PUBLIC_IP"
else
    echo "$(date): Using server public IP: $SERVER_PUBLIC_IP"
fi

SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public_key)
SERVER_PORT=$(grep ListenPort /etc/wireguard/wg0.conf | awk '{print $3}')

# Create client directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Generate client keys
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Create client configuration
CLIENT_CONFIG="$CONFIG_DIR/${CLIENT_NAME}.conf"
cat > "$CLIENT_CONFIG" << EOF
# WireGuard Client Configuration for $CLIENT_NAME
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# Add client to server configuration if not already exists
SERVER_CONFIG="/etc/wireguard/wg0.conf"
if ! grep -q "$CLIENT_PUBLIC_KEY" "$SERVER_CONFIG"; then
    echo "$(date): Adding client $CLIENT_NAME to server config"
    cat >> "$SERVER_CONFIG" << EOF

# Client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = ${CLIENT_IP%/*}/32
EOF

    # Restart WireGuard to apply changes
    systemctl restart wg-quick@wg0
    echo "$(date): WireGuard restarted with new client"
else
    echo "$(date): Client $CLIENT_NAME already exists in server config"
fi

# Generate QR code if qrencode is installed
if command -v qrencode &> /dev/null; then
    echo "$(date): Generating QR code for $CLIENT_NAME"
    qrencode -t ansiutf8 < "$CLIENT_CONFIG" > "$CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
fi

echo "$(date): Client configuration for $CLIENT_NAME created successfully"
GENCONFIG

    chmod +x /usr/local/bin/gen-client-config.sh
    
    # Create default client configs
    /usr/local/bin/gen-client-config.sh admin-laptop 10.8.0.2/24
    /usr/local/bin/gen-client-config.sh admin-phone 10.8.0.3/24
    
    echo "WireGuard setup completed with default clients"
fi

# Create a simple health check script
cat > /usr/local/bin/wireguard-health-check.sh << 'HEALTHCHECK'
#!/bin/bash
# Simple health check for WireGuard

# Check if WireGuard interface is up
if ip a show wg0 up > /dev/null 2>&1; then
    # Check if we can see the WireGuard process
    if wg show wg0 > /dev/null 2>&1; then
        # Everything seems to be working
        echo "WireGuard is running normally"
        exit 0
    fi
fi

# Something is wrong, restart WireGuard
echo "WireGuard health check failed, restarting service..."
systemctl restart wg-quick@wg0
exit 1
HEALTHCHECK

chmod +x /usr/local/bin/wireguard-health-check.sh

# Setup a cron job to run the health check every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/wireguard-health-check.sh > /dev/null 2>&1") | crontab -

# Any additional user data
${additional_user_data}

echo "VPN server setup completed successfully - $(date)"