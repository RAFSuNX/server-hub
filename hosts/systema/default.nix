# Host-specific configuration for systema
{ config, lib, pkgs, ... }:

{
  networking.hostName = "systema";

  # SSH authorized keys for this host
  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGU4GLGFBm6xFx7ncQlPMYLK5D/rmrZ7Kk8Shw/u8tPu rafsunx@systema"
  ];

  # Host-specific services and packages can be added here
}
