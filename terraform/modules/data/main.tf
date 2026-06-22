resource "random_password" "mysql" {
  length  = 16
  special = false
}

resource "random_password" "postgres" {
  length  = 16
  special = false
}

# ── Subnet Group (shared by both RDS instances) ───────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "project-bedrock-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "project-bedrock-db-subnet-group", Project = var.project_tag }
}

# ── Security Group: allow DB traffic from EKS nodes only ─────────────────────
resource "aws_security_group" "rds" {
  name        = "project-bedrock-rds-sg"
  description = "Allow DB access from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
    description     = "MySQL from EKS nodes"
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
    description     = "Postgres from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "project-bedrock-rds-sg", Project = var.project_tag }
}

resource "aws_security_group_rule" "rds_mysql_from_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.rds.id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "MySQL from EKS pod/node CIDR"
}

resource "aws_security_group_rule" "rds_postgres_from_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.rds.id
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Postgres from EKS pod/node CIDR"
}

# ── RDS MySQL (catalog service) ───────────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier        = "project-bedrock-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "catalog"
  username = "dbadmin"
  password = random_password.mysql.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  multi_az            = false
  publicly_accessible = false

  tags = { Name = "project-bedrock-mysql", Project = var.project_tag }
}

# ── RDS PostgreSQL (orders service) ──────────────────────────────────────────
resource "aws_db_instance" "postgres" {
  identifier        = "project-bedrock-postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "orders"
  username = "dbadmin"
  password = random_password.postgres.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  multi_az            = false
  publicly_accessible = false

  tags = { Name = "project-bedrock-postgres", Project = var.project_tag }
}

# ── DynamoDB (cart service) ───────────────────────────────────────────────────
resource "aws_dynamodb_table" "carts" {
  name         = "project-bedrock-carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "customerId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx_global_customerId"
    hash_key        = "customerId"
    projection_type = "ALL"
  }

  tags = { Name = "project-bedrock-carts", Project = var.project_tag }
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "mysql" {
  name                    = "project-bedrock/mysql"
  recovery_window_in_days = 0
  tags                    = { Project = var.project_tag }
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.mysql.result
    host     = aws_db_instance.mysql.address
    port     = 3306
    dbname   = "catalog"
  })
}

resource "aws_secretsmanager_secret" "postgres" {
  name                    = "project-bedrock/postgres"
  recovery_window_in_days = 0
  tags                    = { Project = var.project_tag }
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.postgres.result
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = "orders"
  })
}
