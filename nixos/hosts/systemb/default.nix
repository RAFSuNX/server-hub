# =============================================================================
# Host: systemb
# =============================================================================
# Role:   k3s join node, control-plane, etcd
# =============================================================================

{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "systemb";

  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXg4tKSm2U39RkTY1tT/q3Mk8ijwSHbBySXH7+sY5wT rafsunx@systemb"
  ];
}
