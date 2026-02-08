# K8s Manifests Structure

Standard nested pattern with proper numbering:

```
k8s/
├── 00-namespaces/           # All namespace definitions
│   └── *.yaml
└── {namespace}/             # Namespace-specific resources
    └── {app}/               # App-specific folder
        ├── 01-rbac.yaml     # ServiceAccount, Roles, ClusterRoleBindings (if needed)
        ├── 02-storage.yaml  # PVCs, StorageClasses (if needed)
        ├── 03-deployment.yaml (or statefulset/daemonset)
        └── 04-service.yaml  # Services, Ingress (if needed)
```

Numbering convention:
- 00-namespaces: Namespace definitions
- 01: RBAC resources
- 02: Storage resources  
- 03: Workloads (Deployment/StatefulSet/DaemonSet)
- 04: Network resources (Service/Ingress)

## Current Structure

```
k8s/
├── 00-namespaces/
│   ├── 00-games.yaml
│   ├── 00-media.yaml
│   ├── 00-monitoring.yaml
│   ├── 00-networking.yaml
│   └── 00-tools.yaml
├── games/
│   └── minecraft/
│       ├── 02-storage.yaml
│       ├── 03-deployment.yaml
│       └── 04-service.yaml
├── kube-system/
│   └── kite/
│       ├── 01-rbac.yaml
│       ├── 02-storage.yaml
│       ├── 03-deployment.yaml
│       └── 04-service.yaml
├── media/
│   ├── flaresolverr/
│   │   ├── 03-deployment.yaml
│   │   └── 04-service.yaml
│   ├── jellyfin/
│   │   ├── 02-storage.yaml
│   │   ├── 03-deployment.yaml
│   │   └── 04-service.yaml
│   ├── prowlarr/
│   │   ├── 02-storage.yaml
│   │   ├── 03-deployment.yaml
│   │   └── 04-service.yaml
│   ├── qbittorrent/
│   │   ├── 02-storage.yaml
│   │   ├── 03-deployment.yaml
│   │   └── 04-service.yaml
│   ├── radarr/
│   │   ├── 02-storage.yaml
│   │   ├── 03-deployment.yaml
│   │   └── 04-service.yaml
│   └── sonarr/
│       ├── 02-storage.yaml
│       ├── 03-deployment.yaml
│       └── 04-service.yaml
├── networking/
│   └── cloudflared/
│       └── 03-daemonset.yaml
├── storage/
│   └── piraeus/
│       ├── 01-linstor-cluster.yaml
│       ├── 02-satellite-config.yaml
│       └── 03-storageclass.yaml
└── tools/
    ├── firefox/
    │   ├── 02-storage.yaml
    │   ├── 03-deployment.yaml
    │   └── 04-service.yaml
    ├── n8n/
    │   ├── 02-storage.yaml
    │   ├── 03-deployment.yaml
    │   └── 04-service.yaml
    └── transfersh/
        ├── 03-deployment.yaml
        └── 04-service.yaml
```

## Static IPs

Only these services have static clusterIP:
- `jellyfin` (media): 10.43.10.10
- `minecraft-service` (games): 10.43.111.111

All other services use dynamic IP assignment.

## Notes

- Monitoring namespace (Prometheus/Grafana) is Helm-managed, not tracked in manifests
- All manifests are clean (no status, creationTimestamp, resourceVersion, uid)
- Whisparr removed (no active deployment)
