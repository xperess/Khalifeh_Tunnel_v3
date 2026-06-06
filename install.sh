# پاک کردن نصب قبلی
rm -rf /opt/khalifeh
rm -f /usr/local/bin/khalifeh

# ایجاد ساختار
mkdir -p /opt/khalifeh/modules
mkdir -p /opt/khalifeh/configs
mkdir -p /opt/khalifeh/bin
mkdir -p /opt/khalifeh/backup
mkdir -p /opt/khalifeh/web/templates

# نصب پکیج‌ها
apt update -y
apt install -y curl wget jq unzip openssl
apt install -y python3-flask || apt install -y flask

# ایجاد فایل core.sh
cat > /opt/khalifeh/core.sh << 'CORE_EOF'
#!/bin/bash

BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

if [[ -f "$MOD/rathole.sh" ]]; then
    source $MOD/rathole.sh
fi

if [[ -f "$MOD/frp.sh" ]]; then
    source $MOD/frp.sh
fi

if [[ -f "$MOD/hysteria2.sh" ]]; then
    source $MOD/hysteria2.sh
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

banner() {
clear
echo -e "${MAGENTA}"
echo "=========================================="
echo "   KHALIFEH TUNNEL v2 (COMPLETE EDITION)"
echo "=========================================="
echo -e "${NC}"
}

status_all() {
echo -e "${GREEN}=== RATHOLE ===${NC}"
systemctl status khalifeh-rathole-server --no-pager 2>/dev/null || echo "Not installed"
systemctl status khalifeh-rathole-client --no-pager 2>/dev/null || echo "Not installed"
echo ""
echo -e "${YELLOW}=== FRP ===${NC}"
systemctl status frps --no-pager 2>/dev/null || echo "Not installed"
systemctl status frpc --no-pager 2>/dev/null || echo "Not installed"
echo ""
echo -e "${CYAN}=== HYSTERIA2 ===${NC}"
systemctl status hysteria2 --no-pager 2>/dev/null || echo "Not installed"
systemctl status hysteria2-client --no-pager 2>/dev/null || echo "Not installed"
echo ""
read -p "Press Enter..."
}

optimize_network() {
echo "[*] Applying network optimizations..."
cat >> /etc/sysctl.conf << SYSCTL_EOF

# KHALIFEH OPTIMIZATION
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
SYSCTL_EOF
sysctl -p >/dev/null 2>&1
echo "[+] Network optimized"
read -p "Press Enter..."
}

backup() {
TS=$(date +%Y%m%d_%H%M%S)
BK="/opt/khalifeh/backup_$TS.tar.gz"
tar -czf $BK $BASE
echo "[+] Backup created: $BK"
read -p "Press Enter..."
}

restore() {
ls /opt/khalifeh/backup_*.tar.gz 2>/dev/null
echo "Enter backup file:"
read FILE
if [[ -f "$FILE" ]]; then
    tar -xzf $FILE -C /
    echo "[+] Restored"
else
    echo "Invalid file"
fi
read -p "Press Enter..."
}

health() {
echo "[*] Checking services..."
for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client; do
    if systemctl list-units --full -all 2>/dev/null | grep -q $svc; then
        STATUS=$(systemctl is-active $svc 2>/dev/null)
        if [[ "$STATUS" == "active" ]]; then
            echo -e "$svc : ${GREEN}OK${NC}"
        else
            echo -e "$svc : ${RED}DOWN${NC}"
        fi
    else
        echo -e "$svc : ${YELLOW}Not installed${NC}"
    fi
done
read -p "Press Enter..."
}

main_menu() {
while true; do
banner
echo "1) Rathole Module"
echo "2) FRP Module"
echo "3) Hysteria2 Module"
echo "4) Status All"
echo "5) Health Check"
echo "6) Network Optimize"
echo "7) Backup"
echo "8) Restore"
echo "0) Exit"
read -p "Select: " c
case $c in
1)
    if declare -f rathole_menu > /dev/null; then
        rathole_menu
    else
        echo "Rathole module not loaded"
        read -p "Press Enter..."
    fi
    ;;
2)
    if declare -f frp_menu > /dev/null; then
        frp_menu
    else
        echo "FRP module not loaded"
        read -p "Press Enter..."
    fi
    ;;
3)
    if declare -f hysteria_menu > /dev/null; then
        hysteria_menu
    else
        echo "Hysteria2 module not loaded"
        read -p "Press Enter..."
    fi
    ;;
4) status_all ;;
5) health ;;
6) optimize_network ;;
7) backup ;;
8) restore ;;
0) exit 0 ;;
esac
done
}
CORE_EOF

# ایجاد فایل rathole.sh
cat > /opt/khalifeh/modules/rathole.sh << 'RATHOLE_EOF'
#!/bin/bash

RATHOLE_DIR="/opt/khalifeh"
CONFIG_DIR="$RATHOLE_DIR/configs"
BIN_DIR="$RATHOLE_DIR/bin"
SERVICE_DIR="/etc/systemd/system"

install_rathole() {
echo "[*] Installing Rathole..."
mkdir -p "$BIN_DIR"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
elif [[ "$ARCH" == "aarch64" ]]; then
    URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-gnu.zip"
else
    echo "Unsupported arch: $ARCH"
    exit 1
fi
echo "[*] Downloading from: $URL"
curl -L --connect-timeout 30 --retry 3 "$URL" -o /tmp/rathole.zip
if [[ $? -ne 0 ]]; then
    wget -q --timeout=30 "$URL" -O /tmp/rathole.zip
fi
unzip -o /tmp/rathole.zip -d /tmp/
cp /tmp/rathole "$BIN_DIR/rathole"
chmod +x "$BIN_DIR/rathole"
rm -f /tmp/rathole.zip
echo "[+] Rathole installed successfully"
}

generate_token() {
openssl rand -hex 32
}

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

start_server_service() {
SERVICE="/etc/systemd/system/khalifeh-rathole-server.service"
cat > "$SERVICE" <<EOF
[Unit]
Description=Khalifeh Rathole Server
After=network.target

[Service]
ExecStart=$BIN_DIR/rathole $CONFIG_DIR/rathole-server.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable khalifeh-rathole-server
systemctl start khalifeh-rathole-server
echo "[+] Server started"
}

start_client_service() {
SERVICE="/etc/systemd/system/khalifeh-rathole-client.service"
cat > "$SERVICE" <<EOF
[Unit]
Description=Khalifeh Rathole Client
After=network.target

[Service]
ExecStart=$BIN_DIR/rathole $CONFIG_DIR/rathole-client.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable khalifeh-rathole-client
systemctl start khalifeh-rathole-client
echo "[+] Client started"
}

status() {
systemctl status khalifeh-rathole-server --no-pager
systemctl status khalifeh-rathole-client --no-pager
}

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
RATHOLE_EOF

# ایجاد فایل frp.sh
cat > /opt/khalifeh/modules/frp.sh << 'FRP_EOF'
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
FRP_EOF

# ایجاد فایل hysteria2.sh
cat > /opt/khalifeh/modules/hysteria2.sh << 'HY_EOF'
#!/bin/bash

BASE="/opt/khalifeh"
CFG="$BASE/configs"
BIN="$BASE/bin"
SERVICE="/etc/systemd/system"

generate_ssl() {
    echo "[*] Generating self-signed SSL certificate..."
    mkdir -p /etc/ssl/khalifeh
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
      -keyout /etc/ssl/khalifeh/key.pem -out /etc/ssl/khalifeh/cert.pem \
      -days 3650 -subj "/CN=localhost" 2>/dev/null
    echo "[+] SSL certificate created"
}

install_hysteria2() {
echo "[*] Installing Hysteria2..."
mkdir -p "$BIN"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-arm64"
else
    echo "Unsupported architecture"
    exit 1
fi
echo "[*] Downloading from: $URL"
curl -L --connect-timeout 30 --retry 3 "$URL" -o "$BIN/hysteria2"
if [[ $? -ne 0 ]]; then
    wget -q --timeout=30 "$URL" -O "$BIN/hysteria2"
fi
chmod +x "$BIN/hysteria2"
generate_ssl
echo "[+] Hysteria2 installed"
}

gen_pass() {
openssl rand -hex 16
}

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
  cert: /etc/ssl/khalifeh/cert.pem
  key: /etc/ssl/khalifeh/key.pem

bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF
echo "[+] Hysteria2 Server created"
echo "[!] PASSWORD: $PASS"
}

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

start_server() {
cat > "$SERVICE/hysteria2.service" <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=$BIN/hysteria2 server -c $CFG/hysteria-server.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable hysteria2
systemctl start hysteria2
echo "[+] Server started"
}

start_client() {
cat > "$SERVICE/hysteria2-client.service" <<EOF
[Unit]
Description=Hysteria2 Client
After=network.target

[Service]
ExecStart=$BIN/hysteria2 client -c $CFG/hysteria-client.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable hysteria2-client
systemctl start hysteria2-client
echo "[+] Client started"
}

status() {
systemctl status hysteria2 --no-pager || true
systemctl status hysteria2-client --no-pager || true
}

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
HY_EOF

# ایجاد فایل failover.sh
cat > /opt/khalifeh/failover.sh << 'FAIL_EOF'
#!/bin/bash

BASE="/opt/khalifeh"

check_service() {
systemctl is-active $1 >/dev/null 2>&1
echo $?
}

start_rathole() {
systemctl start khalifeh-rathole-server >/dev/null 2>&1
systemctl start khalifeh-rathole-client >/dev/null 2>&1
echo "[+] Rathole ACTIVE"
}

start_frp() {
systemctl start frps >/dev/null 2>&1
systemctl start frpc >/dev/null 2>&1
echo "[+] FRP ACTIVE"
}

start_hysteria() {
systemctl start hysteria2 >/dev/null 2>&1
systemctl start hysteria2-client >/dev/null 2>&1
echo "[+] Hysteria2 ACTIVE"
}

stop_all() {
systemctl stop khalifeh-rathole-server >/dev/null 2>&1
systemctl stop khalifeh-rathole-client >/dev/null 2>&1
systemctl stop frps >/dev/null 2>&1
systemctl stop frpc >/dev/null 2>&1
systemctl stop hysteria2 >/dev/null 2>&1
systemctl stop hysteria2-client >/dev/null 2>&1
}

failover_loop() {
echo "[*] Starting Auto Failover Engine..."
echo "[*] Check interval: 5 seconds"
while true
do
check_service khalifeh-rathole-server
R1=$?
check_service khalifeh-rathole-client
R2=$?
if [[ $R1 -eq 0 || $R2 -eq 0 ]]; then
    echo "[$(date '+%H:%M:%S')] ✓ Rathole OK (PRIMARY)"
    sleep 5
    continue
fi
echo "[$(date '+%H:%M:%S')] ⚠ Rathole DOWN → switching to FRP"
check_service frps
F1=$?
check_service frpc
F2=$?
if [[ $F1 -eq 0 || $F2 -eq 0 ]]; then
    echo "[$(date '+%H:%M:%S')] ✓ FRP OK (FALLBACK)"
    sleep 5
    continue
fi
echo "[$(date '+%H:%M:%S')] ⚠ FRP DOWN → switching to Hysteria2"
check_service hysteria2
H1=$?
check_service hysteria2-client
H2=$?
if [[ $H1 -eq 0 || $H2 -eq 0 ]]; then
    echo "[$(date '+%H:%M:%S')] ✓ Hysteria2 OK (LAST RESORT)"
    sleep 5
    continue
fi
echo "[$(date '+%H:%M:%S')] ❌ ALL DOWN → restarting all services"
stop_all
sleep 2
start_rathole
sleep 1
start_frp
sleep 1
start_hysteria
sleep 10
done
}

failover_loop
FAIL_EOF

# ایجاد فایل‌های وب
cat > /opt/khalifeh/web/app.py << 'APP_EOF'
from flask import Flask, jsonify, render_template
import os
import subprocess

app = Flask(__name__)

SERVICES = [
    "khalifeh-rathole-server",
    "khalifeh-rathole-client",
    "frps",
    "frpc",
    "hysteria2",
    "hysteria2-client"
]

def get_status(name):
    try:
        output = subprocess.check_output(
            ["systemctl", "is-active", name],
            stderr=subprocess.STDOUT
        ).decode().strip()
        return output
    except:
        return "inactive"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/status")
def status():
    data = {}
    for s in SERVICES:
        data[s] = get_status(s)
    return jsonify(data)

@app.route("/api/start/<name>")
def start(name):
    os.system(f"systemctl start {name}")
    return jsonify({"status": "started", "service": name})

@app.route("/api/stop/<name>")
def stop(name):
    os.system(f"systemctl stop {name}")
    return jsonify({"status": "stopped", "service": name})

@app.route("/api/restart/<name>")
def restart(name):
    os.system(f"systemctl restart {name}")
    return jsonify({"status": "restarted", "service": name})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
APP_EOF

cat > /opt/khalifeh/web/templates/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Khalifeh Tunnel Panel</title>
    <style>
        body { background:#111; color:#0f0; font-family:monospace; }
        .box { padding:10px; border:1px solid #0f0; margin:10px; }
        button { margin:3px; }
    </style>
</head>
<body>

<h2>🔥 Khalifeh Tunnel Control Panel</h2>

<div id="status"></div>

<script>
async function loadStatus() {
    let res = await fetch('/api/status');
    let data = await res.json();

    let html = "";

    for (let k in data) {
        html += `
        <div class="box">
            <b>${k}</b> : ${data[k]}
            <br>
            <button onclick="fetch('/api/start/${k}')">Start</button>
            <button onclick="fetch('/api/stop/${k}')">Stop</button>
            <button onclick="fetch('/api/restart/${k}')">Restart</button>
        </div>`;
    }

    document.getElementById("status").innerHTML = html;
}

setInterval(loadStatus, 3000);
loadStatus();
</script>

</body>
</html>
HTML_EOF

# اجرایی کردن فایل‌ها
chmod +x /opt/khalifeh/modules/*.sh
chmod +x /opt/khalifeh/failover.sh

# ایجاد لانچر
cat > /usr/local/bin/khalifeh << 'LAUNCHER_EOF'
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
LAUNCHER_EOF

chmod +x /usr/local/bin/khalifeh

# ایجاد سرویس‌ها
cat > /etc/systemd/system/khalifeh-failover.service << 'SVC1_EOF'
[Unit]
Description=Khalifeh Failover Engine
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/khalifeh/failover.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC1_EOF

cat > /etc/systemd/system/khalifeh-web.service << 'SVC2_EOF'
[Unit]
Description=Khalifeh Web Panel
After=network.target

[Service]
ExecStart=python3 /opt/khalifeh/web/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SVC2_EOF

systemctl daemon-reload

echo ""
echo "[+] Khalifeh Tunnel v2 installed successfully!"
echo ""
echo "Commands:"
echo "  khalifeh                    -> Run CLI Menu"
echo "  systemctl start khalifeh-failover  -> Start Auto Failover"
echo "  systemctl start khalifeh-web       -> Start Web Panel (port 5000)"