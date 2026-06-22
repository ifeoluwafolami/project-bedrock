data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "project-bedrock-vpc"
    Project = var.project_tag
  }
}

# Public subnets (one per AZ)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name                                            = "project-bedrock-public-${local.azs[count.index]}"
    Project                                         = var.project_tag
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
  }
}

# Private subnets (one per AZ)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = local.azs[count.index]

  tags = {
    Name                                            = "project-bedrock-private-${local.azs[count.index]}"
    Project                                         = var.project_tag
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "project-bedrock-igw"
    Project = var.project_tag
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name    = "project-bedrock-nat-eip-${count.index}"
    Project = var.project_tag
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways (one per public subnet for HA)
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name    = "project-bedrock-nat-${count.index}"
    Project = var.project_tag
  }

  depends_on = [aws_internet_gateway.main]
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "project-bedrock-public-rt"
    Project = var.project_tag
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables (one per AZ, each routes through its own NAT)
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name    = "project-bedrock-private-rt-${count.index}"
    Project = var.project_tag
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
