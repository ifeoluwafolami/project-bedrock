NAME: Hephzibah Ifeoluwa Folami
STUDENT ID: ALT/SOE/025/3333
Cohort: Karatu 2025  
GitHub Repository: https://github.com/ifeoluwafolami/project-bedrock

---

This capstone project demonstrates the successful deployment of a production-grade, highly available e-commerce application (InnovateMart) on Amazon EKS using Infrastructure as Code (Terraform). The architecture implements AWS best practices including:

- Multi-AZ VPC with public and private subnets
- EKS cluster v1.31 with managed node groups in private subnets
- RDS MySQL and PostgreSQL databases for data persistence
- DynamoDB for session/cart management
- Application Load Balancer for ingress traffic management
- CloudWatch for observability and monitoring
- S3 + Lambda for serverless asset processing
- IAM roles with least-privilege access following security best practices

Project Goals
1. Deploy a production-ready EKS cluster with auto-scaling capabilities
2. Implement multi-database architecture (MySQL, PostgreSQL, DynamoDB)
3. Configure secure networking with public/private subnet isolation
4. Set up automated ingress management with AWS Load Balancer Controller
5. Enable comprehensive monitoring and logging
6. Implement Infrastructure as Code for repeatability and version control




### High-Level Architecture


```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                    │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                       │ │
│  │                                                              │ │
│  │  ┌──────────────────┐          ┌──────────────────┐        │ │
│  │  │   AZ 1           │          │   AZ 2           │        │ │
│  │  │                  │          │                  │        │ │
│  │  │  Public Subnet   │          │  Public Subnet   │        │ │
│  │  │  10.0.0.0/24     │          │  10.0.1.0/24     │        │ │
│  │  │  ┌────────────┐  │          │  ┌────────────┐  │        │ │
│  │  │  │ NAT Gateway│  │          │  │ NAT Gateway│  │        │ │
│  │  │  └────────────┘  │          │  └────────────┘  │        │ │
│  │  └──────────────────┘          └──────────────────┘        │ │
│  │           │                              │                   │ │
│  │  ┌──────────────────┐          ┌──────────────────┐        │ │
│  │  │ Private Subnet   │          │ Private Subnet   │        │ │
│  │  │ 10.0.10.0/24     │          │ 10.0.11.0/24     │        │ │
│  │  │                  │          │                  │        │ │
│  │  │  ┌───────────┐   │          │  ┌───────────┐   │        │ │
│  │  │  │ EKS Nodes │   │          │  │ EKS Nodes │   │        │ │
│  │  │  │ (t3.medium)│  │          │  │ (t3.medium)│  │        │ │
│  │  │  └───────────┘   │          │  └───────────┘   │        │ │
│  │  │                  │          │                  │        │ │
│  │  │  ┌───────────┐   │          │  ┌───────────┐   │        │ │
│  │  │  │    RDS    │   │          │  │    RDS    │   │        │ │
│  │  │  │  (MySQL)  │   │          │  │(PostgreSQL)│  │        │ │
│  │  │  └───────────┘   │          │  └───────────┘   │        │ │
│  │  └──────────────────┘          └──────────────────┘        │ │
│  │                                                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────┐     │
│  │     ALB     │    │  DynamoDB    │    │  S3 + Lambda   │     │
│  │  (Ingress)  │    │   (Carts)    │    │(Asset Processor)│    │
│  └─────────────┘    └──────────────┘    └────────────────┘     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                             │
                        Internet Users
Infrastructure Components
1. Compute Layer (EKS)
Cluster Name: project-bedrock-cluster
Kubernetes Version: 1.31
Node Group: project-bedrock-nodes
Instance Type: t3.medium
Scaling: Min: 1, Desired: 2, Max: 3
AMI: EKS-optimized Amazon Linux 2023

2. Database Layer
RDS MySQL:
  - Instance Class: db.t3.micro
  - Engine Version: 8.0
  - Multi-AZ: No (cost optimization)
  - Backup: 7 days retention
  
RDS PostgreSQL:
  - Instance Class: db.t3.micro
  - Engine Version: 14
  - Multi-AZ: No (cost optimization)
  - Backup: 7 days retention

DynamoDB:
  - Table: project-bedrock-carts
  - Billing: On-demand
  - Use Case: Shopping cart persistence

3. Networking & Load Balancing
AWS Load Balancer Controller:
  - Installed via Helm
  - Automatic ALB provisioning for Ingress resources
  - Target Type: IP mode (required for Fargate compatibility)

4. Observability
CloudWatch:
  - EKS Control Plane Logs (api, audit, authenticator, controller, scheduler)
  - Container Insights via CloudWatch Observability addon
  - Lambda function logs

5. Serverless Components
S3 Bucket: bedrock-assets-alt-soe-025-3333
Lambda Function: bedrock-asset-processor
Trigger: S3 object creation events

6. Access Management
IAM User: bedrock-dev-view (read-only access)
EKS Access Entry: Developer view access to retail-app namespace
Deployment Process
### Phase 1: Pre-Deployment Setup
1. **AWS CLI Configuration**
  ```bash
  aws configure
  # Configured credentials for account 229635049440
  ```
2. **Tool Verification**
  ```bash
  aws --version        # AWS CLI 2.x
  terraform -v         # Terraform v1.15.5
  kubectl version --client
  helm version
  ```
3. **Repository Setup**
  ```bash
  git clone https://github.com/ifeoluwafolami/project-bedrock.git
  cd project-bedrock
  ```


### Phase 2: Terraform Infrastructure Deployment
1. **Backend Configuration** (Remote State)
  ```bash
  # Created S3 bucket for Terraform state
  aws s3api create-bucket \
   --bucket project-bedrock-tfstate-229635049440 \
   --region us-east-1
 
  aws s3api put-bucket-versioning \
   --bucket project-bedrock-tfstate-229635049440 \
   --versioning-configuration Status=Enabled
  ```
2. **Terraform Initialization**
  ```bash
  cd terraform
  terraform init
  ```
3. **Infrastructure Planning**
  ```bash
  terraform plan
  # Reviewed plan: 50+ resources to be created
  ```
4. **Infrastructure Deployment**
  ```bash
  terraform apply -auto-approve
  # Initial attempt: FAILED - encountered critical bugs (see Issues section)
  # After fixes: SUCCESS - 11 resources created/replaced
  ```


### Phase 3: Kubernetes Configuration
1. **kubectl Configuration**
  ```bash
  aws eks update-kubeconfig \
   --name project-bedrock-cluster \
   --region us-east-1
  ```
2. **Node Verification**
  ```bash
  kubectl get nodes
  # Expected: 2 nodes in Ready state
  ```


### Phase 4: ALB Controller Installation
1. **Helm Repository Setup**
  ```bash
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  ```
2. **ALB Controller Deployment**
  ```bash
  ALB_ROLE_ARN=$(cd terraform && terraform output -raw alb_controller_role_arn)
 
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
   -n kube-system \
   --set clusterName=project-bedrock-cluster \
   --set serviceAccount.create=true \
   --set serviceAccount.name=aws-load-balancer-controller \
   --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN
  ```


### Phase 5: Application Deployment
1. **Namespace Creation**
  ```bash
  kubectl create namespace retail-app
  ```
2. **Application Deployment**
  ```bash
  kubectl apply -f https://github.com/aws-containers/retail-store-sample-app/releases/latest/download/kubernetes.yaml
  ```
3. **Ingress Configuration**
  ```bash
  kubectl apply -f kubernetes/ingress.yaml
  ```
4. **Verification**
  ```bash
  kubectl get pods -n retail-app
  kubectl get ingress -n retail-app
  kubectl get svc -n retail-app
  ```


Key Outputs & Results
Terraform Outputs

```hcl
Outputs:

alb_controller_role_arn = "arn:aws:iam::229635049440:role/project-bedrock-alb-controller"
cluster_endpoint = "https://AED8101FFFC26629ACD97E43D1E4BD6A.gr7.us-east-1.eks.amazonaws.com"
cluster_name = "project-bedrock-cluster"
cluster_security_group_id = "sg-0235e40bc5300d71b"
mysql_endpoint = "project-bedrock-mysql.xxxxx.us-east-1.rds.amazonaws.com:3306"
postgres_endpoint = "project-bedrock-postgres.xxxxx.us-east-1.rds.amazonaws.com:5432"
vpc_id = "vpc-072bf34dba25a549a"
```

Evidence & Screenshots
1. Terraform Output Success
![Terraform Apply Complete](./evidence/terraform-apply-complete.png)
*Shows "Apply complete! Resources: 11 added" message with full output*

### 2. EKS Cluster Status
![EKS Cluster Active](./evidence/eks-cluster-active.png)
*AWS Console showing cluster status: ACTIVE with version 1.31*

### 3. Node Group Status
![Node Group Active](./evidence/node-group-active.png)
*Node group showing status: ACTIVE with 2 nodes, health: no issues*

### 4. kubectl Get Nodes
![Kubernetes Nodes Ready](./evidence/kubectl-get-nodes.png)
*Terminal showing 2 nodes in Ready state with version and age*

### 5. Application Pods Running
![Retail App Pods](./evidence/retail-app-pods.png)
*All application pods in Running state across multiple deployments*

### 6. ALB Created
![ALB Ingress](./evidence/alb-ingress.png)
*kubectl get ingress showing ALB DNS name and routing configuration*

### 7. Application Accessible
![Application Browser](./evidence/app-browser-screenshot.png)
*Browser showing InnovateMart retail application fully functional*

### 8. RDS Instances
![RDS Databases](./evidence/rds-instances.png)
*AWS Console showing both MySQL and PostgreSQL instances in available status*

### 9. VPC Architecture
![VPC Diagram](./evidence/vpc-architecture.png)
*VPC with subnets, route tables, NAT gateways, and internet gateway*

### 10. Code Fixes
![Git Diff](./evidence/git-diff-fixes.png)
*Git diff showing the two critical bug fixes in main.tf*

---
