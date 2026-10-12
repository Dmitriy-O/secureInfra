locals {
  waf_managed_rule_groups = {
    ip_reputation = {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 10
    }

    common = {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 20
    }

    known_bad_inputs = {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 30
    }
  }
}

resource "aws_wafv2_web_acl" "frontend" {
  provider = aws.global

  name        = "${local.name_prefix}-frontend-waf"
  description = "Managed security rules and rate limiting for the frontend."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimit"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = 2000
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-frontend-rate"
      sampled_requests_enabled   = false
    }
  }

  dynamic "rule" {
    for_each = local.waf_managed_rule_groups

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-frontend-${rule.key}"
        sampled_requests_enabled   = false
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-frontend-waf"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl" "api" {
  name        = "${local.name_prefix}-api-waf"
  description = "Managed security rules and rate limiting for the API."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimit"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = 2000
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-api-rate"
      sampled_requests_enabled   = false
    }
  }

  dynamic "rule" {
    for_each = local.waf_managed_rule_groups

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = rule.key == "common" ? [1] : []

            content {
              name = "SizeRestrictions_BODY"

              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-api-${rule.key}"
        sampled_requests_enabled   = false
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-api-waf"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_lb.api.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
