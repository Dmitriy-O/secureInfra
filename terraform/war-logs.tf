locals {
  waf_redacted_headers = toset([
    "authorization",
    "cookie",
    "x-api-key"
  ])
}

resource "aws_cloudwatch_log_group" "waf_frontend" {
  provider = aws.global

  name              = "aws-waf-logs-${local.name_prefix}-frontend"
  retention_in_days = 90

  tags = {
    Name    = "${local.name_prefix}-frontend-waf-logs"
    Purpose = "web-security-logs"
  }
}

resource "aws_cloudwatch_log_group" "waf_api" {
  name              = "aws-waf-logs-${local.name_prefix}-api"
  retention_in_days = 90

  tags = {
    Name    = "${local.name_prefix}-api-waf-logs"
    Purpose = "web-security-logs"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "frontend" {
  provider = aws.global

  resource_arn = aws_wafv2_web_acl.frontend.arn

  log_destination_configs = [
    aws_cloudwatch_log_group.waf_frontend.arn
  ]

  dynamic "redacted_fields" {
    for_each = local.waf_redacted_headers

    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  redacted_fields {
    query_string {}
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "api" {
  resource_arn = aws_wafv2_web_acl.api.arn

  log_destination_configs = [
    aws_cloudwatch_log_group.waf_api.arn
  ]

  dynamic "redacted_fields" {
    for_each = local.waf_redacted_headers

    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  redacted_fields {
    query_string {}
  }
}
