{ pkgs, ... }:

{
  services.glusterfs.enable = true;

  boot.kernelModules = [ "fuse" ];

  systemd.services.glusterd = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/storage-brick 0775 rafsunx users -"
    "d /mnt/storage       0775 rafsunx users -"
  ];

  fileSystems."/mnt/storage" = {
    device  = "localhost:/storage";
    fsType  = "glusterfs";
    options = [
      "_netdev" "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=0"
      "x-systemd.requires=glusterd.service"
      "x-systemd.after=glusterd.service"
      "x-systemd.mount-timeout=30"
    ];
  };

  environment.systemPackages = with pkgs; [ glusterfs ];
}
