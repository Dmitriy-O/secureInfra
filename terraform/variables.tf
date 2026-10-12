variable "aws_region" {
  description = "AWS region for the infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for resource names."
  type        = string
  default     = "secure-saas"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Two availability zones within the selected region."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition = (
      length(var.availability_zones) == 2 &&
      length(distinct(var.availability_zones)) == 2
    )
    error_message = "Specify exactly two distinct availability zones."
  }
}
variable "backend_port" {
  description = "HTTPS port exposed by the backend container."
  type        = number
  default     = 8443
}

variable "database_port" {
  description = "PostgreSQL listening port."
  type        = number
  default     = 5432
}
variable "db_instance_class" {
  description = "RDS instance class for the proposed deployment."
  type        = string
  default     = "db.t4g.small"
}

variable "db_application_username" {
  description = "PostgreSQL application user authenticated through IAM."
  type        = string
  default     = "saas_app"
}
variable "api_certificate_arn" {
  description = "ARN of an issued ACM certificate in the ALB region."
  type        = string
}

variable "backend_image_digest" {
  description = "Digest of the backend image uploaded to the project ECR repository."
  type        = string

  validation {
    condition = can(
      regex("^sha256:[0-9a-f]{64}$", var.backend_image_digest)
    )
    error_message = "Specify an image digest in sha256:<64 lowercase hex characters> format."
  }
}

variable "backend_tls_secret_arn" {
  description = "ARN of a same-region Secrets Manager secret containing certificate and private_key JSON fields."
  type        = string
}

variable "backend_tls_secret_kms_key_arn" {
  description = "ARN of the customer-managed KMS key encrypting the backend TLS secret."
  type        = string
}
variable "frontend_domain_name" {
  description = "Custom domain name for the frontend."
  type        = string
}

variable "frontend_certificate_arn" {
  description = "ARN of an issued ACM certificate in us-east-1 covering the frontend domain."
  type        = string
}
variable "alarm_sns_topic_arns" {
  description = "Optional SNS topic ARNs for alarm and recovery notifications."
  type        = list(string)
  default     = []
}
