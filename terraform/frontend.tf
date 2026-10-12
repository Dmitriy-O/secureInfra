resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-frontend-oac"
  description                       = "Signed access from CloudFront to the private frontend bucket."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "frontend" {
  name        = "${local.name_prefix}-frontend-cache"
  comment     = "Cache static frontend content without cookies or query strings."
  min_ttl     = 0
  default_ttl = 300
  max_ttl     = 86400

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "frontend" {
  name    = "${local.name_prefix}-frontend-security-headers"
  comment = "Browser security headers for the frontend."

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }
  }
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Secure static frontend distribution."
  default_root_object = "index.html"
  http_version        = "http2"
  price_class         = "PriceClass_100"

  aliases    = [var.frontend_domain_name]
  web_acl_id = aws_wafv2_web_acl.frontend.arn

  origin {
    domain_name = (
      aws_s3_bucket.storage["frontend"].bucket_regional_domain_name
    )

    origin_id = "${local.name_prefix}-frontend-s3"

    origin_access_control_id = (
      aws_cloudfront_origin_access_control.frontend.id
    )
  }

  default_cache_behavior {
    target_origin_id       = "${local.name_prefix}-frontend-s3"
    viewer_protocol_policy = "https-only"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    cache_policy_id = aws_cloudfront_cache_policy.frontend.id

    response_headers_policy_id = (
      aws_cloudfront_response_headers_policy.frontend.id
    )
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.frontend_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [
    aws_s3_bucket_public_access_block.storage,
    aws_s3_bucket_ownership_controls.storage
  ]
}
