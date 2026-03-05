#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="/etc/nixos"
SERVERS=("systema" "systemb" "systemc")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    echo "Usage: $0 [command] [host]"
    echo ""
    echo "Commands:"
    echo "  deploy [host]     Deploy to all servers or specific host (parallel)"
    echo "  sync [host]       Sync configs only, no rebuild"
    echo "  dry-run [host]    Build config without switching"
    echo "  cleanup [host]    GC old generations and clean temp files"
    echo "  status            Check SSH + Tailscale status"
    echo ""
    echo "Options:"
    echo "  --reboot          Reboot after deploy"
    echo ""
    echo "Examples:"
    echo "  $0 deploy                 # Deploy to all (parallel)"
    echo "  $0 deploy systema         # Deploy to systema only"
    echo "  $0 cleanup                # GC all servers"
    echo "  $0 deploy --reboot        # Deploy + reboot all"
}

sync_to_host() {
    local host=$1
    local tmp="~/nixos-deploy-$$"
    log_info "[${host}] Syncing configuration..."

    ssh "$host" "mkdir -p ${tmp}/secrets"
    rsync -a --delete \
        --exclude='*.sh' \
        "${SCRIPT_DIR}/" "rafsunx@${host}:${tmp}/"

    ssh "$host" "sudo rsync -a --delete ${tmp}/ ${REMOTE_DIR}/ && \
        sudo chown -R root:root ${REMOTE_DIR} && \
        sudo chmod 600 ${REMOTE_DIR}/secrets/*.age 2>/dev/null || true && \
        rm -rf ${tmp}"

    log_success "[${host}] Synced"
}

deploy_to_host() {
    local host=$1
    local reboot=${2:-false}

    sync_to_host "$host"

    log_info "[${host}] Rebuilding NixOS..."
    ssh "$host" "sudo nixos-rebuild switch --flake ${REMOTE_DIR}#${host} 2>&1 | tail -5"
    log_success "[${host}] Deployed"

    if [[ "$reboot" == "true" ]]; then
        log_info "[${host}] Rebooting..."
        ssh "$host" "sudo reboot" || true
    fi
}

deploy_parallel() {
    local reboot=$1
    shift
    local hosts=("$@")
    local pids=()

    for host in "${hosts[@]}"; do
        deploy_to_host "$host" "$reboot" &
        pids+=($!)
    done

    local failed=0
    for pid in "${pids[@]}"; do
        wait "$pid" || { log_error "A deploy job failed (pid $pid)"; failed=1; }
    done

    [[ $failed -eq 0 ]] && log_success "All deployments complete"
}

dry_run_on_host() {
    local host=$1
    local tmp="~/nixos-dry-run-$$"
    log_info "[${host}] Dry run..."

    ssh "$host" "mkdir -p ${tmp}/secrets"
    rsync -a --exclude='*.sh' "${SCRIPT_DIR}/" "rafsunx@${host}:${tmp}/"

    local current
    current=$(ssh "$host" "readlink -f /run/current-system")

    local result
    result=$(ssh "$host" "nixos-rebuild build --flake ${tmp}#${host} --no-link 2>/dev/null; \
        ls -d /nix/store/*-nixos-system-${host}-* 2>/dev/null | sort | tail -1") || true

    ssh "$host" "rm -rf ${tmp}"

    if [[ "$result" == "$current" ]]; then
        log_success "[${host}] Up to date: ${current}"
    else
        log_warn  "[${host}] Would change:"
        log_info  "  current: ${current}"
        log_info  "  new:     ${result}"
    fi
}

cleanup_host() {
    local host=$1
    log_info "[${host}] Running cleanup..."
    ssh "$host" "
        sudo nix-collect-garbage -d 2>&1 | tail -3
        sudo rm -rf /tmp/nixos-* /tmp/nixos-deploy-* /tmp/nixos-dry-run-* 2>/dev/null || true
        sudo journalctl --vacuum-size=50M 2>&1 | tail -2
    "
    log_success "[${host}] Cleaned"
}

check_status() {
    for host in "${SERVERS[@]}"; do
        if ssh -o ConnectTimeout=5 "$host" "echo ok" &>/dev/null; then
            local ts
            ts=$(ssh "$host" "sudo tailscale status 2>/dev/null | grep \$(hostname)" || echo "tailscale unknown")
            log_success "${host} online — ${ts}"
        else
            log_error "${host} offline"
        fi
    done
}

# Parse args
COMMAND=${1:-}
TARGET=${2:-}
REBOOT=false
for arg in "$@"; do [[ "$arg" == "--reboot" ]] && REBOOT=true; done

# Filter out --reboot from TARGET
[[ "$TARGET" == "--reboot" ]] && TARGET=""

case "$COMMAND" in
    deploy)
        if [[ -n "$TARGET" ]]; then
            deploy_to_host "$TARGET" "$REBOOT"
        else
            deploy_parallel "$REBOOT" "${SERVERS[@]}"
        fi
        ;;
    sync)
        targets=( ${TARGET:-"${SERVERS[@]}"} )
        for h in "${targets[@]}"; do sync_to_host "$h"; done
        ;;
    dry-run)
        targets=( ${TARGET:-"${SERVERS[@]}"} )
        for h in "${targets[@]}"; do dry_run_on_host "$h"; done
        ;;
    cleanup)
        if [[ -n "$TARGET" ]]; then
            cleanup_host "$TARGET"
        else
            for host in "${SERVERS[@]}"; do cleanup_host "$host" & done
            wait && log_success "All nodes cleaned"
        fi
        ;;
    status)
        check_status
        ;;
    *)
        usage; exit 1
        ;;
esac
