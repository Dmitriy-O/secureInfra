resource "aws_s3_bucket" "alb_logs" {
  bucket = format(
    "%s-alb-logs-%s-%s",
    local.name_prefix,
    data.aws_caller_identity.current.account_id,
    var.aws_region
  )

  force_destroy = false

  tags = {
    Name    = "${local.name_prefix}-alb-logs"
    Purpose = "http-access-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"

        Resource = [
          aws_s3_bucket.alb_logs.arn,
          "${aws_s3_bucket.alb_logs.arn}/*"
        ]

        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false"
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      },

      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"

        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }

        Action = "s3:PutObject"

        Resource = format(
          "%s/api/AWSLogs/%s/*",
          aws_s3_bucket.alb_logs.arn,
          data.aws_caller_identity.current.account_id
        )

        Condition = {
          ArnLike = {
            "aws:SourceArn" = format(
              "arn:%s:elasticloadbalancing:%s:%s:loadbalancer/app/*",
              data.aws_partition.current.partition,
              var.aws_region,
              data.aws_caller_identity.current.account_id
            )
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.alb_logs,
    aws_s3_bucket_ownership_controls.alb_logs
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "AccessLogRetention"
    status = "Enabled"

    filter {
      prefix = "api/"
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.alb_logs
  ]
}
