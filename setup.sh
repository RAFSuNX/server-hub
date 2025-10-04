#!/usr/bin/env bash
# Debian multi-device bootstrap with hardened SSH for systema/systemb/systemc/systemd
set -euo pipefail

### EDIT THESE: per-host SSH public keys for user 'rafsunx'
SYSTEMA_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSJiMWP0fTAfltKnIY3HtG78z31vqip0gVlBcfvp44DxsEjo4Zog/UFV/bwMuyFGwtoYSKUGmbCfYbj6O4rccvrI7QeBLpmAC73ElNufyyqP68iMVoGxNDKonFYcpchTPswv9cSuJ1DrOay7GmOO8/eQtwq/eFGSCj7Sa3NYPe3sdW7DF9GA55uNQggVFVfpcybnCm4Oq8U6ZgIEnHJKt6Z8ks9dtlOxuLEHIRhod8dBZYsr3ojk4ZUmgeXxfAmToWI/lOu1QjF99+6yRh/ajzHpjJY7RjjVXIsCKWOxoQGUrFgYd1cAUF6sxwgBQSrLMRKpwnuIcbM4+6CNmFpIhf rafsunx@systema'
SYSTEMB_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqCcKobf8gIOVuJAGRyPUtZisNHgFSpBucW/Ss7eurTFlpFSmPIG5TJxOK72s2K5CSnoDLoFeBOtjKaSEwMO/Py9hHpjLh/IeD1w3YYJaJAgOjBLhyMjD4jrxD42a61SI1uiPQqy8zB0KMvmhEfKO8rGa4HlNVODJhIdAPE1kRmCqHbE1dCu4SbYqKPbglPiX2yaAiHgv3BOSPQp/HbSETXh23kOO5wK1pfPSb2ynSI+ybtdPGd/OWhkZO+n8MHmynQn+lYtPAIqxpAkBT5tQIz/hLtz6XDdyerx10d4wZRQ8JN/byUTURHSJgrriHb3rPvsQh1qAv17JYQlSin4mf rafsunx@systemb'
SYSTEMC_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDddSrgt+cXSqqA5Nx/2Zj24ae5zSH8PqMJiywi7AVM6hLlqyP/lyF38dEy0vpXAS7zoyzOuY20nz1Yimn5vIJMBqR7mpObrwuJ+NcmQiKumJeOqcdxrZAnF0Q4YQDLiHMRTckEF9XNtk5pAFWbSe/osBUJwvAFIbdB5GYlYVv/MhMS4F19Yzgt01CVFNg3DztaqcydoIVKMU8hEIOQ/LbHbLrVQWeur99p713RoK2286mr2ufB9ZchaBsNwLXEZUmi+PtNZXe9vPhgUEOQEtzVj7qtKU16WDZB8zawg9kPxlc2UqQN/cAwte+YbqeK/yD37Tn548CGUq/Im3NeMP1l rafsunx@systemc'
SYSTEMD_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSc7qxw1S5rcuAmZNfbsoKroV/oFC4WHGKq9F8vlGUx/Yrw8s08enbffLIUnK75rMkHYNR29GYT3pbjWGOd3EPIahxKqf7bC+zRHLx13EZM49FDcJqEy+TPWZ5aawjlv48LKziFmpQuIItYY1aAJn0rIVziP3BZJjfuOadBLp6S+Bd3rG7mnpUXWFfJllZV3XypcKVyHmqGzMvRsEjXlJrORLSJmfWlvYPu6LdfkuXLKoonp43qslUYW4A1r9nhq3W5CPr0sKTgz2YEjFRcTYytdpLlR14ff2uqYCjyNWSxLXJ35hU3hPW8M2dkzLUH6xG2xrowbowAzOMh4mzzqg/ rafsunx@systemd'

REQUIRED_USER="rafsunx"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run as root." >&2
    exit 1
  fi
}

detect_debian() {
  if [[ ! -r /etc/os-release ]]; then
    echo "/etc/os-release missing." >&2
    exit 1
  fi
  . /etc/os-release
  if [[ "${ID:-}" == "debian" || "${ID_LIKE:-}" =~ debian ]]; then
    return 0
  fi
  echo "This script supports Debian or Debian-like only. Detected ID=${ID:-unknown} ID_LIKE=${ID_LIKE:-unknown}" >&2
  exit 1
}

install_base() {
  echo "[1/9] Installing base packages..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y sudo curl wget nano openssh-server passwd
}

install_docker() {
  echo "[3/9] Installing Docker using official script..."
  # Download and execute Docker's official installation script
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
  
  # Enable and start Docker service
  systemctl enable docker
  systemctl start docker
  
  # Ensure Docker group exists and add user to it
  groupadd -f docker
  usermod -aG docker "$REQUIRED_USER"
  
  echo "Docker installed successfully. User '${REQUIRED_USER}' added to docker group."
  echo ""
  echo "IMPORTANT: For Docker to work as '${REQUIRED_USER}', you must:"
  echo "  1. Completely log out of the system"
  echo "  2. Log back in via SSH"
  echo "  3. Then 'docker ps' will work without sudo"
  echo ""
  echo "This is required because group membership changes only apply to new login sessions."
}

ensure_user() {
  echo "[4/9] Ensuring user '${REQUIRED_USER}' exists and is sudoer..."
  if ! id -u "$REQUIRED_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$REQUIRED_USER"
  fi
  if ! getent group sudo >/dev/null; then
    groupadd sudo
  fi
  usermod -aG sudo "$REQUIRED_USER"
  local drop="/etc/sudoers.d/90-${REQUIRED_USER}"
  echo "${REQUIRED_USER} ALL=(ALL:ALL) NOPASSWD:ALL" > "$drop"
  chmod 440 "$drop"
  visudo -cf "$drop" >/dev/null
}

install_key() {
  echo "[5/9] Installing per-host SSH key for '${REQUIRED_USER}'..."
  local host_lc sel_key
  host_lc="$(hostname -s | tr '[:upper:]' '[:lower:]')"
  case "$host_lc" in
    systema) sel_key="$SYSTEMA_PUBKEY" ;;
    systemb) sel_key="$SYSTEMB_PUBKEY" ;;
    systemc) sel_key="$SYSTEMC_PUBKEY" ;;
    systemd) sel_key="$SYSTEMD_PUBKEY" ;;
    *) sel_key=""; echo "Warning: hostname '$host_lc' not in {systema,systemb,systemc,systemd}. Skipping key append." ;;
  esac
  local home dir auth
  home="$(getent passwd "$REQUIRED_USER" | cut -d: -f6)"
  [[ -n "$home" && -d "$home" ]] || { echo "Cannot resolve home for ${REQUIRED_USER}." >&2; exit 1; }
  dir="${home}/.ssh"; auth="${dir}/authorized_keys"
  mkdir -p "$dir"; chmod 700 "$dir"; touch "$auth"; chmod 600 "$auth"
  if [[ -n "$sel_key" ]] && ! grep -Fq "$sel_key" "$auth"; then
    echo "$sel_key" >> "$auth"
  fi
  chown -R "${REQUIRED_USER}:${REQUIRED_USER}" "$dir"
}

fix_aarch64_path() {
  echo "[2/9] aarch64 PATH fix for system binaries..."
  local arch; arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    # Ensure current shell sees the paths for subsequent commands
    export PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"
    echo "Exported administrative paths to current shell for aarch64 system"
  fi
}

configure_user_profile() {
  echo "[5.5/9] Configuring user profile for aarch64..."
  local arch; arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    local home profile_file
    home="$(getent passwd "$REQUIRED_USER" | cut -d: -f6)"
    profile_file="${home}/.profile"
    if ! grep -Fq '/sbin' "$profile_file" 2>/dev/null; then
      {
        echo ""
        echo "# Added by bootstrap: ensure administrative sbin paths are present"
        echo 'export PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"'
      } >> "$profile_file" || true
      chown "${REQUIRED_USER}:${REQUIRED_USER}" "$profile_file" || true
      echo "Added administrative paths to ${REQUIRED_USER} profile"
    fi
  fi
}

harden_sshd() {
  echo "[6/9] Hardening SSH server for key-only access..."
  local sshd=/etc/ssh/sshd_config
  [[ -f "${sshd}.bak" ]] || cp "$sshd" "${sshd}.bak" 2>/dev/null || true

  if ! grep -Eq '^[#\s]*Include\s+/etc/ssh/sshd_config\.d/\*' "$sshd"; then
    echo -e "\nInclude /etc/ssh/sshd_config.d/*" >> "$sshd"
  fi

  mkdir -p /etc/ssh/sshd_config.d
  local harden=/etc/ssh/sshd_config.d/99-hardening.conf

  cat > "$harden" <<'EOF'
# Hardened settings
Protocol 2
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

  if grep -Eiq '^[#\s]*AllowUsers\b' "$sshd"; then
    sed -i -E "s|^[#\s]*AllowUsers\b.*|AllowUsers ${REQUIRED_USER}|I" "$sshd"
  else
    echo "AllowUsers ${REQUIRED_USER}" >> "$sshd"
  fi

  sshd -t
  systemctl enable ssh
  systemctl restart ssh
}

configure_grub() {
  echo "[7/9] Configuring GRUB timeout..."
  if [[ -f /etc/default/grub ]]; then
    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
      sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
    else
      echo 'GRUB_TIMEOUT=0' >> /etc/default/grub
    fi
    if grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then
      sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    else
      echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub
    fi
    if command -v update-grub >/dev/null 2>&1; then
      update-grub
    elif command -v grub-mkconfig >/dev/null 2>&1; then
      grub-mkconfig -o /boot/grub/grub.cfg
    else
      echo "GRUB tools not found. Skipping config regeneration." >&2
    fi
  else
    echo "No /etc/default/grub. Skipping."
  fi
}

final_summary() {
  echo "[8/9] Final checks..."
  local host_lc; host_lc="$(hostname -s | tr '[:upper:]' '[:lower:]')"
  echo
  echo "Done."
  echo "Summary:"
  echo " - Base tools installed and ssh enabled on boot"
  echo " - Docker installed and enabled. User '${REQUIRED_USER}' added to docker group"
  echo " - User '${REQUIRED_USER}' ensured and added to sudo with passwordless access"
  echo " - SSH hardened to key-only. Root login disabled. Only '${REQUIRED_USER}' allowed"
  echo " - Host '${host_lc}': authorized_keys updated if a matching key variable was set"
  if [[ -f /etc/default/grub ]]; then
    echo " - GRUB timeout set to 0 and config regenerated"
  else
    echo " - GRUB not detected or not standard. Skipped"
  fi
  local arch; arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    echo " - aarch64: sbin paths appended to ${REQUIRED_USER} profile and exported for this run"
  fi
}

note_usage() {
  echo "[9/9] Usage note:"
  echo " After confirming key based login for '${REQUIRED_USER}', you are already on key only mode."
  echo " If you need SSH forwarding later, set AllowTcpForwarding yes in /etc/ssh/sshd_config.d/99-hardening.conf and restart ssh."
  echo ""
  echo " DOCKER USAGE:"
  echo " - Root can use Docker immediately: 'sudo docker ps'"
  echo " - For '${REQUIRED_USER}' to use Docker without sudo, you MUST completely log out and log back in"
  echo " - This is required because group membership changes only apply to new login sessions"
  echo " - After fresh login: 'docker ps' will work without sudo"
}

main() {
  require_root
  detect_debian
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
}

main "$@"
