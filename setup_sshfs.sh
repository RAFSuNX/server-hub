#!/bin/bash

# SSHFS Auto-Setup Script
# This script automatically configures bidirectional SSHFS mounts between systems
# Uses user-level systemd services for reliability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CURRENT_HOSTNAME=$(hostname)
CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)
MOUNT_BASE_DIR="$HOME_DIR"
USER_SYSTEMD_DIR="$HOME_DIR/.config/systemd/user"

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Please run this script as a regular user, not root"
        log_info "The script will use sudo when needed"
        exit 1
    fi
}

# Check if sshfs is installed
check_sshfs() {
    if ! command -v sshfs &> /dev/null; then
        log_warning "sshfs is not installed. Installing..."
        
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y sshfs
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y fuse-sshfs
        elif command -v yum &> /dev/null; then
            sudo yum install -y fuse-sshfs
        else
            log_error "Could not determine package manager. Please install sshfs manually."
            exit 1
        fi
        
        log_success "sshfs installed successfully"
    else
        log_success "sshfs is already installed"
    fi
}

# Parse /etc/hosts to find systems
find_systems() {
    log_info "Scanning /etc/hosts for available systems..."
    
    local systems=()
    
    # Read /etc/hosts and extract hostnames that match system pattern
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extract hostname (second field typically)
        local hostname=$(echo "$line" | awk '{print $2}')
        
        # Skip if empty or localhost variants
        [[ -z "$hostname" ]] && continue
        [[ "$hostname" == "localhost" ]] && continue
        [[ "$hostname" =~ ^localhost\. ]] && continue
        
        # Skip current host
        [[ "$hostname" == "$CURRENT_HOSTNAME" ]] && continue
        
        # Check if hostname matches system* pattern or add all non-localhost entries
        if [[ "$hostname" =~ ^system[a-z0-9]+$ ]] || [[ "$hostname" != "" ]]; then
            systems+=("$hostname")
        fi
    done < /etc/hosts
    
    # Remove duplicates
    systems=($(printf "%s\n" "${systems[@]}" | sort -u))
    
    echo "${systems[@]}"
}

# Test passwordless SSH connection
test_ssh_connection() {
    local remote_host=$1
    
    log_info "Testing SSH connection to $remote_host..."
    
    # Try to connect with a simple command, timeout after 5 seconds
    if timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        "$CURRENT_USER@$remote_host" "exit" 2>/dev/null; then
        log_success "Passwordless SSH to $remote_host works!"
        return 0
    else
        log_warning "Cannot establish passwordless SSH to $remote_host"
        return 1
    fi
}

# Create mount point directory
create_mount_point() {
    local mount_point=$1
    
    if [ ! -d "$mount_point" ]; then
        log_info "Creating mount point: $mount_point"
        mkdir -p "$mount_point"
        log_success "Mount point created"
    else
        log_info "Mount point already exists: $mount_point"
    fi
}

# Clean up existing mount if in bad state
cleanup_mount() {
    local mount_point=$1
    
    log_info "Cleaning up mount point: $mount_point"
    
    # Unmount if mounted
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log_warning "Mount point is currently mounted. Unmounting..."
        fusermount -u "$mount_point" 2>/dev/null || true
    fi
    
    # Check for I/O errors and force unmount
    if ! ls "$mount_point" &>/dev/null; then
        log_warning "Mount point has I/O errors. Force cleaning..."
        fusermount -uz "$mount_point" 2>/dev/null || true
        sudo umount -l "$mount_point" 2>/dev/null || true
    fi
    
    # Kill any orphaned sshfs processes for this mount
    local remote_host=$(basename "$mount_point")
    sudo pkill -9 -f "$remote_host:/home/$CURRENT_USER" 2>/dev/null || true
    
    log_success "Mount point cleaned"
}

# Create user systemd service for SSHFS mount
create_user_systemd_service() {
    local remote_host=$1
    local mount_point=$2
    local service_name="sshfs-${remote_host}.service"
    
    log_info "Creating user systemd service: $service_name"
    
    # Create user systemd directory if it doesn't exist
    mkdir -p "$USER_SYSTEMD_DIR"
    
    local service_file="$USER_SYSTEMD_DIR/$service_name"
    
    cat > "$service_file" <<EOF
[Unit]
Description=SSHFS mount to $remote_host
After=network-online.target

[Service]
Type=forking
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/sshfs $CURRENT_USER@$remote_host:$HOME_DIR $mount_point -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3
ExecStop=/bin/fusermount -u $mount_point
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
    
    log_success "User systemd service created: $service_file"
}

# Enable lingering for user
enable_user_lingering() {
    log_info "Enabling lingering for user $CURRENT_USER..."
    
    if sudo loginctl enable-linger "$CURRENT_USER"; then
        log_success "Lingering enabled - services will start at boot without login"
    else
        log_warning "Failed to enable lingering - mounts may only work after login"
    fi
    
    # Verify lingering is enabled
    if loginctl show-user "$CURRENT_USER" 2>/dev/null | grep -q "Linger=yes"; then
        log_success "Verified: Lingering is enabled"
    fi
}

# Setup mount for a remote system
setup_mount() {
    local remote_host=$1
    
    log_info "=========================================="
    log_info "Setting up SSHFS mount for: $remote_host"
    log_info "=========================================="
    
    # Create mount point
    local mount_point="$MOUNT_BASE_DIR/$remote_host"
    create_mount_point "$mount_point"
    
    # Clean up any existing mounts
    cleanup_mount "$mount_point"
    
    # Create user systemd service
    local service_name="sshfs-${remote_host}.service"
    create_user_systemd_service "$remote_host" "$mount_point"
    
    # Reload user systemd
    log_info "Reloading user systemd daemon..."
    systemctl --user daemon-reload
    
    # Enable the service
    log_info "Enabling service to start automatically..."
    systemctl --user enable "$service_name"
    
    # Start the service
    log_info "Starting mount service..."
    if systemctl --user start "$service_name"; then
        # Wait a moment for mount to complete
        sleep 2
        
        # Verify mount
        if mountpoint -q "$mount_point" 2>/dev/null; then
            log_success "Mount started successfully!"
            df -h "$mount_point" | tail -n 1
        else
            log_warning "Service started but mount verification unclear"
            systemctl --user status "$service_name" --no-pager
        fi
    else
        log_error "Failed to start service"
        systemctl --user status "$service_name" --no-pager
    fi
}

# Main function
main() {
    log_info "================================================"
    log_info "SSHFS Auto-Setup Script"
    log_info "================================================"
    log_info "Current system: $CURRENT_HOSTNAME"
    log_info "Current user: $CURRENT_USER"
    log_info "================================================"
    
    # Checks
    check_root
    check_sshfs
    
    # Find available systems
    systems=($(find_systems))
    
    if [ ${#systems[@]} -eq 0 ]; then
        log_warning "No remote systems found in /etc/hosts"
        exit 0
    fi
    
    log_info "Found ${#systems[@]} system(s) in /etc/hosts: ${systems[*]}"
    
    # Test connectivity and setup mounts
    local connected_systems=()
    
    for system in "${systems[@]}"; do
        if test_ssh_connection "$system"; then
            connected_systems+=("$system")
        fi
    done
    
    if [ ${#connected_systems[@]} -eq 0 ]; then
        log_error "No systems with working passwordless SSH found"
        exit 1
    fi
    
    log_info "================================================"
    log_info "Found ${#connected_systems[@]} system(s) with working SSH:"
    for system in "${connected_systems[@]}"; do
        log_info "  - $system"
    done
    log_info "================================================"
    
    # Setup mounts for all connected systems
    for system in "${connected_systems[@]}"; do
        setup_mount "$system"
        echo ""
    done
    
    # Summary
    log_info "================================================"
    log_success "SSHFS setup completed!"
    log_info "================================================"
    log_info "Mounted systems:"
    for system in "${connected_systems[@]}"; do
        log_info "  - $MOUNT_BASE_DIR/$system -> $system:$HOME_DIR"
    done
    log_info "================================================"
    log_info "To check mount status: systemctl status 'home-*-system*.mount'"
    log_info "To manually unmount: sudo systemctl stop home-<user>-<system>.mount"
    log_info "To disable auto-mount: sudo systemctl disable home-<user>-<system>.mount"
    log_info "================================================"
}

# Run main function
main "$@"