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

  # Block sensitive ports from non-Tailscale interfaces using iptables
  # extraCommands runs raw iptables commands during firewall activation
  networking.firewall.extraCommands = ''
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 111 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p udp --dport 111 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 6443 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 10250 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9100 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 24007 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9500 -j DROP
  '';

  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 111 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p udp --dport 111 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 6443 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 10250 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9100 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 24007 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9500 -j DROP 2>/dev/null || true
  '';
}
