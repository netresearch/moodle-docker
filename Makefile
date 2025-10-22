.PHONY: help clone-moodle setup start stop restart logs clean build traefik

# Default target
.DEFAULT_GOAL := help

# Variables
MOODLE_BRANCH ?= MOODLE_405_STABLE
COMPOSE_FILES := -f compose.yml
COMPOSE_TRAEFIK := -f compose.yml -f compose.traefik.yml

help: ## Show this help message
	@echo "Moodle Docker Stack - Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:"
	@echo "  1. make clone-moodle   # Clone Moodle code"
	@echo "  2. make setup          # Create .env file"
	@echo "  3. make start          # Start the stack"
	@echo ""

clone-moodle: ## Clone Moodle repository (shallow clone, tip only)
	@if [ -d "moodle" ]; then \
		echo "⚠️  Moodle directory already exists"; \
		read -p "Delete and re-clone? [y/N] " confirm; \
		if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
			rm -rf moodle; \
		else \
			echo "Aborted."; \
			exit 1; \
		fi; \
	fi
	@echo "📥 Cloning Moodle $(MOODLE_BRANCH) (depth=1)..."
	git clone -b $(MOODLE_BRANCH) --depth 1 git://git.moodle.org/moodle.git
	@cd moodle && git branch
	@echo "✅ Moodle cloned successfully"

setup: ## Create .env file with random passwords
	@if [ -f ".env" ]; then \
		echo "⚠️  .env file already exists"; \
		read -p "Overwrite? [y/N] " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "Aborted."; \
			exit 1; \
		fi; \
	fi
	@echo "📝 Creating .env file with random passwords..."
	@cp .env.example .env
	@DB_PASS=$$(openssl rand -base64 32); \
	DB_ROOT_PASS=$$(openssl rand -base64 32); \
	VALKEY_PASS=$$(openssl rand -base64 32); \
	sed -i "s|CHANGE_ME_SECURE_PASSWORD_HERE|$$DB_PASS|" .env; \
	sed -i "s|CHANGE_ME_SECURE_ROOT_PASSWORD_HERE|$$DB_ROOT_PASS|" .env; \
	sed -i "s|CHANGE_ME_SECURE_VALKEY_PASSWORD_HERE|$$VALKEY_PASS|" .env
	@echo "✅ .env file created with secure random passwords"
	@echo "   Review and customize: nano .env"

start: ## Start all services (pulls pre-built image)
	docker compose $(COMPOSE_FILES) up -d
	@echo ""
	@echo "✅ Stack started!"
	@echo "   Moodle: http://localhost:8080"
	@echo ""
	@echo "Check status: make status"
	@echo "View logs:    make logs"

start-traefik: ## Start with Traefik (no exposed ports, uses Traefik labels)
	docker compose $(COMPOSE_TRAEFIK) up -d
	@echo ""
	@echo "✅ Stack started with Traefik!"
	@echo "   Access via your configured Traefik domain"
	@echo ""
	@echo "Check status: make status"

stop: ## Stop all services
	docker compose $(COMPOSE_FILES) down
	@echo "✅ Stack stopped"

restart: ## Restart all services
	docker compose $(COMPOSE_FILES) restart
	@echo "✅ Stack restarted"

build: ## Build Moodle image locally
	docker compose $(COMPOSE_FILES) build
	@echo "✅ Image built"

logs: ## Show logs from all services
	docker compose $(COMPOSE_FILES) logs -f

logs-moodle: ## Show Moodle logs only
	docker compose $(COMPOSE_FILES) logs -f moodle

logs-db: ## Show database logs only
	docker compose $(COMPOSE_FILES) logs -f database

logs-valkey: ## Show Valkey logs only
	docker compose $(COMPOSE_FILES) logs -f valkey

logs-ofelia: ## Show Ofelia cron logs only
	docker compose $(COMPOSE_FILES) logs -f ofelia

status: ## Show container status
	docker compose $(COMPOSE_FILES) ps

health: ## Check service health
	@echo "=== Service Health Status ==="
	@docker compose $(COMPOSE_FILES) ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

shell-moodle: ## Open shell in Moodle container
	docker compose $(COMPOSE_FILES) exec moodle bash

shell-db: ## Open MariaDB shell
	docker compose $(COMPOSE_FILES) exec database mariadb -uroot -p

clean: ## Stop and remove all containers, volumes, and networks
	@echo "⚠️  This will remove all containers, volumes, and data!"
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker compose $(COMPOSE_FILES) down -v; \
		echo "✅ Stack cleaned"; \
	else \
		echo "Aborted."; \
	fi

clean-moodle: ## Remove Moodle clone directory
	@echo "⚠️  This will delete the moodle/ directory!"
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		rm -rf moodle; \
		echo "✅ Moodle directory removed"; \
	else \
		echo "Aborted."; \
	fi

pull: ## Pull latest pre-built image from GHCR
	docker compose $(COMPOSE_FILES) pull moodle
	@echo "✅ Latest image pulled"

install: ## Run Moodle CLI installer
	@if [ ! -f ".env" ]; then \
		echo "❌ .env file not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "🚀 Installing Moodle via CLI..."
	@export $$(grep -v '^#' .env | xargs) && docker compose $(COMPOSE_FILES) exec -T moodle php admin/cli/install.php \
		--lang=en \
		--wwwroot=$${MOODLE_SITE_URL} \
		--dataroot=/var/moodledata \
		--dbtype=mariadb \
		--dbhost=database \
		--dbname=moodle \
		--dbuser=moodleuser \
		--dbpass=$${DB_PASSWORD} \
		--prefix=mdl_ \
		--fullname="Moodle LMS" \
		--shortname="Moodle" \
		--adminuser=admin \
		--adminpass=Admin123! \
		--adminemail=admin@example.com \
		--non-interactive \
		--agree-license
	@echo ""
	@echo "✅ Moodle installed successfully!"
	@echo "   URL: http://localhost:8080"
	@echo "   User: admin"
	@echo "   Pass: Admin123!"
	@echo ""
	@echo "⚠️  IMPORTANT: Change the admin password immediately!"

configure-cache: ## Configure Valkey for Moodle Universal Cache (MUC)
	@echo "🔧 Configuring Valkey for application cache..."
	docker compose $(COMPOSE_FILES) exec -T moodle php /var/www/scripts/configure-valkey-cache.php
	@echo "✅ Valkey cache configured"

upgrade-moodle: ## Upgrade Moodle code to latest in branch
	@if [ ! -d "moodle" ]; then \
		echo "❌ Moodle directory not found. Run 'make clone-moodle' first."; \
		exit 1; \
	fi
	@echo "📥 Pulling latest Moodle updates..."
	cd moodle && git pull
	@echo "✅ Moodle updated"
	@echo "⚠️  Remember to run the Moodle upgrade: http://localhost:8080/admin"
