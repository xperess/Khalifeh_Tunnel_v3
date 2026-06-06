#!/bin/bash

BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

if [[ -f "$MOD/rathole.sh" ]]; then
    source $MOD/rathole.sh
else
    echo "Warning: rathole.sh not found"
fi

if [[ -f "$MOD/frp.sh" ]]; then
    source $MOD/frp.sh
else
    echo "Warning: frp.sh not found"
fi

if [[ -f "$MOD/hysteria2.sh" ]]; then
    source $MOD/hysteria2.sh
else
    echo "Warning: hysteria2.sh not found"
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
        echo "Rathole module not loaded properly"
        read -p "Press Enter..."
    fi
    ;;
2)
    if declare -f frp_menu > /dev/null; then
        frp_menu
    else
        echo "FRP module not loaded properly"
        read -p "Press Enter..."
    fi
    ;;
3)
    if declare -f hysteria_menu > /dev/null; then
        hysteria_menu
    else
        echo "Hysteria2 module not loaded properly"
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