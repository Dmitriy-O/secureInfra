locals {
  interface_endpoint_services = toset([
    "ecr.api",
    "ecr.dkr",
    "secretsmanager",
    "logs"
  ])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type = "Interface"

  private_dns_enabled = true

  subnet_ids = [
    for subnet in aws_subnet.application : subnet.id
  ]

  security_group_ids = [
    aws_security_group.service["endpoints"].id
  ]

  tags = {
    Name = "${local.name_prefix}-${replace(each.value, ".", "-")}-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.application.id
  ]

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}
