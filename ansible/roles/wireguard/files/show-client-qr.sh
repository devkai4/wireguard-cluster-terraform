#!/bin/bash
# スクリプトを実行して特定のクライアントのQRコードを表示します

set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <client_name>"
    echo "Example: $0 admin-phone"
    exit 1
fi

CLIENT_NAME="$1"
CONFIG_DIR="/etc/wireguard/clients"
QR_FILE="$CONFIG_DIR/${CLIENT_NAME}.qrcode.txt"
CONFIG_FILE="$CONFIG_DIR/${CLIENT_NAME}.conf"

if [ ! -f "$QR_FILE" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Client configuration not found for $CLIENT_NAME"
        exit 1
    fi
    
    # 設定ファイルからQRコードを生成
    echo "Generating QR code for $CLIENT_NAME..."
    
    # サーバーIPを取得
    SERVER_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || curl -s https://ifconfig.me)
    
    # 設定ファイルを一時ファイルにコピー
    TMP_CONFIG=$(mktemp)
    cp "$CONFIG_FILE" "$TMP_CONFIG"
    
    # エンドポイントが正しいか確認
    if grep -q "Endpoint = :51820" "$TMP_CONFIG"; then
        sed -i "s|Endpoint = :51820|Endpoint = $SERVER_IP:51820|" "$TMP_CONFIG"
    fi
    
    # QRコードを生成
    qrencode -t ansiutf8 < "$TMP_CONFIG" > "$QR_FILE"
    rm -f "$TMP_CONFIG"
fi

# QRコードを表示
if [ -f "$QR_FILE" ]; then
    echo "QR code for $CLIENT_NAME:"
    cat "$QR_FILE"
else
    echo "Error: Could not generate QR code"
    exit 1
fi
