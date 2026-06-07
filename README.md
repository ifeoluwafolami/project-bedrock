# Project Bedrock — InnovateMart EKS Deployment

**AltSchool Cloud Engineering Karatu 2025 | Student: ALT/SOE/025/3333**

## Architecture

- VPC: `project-bedrock-vpc` (us-east-1, 2 AZs, public + private subnets)
- EKS: `project-bedrock-cluster` (v1.31, nodes in private subnets)
- Data: RDS MySQL, RDS PostgreSQL, DynamoDB (all in private subnets)
- Ingress: AWS Load Balancer Controller → ALB
- Observability: CloudWatch (control plane + containers via CloudWatch Observability addon)
- Serverless: S3 `bedrock-assets-alt-soe-025-3333` → Lambda `bedrock-asset-processor`
- All resources tagged: `Project: karatu-2025-capstone`

## Prerequisites

```bash
aws --version        # >= 2.x
terraform -v         # >= 1.0
kubectl version --client
helm version
```

## Deployment Steps

### 1. Create Terraform remote state bucket (one-time)

```bash
aws s3api create-bucket \
  --bucket project-bedrock-tfstate-229635049440 \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket project-bedrock-tfstate-229635049440 \
  --versioning-configuration Status=Enabled
```

### 2. Deploy infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

EKS + RDS take ~15-20 minutes. Go get coffee.

### 3. Configure kubectl

```bash
aws eks update-kubeconfig \
  --name project-bedrock-cluster \
  --region us-east-1
kubectl get nodes
```

### 4. Install AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get ALB controller role ARN from terraform output
ALB_ROLE_ARN=$(cd terraform && terraform output -raw alb_controller_role_arn 2>/dev/null || echo "")

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=project-bedrock-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN
```

### 5. Deploy the retail store app

```bash
# Create namespace
kubectl apply -f kubernetes/ingress.yaml

# Deploy the app (AWS's pre-built manifest — deploys all services)
kubectl apply -f https://github.com/aws-containers/retail-store-sample-app/releases/latest/download/kubernetes.yaml -n retail-app

# Wait for everything to be ready
kubectl wait --for=condition=available deployments --all -n retail-app --timeout=300s
```

### 6. Get the application URL

```bash
kubectl get ingress -n retail-app
# Use the ADDRESS field — this is your ALB DNS name
```

### 7. Generate grading output

```bash
cd terraform
terraform output -json > ../grading.json
cat ../grading.json
```

## CI/CD Pipeline

- **Pull Request** → triggers `terraform plan`, posts output as PR comment
- **Merge to main** → triggers `terraform apply`

### Setup GitHub secrets

In your GitHub repo → Settings → Secrets → Actions, add:
- `AWS_ACCESS_KEY_ID` — your AWS access key
- `AWS_SECRET_ACCESS_KEY` — your AWS secret key

## Grading Credentials (bedrock-dev-view)

After `terraform apply`, run:

```bash
cd terraform
terraform output dev_view_access_key_id
terraform output -raw dev_view_secret_access_key
terraform output -raw dev_view_console_password
terraform output dev_view_console_url
```

## Verify developer access

```bash
# Configure a separate AWS profile for the dev user
aws configure --profile bedrock-dev

# This should work:
kubectl get pods -n retail-app --as=bedrock-dev-view

# This should fail with Forbidden:
kubectl delete pod <any-pod> -n retail-app --as=bedrock-dev-view
```

## Test the Lambda trigger

```bash
# Upload a test file using the dev user credentials
aws s3 cp test-image.jpg s3://bedrock-assets-alt-soe-025-3333/ \
  --profile bedrock-dev

# Check Lambda logs
aws logs tail /aws/lambda/bedrock-asset-processor --follow
```

## Teardown (save AWS costs!)

```bash
cd terraform
terraform destroy
```
