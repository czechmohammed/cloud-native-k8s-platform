# cloud-native-k8s-platform

Deployment and operation of a microservices application on Google Kubernetes Engine, done as part of the M2 MoSIG Cloud Computing course at Grenoble INP - Ensimag (2025-2026).

The base application is Google's Online Boutique (11 microservices). Everything around it — IaC, monitoring, load testing, canary deployments, autoscaling, and a custom microservice — was built and configured from scratch.

The full lab report is available in [report.pdf](./report.pdf).

## What was built

**Cluster and application deployment**
3-node GKE cluster (Standard mode, e2-medium, europe-west1-b). Ran into resource capacity issues with the default config, solved them using Kustomize overlays to reduce CPU requests on non-critical services without touching the original manifests.

**Infrastructure as Code**
Two approaches for the load generator VM, both documented:
- Terraform only, using a startup script
- Terraform + Ansible, with proper separation between infra provisioning and configuration management

**Monitoring**
Deployed kube-prometheus-stack via Helm. Set up cluster, node, and pod-level Grafana dashboards. Added a Redis exporter with a ServiceMonitor for database-specific metrics. Wrote 5 custom Prometheus alert rules (CPU, memory, pod restarts, Redis availability).

**Load testing**
Locust deployed on a GCP VM in the same zone as the cluster. Ran a 22-hour sustained test:
- 351,603 requests
- 99.89% success rate
- 27ms average response time

Running the load generator locally (from my laptop) gave 956ms average and 2.61% failures — the difference shows how much network proximity matters for accurate benchmarks.

**Canary deployment**
Progressive traffic shift on the recommendation service: 33% to v2, adjusted to 25%, then full rollout to 100%. No downtime throughout. Each phase monitored via Grafana.

**Horizontal Pod Autoscaling**
HPA on the frontend service (target: 50% CPU, min 1 replica, max 3). Validated under load: triggered at 96% CPU, scaled to 3 replicas in under a minute. Ran into an interesting issue — CPU requests were committed at 93.3% while actual CPU usage was only 10.6%, which blocked the scheduler from placing new pods. Documents the difference between scheduling capacity and performance capacity.

**Custom microservice**
Built an OrderLog service from scratch (Python, Flask) that logs orders to Redis and exposes a query endpoint. Deployed on the cluster with its own Kubernetes manifests. Uses the existing Redis instance so no extra infrastructure needed.

## Results

| metric | value |
|---|---|
| load test duration | 22 hours |
| total requests | 351,603 |
| success rate | 99.89% |
| average response time | 27ms |
| HPA scale-up time | under 1 minute |
| cluster CPU actual usage | 10.6% |

## Stack

Kubernetes (GKE Standard), Terraform, Ansible, Kustomize, Prometheus, Grafana, Alertmanager, Helm, Locust, Docker, Python/Flask, GCP (europe-west1)

## Repository structure
kubernetes-manifests/       K8s manifests for all 11 microservices
custom-config/              Kustomize overlay for resource optimization
canary-deployment/          v1/v2 split config for canary rollout
terraform-ansible-loadgen/  IaC for the load generator VM (Terraform + Ansible)
terraform-loadgen-main.tf   Terraform-only variant with startup script
orderlog/                   Custom OrderLog microservice (Python/Flask)
orderlog-deployment.yaml    K8s deployment for OrderLog
prometheus-alerts.yaml      5 custom alert rules
redis-exporter.yaml         Redis exporter and ServiceMonitor
simulate-orders.sh          Script to test order logging
report.pdf                  Full lab report with all results and screenshots

## How to deploy

You need gcloud, kubectl, terraform, ansible, and helm.

Create the cluster:
```bash
gcloud container clusters create my-cluster \
  --zone europe-west1-b \
  --num-nodes 3 \
  --machine-type e2-medium
```

Deploy the app with resource optimization:
```bash
kubectl apply -k custom-config/
```

Deploy monitoring:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=7d
```

Deploy custom components:
```bash
kubectl apply -f redis-exporter.yaml
kubectl apply -f prometheus-alerts.yaml
kubectl apply -f orderlog-deployment.yaml
```

Deploy the load generator on a GCP VM:
```bash
cd terraform-ansible-loadgen
terraform init && terraform apply
# update inventory.ini with the VM IP
ansible-playbook playbook.yml
```

## Course

M2 MoSIG - Cloud Computing
Grenoble INP - Ensimag / Universite Grenoble Alpes
Instructors: Thomas Ropars and Renaud Lachaize
