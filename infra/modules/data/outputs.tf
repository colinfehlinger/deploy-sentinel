output "dynamodb_table_name" {
  value       = aws_dynamodb_table.deployments.name
  description = "DynamoDB table name"
}

output "dynamodb_table_arn" {
  value       = aws_dynamodb_table.deployments.arn
  description = "DynamoDB table ARN"
}

output "sqs_queue_url" {
  value       = aws_sqs_queue.main.url
  description = "SQS main queue URL"
}

output "sqs_queue_arn" {
  value       = aws_sqs_queue.main.arn
  description = "SQS main queue ARN"
}

output "sqs_queue_name" {
  value       = aws_sqs_queue.main.name
  description = "SQS main queue name"
}

output "sqs_dlq_url" {
  value       = aws_sqs_queue.dlq.url
  description = "SQS dead letter queue URL"
}

output "sqs_dlq_arn" {
  value       = aws_sqs_queue.dlq.arn
  description = "SQS dead letter queue ARN"
}

output "webhook_secret_arn" {
  value       = aws_secretsmanager_secret.webhook_secret.arn
  description = "Webhook secret ARN in Secrets Manager"
}
