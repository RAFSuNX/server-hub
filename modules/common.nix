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

  # Secrets
  age.secrets.tailscale_authkey.file = ../secrets/tailscale_authkey.age;

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

  # Kernel modules — vxlan required for flannel VXLAN backend
  boot.kernelModules = [ "vxlan" ];

  # IP forwarding — required for Tailscale exit node and subnet routing
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward"          = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Tailscale
  services.tailscale = {
    enable      = true;
    authKeyFile = config.age.secrets.tailscale_authkey.path;
    extraUpFlags = [
      "--advertise-exit-node"
      "--hostname=${config.networking.hostName}"
    ];
  };

  # vnstat — network traffic monitoring
  services.vnstat.enable = true;

  # Nix
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
  };

  environment.systemPackages = with pkgs; [ git curl vnstat ];

  time.timeZone = "Asia/Dhaka";

  system.stateVersion = "25.11";
}
