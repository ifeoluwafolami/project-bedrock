# These output names are required by the grading script exactly as written.
# Do not rename them.

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "assets_bucket_name" {
  description = "S3 assets bucket name"
  value       = module.serverless.assets_bucket_name
}
