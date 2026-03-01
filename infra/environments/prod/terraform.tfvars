aws_region  = "us-east-1"
environment = "prod"

# Required for prod — pass via CI/CD:
# terraform apply -var="image_tag=abc123" -var="acm_certificate_arn=arn:aws:acm:..."
