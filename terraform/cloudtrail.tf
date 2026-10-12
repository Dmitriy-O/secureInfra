locals {
  audit_trail_name = "${local.name_prefix}-audit"

  audit_trail_arn = format(
    "arn:%s:cloudtrail:%s:%s:trail/%s",
    data.aws_partition.current.partition,
    var.aws_region,
    data.aws_caller_identity.current.account_id,
    local.audit_trail_name
  )

  audit_trail_encryption_context = format(
    "arn:%s:cloudtrail:*:%s:trail/%s",
    data.aws_partition.current.partition,
    data.aws_caller_identity.current.account_id,
    local.audit_trail_name
  )
}

resource "aws_kms_key" "audit" {
  description              = "Encryption key for CloudTrail audit logs."
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
          AWS = format(
            "arn:%s:iam::%s:root",
            data.aws_partition.current.partition,
            data.aws_caller_identity.current.account_id
          )
        }

        Action   = "kms:*"
        Resource = "*"
      },

      {
        Sid    = "AllowCloudTrailEncryption"
        Effect = "Allow"

        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }

        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.audit_trail_arn
          }

          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = (
              local.audit_trail_encryption_context
            )
          }
        }
      },

      {
        Sid    = "AllowCloudTrailDescribeKey"
        Effect = "Allow"

        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }

        Action   = "kms:DescribeKey"
        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.audit_trail_arn
          }
        }
      }
    ]
  })

  tags = {
    Name    = "${local.name_prefix}-audit-key"
    Purpose = "audit"
  }
}

resource "aws_kms_alias" "audit" {
  name          = "alias/${local.name_prefix}-audit"
  target_key_id = aws_kms_key.audit.key_id
}

resource "aws_s3_bucket" "audit" {
  bucket = format(
    "%s-audit-%s-%s",
    local.name_prefix,
    data.aws_caller_identity.current.account_id,
    var.aws_region
  )

  force_destroy = false

  tags = {
    Name    = "${local.name_prefix}-audit"
    Purpose = "audit"
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket = aws_s3_bucket.audit.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit.arn
    }
  }
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"

        Resource = [
          aws_s3_bucket.audit.arn,
          "${aws_s3_bucket.audit.arn}/*"
        ]

        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false"
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      },

      {
        Sid    = "AllowCloudTrailBucketCheck"
        Effect = "Allow"

        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }

        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit.arn

        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.audit_trail_arn
          }
        }
      },

      {
        Sid    = "AllowCloudTrailLogDelivery"
        Effect = "Allow"

        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }

        Action = "s3:PutObject"

        Resource = format(
          "%s/AWSLogs/%s/*",
          aws_s3_bucket.audit.arn,
          data.aws_caller_identity.current.account_id
        )

        Condition = {
          StringEquals = {
            "aws:SourceArn" = local.audit_trail_arn
            "s3:x-amz-acl"  = "bucket-owner-full-control"
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.audit,
    aws_s3_bucket_ownership_controls.audit
  ]
}

resource "aws_cloudtrail" "audit" {
  name           = local.audit_trail_name
  s3_bucket_name = aws_s3_bucket.audit.id
  kms_key_id     = aws_kms_key.audit.arn

  enable_logging                = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"

      values = [
        "${aws_s3_bucket.storage["files"].arn}/"
      ]
    }
  }

  depends_on = [
    aws_s3_bucket_policy.audit,
    aws_s3_bucket_versioning.audit,
    aws_s3_bucket_server_side_encryption_configuration.audit
  ]
}
