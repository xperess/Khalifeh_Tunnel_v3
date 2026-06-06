#!/bin/bash

set -e

BASE="/opt/khalifeh"

echo "=================================="
echo "  Installing Khalifeh Tunnel v2"
echo "=================================="

# ایجاد ساختار
mkdir -p $BASE/modules
mkdir -p $BASE/configs
mkdir -p $BASE/bin
mkdir -p $BASE/backup
mkdir -p $BASE/web/templates

# نصب پکیج‌ها
apt update -y
apt install -y curl wget jq unzip openssl
apt install -y python3-flask || apt install -y flask

# ایجاد فایل core.sh
cat > $BASE/core.sh << 'CORE_EOF'
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

# دانلود ماژول‌ها
echo "[*] Downloading modules..."
GITHUB_BASE="https://raw.githubusercontent.com/xperess/Khalifeh_Tunnel_v3/main"

curl -sSL "$GITHUB_BASE/rathole.sh" -o $BASE/modules/rathole.sh
curl -sSL "$GITHUB_BASE/frp.sh" -o $BASE/modules/frp.sh
curl -sSL "$GITHUB_BASE/hysteria2.sh" -o $BASE/modules/hysteria2.sh
curl -sSL "$GITHUB_BASE/failover.sh" -o $BASE/failover.sh
curl -sSL "$GITHUB_BASE/app.py" -o $BASE/web/app.py
curl -sSL "$GITHUB_BASE/index.html" -o $BASE/web/templates/index.html

chmod +x $BASE/modules/*.sh
chmod +x $BASE/failover.sh

# ایجاد لانچر
cat > /usr/local/bin/khalifeh << 'KHALIFEH_EOF'
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
KHALIFEH_EOF

chmod +x /usr/local/bin/khalifeh

# ایجاد سرویس failover
cat > /etc/systemd/system/khalifeh-failover.service << FAILOVER_EOF
[Unit]
Description=Khalifeh Failover Engine
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $BASE/failover.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
FAILOVER_EOF

# ایجاد سرویس وب
cat > /etc/systemd/system/khalifeh-web.service << WEB_EOF
[Unit]
Description=Khalifeh Web Panel
After=network.target

[Service]
ExecStart=python3 $BASE/web/app.py
Restart=always

[Install]
WantedBy=multi-user.target
WEB_EOF

systemctl daemon-reload

echo ""
echo "[+] Khalifeh Tunnel v2 installed successfully!"
echo ""
echo "Commands:"
echo "  khalifeh                    -> Run CLI Menu"
echo "  systemctl start khalifeh-failover  -> Start Auto Failover"
echo "  systemctl start khalifeh-web       -> Start Web Panel (port 5000)"
echo ""
