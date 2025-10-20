#!/bin/bash

# SSH Mesh Setup Script
# This script sets up passwordless SSH between all systems found in /etc/hosts
# It looks for: systema, systemb, systemc, systemd
# Works with ANY subset of systems (e.g., only systema and systemc)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root. Run as the user you want to setup SSH for."
   exit 1
fi

# Define systems to look for
SYSTEM_NAMES=("systema" "systemb" "systemc" "systemd")

# Array to store discovered systems
declare -A DISCOVERED_SYSTEMS

log_info "Starting SSH mesh setup..."
log_info "Current user: $(whoami)"
log_info "Current hostname: $(hostname)"

# Step 1: Parse /etc/hosts to find systems
log_info "Parsing /etc/hosts for target systems..."
log_info "Looking for: ${SYSTEM_NAMES[*]}"
log_info ""

# Arrays to track found and not found systems
FOUND_SYSTEMS=()
NOT_FOUND_SYSTEMS=()

for system in "${SYSTEM_NAMES[@]}"; do
    # Look for the system in /etc/hosts
    if grep -q "^[^#]*[[:space:]]${system}[[:space:]]*$\|^[^#]*[[:space:]]${system}$" /etc/hosts; then
        ip=$(grep "^[^#]*[[:space:]]${system}[[:space:]]*$\|^[^#]*[[:space:]]${system}$" /etc/hosts | awk '{print $1}' | head -n1)
        DISCOVERED_SYSTEMS[$system]=$ip
        FOUND_SYSTEMS+=("$system")
        log_info "[✓] Found ${system} at IP: ${ip}"
    else
        NOT_FOUND_SYSTEMS+=("$system")
        log_warn "[✗] ${system} not found in /etc/hosts"
    fi
done

log_info ""
log_info "Discovery Summary:"
log_info "  Found: ${#FOUND_SYSTEMS[@]} system(s) - ${FOUND_SYSTEMS[*]}"
log_info "  Not found: ${#NOT_FOUND_SYSTEMS[@]} system(s) - ${NOT_FOUND_SYSTEMS[*]}"
log_info ""

# Check if any systems were found
if [ ${#DISCOVERED_SYSTEMS[@]} -eq 0 ]; then
    log_error "No systems found in /etc/hosts!"
    log_error "Please add entries to /etc/hosts like:"
    log_error "  192.168.1.10 systema"
    log_error "  192.168.1.11 systemb"
    exit 1
fi

log_info "Proceeding with ${#DISCOVERED_SYSTEMS[@]} discovered system(s)"
log_info "Note: Script will only setup SSH between available systems"

# Step 2: Check/Generate SSH key
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
if [ ! -f "$SSH_KEY_PATH" ]; then
    log_info "SSH key not found. Generating new SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "$(whoami)@$(hostname)"
    log_info "SSH key generated: $SSH_KEY_PATH"
else
    log_info "SSH key already exists: $SSH_KEY_PATH"
fi

# Ensure proper permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub 2>/dev/null || true

# Step 3: Get current hostname to identify ourselves
CURRENT_HOSTNAME=$(hostname)
CURRENT_SHORT_HOSTNAME=$(hostname -s)

# Step 4: Setup SSH to all discovered systems
log_info "Setting up passwordless SSH to all discovered systems..."

for system in "${!DISCOVERED_SYSTEMS[@]}"; do
    ip="${DISCOVERED_SYSTEMS[$system]}"

    # Skip if this is the current system
    if [ "$system" == "$CURRENT_HOSTNAME" ] || [ "$system" == "$CURRENT_SHORT_HOSTNAME" ]; then
        log_warn "Skipping $system (current system)"
        continue
    fi

    log_info "Setting up SSH to ${system} (${ip})..."

    # Check if we can already SSH without password
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${system}" "exit" 2>/dev/null; then
        log_info "Already have passwordless SSH to ${system}"
        continue
    fi

    # Copy SSH key to remote system
    log_info "Copying SSH key to ${system}..."

    # First, test if we can connect at all and check what authentication methods are available
    ssh_test_output=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "${system}" "exit" 2>&1)

    # Check if only publickey auth is allowed
    if echo "$ssh_test_output" | grep -q "Permission denied (publickey)"; then
        log_warn "${system} only allows public key authentication (no password)"
        log_info ""
        log_info "═══════════════════════════════════════════════════════════"
        log_info "  MANUAL ACTION REQUIRED FOR ${system}"
        log_info "═══════════════════════════════════════════════════════════"
        log_info ""
        log_info "Please add this public key to ${system}:"
        log_info ""
        echo -e "${YELLOW}$(cat ~/.ssh/id_rsa.pub)${NC}"
        log_info ""
        log_info "Run these commands on ${system}:"
        log_info "  1. ssh $(whoami)@${system}  # (or access it directly)"
        log_info "  2. mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        log_info "  3. nano ~/.ssh/authorized_keys  # (paste the key above)"
        log_info "  4. chmod 600 ~/.ssh/authorized_keys"
        log_info ""
        log_info "Or as a one-liner on ${system}:"
        log_info "  mkdir -p ~/.ssh && chmod 700 ~/.ssh && nano ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        log_info ""
        echo -ne "${GREEN}[INFO]${NC} Press ENTER after you've added the key to ${system}..."
        read -r
        log_info "Verifying connection to ${system}..."

        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${system}" "exit" 2>/dev/null; then
            log_info "Successfully verified passwordless SSH to ${system}!"
        else
            log_error "Still cannot connect to ${system}. Please verify:"
            log_error "  1. The public key was added correctly"
            log_error "  2. Permissions are correct (600 for authorized_keys, 700 for .ssh)"
            log_error "  3. The user $(whoami) exists on ${system}"
        fi
    else
        # Try password-based ssh-copy-id
        log_info "You may be prompted for the password for $(whoami)@${system}"

        if ssh-copy-id -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${system}" 2>/dev/null; then
            log_info "Successfully set up passwordless SSH to ${system}"
        else
            log_error "Failed to setup SSH to ${system}. Please ensure:"
            log_error "  1. The system is reachable"
            log_error "  2. SSH service is running on ${system}"
            log_error "  3. You have the correct password"
            log_error "  4. The user $(whoami) exists on ${system}"
        fi
    fi
done

# Step 5: Verify connections
log_info ""
log_info "Verifying SSH connections..."
SUCCESS_COUNT=0
FAIL_COUNT=0

for system in "${!DISCOVERED_SYSTEMS[@]}"; do
    ip="${DISCOVERED_SYSTEMS[$system]}"

    # Skip if this is the current system
    if [ "$system" == "$CURRENT_HOSTNAME" ] || [ "$system" == "$CURRENT_SHORT_HOSTNAME" ]; then
        continue
    fi

    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${system}" "echo 'Connection successful'" 2>/dev/null | grep -q "successful"; then
        log_info "[✓] ${system} - Passwordless SSH working"
        ((SUCCESS_COUNT++))
    else
        log_error "[✗] ${system} - Passwordless SSH not working"
        ((FAIL_COUNT++))
    fi
done

# Summary
log_info ""
log_info "=========================================="
log_info "SSH Mesh Setup Summary"
log_info "=========================================="
log_info "Systems in /etc/hosts: ${#DISCOVERED_SYSTEMS[@]} (${FOUND_SYSTEMS[*]})"
if [ ${#NOT_FOUND_SYSTEMS[@]} -gt 0 ]; then
    log_warn "Systems NOT in /etc/hosts: ${NOT_FOUND_SYSTEMS[*]}"
fi
log_info "Successful SSH connections: ${SUCCESS_COUNT}"
log_info "Failed connections: ${FAIL_COUNT}"
log_info ""

if [ $FAIL_COUNT -eq 0 ] && [ $SUCCESS_COUNT -gt 0 ]; then
    log_info "All discovered systems connected successfully!"
    log_info ""
    log_info "IMPORTANT: Run this script on each system to create a full mesh:"
    for system in "${!DISCOVERED_SYSTEMS[@]}"; do
        echo "  - ${system}"
    done
    log_info ""
    if [ ${#NOT_FOUND_SYSTEMS[@]} -gt 0 ]; then
        log_info "NOTE: These systems were not found and won't be part of the mesh:"
        for system in "${NOT_FOUND_SYSTEMS[@]}"; do
            echo "  - ${system} (add to /etc/hosts to include)"
        done
    fi
elif [ $SUCCESS_COUNT -gt 0 ]; then
    log_warn "Partial success: ${SUCCESS_COUNT} connected, ${FAIL_COUNT} failed."
    log_warn "Check the errors above for failed connections."
else
    log_error "No connections were established. Please check the errors above."
fi

log_info ""
log_info "Done!"
