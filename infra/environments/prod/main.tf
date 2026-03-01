terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# --- Networking ---
module "networking" {
  source = "../../modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  nat_gateway_count    = 2 # Dual NAT for HA in prod
  enable_vpc_endpoints = true
  tags                 = local.tags
}

# --- Data ---
module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.tags
}

# --- IAM ---
module "iam" {
  source = "../../modules/iam"

  project_name       = var.project_name
  environment        = var.environment
  dynamodb_table_arn = module.data.dynamodb_table_arn
  sqs_queue_arn      = module.data.sqs_queue_arn
  sqs_dlq_arn        = module.data.sqs_dlq_arn
  tags               = local.tags
}

# --- Security ---
module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  enable_waf   = true # Enabled in prod
  tags         = local.tags
}

# --- Compute ---
module "compute" {
  source = "../../modules/compute"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  ecs_security_group_id = module.networking.ecs_security_group_id
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  api_task_role_arn     = module.iam.api_task_role_arn
  worker_task_role_arn  = module.iam.worker_task_role_arn
  image_tag             = var.image_tag
  api_cpu               = 512
  api_memory            = 1024
  api_desired_count     = 2
  api_max_count         = 4
  worker_cpu            = 512
  worker_memory         = 1024
  worker_desired_count  = 2
  worker_max_count      = 4
  dynamodb_table_name   = module.data.dynamodb_table_name
  sqs_queue_url         = module.data.sqs_queue_url
  webhook_secret_arn    = module.data.webhook_secret_arn
  waf_acl_arn           = module.security.waf_acl_arn
  acm_certificate_arn   = var.acm_certificate_arn
  tags                  = local.tags
}

# --- Observability ---
module "observability" {
  source = "../../modules/observability"

  project_name                = var.project_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  alb_arn_suffix              = module.compute.alb_arn_suffix
  api_target_group_arn_suffix = module.compute.api_target_group_arn_suffix
  cluster_name                = module.compute.cluster_name
  api_service_name            = module.compute.api_service_name
  worker_service_name         = module.compute.worker_service_name
  sqs_queue_name              = module.data.sqs_queue_name
  sqs_dlq_name                = "${var.project_name}-deploy-events-dlq-${var.environment}"
  sns_alarm_email             = var.sns_alarm_email
  tags                        = local.tags
}

# --- Outputs ---
output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "ecr_api_url" {
  value = module.compute.ecr_api_url
}

output "ecr_worker_url" {
  value = module.compute.ecr_worker_url
}

output "cluster_name" {
  value = module.compute.cluster_name
}

output "dynamodb_table" {
  value = module.data.dynamodb_table_name
}

output "sqs_queue_url" {
  value = module.data.sqs_queue_url
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.observability.dashboard_name}"
}
