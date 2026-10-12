locals {
  security_group_descriptions = {
    alb       = "Public HTTPS entry point."
    backend   = "Backend access restricted to the ALB."
    database  = "PostgreSQL access restricted to the backend."
    endpoints = "Private AWS service access for backend tasks."
  }

  service_ingress_rules = {
    alb_to_backend = {
      destination = "backend"
      source      = "alb"
      port        = var.backend_port
      description = "Allow HTTPS from the ALB."
    }

    backend_to_database = {
      destination = "database"
      source      = "backend"
      port        = var.database_port
      description = "Allow PostgreSQL from backend tasks."
    }

    backend_to_endpoints = {
      destination = "endpoints"
      source      = "backend"
      port        = 443
      description = "Allow HTTPS from backend tasks."
    }
  }

  service_egress_rules = {
    alb_to_backend = {
      source      = "alb"
      destination = "backend"
      port        = var.backend_port
      description = "Allow HTTPS to backend tasks."
    }

    backend_to_database = {
      source      = "backend"
      destination = "database"
      port        = var.database_port
      description = "Allow PostgreSQL to the database."
    }

    backend_to_endpoints = {
      source      = "backend"
      destination = "endpoints"
      port        = 443
      description = "Allow HTTPS to private AWS endpoints."
    }
  }
}

resource "aws_security_group" "service" {
  for_each = local.security_group_descriptions

  name        = "${local.name_prefix}-${each.key}-sg"
  description = each.value
  vpc_id      = aws_vpc.main.id

  # Rules are managed by separate resources below.
  # No unrestricted outbound rule is configured.

  tags = {
    Name = "${local.name_prefix}-${each.key}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_https" {
  security_group_id = aws_security_group.service["alb"].id

  description = "Allow public HTTPS access to the ALB."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "service" {
  for_each = local.service_ingress_rules

  security_group_id = (
    aws_security_group.service[each.value.destination].id
  )

  referenced_security_group_id = (
    aws_security_group.service[each.value.source].id
  )

  description = each.value.description
  ip_protocol = "tcp"
  from_port   = each.value.port
  to_port     = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "service" {
  for_each = local.service_egress_rules

  security_group_id = (
    aws_security_group.service[each.value.source].id
  )

  referenced_security_group_id = (
    aws_security_group.service[each.value.destination].id
  )

  description = each.value.description
  ip_protocol = "tcp"
  from_port   = each.value.port
  to_port     = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "backend_to_s3" {
  security_group_id = aws_security_group.service["backend"].id

  description    = "Allow HTTPS to regional S3 through the gateway endpoint."
  ip_protocol    = "tcp"
  from_port      = 443
  to_port        = 443
  prefix_list_id = aws_vpc_endpoint.s3.prefix_list_id
}
