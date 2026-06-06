#!/bin/bash

BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

# ================================
# LOAD MODULES
# ================================
source $MOD/rathole.sh
source $MOD/frp.sh

# ================================
# COLORS
# ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ================================
# HEADER
# ================================
banner() {
clear
echo -e "${CYAN}"
echo "======================================"
echo "   KHALIFEH TUNNEL v2 (PRO CORE)"
echo "======================================"
echo -e "${NC}"
}

# ================================
# STATUS OVERVIEW
# ================================
status_all() {

echo -e "${GREEN}=== RATHOLE ===${NC}"
systemctl status khalifeh-rathole-server --no-pager 2>/dev/null || true
systemctl status khalifeh-rathole-client --no-pager 2>/dev/null || true

echo ""
echo -e "${YELLOW}=== FRP ===${NC}"
systemctl status frps --no-pager 2>/dev/null || true
systemctl status frpc --no-pager 2>/dev/null || true

echo ""
read -p "Press Enter..."
}

# ================================
# NETWORK OPTIMIZATION
# ================================
optimize_network() {

echo "[*] Applying network optimizations..."

cat >> /etc/sysctl.conf <<EOF

# KHALIFEH OPTIMIZATION
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl -p >/dev/null 2>&1

echo "[+] Network optimized"
read -p "Press Enter..."
}

# ================================
# BACKUP
# ================================
backup() {

TS=$(date +%Y%m%d_%H%M%S)
BK="/opt/khalifeh/backup_$TS.tar.gz"

tar -czf $BK $BASE

echo "[+] Backup created: $BK"
read -p "Press Enter..."
}

# ================================
# RESTORE
# ================================
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

# ================================
# HEALTH CHECK
# ================================
health() {

echo "[*] Checking services..."

for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc
do
    STATUS=$(systemctl is-active $svc 2>/dev/null)
    
    if [[ "$STATUS" == "active" ]]; then
        echo -e "$svc : ${GREEN}OK${NC}"
    else
        echo -e "$svc : ${RED}DOWN${NC}"
    fi
done

read -p "Press Enter..."
}

# ================================
# MAIN MENU
# ================================
main_menu() {

while true
do
banner

echo "1) Rathole Module"
echo "2) FRP Module"
echo "3) Status All"
echo "4) Health Check"
echo "5) Network Optimize"
echo "6) Backup"
echo "7) Restore"
echo "0) Exit"

read -p "Select: " c

case $c in

1) rathole_menu ;;
2) frp_menu ;;
3) status_all ;;
4) health ;;
5) optimize_network ;;
6) backup ;;
7) restore ;;
0) exit 0 ;;

esac

done

}