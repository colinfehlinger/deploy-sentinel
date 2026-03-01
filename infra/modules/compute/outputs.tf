output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "ALB DNS name"
}

output "alb_arn" {
  value       = aws_lb.main.arn
  description = "ALB ARN"
}

output "alb_arn_suffix" {
  value       = aws_lb.main.arn_suffix
  description = "ALB ARN suffix (for CloudWatch metrics dimensions)"
}

output "api_target_group_arn_suffix" {
  value       = aws_lb_target_group.api.arn_suffix
  description = "API target group ARN suffix (for CloudWatch metrics dimensions)"
}

output "alb_zone_id" {
  value       = aws_lb.main.zone_id
  description = "ALB hosted zone ID (for Route53)"
}

output "cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "ECS cluster name"
}

output "api_service_name" {
  value       = aws_ecs_service.api.name
  description = "API ECS service name"
}

output "worker_service_name" {
  value       = aws_ecs_service.worker.name
  description = "Worker ECS service name"
}

output "ecr_api_url" {
  value       = aws_ecr_repository.api.repository_url
  description = "ECR repository URL for API"
}

output "ecr_worker_url" {
  value       = aws_ecr_repository.worker.repository_url
  description = "ECR repository URL for Worker"
}

output "api_target_group_arn" {
  value       = aws_lb_target_group.api.arn
  description = "API target group ARN"
}

output "api_log_group" {
  value       = aws_cloudwatch_log_group.api.name
  description = "API CloudWatch log group"
}

output "worker_log_group" {
  value       = aws_cloudwatch_log_group.worker.name
  description = "Worker CloudWatch log group"
}
