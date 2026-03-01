variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics"
  type        = string
}

variable "api_target_group_arn_suffix" {
  description = "API target group ARN suffix for CloudWatch metrics"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "api_service_name" {
  type = string
}

variable "worker_service_name" {
  type = string
}

variable "sqs_queue_name" {
  type = string
}

variable "sqs_dlq_name" {
  description = "DLQ name for alarms"
  type        = string
}

variable "sns_alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
