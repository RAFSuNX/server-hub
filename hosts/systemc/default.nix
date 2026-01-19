# Host-specific configuration for systemc
{ config, lib, pkgs, ... }:

{
  networking.hostName = "systemc";

  # SSH authorized keys for this host
  users.users.rafsunx.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIIFtPMG/Nk6mgBsXXzy7ESVLD5t44hMVD7KOZ16EAWq rafsunx@systemc"
  ];

  # Host-specific services and packages can be added here
}
