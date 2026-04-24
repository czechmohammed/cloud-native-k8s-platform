# cloud-native-k8s-platform

Cloud Computing project for the M2 MoSIG program at Grenoble INP - Ensimag (2025-2026).

The goal was to deploy and operate Google's Online Boutique (11 microservices) on GKE. The base app was given to us. Everything else (IaC, monitoring, load testing, canary deployments, autoscaling, custom microservice) was built from scratch.

Full report with screenshots and results: [report.pdf](./report.pdf)

---

## What we built

### Cluster setup

3-node GKE cluster, Standard mode, e2-medium, europe-west1-b. The default resource requests were too high for the nodes so we ended up using Kustomize overlays to tune CPU requests on non-critical services. No changes to the original manifests.

### Infrastructure as Code

We did the load generator VM two ways:

- Terraform only, with a startup script baked in
- Terraform + Ansible, clean separation between provisioning and config management

Both are documented and in the repo.

### Monitoring

kube-prometheus-stack via Helm. Grafana dashboards at the cluster, node, and pod level. We also added a Redis exporter with a ServiceMonitor for DB-specific metrics, and wrote 5 custom alert rules covering CPU, memory, pod restarts, and Redis availability.

### Load testing

Locust on a GCP VM in the same zone as the cluster. We ran it for 22 hours:

- 351,603 requests
- 99.89% success rate
- 27ms average response time

We also ran it from a laptop as a sanity check: 956ms average, 2.61% failure rate. The gap makes it obvious why you want your load generator close to the cluster.

### Canary deployment

We did a progressive rollout on the recommendation service: 33% to v2, then adjusted to 25%, then full switch to 100%. Zero downtime. Each step was monitored in Grafana before moving on.

### Horizontal Pod Autoscaling

HPA on the frontend (50% CPU target, 1 to 3 replicas). Under load it triggered at 96% CPU and scaled to 3 replicas in under a minute.

One thing that caught us off guard: CPU requests were sitting at 93.3% committed while actual usage was only 10.6%. The scheduler saw no room even though the nodes were mostly idle. Good illustration of the difference between scheduling capacity and actual performance headroom.

### Custom microservice

OrderLog service, written in Python with Flask. Logs orders to Redis and exposes a query endpoint. Deployed on the cluster with its own manifests, reuses the existing Redis instance.

---

## Numbers

| metric | value |
|---|---|
| load test duration | 22 hours |
| total requests | 351,603 |
| success rate | 99.89% |
| average response time | 27ms |
| HPA scale-up time | under 1 minute |
| cluster CPU actual usage | 10.6% |

---

## Stack

Kubernetes (GKE Standard), Terraform, Ansible, Kustomize, Prometheus, Grafana, Alertmanager, Helm, Locust, Docker, Python/Flask, GCP (europe-west1)

---

## Repo structure

    kubernetes-manifests/       manifests for all 11 microservices
    custom-config/              Kustomize overlay for resource tuning
    canary-deployment/          v1/v2 traffic split config
    terraform-ansible-loadgen/  load generator VM (Terraform + Ansible)
    terraform-loadgen-main.tf   Terraform-only variant
    orderlog/                   OrderLog microservice (Python/Flask)
    orderlog-deployment.yaml    K8s deployment for OrderLog
    prometheus-alerts.yaml      5 custom alert rules
    redis-exporter.yaml         Redis exporter + ServiceMonitor
    simulate-orders.sh          quick script to test order logging
    report.pdf                  full report with all results and screenshots

---

## How to deploy

You need: gcloud, kubectl, terraform, ansible, helm.

**Cluster**
```bash
gcloud container clusters create my-cluster \
  --zone europe-west1-b \
  --num-nodes 3 \
  --machine-type e2-medium
```

**App**
```bash
kubectl apply -k custom-config/
```

**Monitoring**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=7d
```

**Custom components**
```bash
kubectl apply -f redis-exporter.yaml
kubectl apply -f prometheus-alerts.yaml
kubectl apply -f orderlog-deployment.yaml
```

**Load generator**
```bash
cd terraform-ansible-loadgen
terraform init && terraform apply
# put the VM IP in inventory.ini
ansible-playbook playbook.yml
```

---

## Course

M2 MoSIG - Cloud Computing
Grenoble INP - Ensimag / Universite Grenoble Alpes
Instructors: Thomas Ropars and Renaud Lachaize
