# Cloud Lab — Online Boutique on GKE

Deployment of a microservices application on Google Kubernetes Engine.

## Structure
- `kubernetes/` — Kubernetes manifests
- `terraform/` — Infrastructure as Code
- `scripts/` — Cluster create/delete scripts
- `monitoring/` — Prometheus and Grafana configuration

## Usage
```bash
# Create cluster and deploy
./scripts/start.sh

# Delete cluster
./scripts/stop.sh
```
