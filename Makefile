.PHONY: help setup certs start start-traefik stop restart logs clean build install \
	configure-cache upgrade-moodle pull status health

# Default target
.DEFAULT_GOAL := help

# Variables
COMPOSE_FILES := -f compose.yml
COMPOSE_TRAEFIK := -f compose.yml -f compose.traefik.yml

help: ## Show this help message
	@echo "Moodle Docker Stack - Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:"
	@echo "  1. make setup          # Create .env with random passwords and a TLS certificate"
	@echo "  2. make start          # Start the stack"
	@echo "  3. make install        # Create the Moodle database (first time only)"
	@echo ""

setup: certs ## Create .env with random passwords and a TLS certificate
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
	@set -e; \
	for placeholder in CHANGE_ME_SECURE_ROOT_PASSWORD CHANGE_ME_SECURE_VALKEY_PASSWORD CHANGE_ME_SECURE_PASSWORD; do \
		grep -q "$$placeholder" .env || { echo "❌ .env.example no longer contains $$placeholder"; exit 1; }; \
		pass=$$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32); \
		sed -i "s|$$placeholder|$$pass|" .env; \
	done; \
	if grep -q CHANGE_ME .env; then echo "❌ placeholders left in .env"; exit 1; fi
	@echo "✅ .env file created with secure random passwords"
	@echo "   Review and customize: nano .env"

certs: ## Create a self-signed TLS certificate for nginx if there is none
	@if [ -f "docker/nginx/ssl/cert.pem" ] && [ -f "docker/nginx/ssl/key.pem" ]; then \
		echo "✅ TLS certificate already present"; \
	else \
		echo "🔐 Creating a self-signed TLS certificate (nginx will not start without one)..."; \
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout docker/nginx/ssl/key.pem \
			-out docker/nginx/ssl/cert.pem \
			-subj "/CN=localhost" 2>/dev/null; \
		echo "✅ Certificate created - replace it with a real one for production"; \
	fi

start: certs ## Start all services (pulls pre-built image)
	docker compose $(COMPOSE_FILES) up -d
	@echo ""
	@echo "✅ Stack started!"
	@echo "   Moodle: http://localhost"
	@echo ""
	@echo "Check status: make status"
	@echo "View logs:    make logs"

start-traefik: certs ## Start with Traefik (no exposed ports, uses Traefik labels)
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

pull: ## Pull latest pre-built image from GHCR
	docker compose $(COMPOSE_FILES) pull moodle
	@echo "✅ Latest image pulled"

install: ## Create the Moodle database (first time only) - pass ADMIN_PASS and ADMIN_EMAIL
	@if [ ! -f ".env" ]; then \
		echo "❌ .env file not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@if [ -z "$(ADMIN_PASS)" ] || [ -z "$(ADMIN_EMAIL)" ]; then \
		echo "❌ Usage: make install ADMIN_PASS='<password>' ADMIN_EMAIL='<address>'"; \
		echo "   Moodle enforces its own password policy on the value."; \
		exit 1; \
	fi
	@echo "🚀 Creating the Moodle database..."
	@docker compose $(COMPOSE_FILES) exec -T -u www-data moodle \
		php /var/www/html/admin/cli/install_database.php \
		--lang=en \
		--adminuser=admin \
		--adminpass="$(ADMIN_PASS)" \
		--adminemail="$(ADMIN_EMAIL)" \
		--fullname="Moodle" \
		--shortname="Moodle" \
		--agree-license
	@echo ""
	@echo "✅ Moodle installed. Sign in as 'admin' with the password you passed in."

configure-cache: ## Configure Valkey for Moodle Universal Cache (MUC)
	@echo "🔧 Configuring Valkey for application cache..."
	@docker compose $(COMPOSE_FILES) cp scripts/configure-valkey-cache.php moodle:/tmp/configure-valkey-cache.php
	@docker compose $(COMPOSE_FILES) exec -T -u www-data moodle php /tmp/configure-valkey-cache.php
	@docker compose $(COMPOSE_FILES) exec -T moodle rm -f /tmp/configure-valkey-cache.php
	@echo "✅ Valkey cache configured"

upgrade-moodle: ## Rebuild the image for the MOODLE_VERSION in .env and restart
	@if [ ! -f ".env" ]; then \
		echo "❌ .env file not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@echo "🏗️  Rebuilding the Moodle image..."
	docker compose $(COMPOSE_FILES) build moodle
	docker compose $(COMPOSE_FILES) up -d moodle
	@echo "✅ Rebuilt and restarted - the entrypoint upgrades the database itself"
	@echo "   Watch it: make logs-moodle"
