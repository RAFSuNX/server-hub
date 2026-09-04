{ ... }:

{
  networking.firewall = {
    allowedTCPPorts  = [ 22 ];
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

  # Allow node-exporter and Longhorn webhook from local pods (cni0).
  # Cross-node pod traffic arrives on tailscale0 which is already trusted.
  # All other non-SSH ports are blocked by the default DROP input policy.
  networking.firewall.interfaces."cni0".allowedTCPPorts = [ 9100 9502 ];

}
