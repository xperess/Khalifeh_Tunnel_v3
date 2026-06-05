#!/bin/bash

# ============================================
# تانل خلیفه - Khalifeh Tunnel Manager
# مدیریت تونل Rathole برای اتصال ایران به خارج
# مناسب برای استفاده با 3x-ui و Xray
# ============================================
# Repository: https://github.com/xperee/khalifeh-tunnel
# Version: 1.0.0
# License: MIT
# ============================================

set -e

# ==================== تنظیمات رنگ‌ها ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[0;37m'
NC='\033[0m'

# ==================== مسیرها ====================
CONFIG_DIR="/root/khalifeh-tunnel"
SERVICE_DIR="/etc/systemd/system"
LOG_DIR="/var/log/khalifeh"
SCRIPT_PATH="/usr/local/bin/khalifeh"

# ==================== تنظیمات ====================
VERSION="1.0.0"
GITHUB_REPO="xperee/khalifeh-tunnel"
GITHUB_RAW="https://raw.githubusercontent.com/xperee/khalifeh-tunnel/main"

# ==================== توابع کمکی ====================
print_color() {
    echo -e "${1}${2}${NC}"
}

print_success() {
    print_color "$GREEN" "✓ $1"
}

print_error() {
    print_color "$RED" "✗ $1"
}

print_info() {
    print_color "$CYAN" "ℹ $1"
}

print_warning() {
    print_color "$YELLOW" "⚠ $1"
}

print_header() {
    echo
    print_color "$MAGENTA" "═══════════════════════════════════════════════════════════"
    print_color "$WHITE" "  $1"
    print_color "$MAGENTA" "═══════════════════════════════════════════════════════════"
    echo
}

press_key() {
    read -p "Press Enter to continue..."
}

# ==================== بررسی دسترسی روت ====================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Please run: sudo khalifeh"
        exit 1
    fi
}

# ==================== تشخیص IP سرور ====================
detect_server_ip() {
    local ipv4=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null || curl -4 -s --max-time 3 ipinfo.io/ip 2>/dev/null)
    local ipv6=$(curl -6 -s --max-time 3 ifconfig.me 2>/dev/null)
    
    if [[ -n "$ipv4" ]]; then
        echo "$ipv4"
    elif [[ -n "$ipv6" ]]; then
        echo "$ipv6"
    else
        echo "unknown"
    fi
}

# ==================== تشخیص لوکیشن سرور ====================
detect_server_location() {
    local ip=$(detect_server_ip)
    if [[ "$ip" != "unknown" ]]; then
        local location=$(curl -s --max-time 3 "http://ip-api.com/json/$ip" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        echo "${location:-Unknown}"
    else
        echo "Unknown"
    fi
}

# ==================== نصب وابستگی‌ها ====================
install_dependencies() {
    print_header "نصب وابستگی‌های مورد نیاز"
    
    local deps=("unzip" "jq" "curl" "openssl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_info "در حال نصب: ${missing[*]}"
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y -qq "${missing[@]}"
        elif command -v yum &> /dev/null; then
            yum install -y -q "${missing[@]}"
        elif command -v dnf &> /dev/null; then
            dnf install -y -q "${missing[@]}"
        else
            print_error "مدیریت بسته پشتیبانی نمی‌شود. لطفاً دستی نصب کنید: ${missing[*]}"
            exit 1
        fi
        print_success "وابستگی‌ها نصب شدند"
    else
        print_success "تمام وابستگی‌ها قبلاً نصب شده‌اند"
    fi
}

# ==================== نصب Rathole ====================
install_rathole() {
    print_header "نصب هسته Rathole"
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    local arch=$(uname -m)
    local rathole_path="$CONFIG_DIR/rathole"
    
    if [[ -f "$rathole_path" ]] && [[ "$1" != "force" ]]; then
        print_warning "Rathole قبلاً نصب شده است"
        return 0
    fi
    
    # تعیین معماری
    case "$arch" in
        x86_64)  local rathole_arch="x86_64" ;;
        aarch64) local rathole_arch="aarch64" ;;
        armv7l)  local rathole_arch="armv7" ;;
        *) print_error "معماری پشتیبانی نمی‌شود: $arch"; return 1 ;;
    esac
    
    # دریافت آخرین نسخه از گیتهاب رسمی
    print_info "دریافت آخرین نسخه Rathole..."
    local latest_url=$(curl -s https://api.github.com/repos/rapiz1/rathole/releases/latest | grep -o "https://.*rathole-.*-${rathole_arch}-unknown-linux-gnu.zip" | head -1)
    
    if [[ -z "$latest_url" ]]; then
        print_error "خطا در دریافت آدرس دانلود"
        return 1
    fi
    
    print_info "دانلود از: $latest_url"
    
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    curl -sSL -o rathole.zip "$latest_url"
    unzip -q rathole.zip
    cp rathole "$rathole_path"
    chmod +x "$rathole_path"
    
    cd - > /dev/null
    rm -rf "$tmp_dir"
    
    print_success "Rathole با موفقیت نصب شد"
}

# ==================== تولید توکن تصادفی ====================
generate_token() {
    local token=""
    while [[ -z "$token" ]]; do
        echo -ne "توکن امنیتی (Enter برای تولید تصادفی): "
        read -r token
        if [[ -z "$token" ]]; then
            token=$(openssl rand -hex 16)
            print_info "توکن تولید شده: $token"
        fi
        if [[ ${#token} -lt 8 ]]; then
            print_error "توکن باید حداقل 8 کاراکتر باشد"
            token=""
        fi
    done
    echo "$token"
}

# ==================== بررسی پورت در حال استفاده ====================
check_port() {
    local port=$1
    local proto=${2:-tcp}
    
    if [[ "$proto" == "tcp" ]]; then
        ss -tlnp "sport = :$port" 2>/dev/null | grep -q ":$port"
    else
        ss -ulnp "sport = :$port" 2>/dev/null | grep -q ":$port"
    fi
}

# ==================== پیکربندی سرور ایران ====================
configure_iran() {
    print_header "پیکربندی سرور ایران (سمت شنونده)"
    
    # دریافت آدرس bind
    local bind_addr="0.0.0.0"
    echo -ne "آیا روی IPv6 گوش داده شود؟ (y/n) [n]: "
    read -r use_ipv6
    if [[ "$use_ipv6" =~ ^[yY]$ ]]; then
        bind_addr="[::]"
        print_info "IPv6 فعال شد"
    else
        print_info "IPv4 فعال شد"
    fi
    
    # پورت تونل
    local tunnel_port=""
    while true; do
        echo -ne "پورت تونل [10000-65535]: "
        read -r tunnel_port
        if [[ "$tunnel_port" =~ ^[0-9]+$ ]] && [[ "$tunnel_port" -ge 10000 ]] && [[ "$tunnel_port" -le 65535 ]]; then
            if check_port "$tunnel_port" "tcp"; then
                print_error "پورت $tunnel_port در حال استفاده است"
            else
                break
            fi
        else
            print_error "پورت نامعتبر. از 10000 تا 65535 استفاده کنید"
        fi
    done
    
    # توکن
    local token=$(generate_token)
    
    # تنظیمات TCP_NODELAY
    local nodelay="true"
    echo -ne "TCP_NODELAY فعال باشد؟ (y/n) [y]: "
    read -r enable_nodelay
    if [[ "$enable_nodelay" =~ ^[nN]$ ]]; then
        nodelay="false"
    fi
    
    # Heartbeat
    local heartbeat=30
    echo -ne "Heartbeat فعال باشد؟ (y/n) [y]: "
    read -r enable_heartbeat
    if [[ "$enable_heartbeat" =~ ^[nN]$ ]]; then
        heartbeat=0
        print_info "Heartbeat غیرفعال شد"
    fi
    
    # پورت‌های سرویس
    local service_ports=()
    print_info "پورت‌هایی که باید فوروارد شوند را وارد کنید (مثال: 443,80,8080)"
    echo -ne "پورت‌ها: "
    read -r ports_input
    
    IFS=',' read -ra ports <<< "$ports_input"
    for port in "${ports[@]}"; do
        port=$(echo "$port" | xargs)
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
            service_ports+=("$port")
            print_success "پورت $port اضافه شد"
        else
            print_warning "پورت نامعتبر: $port - رد شد"
        fi
    done
    
    if [[ ${#service_ports[@]} -eq 0 ]]; then
        print_error "هیچ پورت معتبری وارد نشد"
        return 1
    fi
    
    # انتخاب پروتکل حمل و نقل
    local transport="tcp"
    echo -ne "پروتکل انتقال (tcp/udp) [tcp]: "
    read -r transport_input
    if [[ "$transport_input" == "udp" ]]; then
        transport="udp"
    fi
    
    # ایجاد فایل کانفیگ
    local config_file="$CONFIG_DIR/iran-${tunnel_port}.toml"
    
    cat > "$config_file" << EOF
[server]
bind_addr = "${bind_addr}:${tunnel_port}"
default_token = "${token}"
heartbeat_interval = ${heartbeat}

[server.transport]
type = "tcp"

[server.transport.tcp]
nodelay = ${nodelay}

EOF
    
    # افزودن پورت‌های سرویس
    for port in "${service_ports[@]}"; do
        cat >> "$config_file" << EOF

[server.services.${port}]
type = "${transport}"
bind_addr = "${bind_addr}:${port}"

EOF
    done
    
    print_success "کانفیگ ایجاد شد: $config_file"
    
    # ایجاد سرویس systemd
    local service_name="khalifeh-iran-${tunnel_port}"
    local service_file="$SERVICE_DIR/${service_name}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=Khalifeh Tunnel - Iran (Port: ${tunnel_port})
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=${CONFIG_DIR}/rathole ${config_file}
Restart=always
RestartSec=3
StartLimitInterval=0
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$service_name" > /dev/null 2>&1
    systemctl start "$service_name" > /dev/null 2>&1
    
    if systemctl is-active --quiet "$service_name"; then
        print_success "سرویس با موفقیت راه‌اندازی شد"
    else
        print_error "خطا در راه‌اندازی سرویس"
        journalctl -u "$service_name" -n 10 --no-pager
        return 1
    fi
    
    # نمایش اطلاعات نهایی
    print_header "پیکربندی سرور ایران با موفقیت انجام شد"
    echo -e "${CYAN}پورت تونل:${NC} $tunnel_port"
    echo -e "${CYAN}توکن:${NC} $token"
    echo -e "${CYAN}پورت‌های فوروارد شده:${NC} ${service_ports[*]}"
    echo
    print_warning "این اطلاعات را برای پیکربندی سرور خارج ذخیره کنید"
}

# ==================== پیکربندی سرور خارج ====================
configure_kharej() {
    print_header "پیکربندی سرور خارج (سمت کلاینت)"
    
    # دریافت اطلاعات سرور ایران
    local server_addr=""
    while true; do
        echo -ne "آدرس IP سرور ایران: "
        read -r server_addr
        if [[ -n "$server_addr" ]]; then
            break
        else
            print_error "آدرس IP نمی‌تواند خالی باشد"
        fi
    done
    
    local tunnel_port=""
    while true; do
        echo -ne "پورت تونل: "
        read -r tunnel_port
        if [[ "$tunnel_port" =~ ^[0-9]+$ ]] && [[ "$tunnel_port" -ge 10000 ]] && [[ "$tunnel_port" -le 65535 ]]; then
            break
        else
            print_error "پورت نامعتبر"
        fi
    done
    
    local token=""
    echo -ne "توکن امنیتی: "
    read -r token
    if [[ -z "$token" ]]; then
        print_error "توکن الزامی است"
        return 1
    fi
    
    local nodelay="true"
    echo -ne "TCP_NODELAY فعال باشد؟ (y/n) [y]: "
    read -r enable_nodelay
    if [[ "$enable_nodelay" =~ ^[nN]$ ]]; then
        nodelay="false"
    fi
    
    local heartbeat=40
    echo -ne "Heartbeat فعال باشد؟ (y/n) [y]: "
    read -r enable_heartbeat
    if [[ "$enable_heartbeat" =~ ^[nN]$ ]]; then
        heartbeat=0
    fi
    
    # پورت‌های محلی
    local local_ports=()
    print_info "پورت‌های محلی که باید فوروارد شوند را وارد کنید"
    echo -ne "پورت‌ها: "
    read -r ports_input
    
    IFS=',' read -ra ports <<< "$ports_input"
    for port in "${ports[@]}"; do
        port=$(echo "$port" | xargs)
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
            local_ports+=("$port")
            print_success "پورت $port اضافه شد"
        else
            print_warning "پورت نامعتبر: $port - رد شد"
        fi
    done
    
    if [[ ${#local_ports[@]} -eq 0 ]]; then
        print_error "هیچ پورت معتبری وارد نشد"
        return 1
    fi
    
    local transport="tcp"
    echo -ne "پروتکل انتقال (tcp/udp) [tcp]: "
    read -r transport_input
    if [[ "$transport_input" == "udp" ]]; then
        transport="udp"
    fi
    
    # تشخیص IP محلی برای bind
    local bind_addr="127.0.0.1"
    echo -ne "به همه اینترفیس‌ها متصل شود؟ (y/n) [n]: "
    read -r bind_all
    if [[ "$bind_all" =~ ^[yY]$ ]]; then
        bind_addr="0.0.0.0"
    fi
    
    # ایجاد فایل کانفیگ
    local config_file="$CONFIG_DIR/kharej-${tunnel_port}.toml"
    
    cat > "$config_file" << EOF
[client]
remote_addr = "${server_addr}:${tunnel_port}"
default_token = "${token}"
heartbeat_timeout = ${heartbeat}
retry_interval = 3

[client.transport]
type = "tcp"

[client.transport.tcp]
nodelay = ${nodelay}

EOF
    
    for port in "${local_ports[@]}"; do
        cat >> "$config_file" << EOF

[client.services.${port}]
type = "${transport}"
local_addr = "${bind_addr}:${port}"

EOF
    done
    
    print_success "کانفیگ ایجاد شد: $config_file"
    
    # ایجاد سرویس systemd
    local service_name="khalifeh-kharej-${tunnel_port}"
    local service_file="$SERVICE_DIR/${service_name}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=Khalifeh Tunnel - Kharej (Port: ${tunnel_port})
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=${CONFIG_DIR}/rathole ${config_file}
Restart=always
RestartSec=3
StartLimitInterval=0
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$service_name" > /dev/null 2>&1
    systemctl start "$service_name" > /dev/null 2>&1
    
    if systemctl is-active --quiet "$service_name"; then
        print_success "سرویس با موفقیت راه‌اندازی شد"
    else
        print_error "خطا در راه‌اندازی سرویس"
        journalctl -u "$service_name" -n 10 --no-pager
        return 1
    fi
    
    print_header "پیکربندی سرور خارج با موفقیت انجام شد"
    print_success "تونل اکنون فعال است"
}

# ==================== مدیریت سرویس‌ها ====================
manage_services() {
    print_header "مدیریت تونل‌ها"
    
    local services=()
    local index=1
    
    # جمع‌آوری سرویس‌ها
    for service in $(systemctl list-units --type=service --all | grep -o "khalifeh-[^[:space:]]*" | sort -u); do
        services+=("$service")
        local status=$(systemctl is-active "$service" 2>/dev/null)
        local color="$GREEN"
        [[ "$status" != "active" ]] && color="$RED"
        echo -e "$index) ${CYAN}$service${NC} - ${color}$status${NC}"
        ((index++))
    done
    
    if [[ ${#services[@]} -eq 0 ]]; then
        print_warning "هیچ تونلی پیدا نشد"
        press_key
        return
    fi
    
    echo
    echo "0) بازگشت به منوی اصلی"
    echo -n "انتخاب کنید: "
    read -r choice
    
    if [[ "$choice" -eq 0 ]] || [[ -z "$choice" ]]; then
        return
    fi
    
    if [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#services[@]} ]]; then
        local selected="${services[$((choice-1))]}"
        manage_single_service "$selected"
    else
        print_error "انتخاب نامعتبر"
    fi
}

# ==================== مدیریت سرویس تکی ====================
manage_single_service() {
    local service_name="$1"
    
    while true; do
        clear
        print_header "مدیریت: $service_name"
        
        local status=$(systemctl is-active "$service_name" 2>/dev/null)
        echo -e "وضعیت: ${GREEN}$status${NC}"
        echo
        echo "1) راه‌اندازی مجدد"
        echo "2) توقف سرویس"
        echo "3) شروع سرویس"
        echo "4) مشاهده لاگ (50 خط آخر)"
        echo "5) مشاهده لاگ زنده"
        echo "6) حذف تونل"
        echo "0) بازگشت"
        echo
        read -p "انتخاب: " choice
        
        case $choice in
            1)
                systemctl restart "$service_name"
                print_success "سرویس راه‌اندازی مجدد شد"
                sleep 1
                ;;
            2)
                systemctl stop "$service_name"
                print_success "سرویس متوقف شد"
                sleep 1
                ;;
            3)
                systemctl start "$service_name"
                print_success "سرویس شروع شد"
                sleep 1
                ;;
            4)
                journalctl -u "$service_name" -n 50 --no-pager
                press_key
                ;;
            5)
                journalctl -u "$service_name" -f
                ;;
            6)
                delete_tunnel "$service_name"
                break
                ;;
            0)
                break
                ;;
        esac
    done
}

# ==================== حذف تونل ====================
delete_tunnel() {
    local service_name="$1"
    
    print_warning "آیا از حذف تونل $service_name اطمینان دارید؟"
    read -p "تأیید (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        print_info "انصراف شد"
        return
    fi
    
    # توقف و حذف سرویس
    systemctl stop "$service_name" > /dev/null 2>&1
    systemctl disable "$service_name" > /dev/null 2>&1
    rm -f "$SERVICE_DIR/${service_name}.service"
    
    # حذف فایل کانفیگ
    local tunnel_port=$(echo "$service_name" | grep -o '[0-9]*$')
    rm -f "$CONFIG_DIR/iran-${tunnel_port}.toml" 2>/dev/null
    rm -f "$CONFIG_DIR/kharej-${tunnel_port}.toml" 2>/dev/null
    
    systemctl daemon-reload
    
    print_success "تونل حذف شد"
    sleep 1
}

# ==================== بررسی وضعیت همه تونل‌ها ====================
check_status() {
    print_header "وضعیت تونل‌ها"
    
    local has_tunnels=false
    
    for service in $(systemctl list-units --type=service --all | grep -o "khalifeh-[^[:space:]]*" | sort -u); do
        has_tunnels=true
        local status=$(systemctl is-active "$service" 2>/dev/null)
        local color="$GREEN"
        [[ "$status" != "active" ]] && color="$RED"
        
        local port=$(echo "$service" | grep -o '[0-9]*$')
        local type=$(echo "$service" | grep -o 'iran\|kharej')
        
        if [[ "$type" == "iran" ]]; then
            type_name="ایران"
        else
            type_name="خارج"
        fi
        
        echo -e "${CYAN}${type_name}${NC} - پورت: ${YELLOW}${port}${NC} : ${color}${status}${NC}"
    done
    
    if [[ "$has_tunnels" == "false" ]]; then
        print_warning "هیچ تونلی پیکربندی نشده است"
    fi
    
    echo
    press_key
}

# ==================== تست سلامت تونل ====================
test_tunnel() {
    print_header "تست سلامت تونل"
    
    local tested=false
    
    for service in $(systemctl list-units --type=service --all | grep -o "khalifeh-[^[:space:]]*" | sort -u); do
        local status=$(systemctl is-active "$service" 2>/dev/null)
        local port=$(echo "$service" | grep -o '[0-9]*$')
        local type=$(echo "$service" | grep -o 'iran\|kharej')
        
        if [[ "$type" == "iran" ]]; then
            type_name="ایران"
        else
            type_name="خارج"
        fi
        
        if [[ "$status" == "active" ]]; then
            tested=true
            print_success "${type_name} (پورت $port) - فعال"
            
            local last_log=$(journalctl -u "$service" -n 3 --no-pager 2>/dev/null | grep -E "connected|error|failed" | tail -1)
            if [[ -n "$last_log" ]]; then
                echo "  آخرین رویداد: $last_log"
            fi
        else
            print_error "${type_name} (پورت $port) - غیرفعال"
        fi
        echo
    done
    
    if [[ "$tested" == "false" ]]; then
        print_warning "هیچ تونلی پیکربندی نشده است"
    fi
    
    press_key
}

# ==================== بهینه‌سازی شبکه ====================
optimize_network() {
    print_header "بهینه‌سازی شبکه و سیستم"
    
    # پشتیبان‌گیری
    cp /etc/sysctl.conf /etc/sysctl.conf.bak 2>/dev/null
    print_success "پشتیبان تهیه شد: /etc/sysctl.conf.bak"
    
    # حذف تنظیمات قبلی مربوط به بهینه‌سازی
    sed -i '/# Khalifeh Tunnel Optimizations/,/# End Khalifeh/d' /etc/sysctl.conf 2>/dev/null
    
    # اعمال تنظیمات بهینه
    cat >> /etc/sysctl.conf << 'EOF'

# Khalifeh Tunnel Optimizations
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 16384 1048576 33554432
net.ipv4.tcp_wmem = 16384 1048576 33554432
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
vm.swappiness = 10
vm.vfs_cache_pressure = 250
# End Khalifeh
EOF
    
    sysctl -p > /dev/null 2>&1
    
    # تنظیمات محدودیت‌های سیستم
    if ! grep -q "# Khalifeh Limits" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf << 'EOF'

# Khalifeh Limits
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
    fi
    
    print_success "بهینه‌سازی شبکه اعمال شد"
    print_warning "برای اعمال کامل، ریبوت سرور توصیه می‌شود"
    
    echo -ne "آیا اکنون ریبوت شود؟ (y/n): "
    read -r reboot_now
    if [[ "$reboot_now" =~ ^[yY]$ ]]; then
        print_info "در حال ریبوت..."
        reboot
    fi
}

# ==================== بروزرسانی اسکریپت ====================
update_script() {
    print_header "بروزرسانی تانل خلیفه"
    
    print_info "دریافت آخرین نسخه..."
    
    if curl -sSL -o "$SCRIPT_PATH" "$GITHUB_RAW/khalifeh.sh"; then
        chmod +x "$SCRIPT_PATH"
        print_success "اسکریپت با موفقیت بروزرسانی شد"
        print_info "برای اجرا: khalifeh"
        exit 0
    else
        print_error "خطا در بروزرسانی"
        return 1
    fi
}

# ==================== حذف کامل ====================
remove_core() {
    print_header "حذف کامل تانل خلیفه"
    
    print_warning "این عمل تمام تونل‌ها و تنظیمات را حذف خواهد کرد"
    read -p "آیا اطمینان دارید؟ (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        print_info "انصراف شد"
        return
    fi
    
    # حذف همه سرویس‌ها
    for service in $(systemctl list-units --type=service --all | grep -o "khalifeh-[^[:space:]]*" | sort -u); do
        systemctl stop "$service" > /dev/null 2>&1
        systemctl disable "$service" > /dev/null 2>&1
        rm -f "$SERVICE_DIR/${service}.service"
    done
    
    systemctl daemon-reload
    
    # حذف فایل‌ها
    rm -rf "$CONFIG_DIR"
    rm -rf "$LOG_DIR"
    
    print_success "تانل خلیفه به طور کامل حذف شد"
    sleep 2
}

# ==================== نمایش لوگو ====================
show_logo() {
    clear
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
    echo -e "${GREEN}    تانل خلیفه - Khalifeh Tunnel Manager v${VERSION}${NC}"
    echo -e "${YELLOW}    راهکاری امن و سریع برای تونل‌زنی${NC}"
    echo -e "${CYAN}    github.com/xperee/khalifeh-tunnel${NC}"
    echo
}

# ==================== نمایش اطلاعات سرور ====================
show_server_info() {
    local ip=$(detect_server_ip)
    local location=$(detect_server_location)
    
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}آدرس IP سرور:${NC} $ip"
    echo -e "${CYAN}موقعیت مکانی:${NC} $location"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
    echo
}

# ==================== نمایش وضعیت Rathole ====================
show_rathole_status() {
    if [[ -f "$CONFIG_DIR/rathole" ]]; then
        echo -e "هسته Rathole: ${GREEN}نصب شده${NC}"
    else
        echo -e "هسته Rathole: ${RED}نصب نشده${NC}"
    fi
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
}

# ==================== منوی اصلی ====================
main_menu() {
    while true; do
        show_logo
        show_server_info
        show_rathole_status
        
        echo -e "${GREEN}1.${NC} پیکربندی سرور ایران (سمت شنونده)"
        echo -e "${GREEN}2.${NC} پیکربندی سرور خارج (سمت کلاینت)"
        echo -e "${CYAN}3.${NC} مدیریت تونل‌ها"
        echo -e "${CYAN}4.${NC} مشاهده وضعیت تونل‌ها"
        echo -e "${CYAN}5.${NC} تست سلامت تونل"
        echo -e "${YELLOW}6.${NC} بهینه‌سازی شبکه"
        echo -e "${YELLOW}7.${NC} نصب/نصب مجدد Rathole"
        echo -e "${BLUE}8.${NC} بروزرسانی اسکریپت"
        echo -e "${RED}9.${NC} حذف کامل تانل خلیفه"
        echo -e "${RED}0.${NC} خروج"
        echo
        
        read -p "انتخاب [0-9]: " choice
        
        case $choice in            1) configure_iran ;;
            2) configure_kharej ;;
            3) manage_services ;;
            4) check_status ;;
            5) test_tunnel ;;
            6) optimize_network ;;
            7) install_rathole "force" ;;
            8) update_script ;;
            9) remove_core ;;
            0) 
                print_info "خدانگهدار!"
                exit 0
                ;;
            *) print_error "انتخاب نامعتبر" ;;
        esac
        
        press_key
    done
}

# ==================== شروع اسکریپت ====================
main() {
    check_root
    install_dependencies
    install_rathole
    main_menu
}

main "$@"