# Moodle 4.5 Docker Stack - Quick Start Guide

**Production-ready deployment in 10 minutes**

---

## Prerequisites Check

```bash
# Verify Docker
docker --version  # Need 20.10.15+

# Verify Docker Compose
docker compose version  # Need V2.5.0+

# Verify Git
git --version
```

---

## Step-by-Step Deployment

### 1. Clone Moodle (5 min)

```bash
# Clone Moodle 4.5 stable branch
git clone -b MOODLE_405_STABLE --depth 1 git://git.moodle.org/moodle.git

# Verify
cd moodle && git branch && cd ..
# Should show: * MOODLE_405_STABLE
```

### 2. Configure Environment (2 min)

```bash
# Copy template
cp .env.example .env

# Generate three secure passwords
openssl rand -base64 32  # Copy for DB_PASSWORD
openssl rand -base64 32  # Copy for DB_ROOT_PASSWORD
openssl rand -base64 32  # Copy for VALKEY_PASSWORD

# Edit .env and paste passwords
nano .env
```

**Required changes in `.env`:**
```env
DB_PASSWORD=<paste-first-password>
DB_ROOT_PASSWORD=<paste-second-password>
VALKEY_PASSWORD=<paste-third-password>

# For production, also change:
MOODLE_SITE_URL=https://moodle.example.com
```

Save and exit (Ctrl+X, Y, Enter)

### 3. Deploy Stack (2 min)

```bash
# Build custom Moodle image
docker compose build

# Start all services
docker compose up -d

# Verify all services running
docker compose ps
```

**Expected output:**
```
NAME                     STATUS
moodle45_moodle          Up (healthy)
moodle45_database        Up (healthy)
moodle45_valkey          Up (healthy)
moodle45_ofelia          Up
```

### 4. Install Moodle (1 min)

Open browser: `http://localhost:8080`

**Or use CLI installer:**

```bash
docker compose exec moodle php admin/cli/install.php \
  --lang=en \
  --wwwroot=http://localhost:8080 \
  --dataroot=/var/moodledata \
  --dbtype=mariadb \
  --dbhost=database \
  --dbname=moodle \
  --dbuser=moodleuser \
  --dbpass=<YOUR_DB_PASSWORD> \
  --prefix=mdl_ \
  --fullname="My Moodle Site" \
  --shortname="Moodle" \
  --adminuser=admin \
  --adminpass=Admin123! \
  --adminemail=admin@example.com \
  --non-interactive \
  --agree-license
```

---

## Post-Installation: Configure Valkey Cache

**Why?** 10x faster than file cache for production.

1. Login to Moodle as admin
2. Go to: **Site Administration → Plugins → Caching → Configuration**
3. Click **Add instance** (under Redis section)
4. Configure:
   - Server: `valkey:6379`
   - Password: `<YOUR_VALKEY_PASSWORD from .env>`
   - Database: `1`
5. Click **Save**
6. Map **Application** cache to Valkey store

✅ **Done!** Moodle is now production-ready.

---

## Verification Checklist

```bash
# Web access works
curl -I http://localhost:8080
# Should return: HTTP/1.1 200 OK

# Cron is running
docker compose logs ofelia
# Should see: "Job executed successfully"

# Database is accessible
docker compose exec moodle php admin/cli/cron.php
# Should complete without errors

# Valkey is working
docker compose exec valkey valkey-cli -a <YOUR_VALKEY_PASSWORD> PING
# Should return: PONG
```

---

## Common Next Steps

### Enable Traefik (Production SSL)

1. Edit `compose.yml`
2. Uncomment Traefik labels under `moodle` service
3. Change domain to yours:
   ```yaml
   traefik.http.routers.moodle.rule: "Host(`moodle.example.com`)"
   ```
4. Update `.env`: `MOODLE_SITE_URL=https://moodle.example.com`
5. Update `config/moodle-config.php`:
   ```php
   $CFG->cookiesecure = true;
   $CFG->sslproxy = true;
   ```
6. Restart: `docker compose up -d`

### Increase Performance (Optional)

For larger installations, edit `compose.yml`:

```yaml
services:
  moodle:
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 4G
```

Then: `docker compose up -d`

---

## Troubleshooting

**Problem:** Container not starting
```bash
docker compose logs <service-name>
```

**Problem:** Database connection failed
```bash
# Check .env passwords match
cat .env | grep PASSWORD

# Test database connection
docker compose exec moodle ping database
```

**Problem:** Out of memory
```bash
# Check usage
docker stats

# Increase in docker/moodle/Dockerfile:
# memory_limit = 512M
# Then rebuild: docker compose build moodle && docker compose up -d
```

---

## Essential Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f moodle

# Moodle cron (manual)
docker compose exec moodle php admin/cli/cron.php

# Enable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --enable

# Disable maintenance mode
docker compose exec moodle php admin/cli/maintenance.php --disable

# Database backup
docker compose exec database mysqldump -u root -p moodle | gzip > backup-$(date +%Y%m%d).sql.gz
```

---

## What's Running?

| Service | Purpose | Port | Access |
|---------|---------|------|--------|
| Moodle | Web application | 8080 | http://localhost:8080 |
| MariaDB | Database | - | Internal only |
| Valkey | Cache + Sessions | - | Internal only |
| Ofelia | Cron scheduler | - | Logs only |

---

## Support

- **Full documentation**: See `README.md`
- **Architecture details**: See `claudedocs/ARCHITECTURE_SUMMARY.md`
- **Complete PRD**: See `claudedocs/PRD_Moodle_4.5_Docker_Stack.md`
- **Moodle docs**: https://docs.moodle.org/405/en/

---

**Deployment complete! 🚀**
