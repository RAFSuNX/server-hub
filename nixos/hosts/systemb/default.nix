# Host-specific configuration for systemb
{ config, lib, pkgs, ... }:

{
  networking.hostName = "systemb";

  # SSH authorized keys for this host
  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXg4tKSm2U39RkTY1tT/q3Mk8ijwSHbBySXH7+sY5wT rafsunx@systemb"
  ];

  # Host-specific services and packages can be added here
}
