resource "aws_cloudwatch_metric_alarm" "backend_unavailable" {
  alarm_name = "${local.name_prefix}-backend-unavailable"

  alarm_description = (
    "No healthy backend targets reported during two consecutive one-minute periods."
  )

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"
  statistic   = "Maximum"

  comparison_operator = "LessThanThreshold"
  threshold           = 1

  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  treat_missing_data = "missing"

  dimensions = {
    LoadBalancer = aws_lb.api.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns
}

resource "aws_cloudwatch_metric_alarm" "backend_server_errors" {
  alarm_name = "${local.name_prefix}-backend-server-errors"

  alarm_description = (
    "Backend returns at least five HTTP 5xx responses per minute during two consecutive periods."
  )

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"
  statistic   = "Sum"

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5

  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.api.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns
}
