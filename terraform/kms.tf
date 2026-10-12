locals {
  encryption_key_purposes = toset([
    "files",
    "database",
    "secrets"
  ])
}

resource "aws_kms_key" "data" {
  for_each = local.encryption_key_purposes

  description = (
    "Encryption key for ${local.name_prefix} ${each.value}."
  )

  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  deletion_window_in_days  = 30

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableAccountIAMPermissions"
        Effect = "Allow"

        Principal = {
          AWS = (
            "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
          )
        }

        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${local.name_prefix}-${each.value}-key"
    Purpose = each.value
  }
}

resource "aws_kms_alias" "data" {
  for_each = local.encryption_key_purposes

  name          = "alias/${local.name_prefix}-${each.value}"
  target_key_id = aws_kms_key.data[each.key].key_id
}
