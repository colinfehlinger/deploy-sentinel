# --- Alarm 1: API 5xx Rate ---
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx"
  alarm_description   = "API is returning HTTP 5xx errors — likely app bug or downstream failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

# --- Alarm 2: API Latency P99 ---
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-api-latency-p99"
  alarm_description   = "API P99 latency exceeds 2s — performance degradation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 2
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

# --- Alarm 3: SQS Queue Depth ---
resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  alarm_name          = "${var.project_name}-${var.environment}-queue-depth"
  alarm_description   = "SQS queue depth > 500 — worker cannot keep up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 500
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.sqs_queue_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

# --- Alarm 4: DLQ Non-Empty ---
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-${var.environment}-dlq-nonempty"
  alarm_description   = "Dead letter queue has messages — always investigate poison messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.sqs_dlq_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

# --- Alarm 5: API Running Task Count ---
resource "aws_cloudwatch_metric_alarm" "api_task_count" {
  alarm_name          = "${var.project_name}-${var.environment}-api-tasks-low"
  alarm_description   = "API service has no running tasks — service is down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.api_service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

# --- Alarm 6: Worker Running Task Count ---
resource "aws_cloudwatch_metric_alarm" "worker_task_count" {
  alarm_name          = "${var.project_name}-${var.environment}-worker-tasks-low"
  alarm_description   = "Worker service has no running tasks — event processing stopped"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.worker_service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = var.tags
}

# --- Alarm 7: ALB Unhealthy Hosts ---
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-hosts"
  alarm_description   = "ALB has unhealthy targets — containers failing health checks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.api_target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = var.tags
}
