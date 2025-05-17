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

# パブリックIPを取得する関数
get_public_ip() {
    # 方法1: AWS メタデータサービス
    local ip=$(curl -s --connect-timeout 3 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    if [ -n "$ip" ] && [[ ! "$ip" =~ ^10\. ]] && [[ ! "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && [[ ! "$ip" =~ ^192\.168\. ]]; then
        echo "$ip"
        return 0
    fi
    
    # 方法2: 外部サービスを使用
    ip=$(curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null)
    if [ -n "$ip" ] && [[ ! "$ip" =~ ^10\. ]] && [[ ! "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && [[ ! "$ip" =~ ^192\.168\. ]]; then
        echo "$ip"
        return 0
    fi
    
    # 方法3: 別の外部サービス
    ip=$(curl -s --connect-timeout 3 https://api.ipify.org 2>/dev/null)
    if [ -n "$ip" ] && [[ ! "$ip" =~ ^10\. ]] && [[ ! "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && [[ ! "$ip" =~ ^192\.168\. ]]; then
        echo "$ip"
        return 0
    fi
    
    return 1
}

# パブリックIPを取得
SERVER_PUBLIC_IP=$(get_public_ip)

# 取得したIPがプライベートIPでないか確認
if [ -z "$SERVER_PUBLIC_IP" ] || [[ "$SERVER_PUBLIC_IP" =~ ^10\. ]] || [[ "$SERVER_PUBLIC_IP" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$SERVER_PUBLIC_IP" =~ ^192\.168\. ]]; then
    echo "Warning: Got private IP or failed to determine public IP: $SERVER_PUBLIC_IP" >&2
    echo "Trying external services to get public IP..." >&2
    
    # 強制的に外部サービスを使用
    SERVER_PUBLIC_IP=$(curl -s https://ifconfig.me 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null)
    
    if [ -z "$SERVER_PUBLIC_IP" ] || [[ "$SERVER_PUBLIC_IP" =~ ^10\. ]] || [[ "$SERVER_PUBLIC_IP" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$SERVER_PUBLIC_IP" =~ ^192\.168\. ]]; then
        echo "Error: Still got private IP or failed to determine public IP: $SERVER_PUBLIC_IP" >&2
        echo "Please set the public IP address manually." >&2
        SERVER_PUBLIC_IP="REPLACE_WITH_YOUR_PUBLIC_IP"
    fi
fi

SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public_key)
SERVER_PORT=$(grep ListenPort /etc/wireguard/wg0.conf | awk '{print $3}')

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
    
    # プライベートIPが使われていないか確認
    if grep -q "Endpoint = 10\." "$TMP_CONFIG" || grep -q "Endpoint = 172\." "$TMP_CONFIG" || grep -q "Endpoint = 192\.168\." "$TMP_CONFIG"; then
        # プライベートIPを修正
        sed -i "s|Endpoint = [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+:|Endpoint = $SERVER_PUBLIC_IP:|" "$TMP_CONFIG"
        echo "Fixed private IP endpoint in QR code configuration"
    fi
   
    # QRコードを生成
    qrencode -t ansiutf8 < "$TMP_CONFIG" > "$CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
    echo "QR code generated at $CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
   
    # 一時ファイルを削除
    rm -f "$TMP_CONFIG"
fi

echo "Client configuration for $CLIENT_NAME created at $CLIENT_CONFIG"
echo "Public IP: $SERVER_PUBLIC_IP"