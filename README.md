# Moodle 4.5 Docker Stack

[![Docker Build](https://github.com/netresearch/moodle-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/netresearch/moodle-docker/actions/workflows/docker-build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Moodle](https://img.shields.io/badge/Moodle-4.5-orange.svg)](https://moodle.org/)
[![PHP](https://img.shields.io/badge/PHP-8.3-blue.svg)](https://www.php.net/)
[![MariaDB](https://img.shields.io/badge/MariaDB-11-blue.svg)](https://mariadb.org/)
[![Valkey](https://img.shields.io/badge/Valkey-9-red.svg)](https://valkey.io/)

Production-ready Docker Compose stack for Moodle 4.5 LMS with PHP 8.3, MariaDB 11, and Valkey 9.

## Architecture

```
┌─────────────────────────────────────────┐
│         Moodle 4.5 Stack                │
├─────────────────────────────────────────┤
│  ┌──────────┐   ┌──────────┐           │
│  │  Moodle  │   │  Ofelia  │           │
│  │ PHP 8.3  │   │  (Cron)  │           │
│  │  Apache  │   └──────────┘           │
│  └─────┬────┘                           │
│        │                                │
│  ┌─────┴──────┐   ┌────────────┐       │
│  │  MariaDB   │   │  Valkey 9  │       │
│  │     11     │   │ (Sessions  │       │
│  │            │   │  + Cache)  │       │
│  └────────────┘   └────────────┘       │
└─────────────────────────────────────────┘
```

## Components

- **Moodle**: PHP 8.3 + Apache on Debian Bookworm (available at `ghcr.io/netresearch/moodle-docker/moodle:latest`)
- **MariaDB 11**: Database server with optimized configuration
- **Valkey 9**: Redis-compatible cache and session storage
- **Ofelia**: Docker-native cron scheduler for Moodle tasks

## Pre-built Docker Image

The Moodle image is automatically built and published to GitHub Container Registry:

```bash
# Pull the latest image
docker pull ghcr.io/netresearch/moodle-docker/moodle:latest

# Or use in compose.yml instead of building locally
services:
  moodle:
    image: ghcr.io/netresearch/moodle-docker/moodle:latest
    # ... rest of configuration
```

Available tags:
- `latest` - Latest build from main branch
- `main` - Latest build from main branch
- `main-<sha>` - Specific commit from main branch

The `compose.yml` includes both `image:` and `build:` directives:
- `docker compose up` - Pulls pre-built image (fast)
- `docker compose build` - Builds locally (for customization)

## Prerequisites

- Docker Engine 20.10.15+
- Docker Compose V2.5.0+
- Git
- 4GB+ RAM (8GB+ recommended for production)
- 50GB+ disk space

## Quick Start

### 1. Clone Moodle Repository

```bash
# Clone Moodle 4.5 stable branch
git clone -b MOODLE_405_STABLE --depth 1 git://git.moodle.org/moodle.git

# Verify branch
cd moodle
git branch
# Should show: * MOODLE_405_STABLE
cd ..
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Generate secure passwords
openssl rand -base64 32  # Use for DB_PASSWORD
openssl rand -base64 32  # Use for DB_ROOT_PASSWORD
openssl rand -base64 32  # Use for VALKEY_PASSWORD

# Edit .env with your values
nano .env
```

**Required changes in `.env`:**
- `DB_PASSWORD`: Set secure password
- `DB_ROOT_PASSWORD`: Set secure password
- `VALKEY_PASSWORD`: Set secure password
- `MOODLE_SITE_URL`: Update for production (e.g., `https://moodle.example.com`)

### 3. Start Services

```bash
# Pull pre-built image and start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f moodle
```

### 4. Install Moodle

**Option A: Web Installer (Recommended)**

1. Open browser: `http://localhost:8080` (or your configured URL)
2. Follow installation wizard
3. Database settings will be auto-detected from environment variables

**Option B: CLI Installer**

```bash
docker compose exec moodle php admin/cli/install.php \
  --lang=en \
  --wwwroot=http://localhost:8080 \
  --dataroot=/var/moodledata \
  --dbtype=mariadb \
  --dbhost=database \
  --dbname=moodle \
  --dbuser=moodleuser \
  --dbpass=YOUR_DB_PASSWORD \
  --prefix=mdl_ \
  --fullname="My Moodle Site" \
  --shortname="Moodle" \
  --adminuser=admin \
  --adminpass=Admin123! \
  --adminemail=admin@example.com \
  --non-interactive \
  --agree-license
```

### 5. Configure Valkey Cache (MUC)

After installation:

1. Go to: **Site Administration → Plugins → Caching → Configuration**
2. Click **Add instance** under Redis
3. Configure:
   - **Server**: `valkey:6379`
   - **Password**: Your `VALKEY_PASSWORD` from `.env`
   - **Database**: `1` (sessions use database 0)
   - **Serializer**: PHP (or igbinary if available)
4. Click **Save changes**
5. Map **Application cache** to the Valkey store

## Operations

### Service Management

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart single service
docker compose restart moodle

# View logs
docker compose logs -f [service_name]

# Execute commands
docker compose exec moodle bash
```

### Moodle CLI

```bash
# Run Moodle cron manually
docker compose exec moodle php admin/cli/cron.php

# Enable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --enable

# Disable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --disable

# Purge all caches
docker compose exec moodle php admin/cli/purge_caches.php

# List scheduled tasks
docker compose exec moodle php admin/cli/scheduled_task.php --list
```

### Database Access

```bash
# MySQL CLI
docker compose exec database mysql -u root -p

# mysqldump
docker compose exec database mysqldump -u root -p moodle > backup.sql
```

### Valkey Access

```bash
# Valkey CLI
docker compose exec valkey valkey-cli -a YOUR_VALKEY_PASSWORD

# Check memory usage
docker compose exec valkey valkey-cli -a YOUR_VALKEY_PASSWORD INFO memory

# Monitor commands
docker compose exec valkey valkey-cli -a YOUR_VALKEY_PASSWORD MONITOR
```

## Upgrading Moodle

```bash
# 1. Enable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --enable

# 2. Backup database (recommended)
docker compose exec database mysqldump -u root -p moodle | gzip > moodle-backup-$(date +%Y%m%d).sql.gz

# 3. Update Moodle code
cd moodle
git fetch origin
git checkout MOODLE_410_STABLE  # Next version

# 4. Run upgrade
docker compose exec moodle php admin/cli/upgrade.php --non-interactive

# 5. Purge caches
docker compose exec moodle php admin/cli/purge_caches.php

# 6. Disable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --disable
```

## Traefik Integration

To enable Traefik reverse proxy with automatic SSL:

1. Ensure Traefik is running on your Docker host
2. Edit `compose.yml` and uncomment Traefik labels under `moodle` service
3. Update labels with your domain:
   ```yaml
   traefik.enable: "true"
   traefik.http.routers.moodle.rule: "Host(`moodle.example.com`)"
   traefik.http.routers.moodle.entrypoints: "websecure"
   traefik.http.routers.moodle.tls.certresolver: "letsencrypt"
   ```
4. Update `.env`:
   ```env
   MOODLE_SITE_URL=https://moodle.example.com
   ```
5. Update `config/moodle-config.php`:
   ```php
   $CFG->cookiesecure = true;
   $CFG->sslproxy = true;
   ```
6. Restart: `docker compose up -d`

## Troubleshooting

### Moodle not accessible

```bash
# Check container status
docker compose ps

# Check logs
docker compose logs moodle

# Test internal access
docker compose exec moodle curl -I http://localhost/
```

### Database connection failed

```bash
# Verify database is running
docker compose ps database

# Test connection from Moodle container
docker compose exec moodle ping -c 3 database

# Check database logs
docker compose logs database

# Verify credentials match in .env and config/moodle-config.php
```

### Cron not running

```bash
# Check Ofelia logs
docker compose logs ofelia

# Manually trigger cron
docker compose exec moodle php admin/cli/cron.php

# Check scheduled tasks status
docker compose exec moodle php admin/cli/scheduled_task.php --list
```

### Permission errors

```bash
# Fix moodledata permissions
docker compose exec moodle chown -R www-data:www-data /var/moodledata
docker compose exec moodle chmod -R 0750 /var/moodledata

# Fix web root permissions
docker compose exec moodle chown -R www-data:www-data /var/www/html
```

### Out of memory

```bash
# Check container memory usage
docker stats

# Increase PHP memory limit in docker/moodle/Dockerfile:
# memory_limit = 512M  (or higher)

# Rebuild image
docker compose build moodle
docker compose up -d moodle
```

## File Structure

```
moodle_docker/
├── docker/
│   ├── moodle/
│   │   └── Dockerfile              # Custom PHP 8.3 + Apache image
│   ├── mariadb/
│   │   └── custom.cnf              # MariaDB optimization
│   └── valkey/
│       └── valkey.conf             # Valkey configuration
├── moodle/                         # Git clone of Moodle code
├── config/
│   └── moodle-config.php           # Moodle configuration
├── claudedocs/
│   └── PRD_Moodle_4.5_Docker_Stack.md  # Product requirements
├── compose.yml                     # Docker Compose configuration
├── .env                            # Environment variables (create from .env.example)
├── .env.example                    # Environment template
├── .gitignore                      # Git ignore rules
└── README.md                       # This file
```

## Volumes

- **moodledata**: User files, cache, temp files (persistent)
- **db_data**: MariaDB database files (persistent)
- **valkey_data**: Valkey data (persistent for sessions)

## Networks

- **frontend**: External access (Moodle web interface)
- **backend**: Internal services (MariaDB, Valkey)

## Security Notes

1. **Change all default passwords** in `.env`
2. Never commit `.env` to version control
3. Use strong passwords (32+ characters)
4. Enable HTTPS in production (via Traefik or SSL certificates)
5. Set `$CFG->cookiesecure = true` when using HTTPS
6. Keep Docker images updated: `docker compose pull && docker compose up -d`
7. Regularly update Moodle: check for security releases
8. Backend network can be set to `internal: true` if no external access needed

## Performance Tuning

### For Production

1. **Increase resources in `compose.yml`**:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2.0'
         memory: 2G
   ```

2. **Adjust MariaDB settings** in `docker/mariadb/custom.cnf`:
   - `innodb_buffer_pool_size`: 50-70% of available RAM
   - `innodb_io_capacity`: 2000+ for SSD

3. **Increase Valkey memory** in `docker/valkey/valkey.conf`:
   - `maxmemory 1gb` (or higher based on needs)

4. **Enable Valkey MUC** for application cache (see setup above)

5. **PHP tuning** in `docker/moodle/Dockerfile`:
   - Increase `memory_limit` to 512M or higher
   - Adjust `max_execution_time` if needed

## Support & Documentation

- **Moodle Documentation**: https://docs.moodle.org/405/en/
- **Moodle Forums**: https://moodle.org/forums/
- **Docker Documentation**: https://docs.docker.com/
- **Valkey Documentation**: https://valkey.io/

## License

This Docker stack configuration is provided as-is. Moodle is licensed under GPL v3.
