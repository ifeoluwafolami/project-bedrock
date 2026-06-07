terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket = "project-bedrock-tfstate-229635049440"
    key    = "project-bedrock/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = "karatu-2025-capstone"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

module "networking" {
  source      = "./modules/networking"
  aws_region  = var.aws_region
  project_tag = var.project_tag
}

module "eks" {
  source             = "./modules/eks"
  aws_region         = var.aws_region
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  project_tag        = var.project_tag
}

module "data" {
  source             = "./modules/data"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
  project_tag        = var.project_tag
}

module "security" {
  source       = "./modules/security"
  cluster_name = module.eks.cluster_name
  assets_bucket_arn = module.serverless.assets_bucket_arn
  project_tag  = var.project_tag
}

module "serverless" {
  source      = "./modules/serverless"
  student_id  = var.student_id
  project_tag = var.project_tag
}
