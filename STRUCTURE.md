# Project Structure

## Overview

```
FiveMServer/
├── docker-compose.yml          # Container config
├── .env                        # License key (not in git)
├── .env.example
├── server.cfg.example          # Base server config
├── README.md                   # User documentation
├── STRUCTURE.md                # This file
└── server-data/                # FiveM server data (cloned from cfx-server-data)
    ├── server.cfg              # Active server config
    └── resources/
        └── [minigames]/        # Custom minigames
            └── offense-defense/
```

## Minigame Architecture

Each minigame follows this modular structure:

```
[minigames]/offense-defense/
├── fxmanifest.lua              # Resource manifest
├── config.lua                  # All configuration (vehicles, teams, admins, settings)
├── shared/
│   └── utils.lua               # Shared utility functions
├── server/
│   └── main.lua                # Server-side logic (state, commands, events)
├── client/
│   ├── main.lua                # Client-side logic (UI, vehicles, gameplay)
│   └── editor.lua              # Race editor (admin only)
├── html/
│   ├── index.html              # NUI markup
│   ├── style.css               # NUI styles
│   └── script.js               # NUI logic
└── maps/
    └── *.json                  # Saved race maps
```

## Key Files

### config.lua
Central configuration for the minigame:
- `Config.Admins` - List of admin identifiers
- `Config.Teams` - Team names, colors
- `Config.Vehicles` - Runner/Blocker vehicles
- `Config.Settings` - Gameplay settings

### server/main.lua
Server-side game state and logic:
- `GameState` - Current phase, players, teams
- `OnlinePlayers` - Connected players with roles
- Permission checks (`IsAdmin()`)
- Lobby management
- Race start/end logic

### client/main.lua
Client-side rendering and interaction:
- NUI communication
- Vehicle spawning
- Checkpoint detection
- Race countdown

### client/editor.lua
Race track editor (admin only):
- Checkpoint placement
- Spawn point configuration
- Map saving to JSON

### html/
NUI overlays:
- Online players bar (always visible)
- Lobby UI (team selection, car selection, ready up)
- Race countdown (3-2-1-GO)
- Editor panel

## Adding a New Minigame

1. Create folder: `server-data/resources/[minigames]/new-game/`
2. Copy structure from offense-defense
3. Update `fxmanifest.lua` with new name
4. Add `ensure new-game` to `server.cfg`
5. Register `/join newgame` command

## State Flow

```
IDLE → LOBBY → COUNTDOWN → RACING → END → IDLE
         ↑                            │
         └────────────────────────────┘
```

1. **IDLE** - No active game, announcements broadcast
2. **LOBBY** - Players join, select cars, ready up
3. **COUNTDOWN** - All ready, 30s lobby countdown
4. **RACING** - Teleport to grid, 5s race countdown, GO
5. **END** - Winner announced, cleanup, return to IDLE

## Permission System

```lua
-- config.lua
Config.Admins = {
    'mcmahonl',     -- By player name
    'steam:xxxxx',  -- By identifier
}

-- Roles
admin: canEdit, canForceStart, canStop
player: canJoin
```

## NUI Communication

```
Server → Client: TriggerClientEvent('od:eventName', playerId, data)
Client → NUI:    SendNUIMessage({ type = 'eventType', ... })
NUI → Client:    RegisterNUICallback('callbackName', function)
Client → Server: TriggerServerEvent('od:eventName', data)
```

## Map Format (JSON)

```json
{
    "name": "airport-sprint",
    "checkpoints": [
        { "x": -1600.0, "y": -2714.0, "z": 13.9 },
        { "x": -1750.0, "y": -2920.0, "z": 13.9 }
    ],
    "lobbySpawn": { "x": -1037.0, "y": -2962.0, "z": 13.9, "w": 60.0 },
    "startGrid": { "x": -1497.0, "y": -2595.0, "z": 13.9, "w": 240.0 }
}
```

## Development Commands

```bash
# SSH to server
ssh -i ~/.ssh/id_ed25519 root@5.78.177.239

# Edit file on server
nano /opt/FiveMServer/server-data/resources/[minigames]/offense-defense/config.lua

# Restart to apply changes
cd /opt/FiveMServer && docker compose restart

# Watch logs
docker logs -f fivem-server

# Copy file to local
scp -i ~/.ssh/id_ed25519 root@5.78.177.239:/opt/FiveMServer/path/file ~/Desktop/FiveMServer/
```

## Future Additions

- [ ] Points/scoring system
- [ ] Persistent player stats
- [ ] More minigames (Sumo, Slasher, etc.)
- [ ] Map voting
- [ ] Spectator mode
