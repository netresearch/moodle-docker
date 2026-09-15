# Moodle 5.2 Docker Stack

[![Docker Build](https://github.com/netresearch/moodle-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/netresearch/moodle-docker/actions/workflows/docker-build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Moodle](https://img.shields.io/badge/Moodle-5.2-orange.svg)](https://moodle.org/)
[![PHP](https://img.shields.io/badge/PHP-8.4-blue.svg)](https://www.php.net/)
[![nginx](https://img.shields.io/badge/nginx-1.31-green.svg)](https://nginx.org/)
[![MariaDB](https://img.shields.io/badge/MariaDB-12.3%20hardened-blue.svg)](https://mariadb.org/)
[![Valkey](https://img.shields.io/badge/Valkey-9-red.svg)](https://valkey.io/)

Production-ready Docker Compose stack for Moodle 5.2 LMS with PHP 8.4 (PHP-FPM),
nginx 1.31, MariaDB 12.3 (Docker Hardened Image), and Valkey 9.

## Key Features

- **Sources in the Image**: Moodle is fetched at build time and pinned to an
  upstream commit, not downloaded at container startup
- **Environment-Driven Config**: `config.php` is generated from environment variables
- **Modern Web Stack**: PHP-FPM + nginx architecture (no mod_php)
- **HTTP/2 and HTTP/3 (QUIC)**: Modern protocol support out of the box
- **Brotli Compression**: Better compression than gzip for modern browsers
- **Scheduled Cron**: Ofelia runs Moodle cron in the application container
  on a one-minute schedule
- **Redis Sessions**: Valkey-backed session storage for scalability

## Architecture

```
                              ┌─────────────────────────────────────────────────┐
                              │           Moodle 5.2 Docker Stack               │
                              ├─────────────────────────────────────────────────┤
                              │                                                 │
        HTTP/HTTPS/QUIC       │  ┌────────────────────────────────────────┐    │
      ───────────────────────►│  │           nginx 1.31                   │    │
        (80/443)              │  │   HTTP/2 + HTTP/3 + Brotli             │    │
                              │  │   Static files, SSL termination        │    │
                              │  └──────────────────┬─────────────────────┘    │
                              │                     │                           │
                              │                     │ FastCGI (port 9000)       │
                              │                     ▼                           │
                              │  ┌──────────────────────────────────────────┐  │
                              │  │              PHP 8.4 FPM                 │  │
                              │  │   Moodle App (baked into the image)     │  │
                              │  │   OPcache + JIT + Redis extension       │  │
                              │  └──────┬───────────────────────┬──────────┘  │
                              │         │                       │              │
                              │  ┌──────┴──────┐         ┌──────┴──────┐      │
                              │  │ MariaDB 12.3│         │  Valkey 9   │      │
                              │  │  Database   │         │  Sessions   │      │
                              │  │             │         │  + Cache    │      │
                              │  └─────────────┘         └─────────────┘      │
                              │                                                 │
                              │  ┌─────────────┐         ┌─────────────┐      │
                              │  │  Moodle App │◄────────│   Ofelia    │      │
                              │  │  (cron job) │  exec   │  Scheduler  │      │
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
| **nginx** | 1.31 | Web server with HTTP/2, HTTP/3 (QUIC), Brotli compression |
| **PHP-FPM** | 8.4 | PHP runtime with OPcache JIT, Redis, igbinary, APCu |
| **MariaDB** | 12.3 (hardened) | Docker Hardened Image, runs non-root (uid 65532) |
| **Valkey** | 9 | Redis-compatible server for sessions and cache |
| **Ofelia** | 1.0.0 (netresearch) | Docker-native cron scheduler for Moodle tasks |
| **Mailpit** | v1.31.1 | Development mail catcher (optional, `dev` profile) |

## Prerequisites

- Docker Engine 24.0+
- Access to `dhi.io` for the hardened MariaDB image (`docker login dhi.io`)
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

# Watch the logs (first start copies the sources into the code volume)
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
| `MOODLE_VERSION` | `5.2.3` | Moodle version baked into the image; changing it needs a rebuild |
| `MOODLE_URL` | `http://localhost` | Full URL to your Moodle site (no trailing slash) |
| `SSL_PROXY` | `false` | Set to `true` behind an SSL-terminating proxy; sets `$CFG->sslproxy` |
| `REVERSE_PROXY` | `false` | Sets `$CFG->reverseproxy` for advanced load balancing or port forwarding; leave off for a plain TLS terminator |
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

Visit https://download.moodle.org/releases/latest/ to see available versions. The
image is built from the matching Git tag at https://github.com/moodle/moodle/tags.

### 2. Update Version and Commit Pin

The build pins the upstream commit, so a version bump needs both values. Resolve
the tag and cross-check it against Moodle's own release metadata:

Replace `<version>` below with the release you are moving to, for example
`5.2.4` once it is published:

```bash
# Commit the tag points at
git ls-remote https://github.com/moodle/moodle.git "refs/tags/v<version>^{}"

# Cross-check against Moodle's own release metadata: githash must match the
# first characters of the commit above. `version` and `branch` describe the
# release you are coming FROM - the API answers with what is newer than that.
curl -s "https://download.moodle.org/api/1.3/updates.php?version=2026042003&branch=5.2&format=json" \
  | grep -o '"release":"<version>[^}]*githash":"[^"]*"'
```

```bash
# Edit .env and change MOODLE_VERSION
nano .env
# Change: MOODLE_VERSION=<version>
```

Then update `ARG MOODLE_COMMIT` in `docker/moodle/Dockerfile` to the resolved
commit. A mismatch fails the build rather than producing an image whose contents
nobody verified.

### 3. Rebuild and Restart the Stack

The sources ship inside the image, so the new version needs a rebuild — changing
`MOODLE_VERSION` alone makes the container refuse to start rather than serve a
version that is not there.

```bash
# Enable maintenance mode first
docker compose exec moodle php /var/www/html/admin/cli/maintenance.php --enable

# Backup database (recommended)
docker compose exec database mysqldump -uroot -p"$DB_ROOT_PASSWORD" moodle | gzip > backup-$(date +%Y%m%d).sql.gz

# Rebuild the image with the new version, then restart
docker compose build moodle
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

`SSL_PROXY` and `REVERSE_PROXY` are different switches and a TLS terminator needs only the first.
`$CFG->reverseproxy` makes Moodle compare every request against `wwwroot` and abort with `reverseproxyabused`
when they differ, which is what Traefik in front of the same host produces. Turn `REVERSE_PROXY=true` on only
for the advanced load balancing and port forwarding cases Moodle's `config-dist.php` describes.

The Traefik overlay drops the published host ports (`ports: !reset []`), so nginx is then reachable through
Traefik alone. That matters because nginx trusts `X-Forwarded-Proto` to decide the scheme it reports to PHP:
behind Traefik the header is set by Traefik on every request, while the base stack publishes port 80 and
anyone reaching it directly can declare any scheme. Do not publish those ports on a host that also sits behind
a proxy.

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
| `moodle_code` | Moodle PHP source code (copied from the image on first start) |
| `moodledata` | User files, cache, temp files |
| `db_data` | MariaDB database files |
| `valkey_data` | Valkey persistence (AOF) |

## Networks

| Network | Purpose |
|---------|---------|
| `frontend` | External access (nginx) |
| `backend` | Internal services (isolated, no external access) |

## Troubleshooting

### Moodle Sources Missing or Version Mismatch

The sources are baked into the image, so a failed fetch shows up as a build
failure, not as a container that never becomes healthy.

On a version mismatch the container exits during startup, so these use a
one-off container rather than `exec`, which would need a running one.

```bash
# Check container logs
docker compose logs moodle

# Which version does the image carry?
docker compose run --rm --no-deps --entrypoint cat moodle /opt/moodle-dist/.moodle-version

# Which version is installed in the code volume?
docker compose run --rm --no-deps --entrypoint cat moodle /var/www/html/.moodle-version

# On a mismatch, set MOODLE_VERSION in .env, then rebuild and restart.
# Compose passes that value as the build argument, so do not pass it again
# here - a divergence between the two is what caused the mismatch.
docker compose build moodle
docker compose up -d moodle
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
docker compose logs ofelia

# Run cron manually
docker compose exec -u www-data moodle php /var/www/html/admin/cli/cron.php
```

## Security Notes

1. **Change all default passwords** in `.env` before deployment
2. Never commit `.env` to version control
3. Use strong passwords (24+ characters recommended)
4. For production, mount real SSL certificates instead of self-signed
5. Set `SSL_PROXY=true` when behind Traefik or other SSL-terminating proxy, and keep `REVERSE_PROXY=false`
   unless you really run the advanced setup it is meant for
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
