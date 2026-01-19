# Security configuration - Firewall and Fail2ban
{ config, lib, pkgs, ... }:

{
  # Firewall - only SSH on public interface
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    # Trust Tailscale interface for all internal traffic
    trustedInterfaces = [ "tailscale0" ];
  };

  # Fail2ban for SSH
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "-1";  # Permanent ban

    jails.sshd = {
      settings = {
        enabled = true;
        port = "ssh";
        filter = "sshd";
        maxretry = 3;
        bantime = "-1";
      };
    };
  };
}
