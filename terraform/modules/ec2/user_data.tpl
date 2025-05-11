#!/bin/bash
# Initial server setup for VPN server

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
    wireguard-tools

# Set up hostname
hostnamectl set-hostname ${hostname}

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

# Setup CloudWatch Agent if needed
if [ "${install_cloudwatch_agent}" = "true" ]; then
    # Install CloudWatch Agent
    curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i amazon-cloudwatch-agent.deb
    
    # Configure CloudWatch Agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
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
          }
        ]
      }
    }
  }
}
EOF
    
    # Start CloudWatch Agent
    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
fi

# Setup Node Exporter for Prometheus
if [ "${install_node_exporter}" = "true" ]; then
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
fi

# Additional setup scripts
${additional_user_data}

echo "Server setup completed!"# WireGuard Installation (Basic setup, will be configured fully with Ansible)
if [ "${install_wireguard}" = "true" ]; then
    # Install WireGuard
    apt-get install -y wireguard wireguard-tools

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
    sysctl -p /etc/sysctl.d/99-wireguard.conf
    
    # Make sure WireGuard directory exists with proper permissions
    mkdir -p /etc/wireguard
    chmod 700 /etc/wireguard
    
    # Generate initial keys
    wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
    chmod 600 /etc/wireguard/server_private_key
    
    echo "WireGuard basic installation completed. Full configuration will be done with Ansible."
fi
