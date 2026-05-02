#!/usr/bin/env bash
#
# LagoonAtHome Installer
# Interactive installer for Lagoon on k3s — tailored for bare-metal homelabs.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# --- Colors and formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
  _                                    _   _   _
 | |    __ _  __ _  ___   ___  _ __   / \ | |_| |__   ___  _ __ ___   ___
 | |   / _` |/ _` |/ _ \ / _ \| '_ \ / _ \| __| '_ \ / _ \| '_ ` _ \ / _ \
 | |__| (_| | (_| | (_) | (_) | | | / ___ \ |_| | | | (_) | | | | | |  __/
 |_____\__,_|\__, |\___/ \___/|_| |_/_/   \_\__|_| |_|\___/|_| |_| |_|\___|
             |___/
EOF
    echo -e "${NC}"
    echo -e "${BOLD}Lagoon on k3s — for bare-metal homelabs${NC}"
    echo ""
}

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()    { echo -e "\n${CYAN}${BOLD}==> $*${NC}"; }

# --- Utility functions ---

prompt() {
    local var_name="$1"
    local prompt_text="$2"
    local default="${3:-}"
    local value

    if [ -n "$default" ]; then
        echo -en "${BOLD}${prompt_text}${NC} [${default}]: "
    else
        echo -en "${BOLD}${prompt_text}${NC}: "
    fi
    read -r value
    value="${value:-$default}"

    if [ -z "$value" ]; then
        error "Value required for: ${prompt_text}"
        prompt "$var_name" "$prompt_text" "$default"
        return
    fi

    eval "$var_name=\"$value\""
}

prompt_password() {
    local var_name="$1"
    local prompt_text="$2"
    local value

    echo -en "${BOLD}${prompt_text}${NC}: "
    read -rs value
    echo ""

    if [ -z "$value" ]; then
        error "Password cannot be empty"
        prompt_password "$var_name" "$prompt_text"
        return
    fi

    eval "$var_name=\"$value\""
}

confirm() {
    local prompt_text="$1"
    local default="${2:-y}"
    local yn

    if [ "$default" = "y" ]; then
        echo -en "${BOLD}${prompt_text}${NC} [Y/n]: "
    else
        echo -en "${BOLD}${prompt_text}${NC} [y/N]: "
    fi
    read -r yn
    yn="${yn:-$default}"

    case "$yn" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

generate_password() {
    openssl rand -base64 18 | tr -d '/+=' | head -c 24
}

detect_os() {
    local os
    os="$(uname -s)"
    case "$os" in
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                local id_check="${ID} ${ID_LIKE:-}"
                case "$id_check" in
                    *ubuntu*|*debian*) echo "debian" ;;
                    *fedora*|*rhel*|*centos*) echo "rhel" ;;
                    *arch*) echo "arch" ;;
                    *suse*) echo "suse" ;;
                    *) echo "linux-unknown" ;;
                esac
            else
                echo "linux-unknown"
            fi
            ;;
        Darwin) echo "darwin" ;;
        *) echo "unknown" ;;
    esac
}

detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "$arch" ;;
    esac
}

detect_default_ip() {
    # Try to get the default route interface IP
    if command -v ip >/dev/null 2>&1; then
        ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1
    else
        echo "192.168.1.100"
    fi
}

install_pkg() {
    local pkg="$1"
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y "$pkg"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "$pkg"
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y "$pkg"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm "$pkg"
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y "$pkg"
    else
        return 1
    fi
}

check_prerequisites() {
    # Try to auto-install make if it's missing — install.sh hands off to the Makefile,
    # so without it the installer dies in run_installation with an unhelpful error.
    if ! command -v make >/dev/null 2>&1; then
        info "make not found, attempting to install it"
        if ! install_pkg make; then
            error "Could not auto-install make. Please install it manually and re-run."
            exit 1
        fi
    fi

    local missing=()
    for cmd in curl git openssl ssh-keygen make; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        error "Please install them and re-run the installer."
        exit 1
    fi
    success "Prerequisites check passed"
}

# --- Main installer flow ---

main() {
    cd "$SCRIPT_DIR"
    print_banner

    # Check for existing config
    if [ -f "$ENV_FILE" ]; then
        warn "Existing configuration found (.env)"
        if confirm "Use existing configuration?"; then
            info "Loading existing configuration"
            source "$ENV_FILE"
            if confirm "Proceed with installation?"; then
                run_installation
                return
            else
                info "Reconfiguring..."
            fi
        fi
    fi

    # --- Phase 1: System checks ---
    step "Checking system"

    local os_type arch
    os_type="$(detect_os)"
    arch="$(detect_arch)"
    info "Detected OS: ${os_type} (${arch})"

    if [ "$os_type" = "unknown" ]; then
        error "Unsupported operating system"
        exit 1
    fi

    if [ "$os_type" = "darwin" ]; then
        warn "macOS detected. k3s runs on Linux only."
        warn "You can use this installer to generate configuration for a remote Linux node."
    fi

    # Detect container/Distrobox environment
    if [ -f /run/.containerenv ] || [ -n "${DISTROBOX_ENTER_PATH:-}" ]; then
        warn "Running inside a container (Distrobox/Toolbox detected)."
        warn "k3s must be installed on the HOST, not inside the container."
        warn ""
        warn "Recommended approach for immutable distros (Bazzite, Bluefin, etc.):"
        warn "  1. Run this installer on the HOST to generate config: ./install.sh"
        warn "     (answer the prompts, then Ctrl-C before installation starts)"
        warn "  2. On the HOST, run: make k3s && make system"
        warn "  3. Everything else can run from here (Distrobox has kubectl/helm access)"
        warn ""
        if ! confirm "Continue anyway (config generation only)?" "n"; then
            exit 0
        fi
    fi

    # Detect immutable OS
    if [ -f /run/ostree-booted ]; then
        info "Immutable OS detected (OSTree/Atomic: Bazzite, Bluefin, Silverblue, etc.)"
        info "Packages will be installed via rpm-ostree where needed."
        info "A reboot may be required after the system setup step."
    fi

    check_prerequisites

    # --- Phase 2: Network configuration ---
    step "Network Configuration"

    local default_ip
    default_ip="$(detect_default_ip)"

    prompt NODE_IP "Node IP address (the IP of this machine)" "$default_ip"

    local default_range="${NODE_IP}-${NODE_IP%.*}.$((${NODE_IP##*.} + 10))"
    prompt LAGOON_NETWORK_RANGE "MetalLB IP range" "$default_range"

    # --- Phase 3: TLS configuration ---
    step "TLS Configuration"

    echo ""
    echo "  Choose your TLS certificate strategy:"
    echo ""
    echo -e "  ${BOLD}1)${NC} Self-signed certificates (uses nip.io domains)"
    echo "     Best for: local/private networks, no public IP needed"
    echo ""
    echo -e "  ${BOLD}2)${NC} Let's Encrypt (HTTP-01 challenge)"
    echo "     Best for: public-facing setups with ports 80/443 forwarded"
    echo "     Requires: a real domain pointing to your public IP"
    echo ""
    echo -e "  ${BOLD}3)${NC} Let's Encrypt via Cloudflare DNS-01"
    echo "     Best for: homelabs behind NAT, no port forwarding needed"
    echo "     Requires: domain on Cloudflare + API token"
    echo ""

    local tls_choice
    while true; do
        echo -en "${BOLD}Select TLS mode [1/2/3]${NC}: "
        read -r tls_choice
        case "$tls_choice" in
            1)
                TLS_MODE="selfsigned"
                CLUSTER_ISSUER="lagoon-issuer"
                DOMAIN="${NODE_IP}.nip.io"
                ACME_EMAIL=""
                CLOUDFLARE_API_TOKEN=""
                info "Using self-signed certificates with domain: ${DOMAIN}"
                break
                ;;
            2)
                TLS_MODE="letsencrypt"
                CLUSTER_ISSUER="letsencrypt-prod"
                prompt DOMAIN "Your domain (e.g., lagoon.example.com)" ""
                prompt ACME_EMAIL "Email for Let's Encrypt notifications" ""
                CLOUDFLARE_API_TOKEN=""
                info "Using Let's Encrypt with domain: ${DOMAIN}"
                break
                ;;
            3)
                TLS_MODE="cloudflare"
                CLUSTER_ISSUER="cloudflare-dns01"
                prompt DOMAIN "Your domain (e.g., lagoon.example.com)" ""
                prompt ACME_EMAIL "Email for Let's Encrypt notifications" ""
                prompt CLOUDFLARE_API_TOKEN "Cloudflare API token (Zone:DNS:Edit permission)" ""
                info "Using Cloudflare DNS-01 with domain: ${DOMAIN}"
                break
                ;;
            *)
                warn "Please select 1, 2, or 3"
                ;;
        esac
    done

    # --- Phase 4: User configuration ---
    step "Admin User Configuration"

    prompt ADMIN_EMAIL "Admin email" "admin@example.com"
    prompt ADMIN_FIRST_NAME "First name" "Admin"
    prompt ADMIN_LAST_NAME "Last name" "User"
    prompt ORG_NAME "Organization name" "lagoon"

    local default_ssh_key="${HOME}/.ssh/id_ed25519"
    if [ ! -f "${default_ssh_key}.pub" ]; then
        default_ssh_key="${HOME}/.ssh/id_rsa"
    fi
    prompt SSH_KEY_PATH "SSH key path (private key)" "$default_ssh_key"
    # Expand a leading ~ so .env always holds an absolute path — lagoon CLI doesn't expand ~ itself.
    case "$SSH_KEY_PATH" in
        "~"|"~/"*) SSH_KEY_PATH="${HOME}${SSH_KEY_PATH#~}" ;;
    esac

    if [ ! -f "${SSH_KEY_PATH}.pub" ]; then
        warn "Public key not found at ${SSH_KEY_PATH}.pub"
        if confirm "Generate a new SSH key pair?"; then
            ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -q
            success "Generated SSH key pair at ${SSH_KEY_PATH}"
        else
            error "SSH public key required. Please provide a valid path."
            exit 1
        fi
    fi

    # --- Phase 5: Optional components ---
    step "Optional Components"

    INSTALL_HARBOR="false"
    INSTALL_PROMETHEUS="false"
    INSTALL_POSTGRES="true"
    INSTALL_MARIADB="true"
    INSTALL_HEADLAMP="false"

    confirm "Install Harbor (private Docker registry)?" "n" && INSTALL_HARBOR="true"
    confirm "Install Prometheus & Grafana (monitoring)?" "n" && INSTALL_PROMETHEUS="true"
    confirm "Install PostgreSQL (database provider)?" "y" && INSTALL_POSTGRES="true" || INSTALL_POSTGRES="false"
    confirm "Install MariaDB (database provider)?" "y" && INSTALL_MARIADB="true" || INSTALL_MARIADB="false"
    confirm "Install Headlamp (Kubernetes dashboard)?" "n" && INSTALL_HEADLAMP="true"

    # --- Phase 6: Generate secrets ---
    step "Generating Secrets"

    ADMIN_PASSWORD="$(generate_password)"
    MINIO_PASSWORD="$(generate_password)"
    HARBOR_PASSWORD="$(generate_password)"
    POSTGRES_PASSWORD="$(generate_password)"
    MARIADB_PASSWORD="$(generate_password)"

    success "Generated random passwords for all services"

    # --- Phase 7: Write configuration ---
    step "Writing Configuration"

    cat > "$ENV_FILE" << ENVEOF
# LagoonAtHome Configuration
# Generated by install.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Network
NODE_IP=${NODE_IP}
LAGOON_NETWORK_RANGE=${LAGOON_NETWORK_RANGE}

# TLS
TLS_MODE=${TLS_MODE}
ACME_EMAIL=${ACME_EMAIL}
CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}

# Domain
DOMAIN=${DOMAIN}
CLUSTER_ISSUER=${CLUSTER_ISSUER}

# Admin User
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_FIRST_NAME=${ADMIN_FIRST_NAME}
ADMIN_LAST_NAME=${ADMIN_LAST_NAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ORG_NAME=${ORG_NAME}
SSH_KEY_PATH=${SSH_KEY_PATH}

# Service Passwords
MINIO_PASSWORD=${MINIO_PASSWORD}
HARBOR_PASSWORD=${HARBOR_PASSWORD}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
MARIADB_PASSWORD=${MARIADB_PASSWORD}

# Optional Components
INSTALL_HARBOR=${INSTALL_HARBOR}
INSTALL_PROMETHEUS=${INSTALL_PROMETHEUS}
INSTALL_POSTGRES=${INSTALL_POSTGRES}
INSTALL_MARIADB=${INSTALL_MARIADB}
INSTALL_HEADLAMP=${INSTALL_HEADLAMP}
ENVEOF

    chmod 600 "$ENV_FILE"
    success "Configuration written to .env"

    # --- Phase 8: Review ---
    step "Configuration Summary"

    echo ""
    echo -e "  ${BOLD}Network${NC}"
    echo "    Node IP:        ${NODE_IP}"
    echo "    MetalLB range:  ${LAGOON_NETWORK_RANGE}"
    echo ""
    echo -e "  ${BOLD}TLS${NC}"
    echo "    Mode:           ${TLS_MODE}"
    echo "    Domain:         ${DOMAIN}"
    [ -n "$ACME_EMAIL" ] && echo "    ACME email:     ${ACME_EMAIL}"
    echo "    Cluster issuer: ${CLUSTER_ISSUER}"
    echo ""
    echo -e "  ${BOLD}Admin${NC}"
    echo "    Email:          ${ADMIN_EMAIL}"
    echo "    Name:           ${ADMIN_FIRST_NAME} ${ADMIN_LAST_NAME}"
    echo "    Organization:   ${ORG_NAME}"
    echo "    SSH key:        ${SSH_KEY_PATH}"
    echo ""
    echo -e "  ${BOLD}Components${NC}"
    echo "    Harbor:         ${INSTALL_HARBOR}"
    echo "    Prometheus:     ${INSTALL_PROMETHEUS}"
    echo "    PostgreSQL:     ${INSTALL_POSTGRES}"
    echo "    MariaDB:        ${INSTALL_MARIADB}"
    echo "    Headlamp:       ${INSTALL_HEADLAMP}"
    echo ""

    if ! confirm "Proceed with installation?"; then
        info "Configuration saved to .env. Edit manually and run './install.sh' again."
        info "Or run individual targets with: make <target>"
        exit 0
    fi

    run_installation
}

run_installation() {
    local start_time
    start_time=$(date +%s)

    step "Generating configuration files"
    make -C "$SCRIPT_DIR" generate-config
    success "Configuration files generated"

    step "Installing k3s"
    run_step "k3s"

    step "Configuring system"
    run_step "system"

    step "Setting up Helm repositories"
    run_step "helm-repos"

    step "Installing MetalLB"
    run_step "metallb"

    step "Installing cert-manager"
    run_step "cert-manager"

    step "Installing Gatekeeper"
    run_step "gatekeeper"

    step "Installing Ingress Nginx"
    run_step "ingress"

    if [ "${INSTALL_HARBOR:-false}" = "true" ]; then
        step "Installing Harbor (build registry)"
        run_step "harbor"
    else
        step "Installing Docker registry"
        run_step "registry"
    fi

    step "Installing MinIO"
    run_step "minio"

    if [ "${INSTALL_POSTGRES:-true}" = "true" ]; then
        step "Installing PostgreSQL"
        run_step "postgres"
    fi

    if [ "${INSTALL_MARIADB:-true}" = "true" ]; then
        step "Installing MariaDB"
        run_step "mariadb"
    fi

    step "Installing Lagoon Core"
    run_step "lagoon-core"

    step "Installing Lagoon Remote"
    run_step "lagoon-remote"

    step "Configuring Lagoon (post-install)"
    run_step "lagoon-config"

    step "Building and pushing build-deploy-tool"
    if command -v docker >/dev/null 2>&1; then
        run_step "build-deploy-tool"
        run_step "push-local-build-image"
    else
        warn "Docker not found, skipping build-deploy-tool."
        warn "Install Docker and run: make build-deploy-tool push-local-build-image"
    fi

    if [ "${INSTALL_PROMETHEUS:-false}" = "true" ]; then
        step "Installing Prometheus"
        run_step "prometheus"
    fi

    if [ "${INSTALL_HEADLAMP:-false}" = "true" ]; then
        step "Installing Headlamp"
        run_step "headlamp"
    fi

    # Apply any user-supplied resources from extras/ (additional ingresses,
    # services, etc. that share the cluster with Lagoon).
    if compgen -G "extras/*.yml" >/dev/null \
        || compgen -G "extras/*.yaml" >/dev/null \
        || compgen -G "extras/*.yml.tpl" >/dev/null \
        || compgen -G "extras/*.yaml.tpl" >/dev/null; then
        step "Applying user resources from extras/"
        run_step "apply-extras"
    fi

    local end_time elapsed_min
    end_time=$(date +%s)
    elapsed_min=$(( (end_time - start_time) / 60 ))

    # --- Summary ---
    echo ""
    echo -e "${GREEN}${BOLD}============================================${NC}"
    echo -e "${GREEN}${BOLD}  Installation complete! (${elapsed_min} minutes)${NC}"
    echo -e "${GREEN}${BOLD}============================================${NC}"
    echo ""
    echo -e "  ${BOLD}Access URLs${NC}"
    echo "    Dashboard:  https://dashboard.${DOMAIN}"
    echo "    API:        https://api.${DOMAIN}/graphql"
    echo "    Keycloak:   https://keycloak.${DOMAIN}"
    echo "    MinIO:      https://minio.${DOMAIN}"
    [ "${INSTALL_HARBOR:-false}" = "true" ] && echo "    Harbor:     https://harbor.${DOMAIN}"
    [ "${INSTALL_HEADLAMP:-false}" = "true" ] && echo "    Headlamp:   https://headlamp.${DOMAIN}"
    echo ""
    echo -e "  ${BOLD}Credentials${NC}"
    echo "    Admin email:    ${ADMIN_EMAIL}"
    echo "    Admin password: ${ADMIN_PASSWORD}"
    echo "    MinIO password: ${MINIO_PASSWORD}"
    [ "${INSTALL_HARBOR:-false}" = "true" ] && echo "    Harbor password: ${HARBOR_PASSWORD}"
    echo ""
    echo -e "  ${BOLD}SSH Access${NC}"
    echo "    lagoon ssh -p <project> -e <environment>"
    echo ""

    if [ "${TLS_MODE}" = "selfsigned" ]; then
        echo -e "  ${YELLOW}${BOLD}Note:${NC} Self-signed certificates are in use."
        echo "    To trust them on your workstation, install the CA:"
        echo "    ${SCRIPT_DIR}/certs/rootCA.pem"
        echo ""
    fi

    echo "  Credentials are saved in: ${ENV_FILE}"
    echo ""
}

run_step() {
    local target="$1"
    if make -C "$SCRIPT_DIR" "$target" 2>&1 | while IFS= read -r line; do
        echo "  $line"
    done; then
        success "$target completed"
    else
        error "$target failed"
        error "Fix the issue and re-run: make $target"
        error "Or re-run the full installer: ./install.sh"
        exit 1
    fi
}

# --- Entry point ---
main "$@"
