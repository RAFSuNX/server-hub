# Monitoring Agent Stack

**Deploy on systema via Portainer**

This is a fully self-contained agent stack. All configuration is embedded in the compose file using Docker configs - no external config files needed!

## What's Included

- **cAdvisor**: Exports container metrics to Prometheus (port 8080)
- **Node Exporter**: Exports host metrics to Prometheus (port 9100)
- **Promtail**: Ships all container and system logs to Loki on systemc

## How It Works

```
systema (this stack)          →  Tailscale  →  systemc (monitoring-central)
├── cAdvisor:8080             →   metrics   →  Prometheus
├── Node Exporter:9100        →   metrics   →  Prometheus
└── Promtail                  →    logs     →  Loki:3100
```

All logs are tagged with `host: systema` so you can filter by server in Grafana.

## Quick Deploy via Portainer

### Step 1: Deploy Stack in Portainer

1. Open **Portainer** on systema (connect to systema endpoint)
2. Go to **Stacks** → **Add stack**
3. **Name**: `monitoring-agent`
4. **Build method**: Choose one:

   **Option A - Git Repository (Recommended)**
   - Repository URL: `https://github.com/your-repo/server-hub` (or your repo)
   - Repository reference: `main`
   - Compose path: `docker_composes/monitoring-agent/compose.yaml`

   **Option B - Upload**
   - Upload the `compose.yaml` file

   **Option C - Web editor**
   - Copy and paste the entire `compose.yaml` content

5. **Environment variables** (scroll down):
   ```
   SYSTEMC_IP=100.x.x.x
   ```

   **Note**: Get systemc's Tailscale IP by running `tailscale ip -4` on systemc

6. Click **Deploy the stack**

### Step 2: Verify

Check containers are running in Portainer or via SSH:
```bash
docker ps | grep -E "cadvisor-agent|node-exporter-agent|promtail"
```

You should see 3 containers running.

### Step 3: Test Connectivity

SSH to systema and run:

```bash
# Test cAdvisor metrics endpoint
curl http://localhost:8080/metrics | head

# Test Node Exporter metrics endpoint
curl http://localhost:9100/metrics | head

# Test if Promtail can reach Loki on systemc
docker exec promtail wget -qO- http://systemc:3100/ready
```

If all three commands work, everything is connected properly!

### Step 4: Check Prometheus Targets

1. On systemc, access Prometheus (or via Grafana → Explore)
2. Go to Status → Targets
3. Look for:
   - `systema-containers` (should be UP)
   - `systema-host` (should be UP)

If they show UP, metrics are being collected successfully!

## What Gets Monitored

### Container Metrics (via cAdvisor):
- CPU usage per container
- Memory usage per container
- Network I/O per container
- Disk I/O per container
- Container states and restarts

### Host Metrics (via Node Exporter):
- CPU usage (total and per-core)
- Memory and swap usage
- Disk usage and I/O statistics
- Network interface statistics
- Load average
- File system information

### Logs (via Promtail):
- All Docker container logs (stdout/stderr)
- System logs from `/var/log/*.log`
- Each log entry tagged with:
  - `host: systema`
  - `container: container_name`
  - `compose_service: service_name`
  - `compose_project: project_name`

## Ports Exposed

These ports are exposed on systema's host network for Prometheus to scrape via Tailscale:

- **8080**: cAdvisor metrics endpoint
- **9100**: Node Exporter metrics endpoint

No ports need to be opened in firewall - Tailscale handles the secure networking.

## Troubleshooting

### Prometheus shows systema targets as DOWN

1. **Check containers are running**:
   ```bash
   docker ps | grep -E "cadvisor-agent|node-exporter-agent"
   ```

2. **Test metrics endpoints locally**:
   ```bash
   curl http://localhost:8080/metrics
   curl http://localhost:9100/metrics
   ```

3. **Test from systemc** (SSH to systemc):
   ```bash
   curl http://systema:8080/metrics
   curl http://systema:9100/metrics
   ```

4. **Check Tailscale**:
   ```bash
   tailscale status
   ping systemc
   ```

### Logs not appearing in Grafana

1. **Check Promtail logs**:
   ```bash
   docker logs promtail
   ```

   Look for errors connecting to Loki.

2. **Test Loki connectivity**:
   ```bash
   docker exec promtail wget -qO- http://systemc:3100/ready
   ```

   Should return: `ready`

3. **Check the SYSTEMC_IP**:
   ```bash
   docker inspect promtail | grep -A5 extra_hosts
   ```

   Should show your systemc Tailscale IP

4. **Verify Loki is running on systemc**:
   ```bash
   # On systemc
   docker ps | grep loki
   docker logs loki | tail -20
   ```

### cAdvisor fails to start

If you see errors about `/dev/kmsg`:

1. In Portainer, go to Stacks → `monitoring-agent` → Editor
2. Change `privileged: true` to `privileged: false`
3. Remove the `devices` section
4. Update the stack

Most metrics will still work without `/dev/kmsg` access.

### High CPU usage from cAdvisor

cAdvisor can use some CPU. To reduce:

1. Edit the stack in Portainer
2. Add to cadvisor-agent service:
   ```yaml
   command:
     - '--housekeeping_interval=30s'  # Default is 10s
     - '--docker_only=true'
   ```
3. Update the stack

## Updating Configuration

To change configuration (e.g., modify which logs to collect):

1. In Portainer, go to **Stacks** → `monitoring-agent`
2. Click **Editor**
3. Scroll to the bottom to find the `promtail-config` section
4. Modify as needed
5. Click **Update the stack**

## Adding More Servers

To monitor additional servers:

1. Deploy this same stack on the new server via Portainer
2. Change the hostname in the promtail config from `systema` to the new server name
3. Add the new server to Prometheus config on systemc:
   - Edit monitoring-central stack in Portainer
   - Add new scrape configs in the `prometheus-config` section
   - Update the stack

## Next Steps

- Access Grafana on systemc
- Import dashboard ID **179** for Docker monitoring
- Import dashboard ID **1860** for detailed host metrics
- Import dashboard ID **13639** for log viewing
- Filter by `host="systema"` to see systema's metrics and logs
