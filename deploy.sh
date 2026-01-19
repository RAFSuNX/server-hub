#!/usr/bin/env bash
set -euo pipefail

# NixOS Fleet Deploy Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="${SCRIPT_DIR}"
REMOTE_DIR="/etc/nixos"
SERVERS=("systema" "systemb" "systemc")
SECRETS_DIR="${NIXOS_DIR}/secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  deploy [host]       Deploy to all servers or specific host"
    echo "  sync [host]         Only sync configs (no rebuild)"
    echo "  check               Validate flake configuration"
    echo "  status              Check server status"
    echo "  dry-run [host]      Build config and show path without deploying"
    echo ""
    echo "Options:"
    echo "  --reboot            Reboot after deploy"
    echo ""
    echo "Examples:"
    echo "  $0 deploy                    # Deploy to all servers"
    echo "  $0 deploy systema            # Deploy to systema only"
    echo "  $0 dry-run                   # Check all servers"
}

sync_to_host() {
    local host=$1
    local tmp_dir="~/nixos-config-$$"
    log_info "Syncing configuration to ${host}..."

    # Copy to temp location first
    ssh "$host" "rm -rf ${tmp_dir} && mkdir -p ${tmp_dir}/secrets"
    scp -r "${NIXOS_DIR}/flake.nix" "${host}:${tmp_dir}/"
    scp -r "${NIXOS_DIR}/flake.lock" "${host}:${tmp_dir}/" 2>/dev/null || true
    scp -r "${NIXOS_DIR}/modules" "${host}:${tmp_dir}/"
    scp -r "${NIXOS_DIR}/hosts" "${host}:${tmp_dir}/"

    # Copy secrets if they exist
    if [[ -d "$SECRETS_DIR" ]] && [[ -n "$(ls -A $SECRETS_DIR 2>/dev/null)" ]]; then
        scp -r "${SECRETS_DIR}"/* "${host}:${tmp_dir}/secrets/"
    fi

    # Move to /etc/nixos with sudo
    ssh "$host" "sudo rm -rf ${REMOTE_DIR}/* && sudo cp -r ${tmp_dir}/* ${REMOTE_DIR}/ && sudo chown -R root:root ${REMOTE_DIR} && sudo chmod 600 ${REMOTE_DIR}/secrets/* 2>/dev/null || true && rm -rf ${tmp_dir}"

    log_success "Synced to ${host}"
}

deploy_to_host() {
    local host=$1
    local reboot=${2:-false}

    sync_to_host "$host"

    log_info "Rebuilding NixOS on ${host}..."
    ssh "$host" "sudo nixos-rebuild switch --flake ${REMOTE_DIR}#${host}"
    log_success "Deployed to ${host}"

    if [[ "$reboot" == "true" ]]; then
        log_info "Rebooting ${host}..."
        ssh "$host" "sudo reboot" || true
    fi
}

dry_run_on_host() {
    local host=$1
    local tmp_dir="~/nixos-config-dry-run-$$"
    log_info "Performing a dry-run for ${host}..."

    # Sync to a temporary directory
    ssh "$host" "rm -rf ${tmp_dir} && mkdir -p ${tmp_dir}/secrets"
    scp -r "${NIXOS_DIR}/flake.nix" "${host}:${tmp_dir}/"
    scp -r "${NIXOS_DIR}/flake.lock" "${host}:${tmp_dir}/" 2>/dev/null || true
    scp -r "${NIXOS_DIR}/modules" "${host}:${tmp_dir}/"
    scp -r "${NIXOS_DIR}/hosts" "${host}:${tmp_dir}/"
    if [[ -d "$SECRETS_DIR" ]] && [[ -n "$(ls -A $SECRETS_DIR 2>/dev/null)" ]]; then
        scp -r "${SECRETS_DIR}"/* "${host}:${tmp_dir}/secrets/"
    fi

    # Build the configuration and get the output path
    local result_path
    result_path=$(ssh "$host" "nixos-rebuild build --flake ${tmp_dir}#${host} --no-link")
    
    # Get the store path from the result
    local store_path
    store_path=$(echo "$result_path" | grep -o '/nix/store/.*-nixos-system-.*')

    log_info "Local config for ${host} builds: ${store_path}"

    # Get the current system path
    local current_system
    current_system=$(ssh "$host" "readlink -f /run/current-system")
    log_info "Current system on ${host} is: ${current_system}"

    if [[ "$store_path" == "$current_system" ]]; then
        log_success "Configuration for ${host} is up to date."
    else
        log_warn "Configuration for ${host} is NOT up to date."
    fi

    # Clean up
    ssh "$host" "rm -rf ${tmp_dir}"
}

check_status() {
    for host in "${SERVERS[@]}"; do
        if ssh -o ConnectTimeout=5 "$host" "echo ok" &>/dev/null; then
            log_success "${host} is online"
        else
            log_error "${host} is offline"
        fi
    done
}

check_flake() {
    log_info "Checking flake configuration..."
    cd "$NIXOS_DIR" && nix flake check
    log_success "Flake configuration is valid"
}

# Parse arguments
COMMAND=${1:-}
TARGET=${2:-}
REBOOT=false

for arg in "$@"; do
    case $arg in
        --reboot) REBOOT=true ;;
    esac
done

case "$COMMAND" in
    deploy)
        if [[ -n "$TARGET" && "$TARGET" != "--"* ]]; then
            deploy_to_host "$TARGET" "$REBOOT"
        else
            for host in "${SERVERS[@]}"; do
                deploy_to_host "$host" "$REBOOT"
            done
        fi
        ;;
    sync)
        if [[ -n "$TARGET" && "$TARGET" != "--"* ]]; then
            sync_to_host "$TARGET"
        else
            for host in "${SERVERS[@]}"; do
                sync_to_host "$host"
            done
        fi
        ;;
    dry-run)
        if [[ -n "$TARGET" && "$TARGET" != "--"* ]]; then
            dry_run_on_host "$TARGET"
        else
            for host in "${SERVERS[@]}"; do
                dry_run_on_host "$host"
            done
        fi
        ;;
    check)
        check_flake
        ;;
    status)
        check_status
        ;;
    *)
        usage
        exit 1
        ;;
esac
