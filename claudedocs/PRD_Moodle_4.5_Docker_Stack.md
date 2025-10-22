# Product Requirements Document: Moodle 4.5 Docker Compose Stack

**Version:** 1.0
**Date:** 2025-10-22
**Status:** Draft
**Author:** Technical Architecture Team

---

## Executive Summary

This document defines the requirements and architecture for a production-ready Docker Compose stack for Moodle 4.5 Learning Management System. The solution provides a containerized, scalable, and maintainable deployment supporting both development and production environments.

### Key Objectives

- Deploy Moodle 4.5 with PHP 8.3 and MariaDB 11
- Provide development and production environment configurations
- Implement automated cron job scheduling
- Ensure data persistence and backup capability
- Enable performance optimization through caching
- Support security hardening and monitoring

---

## 1. Technical Requirements

### 1.1 Core Components

| Component | Version | Purpose | Priority |
|-----------|---------|---------|----------|
| Moodle | 4.5.x (MOODLE_405_STABLE) | LMS Application | CRITICAL |
| PHP | 8.3.x | Application Runtime | CRITICAL |
| MariaDB | 11.x | Database Server | CRITICAL |
| Redis | 7.x | Cache & Sessions | HIGH |
| Apache | 2.4.x | Web Server | CRITICAL |
| Ofelia | latest | Cron Scheduler | HIGH |

### 1.2 PHP Requirements

**Minimum PHP Version:** 8.3.0
**Architecture:** 64-bit only

**Required PHP Extensions:**
```
Core Extensions:
- sodium (Moodle 4.5 requirement)
- curl, zip, xml, mbstring, json, openssl
- gd or imagick (image processing)
- intl (internationalization)
- opcache (performance)

Database Connectors:
- mysqli, pdo_mysql (MariaDB)
- pgsql, pdo_pgsql (optional PostgreSQL support)

Additional Extensions:
- bcmath, bz2, calendar, exif, ftp, gettext, iconv
- ldap (LDAP authentication)
- pcntl, soap, sockets
- sysvmsg, sysvsem, sysvshm
- tokenizer, xmlrpc

Performance Extensions:
- redis (cache backend)
- apcu (alternative caching)
- igbinary (efficient serialization)
```

**PHP Configuration:**
```ini
max_input_vars = 5000           # Moodle 4.5 minimum requirement
memory_limit = 256M             # Minimum, 512M recommended
upload_max_filesize = 100M      # Adjust based on needs
post_max_size = 100M
max_execution_time = 300
```

### 1.3 Database Requirements

**MariaDB Configuration:**
- **Minimum Version:** 10.6.7 (Moodle requirement)
- **Target Version:** 11.x (user requirement)
- **Character Set:** utf8mb4
- **Collation:** utf8mb4_unicode_ci
- **Max Prefix Length:** 10 characters

**Recommended Settings:**
```ini
[mysqld]
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1
max_connections = 200
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

### 1.4 System Requirements

**Minimum Resources (Development):**
- CPU: 2 cores
- RAM: 4GB
- Disk: 20GB (application + small dataset)

**Recommended Resources (Production):**
- CPU: 4+ cores
- RAM: 8GB+ (16GB for large installations)
- Disk: 100GB+ (highly dependent on moodledata size)
- Network: 100Mbps+

---

## 2. Architecture Design

### 2.1 Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Docker Host                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Frontend Network                     │ │
│  │                                                          │ │
│  │  ┌──────────────┐         ┌─────────────┐              │ │
│  │  │   Moodle     │◄────────┤  Ofelia     │              │ │
│  │  │  (PHP 8.3)   │         │  (Cron)     │              │ │
│  │  └──────┬───────┘         └─────────────┘              │ │
│  │         │                                                │ │
│  └─────────┼────────────────────────────────────────────────┘ │
│            │                                                  │
│  ┌─────────┼────────────────────────────────────────────────┐ │
│  │         │         Backend Network                        │ │
│  │         │                                                │ │
│  │    ┌────▼─────┐      ┌──────────┐                       │ │
│  │    │ MariaDB  │      │  Redis   │                       │ │
│  │    │   11.x   │      │   7.x    │                       │ │
│  │    └──────────┘      └──────────┘                       │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  Optional Services (Development):                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Mailpit  │  │ Adminer  │  │ Prometheus│                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Service Definitions

#### 2.2.1 Moodle Service (Application Container)

**Purpose:** Web server and PHP application runtime

**Configuration:**
- Base Image: `php:8.3-apache-bookworm` (custom build)
- Alternative: `bitnami/moodle:4.5` (pre-configured)
- Exposed Ports: 8080:80, 8443:443
- Dependencies: database, redis

**Volumes:**
```yaml
volumes:
  - ./moodle:/var/www/html          # Application code (git clone)
  - moodledata:/var/moodledata      # User data, cache, temp files
  - ./moodle-config.php:/var/www/html/config.php  # Configuration
```

**Health Check:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

#### 2.2.2 Database Service (MariaDB)

**Purpose:** Persistent data storage

**Configuration:**
- Image: `mariadb:11`
- Exposed Ports: None (internal only)
- Dependencies: None

**Volumes:**
```yaml
volumes:
  - db_data:/var/lib/mysql          # Database files
  - ./docker/mariadb/custom.cnf:/etc/mysql/conf.d/custom.cnf
```

**Environment Variables:**
```env
MYSQL_ROOT_PASSWORD=<secure-password>
MYSQL_DATABASE=moodle
MYSQL_USER=moodleuser
MYSQL_PASSWORD=<secure-password>
```

#### 2.2.3 Redis Service (Caching & Sessions)

**Purpose:** Application cache and session storage (MUC - Moodle Universal Cache)

**Configuration:**
- Image: `redis:7-alpine`
- Exposed Ports: None (internal only)
- Persistence: Recommended for session storage

**Volumes:**
```yaml
volumes:
  - redis_data:/data
```

**Configuration:**
```conf
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
appendonly yes
requirepass <secure-password>
```

#### 2.2.4 Ofelia Service (Cron Scheduler)

**Purpose:** Execute Moodle cron jobs on schedule

**Configuration:**
- Image: `mcuadros/ofelia:latest`
- Mounts: `/var/run/docker.sock` (Docker API access)

**Moodle Cron Schedule:**
```yaml
labels:
  ofelia.job-exec.moodle-cron.schedule: "@every 1m"
  ofelia.job-exec.moodle-cron.container: "moodle"
  ofelia.job-exec.moodle-cron.command: "php /var/www/html/admin/cli/cron.php"
```

**Alternative: Traditional Cron (in Moodle container)**
```bash
* * * * * php /var/www/html/admin/cli/cron.php >/dev/null 2>&1
```

### 2.3 Network Architecture

**Multi-Network Isolation (Recommended):**

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

**Service Network Assignments:**
- **Moodle:** frontend, backend (bridge between external access and internal services)
- **Database:** backend only (no external access)
- **Redis:** backend only
- **Ofelia:** Access to moodle container via Docker socket

**Security Benefits:**
- Database isolated from external network
- Explicit service communication paths
- Defense in depth architecture

---

## 3. Data Persistence Strategy

### 3.1 Volume Definitions

```yaml
volumes:
  moodledata:
    driver: local
    # Critical: User files, cache, sessions (if not Redis), temp files
    # Size: Typically 10GB-100GB+ depending on usage
    # Backup Priority: CRITICAL

  db_data:
    driver: local
    # Critical: All database files
    # Size: Depends on course content, typically 5GB-50GB
    # Backup Priority: CRITICAL

  redis_data:
    driver: local
    # Cache and session data
    # Size: 512MB-2GB
    # Backup Priority: LOW (can be rebuilt)
```

### 3.2 Moodle Directory Structure

```
/var/www/html/              # Moodle application code
├── admin/                  # Administration scripts
├── auth/                   # Authentication plugins
├── blocks/                 # Block plugins
├── course/                 # Course functionality
├── mod/                    # Activity modules
├── theme/                  # Themes
├── local/                  # Local customizations
├── config.php              # Moodle configuration
└── ...

/var/moodledata/            # Data directory (MUST be outside webroot)
├── cache/                  # MUC cache files
├── filedir/                # User uploaded files (hashed structure)
├── lang/                   # Language packs
├── localcache/             # Local cache
├── sessions/               # PHP sessions (if not using Redis)
├── temp/                   # Temporary files
├── trashdir/               # Deleted files
└── ...
```

### 3.3 File Permissions

**Security Requirements:**
```bash
# Moodle code directory
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod 640 /var/www/html/config.php

# Moodle data directory
chown -R www-data:www-data /var/moodledata
chmod -R 0750 /var/moodledata
```

**Container User:**
- Development: www-data (UID 33) - standard Apache user
- Production: www-data or custom UID mapping
- Bitnami: bitnami user (UID 1001)

---

## 4. Configuration Management

### 4.1 Environment Variables

**Primary Configuration (.env file):**

```env
# Project Configuration
COMPOSE_PROJECT_NAME=moodle45
MOODLE_DOCKER_WEB_PORT=8080
MOODLE_DOCKER_WEB_PORT_SSL=8443

# Moodle Configuration
MOODLE_VERSION=4.5
MOODLE_BRANCH=MOODLE_405_STABLE
MOODLE_SITE_NAME=My Moodle Site
MOODLE_SITE_FULLNAME=My Moodle Learning Platform
MOODLE_ADMIN_USER=admin
MOODLE_ADMIN_PASSWORD=changeme_secure_password_123
MOODLE_ADMIN_EMAIL=admin@example.com
MOODLE_SITE_URL=http://localhost:8080

# Database Configuration
DB_TYPE=mariadb
DB_HOST=database
DB_PORT=3306
DB_NAME=moodle
DB_USER=moodleuser
DB_PASSWORD=secure_db_password_456
DB_ROOT_PASSWORD=secure_root_password_789
DB_PREFIX=mdl_

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=secure_redis_password_012

# PHP Configuration
PHP_MAX_INPUT_VARS=5000
PHP_MEMORY_LIMIT=256M
PHP_UPLOAD_MAX_FILESIZE=100M
PHP_POST_MAX_SIZE=100M
PHP_MAX_EXECUTION_TIME=300

# Mail Configuration (Development - Mailpit)
SMTP_HOST=mailpit
SMTP_PORT=1025
SMTP_USER=
SMTP_PASSWORD=

# Mail Configuration (Production - Real SMTP)
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_USER=noreply@example.com
# SMTP_PASSWORD=smtp_password
# SMTP_SECURITY=tls
```

### 4.2 Moodle Configuration (config.php)

**Template Structure:**

```php
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

// Database Configuration
$CFG->dbtype    = getenv('DB_TYPE') ?: 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('DB_HOST') ?: 'database';
$CFG->dbname    = getenv('DB_NAME') ?: 'moodle';
$CFG->dbuser    = getenv('DB_USER') ?: 'moodleuser';
$CFG->dbpass    = getenv('DB_PASSWORD') ?: '';
$CFG->prefix    = getenv('DB_PREFIX') ?: 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => getenv('DB_PORT') ?: 3306,
    'dbsocket' => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// Site Configuration
$CFG->wwwroot   = getenv('MOODLE_SITE_URL') ?: 'http://localhost:8080';
$CFG->dataroot  = '/var/moodledata';
$CFG->admin     = 'admin';
$CFG->directorypermissions = 0750;

// Session Configuration (Redis)
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = getenv('REDIS_HOST') ?: 'redis';
$CFG->session_redis_port = getenv('REDIS_PORT') ?: 6379;
$CFG->session_redis_auth = getenv('REDIS_PASSWORD') ?: '';
$CFG->session_redis_database = 0;
$CFG->session_redis_acquire_lock_timeout = 120;
$CFG->session_redis_lock_expire = 7200;

// Cache Configuration (MUC - Redis)
// Configured via Moodle admin interface or config array

// Security Settings (Production)
$CFG->forcelogin = false;           // Set true to require login for all pages
$CFG->forceclean = true;            // Clean HTML input
$CFG->cookiesecure = false;         // Set true for HTTPS
$CFG->cookiehttponly = true;        // Prevent XSS
$CFG->preventexecpath = true;       // Prevent execution path manipulation

// Performance Settings
$CFG->enablecaching = true;
$CFG->cachejs = true;
$CFG->yuicomboloading = true;

// Debug Settings (Development only)
// $CFG->debug = (E_ALL | E_STRICT);
// $CFG->debugdisplay = 1;
// @error_reporting(E_ALL | E_STRICT);
// @ini_set('display_errors', '1');

// Production Debug Settings
$CFG->debug = 0;
$CFG->debugdisplay = 0;

require_once(__DIR__ . '/lib/setup.php');
```

### 4.3 Redis MUC Configuration

**Application Cache (via Moodle Admin):**

Path: Site Administration → Plugins → Caching → Configuration

```
Store: Redis
Server: redis:6379
Password: <REDIS_PASSWORD>
Database: 1
Serializer: igbinary (if installed) or PHP
```

---

## 5. Cron Job Strategy

### 5.1 Ofelia Implementation (Recommended)

**Advantages:**
- Docker-native, container-aware
- Dynamic container discovery
- Label-based configuration
- Minimal overhead
- Supports Docker Compose and Swarm

**Docker Compose Configuration:**

```yaml
services:
  ofelia:
    image: mcuadros/ofelia:latest
    container_name: moodle-ofelia
    depends_on:
      - moodle
    command: daemon --docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - backend
    restart: unless-stopped

  moodle:
    # ... other configuration ...
    labels:
      # Run Moodle cron every minute
      ofelia.job-exec.moodle-cron.schedule: "@every 1m"
      ofelia.job-exec.moodle-cron.container: "moodle"
      ofelia.job-exec.moodle-cron.command: "php /var/www/html/admin/cli/cron.php"

      # Alternative: Run every 5 minutes
      # ofelia.job-exec.moodle-cron.schedule: "*/5 * * * *"
```

**Monitoring Cron Execution:**
```bash
# View Ofelia logs
docker compose logs -f ofelia

# Check Moodle cron status
docker compose exec moodle php admin/cli/scheduled_task.php --list
```

### 5.2 Traditional Cron (Alternative)

**In Moodle Container:**

```dockerfile
# Add to Dockerfile
RUN apt-get update && apt-get install -y cron

# Copy cron job
COPY moodle-cron /etc/cron.d/moodle-cron
RUN chmod 0644 /etc/cron.d/moodle-cron && crontab /etc/cron.d/moodle-cron
```

**Cron Job File:**
```
* * * * * www-data php /var/www/html/admin/cli/cron.php >> /var/log/moodle-cron.log 2>&1
```

### 5.3 External Cron (Host-based)

**Via Docker Exec:**
```bash
# Add to host crontab
* * * * * docker compose -f /path/to/docker-compose.yml exec -T moodle php /var/www/html/admin/cli/cron.php >> /var/log/moodle-cron.log 2>&1
```

---

## 6. Backup and Disaster Recovery

### 6.1 Backup Strategy

**What to Backup:**

1. **Database** (CRITICAL - Daily)
   - Full dump: Daily
   - Incremental: Hourly (optional)
   - Retention: 7 daily, 4 weekly, 12 monthly

2. **Moodledata** (CRITICAL - Daily)
   - Method: Incremental backup
   - Challenge: Large size (10GB-100GB+)
   - Retention: 7 daily, 4 weekly

3. **Moodle Code** (MEDIUM - On changes)
   - Git repository (already backed up)
   - Custom plugins/themes: Separate backup
   - Configuration files: .env, config.php

4. **Redis Data** (LOW - Optional)
   - Cache: Can be rebuilt
   - Sessions: Only if critical

### 6.2 Automated Backup Implementation

**Database Backup Script:**

```bash
#!/bin/bash
# docker/scripts/backup-database.sh

BACKUP_DIR="/backups/database"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="${DB_NAME:-moodle}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_ROOT_PASSWORD}"

mkdir -p "$BACKUP_DIR"

# Create backup
docker compose exec -T database mysqldump \
  -u "$DB_USER" \
  -p"$DB_PASSWORD" \
  "$DB_NAME" | gzip > "$BACKUP_DIR/moodle-db-${TIMESTAMP}.sql.gz"

# Cleanup old backups (keep last 7 days)
find "$BACKUP_DIR" -name "moodle-db-*.sql.gz" -mtime +7 -delete

echo "Database backup completed: moodle-db-${TIMESTAMP}.sql.gz"
```

**Moodledata Backup Script:**

```bash
#!/bin/bash
# docker/scripts/backup-moodledata.sh

BACKUP_DIR="/backups/moodledata"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Incremental backup using rsync
docker run --rm \
  -v moodledata:/source:ro \
  -v ./backups/moodledata:/backup \
  alpine:latest \
  sh -c "apk add --no-cache rsync && \
         rsync -av --delete /source/ /backup/current/"

# Create dated snapshot (hardlinks for space efficiency)
docker run --rm \
  -v ./backups/moodledata:/backup \
  alpine:latest \
  cp -al /backup/current "/backup/snapshot-${TIMESTAMP}"

echo "Moodledata backup completed: snapshot-${TIMESTAMP}"
```

**Ofelia-Scheduled Backups:**

```yaml
services:
  backup:
    image: alpine:latest
    volumes:
      - ./docker/scripts:/scripts:ro
      - ./backups:/backups
      - moodledata:/moodledata:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    labels:
      # Database backup: Daily at 2 AM
      ofelia.job-exec.backup-database.schedule: "0 2 * * *"
      ofelia.job-exec.backup-database.command: "/scripts/backup-database.sh"

      # Moodledata backup: Daily at 3 AM
      ofelia.job-exec.backup-moodledata.schedule: "0 3 * * *"
      ofelia.job-exec.backup-moodledata.command: "/scripts/backup-moodledata.sh"
```

### 6.3 Restore Procedures

**Database Restore:**

```bash
#!/bin/bash
# Restore from backup

# Stop Moodle (optional but recommended)
docker compose stop moodle

# Restore database
gunzip < backups/database/moodle-db-20251022_020000.sql.gz | \
  docker compose exec -T database mysql -u root -p"$DB_ROOT_PASSWORD" "$DB_NAME"

# Restart services
docker compose start moodle
```

**Moodledata Restore:**

```bash
# Stop Moodle
docker compose stop moodle

# Restore moodledata volume
docker run --rm \
  -v moodledata:/target \
  -v ./backups/moodledata/snapshot-20251022_030000:/source:ro \
  alpine:latest \
  sh -c "rm -rf /target/* && cp -a /source/. /target/"

# Restart services
docker compose start moodle
```

### 6.4 Disaster Recovery Plan

**Recovery Time Objective (RTO):** < 4 hours
**Recovery Point Objective (RPO):** < 24 hours (daily backups)

**Recovery Steps:**

1. **Prepare Infrastructure**
   - Install Docker and Docker Compose
   - Clone repository with docker-compose.yml
   - Create required directories

2. **Restore Data**
   - Create volumes
   - Restore database from latest backup
   - Restore moodledata from latest backup

3. **Deploy Services**
   - Configure .env with production settings
   - Deploy: `docker compose up -d`
   - Verify all services healthy

4. **Validation**
   - Check web access
   - Test user logins
   - Verify file access
   - Check cron execution
   - Run Moodle health checks

5. **Update DNS** (if applicable)
   - Point domain to new server
   - Update SSL certificates

---

## 7. Security Hardening

### 7.1 Container Security

**Non-Root User:**
```dockerfile
# In Dockerfile
RUN groupadd -r moodle && useradd -r -g moodle moodle
USER moodle
```

**Read-Only Filesystem (where possible):**
```yaml
services:
  moodle:
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=1g
      - /var/run:rw,noexec,nosuid,size=64m
```

**Security Scanning:**
```bash
# Scan images for vulnerabilities
docker scan moodle:4.5

# Or use Trivy
trivy image moodle:4.5
```

### 7.2 Network Security

**Port Binding:**
```yaml
# Development: Bind to localhost only
ports:
  - "127.0.0.1:8080:80"

# Production: Use reverse proxy, no direct exposure
# ports: []  # No ports exposed
```

**Network Isolation:**
```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access
```

### 7.3 Secrets Management

**Docker Secrets (Production):**
```yaml
secrets:
  db_password:
    external: true
  redis_password:
    external: true

services:
  database:
    secrets:
      - db_password
    environment:
      MYSQL_PASSWORD_FILE: /run/secrets/db_password
```

**Create Secrets:**
```bash
echo "secure_password" | docker secret create db_password -
echo "redis_password" | docker secret create redis_password -
```

### 7.4 Application Security

**Moodle config.php Hardening:**
```php
// Force HTTPS
$CFG->sslproxy = true;  // If behind reverse proxy
$CFG->cookiesecure = true;
$CFG->cookiehttponly = true;

// Force login
$CFG->forcelogin = true;

// Disable external RSS feeds (optional)
$CFG->enablerssfeeds = 0;

// Enable security checks
$CFG->forceclean = true;
$CFG->preventexecpath = true;
```

**File Permissions:**
```bash
# Moodle code: Read-only for web server
chmod -R 755 /var/www/html
chmod 640 /var/www/html/config.php

# Moodledata: Write access for web server only
chmod -R 0750 /var/moodledata
chown -R www-data:www-data /var/moodledata
```

### 7.5 SSL/TLS Configuration

**Development (Self-Signed):**
```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./ssl/moodle.key \
  -out ./ssl/moodle.crt
```

**Production (Let's Encrypt via Traefik):**
```yaml
services:
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt

  moodle:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.moodle.rule=Host(`moodle.example.com`)"
      - "traefik.http.routers.moodle.entrypoints=websecure"
      - "traefik.http.routers.moodle.tls.certresolver=letsencrypt"
```

---

## 8. Performance Optimization

### 8.1 Resource Limits

```yaml
services:
  moodle:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    restart: unless-stopped

  database:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    restart: unless-stopped

  redis:
    deploy:
      resources:
        limits:
          memory: 512M
    restart: unless-stopped
```

### 8.2 PHP Optimization

**OPcache Configuration:**
```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
```

**PHP-FPM Configuration (if using FPM):**
```ini
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
```

### 8.3 Moodle Universal Cache (MUC)

**Cache Store Configuration:**

1. **Application Cache → Redis**
   - Stores: Plugin data, language strings, database queries
   - TTL: Variable per cache type

2. **Session Cache → Redis**
   - All user sessions
   - Critical for performance at scale

3. **Request Cache → File**
   - Short-lived, request-scoped data
   - File-based is sufficient

**Configuration via Admin UI:**
```
Site Administration → Plugins → Caching → Configuration
- Add Redis store
- Map application cache to Redis
- Configure session handler in config.php
```

### 8.4 Database Optimization

**Connection Pooling:**
```php
// config.php
$CFG->dboptions = array(
    'dbpersist' => 1,  // Enable persistent connections
    'dbport' => 3306,
    'dbcollation' => 'utf8mb4_unicode_ci',
);
```

**Query Optimization:**
- Enable slow query log for analysis
- Regular OPTIMIZE TABLE on large tables
- Monitor and index frequently queried columns

---

## 9. Monitoring and Observability

### 9.1 Logging Strategy

**Docker Logging:**
```yaml
services:
  moodle:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Centralized Logging (Optional):**
```yaml
services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yaml:/etc/loki/local-config.yaml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log:ro
      - ./promtail-config.yaml:/etc/promtail/config.yaml
    command: -config.file=/etc/promtail/config.yaml
```

### 9.2 Metrics Collection (Production)

**Prometheus Stack:**
```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"

  mysqld-exporter:
    image: prom/mysqld-exporter:latest
    environment:
      - DATA_SOURCE_NAME=exporter:password@(database:3306)/
    ports:
      - "9104:9104"
```

### 9.3 Health Checks

```yaml
services:
  moodle:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  database:
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$DB_ROOT_PASSWORD"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
```

### 9.4 Alerting (Production)

**Prometheus Alertmanager:**
```yaml
# prometheus-alerts.yml
groups:
  - name: moodle
    interval: 30s
    rules:
      - alert: MoodleDown
        expr: up{job="moodle"} == 0
        for: 2m
        annotations:
          summary: "Moodle instance is down"

      - alert: DatabaseDown
        expr: up{job="mysql"} == 0
        for: 1m
        annotations:
          summary: "Database is down"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        annotations:
          summary: "Container using > 90% memory"
```

---

## 10. Development vs Production Environments

### 10.1 Development Environment

**File: compose.dev.yml**

**Characteristics:**
- Xdebug enabled for debugging
- Error display enabled
- Bind mounts for live code editing
- Mailpit for email testing
- Adminer for database management
- Exposed ports on localhost
- Minimal security hardening

**Services:**
- moodle (with Xdebug)
- database (exposed port for local access)
- redis
- mailpit
- adminer
- ofelia (optional)

### 10.2 Production Environment

**File: compose.prod.yml**

**Characteristics:**
- No debug mode
- Error logging only (no display)
- Named volumes (no bind mounts)
- Real SMTP server
- No database GUI
- No exposed ports (reverse proxy)
- Full security hardening
- Resource limits
- Auto-restart policies
- Health checks
- Monitoring stack

**Services:**
- moodle (optimized)
- database (internal only)
- redis (with persistence)
- ofelia (required)
- prometheus
- grafana
- traefik (reverse proxy)

### 10.3 Configuration Overrides

**Development:**
```bash
# Start development environment
docker compose -f compose.yml -f compose.dev.yml up -d
```

**Production:**
```bash
# Start production environment
docker compose -f compose.yml -f compose.prod.yml up -d
```

---

## 11. Deployment and Operations

### 11.1 Initial Deployment

**Prerequisites:**
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
sudo apt-get install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

**Clone Moodle:**
```bash
# Clone Moodle repository
git clone -b MOODLE_405_STABLE --depth 1 git://git.moodle.org/moodle.git
cd moodle
```

**Configure Environment:**
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your settings
nano .env

# Generate secure passwords
openssl rand -base64 32  # For each password field
```

**Deploy Stack:**
```bash
# Development
docker compose -f compose.yml -f compose.dev.yml up -d

# Production
docker compose -f compose.yml -f compose.prod.yml up -d

# Check status
docker compose ps
docker compose logs -f moodle
```

**Initial Setup:**
```bash
# Access Moodle installer
# Development: http://localhost:8080
# Production: https://moodle.example.com

# Or run CLI installer
docker compose exec moodle php admin/cli/install.php \
  --lang=en \
  --wwwroot=http://localhost:8080 \
  --dataroot=/var/moodledata \
  --dbtype=mariadb \
  --dbhost=database \
  --dbname=moodle \
  --dbuser=moodleuser \
  --dbpass=secure_password \
  --prefix=mdl_ \
  --fullname="My Moodle Site" \
  --shortname="Moodle" \
  --adminuser=admin \
  --adminpass=Admin123! \
  --adminemail=admin@example.com \
  --non-interactive \
  --agree-license
```

### 11.2 Upgrade Procedure

**Moodle Version Upgrade:**

```bash
# 1. Enable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --enable

# 2. Backup (CRITICAL)
./docker/scripts/backup-database.sh
./docker/scripts/backup-moodledata.sh

# 3. Update code
cd moodle
git fetch origin
git checkout MOODLE_410_STABLE  # Next version

# 4. Run upgrade
docker compose exec moodle php admin/cli/upgrade.php --non-interactive

# 5. Clear caches
docker compose exec moodle php admin/cli/purge_caches.php

# 6. Disable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --disable

# 7. Verify
curl -I http://localhost:8080
```

**Docker Image Upgrade:**

```bash
# Pull new images
docker compose pull

# Recreate containers
docker compose up -d --force-recreate

# Check logs
docker compose logs -f
```

### 11.3 Scaling Considerations

**Horizontal Scaling (Multiple Moodle Instances):**

```yaml
services:
  moodle:
    deploy:
      replicas: 3  # Multiple instances
    # All instances share:
    # - Same moodledata volume (NFS recommended)
    # - Same database
    # - Same Redis for sessions
```

**Requirements for Scaling:**
- Shared storage (NFS, GlusterFS, or cloud storage)
- Session storage in Redis (not files)
- Load balancer (Traefik, HAProxy, Nginx)
- Sticky sessions or distributed sessions

**Load Balancer Example (Traefik):**
```yaml
services:
  traefik:
    labels:
      - "traefik.http.services.moodle.loadbalancer.sticky.cookie=true"
```

---

## 12. Migration from Existing Installation

### 12.1 Migration Strategy

**Current Setup Analysis:**
- Existing Moodle 4.0.5 (`@MOODLE_405_STABLE`)
- Git clone from official repository
- Existing compose.yml, .env, moodle-config.php
- Existing database and moodledata

**Migration Approach:**

**Option 1: In-Place Upgrade**
- Update Docker Compose files
- Upgrade Moodle code (already at 4.0.5)
- Migrate to new architecture gradually

**Option 2: Side-by-Side Migration (Recommended)**
- Deploy new stack alongside existing
- Migrate data (database + moodledata)
- Test thoroughly
- Switch over when validated
- Keep old stack as fallback

### 12.2 Data Migration Steps

**1. Export Data from Current Setup:**

```bash
# Backup database
docker compose exec database mysqldump -u root -p moodle | gzip > migration_db.sql.gz

# Copy moodledata
docker run --rm \
  -v old_moodledata:/source:ro \
  -v ./migration:/backup \
  alpine tar czf /backup/moodledata.tar.gz -C /source .

# Export custom plugins/themes
tar czf custom_code.tar.gz moodle/local/custom moodle/theme/custom
```

**2. Prepare New Environment:**

```bash
# Create volumes
docker volume create moodle45_moodledata
docker volume create moodle45_db_data

# Start database only
docker compose up -d database
```

**3. Import Data:**

```bash
# Import database
gunzip < migration_db.sql.gz | \
  docker compose exec -T database mysql -u root -p moodle

# Import moodledata
docker run --rm \
  -v moodle45_moodledata:/target \
  -v ./migration:/source:ro \
  alpine tar xzf /source/moodledata.tar.gz -C /target

# Extract custom code
tar xzf custom_code.tar.gz -C moodle/
```

**4. Update Configuration:**

```bash
# Copy and update moodle-config.php
cp old_config.php moodle-config.php

# Update database host to 'database'
# Update wwwroot to new URL
# Update Redis configuration (if using)

# Verify permissions
docker compose exec moodle chown -R www-data:www-data /var/moodledata
```

**5. Start Full Stack:**

```bash
docker compose up -d

# Run upgrade (if needed)
docker compose exec moodle php admin/cli/upgrade.php --non-interactive

# Purge caches
docker compose exec moodle php admin/cli/purge_caches.php
```

**6. Validation:**

```bash
# Check site access
curl -I http://localhost:8080

# Test login
# Verify course content
# Check file uploads
# Verify cron jobs: docker compose logs ofelia
# Test backup/restore
```

### 12.3 Rollback Plan

If migration fails:

```bash
# Stop new stack
docker compose down

# Restart old stack
cd /path/to/old/installation
docker compose up -d

# Restore DNS (if changed)
```

Keep old stack running for 2-4 weeks after successful migration.

---

## 13. Plugin and Theme Management

### 13.1 Plugin Installation Methods

**Method 1: Web Interface (Easiest)**
```
Site Administration → Plugins → Install plugins
→ Upload ZIP file
→ Validate and install
```

**Method 2: Manual Installation**
```bash
# Download plugin
cd moodle/mod  # or blocks/, local/, theme/, etc.
git clone https://github.com/author/moodle-mod_plugin.git pluginname

# Install via CLI
docker compose exec moodle php admin/cli/uninstall_plugins.php --show
docker compose exec moodle php admin/cli/upgrade.php --non-interactive
```

**Method 3: Docker Image (Production)**
```dockerfile
# In Dockerfile
COPY --from=plugins /plugins /var/www/html/local/
RUN chown -R www-data:www-data /var/www/html/local
```

### 13.2 Custom Plugin Management

**Directory Structure:**
```
moodle/
├── local/
│   └── custom/           # Custom local plugins
├── theme/
│   └── mytheme/          # Custom theme
├── mod/
│   └── custommodule/     # Custom activity module
└── blocks/
    └── customblock/      # Custom block
```

**Version Control:**
```bash
# Add custom plugins to separate repo
cd moodle/local/custom
git init
git remote add origin https://github.com/myorg/moodle-custom-plugins.git
```

### 13.3 Plugin Dependencies

Some plugins require additional PHP extensions:

```dockerfile
# Example: If plugin needs GMP extension
RUN docker-php-ext-install gmp

# Example: If plugin needs additional libraries
RUN apt-get update && apt-get install -y \
    libgmp-dev \
    && docker-php-ext-install gmp
```

---

## 14. Testing and Quality Assurance

### 14.1 Automated Testing

**PHPUnit (Moodle Unit Tests):**
```bash
# Initialize test environment
docker compose exec moodle php admin/tool/phpunit/cli/init.php

# Run all tests
docker compose exec moodle vendor/bin/phpunit

# Run specific test
docker compose exec moodle vendor/bin/phpunit --filter test_something
```

**Behat (Acceptance Tests):**
```yaml
# Add Selenium to compose
services:
  selenium:
    image: selenium/standalone-chrome:latest
    ports:
      - "4444:4444"
    shm_size: 2gb
```

```bash
# Initialize Behat
docker compose exec moodle php admin/tool/behat/cli/init.php

# Run Behat tests
docker compose exec moodle vendor/bin/behat --config /var/moodledata/behatdata/behat/behat.yml
```

### 14.2 Integration Testing

**Test Checklist:**

1. **Fresh Installation**
   - Clean database → run installer → verify success
   - Create test course → add content → verify
   - Upload files → verify accessible

2. **Upgrade Path**
   - Backup → upgrade code → run upgrade.php → verify
   - Check for database errors
   - Verify all plugins still function

3. **Backup/Restore**
   - Run backup script → verify files created
   - Destroy environment → restore → verify identical

4. **Performance**
   - Load testing with Apache JMeter or k6
   - Monitor resource usage
   - Check query performance

5. **Security**
   - Run security scanner (OWASP ZAP)
   - Check for open ports: `nmap localhost`
   - Verify SSL/TLS configuration

### 14.3 Smoke Tests (Post-Deployment)

```bash
#!/bin/bash
# smoke-test.sh

# Test web access
echo "Testing web access..."
curl -f http://localhost:8080 || exit 1

# Test database
echo "Testing database..."
docker compose exec database mysql -u root -p"$DB_ROOT_PASSWORD" -e "SHOW DATABASES;" | grep moodle || exit 1

# Test Redis
echo "Testing Redis..."
docker compose exec redis redis-cli ping | grep PONG || exit 1

# Test cron
echo "Checking cron logs..."
docker compose logs ofelia | grep "Job executed" || echo "Warning: No cron executions found"

# Check health
echo "Checking service health..."
docker compose ps | grep "unhealthy" && exit 1

echo "All smoke tests passed!"
```

---

## 15. Maintenance and Operations

### 15.1 Regular Maintenance Tasks

**Daily:**
- Monitor logs for errors
- Check backup completion
- Verify cron execution
- Monitor disk space

**Weekly:**
- Review security logs
- Check for Moodle updates
- Review performance metrics
- Test backup restore procedure

**Monthly:**
- Update Docker images
- Review and optimize database
- Security audit
- Capacity planning review

### 15.2 Common Operations

**View Logs:**
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f moodle

# Last 100 lines
docker compose logs --tail=100 moodle
```

**Execute Commands:**
```bash
# Moodle CLI
docker compose exec moodle php admin/cli/cron.php

# Database access
docker compose exec database mysql -u root -p

# Redis CLI
docker compose exec redis redis-cli
```

**Restart Services:**
```bash
# All services
docker compose restart

# Specific service
docker compose restart moodle

# Recreate (with new image)
docker compose up -d --force-recreate moodle
```

**Update Images:**
```bash
# Pull latest versions
docker compose pull

# Recreate with new images
docker compose up -d
```

### 15.3 Troubleshooting

**Common Issues:**

1. **"Moodle not accessible"**
   ```bash
   # Check container status
   docker compose ps

   # Check logs
   docker compose logs moodle

   # Check health
   docker compose exec moodle curl -f http://localhost/
   ```

2. **"Database connection failed"**
   ```bash
   # Check database running
   docker compose ps database

   # Test connection
   docker compose exec moodle ping -c 3 database

   # Check credentials in .env and config.php match
   ```

3. **"Files not uploading"**
   ```bash
   # Check moodledata permissions
   docker compose exec moodle ls -la /var/moodledata

   # Fix permissions
   docker compose exec moodle chown -R www-data:www-data /var/moodledata
   ```

4. **"Cron not running"**
   ```bash
   # Check Ofelia logs
   docker compose logs ofelia

   # Manually trigger cron
   docker compose exec moodle php admin/cli/cron.php

   # Check scheduled tasks
   docker compose exec moodle php admin/cli/scheduled_task.php --list
   ```

---

## 16. Technical Feasibility Validation

### 16.1 Component Compatibility Matrix

| Component | Version | Moodle 4.5 Support | Status |
|-----------|---------|-------------------|--------|
| PHP | 8.3.x | ✅ Supported (8.1-8.3) | VALIDATED |
| MariaDB | 11.x | ✅ Supported (10.6.7+) | VALIDATED |
| Redis | 7.x | ✅ Supported | VALIDATED |
| Apache | 2.4.x | ✅ Supported | VALIDATED |
| Debian | 12 (Bookworm) | ✅ Supported | VALIDATED |

### 16.2 Performance Validation

**Expected Performance:**
- Page load time: < 2s (typical)
- Concurrent users: 100-500 (single instance)
- File upload: Limited by PHP settings (100MB default)
- Database queries: < 100ms (average)

**Scaling Capacity:**
- Vertical: Up to 16GB RAM, 8 cores per instance
- Horizontal: 3-10 instances with shared storage
- Storage: Unlimited (dependent on volume backend)

### 16.3 Security Validation

**Security Measures Implemented:**
- ✅ Network isolation (multi-network)
- ✅ Non-root containers
- ✅ Secrets management
- ✅ SSL/TLS support
- ✅ Regular security updates
- ✅ Backup encryption (configurable)

### 16.4 Operational Validation

**Deployment Complexity:** Medium
**Maintenance Overhead:** Low-Medium
**Recovery Time:** < 4 hours
**Scalability:** High
**Cost Efficiency:** High (vs managed hosting)

---

## 17. Implementation Roadmap

### Phase 1: Development Environment (Week 1)

- [ ] Create Dockerfile for custom Moodle image
- [ ] Create base docker-compose.yml
- [ ] Create compose.dev.yml with development overrides
- [ ] Configure .env template
- [ ] Test local deployment
- [ ] Document setup process

### Phase 2: Core Services (Week 1-2)

- [ ] Implement MariaDB service with optimization
- [ ] Implement Redis service with persistence
- [ ] Configure Ofelia cron scheduler
- [ ] Implement health checks
- [ ] Test service integration

### Phase 3: Data Management (Week 2)

- [ ] Design volume strategy
- [ ] Implement backup scripts
- [ ] Test backup/restore procedures
- [ ] Document data management

### Phase 4: Production Configuration (Week 3)

- [ ] Create compose.prod.yml
- [ ] Implement security hardening
- [ ] Configure SSL/TLS
- [ ] Implement resource limits
- [ ] Set up monitoring stack

### Phase 5: Migration & Testing (Week 3-4)

- [ ] Develop migration scripts
- [ ] Test migration from existing setup
- [ ] Perform load testing
- [ ] Security audit
- [ ] Create runbooks

### Phase 6: Documentation & Handoff (Week 4)

- [ ] Complete user documentation
- [ ] Create troubleshooting guide
- [ ] Training materials
- [ ] Production deployment
- [ ] Post-deployment support

---

## 18. Success Criteria

### 18.1 Functional Requirements

- ✅ Moodle 4.5 accessible via web browser
- ✅ User authentication working
- ✅ Course creation and content management functional
- ✅ File uploads/downloads working
- ✅ Cron jobs executing on schedule
- ✅ Email notifications working
- ✅ Backup/restore procedures validated

### 18.2 Non-Functional Requirements

- ✅ Page load time < 2s (95th percentile)
- ✅ 99% uptime (production)
- ✅ Recovery time < 4 hours
- ✅ Security audit passed
- ✅ Documentation complete
- ✅ Monitoring operational

### 18.3 Acceptance Criteria

- [ ] Development environment deployed and tested
- [ ] Production environment deployed
- [ ] Migration from existing setup successful
- [ ] All automated tests passing
- [ ] Security review completed
- [ ] Documentation approved
- [ ] Operations team trained

---

## 19. Risks and Mitigations

### 19.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Data loss during migration | Low | Critical | Multi-layer backups, validation |
| Performance degradation | Medium | High | Load testing, monitoring, optimization |
| Security vulnerabilities | Medium | Critical | Regular updates, security scanning |
| Volume permission issues | High | Medium | Clear documentation, validation scripts |
| Cron job failures | Low | Medium | Monitoring, alerting, fallback to traditional cron |

### 19.2 Operational Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Insufficient Docker knowledge | Medium | High | Training, documentation, support |
| Backup failures | Low | Critical | Automated monitoring, test restores |
| Capacity issues | Medium | Medium | Monitoring, capacity planning |
| Update conflicts | Low | Medium | Staging environment, change management |

---

## 20. Appendices

### Appendix A: Quick Reference Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f [service]

# Execute Moodle CLI
docker compose exec moodle php admin/cli/[command].php

# Backup database
docker compose exec database mysqldump -u root -p moodle | gzip > backup.sql.gz

# Restore database
gunzip < backup.sql.gz | docker compose exec -T database mysql -u root -p moodle

# Update images
docker compose pull && docker compose up -d

# Check status
docker compose ps
```

### Appendix B: Directory Structure

```
moodle_docker/
├── docker/
│   ├── moodle/
│   │   └── Dockerfile
│   ├── mariadb/
│   │   └── custom.cnf
│   ├── redis/
│   │   └── redis.conf
│   └── scripts/
│       ├── backup-database.sh
│       ├── backup-moodledata.sh
│       └── restore.sh
├── moodle/                     # Git clone from moodle.org
│   └── (Moodle source code)
├── backups/
│   ├── database/
│   └── moodledata/
├── claudedocs/
│   └── PRD_Moodle_4.5_Docker_Stack.md
├── compose.yml                 # Base configuration
├── compose.dev.yml             # Development overrides
├── compose.prod.yml            # Production overrides
├── .env                        # Environment variables
├── .env.example                # Template
├── moodle-config.php           # Moodle configuration
└── README.md
```

### Appendix C: Environment Variables Reference

See Section 4.1 for complete list.

### Appendix D: Port Reference

| Service | Internal Port | External Port (Dev) | Purpose |
|---------|---------------|---------------------|---------|
| Moodle | 80, 443 | 8080, 8443 | Web access |
| MariaDB | 3306 | - (internal only) | Database |
| Redis | 6379 | - (internal only) | Cache |
| Mailpit | 1025, 8025 | 8025 | Mail testing |
| Adminer | 8080 | 8081 | DB management |
| Prometheus | 9090 | 9090 | Metrics |
| Grafana | 3000 | 3000 | Dashboards |

### Appendix E: Resource Estimates

**Small Installation (< 100 users):**
- Moodle: 1 CPU, 1GB RAM
- Database: 1 CPU, 1GB RAM
- Redis: 256MB RAM
- Total: 2 CPU, 2.25GB RAM, 20GB disk

**Medium Installation (100-1000 users):**
- Moodle: 2 CPU, 2GB RAM
- Database: 2 CPU, 2GB RAM
- Redis: 512MB RAM
- Total: 4 CPU, 4.5GB RAM, 100GB disk

**Large Installation (1000+ users):**
- Moodle: 4+ CPU, 4GB+ RAM (multiple instances)
- Database: 4 CPU, 4GB RAM
- Redis: 1GB RAM
- Total: 8+ CPU, 9GB+ RAM, 500GB+ disk

---

## Document Control

**Version History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Technical Team | Initial PRD creation |

**Review and Approval:**

| Role | Name | Date | Status |
|------|------|------|--------|
| Technical Lead | - | - | Pending |
| DevOps Lead | - | - | Pending |
| Security Lead | - | - | Pending |
| Project Manager | - | - | Pending |

**Next Review Date:** 2025-11-22

---

**End of Document**
