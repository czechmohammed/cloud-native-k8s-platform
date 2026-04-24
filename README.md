# cloud-native-k8s-platform

Cloud Computing project for the M2 MoSIG program at Grenoble INP - Ensimag (2025-2026).

The goal was to deploy and operate Google's Online Boutique (11 microservices) on GKE. The base app was given. Everything else (IaC, monitoring, load testing, canary deployments, autoscaling, custom microservice) was built from scratch.

Full report with screenshots and results: [report.pdf](./report.pdf)

---

## What got built

### Cluster setup

3-node GKE cluster, Standard mode, e2-medium, europe-west1-b. The default resource requests were too high for the nodes so Kustomize overlays were used to tune CPU requests on non-critical services. No changes to the original manifests.

### Infrastructure as Code

The load generator VM was done two ways:

- Terraform only, with a startup script baked in
- Terraform + Ansible, clean separation between provisioning and config management

Both are documented and in the repo.

### Monitoring

kube-prometheus-stack via Helm. Grafana dashboards at the cluster, node, and pod level. A Redis exporter with a ServiceMonitor was added for DB-specific metrics, along with 5 custom alert rules covering CPU, memory, pod restarts, and Redis availability.

### Load testing

Locust on a GCP VM in the same zone as the cluster. 22-hour sustained test:

- 351,603 requests
- 99.89% success rate
- 27ms average response time

Running from a laptop as a sanity check gave 956ms average and 2.61% failure rate. The gap makes it obvious why the load generator needs to be close to the cluster.

### Canary deployment

Progressive rollout on the recommendation service: 33% to v2, adjusted to 25%, then full switch to 100%. Zero downtime. Each step was monitored in Grafana before moving on.

### Horizontal Pod Autoscaling

HPA on the frontend (50% CPU target, 1 to 3 replicas). Under load it triggered at 96% CPU and scaled to 3 replicas in under a minute.

One interesting issue: CPU requests were sitting at 93.3% committed while actual usage was only 10.6%. The scheduler saw no room even though the nodes were mostly idle. Good illustration of the difference between scheduling capacity and actual performance headroom.

### Custom microservice

OrderLog service written in Python with Flask. Logs orders to Redis and exposes a query endpoint. Deployed on the cluster with its own manifests, reuses the existing Redis instance.

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
