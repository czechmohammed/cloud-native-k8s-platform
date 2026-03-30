#!/bin/bash
echo "Creating GKE cluster..."
gcloud container clusters create cloud-k8s-cluster \
  --region=europe-west9 \
  --num-nodes=1 \
  --machine-type=e2-medium \
  --disk-size=20

echo "Configuring kubectl..."
gcloud container clusters get-credentials cloud-k8s-cluster \
  --region=europe-west9

echo "Cluster ready."
kubectl get nodes
