# Moodle 4.5 Docker Stack - Final Architecture Summary

**Version:** 1.0 Final
**Date:** 2025-10-22
**Type:** Simple Production Deployment

---

## Overview

This is a **production-ready, simplified** Docker Compose stack for Moodle 4.5 LMS, designed for skilled teams comfortable with Docker and Linux administration.

### Design Principles

✅ **Simple production** (no development environment complexity)
✅ **Modern stack** (PHP 8.3, MariaDB 11, Valkey 9)
✅ **Docker-native** (Ofelia for cron, multi-network isolation)
✅ **Maintainable** (no unmaintained Bitnami images)
✅ **Externalized concerns** (backups, monitoring handled externally)
✅ **Traefik-ready** (labels included but disabled by default)

---

## Final Stack Components

| Component | Version | Purpose | Critical |
|-----------|---------|---------|----------|
| **Moodle** | 4.5.x | LMS Application | ✅ |
| **PHP** | 8.3 | Application Runtime | ✅ |
| **Apache** | 2.4 | Web Server | ✅ |
| **MariaDB** | 11.x | Database | ✅ |
| **Valkey** | 9.x | Cache + Sessions | ✅ |
| **Ofelia** | latest | Cron Scheduler | ✅ |

---

## Architecture Decisions

### 1. **Image Strategy**
- **Base**: `php:8.3-apache-bookworm` (official PHP image)
- **Approach**: Custom Dockerfile with all required extensions
- **Moodle Code**: Git clone as volume mount (not baked into image)
- **Rationale**: Maximum control, no dependency on unmaintained images

### 2. **Cron Strategy**
- **Choice**: Ofelia (mcuadros/ofelia)
- **Frequency**: Every 1 minute (Moodle requirement)
- **Configuration**: Docker labels on Moodle container
- **Rationale**: Docker-native, cleaner than in-container cron

### 3. **Cache & Sessions**
- **Choice**: Valkey 9 (Redis-compatible)
- **Use Cases**:
  - Database 0: PHP sessions
  - Database 1: Moodle Universal Cache (MUC)
- **Rationale**: Better licensing than Redis, fully compatible

### 4. **Network Architecture**
- **Design**: Multi-network isolation
  - `frontend`: External access (Moodle)
  - `backend`: Internal services (MariaDB, Valkey)
- **Security**: Database and cache not exposed to external network
- **Rationale**: Defense in depth, production best practice

### 5. **SSL/TLS**
- **Strategy**: External Traefik reverse proxy
- **Configuration**: Labels prepared but commented out
- **Initial**: HTTP on port 8080 (enable Traefik when ready)
- **Rationale**: Centralized SSL management, automatic Let's Encrypt

### 6. **Backup Strategy**
- **Decision**: Handled externally (not in Docker stack)
- **Rationale**: Different teams/tools, flexibility in backup solutions
- **Volumes**: Available for backup tooling to mount

### 7. **Monitoring**
- **Decision**: Not included in stack
- **Rationale**: Production monitoring handled by existing infrastructure
- **Health Checks**: Included for container orchestration

---

## Key Features

### ✅ Included

- **Custom PHP 8.3 Dockerfile** with all required extensions
- **Optimized MariaDB config** (InnoDB tuning, UTF8MB4)
- **Optimized Valkey config** (AOF persistence, LRU eviction)
- **Automatic cron execution** (Ofelia every 1 minute)
- **Multi-network isolation** (frontend/backend separation)
- **Health checks** (all services)
- **Traefik labels** (ready to enable)
- **Environment-based config** (.env for all settings)
- **Production-optimized** (OPcache, session handling, security)

### ❌ Excluded (Simplified)

- Development environment configuration
- Separate dev/prod compose files
- Monitoring stack (Prometheus/Grafana)
- Automated backup scripts (handled externally)
- Adminer/PHPMyAdmin
- Mailpit (use production SMTP)
- Multiple environment support

---

## File Structure

```
moodle_docker/
├── docker/
│   ├── moodle/
│   │   └── Dockerfile              # Custom PHP 8.3 + Apache
│   ├── mariadb/
│   │   └── custom.cnf              # Optimized MariaDB config
│   └── valkey/
│       └── valkey.conf             # Optimized Valkey config
├── config/
│   └── moodle-config.php           # Moodle config with Valkey
├── claudedocs/
│   ├── PRD_Moodle_4.5_Docker_Stack.md      # Full requirements
│   └── ARCHITECTURE_SUMMARY.md              # This file
├── compose.yml                     # Single production compose file
├── .env.example                    # Environment template
├── .gitignore                      # Git ignore rules
└── README.md                       # Setup and operations guide
```

---

## Deployment Flow

```
1. Clone Moodle 4.5
   ↓
2. Configure .env (passwords, URLs)
   ↓
3. Build custom image (docker compose build)
   ↓
4. Start stack (docker compose up -d)
   ↓
5. Install Moodle (web or CLI)
   ↓
6. Configure Valkey MUC (admin UI)
   ↓
7. [Optional] Enable Traefik (uncomment labels)
   ↓
8. Production ready!
```

---

## Technical Specifications

### PHP Extensions Installed

**Core Required:**
- sodium (Moodle 4.5 requirement)
- mysqli, pdo_mysql, pgsql, pdo_pgsql
- gd (with FreeType, JPEG)
- xml, xmlrpc, soap
- intl, mbstring
- zip, bz2
- bcmath
- opcache

**System & Networking:**
- pcntl, sockets
- sysvmsg, sysvsem, sysvshm
- ldap

**Performance:**
- redis (PECL 6.0.2)
- apcu (PECL 5.1.23)
- igbinary (PECL 3.2.15)

### PHP Configuration

```ini
memory_limit = 256M
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
max_input_vars = 5000          # Moodle 4.5 minimum
opcache.memory_consumption = 256
```

### MariaDB Configuration

```ini
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb_buffer_pool_size = 1G   # Adjust based on RAM
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1
max_connections = 200
```

### Valkey Configuration

```conf
maxmemory 512mb                # Adjust based on needs
maxmemory-policy allkeys-lru
appendonly yes                 # AOF persistence
save 900 1                     # RDB snapshots
requirepass <secure-password>
databases 16                   # 0=sessions, 1=MUC
```

---

## Environment Variables

**Critical Settings (`.env`):**

```env
# Project
COMPOSE_PROJECT_NAME=moodle45

# Web ports
MOODLE_DOCKER_WEB_PORT=8080
MOODLE_DOCKER_WEB_PORT_SSL=8443

# Site
MOODLE_SITE_URL=http://localhost:8080

# Database
DB_PASSWORD=<generate-secure-32-char>
DB_ROOT_PASSWORD=<generate-secure-32-char>

# Valkey
VALKEY_PASSWORD=<generate-secure-32-char>
```

---

## Resource Requirements

### Minimum (Small Installation < 100 users)
- CPU: 2 cores
- RAM: 4GB
- Disk: 50GB

### Recommended (Medium Installation 100-1000 users)
- CPU: 4 cores
- RAM: 8GB
- Disk: 100GB

### Large Installation (1000+ users)
- CPU: 8+ cores
- RAM: 16GB+
- Disk: 500GB+
- Consider horizontal scaling

---

## Security Features

✅ Multi-network isolation (backend services not exposed)
✅ No root user in containers (www-data)
✅ Health checks enabled
✅ Secrets via environment variables
✅ Dangerous Valkey commands disabled (FLUSHDB, CONFIG)
✅ Traefik-ready for automatic SSL
✅ Cookie security configured (httponly, secure when HTTPS)
✅ Apache hardening (ServerTokens Prod, indexes disabled)

---

## Operations

### Essential Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Logs
docker compose logs -f [service]

# Moodle cron (manual)
docker compose exec moodle php admin/cli/cron.php

# Database backup
docker compose exec database mysqldump -u root -p moodle | gzip > backup.sql.gz

# Purge caches
docker compose exec moodle php admin/cli/purge_caches.php
```

---

## Migration Notes

**From existing Moodle 4.0.5 setup:**

1. Export database and moodledata
2. Deploy new stack
3. Import data to new volumes
4. Update config.php paths
5. Run upgrade if needed
6. Test thoroughly
7. Switch DNS/proxy when validated

**Important:** `MOODLE_405_STABLE` = Moodle 4.5.x (not 4.0.5)

---

## Maintenance

### Regular Tasks
- **Daily**: Check logs, verify cron execution
- **Weekly**: Review disk space, check for Moodle updates
- **Monthly**: Update Docker images, security review

### Upgrade Path
1. Maintenance mode ON
2. Backup database
3. Update Moodle code (git checkout)
4. Run upgrade CLI
5. Purge caches
6. Maintenance mode OFF

---

## Success Criteria

✅ Moodle 4.5 running on PHP 8.3
✅ MariaDB 11 with optimized configuration
✅ Valkey 9 handling sessions + cache
✅ Ofelia executing cron every 1 minute
✅ Multi-network security isolation
✅ Traefik-ready (labels prepared)
✅ No development complexity
✅ No unmaintained images
✅ Simple, maintainable, production-ready

---

## Constraints & Trade-offs

### What We Simplified
- ❌ Separate dev environment (production only)
- ❌ Built-in monitoring (use existing infrastructure)
- ❌ Automated backups (handled externally)
- ❌ Multiple compose file complexity

### What We Optimized For
- ✅ Production reliability
- ✅ Operational simplicity
- ✅ Team expertise (skilled with Docker/Linux)
- ✅ Modern stack (latest stable versions)
- ✅ Maintainability (no deprecated dependencies)

---

## Next Steps (Post-Deployment)

1. **Enable Traefik** (uncomment labels, update config)
2. **Configure backups** (external tooling)
3. **Add monitoring** (integrate with existing stack)
4. **Performance tuning** (based on actual usage)
5. **Security hardening** (firewall rules, fail2ban)
6. **Scale if needed** (horizontal scaling with shared storage)

---

**End of Architecture Summary**
