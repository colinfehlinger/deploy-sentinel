terraform {
  backend "s3" {
    bucket         = "deploy-sentinel-tf-state-ACCOUNT_ID"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "deploy-sentinel-tf-lock"
    encrypt        = true
  }
}
