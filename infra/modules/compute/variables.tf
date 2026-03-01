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

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ecs_security_group_id" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "api_task_role_arn" {
  type = string
}

variable "worker_task_role_arn" {
  type = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "api_cpu" {
  description = "CPU units for API task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "Memory in MiB for API task"
  type        = number
  default     = 512
}

variable "worker_cpu" {
  type    = number
  default = 256
}

variable "worker_memory" {
  type    = number
  default = 512
}

variable "api_desired_count" {
  type    = number
  default = 1
}

variable "api_max_count" {
  type    = number
  default = 4
}

variable "worker_desired_count" {
  type    = number
  default = 1
}

variable "worker_max_count" {
  type    = number
  default = 4
}

# Data module outputs passed through
variable "dynamodb_table_name" {
  type = string
}

variable "sqs_queue_url" {
  type = string
}

variable "webhook_secret_arn" {
  type = string
}

variable "waf_acl_arn" {
  description = "WAF Web ACL ARN to associate with ALB"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Required for TLS termination."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
