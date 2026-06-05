#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
    ██╗  ██╗██╗  ██╗ █████╗ ██╗     ██╗███████╗███████╗██╗  ██╗
    ██║ ██╔╝██║  ██║██╔══██╗██║     ██║██╔════╝██╔════╝██║  ██║
    █████╔╝ ███████║███████║██║     ██║█████╗  █████╗  ███████║
    ██╔═██╗ ██╔══██║██╔══██║██║     ██║██╔══╝  ██╔══╝  ██╔══██║
    ██║  ██╗██║  ██║██║  ██║███████╗██║██║     ███████╗██║  ██║
    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝
EOF
echo -e "${NC}"
echo -e "${GREEN}نصب تانل خلیفه${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}این اسکریپت باید با دسترسی روت اجرا شود${NC}"
    exit 1
fi

echo -e "${YELLOW}در حال دانلود اسکریپت اصلی...${NC}"

# تلاش با چندین منبع مختلف
if curl -sSL -o /usr/local/bin/khalifeh https://raw.githubusercontent.com/xperess/Khalifeh_Tunnel_v3/main/khalifeh.sh 2>/dev/null; then
    chmod +x /usr/local/bin/khalifeh
elif curl -sSL -o /usr/local/bin/khalifeh https://gh-proxy.com/raw.githubusercontent.com/xperess/Khalifeh_Tunnel_v3/main/khalifeh.sh 2>/dev/null; then
    chmod +x /usr/local/bin/khalifeh
elif curl -sSL -o /usr/local/bin/khalifeh https://ghproxy.net/raw.githubusercontent.com/xperess/Khalifeh_Tunnel_v3/main/khalifeh.sh 2>/dev/null; then
    chmod +x /usr/local/bin/khalifeh
else
    echo -e "${RED}خطا در دانلود. لطفاً دستی نصب کنید${NC}"
    exit 1
fi

echo -e "${GREEN}✅ تانل خلیفه با موفقیت نصب شد${NC}"
echo ""
echo -e "${CYAN}برای اجرا:${NC} ${YELLOW}khalifeh${NC}"
