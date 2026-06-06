#!/bin/bash

set -e

BASE="/opt/khalifeh"

echo "=================================="
echo "  Installing Khalifeh Tunnel v2"
echo "=================================="

# ================================
# CREATE STRUCTURE
# ================================
mkdir -p $BASE/modules
mkdir -p $BASE/configs
mkdir -p $BASE/bin
mkdir -p $BASE/backup

# ================================
# PACKAGES
# ================================
apt update -y
apt install -y curl wget jq unzip openssl tar

# ================================
# DOWNLOAD MODULES PLACEHOLDER
# ================================
echo "[*] Preparing system structure..."

# core launcher
cat > /usr/local/bin/khalifeh <<EOF
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
EOF

chmod +x /usr/local/bin/khalifeh

# ================================
# PLACE CORE FILE
# ================================
cat > $BASE/core.sh <<'EOF'
# core will be injected later
EOF

# ================================
# CREATE SERVICE WRAPPER (optional auto start)
# ================================
cat > /etc/systemd/system/khalifeh.service <<EOF
[Unit]
Description=Khalifeh Tunnel Core
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/khalifeh
Restart=always
TTYPath=/dev/tty

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo ""
echo "[+] Base system installed"
echo ""
echo "Next step:"
echo "1) Run: khalifeh"
echo "2) Install Rathole or FRP from menu"
echo ""