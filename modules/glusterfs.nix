# =============================================================================
# GlusterFS Distributed Storage Configuration
# =============================================================================
# Distributed storage for media files (NO replication).
# Optimized for maximum capacity rather than redundancy.
#
# Configuration:
#   - Type: Distribute (RAID 0 style)
#   - Total Capacity: 600 GB (3 × 200 GB)
#   - Replication: None (data loss if any node fails)
#   - Use Case: Replaceable media files only
#
# Volume Setup:
#   gluster volume create storage systema:/mnt/brick \
#                                  systemb:/mnt/brick \
#                                  systemc:/mnt/brick
#
# Author: rafsunx
# Last Modified: 2026-02-08
# =============================================================================

{ config, lib, pkgs, ... }:

let
  # GlusterFS paths
  brickPath = "/mnt/brick";     # Per-node brick storage
  mountPath = "/mnt/storage";   # Client mount point
  volumeName = "storage";       # GlusterFS volume name
in
{
  # ===========================================================================
  # GlusterFS Service
  # ===========================================================================

  services.glusterfs.enable = true;

  # Prepare brick directory before glusterd starts
  systemd.services.glusterd = {
    preStart = ''
      mkdir -p ${brickPath}
      chown rafsunx:users ${brickPath}
    '';
  };

  # ===========================================================================
  # Directory Configuration
  # ===========================================================================

  # Create directories with proper ownership and permissions
  systemd.tmpfiles.rules = [
    "d ${brickPath} 0775 rafsunx users -"
    "d ${mountPath} 0775 rafsunx users -"
  ];

  # ===========================================================================
  # Filesystem Mounts
  # ===========================================================================

  # Mount GlusterFS volume persistently
  # Note: Uses automount to prevent boot failure if GlusterFS is unavailable
  fileSystems.${mountPath} = {
    device = "localhost:/${volumeName}";
    fsType = "glusterfs";
    options = [
      "defaults"
      "_netdev"                           # Network filesystem
      "nofail"                            # Don't fail boot if mount fails
      "x-systemd.automount"               # Mount on first access
      "x-systemd.idle-timeout=0"          # Never auto-unmount
      "x-systemd.requires=glusterd.service"
      "x-systemd.after=glusterd.service"
      "x-systemd.mount-timeout=30"        # Timeout after 30 seconds
    ];
  };

  # ===========================================================================
  # System Packages
  # ===========================================================================

  environment.systemPackages = with pkgs; [
    glusterfs  # GlusterFS client and server tools
  ];
}

# =============================================================================
# Performance Tuning (Manual Commands)
# =============================================================================
# Run these commands on one server after volume creation:
#
#   sudo gluster volume set storage performance.cache-size 4GB
#   sudo gluster volume set storage performance.write-behind on
#   sudo gluster volume set storage performance.read-ahead on
#   sudo gluster volume set storage performance.read-ahead-page-count 8
# =============================================================================
