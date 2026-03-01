.PHONY: dev-up dev-down dev-logs lint test build tf-init tf-plan tf-apply tf-destroy tf-fmt deploy teardown bootstrap

# --- Local Development ---
dev-up:
	docker compose up -d --build

dev-down:
	docker compose down -v

dev-logs:
	docker compose logs -f

# --- Application ---
lint:
	cd services/shared && npm run lint; \
	cd ../api && npm run lint; \
	cd ../worker && npm run lint

test:
	cd services/shared && npm test; \
	cd ../api && npm test; \
	cd ../worker && npm test

build:
	docker build -t deploy-sentinel-api -f services/api/Dockerfile .
	docker build -t deploy-sentinel-worker -f services/worker/Dockerfile .

# --- Terraform ---
ENV ?= dev

tf-init:
	cd infra/environments/$(ENV) && terraform init

tf-plan:
	cd infra/environments/$(ENV) && terraform plan

tf-apply:
	cd infra/environments/$(ENV) && terraform apply

tf-destroy:
	cd infra/environments/$(ENV) && terraform destroy

tf-fmt:
	terraform fmt -recursive infra/

tf-validate:
	cd infra/environments/$(ENV) && terraform init -backend=false && terraform validate

# --- Operations ---
deploy:
	./scripts/deploy.sh $(ENV)

teardown:
	./scripts/teardown.sh $(ENV)

bootstrap:
	./scripts/bootstrap.sh
