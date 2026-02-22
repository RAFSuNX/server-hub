# =============================================================================
# Bandwidth Guard Module
# =============================================================================
# Monitors monthly outbound (TX) traffic and applies progressive tc throttling
# as the Oracle free-tier egress limit (10 TB/month) approaches.
#
# Author: rafsunx
# =============================================================================

{ config, lib, pkgs, ... }:

let
  cfg = config.services.bandwidthGuard;

  # Convert GB to bytes (base-10, matching Oracle's TB definition)
  gbToBytes = gb: gb * 1000 * 1000 * 1000;

in
{
  # ===========================================================================
  # Options
  # ===========================================================================

  options.services.bandwidthGuard = {
    enable = lib.mkEnableOption "monthly egress bandwidth guard";

    interface = lib.mkOption {
      type    = lib.types.str;
      default = "enp0s6";
      description = "Physical network interface to monitor and throttle.";
    };

    limitGB = lib.mkOption {
      type    = lib.types.int;
      default = 10000; # 10 TB in GB
      description = "Monthly outbound cap in gigabytes (base-10).";
    };

    stages = lib.mkOption {
      description = "Throttle stages as percentage of limitGB and their rates.";
      default = [
        { percent = 90; rate = "10mbit";  burst = "1mbit";   }
        { percent = 95; rate = "1mbit";   burst = "128kbit"; }
        { percent = 98; rate = "100kbit"; burst = "32kbit";  }
      ];
      type = lib.types.listOf (lib.types.submodule {
        options = {
          percent = lib.mkOption { type = lib.types.int; };
          rate    = lib.mkOption { type = lib.types.str; };
          burst   = lib.mkOption { type = lib.types.str; };
        };
      });
    };
  };

  # ===========================================================================
  # Implementation
  # ===========================================================================

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ iproute2 jq ];

    systemd.services.bandwidth-guard = {
      description = "Monthly egress bandwidth guard";
      after       = [ "network.target" "vnstat.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";

        ExecStart = pkgs.writeShellApplication {
          name = "bandwidth-guard";
          runtimeInputs = with pkgs; [ vnstat jq iproute2 ];
          text = ''
            IFACE="${cfg.interface}"
            LIMIT_BYTES="${toString (gbToBytes cfg.limitGB)}"

            YEAR=$(date +%Y)
            MONTH=$(date +%-m)

            MONTH_TX=$(vnstat -i "$IFACE" --json | jq \
              --argjson y "$YEAR" --argjson m "$MONTH" \
              '[.interfaces[0].traffic.month[] |
                select(.date.year == $y and .date.month == $m) | .tx] | last // 0')

            MONTH_TX=''${MONTH_TX:-0}

            echo "bandwidth-guard: TX this month = $MONTH_TX / $LIMIT_BYTES bytes"

            # Remove existing root qdisc before (re)applying
            tc qdisc del dev "$IFACE" root 2>/dev/null || true

            ${lib.concatMapStrings (stage:
              let threshold = (cfg.limitGB * stage.percent / 100) * 1000 * 1000 * 1000; in
              ''
                if [ "$MONTH_TX" -ge "${toString threshold}" ]; then
                  echo "bandwidth-guard: >= ${toString stage.percent}% of limit — rate ${stage.rate}"
                  tc qdisc add dev "$IFACE" root tbf rate ${stage.rate} burst ${stage.burst} latency 400ms
                  exit 0
                fi
              ''
            ) (lib.reverseList cfg.stages)}

            echo "bandwidth-guard: within limits, no throttle"
          '';
        } + "/bin/bandwidth-guard";
      };
    };

    systemd.timers.bandwidth-guard = {
      description = "Monthly egress bandwidth guard — hourly check";
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        OnBootSec  = "5min";
        Persistent = true;
      };
    };
  };
}
