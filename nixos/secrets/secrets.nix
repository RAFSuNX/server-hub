# =============================================================================
# Agenix Secrets Configuration
# =============================================================================
# Defines which hosts and the admin can decrypt each secret.
#
# Keys used:
#   - Host SSH keys  → each node decrypts its own secrets at activation
#   - Admin SSH key  → admin can re-encrypt / rotate secrets locally
# =============================================================================

let
  # Host SSH keys (from /etc/ssh/ssh_host_ed25519_key.pub on each node)
  systema = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH8e4IdlcpMeiku+wv6qkjKmMas7Uf9K77+bjo0lTvyw";
  systemb = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZdrsf03NpGCtcUICctmnv3OezOCHY29vJPxOmpkmOA";
  systemc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnEkSzmiJ8uYRoA7Xks7g5FLGjxVVQ2G+xhnXkIo2gn";

  # Admin key (server-hub machine)
  admin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHgIRW/qz8hibyQfrIkYA9dviXF4T6+JPdMV0xVnK2tw";

  allNodes = [ systema systemb systemc admin ];
in
{
  # Cluster-wide secrets (all nodes + admin can decrypt)
  "tailscale_authkey.age".publicKeys       = allNodes;
  "k3s_token.age".publicKeys               = allNodes;
  "rclone_gdrive.age".publicKeys           = allNodes;

  # Per-node authorized SSH keys (node + admin only)
  "authorized_keys_systema.age".publicKeys = [ systema admin ];
  "authorized_keys_systemb.age".publicKeys = [ systemb admin ];
  "authorized_keys_systemc.age".publicKeys = [ systemc admin ];
}
