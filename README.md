# FiveM Server

Dockerized FiveM server for easy VPS deployment.

## Quick Start

### 1. Provision a VPS
- [Hetzner Cloud](https://www.hetzner.com/cloud) - CX22 (~$5/mo) recommended
- Ubuntu 24.04 LTS
- Add your SSH key during setup

### 2. Get a FiveM License Key
- Go to https://keymaster.fivem.net/
- Login with Cfx.re account
- Generate a key for your server IP

### 3. Deploy

```bash
ssh root@YOUR_SERVER_IP

# Install Docker
curl -fsSL https://get.docker.com | sh

# Clone repo
git clone https://github.com/mcmahonl/FiveMServer.git /opt/FiveMServer
cd /opt/FiveMServer

# Clone official FiveM server data
git clone https://github.com/citizenfx/cfx-server-data.git server-data

# Create server.cfg (or copy server.cfg.example)
cp server.cfg.example server-data/server.cfg

# Set license key
cp .env.example .env
nano .env  # add your license key

# Start
docker compose up -d
```

### 4. Connect
```
connect YOUR_SERVER_IP:30120
```

## Server Management

```bash
cd /opt/FiveMServer

docker logs -f fivem-server     # View logs
docker compose restart          # Restart after changes
docker compose down             # Stop
docker compose pull && docker compose up -d  # Update
```

## File Locations

| Path | Purpose |
|------|---------|
| `server-data/server.cfg` | Server config |
| `server-data/resources/` | Add resources here |
| `.env` | License key |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 30120 | TCP/UDP | Game |
| 40120 | TCP | txAdmin |

## Development Workflow

Development happens directly on the production server for fast iteration. To sync changes back to GitHub:

### 1. Copy changes from server to local
```bash
# From local machine
scp -i ~/.ssh/id_ed25519 root@5.78.177.239:/opt/FiveMServer/docker-compose.yml ~/Desktop/FiveMServer/
scp -i ~/.ssh/id_ed25519 root@5.78.177.239:/opt/FiveMServer/server-data/server.cfg ~/Desktop/FiveMServer/server.cfg.example
# Add other modified files as needed
```

### 2. Commit and push
```bash
cd ~/Desktop/FiveMServer
git add .
git commit -m "Description of changes"
git push origin main
```

### 3. For larger changes, create a PR
```bash
git checkout -b feature/my-feature
git add .
git commit -m "Description"
git push -u origin feature/my-feature
gh pr create --title "My feature" --body "Description"
```

## Agent Notes

For Claude Code sessions working on this project:
- **Server IP:** 5.78.177.239
- **SSH:** `ssh -i ~/.ssh/id_ed25519 root@5.78.177.239`
- **Server path:** `/opt/FiveMServer/`
- **Logs:** `docker logs -f fivem-server`
- **Restart:** `cd /opt/FiveMServer && docker compose restart`
- Edit directly on server, then sync to local and push to GitHub

## License

MIT
