resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = 90

  tags = {
    Name    = "${local.name_prefix}-vpc-flow-logs"
    Purpose = "network-audit"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowVPCFlowLogsService"
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = (
              data.aws_caller_identity.current.account_id
            )
          }

          ArnLike = {
            "aws:SourceArn" = format(
              "arn:%s:ec2:%s:%s:vpc-flow-log/*",
              data.aws_partition.current.partition,
              var.aws_region,
              data.aws_caller_identity.current.account_id
            )
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-log-delivery"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "WriteToVPCFlowLogGroup"
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]

        Resource = (
          "${aws_cloudwatch_log_group.vpc_flow.arn}:*"
        )
      },

      {
        Sid      = "DiscoverLogGroups"
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"

  log_destination = aws_cloudwatch_log_group.vpc_flow.arn
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn

  max_aggregation_interval = 60

  log_format = join(" ", [
    "$${version}",
    "$${account-id}",
    "$${interface-id}",
    "$${srcaddr}",
    "$${dstaddr}",
    "$${srcport}",
    "$${dstport}",
    "$${protocol}",
    "$${packets}",
    "$${bytes}",
    "$${start}",
    "$${end}",
    "$${action}",
    "$${log-status}"
  ])

  tags = {
    Name = "${local.name_prefix}-vpc-flow-log"
  }

  depends_on = [
    aws_iam_role_policy.vpc_flow_logs
  ]
}
