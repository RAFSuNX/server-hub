# =============================================================================
# Host Configuration: systemc
# =============================================================================
# Tertiary node in the k3s cluster.
#
# Role: k3s join node, control-plane, etcd
# Public IP: 158.101.102.237
# Private IP: 10.0.0.53/24
# Tailscale IP: 100.65.5.39/32
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{ config, lib, pkgs, ... }:

{
  # ===========================================================================
  # Host Identity
  # ===========================================================================

  networking.hostName = "systemc";

  # ===========================================================================
  # User Configuration
  # ===========================================================================

  # SSH authorized keys for this host
  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIIFtPMG/Nk6mgBsXXzy7ESVLD5t44hMVD7KOZ16EAWq rafsunx@systemc"
    # Server-to-server access
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/HGagyQ0lj2CQ8OUzvairkp1LCbMs0/rdJUeOARF8/ rafsunx@systema"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkgLUgPnDJLYt5PPsw7/kNeC2iYA/FxuuoIkBTbEo9B rafsunx@systemb"
  ];

  # ===========================================================================
  # Host-Specific Configuration
  # ===========================================================================

  # Additional host-specific services and packages can be added here
}
