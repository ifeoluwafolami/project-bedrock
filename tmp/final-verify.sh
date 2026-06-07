#!/bin/bash
set -e

cd /Users/hephzibahfolami/Documents/altschool/project-bedrock/terraform

echo "========================================"
echo "FINAL VERIFICATION & OUTPUT COLLECTION"
echo "========================================"
echo ""

echo "1. EKS Cluster Status:"
aws eks describe-cluster --name project-bedrock-cluster --region us-east-1 --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}' --output table

echo ""
echo "2. Node Status:"
kubectl get nodes -o wide

echo ""
echo "3. All Pods:"
kubectl get pods -A

echo ""
echo "4. Services:"
kubectl get svc -A

echo ""
echo "5. Ingresses:"
kubectl get ingress -A

echo ""
echo "6. Terraform Outputs:"
terraform output

echo ""
echo "7. Saving outputs to file..."
terraform output -json > /tmp/terraform-outputs.json
echo "Outputs saved to: /tmp/terraform-outputs.json"

echo ""
echo "========================================"
echo "✅ VERIFICATION COMPLETE!"
echo "========================================"
echo ""
echo "Key information for grading:"
echo "- Cluster Endpoint: $(terraform output -raw cluster_endpoint)"
echo "- ALB Controller Role: $(terraform output -raw alb_controller_role_arn)"
echo ""
