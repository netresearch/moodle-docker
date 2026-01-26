# Moodle 5.1 Docker Stack

[![Docker Build](https://github.com/netresearch/moodle-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/netresearch/moodle-docker/actions/workflows/docker-build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Moodle](https://img.shields.io/badge/Moodle-5.1-orange.svg)](https://moodle.org/)
[![PHP](https://img.shields.io/badge/PHP-8.4-blue.svg)](https://www.php.net/)
[![nginx](https://img.shields.io/badge/nginx-1.27-green.svg)](https://nginx.org/)
[![MariaDB](https://img.shields.io/badge/MariaDB-11.8-blue.svg)](https://mariadb.org/)
[![Valkey](https://img.shields.io/badge/Valkey-9-red.svg)](https://valkey.io/)

Production-ready Docker Compose stack for Moodle 5.1 LMS with PHP 8.4 (PHP-FPM), nginx 1.27, MariaDB 11.8, and Valkey 9.

## Key Features

- **Runtime Moodle Download**: Moodle is downloaded at container startup, not baked into the image
- **Environment-Driven Config**: `config.php` is generated from environment variables
- **Modern Web Stack**: PHP-FPM + nginx architecture (no mod_php)
- **HTTP/2 and HTTP/3 (QUIC)**: Modern protocol support out of the box
- **Brotli Compression**: Better compression than gzip for modern browsers
- **Dedicated Cron Container**: Isolated cron execution via Ofelia scheduler
- **Redis Sessions**: Valkey-backed session storage for scalability

## Architecture

```
                              ┌─────────────────────────────────────────────────┐
                              │           Moodle 5.1 Docker Stack               │
                              ├─────────────────────────────────────────────────┤
                              │                                                 │
        HTTP/HTTPS/QUIC       │  ┌────────────────────────────────────────┐    │
      ───────────────────────►│  │           nginx 1.27                   │    │
        (80/443)              │  │   HTTP/2 + HTTP/3 + Brotli             │    │
                              │  │   Static files, SSL termination        │    │
                              │  └──────────────────┬─────────────────────┘    │
                              │                     │                           │
                              │                     │ FastCGI (port 9000)       │
                              │                     ▼                           │
                              │  ┌──────────────────────────────────────────┐  │
                              │  │              PHP 8.4 FPM                 │  │
                              │  │   Moodle App (downloaded at runtime)    │  │
                              │  │   OPcache + JIT + Redis extension       │  │
                              │  └──────┬───────────────────────┬──────────┘  │
                              │         │                       │              │
                              │  ┌──────┴──────┐         ┌──────┴──────┐      │
                              │  │ MariaDB 11.8│         │  Valkey 9   │      │
                              │  │  Database   │         │  Sessions   │      │
                              │  │             │         │  + Cache    │      │
                              │  └─────────────┘         └─────────────┘      │
                              │                                                 │
                              │  ┌─────────────┐         ┌─────────────┐      │
                              │  │ Moodle Cron │◄────────│   Ofelia    │      │
                              │  │ (PHP-FPM)   │  exec   │  Scheduler  │      │
                              │  └─────────────┘         └─────────────┘      │
                              │                                                 │
                              │  ┌─────────────┐  (optional, dev profile)     │
                              │  │   Mailpit   │  Mail catcher for testing    │
                              │  └─────────────┘                               │
                              └─────────────────────────────────────────────────┘
```

## Components

| Component | Version | Description |
|-----------|---------|-------------|
| **nginx** | 1.27 | Web server with HTTP/2, HTTP/3 (QUIC), Brotli compression |
| **PHP-FPM** | 8.4 | PHP runtime with OPcache JIT, Redis, igbinary, APCu |
| **MariaDB** | 11.8 LTS | Database server with optimized InnoDB configuration |
| **Valkey** | 9 | Redis-compatible server for sessions and cache |
| **Ofelia** | latest | Docker-native cron scheduler for Moodle tasks |
| **Mailpit** | latest | Development mail catcher (optional, `dev` profile) |

## Prerequisites

- Docker Engine 24.0+
- Docker Compose V2.20+
- 4GB+ RAM (8GB+ recommended for production)
- 20GB+ disk space

## Quick Start

### 1. Clone this Repository

```bash
git clone https://github.com/netresearch/moodle-docker.git
cd moodle-docker
```

### 2. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Generate secure passwords (or use your own)
sed -i "s/CHANGE_ME_SECURE_PASSWORD/$(openssl rand -base64 24)/" .env
sed -i "s/CHANGE_ME_SECURE_ROOT_PASSWORD/$(openssl rand -base64 24)/" .env
sed -i "s/CHANGE_ME_SECURE_VALKEY_PASSWORD/$(openssl rand -base64 24)/" .env

# Review and customize
nano .env
```

### 3. Start the Stack

```bash
# Start all services
docker compose up -d

# Watch the logs (Moodle download takes 1-2 minutes on first start)
docker compose logs -f moodle
```

### 4. Access Moodle

- **Web UI**: http://localhost (or https://localhost with self-signed cert warning)
- **First run**: Complete the Moodle installation wizard
- **Database settings**: Pre-filled from environment variables

## Environment Variables

All configuration is done via environment variables in `.env`:

### Moodle Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `MOODLE_VERSION` | `5.1.2` | Moodle version to download and install |
| `MOODLE_URL` | `http://localhost` | Full URL to your Moodle site (no trailing slash) |
| `SSL_PROXY` | `false` | Set to `true` if behind SSL-terminating proxy |
| `MOODLE_DEBUG` | `false` | Enable Moodle debug mode for development |

### Database Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_TYPE` | `mariadb` | Database type (`mariadb` or `pgsql`) |
| `DB_HOST` | `database` | Database hostname |
| `DB_NAME` | `moodle` | Database name |
| `DB_USER` | `moodle` | Database user |
| `DB_PASSWORD` | *required* | Database password |
| `DB_ROOT_PASSWORD` | *required* | Database root password |
| `DB_PREFIX` | `mdl_` | Table prefix |

### Cache Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VALKEY_HOST` | `valkey` | Valkey server hostname |
| `VALKEY_PORT` | `6379` | Valkey server port |
| `VALKEY_PASSWORD` | *required* | Valkey authentication password |

### Email Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_HOST` | `mailpit` | SMTP server hostname |
| `SMTP_PORT` | `1025` | SMTP server port |
| `SMTP_NOREPLY` | `noreply@example.com` | No-reply email address |

### Port Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `HTTP_PORT` | `80` | HTTP port to expose |
| `HTTPS_PORT` | `443` | HTTPS port to expose (TCP + UDP for HTTP/3) |

## Upgrading Moodle

To upgrade to a new Moodle version:

### 1. Check Available Versions

Visit https://download.moodle.org/releases/latest/ to see available versions.

### 2. Update Environment Variable

```bash
# Edit .env and change MOODLE_VERSION
nano .env
# Change: MOODLE_VERSION=5.1.3  (or desired version)
```

### 3. Restart the Stack

```bash
# Enable maintenance mode first
docker compose exec moodle php /var/www/html/admin/cli/maintenance.php --enable

# Backup database (recommended)
docker compose exec database mysqldump -uroot -p"$DB_ROOT_PASSWORD" moodle | gzip > backup-$(date +%Y%m%d).sql.gz

# Restart to trigger download of new version
docker compose up -d moodle

# Watch the upgrade
docker compose logs -f moodle

# Run database upgrade
docker compose exec moodle php /var/www/html/admin/cli/upgrade.php --non-interactive

# Disable maintenance mode
docker compose exec moodle php /var/www/html/admin/cli/maintenance.php --disable
```

The entrypoint script automatically:
- Detects the version change
- Downloads the new Moodle version
- Preserves any custom plugins you've installed
- Regenerates `config.php`

## Development

### Using Mailpit (Mail Catcher)

For development, you can enable the Mailpit mail catcher to intercept all outgoing emails:

```bash
# Start with the dev profile
docker compose --profile dev up -d

# Access Mailpit web UI at http://localhost/mailpit/
```

All emails sent by Moodle will appear in Mailpit instead of being delivered.

### Building Images Locally

If you want to customize the Docker images:

```bash
# Build all images
docker compose build

# Build a specific image
docker compose build moodle
docker compose build nginx

# Force rebuild without cache
docker compose build --no-cache
```

### Accessing Containers

```bash
# Shell into Moodle container
docker compose exec moodle sh

# Shell into nginx container
docker compose exec nginx sh

# Run Moodle CLI commands
docker compose exec moodle php /var/www/html/admin/cli/cron.php
docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php

# Access database
docker compose exec database mariadb -uroot -p
```

## Traefik Integration

For production deployments with Traefik reverse proxy:

```bash
# Configure in .env
MOODLE_URL=https://moodle.example.com
SSL_PROXY=true

# Start with Traefik overlay
docker compose -f compose.yml -f compose.traefik.yml up -d
```

See `compose.traefik.yml` for Traefik labels configuration.

## File Structure

```
moodle-docker/
├── docker/
│   ├── moodle/
│   │   ├── Dockerfile          # PHP 8.4 FPM image
│   │   └── entrypoint.sh       # Moodle download & config generation
│   ├── nginx/
│   │   ├── Dockerfile          # nginx with Brotli modules
│   │   ├── nginx.conf          # nginx configuration
│   │   └── ssl/                # SSL certificates (mount your own for prod)
│   ├── mariadb/
│   │   └── custom.cnf          # MariaDB optimization settings
│   └── valkey/
│       └── valkey.conf         # Valkey configuration
├── compose.yml                 # Main Docker Compose configuration
├── compose.traefik.yml         # Traefik overlay for production
├── .env.example                # Environment template
├── Makefile                    # Convenience commands
└── README.md                   # This file
```

## Volumes

| Volume | Purpose |
|--------|---------|
| `moodle_code` | Moodle PHP source code (downloaded at runtime) |
| `moodledata` | User files, cache, temp files |
| `db_data` | MariaDB database files |
| `valkey_data` | Valkey persistence (AOF) |

## Networks

| Network | Purpose |
|---------|---------|
| `frontend` | External access (nginx) |
| `backend` | Internal services (isolated, no external access) |

## Troubleshooting

### Moodle Download Fails

```bash
# Check container logs
docker compose logs moodle

# Verify internet connectivity from container
docker compose exec moodle curl -I https://download.moodle.org

# Manual download URL test
docker compose exec moodle curl -fSL "https://download.moodle.org/download.php/direct/stable501/moodle-5.1.2.tgz" -o /tmp/test.tgz
```

### PHP-FPM Health Check Fails

```bash
# Check PHP-FPM status
docker compose exec moodle php-fpm-healthcheck

# Check PHP-FPM logs
docker compose logs moodle

# Verify PHP-FPM is running
docker compose exec moodle ps aux | grep php-fpm
```

### Database Connection Issues

```bash
# Test database connectivity
docker compose exec moodle php -r "new PDO('mysql:host=database;dbname=moodle', 'moodle', getenv('DB_PASSWORD'));"

# Check database logs
docker compose logs database
```

### Permission Errors

```bash
# Fix moodledata permissions
docker compose exec moodle chown -R www-data:www-data /var/moodledata
docker compose exec moodle chmod -R 0775 /var/moodledata
```

### Cron Not Running

```bash
# Check Ofelia logs
docker compose logs ofelia

# Check cron container
docker compose logs moodle-cron

# Run cron manually
docker compose exec moodle-cron php /var/www/html/admin/cli/cron.php
```

## Security Notes

1. **Change all default passwords** in `.env` before deployment
2. Never commit `.env` to version control
3. Use strong passwords (24+ characters recommended)
4. For production, mount real SSL certificates instead of self-signed
5. Set `SSL_PROXY=true` when behind Traefik or other SSL-terminating proxy
6. The backend network is isolated (`internal: true`) - only nginx has external access
7. Keep images updated: `docker compose pull && docker compose up -d`

## Performance Tuning

### PHP-FPM

Adjust in `docker/moodle/Dockerfile`:

```ini
; Increase for high-traffic sites
pm.max_children = 100
pm.start_servers = 10
pm.min_spare_servers = 10
pm.max_spare_servers = 50
```

### MariaDB

Adjust in `docker/mariadb/custom.cnf`:

```ini
; Set to 50-70% of available RAM
innodb_buffer_pool_size = 2G

; Increase for SSD storage
innodb_io_capacity = 2000
```

### Valkey

Adjust memory via compose.yml or command line:

```bash
# In compose.yml, change:
--maxmemory 1gb
```

### nginx

Adjust in `docker/nginx/nginx.conf`:

```nginx
# Increase for high concurrency
worker_connections 4096;
```

## Support & Documentation

- **Moodle Documentation**: https://docs.moodle.org/501/en/
- **Moodle Forums**: https://moodle.org/forums/
- **Docker Documentation**: https://docs.docker.com/
- **Valkey Documentation**: https://valkey.io/docs/

## License

This Docker stack configuration is provided under the MIT License. Moodle is licensed under GPL v3.
