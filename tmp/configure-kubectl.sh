#!/bin/bash
set -e

echo "Configuring kubectl for project-bedrock-cluster..."
aws eks update-kubeconfig --name project-bedrock-cluster --region us-east-1

echo "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Nodes status:"
kubectl get nodes -o wide

echo "✅ Kubectl configured successfully!"