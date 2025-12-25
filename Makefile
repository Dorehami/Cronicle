.PHONY: help build dev up down logs shell clean test

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build Docker image
	docker build -t cronicle:latest .

dev: ## Start development environment
	docker compose up -d
	@echo "Cronicle development environment started"
	@echo "Access UI at http://localhost:3012"
	@echo "Login: admin / admin"

up: dev ## Alias for dev

down: ## Stop development environment
	docker compose down

logs: ## View logs
	docker compose logs -f cronicle

shell: ## Access container shell
	docker compose exec cronicle bash

clean: ## Stop and remove containers, volumes
	docker compose down -v
	@echo "Cleaned up containers and volumes"

test: build ## Build and test image
	@echo "Testing Docker image..."
	docker run --rm --name cronicle-test -d -p 3012:3012 cronicle:latest
	@sleep 30
	@echo "Checking health..."
	@curl -sf http://localhost:3012/ > /dev/null && echo "✓ Health check passed" || echo "✗ Health check failed"
	@docker stop cronicle-test
	@echo "Test complete"

.DEFAULT_GOAL := help
