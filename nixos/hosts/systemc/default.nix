# =============================================================================
# Host: systemc
# =============================================================================
# Role:   k3s join node, control-plane, etcd
# =============================================================================

{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "systemc";

  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIIFtPMG/Nk6mgBsXXzy7ESVLD5t44hMVD7KOZ16EAWq rafsunx@systemc"
  ];
}
