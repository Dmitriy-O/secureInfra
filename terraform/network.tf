locals {
  name_prefix = "${var.project_name}-${var.environment}"

  zones = {
    a = {
      availability_zone = var.availability_zones[0]
      public_cidr       = cidrsubnet(var.vpc_cidr, 8, 10)
      application_cidr  = cidrsubnet(var.vpc_cidr, 8, 20)
      database_cidr     = cidrsubnet(var.vpc_cidr, 8, 30)
    }

    b = {
      availability_zone = var.availability_zones[1]
      public_cidr       = cidrsubnet(var.vpc_cidr, 8, 11)
      application_cidr  = cidrsubnet(var.vpc_cidr, 8, 21)
      database_cidr     = cidrsubnet(var.vpc_cidr, 8, 31)
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_default_security_group" "restricted" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules.
  # Workloads will use explicitly configured security groups.

  tags = {
    Name = "${local.name_prefix}-default-restricted"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.zones

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "application" {
  for_each = local.zones

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.application_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-application-${each.key}"
    Tier = "application"
  }
}

resource "aws_subnet" "database" {
  for_each = local.zones

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.database_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-database-${each.key}"
    Tier = "database"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table" "application" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-application-rt"
  }
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-database-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.zones

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "application" {
  for_each = local.zones

  subnet_id      = aws_subnet.application[each.key].id
  route_table_id = aws_route_table.application.id
}

resource "aws_route_table_association" "database" {
  for_each = local.zones

  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database.id
}
