#!/bin/bash
set -e

echo "Creating retail-app namespace..."
kubectl create namespace retail-app --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying AWS retail store sample app..."
kubectl apply -f https://github.com/aws-containers/retail-store-sample-app/releases/latest/download/kubernetes.yaml

echo "Waiting for deployments to be ready (this may take 3-5 minutes)..."
kubectl wait --for=condition=available deployments --all -n default --timeout=600s

echo ""
echo "Getting application ingress..."
kubectl get ingress -n default

echo ""
echo "Getting all services..."
kubectl get svc -n default

echo ""
echo "✅ Retail app deployed successfully!"
echo ""
echo "To access the app, find the ALB DNS name above (EXTERNAL-IP or Address)"
