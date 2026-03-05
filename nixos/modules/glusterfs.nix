{ config, lib, pkgs, ... }:

let
  mkMount = device: mountPath: {
    inherit device;
    fsType = "glusterfs";
    options = [
      "_netdev"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=0"
      "x-systemd.requires=glusterd.service"
      "x-systemd.after=glusterd.service"
      "x-systemd.mount-timeout=30"
    ];
  };
in
{
  services.glusterfs.enable = true;

  systemd.services.glusterd = {
    after   = [ "tailscale.service" ];
    wants   = [ "tailscale.service" ];
    preStart = ''
      mkdir -p /mnt/storage-brick
    '';
  };

  systemd.tmpfiles.rules = [
    "d /mnt/storage-brick 0775 rafsunx users -"
    "d /mnt/storage       0775 rafsunx users -"
  ];

  # storage — distribute (RAID-0), 3×200GB = 600GB, media files
  fileSystems."/mnt/storage" = mkMount "localhost:/storage" "/mnt/storage";

  environment.systemPackages = with pkgs; [ glusterfs ];
}
