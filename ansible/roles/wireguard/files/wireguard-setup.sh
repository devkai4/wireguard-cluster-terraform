#!/bin/bash
# WireGuard setup script

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Install WireGuard if not already installed
if ! command -v wg &> /dev/null; then
    apt-get update
    apt-get install -y wireguard wireguard-tools
fi

# Generate server keys if they don't exist
if [ ! -f /etc/wireguard/server_private_key ]; then
    wg genkey > /etc/wireguard/server_private_key
    chmod 600 /etc/wireguard/server_private_key
fi

if [ ! -f /etc/wireguard/server_public_key ]; then
    cat /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
fi

# Create client directory
mkdir -p /etc/wireguard/clients

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

SERVER_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || curl -s https://ifconfig.me)
if [ -n "$SERVER_PUBLIC_IP" ]; then
    echo "$SERVER_PUBLIC_IP" > /etc/wireguard/server_public_ip
    chmod 644 /etc/wireguard/server_public_ip
    echo "Saved server public IP: $SERVER_PUBLIC_IP"
else
    echo "Warning: Could not determine server public IP address"
fi

# サーバーの正しいネットワークインターフェースを特定
WAN_IFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$WAN_IFACE" ]; then
    echo "Warning: Could not determine WAN interface, defaulting to eth0" >&2
    WAN_IFACE="eth0"
fi
echo "Detected WAN interface: $WAN_IFACE"

# サーバーのパブリックIPを取得して保存
SERVER_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || curl -s https://ifconfig.me)
if [ -n "$SERVER_PUBLIC_IP" ]; then
    echo "$SERVER_PUBLIC_IP" > /etc/wireguard/server_public_ip
    chmod 644 /etc/wireguard/server_public_ip
    echo "Saved server public IP: $SERVER_PUBLIC_IP"
else
    echo "Warning: Could not determine server public IP address"
fi

echo "WireGuard setup completed!"