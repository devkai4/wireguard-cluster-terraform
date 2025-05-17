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
SERVER_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || curl -s https://ifconfig.me)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public_key)
SERVER_PORT=$(grep ListenPort /etc/wireguard/wg0.conf | awk '{print $3}')

# IPが取得できているか確認
if [ -z "$SERVER_PUBLIC_IP" ]; then
    echo "Warning: Could not determine server public IP address automatically" >&2
    echo "Using hostname resolution as fallback..." >&2
    # ホスト名からの解決を試みる
    SERVER_PUBLIC_IP=$(hostname -I | awk '{print $1}')
    # それでも取得できない場合
    if [ -z "$SERVER_PUBLIC_IP" ]; then
        echo "Error: Failed to determine server IP. Please set manually." >&2
        SERVER_PUBLIC_IP="YOUR_SERVER_IP"  # この行はデプロイ前に適切に設定する必要がある
    fi
fi

echo "Using server public IP: $SERVER_PUBLIC_IP"

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

# エンドポイントが正しく設定されているか確認
if ! grep -q "Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT" "$CLIENT_CONFIG"; then
    echo "Warning: Endpoint may not be correctly set in config file" >&2
    # 設定ファイルを修正
    sed -i "s|Endpoint = .*|Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT|" "$CLIENT_CONFIG"
    echo "Fixed endpoint in configuration file"
fi

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
    # クライアント設定を一時ファイルにコピー
    TMP_CONFIG=$(mktemp)
    cat "$CLIENT_CONFIG" > "$TMP_CONFIG"
    
    # 一時ファイル内のエンドポイントが正しいことを確認
    if grep -q "Endpoint = :51820" "$TMP_CONFIG"; then
        # 空のエンドポイントを修正
        sed -i "s|Endpoint = :51820|Endpoint = $SERVER_PUBLIC_IP:51820|" "$TMP_CONFIG"
        echo "Fixed empty endpoint in QR code configuration"
    fi
    
    # QRコードを生成
    qrencode -t ansiutf8 < "$TMP_CONFIG" > "$CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
    echo "QR code generated at $CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
    
    # 一時ファイルを削除
    rm -f "$TMP_CONFIG"
fi