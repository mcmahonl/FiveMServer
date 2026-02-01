# FiveM Racing Server

A QBCore-based FiveM server featuring racing mini games with vehicle selection. Dockerized for easy deployment on any VPS.

## Quick Start

### 1. Provision a VPS
- [Hetzner Cloud](https://www.hetzner.com/cloud) - CX22 (~$5/mo) recommended for dev
- Ubuntu 22.04 LTS
- Note the IP address

### 2. Get a FiveM License Key
- Go to https://keymaster.fivem.net/
- Register/login with Cfx.re account
- Generate a key for your server IP

### 3. Deploy
```bash
# SSH into your server
ssh root@YOUR_SERVER_IP

# Clone and setup
git clone https://github.com/mcmahonl/FiveMServer.git
cd FiveMServer
chmod +x setup.sh
./setup.sh

# Edit config with your license key
nano .env

# Start the server
docker compose up -d
```

### 4. Access
- **txAdmin Panel:** http://YOUR_SERVER_IP:40120
- **FiveM Connect:** YOUR_SERVER_IP:30120

## Project Structure

```
FiveMServer/
├── docker-compose.yml    # Container orchestration
├── setup.sh              # One-click VPS setup
├── .env.example          # Environment template
├── server-data/          # FiveM config (auto-created)
├── DESIGN.md             # Architecture docs
└── README.md
```

## Commands

```bash
# Start server
docker compose up -d

# Stop server
docker compose down

# View logs
docker compose logs -f

# Restart
docker compose restart

# Update FiveM
docker compose pull && docker compose up -d
```

## Documentation

See [DESIGN.md](DESIGN.md) for full architecture, roadmap, and scaling strategy.

## License

MIT
