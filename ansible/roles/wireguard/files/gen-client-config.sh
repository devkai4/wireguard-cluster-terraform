#!/bin/bash
# WireGuard client configuration generator

set -e

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <client_name> <client_ip>"
    echo "Example: $0 laptop 10.8.0.2/24"
    exit 1
fi

CLIENT_NAME="$1"
CLIENT_IP="$2"
CONFIG_DIR="/etc/wireguard/clients"
SERVER_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
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

# Add client to server configuration
SERVER_CONFIG="/etc/wireguard/wg0.conf"
if ! grep -q "$CLIENT_PUBLIC_KEY" "$SERVER_CONFIG"; then
    cat >> "$SERVER_CONFIG" << EOF

# Client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = ${CLIENT_IP%/*}/32
EOF
fi

# Restart WireGuard
systemctl restart wg-quick@wg0

# Generate QR code
if command -v qrencode &> /dev/null; then
    qrencode -t ansiutf8 < "$CLIENT_CONFIG" > "$CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
    echo "QR code generated at $CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
fi

echo "Client configuration for $CLIENT_NAME created at $CLIENT_CONFIG"
echo "Public IP: $SERVER_PUBLIC_IP"