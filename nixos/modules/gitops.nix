{ pkgs, config, ... }:

let
  repo     = "RAFSuNX/server-hub";
  branch   = "main";
  hostname = config.networking.hostName;

  script = pkgs.writeShellScript "nixos-gitops-${hostname}" ''
    set -euo pipefail

    STATE_DIR="/var/lib/nixos-gitops"
    STATE_FILE="$STATE_DIR/last-commit"
    mkdir -p "$STATE_DIR"

    # Fetch latest commit SHA from GitHub API
    RESPONSE=$(${pkgs.curl}/bin/curl -sf \
      "https://api.github.com/repos/${repo}/commits/${branch}" 2>/dev/null || true)

    if [ -z "$RESPONSE" ]; then
      echo "gitops: failed to reach GitHub, skipping"
      exit 0
    fi

    LATEST=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.sha // empty')

    if [ -z "$LATEST" ]; then
      echo "gitops: failed to parse commit SHA, skipping"
      exit 0
    fi

    CURRENT=""
    [ -f "$STATE_FILE" ] && CURRENT=$(cat "$STATE_FILE")

    if [ "$CURRENT" = "$LATEST" ]; then
      echo "gitops: already at $LATEST, nothing to do"
      exit 0
    fi

    echo "gitops: new commit $LATEST (was: ''${CURRENT:-none})"

    # Clear any stale transient unit left by a previously interrupted nixos-rebuild
    systemctl kill nixos-rebuild-switch-to-configuration.service 2>/dev/null || true
    systemctl reset-failed nixos-rebuild-switch-to-configuration.service 2>/dev/null || true
    rm -f /run/systemd/transient/nixos-rebuild-switch-to-configuration.service
    systemctl daemon-reload

    echo "gitops: running nixos-rebuild switch..."

    /run/current-system/sw/bin/nixos-rebuild switch \
      --flake "github:${repo}/$LATEST?dir=nixos#${hostname}"

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

    # Prevent deadlock: switch-to-configuration must not try to restart
    # nixos-gitops while nixos-gitops itself is running a rebuild.
    stopIfChanged    = false;
    restartIfChanged = false;
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
