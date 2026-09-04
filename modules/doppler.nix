{ pkgs, adminUser, ... }:

# Requires /etc/doppler-token on each node containing:
#   DOPPLER_TOKEN=dp.st.prod.xxxxxxxxx
# Place this file once during initial provisioning. Everything else is automatic.
#
# Doppler secrets this module expects:
#   K3S_TOKEN               — k3s cluster join token
#   TAILSCALE_AUTHKEY       — Tailscale auth key for initial node registration
#   CLUSTER_SSH_PRIVATE_KEY — Ed25519 private key shared across all nodes
#   CLUSTER_SSH_PUB_KEY     — Corresponding public key (authorizes inter-node SSH)

{
  environment.systemPackages = with pkgs; [ doppler ];

  systemd.tmpfiles.rules = [
    "d /run/secrets              0700 root       root       -"
    "d /home/${adminUser}/.ssh  0700 ${adminUser} ${adminUser} -"
  ];

  systemd.services.doppler-secrets = {
    description = "Fetch secrets from Doppler";
    wantedBy    = [ "multi-user.target" ];
    before      = [ "tailscaled.service" "k3s.service" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = "/etc/doppler-token";
      ExecStart       = pkgs.writeShellScript "doppler-fetch" ''
        set -euo pipefail
        fetch() { ${pkgs.doppler}/bin/doppler secrets get "$1" --plain 2>/dev/null; }

        install -m600 /dev/null /run/secrets/k3s_token
        fetch K3S_TOKEN > /run/secrets/k3s_token

        install -m600 /dev/null /run/secrets/tailscale_authkey
        fetch TAILSCALE_AUTHKEY > /run/secrets/tailscale_authkey

        install -m600 -o ${adminUser} /dev/null /home/${adminUser}/.ssh/cluster_key
        fetch CLUSTER_SSH_PRIVATE_KEY > /home/${adminUser}/.ssh/cluster_key

        install -m644 /dev/null /run/secrets/cluster_authorized_keys
        fetch CLUSTER_SSH_PUB_KEY > /run/secrets/cluster_authorized_keys
      '';
    };
  };

  # sshd checks this file in addition to each user's ~/.ssh/authorized_keys,
  # so every node automatically accepts the cluster key once Doppler writes it.
  services.openssh.authorizedKeysFiles = [
    "%h/.ssh/authorized_keys"
    "/run/secrets/cluster_authorized_keys"
  ];

  programs.ssh.extraConfig = ''
    Host systema systemb systemc
      User ${adminUser}
      IdentityFile /home/${adminUser}/.ssh/cluster_key
      StrictHostKeyChecking accept-new
  '';
}
