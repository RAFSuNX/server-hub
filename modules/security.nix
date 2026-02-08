# =============================================================================
# Security Configuration
# =============================================================================
# Firewall and intrusion prevention configuration.
#
# Security Model:
#   - Public interface: Only SSH (port 22) allowed
#   - Tailscale VPN: Fully trusted (all ports allowed)
#   - Fail2ban: Permanent ban after 3 failed SSH attempts
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{ config, lib, pkgs, ... }:

{
  # ===========================================================================
  # Firewall Configuration
  # ===========================================================================

  networking.firewall = {
    enable = true;

    # Public interface: SSH only
    allowedTCPPorts = [ 22 ];

    # Fully trust Tailscale VPN interface
    # All internal cluster traffic (k3s, GlusterFS, etc.) uses Tailscale
    trustedInterfaces = [ "tailscale0" ];
  };

  # ===========================================================================
  # Intrusion Prevention
  # ===========================================================================

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "-1";  # Permanent ban (never auto-unban)

    # SSH jail configuration
    jails.sshd = {
      settings = {
        enabled = true;
        port = "ssh";
        filter = "sshd";
        maxretry = 3;
        bantime = "-1";  # Permanent ban
      };
    };
  };
}
