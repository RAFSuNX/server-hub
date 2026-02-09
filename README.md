# Infrastructure Overview

High-level architecture documentation for the 3-node homelab cluster.

## Architecture

### Hardware
- 3x ARM servers (Neoverse-N1, 24GB RAM, 200GB disk each)
- Geographic distribution: Different data centers
- OS: NixOS 26.05 (declarative configuration)

### Core Components
```
┌─────────────────────────────────────────────────────────────┐
│                      Tailscale VPN Mesh                     │
│                  (Encrypted WireGuard tunnel)               │
└─────────────────────────────────────────────────────────────┘
           │                  │                  │
    ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐
    │   systema   │   │   systemb   │   │   systemc   │
    │  (control)  │   │  (control)  │   │  (control)  │
    │   (etcd)    │   │   (etcd)    │   │   (etcd)    │
    │   (worker)  │   │   (worker)  │   │   (worker)  │
    └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
           │                  │                  │
           └──────────────────┴──────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │   k3s Cluster     │
                   │  (Kubernetes)     │
                   └───────────────────┘
```

## Networking

### Mesh Network
- **Tailscale VPN**: All servers connected via encrypted WireGuard tunnel
- **Flannel CNI**: Kubernetes pod network over Tailscale interface
- **Private IPs**: 100.x.x.x range (Tailscale CGNAT)
- **Exit nodes**: All servers advertise as exit nodes

### Ingress
- **Cloudflare Tunnels**: 3x cloudflared daemonsets (one per node)
- **No exposed ports**: All external traffic through Cloudflare
- **DNS**: Managed by Cloudflare
- **SSL/TLS**: Terminated at Cloudflare edge

### Internal DNS
- **CoreDNS**: 3 replicas with pod anti-affinity
- **High availability**: Survives single node failure
- **Service discovery**: Automatic for all Kubernetes services

## Storage Architecture

### Two-tier Storage Strategy

#### Tier 1: Critical Data (LINSTOR/DRBD)
- **Replication**: 3x synchronous across all nodes
- **Technology**: DRBD9 (Distributed Replicated Block Device)
- **Use case**: Databases, config data, application state
- **Characteristics**:
  - High durability (survives 2 node failures)
  - I/O overhead due to synchronous replication
  - ~30GB total usage

#### Tier 2: Media Storage (GlusterFS)
- **Replication**: None (distributed only)
- **Technology**: GlusterFS distributed volume
- **Use case**: Movies, TV shows, downloads (non-critical)
- **Characteristics**:
  - Maximum capacity utilization
  - No replication overhead
  - ~250GB per node

### Storage Flow
```
Application Write
       │
       ▼
┌──────────────┐
│ Kubernetes   │
│     PVC      │
└──────┬───────┘
       │
       ├─────────────────┬─────────────────┐
       │                 │                 │
       ▼                 ▼                 ▼
 ┌─────────┐       ┌─────────┐       ┌─────────┐
 │ systema │◄─────►│ systemb │◄─────►│ systemc │
 │  DRBD   │       │  DRBD   │       │  DRBD   │
 └─────────┘       └─────────┘       └─────────┘
    (sync)            (sync)            (sync)
```

## High Availability

### Control Plane
- **k3s embedded etcd**: 3-node quorum (tolerates 1 failure)
- **API servers**: Running on all 3 nodes
- **Scheduler/Controller**: Leader election across nodes

### Data Plane
- **Pod distribution**: Spread across nodes with anti-affinity rules
- **CoreDNS**: 3 replicas (1 per node)
- **Metrics server**: 2 replicas
- **LINSTOR controller**: 1 replica (planned HA upgrade)

### Failure Scenarios
- **1 node down**: Cluster operational, etcd maintains quorum
- **2 nodes down**: Cluster degraded, some services unavailable
- **Storage**: DRBD survives 2-node failure, data remains accessible

## Management

### Infrastructure as Code

#### NixOS Configuration (System Level)
```
nixos/
├── flake.nix           # Flake definition
├── modules/            # Shared configuration
│   ├── common.nix      # Base system config
│   ├── k3s.nix         # Kubernetes setup
│   ├── glusterfs.nix   # Media storage
│   └── security.nix    # Firewall, fail2ban
└── hosts/              # Per-server config
    ├── systema/
    ├── systemb/
    └── systemc/
```

**Deployment**: `./deploy.sh <server>` rebuilds and activates NixOS config

#### Kubernetes Manifests (Application Level)
```
k8s/
├── 00-namespaces/      # Namespace definitions
└── <namespace>/
    └── <app>/
        ├── 01-rbac.yaml       # RBAC (if needed)
        ├── 02-storage.yaml    # PVCs
        ├── 03-deployment.yaml # Workloads
        └── 04-service.yaml    # Services
```

**Deployment**: `kubectl apply -R -f k8s/<namespace>/`

### Deployment Workflow

1. **NixOS Changes** (system-level):
   ```bash
   cd nixos/
   ./deploy.sh systema  # Deploy to systema
   ```

2. **Application Changes** (Kubernetes-level):
   ```bash
   kubectl apply -f k8s/media/jellyfin/
   ```

3. **Verification**:
   ```bash
   kubectl get pods -A           # Check all pods
   kubectl top nodes             # Resource usage
   linstor resource list         # Storage status
   ```

## Data Flow

### Write Operation (Critical Data)
```
App Write Request
    ↓
Kubernetes PVC
    ↓
LINSTOR CSI Driver
    ↓
DRBD Primary Node ──┬──► DRBD Secondary (systemb)
                    └──► DRBD Secondary (systemc)
    ↓
Acknowledge (after all 3 writes complete)
```

### Read Operation (Media)
```
App Read Request
    ↓
GlusterFS Mount (/mnt/storage)
    ↓
Direct read from local disk
(No network overhead)
```

## Security

### Network Security
- **Tailscale**: End-to-end encryption between nodes
- **Firewall**: Public interface allows SSH only
- **Fail2ban**: Permanent ban after 3 failed attempts
- **No exposed services**: All external via Cloudflare Tunnels

### Access Control
- **SSH**: Key-based only, no password auth
- **Kubernetes RBAC**: Role-based access for workloads
- **Secrets**: Stored in `/etc/nixos/secrets/` (not in git)

## Monitoring

### Built-in
- **Prometheus**: Metrics collection (10-day retention)
- **Grafana**: Visualization dashboards
- **Node Exporter**: System metrics from all nodes
- **VNStat**: Network usage tracking

### Health Checks
```bash
# Cluster health
kubectl get nodes
kubectl top nodes

# Storage health
linstor resource list
df -h /mnt/storage

# Network health
tailscale status
```

## Maintenance

### Rolling Updates
Safe server reboot sequence:
1. Drain node: `kubectl drain <node> --ignore-daemonsets`
2. Reboot: `ssh <node> sudo reboot`
3. Wait for node ready
4. Uncordon: `kubectl uncordon <node>`
5. Repeat for next node

### Cleanup
- **Container images**: Automatic pruning
- **Journal logs**: Vacuum to 100MB
- **Nix store**: Weekly garbage collection
- **Old generations**: Auto-delete after 7 days

## Key Decisions

### Why NixOS?
- Declarative configuration (infrastructure as code)
- Atomic rollbacks if deployment fails
- Reproducible system state across all nodes
- Easy to version control entire system

### Why k3s over k8s?
- Lightweight (single binary)
- Embedded etcd (no external dependency)
- Perfect for edge/homelab scenarios
- Full Kubernetes API compatibility

### Why DRBD + GlusterFS?
- **DRBD**: Strong consistency for critical data
- **GlusterFS**: Capacity optimization for media
- Right tool for each use case

### Why Tailscale?
- Zero-trust mesh network
- No firewall port forwarding needed
- Automatic NAT traversal
- Encrypted by default

## Further Reading

- **Application details**: See `k8s/STRUCTURE.md`
- **NixOS configs**: See `nixos/modules/`
- **Troubleshooting**: Check Prometheus/Grafana dashboards
