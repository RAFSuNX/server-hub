# Common configuration shared across all servers
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 1;  # Small /boot partition
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;  # No boot menu delay

  # DRBD 9 kernel module for Piraeus/LINSTOR storage
  boot.extraModulePackages = with config.boot.kernelPackages; [ drbd ];
  boot.blacklistedKernelModules = [ "drbd" ];
  boot.kernelModules = [ "drbd9" ];
  systemd.tmpfiles.rules = [
    "c /dev/drbd-control 0600 root disk 147 0 -"
  ];
  boot.extraModprobeConfig = ''
    options drbd usermode_helper=/run/current-system/sw/bin/true
  '';

  # Symlink /lib/modules for Piraeus/LINSTOR (NixOS uses different path)
  system.activationScripts.libModulesSymlink = ''
    mkdir -p /lib
    ln -sfn /run/current-system/kernel-modules/lib/modules /lib/modules
  '';

  # Networking
  networking.networkmanager.enable = true;

  # Tailscale IP mappings
  networking.hosts = {
    "100.108.186.15" = [ "systema" ];
    "100.127.141.103" = [ "systemb" ];
    "100.65.5.39" = [ "systemc" ];
  };

  # Timezone
  time.timeZone = "Asia/Dhaka";

  # User configuration
  users.users.rafsunx = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # Keys are defined per-host in hosts/<hostname>/default.nix
    ];
  };

  # Passwordless sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # System packages
  environment.systemPackages = with pkgs; [
    nano
    curl
    git
    htop
    drbd  # DRBD utilities for Piraeus/LINSTOR
    vnstat
  ];

  # SSH
  services.openssh.enable = true;

  # VNStat network usage monitoring
  services.vnstat.enable = true;

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    authKeyFile = "/etc/nixos/secrets/tailscale_authkey";
    extraUpFlags = [
      "--advertise-exit-node"
      "--hostname=${config.networking.hostName}"
    ];
  };

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  system.stateVersion = "25.11";
}
