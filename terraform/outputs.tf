output "storage_bucket_names" {
  description = "Names of the private storage buckets."

  value = {
    for purpose, bucket in aws_s3_bucket.storage :
    purpose => bucket.id
  }
}

output "encryption_key_arns" {
  description = "ARNs of the data encryption keys."

  value = {
    for purpose, key in aws_kms_key.data :
    purpose => key.arn
  }
}
output "database_address" {
  description = "Private PostgreSQL hostname."
  value       = aws_db_instance.postgres.address
}

output "database_port" {
  description = "PostgreSQL listening port."
  value       = aws_db_instance.postgres.port
}

output "database_master_secret_arn" {
  description = "ARN of the RDS-managed administrative secret."
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "backend_repository_url" {
  description = "Private ECR repository URL."
  value       = aws_ecr_repository.backend.repository_url
}

output "ecs_role_arns" {
  description = "Separate ECS execution and application role ARNs."

  value = {
    for purpose, role in aws_iam_role.ecs :
    purpose => role.arn
  }
}
output "api_load_balancer_dns_name" {
  description = "DNS name of the public API load balancer."
  value       = aws_lb.api.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "ecs_backend_service_name" {
  description = "Backend ECS service name."
  value       = aws_ecs_service.backend.name
}
output "frontend_distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.frontend.id
}

output "frontend_url" {
  description = "HTTPS URL of the custom frontend domain."
  value       = "https://${var.frontend_domain_name}"
}

output "waf_web_acl_arns" {
  description = "Web ACL ARNs for the frontend and API."

  value = {
    frontend = aws_wafv2_web_acl.frontend.arn
    api      = aws_wafv2_web_acl.api.arn
  }
}
output "audit_trail_arn" {
  description = "ARN of the multi-region CloudTrail audit trail."
  value       = aws_cloudtrail.audit.arn
}

output "audit_bucket_name" {
  description = "Private S3 bucket storing CloudTrail audit logs."
  value       = aws_s3_bucket.audit.id
}

output "audit_encryption_key_arn" {
  description = "KMS key used to encrypt CloudTrail audit logs."
  value       = aws_kms_key.audit.arn
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Log Group containing VPC Flow Logs."
  value       = aws_cloudwatch_log_group.vpc_flow.name
}
output "alb_access_logs_bucket_name" {
  description = "Private S3 bucket containing ALB access logs."
  value       = aws_s3_bucket.alb_logs.id
}

output "waf_log_group_names" {
  description = "CloudWatch Log Groups containing WAF request logs."

  value = {
    frontend = aws_cloudwatch_log_group.waf_frontend.name
    api      = aws_cloudwatch_log_group.waf_api.name
  }
}
output "monitoring_alarm_names" {
  description = "CloudWatch alarms for backend availability and server errors."

  value = {
    backend_unavailable = (
      aws_cloudwatch_metric_alarm.backend_unavailable.alarm_name
    )

    backend_server_errors = (
      aws_cloudwatch_metric_alarm.backend_server_errors.alarm_name
    )
  }
}
