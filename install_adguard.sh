#!/bin/bash
################################################################################
# AdGuard Home Installation Script - Professional Edition
# Author: Ibrahim Aljuhani
# Version: 1.0.0
# Supports: Ubuntu 22.04+
# Architecture: Configuration-First Pattern (Gather → Validate → Execute)
# Modes: Interactive | Non-Interactive | Dry-Run
################################################################################
set -e
export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────────────────────────────────────────────────────
#  Color Definitions
# ─────────────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

print_info()      { echo -e "${GREEN}[✔ DONE ]${NC} $1"; }
print_warn()      { echo -e "${YELLOW}[⚠ WARN ]${NC} $1"; }
print_error()     { echo -e "${RED}[✖ ERROR]${NC} $1"; exit 1; }
print_step()      { echo -e "${CYAN}[  ==>  ]${NC} $1"; }
print_danger()    { echo -e "${RED}[🔥 WARN ]${NC} $1"; }
print_security()  { echo -e "${PURPLE}[🔒 SEC  ]${NC} $1"; }

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║          AdGuard Home Installer - Professional Edition          ║"
    echo "║                        Version 1.0.0                            ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_divider() {
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
}

print_section() {
    echo ""
    echo -e "${BOLD}${CYAN}▶ $1${NC}"
    print_divider
}

# ─────────────────────────────────────────────────────────────────────────────
#  Global Configuration
# ─────────────────────────────────────────────────────────────────────────────
CONFIG_MODE="interactive"    # interactive | non-interactive | dry-run
DRY_RUN=false

AG_INSTALL_DIR="/opt/AdGuardHome"
AG_DATA_DIR="/var/lib/AdGuardHome"
AG_LOG_DIR="/var/log/AdGuardHome"
AG_USER="adguardhome"
AG_WEB_PORT="3000"           # Initial setup port
AG_DNS_PORT="53"
AG_HTTP_PORT="80"
AG_HTTPS_PORT="443"
NGINX_CHOICE="n"
NGINX_DOMAIN=""
SSL_CHOICE="n"
LETSENCRYPT_EMAIL=""
AG_ADMIN_USER=""
AG_ADMIN_PASSWORD=""

SERVER_IP=$(hostname -I | awk '{print $1}')
SECRETS_FILE="/root/adguard-secrets.txt"
MANIFEST_DIR="/root/adguard-installs"

# ─────────────────────────────────────────────────────────────────────────────
#  Validation Helpers
# ─────────────────────────────────────────────────────────────────────────────
check_adguard_installed() {
    [ -f "$AG_INSTALL_DIR/AdGuardHome" ] && return 0
    systemctl list-unit-files --type=service 2>/dev/null | grep -q "^AdGuardHome\.service" && return 0
    return 1
}

check_port_in_use() {
    local port="$1"
    ss -tuln 2>/dev/null | grep -q ":$port\b" && return 0
    return 1
}

validate_port_range() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

validate_email() {
    [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

generate_random_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 20
}

# ─────────────────────────────────────────────────────────────────────────────
#  CLI Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --non-interactive)  CONFIG_MODE="non-interactive"; shift ;;
            --dry-run)          DRY_RUN=true; CONFIG_MODE="non-interactive"; shift ;;
            --web-port)         AG_WEB_PORT="$2"; shift 2 ;;
            --dns-port)         AG_DNS_PORT="$2"; shift 2 ;;
            --nginx)            NGINX_CHOICE="y"; shift ;;
            --domain)           NGINX_DOMAIN="$2"; shift 2 ;;
            --ssl)              SSL_CHOICE="y"; shift ;;
            --email)            LETSENCRYPT_EMAIL="$2"; shift 2 ;;
            --admin-user)       AG_ADMIN_USER="$2"; shift 2 ;;
            --help|-h)          show_help; exit 0 ;;
            *)                  shift ;;
        esac
    done
}

show_help() {
    print_banner
    echo -e "${BOLD}Usage:${NC}"
    echo ""
    echo "  Interactive (default):"
    echo "    sudo ./install_adguard.sh"
    echo ""
    echo "  Non-Interactive:"
    echo "    sudo ./install_adguard.sh --non-interactive \\"
    echo "      --web-port <port> --dns-port <port> \\"
    echo "      [--nginx] [--domain <domain>] [--ssl] [--email <email>]"
    echo ""
    echo "  Dry-Run (simulate only):"
    echo "    sudo ./install_adguard.sh --dry-run"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    printf "  %-20s %s\n" "--web-port"    "Web UI / initial setup port (default: 3000)"
    printf "  %-20s %s\n" "--dns-port"    "DNS listening port (default: 53)"
    printf "  %-20s %s\n" "--nginx"       "Enable Nginx reverse proxy for Web UI"
    printf "  %-20s %s\n" "--domain"      "Domain name for Nginx"
    printf "  %-20s %s\n" "--ssl"         "Enable Let's Encrypt SSL"
    printf "  %-20s %s\n" "--email"       "Email for SSL notifications"
    printf "  %-20s %s\n" "--admin-user"  "Admin username (default: admin)"
    printf "  %-20s %s\n" "--dry-run"     "Simulate without making changes"
    printf "  %-20s %s\n" "--help, -h"    "Show this help message"
}

# ─────────────────────────────────────────────────────────────────────────────
#  Dry-Run Executor
# ─────────────────────────────────────────────────────────────────────────────
execute_step() {
    local DESC="$1"
    local FUNC="$2"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would execute: $DESC"
        return 0
    fi
    print_step "$DESC..."
    $FUNC
    print_info "$DESC"
}

# ─────────────────────────────────────────────────────────────────────────────
#  Phase 1: Handle Existing Installation
# ─────────────────────────────────────────────────────────────────────────────
handle_existing_installation() {
    echo -e "${RED}"
    echo "  ┌─────────────────────────────────────────────────────────┐"
    echo "  │  ⚠  WARNING: AdGuard Home is already installed!         │"
    echo "  │     Proceeding will remove the existing installation.   │"
    echo "  └─────────────────────────────────────────────────────────┘"
    echo -e "${NC}"

    read -p "  Do you want to REMOVE the existing installation and reinstall? (y/N): " REINSTALL_CHOICE
    [[ ! "$(echo "$REINSTALL_CHOICE" | tr '[:upper:]' '[:lower:]')" =~ ^(y|yes)$ ]] && \
        print_error "Installation aborted by user."

    read -p "  Create a backup of current config before removal? (y/N): " BACKUP_CHOICE
    if [[ "$(echo "$BACKUP_CHOICE" | tr '[:upper:]' '[:lower:]')" =~ ^(y|yes)$ ]]; then
        local BACKUP_FILE="/root/adguard_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        print_step "Creating backup: $BACKUP_FILE"
        tar -czf "$BACKUP_FILE" \
            "$AG_INSTALL_DIR" \
            "$AG_DATA_DIR" \
            "$AG_LOG_DIR" 2>/dev/null || true
        print_info "Backup saved: $BACKUP_FILE"
    fi

    print_step "Stopping and removing existing AdGuard Home..."
    systemctl stop AdGuardHome  2>/dev/null || true
    systemctl disable AdGuardHome 2>/dev/null || true
    "$AG_INSTALL_DIR/AdGuardHome" -s uninstall 2>/dev/null || true
    rm -rf "$AG_INSTALL_DIR" "$AG_DATA_DIR" "$AG_LOG_DIR"
    userdel -r "$AG_USER" 2>/dev/null || true
    rm -f /etc/systemd/system/AdGuardHome.service
    rm -f /etc/nginx/sites-enabled/adguardhome
    rm -f /etc/nginx/sites-available/adguardhome
    rm -f /etc/nginx/snippets/adguard-security-headers.conf
    nginx -t && systemctl reload nginx 2>/dev/null || true
    systemctl daemon-reload
    print_info "Existing installation removed."
}

# ─────────────────────────────────────────────────────────────────────────────
#  Phase 2: Gather Inputs
# ─────────────────────────────────────────────────────────────────────────────
gather_inputs() {
    print_banner

    print_section "Configuration"

    # Admin username
    echo -e "${BOLD}  Admin Username${NC} (default: admin):"
    read -p "  > " INPUT_ADMIN_USER
    AG_ADMIN_USER="${INPUT_ADMIN_USER:-admin}"

    # Admin password
    echo ""
    echo -e "${BOLD}  Admin Password${NC} (leave blank to auto-generate):"
    read -s -p "  > " INPUT_PASS; echo
    if [[ -z "$INPUT_PASS" ]]; then
        AG_ADMIN_PASSWORD=$(generate_random_password)
        print_warn "Auto-generated password will be shown at the end."
    else
        AG_ADMIN_PASSWORD="$INPUT_PASS"
    fi

    # Web UI port
    echo ""
    echo -e "${BOLD}  Web UI Port${NC} (default: 3000):"
    read -p "  > " INPUT_WEB_PORT
    AG_WEB_PORT="${INPUT_WEB_PORT:-3000}"
    validate_port_range "$AG_WEB_PORT" || print_error "Invalid port: $AG_WEB_PORT"

    # DNS port
    echo ""
    echo -e "${BOLD}  DNS Port${NC} (default: 53 — requires root):"
    read -p "  > " INPUT_DNS_PORT
    AG_DNS_PORT="${INPUT_DNS_PORT:-53}"
    validate_port_range "$AG_DNS_PORT" || print_error "Invalid port: $AG_DNS_PORT"

    # Nginx
    echo ""
    echo -e "${BOLD}  Install Nginx reverse proxy for Web UI?${NC} (y/N):"
    read -p "  > " NGINX_CHOICE
    NGINX_CHOICE=$(echo "${NGINX_CHOICE:-n}" | tr '[:upper:]' '[:lower:]')

    if [[ "$NGINX_CHOICE" =~ ^(y|yes)$ ]]; then
        echo ""
        echo -e "${BOLD}  Domain name for Nginx${NC} (e.g., adguard.example.com):"
        read -p "  > " NGINX_DOMAIN
        [[ -z "$NGINX_DOMAIN" ]] && print_error "Domain cannot be empty when Nginx is selected."

        echo ""
        echo -e "${BOLD}  Enable Let's Encrypt SSL for $NGINX_DOMAIN?${NC} (y/N):"
        read -p "  > " SSL_CHOICE
        SSL_CHOICE=$(echo "${SSL_CHOICE:-n}" | tr '[:upper:]' '[:lower:]')

        if [[ "$SSL_CHOICE" =~ ^(y|yes)$ ]]; then
            echo ""
            echo -e "${BOLD}  Email for Let's Encrypt notifications:${NC}"
            read -p "  > " LETSENCRYPT_EMAIL
            validate_email "$LETSENCRYPT_EMAIL" || print_error "Invalid email: $LETSENCRYPT_EMAIL"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  Validate Configuration
# ─────────────────────────────────────────────────────────────────────────────
validate_configuration() {
    print_section "Validating Configuration"

    check_port_in_use "$AG_WEB_PORT" && print_warn "Port $AG_WEB_PORT is already in use — may conflict."
    check_port_in_use "$AG_DNS_PORT" && print_warn "Port $AG_DNS_PORT is already in use — DNS conflict possible."

    if check_adguard_installed; then
        [[ "$CONFIG_MODE" == "non-interactive" ]] && \
            print_error "AdGuard Home already installed. Run interactively to reinstall."
        handle_existing_installation
    fi

    print_info "Configuration validated."
}

# ─────────────────────────────────────────────────────────────────────────────
#  Installation Steps
# ─────────────────────────────────────────────────────────────────────────────
step_check_tools() {
    local TOOLS=(curl wget tar systemctl ss)
    for tool in "${TOOLS[@]}"; do
        command -v "$tool" &>/dev/null || print_error "Required tool not found: $tool"
    done
}

step_check_ubuntu() {
    local OS_ID OS_VERSION_ID
    if [ -f /etc/os-release ]; then
        OS_ID=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "unknown")
        OS_VERSION_ID=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "0")
    else
        OS_ID="unknown"
        OS_VERSION_ID="0"
    fi

    if [[ "$OS_ID" != "ubuntu" ]]; then
        print_warn "This script is tested on Ubuntu. Detected: ${OS_ID}. Proceeding anyway..."
    else
        print_info "Detected Ubuntu ${OS_VERSION_ID} — supported."
    fi
}

step_update_system() {
    apt-get update -qq
    apt-get upgrade -y -qq
}

step_install_packages() {
    apt-get install -y -qq \
        curl wget tar gzip \
        ca-certificates \
        net-tools ufw \
        nginx certbot python3-certbot-nginx
}

step_disable_systemd_resolved() {
    # Port 53 may be occupied by systemd-resolved
    if ss -tuln | grep -q ":53\b"; then
        print_warn "Port 53 is in use. Disabling systemd-resolved stub listener..."
        local RESOLVED_CONF="/etc/systemd/resolved.conf"
        # Remove any existing DNSStubListener line (commented or not), then append correct value
        sed -i '/^#*DNSStubListener/d' "$RESOLVED_CONF" || true
        echo "DNSStubListener=no" >> "$RESOLVED_CONF"
        systemctl restart systemd-resolved || true
        sleep 1
        print_info "systemd-resolved stub listener disabled."
    else
        print_info "Port 53 is free — no action needed."
    fi
}

step_create_user() {
    if ! id "$AG_USER" &>/dev/null; then
        useradd --system --no-create-home --shell /usr/sbin/nologin "$AG_USER"
        print_info "System user '$AG_USER' created."
    else
        print_warn "User '$AG_USER' already exists — skipping."
    fi
}

step_download_adguard() {
    local ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)           AG_ARCH="amd64" ;;
        aarch64|arm64)    AG_ARCH="arm64" ;;
        armv7l)           AG_ARCH="armv7" ;;
        *)                print_error "Unsupported architecture: $ARCH" ;;
    esac

    local DOWNLOAD_URL="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_${AG_ARCH}.tar.gz"
    local TMP_FILE="/tmp/adguardhome_linux_${AG_ARCH}.tar.gz"

    print_step "Downloading AdGuard Home (linux/$AG_ARCH)..."
    wget -q --show-progress -O "$TMP_FILE" "$DOWNLOAD_URL" || \
        print_error "Download failed. Check connectivity or URL: $DOWNLOAD_URL"

    print_step "Extracting to $AG_INSTALL_DIR..."
    mkdir -p "$AG_INSTALL_DIR"
    tar -xzf "$TMP_FILE" -C "$AG_INSTALL_DIR" --strip-components=2
    rm -f "$TMP_FILE"
    chmod +x "$AG_INSTALL_DIR/AdGuardHome"
    chown -R "$AG_USER:$AG_USER" "$AG_INSTALL_DIR"
    print_info "AdGuard Home binary installed."
}

step_create_directories() {
    mkdir -p "$AG_DATA_DIR" "$AG_LOG_DIR" "$AG_INSTALL_DIR"
    chown -R "$AG_USER:$AG_USER" "$AG_DATA_DIR" "$AG_LOG_DIR"
    print_info "Directories created."
}

step_write_config() {
    # Build a minimal YAML config so AdGuard starts without the initial wizard
    # Password is bcrypt-hashed; we store plain text in secrets file
    local HASHED_PASS
    # Use Python to bcrypt-hash the password if available
    if command -v python3 &>/dev/null && python3 -c "import bcrypt" 2>/dev/null; then
        HASHED_PASS=$(python3 -c "import bcrypt; print(bcrypt.hashpw('${AG_ADMIN_PASSWORD}'.encode(), bcrypt.gensalt()).decode())")
    else
        # Fallback: AdGuard also accepts SHA256 with $2y$ prefix via htpasswd
        apt-get install -y -qq apache2-utils 2>/dev/null || true
        HASHED_PASS=$(htpasswd -bnBC 10 "" "$AG_ADMIN_PASSWORD" | tr -d ':\n' | sed 's/^\$/\$2y\$/')
    fi

    cat > "$AG_INSTALL_DIR/AdGuardHome.yaml" <<EOF
http:
  pprof:
    port: 6060
    enabled: false
  address: 0.0.0.0:${AG_WEB_PORT}
  session_ttl: 720h
users:
  - name: ${AG_ADMIN_USER}
    password: "${HASHED_PASS}"
auth_attempts: 5
block_auth_min: 15
dns:
  bind_hosts:
    - 0.0.0.0
  port: ${AG_DNS_PORT}
  upstream_dns:
    - https://dns10.quad9.net/dns-query
    - https://dns.cloudflare.com/dns-query
    - https://dns.google/dns-query
  bootstrap_dns:
    - 9.9.9.10
    - 1.1.1.1
    - 8.8.8.8
  fallback_dns:
    - 8.8.8.8
    - 9.9.9.9
  use_private_ptr_resolvers: true
  resolve_clients: true
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  ratelimit: 20
  blocking_mode: default
  rewrites: []
  filters_update_interval: 24
  blocked_services:
    schedule:
      time_zone: UTC
    ids: []
filtering:
  protection_enabled: true
  filtering_enabled: true
  parental_enabled: false
  safe_search:
    enabled: false
  safe_browsing_enabled: false
  filters:
    - enabled: true
      url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
      name: AdGuard DNS filter
      id: 1
    - enabled: true
      url: https://adaway.org/hosts.txt
      name: AdAway Default Blocklist
      id: 2
    - enabled: true
      url: https://www.malwaredomainlist.com/hostslist/hosts.txt
      name: MalwareDomainList.com Hosts List
      id: 3
log:
  file: ${AG_LOG_DIR}/AdGuardHome.log
  max_backups: 3
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ${AG_USER}
  user: ${AG_USER}
  rlimit_nofile: 0
schema_version: 28
EOF

    chown "$AG_USER:$AG_USER" "$AG_INSTALL_DIR/AdGuardHome.yaml"
    chmod 640 "$AG_INSTALL_DIR/AdGuardHome.yaml"
}

step_install_service() {
    # Install AdGuard Home as a systemd service
    "$AG_INSTALL_DIR/AdGuardHome" -s install 2>/dev/null || true

    # Override the unit file to enforce user/group
    cat > /etc/systemd/system/AdGuardHome.service <<EOF
[Unit]
Description=AdGuard Home - DNS-level network protection
After=network.target

[Service]
Type=simple
User=${AG_USER}
Group=${AG_USER}
WorkingDirectory=${AG_INSTALL_DIR}
ExecStart=${AG_INSTALL_DIR}/AdGuardHome --config ${AG_INSTALL_DIR}/AdGuardHome.yaml --work-dir ${AG_DATA_DIR} --no-check-update
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # Grant AdGuardHome binary permission to bind port 53 without root
    setcap 'cap_net_bind_service=+eip' "$AG_INSTALL_DIR/AdGuardHome" || \
        print_warn "setcap failed — AdGuard may need root to bind port 53."

    systemctl daemon-reload
    systemctl enable AdGuardHome
}

step_start_service() {
    systemctl start AdGuardHome
    sleep 3
    systemctl is-active --quiet AdGuardHome && \
        print_info "AdGuard Home service is running." || \
        print_error "AdGuard Home failed to start. Check: journalctl -u AdGuardHome -n 50"
}

step_configure_ufw() {
    if command -v ufw &>/dev/null; then
        ufw allow "${AG_DNS_PORT}/tcp"  comment "AdGuard DNS TCP"  > /dev/null 2>&1 || true
        ufw allow "${AG_DNS_PORT}/udp"  comment "AdGuard DNS UDP"  > /dev/null 2>&1 || true
        ufw allow "${AG_WEB_PORT}/tcp"  comment "AdGuard Web UI"   > /dev/null 2>&1 || true
        ufw allow "80/tcp"              comment "HTTP"             > /dev/null 2>&1 || true
        ufw allow "443/tcp"             comment "HTTPS"            > /dev/null 2>&1 || true
        print_info "UFW rules applied."
    else
        print_warn "ufw not found — skipping firewall configuration."
    fi
}

step_configure_nginx() {
    AG_ACCESS_URL="https://${NGINX_DOMAIN}"

    # Disable default site
    rm -f /etc/nginx/sites-enabled/default

    # Create AdGuard Nginx config — HTTP only first so Certbot can validate
    # Certbot will modify this file to add SSL automatically
    cat > "/etc/nginx/sites-available/adguardhome" <<EOF
server {
    listen 80;
    server_name ${NGINX_DOMAIN};

    location / {
        proxy_pass         http://127.0.0.1:${AG_WEB_PORT};
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/adguardhome /etc/nginx/sites-enabled/adguardhome

    # Test and reload Nginx with the clean HTTP config
    nginx -t || print_error "Nginx config test failed. Check: nginx -t"
    systemctl reload nginx
    print_info "Nginx configured for $NGINX_DOMAIN (HTTP)."

    if [[ "$SSL_CHOICE" =~ ^(y|yes)$ ]]; then
        print_step "Obtaining Let's Encrypt certificate..."
        # --redirect tells Certbot to add the HTTPS redirect automatically
        certbot --nginx \
            -d "$NGINX_DOMAIN" \
            --non-interactive \
            --agree-tos \
            -m "$LETSENCRYPT_EMAIL" \
            --redirect \
            --keep-until-expiring \
            --allow-subset-of-names || {
                print_warn "Certbot failed — make sure $NGINX_DOMAIN points to this server's IP."
                print_warn "To retry manually: certbot --nginx -d $NGINX_DOMAIN -m $LETSENCRYPT_EMAIL --agree-tos --redirect"
                return 0
        }

        # Add security headers after Certbot modifies the config
        # Append them inside a new server block snippet
        cat > "/etc/nginx/snippets/adguard-security-headers.conf" <<'HEADERS'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
HEADERS

        # Include the snippet in the site config if not already there
        if ! grep -q "adguard-security-headers" /etc/nginx/sites-available/adguardhome; then
            sed -i '/server_name/a\    include snippets/adguard-security-headers.conf;' \
                /etc/nginx/sites-available/adguardhome
        fi

        nginx -t && systemctl reload nginx || true

        # Enable auto-renewal
        systemctl enable --now certbot.timer 2>/dev/null || \
            { crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'"; } | crontab -

        AG_ACCESS_URL="https://${NGINX_DOMAIN}"
        print_info "SSL certificate obtained and auto-renewal enabled."
    else
        AG_ACCESS_URL="http://${NGINX_DOMAIN}"
    fi
}

step_save_secrets() {
    cat > "$SECRETS_FILE" <<EOF
# AdGuard Home - Installation Secrets
# Generated: $(date -Iseconds)
# ─────────────────────────────────────
Admin Username : ${AG_ADMIN_USER}
Admin Password : ${AG_ADMIN_PASSWORD}
Web UI Port    : ${AG_WEB_PORT}
DNS Port       : ${AG_DNS_PORT}
Server IP      : ${SERVER_IP}
EOF
    chmod 600 "$SECRETS_FILE"
    print_info "Credentials saved to: $SECRETS_FILE"
}

step_generate_manifest() {
    mkdir -p "$MANIFEST_DIR"
    local MANIFEST_FILE="$MANIFEST_DIR/adguard_$(date +%Y%m%d_%H%M%S)_manifest.json"
    local NGINX_EN="false"; local SSL_EN="false"
    [[ "$NGINX_CHOICE" =~ ^(y|yes)$ ]] && NGINX_EN="true"
    [[ "$SSL_CHOICE"   =~ ^(y|yes)$ ]] && SSL_EN="true"

    cat > "$MANIFEST_FILE" <<EOF
{
  "application":      "AdGuard Home",
  "version":          "latest",
  "web_port":         ${AG_WEB_PORT},
  "dns_port":         ${AG_DNS_PORT},
  "install_dir":      "${AG_INSTALL_DIR}",
  "data_dir":         "${AG_DATA_DIR}",
  "nginx_enabled":    ${NGINX_EN},
  "domain":           "${NGINX_DOMAIN}",
  "ssl_enabled":      ${SSL_EN},
  "ssl_email":        "${LETSENCRYPT_EMAIL}",
  "server_ip":        "${SERVER_IP}",
  "installation_date":"$(date -Iseconds)"
}
EOF
    chmod 600 "$MANIFEST_FILE"
    print_info "Manifest saved: $MANIFEST_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
#  Phase 3: Execute Installation
# ─────────────────────────────────────────────────────────────────────────────
execute_installation() {
    local START_TIME
    START_TIME=$(date +%s)

    print_section "System Preparation"
    execute_step "Checking required tools"        step_check_tools
    execute_step "Checking OS"                    step_check_ubuntu
    execute_step "Updating system packages"       step_update_system
    execute_step "Installing dependencies"        step_install_packages
    execute_step "Freeing port 53 if needed"      step_disable_systemd_resolved

    print_section "User & Directories"
    execute_step "Creating system user"           step_create_user
    execute_step "Creating directories"           step_create_directories

    print_section "AdGuard Home"
    execute_step "Downloading AdGuard Home"       step_download_adguard
    execute_step "Writing configuration"          step_write_config

    print_section "Service Setup"
    execute_step "Installing systemd service"     step_install_service
    execute_step "Starting AdGuard Home"          step_start_service
    execute_step "Configuring UFW firewall"       step_configure_ufw

    if [[ "$NGINX_CHOICE" =~ ^(y|yes)$ ]]; then
        print_section "Nginx & SSL"
        execute_step "Configuring Nginx + SSL"    step_configure_nginx
    else
        AG_ACCESS_URL="http://${SERVER_IP}:${AG_WEB_PORT}"
    fi

    print_section "Finalization"
    execute_step "Saving credentials"             step_save_secrets
    execute_step "Generating manifest"            step_generate_manifest

    local END_TIME DURATION
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    # ── Production Hardening Checklist ────────────────────────────────────────
    echo -e "${PURPLE}"
    echo "  ─── Production Hardening Checklist ─────────────────────────────"
    echo ""
    echo "  [ ] Point your router's DNS to this server: ${SERVER_IP}"
    echo "  [ ] Change upstream DNS in the Web UI to your preferred providers"
    echo "  [ ] Enable DNSSEC in Settings → DNS Settings"
    echo "  [ ] Enable Encrypted DNS (DoH/DoT) in Settings → Encryption"
    echo "  [ ] Add custom blocklists in Filters → DNS Blocklists"
    echo "  [ ] Review UFW rules:   sudo ufw status"
    echo "  [ ] Enable auto OS updates: sudo dpkg-reconfigure unattended-upgrades"
    echo ""
    echo "  ─────────────────────────────────────────────────────────────────"
    echo -e "${NC}"

    # ── Final Summary Box ────────────────────────────────────────────────────
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                   ✅  Installation Complete!                    ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    printf "║  %-22s : %-40s║\n" "Service Name"     "AdGuardHome"
    printf "║  %-22s : %-40s║\n" "Install Directory" "$AG_INSTALL_DIR"
    printf "║  %-22s : %-40s║\n" "Data Directory"   "$AG_DATA_DIR"
    printf "║  %-22s : %-40s║\n" "Web UI Port"      "$AG_WEB_PORT"
    printf "║  %-22s : %-40s║\n" "DNS Port"         "$AG_DNS_PORT"
    printf "║  %-22s : %-40s║\n" "Access URL"       "$AG_ACCESS_URL"
    printf "║  %-22s : %-40s║\n" "Config File"      "$AG_INSTALL_DIR/AdGuardHome.yaml"
    printf "║  %-22s : %-40s║\n" "Log File"         "$AG_LOG_DIR/AdGuardHome.log"
    printf "║  %-22s : %-40s║\n" "Install Time"     "$((DURATION / 60)) min $((DURATION % 60)) sec"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo -e "${NC}${BOLD}${RED}"
    printf "║  %-22s : %-40s║\n" "👤 Admin Username"  "$AG_ADMIN_USER"
    printf "║  %-22s : %-40s║\n" "🔑 Admin Password"  "$AG_ADMIN_PASSWORD"
    echo -e "${NC}${GREEN}"
    printf "║  %-22s : %-40s║\n" "Password Backup"  "$SECRETS_FILE"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # ── Security Warning ────────────────────────────────────────────────────
    echo -e "${YELLOW}"
    echo "  ╔─────────────────────────────────────────────────────────────╗"
    echo "  │  🔒  SECURITY REMINDER — ACTION REQUIRED                    │"
    echo "  ├─────────────────────────────────────────────────────────────┤"
    echo "  │                                                             │"
    echo "  │  ⚠  Credentials are displayed above in plain text.         │"
    echo "  │                                                             │"
    echo "  │  Before leaving this terminal, please:                     │"
    echo "  │    1. Copy credentials to a secure password manager.       │"
    echo "  │    2. Clear terminal history:                              │"
    echo "  │         history -c && history -w                           │"
    echo "  │                                                             │"
    echo "  │  Credentials also saved in (root-only):                    │"
    echo "  │    $SECRETS_FILE"
    printf "  │  %-61s│\n" ""
    echo "  ╚─────────────────────────────────────────────────────────────╝"
    echo -e "${NC}"

    # ── Quick Commands ─────────────────────────────────────────────────────
    echo -e "${CYAN}  Quick commands:${NC}"
    echo "    Status  : sudo systemctl status AdGuardHome"
    echo "    Restart : sudo systemctl restart AdGuardHome"
    echo "    Logs    : sudo journalctl -u AdGuardHome -f"
    echo "    Config  : sudo nano $AG_INSTALL_DIR/AdGuardHome.yaml"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────────────────────
main() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED}[✖ ERROR]${NC} Please run as root: sudo $0 $*"
        exit 1
    fi

    parse_arguments "$@"

    if [[ "$CONFIG_MODE" == "interactive" ]]; then
        gather_inputs
    else
        [[ -z "$AG_ADMIN_USER" ]] && AG_ADMIN_USER="admin"
        [[ -z "$AG_ADMIN_PASSWORD" ]] && AG_ADMIN_PASSWORD=$(generate_random_password)
        validate_port_range "$AG_WEB_PORT" || print_error "Invalid web port: $AG_WEB_PORT"
        validate_port_range "$AG_DNS_PORT" || print_error "Invalid DNS port: $AG_DNS_PORT"
    fi

    validate_configuration
    execute_installation
}

main "$@"
