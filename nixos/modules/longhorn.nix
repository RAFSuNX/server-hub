{ config, pkgs, ... }:

{
  # Longhorn requires open-iscsi on every node
  services.openiscsi = {
    enable = true;
    name   = "iqn.2016-09.com.longhorn:${config.networking.hostName}";
  };

  boot.kernelModules = [ "iscsi_tcp" "dm_crypt" ];

  environment.systemPackages = with pkgs; [ nfs-utils ];

  # Longhorn's manager container uses nsenter to run iscsiadm on the host,
  # expecting it at /usr/bin/iscsiadm — NixOS puts it in the store so we symlink it.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
  ];
}
