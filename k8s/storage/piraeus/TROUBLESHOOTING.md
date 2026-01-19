# Piraeus/LINSTOR troubleshooting notes

This document summarizes what was failing and how it was fixed in this cluster.

## Symptoms
- PVC provisioning failed with "Not enough available nodes" and high additional replicas.
- LINSTOR resources failed to place with DRBD layer support errors.
- `ha-controller` crashlooped due to DRBD userspace/kernel mismatch.

## Root causes
1) DRBD kernel module mismatch (DRBD 8 in kernel, DRBD 9 userspace).
2) Missing `/dev/drbd-control` device node on hosts, so satellites could not use DRBD layer.
3) Auto-added quorum tiebreaker replicas increased placement beyond node count.

## Fixes applied
1) Use DRBD 9 kernel module in NixOS:
   - `boot.extraModulePackages = with config.boot.kernelPackages; [ drbd ];`
   - `boot.blacklistedKernelModules = [ "drbd" ];`
   - `boot.kernelModules = [ "drbd9" ];`

2) Ensure `/dev/drbd-control` exists on all nodes:
   - `mknod -m 600 /dev/drbd-control c 147 0`
   - `chown root:disk /dev/drbd-control`
   - Restart LINSTOR satellite pods to re-detect DRBD layer.

3) Use 3 replicas across 3 nodes and disable extra tiebreaker:
   - `placementCount: "3"`
   - `allowRemoteVolumeAccess: "false"`
   - `DrbdOptions/auto-add-quorum-tiebreaker: "false"`

## Verification
- PVC bound and test pod read back data: `linstor test OK`
- LINSTOR resources show replicas on `systema`, `systemb`, `systemc` as `UpToDate`

## Notes
- `/dev/drbd-control` is not persistent across reboot unless added via NixOS (udev or systemd tmpfiles).
