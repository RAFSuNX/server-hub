# Infrastructure Preferences

- K8s manifest directories in the repo should match the actual Kubernetes namespace where resources deploy — not a logical grouping name. (e.g. cloudflared deploys to `default` namespace → lives under `k8s/default/`, not `k8s/networking/`). Confidence: 0.85
- Consolidates resources targeting the same namespace into a single directory (e.g. both external-secrets and cloudflared under `k8s/default/`). Confidence: 0.8
- Prefers removing empty/unused namespaces and their corresponding repo directories rather than leaving them as stubs. Confidence: 0.85
- `kubectl` works from the local dev machine (kubeconfig is set up), but do NOT run host-level OS commands (`ip route`, `/proc/`, `nft`, etc.) locally — they don't reflect server state. For host-level server investigation, read NixOS config files from the `nixos_server` repo instead. Confidence: 0.9
- Remote servers are accessed via SSH alias `systema`; server OS configs live in `/home/rafsunx/repos/nixos_server`. Confidence: 0.85
- DaemonSets that need host-level network access (e.g., routing to Tailscale CIDR 100.64.0.0/10) should use `hostNetwork: true` with `dnsPolicy: ClusterFirstWithHostNet`. Confidence: 0.8
- Cloudflare Tunnels use QUIC protocol. Confidence: 0.8
