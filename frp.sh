#!/bin/bash

BASE="/opt/khalifeh"
CONFIG="$BASE/configs"
BIN="$BASE/bin"
SERVICE="/etc/systemd/system"

# ================================
# INSTALL FRP
# ================================
install_frp() {

echo "[*] Installing FRP..."

mkdir -p "$BIN"

ARCH=$(uname -m)

LATEST=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest)

if [[ "$ARCH" == "x86_64" ]]; then
    URL=$(echo "$LATEST" | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4)
elif [[ "$ARCH" == "aarch64" ]]; then
    URL=$(echo "$LATEST" | grep browser_download_url | grep linux_arm64 | cut -d '"' -f 4)
else
    echo "Unsupported architecture"
    exit 1
fi

curl -L "$URL" -o /tmp/frp.tar.gz
tar -xzf /tmp/frp.tar.gz -C /tmp/

cp /tmp/frp*/frps "$BIN/"
cp /tmp/frp*/frpc "$BIN/"

chmod +x "$BIN/frps" "$BIN/frpc"

echo "[+] FRP installed"
}

# ================================
# GENERATE TOKEN
# ================================
gen_token() {
openssl rand -hex 32
}

# ================================
# SERVER CONFIG (IRAN)
# ================================
frp_server() {

echo "Dashboard port [7500]: "
read DASH
DASH=${DASH:-7500}

echo "Bind port (tunnel) [7000]: "
read BIND
BIND=${BIND:-7000}

TOKEN=$(gen_token)

CONFIG="$CONFIG/frps.toml"

cat > "$CONFIG" <<EOF
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

# ================================
# CLIENT CONFIG (KHAREJ)
# ================================
frp_client() {

echo "Iran IP: "
read IP

echo "Tunnel port: "
read PORT

echo "Token: "
read TOKEN

echo "Local ports (comma separated): "
read PORTS

CONFIG="$CONFIG/frpc.toml"

cat > "$CONFIG" <<EOF
[common]
server_addr = "$IP"
server_port = $PORT
auth.method = "token"
auth.token = "$TOKEN"
EOF

IFS=',' read -ra ADDR <<< "$PORTS"

for p in "${ADDR[@]}"; do
p=$(echo $p | xargs)

cat >> "$CONFIG" <<EOF

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

# ================================
# SYSTEMD SERVER
# ================================
start_server() {

cat > "$SERVICE/frps.service" <<EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=$BIN/frps -c $CONFIG/frps.toml
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frps
systemctl start frps

echo "[+] FRP Server started"
}

# ================================
# SYSTEMD CLIENT
# ================================
start_client() {

cat > "$SERVICE/frpc.service" <<EOF
[Unit]
Description=FRP Client
After=network.target

[Service]
ExecStart=$BIN/frpc -c $CONFIG/frpc.toml
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frpc
systemctl start frpc

echo "[+] FRP Client started"
}

# ================================
# STATUS
# ================================
status() {
echo "=== FRP SERVER ==="
systemctl status frps --no-pager || true

echo "=== FRP CLIENT ==="
systemctl status frpc --no-pager || true
}

# ================================
# DASHBOARD INFO
# ================================
info() {
echo "FRP Dashboard usually runs on:"
echo "http://SERVER_IP:7500"
echo "Default user: admin"
echo "Password is randomly generated"
}

# ================================
# MENU
# ================================
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