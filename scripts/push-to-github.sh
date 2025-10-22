#!/bin/bash
# Helper script to push Moodle Docker stack to GitHub
# Usage: ./scripts/push-to-github.sh [repository-name]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default repository name
REPO_NAME="${1:-moodle-docker}"
ORG="netresearch"
REPO_URL="git@github.com:${ORG}/${REPO_NAME}.git"

echo -e "${GREEN}=== Moodle Docker Stack - GitHub Push Helper ===${NC}\n"

# Check if we're in the right directory
if [ ! -f "compose.yml" ]; then
    echo -e "${RED}Error: compose.yml not found. Run this script from the project root.${NC}"
    exit 1
fi

# Check if .env exists (should NOT be committed)
if [ -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file exists. It will NOT be committed (in .gitignore).${NC}"
    echo -e "${YELLOW}Make sure you have .env.example instead.${NC}"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if moodle directory exists (should NOT be committed)
if [ -d "moodle" ]; then
    echo -e "${YELLOW}Warning: moodle/ directory exists. It will NOT be committed (in .gitignore).${NC}"
    echo -e "${YELLOW}This is correct - users should clone Moodle separately.${NC}"
fi

# Initialize git if not already done
if [ ! -d ".git" ]; then
    echo -e "${GREEN}Initializing git repository...${NC}"
    git init
    git branch -M main
else
    echo -e "${GREEN}Git repository already initialized.${NC}"
fi

# Show what will be committed
echo -e "\n${GREEN}Files to be committed:${NC}"
git add -n . | head -20
echo "... (showing first 20 files)"

echo -e "\n${YELLOW}Ready to commit and push to: ${REPO_URL}${NC}"
echo -e "${YELLOW}Repository: https://github.com/${ORG}/${REPO_NAME}${NC}\n"

read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 1
fi

# Add all files (respecting .gitignore)
echo -e "\n${GREEN}Adding files...${NC}"
git add .

# Create commit
echo -e "\n${GREEN}Creating commit...${NC}"
git commit -m "Initial commit: Moodle 4.5 Docker Compose stack

Stack Components:
- Moodle 4.5 (MOODLE_405_STABLE)
- PHP 8.3 + Apache (custom Dockerfile)
- MariaDB 11 (optimized configuration)
- Valkey 9 (Redis-compatible cache + sessions)
- Ofelia (Docker-native cron scheduler)

Architecture:
- Multi-network isolation (frontend/backend)
- Production-focused deployment
- Traefik-ready with SSL labels
- No unmaintained Bitnami images

Features:
- All required PHP extensions (sodium, opcache, redis, etc.)
- Optimized MariaDB config (InnoDB tuning, UTF8MB4)
- Optimized Valkey config (AOF persistence, LRU eviction)
- Automatic cron execution (every 1 minute)
- Health checks on all services
- Environment-based configuration

Documentation:
- README.md: Complete setup and operations guide
- QUICKSTART.md: 10-minute deployment guide
- claudedocs/ARCHITECTURE_SUMMARY.md: Architecture decisions
- claudedocs/PRD_Moodle_4.5_Docker_Stack.md: Full requirements

Deployment:
1. Clone Moodle: git clone -b MOODLE_405_STABLE git://git.moodle.org/moodle.git
2. Configure: cp .env.example .env (set passwords)
3. Deploy: docker compose build && docker compose up -d
4. Install: http://localhost:8080
5. Configure Valkey MUC cache (optional but recommended)

Production ready for skilled teams comfortable with Docker and Linux."

# Add remote
echo -e "\n${GREEN}Adding remote origin...${NC}"
if git remote | grep -q '^origin$'; then
    echo -e "${YELLOW}Remote 'origin' already exists. Updating URL...${NC}"
    git remote set-url origin "${REPO_URL}"
else
    git remote add origin "${REPO_URL}"
fi

# Show remote
git remote -v

# Push
echo -e "\n${GREEN}Pushing to GitHub...${NC}"
echo -e "${YELLOW}Note: This requires SSH key access to github.com/netresearch/${NC}\n"

git push -u origin main

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}=== SUCCESS ===${NC}"
    echo -e "${GREEN}Repository pushed to: https://github.com/${ORG}/${REPO_NAME}${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo -e "1. Visit https://github.com/${ORG}/${REPO_NAME}"
    echo -e "2. Add repository description"
    echo -e "3. Add topics: moodle, docker, php, mariadb, valkey, lms"
    echo -e "4. Configure branch protection (if needed)"
    echo -e "5. Share with team\n"
else
    echo -e "\n${RED}=== PUSH FAILED ===${NC}"
    echo -e "${YELLOW}Possible issues:${NC}"
    echo -e "1. Repository doesn't exist on GitHub (create it first)"
    echo -e "2. No SSH key access to netresearch organization"
    echo -e "3. Network/connectivity issues"
    echo -e "\n${YELLOW}To create repository manually:${NC}"
    echo -e "Visit: https://github.com/organizations/netresearch/repositories/new"
    echo -e "Name: ${REPO_NAME}"
    echo -e "Then run this script again.\n"
    exit 1
fi
