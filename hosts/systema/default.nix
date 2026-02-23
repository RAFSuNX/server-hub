# =============================================================================
# Host Configuration: systema
# =============================================================================
# Primary/Init node for the k3s cluster.
#
# Role: k3s init node, control-plane, etcd
# Public IP: 92.5.79.76
# Private IP: 10.0.0.2/24
# Tailscale IP: 100.108.186.15/32
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{ config, lib, pkgs, ... }:

{
  # ===========================================================================
  # Host Identity
  # ===========================================================================

  networking.hostName = "systema";

  # ===========================================================================
  # User Configuration
  # ===========================================================================

  # SSH authorized keys for this host
  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGU4GLGFBm6xFx7ncQlPMYLK5D/rmrZ7Kk8Shw/u8tPu rafsunx@systema"
    # Server-to-server access
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkgLUgPnDJLYt5PPsw7/kNeC2iYA/FxuuoIkBTbEo9B rafsunx@systemb"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfZX9XhE1m/URa6tKxUhLbFh9UsY64IUupkl7A1HsR6 rafsunx@systemc"
  ];

  # ===========================================================================
  # Host-Specific Configuration
  # ===========================================================================

  # Additional host-specific services and packages can be added here
}
