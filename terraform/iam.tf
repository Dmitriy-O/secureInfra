locals {
  backend_log_group_name = "/ecs/${local.name_prefix}/backend"

  backend_log_stream_arn = (
    "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.backend_log_group_name}:log-stream:*"
  )

  application_db_user_arn = (
    "arn:${data.aws_partition.current.partition}:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.postgres.resource_id}/${var.db_application_username}"
  )
}

resource "aws_iam_role" "ecs" {
  for_each = toset([
    "execution",
    "task"
  ])

  name = "${local.name_prefix}-ecs-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = (
              data.aws_caller_identity.current.account_id
            )
          }

          ArnLike = {
            "aws:SourceArn" = (
              "arn:${data.aws_partition.current.partition}:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
            )
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-${each.key}"
  }
}

resource "aws_iam_role_policy" "execution" {
  name = "${local.name_prefix}-execution-permissions"
  role = aws_iam_role.ecs["execution"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "GetECRAuthorizationToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PullBackendImage"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]

        Resource = aws_ecr_repository.backend.arn
      },
      {
        Sid    = "WriteBackendLogs"
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = local.backend_log_stream_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "task" {
  name = "${local.name_prefix}-application-permissions"
  role = aws_iam_role.ecs["task"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ListClientFiles"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.storage["files"].arn
      },
      {
        Sid    = "ManageClientFiles"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = "${aws_s3_bucket.storage["files"].arn}/*"
      },
      {
        Sid    = "UseClientFilesEncryptionKey"
        Effect = "Allow"

        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]

        Resource = aws_kms_key.data["files"].arn

        Condition = {
          StringEquals = {
            "kms:ViaService" = (
              "s3.${var.aws_region}.${data.aws_partition.current.dns_suffix}"
            )
          }

          StringLike = {
            "kms:EncryptionContext:aws:s3:arn" = [
              aws_s3_bucket.storage["files"].arn,
              "${aws_s3_bucket.storage["files"].arn}/*"
            ]
          }
        }
      },
      {
        Sid      = "ConnectAsApplicationDatabaseUser"
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = local.application_db_user_arn
      }
    ]
  })
}
resource "aws_iam_role_policy" "execution_tls" {
  name = "${local.name_prefix}-execution-tls"
  role = aws_iam_role.ecs["execution"].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ReadBackendTLSSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.backend_tls_secret_arn
      },
      {
        Sid      = "DecryptBackendTLSSecret"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = var.backend_tls_secret_kms_key_arn

        Condition = {
          StringEquals = {
            "kms:ViaService" = (
              "secretsmanager.${var.aws_region}.${data.aws_partition.current.dns_suffix}"
            )
          }
        }
      }
    ]
  })
}
