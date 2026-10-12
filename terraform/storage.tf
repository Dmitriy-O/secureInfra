locals {
  storage_purposes = toset([
    "frontend",
    "files"
  ])
}

resource "aws_s3_bucket" "storage" {
  for_each = local.storage_purposes

  bucket = (
    "${local.name_prefix}-${each.key}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )

  force_destroy = false

  tags = {
    Name    = "${local.name_prefix}-${each.key}"
    Purpose = each.key
  }
}

resource "aws_s3_bucket_public_access_block" "storage" {
  for_each = local.storage_purposes

  bucket = aws_s3_bucket.storage[each.key].id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "storage" {
  for_each = local.storage_purposes

  bucket = aws_s3_bucket.storage[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "storage" {
  for_each = local.storage_purposes

  bucket = aws_s3_bucket.storage[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.storage["frontend"].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "files" {
  bucket = aws_s3_bucket.storage["files"].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data["files"].arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "storage" {
  for_each = local.storage_purposes

  bucket = aws_s3_bucket.storage[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = concat(
      [
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"

          Resource = [
            aws_s3_bucket.storage[each.key].arn,
            "${aws_s3_bucket.storage[each.key].arn}/*"
          ]

          Condition = {
            Bool = {
              "aws:SecureTransport"       = "false"
              "aws:PrincipalIsAWSService" = "false"
            }
          }
        }
      ],

      each.key == "frontend" ? [
        {
          Sid    = "AllowCloudFrontReadOnly"
          Effect = "Allow"

          Principal = {
            Service = "cloudfront.amazonaws.com"
          }

          Action = "s3:GetObject"

          Resource = (
            "${aws_s3_bucket.storage[each.key].arn}/*"
          )

          Condition = {
            StringEquals = {
              "AWS:SourceArn" = (
                aws_cloudfront_distribution.frontend.arn
              )
            }
          }
        }
      ] : []
    )
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  for_each = local.storage_purposes

  bucket = aws_s3_bucket.storage[each.key].id

  rule {
    id     = "AbortIncompleteMultipartUploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.storage
  ]
}
