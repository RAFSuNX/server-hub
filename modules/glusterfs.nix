# GlusterFS distributed storage (no replication)
{ config, lib, pkgs, ... }:

let
  brickPath = "/mnt/brick";
  mountPath = "/mnt/storage";
  volumeName = "storage";
in
{
  services.glusterfs.enable = true;

  systemd.services.glusterd = {
    preStart = ''
      mkdir -p /mnt/brick
      chown rafsunx:users /mnt/brick
    '';
  };

  # Create directories owned by rafsunx:users with 0775
  systemd.tmpfiles.rules = [
    "d ${brickPath} 0775 rafsunx users -"
    "d ${mountPath} 0775 rafsunx users -"
  ];

  environment.systemPackages = with pkgs; [
    glusterfs
  ];

  # Persistent mount via fstab (won't block boot)
  fileSystems.${mountPath} = {
    device = "localhost:/${volumeName}";
    fsType = "glusterfs";
    options = [
      "defaults"
      "_netdev"                           # Network filesystem
      "nofail"                            # Don't fail boot if mount fails
      "x-systemd.automount"               # Mount on first access, not at boot
      "x-systemd.idle-timeout=0"          # Never auto-unmount
      "x-systemd.requires=glusterd.service"
      "x-systemd.after=glusterd.service"
      "x-systemd.mount-timeout=30"        # 30s timeout, don't hang forever
    ];
  };
}

# To apply performance tuning options, run these commands on one of the servers:
# sudo gluster volume set storage performance.cache-size 4GB
# sudo gluster volume set storage performance.write-behind on
# sudo gluster volume set storage performance.read-ahead on
# sudo gluster volume set storage performance.read-ahead-page-count 8
