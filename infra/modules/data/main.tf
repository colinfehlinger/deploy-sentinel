# --- DynamoDB Table ---
resource "aws_dynamodb_table" "deployments" {
  name         = "${var.project_name}-deployments-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "deploymentId"
    type = "S"
  }

  global_secondary_index {
    name            = "gsi1-deployment-id"
    hash_key        = "deploymentId"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-deployments-${var.environment}"
  })
}

# --- SQS Dead Letter Queue ---
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-deploy-events-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 20

  tags = merge(var.tags, {
    Name = "${var.project_name}-deploy-events-dlq-${var.environment}"
  })
}

# --- SQS Main Queue ---
resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-deploy-events-${var.environment}"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 604800 # 7 days
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-deploy-events-${var.environment}"
  })
}

# --- Secrets Manager ---
resource "aws_secretsmanager_secret" "webhook_secret" {
  name        = "${var.project_name}-${var.environment}-webhook-secret"
  description = "GitHub webhook HMAC signing secret"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-webhook-secret"
  })
}

resource "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id     = aws_secretsmanager_secret.webhook_secret.id
  secret_string = "CHANGE_ME_AFTER_DEPLOY_min16chars"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
