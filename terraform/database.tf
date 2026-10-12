resource "aws_db_subnet_group" "postgres" {
  name        = "${local.name_prefix}-database-subnets"
  description = "Isolated subnets for PostgreSQL."

  subnet_ids = [
    for subnet in aws_subnet.database : subnet.id
  ]

  tags = {
    Name = "${local.name_prefix}-database-subnets"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${local.name_prefix}-postgres-"
  family      = "postgres17"
  description = "PostgreSQL parameters with mandatory TLS."

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "immediate"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-postgres-parameters"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = "17"
  instance_class = var.db_instance_class

  db_name  = "saas"
  username = "saas_admin"
  port     = var.database_port

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"

  storage_encrypted = true
  kms_key_id        = aws_kms_key.data["database"].arn

  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.data["secrets"].arn

  iam_database_authentication_enabled = true

  db_subnet_group_name = aws_db_subnet_group.postgres.name
  parameter_group_name = aws_db_parameter_group.postgres.name

  vpc_security_group_ids = [
    aws_security_group.service["database"].id
  ]

  publicly_accessible = false
  multi_az            = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-postgres-final"
  copy_tags_to_snapshot     = true

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
