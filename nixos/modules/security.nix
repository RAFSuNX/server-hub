{ config, lib, pkgs, ... }:

{
  networking.firewall = {
    enable = true;

    # Public interface: SSH only
    allowedTCPPorts = [ 22 ];

    # Tailscale VPN fully trusted — all cluster traffic (k3s, GlusterFS, DRBD) uses Tailscale
    trustedInterfaces = [ "tailscale0" ];
  };

  # Kernel hardening
  boot.kernel.sysctl = {
    # Disable ICMP redirects — prevent routing table manipulation
    "net.ipv4.conf.all.accept_redirects"    = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects"    = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects"      = 0;
    "net.ipv4.conf.default.send_redirects"  = 0;

    # Reverse path filtering — drop spoofed packets
    "net.ipv4.conf.all.rp_filter"     = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    # SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;

    # Disable source routing
    "net.ipv4.conf.all.accept_source_route"    = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;

    # Restrict kernel pointer and dmesg exposure
    "kernel.kptr_restrict"   = 2;
    "kernel.dmesg_restrict"  = 1;

    # Full ASLR
    "kernel.randomize_va_space" = 2;

    # Ignore broadcast ICMP (smurf attack prevention)
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # Disable keyboard interactive auth path (belt-and-suspenders)
    "kernel.sysrq" = 0;
  };

  # Restrict rpcbind to Tailscale interface only (required by GlusterFS)
  # Binding to specific interface not supported directly — use firewall to block public access
  networking.firewall.extraInputRules = ''
    # Block port 111 (rpcbind) from non-Tailscale interfaces
    iifname != "tailscale0" tcp dport 111 drop
    iifname != "tailscale0" udp dport 111 drop

    # Block k3s API server from non-Tailscale interfaces
    iifname != "tailscale0" tcp dport 6443 drop

    # Block kubelet from non-Tailscale interfaces
    iifname != "tailscale0" tcp dport 10250 drop

    # Block node-exporter metrics from non-Tailscale interfaces
    iifname != "tailscale0" tcp dport 9100 drop

    # Block Longhorn ports from non-Tailscale interfaces
    iifname != "tailscale0" tcp dport 24007 drop
    iifname != "tailscale0" tcp dport 9500 drop
  '';
}
