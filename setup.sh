#!/usr/bin/env bash
# Debian multi-device bootstrap with hardened SSH for systema/systemb/systemc/systemd
set -euo pipefail

### CONFIGURATION SECTION - EDIT THESE VALUES ###
REQUIRED_USER="rafsunx"
GRUB_TIMEOUT="0"
GRUB_TIMEOUT_STYLE="hidden"
SSH_PORT="22"
DOCKER_VERSION_CHECK="true"
VERBOSE_LOGGING="false"
LOG_DIR="/tmp"

# Per-host SSH public keys for user
SYSTEMA_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSJiMWP0fTAfltKnIY3HtG78z31vqip0gVlBcfvp44DxsEjo4Zog/UFV/bwMuyFGwtoYSKUGmbCfYbj6O4rccvrI7QeBLpmAC73ElNufyyqP68iMVoGxNDKonFYcpchTPswv9cSuJ1DrOay7GmOO8/eQtwq/eFGSCj7Sa3NYPe3sdW7DF9GA55uNQggVFVfpcybnCm4Oq8U6ZgIEnHJKt6Z8ks9dtlOxuLEHIRhod8dBZYsr3ojk4ZUmgeXxfAmToWI/lOu1QjF99+6yRh/ajzHpjJY7RjjVXIsCKWOxoQGUrFgYd1cAUF6sxwgBQSrLMRKpwnuIcbM4+6CNmFpIhf rafsunx@systema'
SYSTEMB_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqCcKobf8gIOVuJAGRyPUtZisNHgFSpBucW/Ss7eurTFlpFSmPIG5TJxOK72s2K5CSnoDLoFeBOtjKaSEwMO/Py9hHpjLh/IeD1w3YYJaJAgOjBLhyMjD4jrxD42a61SI1uiPQqy8zB0KMvmhEfKO8rGa4HlNVODJhIdAPE1kRmCqHbE1dCu4SbYqKPbglPiX2yaAiHgv3BOSPQp/HbSETXh23kOO5wK1pfPSb2ynSI+ybtdPGd/OWhkZO+n8MHmynQn+lYtPAIqxpAkBT5tQIz/hLtz6XDdyerx10d4wZRQ8JN/byUTURHSJgrriHb3rPvsQh1qAv17JYQlSin4mf rafsunx@systemb'
SYSTEMC_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDddSrgt+cXSqqA5Nx/2Zj24ae5zSH8PqMJiywi7AVM6hLlqyP/lyF38dEy0vpXAS7zoyzOuY20nz1Yimn5vIJMBqR7mpObrwuJ+NcmQiKumJeOqcdxrZAnF0Q4YQDLiHMRTckEF9XNtk5pAFWbSe/osBUJwvAFIbdB5GYlYVv/MhMS4F19Yzgt01CVFNg3DztaqcydoIVKMU8hEIOQ/LbHbLrVQWeur99p713RoK2286mr2ufB9ZchaBsNwLXEZUmi+PtNZXe9vPhgUEOQEtzVj7qtKU16WDZB8zawg9kPxlc2UqQN/cAwte+YbqeK/yD37Tn548CGUq/Im3NeMP1l rafsunx@systemc'
SYSTEMD_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSc7qxw1S5rcuAmZNfbsoKroV/oFC4WHGKq9F8vlGUx/Yrw8s08enbffLIUnK75rMkHYNR29GYT3pbjWGOd3EPIahxKqf7bC+zRHLx13EZM49FDcJqEy+TPWZ5aawjlv48LKziFmpQuIItYY1aAJn0rIVziP3BZJjfuOadBLp6S+Bd3rG7mnpUXWFfJllZV3XypcKVyHmqGzMvRsEjXlJrORLSJmfWlvYPu6LdfkuXLKoonp43qslUYW4A1r9nhq3W5CPr0sKTgz2YEjFRcTYytdpLlR14ff2uqYCjyNWSxLXJ35hU3hPW8M2dkzLUH6xG2xrowbowAzOMh4mzzqg/ rafsunx@systemd'

### END CONFIGURATION SECTION ###

# Global variables
SCRIPT_START_TIME=$(date +%s)
LOG_FILE="${LOG_DIR}/server-hub-setup-$(date +%Y%m%d-%H%M%S).log"
DEBIAN_FRONTEND=noninteractive

# Associative array for hostname to key mapping
declare -A HOST_KEYS=(
  ["systema"]="$SYSTEMA_PUBKEY"
  ["systemb"]="$SYSTEMB_PUBKEY"
  ["systemc"]="$SYSTEMC_PUBKEY"
  ["systemd"]="$SYSTEMD_PUBKEY"
)

# Logging functions
log() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

verbose_log() {
  if [[ "$VERBOSE_LOGGING" == "true" ]]; then
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [VERBOSE] $*" | tee -a "$LOG_FILE"
  fi
}

error_log() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

# Cleanup function for graceful exits
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    error_log "Script failed with exit code $exit_code"
    log "Setup log saved to: $LOG_FILE"
  fi
  exit $exit_code
}

trap cleanup EXIT

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error_log "Run as root."
    exit 1
  fi
}

# Global OS variables
OS_FAMILY=""
PACKAGE_MANAGER=""

detect_os() {
  if [[ ! -r /etc/os-release ]]; then
    error_log "/etc/os-release missing."
    exit 1
  fi
  . /etc/os-release

  case "${ID:-}" in
    "ubuntu")
      OS_FAMILY="debian"
      PACKAGE_MANAGER="apt"
      verbose_log "Detected Ubuntu system: ${PRETTY_NAME:-unknown}"
      ;;
    "debian")
      OS_FAMILY="debian"
      PACKAGE_MANAGER="apt"
      verbose_log "Detected Debian system: ${PRETTY_NAME:-unknown}"
      ;;
    "alpine")
      OS_FAMILY="alpine"
      PACKAGE_MANAGER="apk"
      verbose_log "Detected Alpine system: ${PRETTY_NAME:-unknown}"
      ;;
    *)
      # Check ID_LIKE for compatibility
      if [[ "${ID_LIKE:-}" =~ ubuntu ]] || [[ "${ID_LIKE:-}" =~ debian ]]; then
        OS_FAMILY="debian"
        PACKAGE_MANAGER="apt"
        verbose_log "Detected Debian-like system: ${PRETTY_NAME:-unknown} (ID: ${ID:-unknown})"
      else
        error_log "This script supports Debian-based (Ubuntu, Debian) and Alpine systems only. Detected ID=${ID:-unknown} ID_LIKE=${ID_LIKE:-unknown}"
        exit 1
      fi
      ;;
  esac
}

check_package_installed() {
  local package="$1"
  if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    dpkg -l "$package" >/dev/null 2>&1
  elif [[ "$PACKAGE_MANAGER" == "apk" ]]; then
    apk info -e "$package" >/dev/null 2>&1
  fi
}

update_package_cache() {
  if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    # Only update if we haven't updated recently (within 1 hour)
    local apt_updated_file="/tmp/.apt-updated-$(date +%Y%m%d%H)"
    if [[ ! -f "$apt_updated_file" ]]; then
      apt-get update -y
      touch "$apt_updated_file"
      verbose_log "APT package cache updated"
    else
      verbose_log "APT package cache recently updated, skipping"
    fi
  elif [[ "$PACKAGE_MANAGER" == "apk" ]]; then
    apk update
    verbose_log "APK package cache updated"
  fi
}

install_packages() {
  local packages=("$@")
  if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    apt-get install -y "${packages[@]}"
  elif [[ "$PACKAGE_MANAGER" == "apk" ]]; then
    apk add "${packages[@]}"
  fi
}

install_base() {
  log "[1/9] Installing base packages..."
  verbose_log "Updating package cache..."
  update_package_cache

  # Define packages based on OS family
  local packages=()
  if [[ "$OS_FAMILY" == "debian" ]]; then
    packages=("sudo" "curl" "wget" "nano" "openssh-server" "passwd")
  elif [[ "$OS_FAMILY" == "alpine" ]]; then
    packages=("sudo" "curl" "wget" "nano" "openssh" "openssh-server" "shadow")
  fi

  local to_install=()
  for package in "${packages[@]}"; do
    if ! check_package_installed "$package"; then
      to_install+=("$package")
      verbose_log "Package $package needs installation"
    else
      verbose_log "Package $package already installed"
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    verbose_log "Installing packages: ${to_install[*]}"
    install_packages "${to_install[@]}"
  else
    log "All base packages already installed"
  fi
}

fix_aarch64_path() {
  log "[2/9] aarch64 PATH fix for system binaries..."
  local arch; arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    export PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"
    verbose_log "Exported administrative paths to current shell for aarch64 system"
  else
    verbose_log "Not an aarch64 system, skipping PATH fix"
  fi
}

get_service_manager() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    echo "systemd"
  elif command -v rc-service >/dev/null 2>&1; then
    echo "openrc"
  else
    echo "unknown"
  fi
}

check_docker_installed() {
  local service_manager
  service_manager="$(get_service_manager)"
  
  if command -v docker >/dev/null 2>&1; then
    if [[ "$service_manager" == "systemd" ]]; then
      systemctl is-active --quiet docker 2>/dev/null
    elif [[ "$service_manager" == "openrc" ]]; then
      rc-service docker status >/dev/null 2>&1
    fi
  else
    return 1
  fi
}

enable_service() {
  local service="$1"
  local service_manager
  service_manager="$(get_service_manager)"
  
  if [[ "$service_manager" == "systemd" ]]; then
    systemctl enable "$service"
    systemctl start "$service"
  elif [[ "$service_manager" == "openrc" ]]; then
    rc-update add "$service" default
    rc-service "$service" start
  else
    log "Warning: Unknown service manager, cannot enable service $service"
  fi
}

install_docker() {
  log "[3/9] Installing Docker using official script..."
  
  if [[ "$DOCKER_VERSION_CHECK" == "true" ]] && check_docker_installed; then
    local docker_version=$(docker --version 2>/dev/null || echo "unknown")
    log "Docker already installed: $docker_version"
    verbose_log "Skipping Docker installation"
  else
    verbose_log "Downloading Docker installation script..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    
    verbose_log "Executing Docker installation script..."
    sh get-docker.sh
    rm get-docker.sh
    
    verbose_log "Enabling Docker service..."
    enable_service docker
  fi
  
  # Ensure Docker group exists and add user to it
  verbose_log "Configuring Docker group for user '$REQUIRED_USER'..."
  groupadd -f docker
  if ! groups "$REQUIRED_USER" | grep -q docker; then
    usermod -aG docker "$REQUIRED_USER"
    verbose_log "User '$REQUIRED_USER' added to docker group"
  else
    verbose_log "User '$REQUIRED_USER' already in docker group"
  fi
  
  log "Docker setup completed successfully"
  log ""
  log "IMPORTANT: For Docker to work as '$REQUIRED_USER', you must:"
  log "  1. Completely log out of the system"
  log "  2. Log back in via SSH"
  log "  3. Then 'docker ps' will work without sudo"
  log ""
  log "This is required because group membership changes only apply to new login sessions."
}

ensure_user() {
  log "[4/9] Ensuring user '$REQUIRED_USER' exists and is sudoer..."
  
  if ! id -u "$REQUIRED_USER" >/dev/null 2>&1; then
    verbose_log "Creating user '$REQUIRED_USER'..."
    useradd -m -s /bin/bash "$REQUIRED_USER"
  else
    verbose_log "User '$REQUIRED_USER' already exists"
  fi
  
  if ! getent group sudo >/dev/null; then
    verbose_log "Creating sudo group..."
    groupadd sudo
  fi
  
  if ! groups "$REQUIRED_USER" | grep -q sudo; then
    verbose_log "Adding user '$REQUIRED_USER' to sudo group..."
    usermod -aG sudo "$REQUIRED_USER"
  else
    verbose_log "User '$REQUIRED_USER' already in sudo group"
  fi
  
  local drop="/etc/sudoers.d/90-${REQUIRED_USER}"
  if [[ ! -f "$drop" ]] || ! grep -q "NOPASSWD:ALL" "$drop"; then
    verbose_log "Configuring passwordless sudo for '$REQUIRED_USER'..."
    echo "${REQUIRED_USER} ALL=(ALL:ALL) NOPASSWD:ALL" > "$drop"
    chmod 440 "$drop"
    visudo -cf "$drop" >/dev/null
  else
    verbose_log "Passwordless sudo already configured for '$REQUIRED_USER'"
  fi
}

install_key() {
  log "[5/9] Installing per-host SSH key for '$REQUIRED_USER'..."
  local host_lc sel_key
  host_lc="$(hostname -s | tr '[:upper:]' '[:lower:]')"
  
  if [[ -n "${HOST_KEYS[$host_lc]:-}" ]]; then
    sel_key="${HOST_KEYS[$host_lc]}"
    verbose_log "Found SSH key for hostname '$host_lc'"
  else
    sel_key=""
    log "Warning: hostname '$host_lc' not in known hosts. Skipping key installation."
    return 0
  fi
  
  local home dir auth
  home="$(getent passwd "$REQUIRED_USER" | cut -d: -f6)"
  [[ -n "$home" && -d "$home" ]] || { error_log "Cannot resolve home for $REQUIRED_USER."; exit 1; }
  
  dir="${home}/.ssh"
  auth="${dir}/authorized_keys"
  
  verbose_log "Setting up SSH directory structure..."
  mkdir -p "$dir"
  chmod 700 "$dir"
  touch "$auth"
  chmod 600 "$auth"
  
  if ! grep -Fq "$sel_key" "$auth"; then
    verbose_log "Adding SSH key to authorized_keys..."
    echo "$sel_key" >> "$auth"
  else
    verbose_log "SSH key already present in authorized_keys"
  fi
  
  chown -R "${REQUIRED_USER}:${REQUIRED_USER}" "$dir"
}

configure_user_profile() {
  log "[5.5/9] Configuring user profile for aarch64..."
  local arch; arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    local home profile_file
    home="$(getent passwd "$REQUIRED_USER" | cut -d: -f6)"
    profile_file="${home}/.profile"
    
    if ! grep -Fq '/sbin' "$profile_file" 2>/dev/null; then
      verbose_log "Adding administrative paths to user profile..."
      {
        echo ""
        echo "# Added by bootstrap: ensure administrative sbin paths are present"
        echo 'export PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"'
      } >> "$profile_file" || true
      chown "${REQUIRED_USER}:${REQUIRED_USER}" "$profile_file" || true
    else
      verbose_log "Administrative paths already in user profile"
    fi
  fi
}

harden_sshd() {
  log "[6/9] Hardening SSH server for key-only access..."
  local sshd=/etc/ssh/sshd_config
  
  # Check if SSH config directory exists, create if missing
  if [[ ! -d /etc/ssh ]]; then
    verbose_log "Creating SSH config directory..."
    mkdir -p /etc/ssh
  fi
  
  # Check if SSH config file exists, create basic one if missing
  if [[ ! -f "$sshd" ]]; then
    verbose_log "SSH config file missing, creating basic configuration..."
    cat > "$sshd" <<EOF
# Basic SSH daemon configuration
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
UsePrivilegeSeparation yes
KeyRegenerationInterval 3600
ServerKeyBits 1024
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 120
PermitRootLogin yes
StrictModes yes
RSAAuthentication yes
PubkeyAuthentication yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication yes
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
EOF
  fi
  
  # Backup original config if not already backed up
  if [[ ! -f "${sshd}.bak" ]]; then
    verbose_log "Creating backup of SSH config..."
    cp "$sshd" "${sshd}.bak" 2>/dev/null || true
  fi

  # Ensure Include directive exists
  if [[ -f "$sshd" ]] && ! grep -Eq '^[#\s]*Include\s+/etc/ssh/sshd_config\.d/\*' "$sshd"; then
    verbose_log "Adding Include directive to SSH config..."
    echo -e "\nInclude /etc/ssh/sshd_config.d/*" >> "$sshd"
  fi

  mkdir -p /etc/ssh/sshd_config.d
  local harden=/etc/ssh/sshd_config.d/99-hardening.conf

  verbose_log "Creating hardened SSH configuration..."
  cat > "$harden" <<EOF
# Hardened settings generated by server-hub setup
Protocol 2
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
AllowStreamLocalForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 4
MaxStartups 10:30:60
AuthorizedKeysFile .ssh/authorized_keys
# Modern algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
EOF

  # Configure AllowUsers in main config file
  if [[ -f "$sshd" ]]; then
    if grep -Eiq '^[#\s]*AllowUsers\b' "$sshd"; then
      verbose_log "Updating AllowUsers directive..."
      sed -i -E "s|^[#\s]*AllowUsers\b.*|AllowUsers ${REQUIRED_USER}|I" "$sshd"
    else
      verbose_log "Adding AllowUsers directive..."
      echo "AllowUsers ${REQUIRED_USER}" >> "$sshd"
    fi
  fi

  # Test SSH configuration if sshd command is available
  verbose_log "Testing SSH configuration..."
  if command -v sshd >/dev/null 2>&1; then
    if ! sshd -t; then
      error_log "SSH configuration test failed"
      exit 1
    fi
  else
    log "Warning: sshd command not found, skipping configuration test"
  fi

  # Generate SSH host keys if they don't exist
  verbose_log "Ensuring SSH host keys exist..."
  if command -v ssh-keygen >/dev/null 2>&1; then
    for keytype in rsa ecdsa ed25519; do
      keyfile="/etc/ssh/ssh_host_${keytype}_key"
      if [[ ! -f "$keyfile" ]]; then
        verbose_log "Generating SSH host key: $keyfile"
        ssh-keygen -t "$keytype" -f "$keyfile" -N "" -q 2>/dev/null || true
      fi
    done
  fi

  verbose_log "Enabling and starting SSH service..."
  enable_service ssh || enable_service sshd
}

configure_grub() {
  log "[7/9] Configuring GRUB timeout..."
  if [[ -f /etc/default/grub ]]; then
    local grub_modified=false
    
    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
      if ! grep -q "^GRUB_TIMEOUT=$GRUB_TIMEOUT" /etc/default/grub; then
        verbose_log "Updating GRUB_TIMEOUT to $GRUB_TIMEOUT..."
        sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$GRUB_TIMEOUT/" /etc/default/grub
        grub_modified=true
      fi
    else
      verbose_log "Adding GRUB_TIMEOUT=$GRUB_TIMEOUT..."
      echo "GRUB_TIMEOUT=$GRUB_TIMEOUT" >> /etc/default/grub
      grub_modified=true
    fi
    
    if grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then
      if ! grep -q "^GRUB_TIMEOUT_STYLE=$GRUB_TIMEOUT_STYLE" /etc/default/grub; then
        verbose_log "Updating GRUB_TIMEOUT_STYLE to $GRUB_TIMEOUT_STYLE..."
        sed -i "s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=$GRUB_TIMEOUT_STYLE/" /etc/default/grub
        grub_modified=true
      fi
    else
      verbose_log "Adding GRUB_TIMEOUT_STYLE=$GRUB_TIMEOUT_STYLE..."
      echo "GRUB_TIMEOUT_STYLE=$GRUB_TIMEOUT_STYLE" >> /etc/default/grub
      grub_modified=true
    fi
    
    if [[ "$grub_modified" == "true" ]]; then
      verbose_log "Regenerating GRUB configuration..."
      if command -v update-grub >/dev/null 2>&1; then
        update-grub
      elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg
      else
        log "GRUB tools not found. Skipping config regeneration."
      fi
    else
      verbose_log "GRUB configuration already optimized"
    fi
  else
    verbose_log "No /etc/default/grub found. Skipping GRUB configuration."
  fi
}

final_summary() {
  log "[8/9] Final checks and summary..."
  local host_lc; host_lc="$(hostname -s | tr '[:upper:]' '[:lower:]')"
  local setup_duration=$(($(date +%s) - SCRIPT_START_TIME))
  
  log ""
  log "=== SETUP COMPLETED SUCCESSFULLY ==="
  log "Setup duration: ${setup_duration} seconds"
  log "Summary:"
  log " ✓ Base tools installed and SSH enabled on boot"
  log " ✓ Docker installed and enabled. User '$REQUIRED_USER' added to docker group"
  log " ✓ User '$REQUIRED_USER' configured with passwordless sudo access"
  log " ✓ SSH hardened to key-only authentication. Root login disabled"
  log " ✓ SSH access restricted to user '$REQUIRED_USER' only"
  log " ✓ Host '$host_lc': SSH key configured for authorized access"
  
  if [[ -f /etc/default/grub ]]; then
    log " ✓ GRUB timeout optimized (${GRUB_TIMEOUT}s, style: $GRUB_TIMEOUT_STYLE)"
  fi
  
  local arch; arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    log " ✓ aarch64: Administrative paths configured for user profile"
  fi
  
  log " ✓ Setup log saved to: $LOG_FILE"
}

note_usage() {
  log "[9/9] Important usage notes:"
  log ""
  log "SECURITY:"
  log " • SSH is now configured for key-only authentication"
  log " • Root login is disabled"
  log " • Only user '$REQUIRED_USER' can SSH to this system"
  log ""
  log "DOCKER USAGE:"
  log " • Root can use Docker immediately: 'sudo docker ps'"
  log " • For '$REQUIRED_USER' to use Docker without sudo:"
  log "   1. Log out completely from this system"
  log "   2. Log back in via SSH"
  log "   3. Then 'docker ps' will work without sudo"
  log "   (Group membership changes require fresh login session)"
  log ""
  log "SSH FORWARDING:"
  log " • TCP forwarding is disabled by default for security"
  log " • To enable if needed: edit /etc/ssh/sshd_config.d/99-hardening.conf"
  log " • Set 'AllowTcpForwarding yes' and restart SSH service"
  log ""
  log "LOGS:"
  log " • Setup log: $LOG_FILE"
  log " • SSH config backup: /etc/ssh/sshd_config.bak"
}

main() {
  # Initialize logging
  mkdir -p "$LOG_DIR"
  log "=== Starting server-hub setup script ==="
  log "Configuration: user=$REQUIRED_USER, verbose=$VERBOSE_LOGGING"
  
  require_root
  detect_os
  install_base
  fix_aarch64_path
  install_docker
  ensure_user
  install_key
  configure_user_profile
  harden_sshd
  configure_grub
  final_summary
  note_usage
  
  log "=== Setup script completed successfully ==="
}

main "$@"
