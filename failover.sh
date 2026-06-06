#!/bin/bash

BASE="/opt/khalifeh"

# ================================
# CHECK SERVICE STATUS
# ================================
check_service() {
systemctl is-active $1 >/dev/null 2>&1
echo $?
}

# ================================
# START SERVICES
# ================================
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

# ================================
# STOP ALL
# ================================
stop_all() {
systemctl stop khalifeh-rathole-server >/dev/null 2>&1
systemctl stop khalifeh-rathole-client >/dev/null 2>&1
systemctl stop frps >/dev/null 2>&1
systemctl stop frpc >/dev/null 2>&1
systemctl stop hysteria2 >/dev/null 2>&1
systemctl stop hysteria2-client >/dev/null 2>&1
}

# ================================
# MAIN LOOP
# ================================
failover_loop() {

echo "[*] Starting Auto Failover Engine..."

while true
do

# ================= RATHOLE =================
check_service khalifeh-rathole-server
R1=$?

check_service khalifeh-rathole-client
R2=$?

if [[ $R1 -eq 0 || $R2 -eq 0 ]]; then
    echo "[✓] Rathole OK (PRIMARY)"
    sleep 10
    continue
fi

echo "[!] Rathole DOWN → switching to FRP"

# ================= FRP =================
check_service frps
F1=$?

check_service frpc
F2=$?

if [[ $F1 -eq 0 || $F2 -eq 0 ]]; then
    echo "[✓] FRP OK (FALLBACK)"
    sleep 10
    continue
fi

echo "[!] FRP DOWN → switching to Hysteria2"

# ================= HYSTERIA =================
check_service hysteria2
H1=$?

check_service hysteria2-client
H2=$?

if [[ $H1 -eq 0 || $H2 -eq 0 ]]; then
    echo "[✓] Hysteria2 OK (LAST RESORT)"
    sleep 10
    continue
fi

echo "[!!!] ALL DOWN → restarting stack"

stop_all
sleep 2

start_rathole
start_frp
start_hysteria

sleep 10

done

}