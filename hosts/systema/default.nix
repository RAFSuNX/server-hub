# =============================================================================
# Host: systema
# =============================================================================
# Role:   k3s init node, control-plane, etcd
# =============================================================================

{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "systema";

  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGU4GLGFBm6xFx7ncQlPMYLK5D/rmrZ7Kk8Shw/u8tPu rafsunx@systema"
  ];
}
