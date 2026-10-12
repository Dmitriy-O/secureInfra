resource "aws_cloudwatch_log_group" "backend" {
  name              = local.backend_log_group_name
  retention_in_days = 30

  tags = {
    Name = "${local.name_prefix}-backend-logs"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

resource "aws_ecs_task_definition" "backend" {
  family = "${local.name_prefix}-backend"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs["execution"].arn
  task_role_arn      = aws_iam_role.ecs["task"].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name = "backend"

      image = (
        "${aws_ecr_repository.backend.repository_url}@${var.backend_image_digest}"
      )

      essential              = true
      user                   = "10001:10001"
      readonlyRootFilesystem = true

      linuxParameters = {
        capabilities = {
          drop = ["ALL"]
        }
      }

      portMappings = [
        {
          name          = "backend-https"
          containerPort = var.backend_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "PORT"
          value = tostring(var.backend_port)
        },
        {
          name  = "DB_HOST"
          value = aws_db_instance.postgres.address
        },
        {
          name  = "DB_PORT"
          value = tostring(var.database_port)
        },
        {
          name  = "DB_NAME"
          value = aws_db_instance.postgres.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_application_username
        },
        {
          name  = "DB_AUTH_MODE"
          value = "iam"
        },
        {
          name  = "DB_SSLMODE"
          value = "verify-full"
        },
        {
          name  = "FILES_BUCKET"
          value = aws_s3_bucket.storage["files"].id
        },
        {
          name  = "FILES_KMS_KEY_ARN"
          value = aws_kms_key.data["files"].arn
        }
      ]

      secrets = [
        {
          name = "TLS_CERT_PEM"

          valueFrom = (
            "${var.backend_tls_secret_arn}:certificate::"
          )
        },
        {
          name = "TLS_KEY_PEM"

          valueFrom = (
            "${var.backend_tls_secret_arn}:private_key::"
          )
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-backend-task"
  }
}

resource "aws_ecs_service" "backend" {
  name    = "${local.name_prefix}-backend"
  cluster = aws_ecs_cluster.main.id

  task_definition = aws_ecs_task_definition.backend.arn

  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  desired_count    = 2

  availability_zone_rebalancing = "ENABLED"

  enable_execute_command = false

  health_check_grace_period_seconds = 120

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = [
      for subnet in aws_subnet.application : subnet.id
    ]

    security_groups = [
      aws_security_group.service["backend"].id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.backend_port
  }

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy.execution,
    aws_iam_role_policy.execution_tls,
    aws_iam_role_policy.task,
    aws_vpc_endpoint.interface,
    aws_vpc_endpoint.s3,
    aws_vpc_security_group_ingress_rule.service,
    aws_vpc_security_group_egress_rule.service,
    aws_vpc_security_group_egress_rule.backend_to_s3,
    aws_s3_bucket_server_side_encryption_configuration.files
  ]

  tags = {
    Name = "${local.name_prefix}-backend-service"
  }
}
