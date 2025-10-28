# Monitoring Central Stack

**Deploy on systemc via Portainer**

This is a fully self-contained monitoring stack. All configuration is embedded in the compose file using Docker configs - no external config files needed!

## What's Included

- **Grafana**: Beautiful dashboards for visualization
- **Prometheus**: Metrics collection and storage (30 days)
- **Loki**: Log aggregation and storage (30 days)
- **cAdvisor**: Monitors systemc's containers
- **Node Exporter**: Monitors systemc's host metrics

## Architecture

```
systemc (this stack)                    systema (monitoring-agent)
├── Grafana (dashboards)                ├── cAdvisor:8080 → Prometheus
├── Prometheus ←────────────scrapes─────┤ Node Exporter:9100 → Prometheus
├── Loki:3100 ←─────────────logs────────└── Promtail → Loki
├── cAdvisor (local)
└── Node Exporter (local)
```

Communication via **Tailscale** network

## Quick Deploy via Portainer

### Step 1: Prepare Data Directories

SSH to systemc and run:

```bash
mkdir -p ~/dockerc/monitoring/{grafana,prometheus,loki}
sudo chown -R 1000:1000 ~/dockerc/monitoring
```

### Step 2: Deploy Stack in Portainer

1. Open **Portainer** on systemc (access your Portainer UI)
2. Select your **systemc** endpoint
3. Go to **Stacks** → **Add stack**
4. **Name**: `monitoring-central`
5. **Build method**: Choose one:

   **Option A - Git Repository (Recommended)**
   - Repository URL: `https://github.com/your-repo/server-hub` (or your repo)
   - Repository reference: `main`
   - Compose path: `docker_composes/monitoring-central/compose.yaml`

   **Option B - Upload**
   - Upload the `compose.yaml` file

   **Option C - Web editor**
   - Copy and paste the entire `compose.yaml` content

6. **Environment variables** (scroll down):
   ```
   UPUID=1000
   UPGID=1000
   HOME=/home/yourusername
   GRAFANA_ADMIN_USER=admin
   GRAFANA_ADMIN_PASSWORD=ChangeMe123!
   GRAFANA_DOMAIN=grafana.yourdomain.com
   SYSTEMA_IP=100.x.x.x
   ```

   **Note**: Get your Tailscale IPs by running `tailscale ip -4` on each server

7. Click **Deploy the stack**

### Step 3: Verify

Check containers are running in Portainer or via SSH:
```bash
docker ps | grep -E "grafana|prometheus|loki|cadvisor|node-exporter"
```

You should see 5 containers running.

## Accessing Services

- **Grafana**: Add to your Cloudflare tunnel or access via http://grafana:3000 on the public network
- **Prometheus**: http://prometheus:9090 (internal)
- **Loki**: http://loki:3100 (exposed for Promtail)

## Setting Up Grafana Dashboards

1. **Login to Grafana**
   - Username: `admin` (or what you set in GRAFANA_ADMIN_USER)
   - Password: What you set in GRAFANA_ADMIN_PASSWORD

2. **Verify Datasources**
   - Go to **Configuration** → **Data sources**
   - You should see **Prometheus** and **Loki** already configured
   - Click each one and click "Save & test" to verify connectivity

3. **Import Dashboards**
   - Go to **Dashboards** → **New** → **Import**
   - Import these dashboard IDs one by one:
     - **179**: Docker and system monitoring
     - **893**: Docker Container & Host Metrics
     - **1860**: Node Exporter Full (detailed host metrics)
     - **13639**: Loki Dashboard (for viewing logs)
   - For each, select **Prometheus** or **Loki** as the datasource when prompted

4. **View Your Metrics**
   - You'll immediately see metrics from systemc
   - Once you deploy monitoring-agent on systema, you'll see those metrics too

## What Gets Monitored

### systemc (local):
- All container metrics (CPU, RAM, network, disk I/O)
- Host metrics (CPU, RAM, disk usage, network)
- All container logs

### systema (remote):
- All container metrics (once agent is deployed)
- Host metrics (once agent is deployed)
- All container logs (once agent is deployed)

## Updating Configuration

If you need to change any configuration (e.g., adjust retention, add more servers):

1. In Portainer, go to **Stacks** → `monitoring-central`
2. Click **Editor**
3. Modify the configs at the bottom of the compose file
4. Click **Update the stack**

Example: To add retention, edit the `prometheus-config` section at the bottom.

## Troubleshooting

### Can't access Grafana

Check if it's running:
```bash
docker logs grafana
```

Check if it's on the public network:
```bash
docker inspect grafana | grep -A10 Networks
```

### Prometheus shows systema targets as DOWN

1. Make sure monitoring-agent is deployed on systema
2. Test Tailscale connectivity from systemc:
   ```bash
   curl http://systema:8080/metrics
   curl http://systema:9100/metrics
   ```
3. Check Prometheus targets: Access Prometheus and go to Status → Targets

### No logs from systema

1. Make sure monitoring-agent is deployed on systema
2. Check if Promtail can reach Loki:
   ```bash
   # On systema
   docker exec promtail wget -qO- http://systemc:3100/ready
   ```
3. Check Loki logs:
   ```bash
   docker logs loki
   ```

### Permission errors for data directories

```bash
sudo chown -R 1000:1000 ~/dockerc/monitoring
```

## Data Retention

- **Prometheus**: 30 days (`--storage.tsdb.retention.time=30d`)
- **Loki**: 30 days (720h in config)

To change, edit the compose file in Portainer and update the stack.

## Next Steps

After deploying this on systemc, deploy **monitoring-agent** on systema to complete the setup!
