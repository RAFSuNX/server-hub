{ config, lib, pkgs, ... }:

{
  networking.firewall = {
    enable = true;

    # Public interface: SSH only
    allowedTCPPorts = [ 22 ];

    # Tailscale VPN fully trusted — all cluster traffic (k3s, GlusterFS, DRBD) uses Tailscale
    trustedInterfaces = [ "tailscale0" ];
  };
}
