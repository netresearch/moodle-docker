# Moodle 5.2 Quick Start

Get Moodle running in under 5 minutes.

---

## Prerequisites

- **Docker** 20.10.15 or later
- **Docker Compose** v2.5.0 or later

```bash
# Verify installation
docker --version
docker compose version
```

---

## Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/netresearch/moodle-docker.git
cd moodle-docker
```

### 2. Configure environment

```bash
# Copy the example configuration
cp .env.example .env

# Generate secure passwords and update .env
# Replace the CHANGE_ME values with secure passwords:
nano .env
```

**Required changes in `.env`:**
```env
DB_PASSWORD=<secure-password>
DB_ROOT_PASSWORD=<secure-password>
VALKEY_PASSWORD=<secure-password>
```

> **Tip:** Generate secure passwords with: `openssl rand -base64 32`

### 3. Start Moodle

```bash
docker compose up -d
```

> **Note:** The sources ship in the image; first startup only copies them into
> the code volume. Watch progress with: `docker compose logs -f moodle`

### 4. Access Moodle

Open your browser: **http://localhost**

Follow the on-screen installation wizard to complete setup.

---

## Development Profile

For development, start with the `dev` profile to include Mailpit (email catcher):

```bash
docker compose --profile dev up -d
```

Access Mailpit at: **http://localhost/mailpit/**

All emails sent by Moodle will be captured there instead of being delivered.

---

## Upgrading Moodle

To upgrade to a new Moodle version:

1. Edit `.env` and change `MOODLE_VERSION`:
   ```env
   MOODLE_VERSION=5.2.4
   ```

2. Rebuild the image and restart the stack. The sources ship inside the image,
   so a rebuild is required — without it the container refuses to start:
   ```bash
   docker compose build moodle moodle-cron
   docker compose up -d
   ```

The new version will be downloaded automatically.

---

## Common Commands

```bash
# View logs
docker compose logs -f moodle

# Restart all services
docker compose restart

# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v
```

---

## What's Running?

| Service  | Purpose           | Access              |
|----------|-------------------|---------------------|
| nginx    | Web server        | http://localhost    |
| moodle   | PHP-FPM app       | (internal)          |
| database | MariaDB 11.8      | (internal)          |
| valkey   | Cache & sessions  | (internal)          |
| ofelia   | Cron scheduler    | (internal)          |
| mailpit  | Mail catcher (dev)| http://localhost/mailpit/ |

---

## Next Steps

- See `README.md` for full documentation
- Configure SSL with a reverse proxy for production
- Customize via environment variables in `.env`
