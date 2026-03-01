variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "deploy-sentinel"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "sns_alarm_email" {
  description = "Email for alarm notifications"
  type        = string
  default     = ""
}
