#!/bin/bash

BASE="/opt/khalifeh"
CONFIG="$BASE/configs"
BIN="$BASE/bin"
SERVICE="/etc/systemd/system"

install_frp() {
echo "[*] Installing FRP..."
mkdir -p "$BIN"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz"
elif [[ "$ARCH" == "aarch64" ]]; then
    URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_arm64.tar.gz"
else
    echo "Unsupported architecture"
    exit 1
fi
echo "[*] Downloading from: $URL"
curl -L --connect-timeout 30 --retry 3 "$URL" -o /tmp/frp.tar.gz
if [[ $? -ne 0 ]]; then
    wget -q --timeout=30 "$URL" -O /tmp/frp.tar.gz
fi
tar -xzf /tmp/frp.tar.gz -C /tmp/
cp /tmp/frp*/frps "$BIN/"
cp /tmp/frp*/frpc "$BIN/"
chmod +x "$BIN/frps" "$BIN/frpc"
rm -rf /tmp/frp* /tmp/frp.tar.gz
echo "[+] FRP installed"
}

gen_token() {
openssl rand -hex 32
}

frp_server() {
echo "Dashboard port [7500]: "
read DASH
DASH=${DASH:-7500}
echo "Bind port (tunnel) [7000]: "
read BIND
BIND=${BIND:-7000}
TOKEN=$(gen_token)
CONFIG_FILE="$CONFIG/frps.toml"
cat > "$CONFIG_FILE" <<EOF
[common]
bindPort = $BIND
auth.method = "token"
auth.token = "$TOKEN"

dashboard_port = $DASH
dashboard_user = "admin"
dashboard_pwd = "$(openssl rand -hex 4)"
EOF
echo "[+] FRP Server config created"
echo "[!] TOKEN: $TOKEN"
echo "[!] Dashboard: http://SERVER_IP:$DASH"
}

frp_client() {
echo "Iran IP: "
read IP
echo "Tunnel port: "
read PORT
echo "Token: "
read TOKEN
echo "Local ports (comma separated): "
read PORTS
CONFIG_FILE="$CONFIG/frpc.toml"
cat > "$CONFIG_FILE" <<EOF
[common]
server_addr = "$IP"
server_port = $PORT
auth.method = "token"
auth.token = "$TOKEN"
EOF
IFS=',' read -ra ADDR <<< "$PORTS"
for p in "${ADDR[@]}"; do
p=$(echo $p | xargs)
cat >> "$CONFIG_FILE" <<EOF

[[proxies]]
name = "p$p"
type = "tcp"
localIP = "127.0.0.1"
localPort = $p
remotePort = $p
EOF
done
echo "[+] FRP Client created"
}

start_server() {
cat > "$SERVICE/frps.service" <<EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=$BIN/frps -c $CONFIG/frps.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable frps
systemctl start frps
echo "[+] FRP Server started"
}

start_client() {
cat > "$SERVICE/frpc.service" <<EOF
[Unit]
Description=FRP Client
After=network.target

[Service]
ExecStart=$BIN/frpc -c $CONFIG/frpc.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc
echo "[+] FRP Client started"
}

status() {
echo "=== FRP SERVER ==="
systemctl status frps --no-pager || true
echo "=== FRP CLIENT ==="
systemctl status frpc --no-pager || true
}

info() {
echo "FRP Dashboard usually runs on:"
echo "http://SERVER_IP:7500"
echo "Default user: admin"
echo "Password is randomly generated"
}

frp_menu() {
while true
do
echo ""
echo "===== FRP MODULE ====="
echo "1) Install FRP"
echo "2) Create Server (Iran)"
echo "3) Create Client (Kharej)"
echo "4) Start Server"
echo "5) Start Client"
echo "6) Status"
echo "7) Dashboard Info"
echo "0) Back"
read -p "Select: " c
case $c in
1) install_frp ;;
2) frp_server ;;
3) frp_client ;;
4) start_server ;;
5) start_client ;;
6) status ;;
7) info ;;
0) break ;;
esac
done
}