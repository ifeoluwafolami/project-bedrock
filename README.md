# Project Bedrock - InnovateMart EKS Deployment

AltSchool Cloud Engineering Karatu 2025
Student ID: `ALT/SOE/025/3333`

## Architecture

- Region: `us-east-1`
- VPC: `project-bedrock-vpc` with public and private subnets across two AZs
- EKS: `project-bedrock-cluster` on Kubernetes `1.34`
- Namespace: `retail-app`
- Data layer: RDS MySQL, RDS PostgreSQL, and DynamoDB
- In-cluster services: Redis and RabbitMQ
- Ingress: AWS Load Balancer Controller and ALB Ingress
- Observability: EKS control plane logs and CloudWatch Observability add-on
- Serverless: S3 `bedrock-assets-alt-soe-025-3333` triggers Lambda `bedrock-asset-processor`
- Tagging: `Project: karatu-2025-capstone`

## Prerequisites

```bash
aws --version
terraform -v
kubectl version --client
helm version
jq --version
```

## Remote State

Create the S3 backend bucket once before `terraform init`:

```bash
aws s3api create-bucket \
  --bucket project-bedrock-tfstate-229635049440 \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket project-bedrock-tfstate-229635049440 \
  --versioning-configuration Status=Enabled
```

## Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Then configure `kubectl`:

```bash
aws eks update-kubeconfig \
  --name project-bedrock-cluster \
  --region us-east-1
```

## Install AWS Load Balancer Controller

```bash
ALB_ROLE_ARN="$(terraform -chdir=terraform output -raw alb_controller_role_arn)"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=project-bedrock-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN"
```

## Deploy Retail Store App

Use the committed Helm deployment script:

```bash
./scripts/deploy-retail-app.sh
```

The script deploys the public ECR Helm charts into `retail-app` and injects live Terraform outputs at deploy time:

- `catalog` uses Amazon RDS MySQL.
- `orders` uses Amazon RDS PostgreSQL and in-cluster RabbitMQ.
- `carts` uses Amazon DynamoDB through an IRSA role.
- `checkout` uses in-cluster Redis.
- `ui` exposes the store through an ALB Ingress.

Get the application URL:

```bash
kubectl get ingress ui -n retail-app
```

Copy the `ADDRESS` value into the submission document as:

```text
Application URL: http://ADDRESS_FROM_INGRESS
```

## CI/CD Pipeline

The workflow in `.github/workflows/terraform.yml` does the required automation:

- Pull request to `main`: runs `terraform plan` and posts the plan as a PR comment.
- Push or merge to `main`: runs `terraform apply -auto-approve`.

Configure these GitHub Actions secrets before opening the PR:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

After pushing, capture screenshots or links showing:

- The PR plan workflow completed successfully.
- The Terraform plan appeared as a PR comment.
- The merge-to-main apply workflow completed successfully.

## Grading Credentials

After `terraform apply`, copy fresh values into the Google Doc:

```bash
terraform -chdir=terraform output dev_view_access_key_id
terraform -chdir=terraform output -raw dev_view_secret_access_key
terraform -chdir=terraform output -raw dev_view_console_password
terraform -chdir=terraform output dev_view_console_url
```

Do not commit the secret access key or console password to the public repository.

## Verify Developer Access

```bash
aws configure --profile bedrock-dev-view

aws eks update-kubeconfig \
  --name project-bedrock-cluster \
  --region us-east-1 \
  --profile bedrock-dev-view \
  --alias bedrock-dev-view

kubectl --context bedrock-dev-view get pods -n retail-app
kubectl --context bedrock-dev-view delete pod "$(kubectl get pod -n retail-app -o jsonpath='{.items[0].metadata.name}')" -n retail-app
```

Expected result:

- `get pods` succeeds.
- `delete pod` fails with `Forbidden`.

## Verify S3 to Lambda

```bash
echo "test" > /tmp/bedrock-test-image.txt

aws s3 cp /tmp/bedrock-test-image.txt \
  "s3://$(terraform -chdir=terraform output -raw assets_bucket_name)/bedrock-test-image.txt" \
  --profile bedrock-dev-view

aws logs tail /aws/lambda/bedrock-asset-processor \
  --region us-east-1 \
  --since 15m
```

Expected log line:

```text
Image received: bedrock-test-image.txt
```

## Grading Output

The assignment requires this file at the repository root:

```bash
cd terraform
terraform output -json > ../grading.json
```

Inspect `grading.json` before committing. If it contains sensitive helper outputs, keep only the required grading keys in the public repository:

- `cluster_endpoint`
- `cluster_name`
- `region`
- `vpc_id`
- `assets_bucket_name`

## Teardown

```bash
cd terraform
terraform destroy
```
