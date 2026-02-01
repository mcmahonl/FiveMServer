# FiveM Racing Server

## Overview

QBCore-based FiveM server with a simple racing mini game featuring vehicle selection.

### Success Criteria
- [ ] Server running on VPS
- [ ] Players can join a race
- [ ] Players can choose their vehicle
- [ ] Race completes with results

---

## Core Feature: Racing

### Flow
1. Player joins lobby
2. Player selects vehicle from menu
3. Race countdown starts
4. Players race through checkpoints
5. First to finish wins

### Vehicle Selection
```lua
Config.Vehicles = {
    { model = 'sultan', label = 'Sultan', class = 'sports' },
    { model = 'banshee', label = 'Banshee', class = 'sports' },
    { model = 'elegy2', label = 'Elegy RH8', class = 'sports' },
    { model = 'comet2', label = 'Comet', class = 'sports' },
}
```

---

## Server Structure
```
FiveMServer/
├── resources/
│   ├── [qb]/              # QBCore framework
│   └── [racing]/
│       └── qb-racing/     # Racing resource
├── server.cfg
└── DESIGN.md
```

---

## Infrastructure

### Tiered Approach (Cost-Effective)

| Phase | Provider | Instance | Cost | Use Case |
|-------|----------|----------|------|----------|
| Dev/Pre-launch | Hetzner Cloud | CX22 (2vCPU/4GB) | ~$5/mo | Development, testing |
| Small community | Hetzner Cloud | CX32 (4vCPU/8GB) | ~$9/mo | Up to 32 players |
| GTA 6 Launch | Hetzner CCX | CCX23 (4vCPU/16GB) | ~$35/mo | Production load |
| High traffic | OVH Game | Dedicated | ~$70/mo | DDoS protection needed |

### Stack
- **OS:** Ubuntu 22.04 LTS
- **Containerization:** Docker + Docker Compose
- **Database:** MariaDB (containerized)
- **FiveM:** txAdmin + FXServer (containerized)
- **Reverse Proxy:** Optional Caddy/nginx for web panel

### Why Docker?
- Same setup works on $5/mo and $500/mo server
- Easy backups (volume snapshots)
- Reproducible environments
- Quick disaster recovery

---

## Quick Start

```bash
# On fresh Ubuntu 22.04 VPS
git clone https://github.com/mcmahonl/FiveMServer.git
cd FiveMServer
chmod +x setup.sh
./setup.sh
```

---

## Roadmap

### Phase 1: Setup
- [x] Initialize repo
- [x] Design infrastructure
- [ ] Set up Hetzner VPS
- [ ] Run setup script
- [ ] Configure FiveM license key

### Phase 2: Racing
- [ ] Vehicle selection menu
- [ ] Checkpoint system
- [ ] Race start/finish logic
- [ ] Results display

---

## Resources
- [QBCore Docs](https://docs.qbcore.org/)
- [FiveM Docs](https://docs.fivem.net/)
