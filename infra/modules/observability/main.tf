# --- SNS Topic for Alarms ---
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-${var.environment}-alarms"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.sns_alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.sns_alarm_email
}

# --- CloudWatch Dashboard ---
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count & Latency"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB HTTP 5xx / 4xx"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", color = "#d62728" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", color = "#ff7f0e" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS API - CPU & Memory"
          region = var.aws_region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.api_service_name, { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.api_service_name, { stat = "Average", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS Worker - CPU & Memory"
          region = var.aws_region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.worker_service_name, { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.worker_service_name, { stat = "Average", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "SQS Queue Depth"
          region = var.aws_region
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_queue_name, { stat = "Maximum", color = "#1f77b4" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_dlq_name, { stat = "Maximum", color = "#d62728" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Worker Custom Metrics"
          region = var.aws_region
          metrics = [
            ["DeploySentinel", "EventsProcessed", "Environment", var.environment, { stat = "Sum" }],
            ["DeploySentinel", "ProcessingDuration", "Environment", var.environment, { stat = "p99", yAxis = "right" }],
            ["DeploySentinel", "EventProcessingErrors", "Environment", var.environment, { stat = "Sum", color = "#d62728" }],
          ]
        }
      },
    ]
  })
}
