#!/bin/bash
echo "Deleting GKE cluster..."
gcloud container clusters delete cloud-k8s-cluster \
  --region=europe-west9 \
  --quiet

echo "Verifying no VMs are running..."
gcloud compute instances list

echo "Done. No more billing."
