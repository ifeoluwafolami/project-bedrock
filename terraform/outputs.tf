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

output "alb_controller_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller service account"
  value       = module.eks.alb_controller_role_arn
}

output "mysql_secret_arn" {
  description = "Secrets Manager secret containing catalog MySQL connection details"
  value       = module.data.mysql_secret_arn
}

output "postgres_secret_arn" {
  description = "Secrets Manager secret containing orders PostgreSQL connection details"
  value       = module.data.postgres_secret_arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table used by the carts service"
  value       = module.data.dynamodb_table
}

output "carts_dynamodb_role_arn" {
  description = "IRSA role ARN used by the carts service account for DynamoDB access"
  value       = module.security.carts_dynamodb_role_arn
}

output "dev_view_access_key_id" {
  description = "Access key ID for the bedrock-dev-view grading user"
  value       = module.security.dev_view_access_key_id
}

output "dev_view_secret_access_key" {
  description = "Secret access key for the bedrock-dev-view grading user"
  value       = module.security.dev_view_secret_access_key
  sensitive   = true
}

output "dev_view_console_password" {
  description = "Console password for the bedrock-dev-view grading user"
  value       = module.security.dev_view_console_password
  sensitive   = true
}

output "dev_view_console_url" {
  description = "AWS console sign-in URL for the grading user"
  value       = module.security.dev_view_console_url
}
