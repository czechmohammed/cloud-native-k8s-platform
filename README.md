# Cloud-Native Kubernetes Platform on GCP

End-to-end deployment and operation of a microservices application on Google Kubernetes Engine — built as part of the M2 MoSIG Cloud Computing course at Grenoble INP - Ensimag.

## Results

| Metric | Value |
|--------|-------|
| Total requests (22h load test) | 351,603 |
| Success rate | 99.89% |
| Average response time | 27ms |
| Cluster CPU utilization | 10.6% (efficient resource allocation) |
| HPA scale-up time | < 1 minute |
| Canary deployment | 33% → 25% → 100% with zero downtime |

## Stack

| Layer | Tools |
|-------|-------|
| Orchestration | Kubernetes (GKE Standard mode) |
| Infrastructure as Code | Terraform + Ansible |
| Configuration management | Kustomize |
| Monitoring | Prometheus + Grafana + Alertmanager |
| Load testing | Locust |
| Containerization | Docker |
| Cloud | Google Cloud Platform (europe-west1) |

## Architecture

11-microservice e-commerce application (Google Online Boutique) deployed on a 3-node GKE cluster (e2-medium).
Load Generator (Locust on GCP VM)
↓
Frontend (LoadBalancer) → CartService → Redis
→ ProductCatalogService
→ CurrencyService
→ CheckoutService → PaymentService
→ ShippingService
→ EmailService
→ OrderLog (custom)
→ RecommendationService
→ AdService
Monitoring: Prometheus + Grafana + Redis Exporter
IaC: Terraform (GKE cluster + VM) + Ansible (configuration)

## Repository Structure
.
├── kubernetes-manifests/        # K8s manifests for all 11 microservices
├── custom-config/               # Kustomize overlay — resource optimization
│   ├── kustomization.yaml
│   └── reduce-resources.yaml
├── canary-deployment/           # Canary deployment config (v1/v2 split)
│   ├── recommendationservice-v1.yaml
│   ├── recommendationservice-v2.yaml
│   └── recommendationservice-service.yaml
├── terraform-ansible-loadgen/   # IaC for load generator VM
│   ├── main.tf                  # Terraform — GCP VM provisioning
│   ├── playbook.yml             # Ansible — Docker + Locust setup
│   ├── ansible.cfg
│   └── inventory.ini
├── terraform-loadgen-main.tf    # Terraform-only variant (startup script)
├── orderlog/                    # Custom microservice (Python/Flask)
│   ├── server.py
│   ├── Dockerfile
│   └── requirements.txt
├── orderlog-deployment.yaml     # K8s deployment for OrderLog
├── prometheus-alerts.yaml       # 5 custom alert rules
├── redis-exporter.yaml          # Redis metrics exporter + ServiceMonitor
└── simulate-orders.sh           # Script to simulate order logging

## What Was Built

### 1. GKE Cluster & Application Deployment
- Created a 3-node GKE Standard cluster (europe-west1-b)
- Deployed 11-microservice Online Boutique app
- Solved resource capacity issues using Kustomize overlays (reduced CPU requests for non-critical services)

### 2. Infrastructure as Code
- **Terraform-only**: VM provisioning with startup script for load generator
- **Terraform + Ansible**: Proper separation of concerns — Terraform handles infra, Ansible handles configuration
- Reproducible, version-controlled infrastructure

### 3. Monitoring Stack
- Deployed `kube-prometheus-stack` via Helm
- Cluster, node, and pod-level Grafana dashboards
- Custom Redis exporter with ServiceMonitor for database-specific metrics
- 5 Prometheus alert rules (CPU, memory, pod restarts, Redis availability)

### 4. Load Testing
- Locust deployed on GCP VM (same zone as cluster) for accurate results
- 22-hour sustained test: 351,603 requests, 99.89% success rate, 27ms avg
- Comparison: local laptop (956ms avg, 2.61% failures) vs GCP VM (27ms, 0.11% failures)

### 5. Canary Deployment
- Progressive traffic shifting on `recommendationservice`: 33% → 25% → 100%
- Zero downtime throughout migration
- Monitored via Grafana during each phase

### 6. Horizontal Pod Autoscaling
- HPA configured on frontend (target: 50% CPU, min: 1, max: 3)
- Validated under load: triggered at 96% CPU, scaled to 3 replicas in < 1 minute
- Identified scheduling bottleneck: CPU requests committed at 93.3% vs 10% actual usage

### 7. Custom Microservice — OrderLog
- Built from scratch: Python/Flask REST API
- Integrates with existing Redis instance (zero additional infrastructure cost)
- Endpoints: `POST /log-order`, `GET /orders`, `GET /health`
- Data persistence verified across pod restarts

## How to Deploy

### Prerequisites
- `gcloud` CLI configured with a GCP project
- `kubectl`
- `terraform >= 1.0`
- `ansible >= 2.9`
- `helm >= 3.0`

### 1. Create the GKE cluster
```bash
gcloud container clusters create my-cluster \
  --zone europe-west1-b \
  --num-nodes 3 \
  --machine-type e2-medium
```

### 2. Deploy the application with resource optimization
```bash
kubectl apply -k custom-config/
```

### 3. Deploy monitoring stack
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=7d
```

### 4. Deploy custom components
```bash
kubectl apply -f redis-exporter.yaml
kubectl apply -f prometheus-alerts.yaml
kubectl apply -f orderlog-deployment.yaml
```

### 5. Deploy load generator on GCP VM
```bash
cd terraform-ansible-loadgen
terraform init && terraform apply
# Update inventory.ini with VM IP
ansible-playbook playbook.yml
```

## Key Learnings

- **Requests vs limits**: Kubernetes schedules based on requests, not actual usage — 93.3% CPU committed despite 10% actual utilization
- **Network proximity matters**: 30x response time improvement (956ms → 27ms) by moving load generator to same GCP zone
- **Standard vs Autopilot**: Standard mode exposes capacity issues that Autopilot would hide — better for understanding Kubernetes internals
- **Terraform + Ansible separation**: Better maintainability than startup scripts — config changes don't require VM recreation

## Course

M2 MoSIG — Cloud Computing  
Grenoble INP - Ensimag / Université Grenoble Alpes  
Instructors: Thomas Ropars and Renaud Lachaize
