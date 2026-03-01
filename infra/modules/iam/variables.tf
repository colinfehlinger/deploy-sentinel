variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB deployments table"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the main SQS queue"
  type        = string
}

variable "sqs_dlq_arn" {
  description = "ARN of the dead letter queue"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
