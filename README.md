# FiveM Server

Dockerized FiveM server with custom minigames.

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

# Create server.cfg
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

## Minigames

### Offense Defense
2-team race mode (Green vs Purple). Each team has 1 Runner + up to 3 Blockers.

**Player Commands:**
| Command | Description |
|---------|-------------|
| `/join od` | Join game (auto-assigns team) |

**Admin Commands:**
| Command | Description |
|---------|-------------|
| `/odedit <mapname>` | Start race editor |
| `/odstart` | Force start game |
| `/odstop` | Stop current game |

**Roles:**
- **Runner** - Drives Voodoo, collects checkpoints, first to finish wins
- **Blocker** - Drives Insurgent/Kuruma/Zentorno, protects Runner, blocks enemies

**Race Editor (Admins):**
| Key | Action |
|-----|--------|
| `E` | Add checkpoint |
| `X` | Remove last checkpoint |
| `L` | Set lobby spawn |
| `G` | Set start grid |
| `F5` | Save map |
| `ESC` | Exit editor |

## Server Management

```bash
cd /opt/FiveMServer

docker logs -f fivem-server     # View logs
docker compose restart          # Restart after changes
docker compose down             # Stop
docker compose pull && docker compose up -d  # Update
```

## Permissions

Configured in `server-data/resources/[minigames]/offense-defense/config.lua`:

```lua
Config.Admins = {
    'mcmahonl',
}
```

Admins can: edit races, force start/stop games
Players can: join games

## File Locations

| Path | Purpose |
|------|---------|
| `server-data/server.cfg` | Server config |
| `server-data/resources/[minigames]/` | Custom minigames |
| `.env` | License key |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 30120 | TCP/UDP | Game |
| 40120 | TCP | txAdmin |

## Development Workflow

Development happens directly on the production server. To sync changes back to GitHub:

```bash
# From local machine - copy changed files
scp -i ~/.ssh/id_ed25519 root@5.78.177.239:/opt/FiveMServer/path/to/file ~/Desktop/FiveMServer/

# Commit and push
cd ~/Desktop/FiveMServer
git add .
git commit -m "Description of changes"
git push origin main
```

For architecture details, see [STRUCTURE.md](STRUCTURE.md).

## Agent Notes

For Claude Code sessions:
- **Server IP:** 5.78.177.239
- **SSH:** `ssh -i ~/.ssh/id_ed25519 root@5.78.177.239`
- **Server path:** `/opt/FiveMServer/`
- **Logs:** `docker logs -f fivem-server`
- **Restart:** `cd /opt/FiveMServer && docker compose restart`
- Edit directly on server, sync to local, push to GitHub
- See [STRUCTURE.md](STRUCTURE.md) for codebase architecture

## License

MIT
