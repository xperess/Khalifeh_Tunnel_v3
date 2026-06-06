#!/bin/bash

BASE="/opt/khalifeh"
CFG="$BASE/configs"
BIN="$BASE/bin"
SERVICE="/etc/systemd/system"

# ================================
# INSTALL HYSTERIA2
# ================================
install_hysteria2() {

echo "[*] Installing Hysteria2..."

mkdir -p "$BIN"

ARCH=$(uname -m)

LATEST=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest)

if [[ "$ARCH" == "x86_64" ]]; then
    URL=$(echo "$LATEST" | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)
elif [[ "$ARCH" == "aarch64" ]]; then
    URL=$(echo "$LATEST" | grep browser_download_url | grep linux-arm64 | cut -d '"' -f 4)
else
    echo "Unsupported architecture"
    exit 1
fi

curl -L "$URL" -o /tmp/hysteria.tar.gz
tar -xzf /tmp/hysteria.tar.gz -C /tmp/

cp /tmp/hysteria*/hysteria $BIN/hysteria2
chmod +x $BIN/hysteria2

echo "[+] Hysteria2 installed"
}

# ================================
# GENERATE PASSWORD
# ================================
gen_pass() {
openssl rand -hex 16
}

# ================================
# SERVER CONFIG
# ================================
hysteria_server() {

echo "Enter listen port [443]: "
read PORT
PORT=${PORT:-443}

PASS=$(gen_pass)

CONFIG="$CFG/hysteria-server.yaml"

cat > "$CONFIG" <<EOF
listen: :$PORT

auth:
  type: password
  password: $PASS

tls:
  cert: /etc/ssl/cert.pem
  key: /etc/ssl/key.pem

bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF

echo "[+] Hysteria2 Server created"
echo "[!] PASSWORD: $PASS"
}

# ================================
# CLIENT CONFIG
# ================================
hysteria_client() {

echo "Server IP: "
read IP

echo "Port: "
read PORT

echo "Password: "
read PASS

CONFIG="$CFG/hysteria-client.yaml"

cat > "$CONFIG" <<EOF
server: $IP:$PORT

auth: $PASS

tls:
  insecure: true

bandwidth:
  up: 50 mbps
  down: 50 mbps
EOF

echo "[+] Hysteria2 Client created"
}

# ================================
# SYSTEMD SERVER
# ================================
start_server() {

cat > "$SERVICE/hysteria2.service" <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=$BIN/hysteria2 server -c $CFG/hysteria-server.yaml
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hysteria2
systemctl start hysteria2

echo "[+] Server started"
}

# ================================
# SYSTEMD CLIENT
# ================================
start_client() {

cat > "$SERVICE/hysteria2-client.service" <<EOF
[Unit]
Description=Hysteria2 Client
After=network.target

[Service]
ExecStart=$BIN/hysteria2 client -c $CFG/hysteria-client.yaml
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hysteria2-client
systemctl start hysteria2-client

echo "[+] Client started"
}

# ================================
# STATUS
# ================================
status() {
systemctl status hysteria2 --no-pager || true
systemctl status hysteria2-client --no-pager || true
}

# ================================
# MENU
# ================================
hysteria_menu() {

while true
do

echo ""
echo "===== HYSTERIA2 MODULE ====="
echo "1) Install Hysteria2"
echo "2) Create Server"
echo "3) Create Client"
echo "4) Start Server"
echo "5) Start Client"
echo "6) Status"
echo "0) Back"

read -p "Select: " c

case $c in
1) install_hysteria2 ;;
2) hysteria_server ;;
3) hysteria_client ;;
4) start_server ;;
5) start_client ;;
6) status ;;
0) break ;;
esac

done
}