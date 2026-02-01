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

### VPS (Minimum)
- 2 CPU cores
- 4 GB RAM
- Ubuntu 22.04

### Software
- FiveM server artifacts
- QBCore
- txAdmin
- MariaDB

---

## Roadmap

### Phase 1: Setup
- [ ] Initialize repo
- [ ] Set up VPS
- [ ] Install FiveM + QBCore

### Phase 2: Racing
- [ ] Vehicle selection menu
- [ ] Checkpoint system
- [ ] Race start/finish logic
- [ ] Results display

---

## Resources
- [QBCore Docs](https://docs.qbcore.org/)
- [FiveM Docs](https://docs.fivem.net/)
