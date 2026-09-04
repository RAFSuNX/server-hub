{ ... }:

{
  networking.firewall = {
    enable = true;

    # SSH only — all other ports handled via extraCommands below
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

    "kernel.sysrq" = 0;

    # Hide server uptime from external scanners
    "net.ipv4.tcp_timestamps" = 0;

    # Log packets with impossible source addresses
    "net.ipv4.conf.all.log_martians"     = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # Ignore bogus ICMP error responses
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Restrict ptrace to parent→child only
    "kernel.yama.ptrace_scope" = 1;

    # Append PID to core dump filenames, no dumps from SUID programs
    "kernel.core_uses_pid" = 1;
    "fs.suid_dumpable"     = 0;

    # Prevent hardlink/symlink attacks (e.g. /tmp tricks)
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks"  = 1;

    # Null pointer exploit mitigation
    "vm.mmap_min_addr" = 65536;
  };

  # Block unused/dangerous kernel modules (mirrors Debian's modprobe-disable.conf)
  boot.blacklistedKernelModules = [
    "cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "udf"
    "usb_storage"
    "dccp" "sctp" "rds" "tipc"
  ];

  # Block sensitive ports from non-Tailscale interfaces using iptables
  # IMPORTANT: All rules use -I nixos-fw 1 (insert at position 1).
  # Because each insert pushes prior rules down, INSERT ORDER IS REVERSE of evaluation order.
  # To have rule A evaluated before rule B, insert B first, then A.
  # Pattern for each port group: insert DROP first, then ACCEPT rules — so ACCEPTs end up above DROP.
  networking.firewall.extraCommands = ''
    # --- Simple DROP ports (no exceptions needed) ---
    # These are inserted first so they end up below the 9100/9502 ACCEPT rules in the chain.
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 111   -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p udp --dport 111   -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 6443  -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 10250 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 24007 -j DROP
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9500  -j DROP

    # --- node-exporter (9100) ---
    # Insert DROP first, then ACCEPTs — so final chain order is: ACCEPT lo, ACCEPT CIDRs, DROP rest
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9100 -j DROP
    iptables -I nixos-fw 1 -i lo                                       -p tcp --dport 9100 -j nixos-fw-accept
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW -s 10.42.0.0/16  -p tcp --dport 9100 -j nixos-fw-accept
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW -s 10.43.0.0/16  -p tcp --dport 9100 -j nixos-fw-accept
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW -s 100.64.0.0/10 -p tcp --dport 9100 -j nixos-fw-accept

    # --- Longhorn webhook (9502) ---
    # Same pattern: DROP first, then ACCEPTs
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9502 -j DROP
    iptables -I nixos-fw 1 -i lo                                       -p tcp --dport 9502 -j nixos-fw-accept
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW -s 10.42.0.0/16  -p tcp --dport 9502 -j nixos-fw-accept
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW -s 10.43.0.0/16  -p tcp --dport 9502 -j nixos-fw-accept
    iptables -I nixos-fw 1 -m conntrack --ctstate NEW -s 100.64.0.0/10 -p tcp --dport 9502 -j nixos-fw-accept
  '';

  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 111   -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p udp --dport 111   -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 6443  -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 10250 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 24007 -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9500  -j DROP 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9100  -j DROP 2>/dev/null || true
    iptables -D nixos-fw -i lo                                       -p tcp --dport 9100  -j nixos-fw-accept 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW -s 10.42.0.0/16  -p tcp --dport 9100  -j nixos-fw-accept 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW -s 10.43.0.0/16  -p tcp --dport 9100  -j nixos-fw-accept 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW -s 100.64.0.0/10 -p tcp --dport 9100  -j nixos-fw-accept 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW ! -i tailscale0 -p tcp --dport 9502  -j DROP 2>/dev/null || true
    iptables -D nixos-fw -i lo                                       -p tcp --dport 9502  -j nixos-fw-accept 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW -s 10.42.0.0/16  -p tcp --dport 9502  -j nixos-fw-accept 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW -s 10.43.0.0/16  -p tcp --dport 9502  -j nixos-fw-accept 2>/dev/null || true
    iptables -D nixos-fw -m conntrack --ctstate NEW -s 100.64.0.0/10 -p tcp --dport 9502  -j nixos-fw-accept 2>/dev/null || true
  '';

}
