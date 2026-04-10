{ pkgs, ... }:

let
  repo   = "RAFSuNX/server-hub";
  branch = "main";

  script = pkgs.writeShellScript "nixos-gitops" ''
    set -euo pipefail

    STATE_DIR="/var/lib/nixos-gitops"
    STATE_FILE="$STATE_DIR/last-commit"
    mkdir -p "$STATE_DIR"

    # Fetch latest commit SHA from GitHub API
    LATEST=$(${pkgs.curl}/bin/curl -sf \
      "https://api.github.com/repos/${repo}/commits/${branch}" \
      | ${pkgs.jq}/bin/jq -r '.sha')

    if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
      echo "gitops: failed to fetch latest commit SHA, skipping"
      exit 0
    fi

    CURRENT=""
    [ -f "$STATE_FILE" ] && CURRENT=$(cat "$STATE_FILE")

    if [ "$CURRENT" = "$LATEST" ]; then
      echo "gitops: already at $LATEST, nothing to do"
      exit 0
    fi

    echo "gitops: new commit $LATEST (was: ''${CURRENT:-none})"
    echo "gitops: running nixos-rebuild switch..."

    /run/current-system/sw/bin/nixos-rebuild switch \
      --flake "github:${repo}/${branch}#$(hostname)"

    echo "$LATEST" > "$STATE_FILE"
    echo "gitops: successfully applied $LATEST"
  '';
in
{
  systemd.services.nixos-gitops = {
    description = "NixOS GitOps — auto-apply on new git commit";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      Type           = "oneshot";
      ExecStart      = script;
      StandardOutput = "journal";
      StandardError  = "journal";
    };
  };

  systemd.timers.nixos-gitops = {
    description = "NixOS GitOps timer";
    wantedBy    = [ "timers.target" ];

    timerConfig = {
      OnBootSec          = "2min";
      OnUnitActiveSec    = "5min";
      RandomizedDelaySec = "30s";
      Unit               = "nixos-gitops.service";
    };
  };
}
