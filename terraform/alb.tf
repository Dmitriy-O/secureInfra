resource "aws_lb" "api" {
  name               = "${local.name_prefix}-api"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [
    aws_security_group.service["alb"].id
  ]

  subnets = [
    for subnet in aws_subnet.public : subnet.id
  ]

  enable_deletion_protection = true
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"

  tags = {
    Name = "${local.name_prefix}-api"
  }

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "api"
    enabled = true
  }

  depends_on = [
    aws_s3_bucket_policy.alb_logs,
    aws_s3_bucket_server_side_encryption_configuration.alb_logs
  ]
}

resource "aws_lb_target_group" "backend" {
  name_prefix = "api-"

  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  protocol    = "HTTPS"
  port        = var.backend_port

  deregistration_delay = 30

  health_check {
    enabled = true

    protocol = "HTTPS"
    port     = "traffic-port"
    path     = "/health"
    matcher  = "200"

    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-backend"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn

  port            = 443
  protocol        = "HTTPS"
  certificate_arn = var.api_certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
