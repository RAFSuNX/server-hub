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

  # Systemd mount unit hardening to prevent auth storms
  systemd.services."mnt-hza" = {
    unitConfig = {
      # Limit restart frequency to prevent auth storms
      StartLimitIntervalSec = 300;    # 5 minute window
      StartLimitBurst = 3;             # Max 3 restart attempts
    };
    serviceConfig = {
      # Wait between restart attempts
      RestartSec = 30;                 # Wait 30s before retry
    };
  };

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
      "x-systemd.mount-timeout=60" # 60s mount timeout (was 30s)
      "_netdev"                    # Network filesystem
      "echo_interval=120"          # TCP keepalive every 2min
      "nostrictsync"               # Better performance, allow async writes
    ];
  };
}
