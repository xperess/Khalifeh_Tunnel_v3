#!/bin/bash

RATHOLE_DIR="/opt/khalifeh"
CONFIG_DIR="$RATHOLE_DIR/configs"
BIN_DIR="$RATHOLE_DIR/bin"
SERVICE_DIR="/etc/systemd/system"

# ================================
# INSTALL RATHOLE
# ================================
install_rathole() {

echo "[*] Installing Rathole..."

mkdir -p "$BIN_DIR"

ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    URL=$(curl -s https://api.github.com/repos/rapiz1/rathole/releases/latest | grep browser_download_url | grep x86_64 | cut -d '"' -f 4)
elif [[ "$ARCH" == "aarch64" ]]; then
    URL=$(curl -s https://api.github.com/repos/rapiz1/rathole/releases/latest | grep browser_download_url | grep aarch64 | cut -d '"' -f 4)
else
    echo "Unsupported arch"
    exit 1
fi

curl -L "$URL" -o /tmp/rathole.zip
unzip -o /tmp/rathole.zip -d /tmp/

cp /tmp/rathole "$BIN_DIR/rathole"
chmod +x "$BIN_DIR/rathole"

echo "[+] Rathole installed"
}

# ================================
# GENERATE TOKEN
# ================================
generate_token() {
openssl rand -hex 32
}

# ================================
# CREATE IRAN SERVER
# ================================
create_iran_server() {

echo "Enter tunnel port (default 2333): "
read TPORT
TPORT=${TPORT:-2333}

echo "Enter service ports (comma separated): "
read PORTS

TOKEN=$(generate_token)

CONFIG="$CONFIG_DIR/rathole-server.toml"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG" <<EOF
[server]
bind_addr = "0.0.0.0:$TPORT"
default_token = "$TOKEN"

[server.transport]
type = "tcp"
EOF

IFS=',' read -ra ADDR <<< "$PORTS"

for p in "${ADDR[@]}"; do
p=$(echo $p | xargs)
cat >> "$CONFIG" <<EOF

[server.services.port$p]
bind_addr = "0.0.0.0:$p"
EOF
done

echo "[+] Server config created: $CONFIG"
echo "[!] SAVE TOKEN: $TOKEN"
}

# ================================
# CREATE KHAREJ CLIENT
# ================================
create_kharej_client() {

echo "Enter Iran IP: "
read IP

echo "Enter tunnel port: "
read TPORT

echo "Enter service ports (comma separated): "
read PORTS

echo "Enter TOKEN: "
read TOKEN

CONFIG="$CONFIG_DIR/rathole-client.toml"

cat > "$CONFIG" <<EOF
[client]
remote_addr = "$IP:$TPORT"
default_token = "$TOKEN"

[client.transport]
type = "tcp"
EOF

IFS=',' read -ra ADDR <<< "$PORTS"

for p in "${ADDR[@]}"; do
p=$(echo $p | xargs)
cat >> "$CONFIG" <<EOF

[client.services.port$p]
local_addr = "127.0.0.1:$p"
EOF
done

echo "[+] Client config created: $CONFIG"
}

# ================================
# SYSTEMD SERVER
# ================================
start_server_service() {

SERVICE="/etc/systemd/system/khalifeh-rathole-server.service"

cat > "$SERVICE" <<EOF
[Unit]
Description=Khalifeh Rathole Server
After=network.target

[Service]
ExecStart=$BIN_DIR/rathole $CONFIG_DIR/rathole-server.toml
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable khalifeh-rathole-server
systemctl start khalifeh-rathole-server

echo "[+] Server started"
}

# ================================
# SYSTEMD CLIENT
# ================================
start_client_service() {

SERVICE="/etc/systemd/system/khalifeh-rathole-client.service"

cat > "$SERVICE" <<EOF
[Unit]
Description=Khalifeh Rathole Client
After=network.target

[Service]
ExecStart=$BIN_DIR/rathole $CONFIG_DIR/rathole-client.toml
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable khalifeh-rathole-client
systemctl start khalifeh-rathole-client

echo "[+] Client started"
}

# ================================
# STATUS
# ================================
status() {
systemctl status khalifeh-rathole-server --no-pager
systemctl status khalifeh-rathole-client --no-pager
}

# ================================
# MENU
# ================================
rathole_menu() {

while true
do
echo ""
echo "==== RATHOLE MENU ===="
echo "1) Install Rathole"
echo "2) Create Iran Server"
echo "3) Create Kharej Client"
echo "4) Start Server"
echo "5) Start Client"
echo "6) Status"
echo "0) Back"
read -p "Select: " c

case $c in
1) install_rathole ;;
2) create_iran_server ;;
3) create_kharej_client ;;
4) start_server_service ;;
5) start_client_service ;;
6) status ;;
0) break ;;
esac

done
}