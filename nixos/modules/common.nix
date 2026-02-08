# =============================================================================
# Common Configuration
# =============================================================================
# Shared configuration applied to all servers in the fleet.
# Includes base system settings, networking, users, and essential services.
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{ config, lib, pkgs, ... }:

{
  # ===========================================================================
  # Boot Configuration
  # ===========================================================================

  boot = {
    # Bootloader settings
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 1;  # Limit boot entries (small /boot partition)
      };
      efi.canTouchEfiVariables = true;
      timeout = 0;  # No boot menu delay
    };

    # DRBD 9 kernel module for Piraeus/LINSTOR distributed storage
    extraModulePackages = with config.boot.kernelPackages; [ drbd ];
    blacklistedKernelModules = [ "drbd" ];
    kernelModules = [ "drbd9" ];

    extraModprobeConfig = ''
      options drbd usermode_helper=/run/current-system/sw/bin/true
    '';
  };

  # DRBD device node
  systemd.tmpfiles.rules = [
    "c /dev/drbd-control 0600 root disk 147 0 -"
  ];

  # Symlink /lib/modules for Piraeus/LINSTOR compatibility
  # NixOS uses different path than standard FHS
  system.activationScripts.libModulesSymlink = ''
    mkdir -p /lib
    ln -sfn /run/current-system/kernel-modules/lib/modules /lib/modules
  '';

  # ===========================================================================
  # Networking Configuration
  # ===========================================================================

  networking = {
    # Enable NetworkManager for network configuration
    networkmanager.enable = true;

    # Tailscale mesh VPN hostname resolution
    hosts = {
      "100.108.186.15" = [ "systema" ];
      "100.127.141.103" = [ "systemb" ];
      "100.65.5.39" = [ "systemc" ];
    };
  };

  # ===========================================================================
  # User Configuration
  # ===========================================================================

  users.users.rafsunx = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # SSH keys are defined per-host in hosts/<hostname>/default.nix
    ];
  };

  # Passwordless sudo for wheel group members
  security.sudo.wheelNeedsPassword = false;

  # ===========================================================================
  # Services Configuration
  # ===========================================================================

  services = {
    # OpenSSH server
    openssh.enable = true;

    # VNStat network usage monitoring
    vnstat.enable = true;

    # Tailscale mesh VPN
    tailscale = {
      enable = true;
      authKeyFile = "/etc/nixos/secrets/tailscale_authkey";
      extraUpFlags = [
        "--advertise-exit-node"
        "--hostname=${config.networking.hostName}"
      ];
    };
  };

  # ===========================================================================
  # System Packages
  # ===========================================================================

  environment.systemPackages = with pkgs; [
    # Text editors
    nano

    # Network utilities
    curl

    # Version control
    git

    # System monitoring
    htop
    vnstat

    # Storage (DRBD utilities for Piraeus/LINSTOR)
    drbd
  ];

  # ===========================================================================
  # Nix Configuration
  # ===========================================================================

  nix = {
    # Nix daemon settings
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ===========================================================================
  # System Settings
  # ===========================================================================

  # Timezone
  time.timeZone = "Asia/Dhaka";

  # NixOS release version
  # DO NOT CHANGE - this value determines the NixOS release from which the
  # default settings for stateful data, like file locations and database
  # versions, were taken.
  system.stateVersion = "25.11";
}
