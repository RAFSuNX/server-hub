{ config, pkgs, ... }:

{
  # Encrypted credentials file (will be created with agenix)
  age.secrets.hza_smb_credentials.file = ../secrets/hza_smb_credentials.age;

  # Install CIFS utilities
  environment.systemPackages = with pkgs; [ cifs-utils ];

  # Create mount point
  systemd.tmpfiles.rules = [
    "d /mnt/hza 0775 root users - -"
  ];

  # SMB/CIFS mount configuration for Hetzner Storage Box
  fileSystems."/mnt/hza" = {
    device = "//u566879.your-storagebox.de/backup";
    fsType = "cifs";
    options = [
      "credentials=${config.age.secrets.hza_smb_credentials.path}"
      "uid=1000"
      "gid=100"
      "file_mode=0664"
      "dir_mode=0775"
      "iocharset=utf8"
      "vers=3.1.1"                 # SMB version 3.1.1 (fastest, most secure)
      "cache=loose"                # Better performance for read-heavy workloads
      "actimeo=30"                 # Attribute cache timeout (30s)
      "rsize=1048576"              # Read size 1MB (optimal for streaming)
      "wsize=1048576"              # Write size 1MB (optimal for downloads)
      "mfsymlinks"                 # Support symlinks
      "nobrl"                      # Disable byte-range locks (better for media)
      "nofail"                     # Don't fail boot if mount fails
      "x-systemd.automount"        # Auto-mount on access
      "x-systemd.idle-timeout=300" # Unmount after 5 min idle
      "x-systemd.mount-timeout=30" # 30s mount timeout
      "_netdev"                    # Network filesystem
    ];
  };
}
