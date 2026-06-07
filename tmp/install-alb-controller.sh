#!/bin/bash
set -e

cd /Users/hephzibahfolami/Documents/altschool/project-bedrock/terraform

echo "Getting ALB controller IAM role ARN from Terraform..."
ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)
echo "ALB Role ARN: $ALB_ROLE_ARN"

echo "Adding EKS Helm repository..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=project-bedrock-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN"

echo "Waiting for ALB controller to be ready..."
kubectl wait --for=condition=available deployment/aws-load-balancer-controller \
  -n kube-system --timeout=300s

echo "✅ ALB controller installed successfully!"