data "aws_caller_identity" "current" {}

# ── IAM User: bedrock-dev-view ────────────────────────────────────────────────
resource "aws_iam_user" "dev_view" {
  name = "bedrock-dev-view"
  tags = { Project = var.project_tag }
}

# Console login profile (allows AWS Console access)
resource "aws_iam_user_login_profile" "dev_view" {
  user                    = aws_iam_user.dev_view.name
  password_reset_required = false
}

# Access keys (for CLI / grader use)
resource "aws_iam_access_key" "dev_view" {
  user = aws_iam_user.dev_view.name
}

# ReadOnlyAccess to AWS Console
resource "aws_iam_user_policy_attachment" "read_only" {
  user       = aws_iam_user.dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# S3 PutObject on the assets bucket only
resource "aws_iam_user_policy" "s3_put" {
  name = "bedrock-dev-view-s3-put"
  user = aws_iam_user.dev_view.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${var.assets_bucket_arn}/*"
    }]
  })
}

# ── EKS Access Entry: map IAM user → Kubernetes view ClusterRole ──────────────
resource "aws_eks_access_entry" "dev_view" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_user.dev_view.arn
  type          = "STANDARD"
  tags          = { Project = var.project_tag }
}

resource "aws_eks_access_policy_association" "dev_view" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_user.dev_view.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["retail-app"]
  }
}

# ── IRSA role: carts service → DynamoDB table ────────────────────────────────
data "aws_iam_policy_document" "carts_dynamodb_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:retail-app:carts"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "carts_dynamodb" {
  name               = "project-bedrock-carts-dynamodb"
  assume_role_policy = data.aws_iam_policy_document.carts_dynamodb_assume.json
  tags               = { Project = var.project_tag }
}

resource "aws_iam_role_policy" "carts_dynamodb" {
  name = "project-bedrock-carts-dynamodb"
  role = aws_iam_role.carts_dynamodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:ConditionCheckItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateItem"
      ]
      Resource = [
        var.dynamodb_table_arn,
        "${var.dynamodb_table_arn}/index/*"
      ]
    }]
  })
}
