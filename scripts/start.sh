#!/bin/bash
echo "Creating GKE cluster..."
gcloud container clusters create cloud-k8s-cluster \
  --region=europe-west1 \
  --num-nodes=1 \
  --machine-type=e2-standard-2 \
  --disk-size=20

echo "Configuring kubectl..."
gcloud container clusters get-credentials cloud-k8s-cluster \
  --region=europe-west1

echo "Cluster ready."
kubectl get nodes
