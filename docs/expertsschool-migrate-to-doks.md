# ExpertsSchool — migrate compute k3s → DigitalOcean Kubernetes (DOKS), Singapore

**Goal:** move only the *compute* (the k8s workloads in `k8s/expertsschool/`) off the
self-hosted k3s cluster onto managed **DOKS in `sgp1` (Singapore)**. Everything else
stays exactly as-is.

## What moves vs. what stays
| Stays (unchanged) | Moves to DOKS |
|---|---|
| Neon Postgres (AWS `ap-southeast-1`) | app Deployment, HPA, PDB, Service |
| Cloudflare R2 + video Worker (`cdn.expertsschool.com`) | in-cluster Valkey (Deployment + PVC) |
| Cloudflare Tunnel (DNS unchanged) | cloudflared (2 replicas) |
| Firebase, SSLCommerz, Doppler, GHCR, GitHub Actions CI | Flux + External Secrets Operator (ESO) |

Because DNS points at the **Cloudflare Tunnel** (outbound), there is **no LB, no static
IP, no DNS change, no cert dance**. Cutover = bring cloudflared up on DOKS (same tunnel
token) and it starts serving.

## Verified cost (Sept 2026 list prices)
- DOKS control plane: **FREE** (HA control plane +$40/mo — skip).
- Worker node **Basic 2 vCPU / 4 GB = $24/mo** each, 4,000 GiB egress included/node (pooled).
- Block storage (Valkey 1 GiB PVC): ~$0.10/mo. Egress here: ~$0 (video is on R2).
- **Recommended: 3× 2vCPU/4GB = ~$72/mo** (HA: survives a node drain with PDB minAvailable=2).
- **Minimum: 2× 2vCPU/4GB = ~$48/mo.**
(Vultr VKE is equivalent: free control plane, ~$20–24/node, `sgp` region.)

## The ONLY manifest change
`k8s/expertsschool/03-redis.yaml` PVC: `storageClassName: longhorn` → **`do-block-storage`**.
Everything else applies as-is. (Optional: drop the `NODE_OPTIONS=--dns-result-order=ipv4first
--no-network-family-autoselection` env in `05-deployment.yaml` — DOKS has healthy IPv6 egress —
but it is harmless to leave.)

---

## Prerequisites
- `doctl` (DigitalOcean CLI), authenticated: `doctl auth init` (needs a DO API token).
- `kubectl`, `flux`, `helm` locally.
- Doppler service tokens for the `expertsschool/prd` config **and** the shared store used for
  `ghcr-secret` (same tokens the k3s cluster uses — from Doppler dashboard).
- The Cloudflare Tunnel token is already in Doppler (`CLOUDFLARED_TUNNEL_TOKEN`) and syncs via ESO.

---

## Step 1 — Create the DOKS cluster (Singapore)
```bash
doctl kubernetes cluster create expertsschool \
  --region sgp1 \
  --version latest \
  --node-pool "name=default;size=s-2vcpu-4gb;count=3;auto-scale=true;min-nodes=3;max-nodes=5" \
  --wait
# kubeconfig is merged + context set automatically:
kubectl config current-context     # do-sgp1-expertsschool
kubectl get nodes                  # 3 Ready
```
(`s-2vcpu-4gb` = the $24/mo Basic node. Drop count to 2 for the $48/mo minimum.)

## Step 2 — Bootstrap secrets (ESO + Doppler), same pattern as the `her` app
DOKS has no ESO by default. Install it, then recreate the ClusterSecretStores + bootstrap
Doppler tokens (these are the only imperative, non-GitOps bits — same as on k3s).
```bash
helm repo add external-secrets https://charts.external-secrets.io && helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace --wait

kubectl create namespace expertsschool

# Bootstrap Doppler tokens (values from Doppler dashboard):
kubectl -n expertsschool create secret generic doppler-expertsschool-token \
  --from-literal=dopplerToken='dp.st.prd.XXXX'          # expertsschool/prd read token
kubectl -n default create secret generic doppler-token \
  --from-literal=dopplerToken='dp.st.XXXX'              # shared store token (for ghcr-secret)
```
> These match `k8s/default/secret-stores/03-doppler-expertsschool.yaml` and the shared
> `doppler` ClusterSecretStore already in this repo — Flux will apply the store objects; the
> **tokens** must exist first (imperative bootstrap, like `doppler-her-token`).

## Step 3 — Point the ONE manifest at DOKS storage
```bash
# in this repo:
sed -i 's/longhorn/do-block-storage/' k8s/expertsschool/03-redis.yaml
git commit -am "expertsschool: storageClass longhorn -> do-block-storage (DOKS)" && git push
```

## Step 4 — Install Flux on DOKS, pointed at this repo
Bootstrap Flux so it reconciles the same `server-hub` repo (read-only deploy key or PAT):
```bash
flux install                       # installs controllers into flux-system
# Git source -> this repo:
flux create source git server-hub \
  --url=ssh://git@github.com/RAFSuNX/server-hub \
  --branch=main --secret-ref=flux-git-auth -n default
# (create flux-git-auth with the deploy key, or use --url=https + PAT)

# Kustomizations (mirror the k3s wiring): the secret-store dir + the app:
flux create kustomization default \
  --source=GitRepository/server-hub --path=./k8s/default \
  --prune=true --interval=10m -n default
flux create kustomization expertsschool \
  --source=GitRepository/server-hub --path=./k8s/expertsschool \
  --prune=true --interval=10m --wait -n default
```
Flux now applies namespace → ExternalSecrets (→ `expertsschool-secrets`, `ghcr-secret`) →
Valkey → app → Service → HPA → PDB → cloudflared. HPA needs metrics-server (DOKS bundles it).

## Step 5 — Verify on DOKS BEFORE cutover (cloudflared not yet serving prod)
```bash
kubectl -n expertsschool get pods            # app 3/3, redis, cloudflared Ready
kubectl -n expertsschool get externalsecret  # SecretSynced=True
# health from inside a pod (avoids the tunnel):
kubectl -n expertsschool exec deploy/expertsschool -- \
  node -e 'fetch("http://localhost:3000/api/health").then(r=>r.text()).then(console.log)'
# -> {"ok":true,"db":true,"redis":true}  (db latency now ~1-5ms, not ~500ms)
```
At this point **both** clusters' cloudflared are connected to the same named tunnel, so
Cloudflare load-balances requests across both. Both talk to the same Neon/R2; sessions are
cookie+Firebase (stateless server-side), so serving from either is safe. Watch a few minutes.

## Step 6 — Cutover (near-zero downtime)
Drain traffic off k3s by stopping its tunnel connectors, leaving DOKS serving 100%:
```bash
# on the OLD k3s cluster:
kubectl --context k3s -n expertsschool scale deploy/cloudflared --replicas=0
# smoke test the live site (should be 100% DOKS now):
curl -s -H 'User-Agent: Mozilla/5.0' https://expertsschool.com/api/health
# then stop the old app:
kubectl --context k3s -n expertsschool scale deploy/expertsschool --replicas=0
```
Monitor `expertsschool.com` (login, a lesson video, a test checkout/IPN) for ~30–60 min.

## Step 7 — Decommission old cluster
Once confident (a day or two): remove the `expertsschool` Flux Kustomization on k3s (or delete
the namespace), and retire the old nodes. Keep the k3s manifests in git untouched — they’re
now serving on DOKS.

## Step 8 — Post-migration cleanup (optional)
- Remove the `NODE_OPTIONS=ipv4first...` env from `05-deployment.yaml` (DOKS IPv6 is fine).
- Confirm the DB-latency win: `/api/health` should drop from ~640ms → ~150–250ms (tunnel floor
  only; the ~500ms Neon RTT is gone).

---

## Rollback
Nothing is destructive until Step 7. To roll back at any point: scale the k3s
`cloudflared` + `expertsschool` deploys back to their replicas (`--replicas=2/3`) and scale
DOKS cloudflared to 0. DNS/tunnel are shared, so traffic returns to k3s immediately. Neon/R2
are shared, so no data divergence.

## Gotchas
- **Storage:** only `03-redis.yaml` needs `do-block-storage`. Valkey data is derived cache — a
  fresh PVC is fine (rebuilds from Neon).
- **Secrets are the one manual step:** the two Doppler bootstrap tokens (Step 2). Everything
  else syncs via ESO from Doppler, unchanged.
- **Image arch:** CI already builds multi-arch (amd64+arm64); DOKS Basic nodes are amd64 — fine.
- **Deploy flow unchanged:** the SHA-pinned `kustomization.yaml` + Flux still drives releases;
  only the cluster Flux runs on changed.
- **Two clusters briefly share the tunnel** (Step 5–6) — expected and safe; kill k3s cloudflared
  to finish cutover.
