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