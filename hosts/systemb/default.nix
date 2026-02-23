# =============================================================================
# Host Configuration: systemb
# =============================================================================
# Secondary node in the k3s cluster.
#
# Role: k3s join node, control-plane, etcd
# Public IP: 141.147.88.103
# Private IP: 10.0.0.245/24
# Tailscale IP: 100.127.141.103/32
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{ config, lib, pkgs, ... }:

{
  # ===========================================================================
  # Host Identity
  # ===========================================================================

  networking.hostName = "systemb";

  # ===========================================================================
  # User Configuration
  # ===========================================================================

  # SSH authorized keys for this host
  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXg4tKSm2U39RkTY1tT/q3Mk8ijwSHbBySXH7+sY5wT rafsunx@systemb"
    # Server-to-server access
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/HGagyQ0lj2CQ8OUzvairkp1LCbMs0/rdJUeOARF8/ rafsunx@systema"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfZX9XhE1m/URa6tKxUhLbFh9UsY64IUupkl7A1HsR6 rafsunx@systemc"
  ];

  # ===========================================================================
  # Host-Specific Configuration
  # ===========================================================================

  # Additional host-specific services and packages can be added here
}
