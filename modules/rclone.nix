{ config, pkgs, ... }:

{
  age.secrets.rclone_gdrive.file    = ../secrets/rclone_gdrive.age;


  environment.systemPackages = with pkgs; [ rclone fuse3 ];

  # Allow FUSE mounts to be accessible by other users (needed for k3s/pods)
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  systemd.services.rclone-gdrive = {
    description = "rclone Google Drive mount";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "multi-user.target" ];

    serviceConfig = {
      Type      = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /mnt/gdrive";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount \
          --config=${config.age.secrets.rclone_gdrive.path} \
          --vfs-cache-mode=off \
          --vfs-cache-max-size=20G \
          --vfs-cache-max-age=24h \
          --buffer-size=256M \
          --dir-cache-time=72h \
          --poll-interval=15s \
          --allow-other \
          --allow-non-empty \
          --uid=1000 \
          --gid=100 \
          --dir-perms=0775 \
          --file-perms=0664 \
          --transfers=8 \
          --drive-chunk-size=128M \
          --drive-pacer-min-sleep=10ms \
          --checkers=16 \
          --vfs-read-chunk-size=32M \
          --vfs-read-chunk-size-limit=2G \
          --vfs-read-ahead=1G \
          gdrive: /mnt/gdrive
      '';
      ExecStop         = "${pkgs.fuse}/bin/fusermount -u /mnt/gdrive";
      Restart          = "on-failure";
      RestartSec       = "10s";
    };
  };
}
