{ config, lib, pkgs, nodeIPs, ... }:

{
  # Boot
  boot.loader = {
    systemd-boot = {
      enable             = true;
      configurationLimit = 1;
    };
    efi.canTouchEfiVariables = true;
    timeout = 0;
  };

  # Networking
  networking.networkmanager.enable = true;

  # Tailscale hostname resolution — each node maps the other two, not itself
  networking.hosts = lib.filterAttrs
    (_ip: names: !(builtins.elem config.networking.hostName names))
    (lib.mapAttrs' (name: ip: lib.nameValuePair ip [ name ]) nodeIPs);

  # User — SSH authorized keys defined per-host in hosts/<hostname>/default.nix
  users.users.rafsunx = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  # Fail2ban — permanent ban after 3 failed SSH attempts
  services.fail2ban = {
    enable     = true;
    maxretry   = 3;
    bantime    = "-1";
    jails.sshd.settings = {
      enabled  = true;
      port     = "ssh";
      filter   = "sshd";
      maxretry = 3;
      bantime  = "-1";
    };
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
      MaxAuthTries           = 3;
      LoginGraceTime         = 20;
    };
  };

  # Kernel modules — vxlan required for flannel VXLAN backend, tcp_bbr for congestion control
  boot.kernelModules = [ "vxlan" "tcp_bbr" ];

  # IP forwarding — required for Tailscale exit node and subnet routing
  # Network performance optimizations for high-bandwidth Tailscale connections
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward"          = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    # TCP buffer sizes (increased from defaults for better throughput)
    "net.core.rmem_max"     = 134217728;  # 128 MB
    "net.core.wmem_max"     = 134217728;  # 128 MB
    "net.ipv4.tcp_rmem"     = "4096 87380 67108864";  # min default max (64 MB)
    "net.ipv4.tcp_wmem"     = "4096 65536 67108864";  # min default max (64 MB)

    # BBR congestion control for better performance
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc"          = "fq";

    # Additional TCP optimizations
    "net.ipv4.tcp_fastopen"           = 3;
    "net.ipv4.tcp_mtu_probing"        = 1;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
  };

  # Tailscale
  services.tailscale = {
    enable      = true;
    authKeyFile = "/run/secrets/tailscale_authkey";
    extraUpFlags = [
      "--advertise-exit-node"
      "--hostname=${config.networking.hostName}"
      "--netfilter-mode=off"
    ];
  };

  # TS_DEBUG_MTU tells tailscaled to use 8000 MTU on the tunnel from the start
  # (same as Debian's TS_DEBUG_MTU in /etc/default/tailscaled).
  # This is the proper way — "ip link set" fights tailscaled resetting the MTU.
  systemd.services.tailscaled.environment.TS_DEBUG_MTU = "8000";

  # UDP GRO forwarding on the public NIC — Tailscale perf best practice for exit nodes
  networking.localCommands = ''
    iface=$(${pkgs.iproute2}/bin/ip route show default | grep -oP 'dev \K\S+' | head -1)
    ${pkgs.ethtool}/bin/ethtool -K "$iface" rx-udp-gro-forwarding on rx-gro-list off || true
  '';

  # vnstat — network traffic monitoring
  services.vnstat.enable = true;

  # Nix
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
  };

  environment.systemPackages = with pkgs; [ git curl vnstat iperf3 ffmpeg-full tmux ethtool ];

  time.timeZone = "UTC";

  system.stateVersion = "25.11";
}
