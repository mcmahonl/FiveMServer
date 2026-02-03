Local = {
    inLobby = false,
    inRace = false,
    inEditor = false,
    team = nil,
    role = nil,
    previewVehicle = nil,
    raceVehicle = nil,
    freeRoamVehicle = nil,
    currentCheckpoint = 1,
    mapData = nil,
    respawnHoldStart = 0,
    showingGamePlayers = false,
    lastCheckpointPos = nil,
}

-- Major road spawn points around Los Santos
RoadSpawns = {
    vector4(-1037.0, -2733.0, 20.0, 240.0),   -- Airport
    vector4(137.0, -1063.0, 29.0, 0.0),       -- Legion Square
    vector4(-538.0, -254.0, 35.0, 180.0),     -- Rockford Hills
    vector4(1137.0, -983.0, 46.0, 90.0),      -- Mirror Park
    vector4(-74.0, -818.0, 44.0, 340.0),      -- Downtown Vinewood
    vector4(295.0, -578.0, 43.0, 70.0),       -- Pillbox Hill
    vector4(-1221.0, -334.0, 37.0, 220.0),    -- Del Perro
    vector4(810.0, -491.0, 30.0, 90.0),       -- La Mesa
    vector4(-212.0, -1326.0, 31.0, 0.0),      -- Strawberry
    vector4(1172.0, -1714.0, 35.0, 0.0),      -- El Burro Heights
}

-- Random cars for free roam spawning
RandomCars = {
    'sultan', 'elegy2', 'comet2', 'buffalo', 'kuruma',
    'zentorno', 'turismor', 'massacro', 'jester', 'banshee'
}

-- NUI Callbacks
RegisterNUICallback('ready', function(_, cb) TriggerServerEvent('od:ready') cb('ok') end)
RegisterNUICallback('leave', function(_, cb) TriggerServerEvent('od:leave') cb('ok') end)
RegisterNUICallback('selectCar', function(data, cb)
    TriggerServerEvent('od:selectCar', data.car)
    UpdatePreviewVehicle(data.car)
    cb('ok')
end)
RegisterNUICallback('editorExit', function(_, cb) ExitEditor() cb('ok') end)
RegisterNUICallback('switchTeam', function(data, cb) TriggerServerEvent('od:switchTeam', data.team) cb('ok') end)
RegisterNUICallback('switchRole', function(data, cb) TriggerServerEvent('od:switchRole', data.role) cb('ok') end)

-- Online players update
RegisterNetEvent('od:updateOnline', function(players)
    SendNUIMessage({ type = 'updateOnlinePlayers', players = players })
end)

-- Join lobby
RegisterNetEvent('od:joinLobby', function(team, role, slotIndex, mapData)
    Local.inLobby = true
    Local.team = team
    Local.role = role
    Local.mapData = mapData

    -- Get spawn from loaded map or use defaults
    local spawn = GetLobbySpawn(team, slotIndex)
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    FreezeEntityPosition(ped, true)
    
    SpawnPreviewVehicle(role, team, spawn)
    
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'showLobby', team = team, role = role })
end)

RegisterNetEvent('od:leaveLobby', function()
    Local.inLobby = false
    FreezeEntityPosition(PlayerPedId(), false)
    DeletePreviewVehicle()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideLobby' })
    SpawnAtRandomRoad(true)
end)

-- Calculate heading from one point to another
function GetHeadingToPoint(from, to)
    local dx = to.x - from.x
    local dy = to.y - from.y
    local heading = math.deg(math.atan(dx, dy))
    if heading < 0 then heading = heading + 360 end
    return heading
end

function SpawnAtRandomRoad(withCar)
    local spawn = RoadSpawns[math.random(#RoadSpawns)]
    local ped = PlayerPedId()

    -- Delete any existing free roam vehicle
    if Local.freeRoamVehicle and DoesEntityExist(Local.freeRoamVehicle) then
        DeleteVehicle(Local.freeRoamVehicle)
        Local.freeRoamVehicle = nil
    end

    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)

    if withCar then
        local model = RandomCars[math.random(#RandomCars)]
        local hash = GetHashKey(model)
        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end
        if HasModelLoaded(hash) then
            Local.freeRoamVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
            SetPedIntoVehicle(ped, Local.freeRoamVehicle, -1)
            SetVehicleOnGroundProperly(Local.freeRoamVehicle)
            SetModelAsNoLongerNeeded(hash)
        end
    end
end

-- Initial spawn when player joins server
AddEventHandler('playerSpawned', function()
    Wait(1000)
    if not Local.inLobby and not Local.inRace and not Local.inEditor then
        SpawnAtRandomRoad(true)
    end
end)

RegisterNetEvent('od:updatePlayer', function(team, role, slotIndex)
    Local.team = team
    Local.role = role
    DeletePreviewVehicle()
    local spawn = GetLobbySpawn(team, slotIndex)
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    SpawnPreviewVehicle(role, team, spawn)
    SendNUIMessage({ type = 'showLobby', team = team, role = role })
end)

RegisterNetEvent('od:updateLobby', function(green, purple)
    SendNUIMessage({ type = 'updateLobby', players = { green = green, purple = purple } })
end)

RegisterNetEvent('od:lobbyCountdown', function(seconds)
    SendNUIMessage({ type = 'updateTimer', time = seconds, label = 'STARTING' })
    PlaySoundFrontend(-1, 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
end)

RegisterNetEvent('od:updatePot', function(pot, wager, teamSize)
    SendNUIMessage({ type = 'updatePot', pot = pot, wager = wager, teamSize = teamSize or 1 })
end)

RegisterNetEvent('od:showResults', function(data)
    SendNUIMessage({ type = 'showResults', data = data })
    if data.won then
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', false)
    else
        PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', false)
    end
end)

-- Start race
RegisterNetEvent('od:startRace', function(team, slotIndex, vehicleModel, role, mapData)
    Local.inLobby = false
    Local.inRace = true
    Local.team = team
    Local.role = role
    Local.currentCheckpoint = 1
    Local.mapData = mapData
    Local.showingGamePlayers = false

    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideLobby' })
    DeletePreviewVehicle()

    local spawn = GetRaceSpawn(team, slotIndex)
    -- Store spawn as initial respawn point
    Local.lastCheckpointPos = spawn
    SpawnRaceVehicle(vehicleModel, spawn)
    
    -- Freeze for countdown
    FreezeEntityPosition(Local.raceVehicle, true)
    
    -- Race countdown
    CreateThread(function()
        for i = Config.Settings.raceCountdown, 1, -1 do
            SendNUIMessage({ type = 'showRaceCountdown', number = tostring(i), text = '' })
            PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', false)
            Wait(1000)
        end
        SendNUIMessage({ type = 'showRaceCountdown', number = 'GO', text = '' })
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', false)
        FreezeEntityPosition(Local.raceVehicle, false)
        Wait(1000)
        SendNUIMessage({ type = 'hideRaceCountdown' })
        SendNUIMessage({ type = 'showRaceHud' })
    end)
end)

RegisterNetEvent('od:endRace', function()
    Local.inRace = false
    Local.lastCheckpointPos = nil
    Local.showingGamePlayers = false
    DeleteRaceVehicle()
    SendNUIMessage({ type = 'hideRaceCountdown' })
    SendNUIMessage({ type = 'hideRaceHud' })
    SendNUIMessage({ type = 'hideRespawnProgress' })
    SendNUIMessage({ type = 'setPlayersTitle', title = 'ONLINE' })
    SpawnAtRandomRoad(true)
end)

RegisterNetEvent('od:updatePositions', function(positions)
    Local.positions = positions
end)

-- Spawns (with fallback defaults)
function GetLobbySpawn(team, slot)
    -- Use map data if available
    if Local.mapData and Local.mapData.lobbySpawn then
        local base = Local.mapData.lobbySpawn
        local spacing = Config.Settings.spawnSpacing
        local offset = (slot - 1) * spacing
        -- Team 1 on left, Team 2 on right
        local sideOffset = team == 1 and -10 or 10
        return vector4(base.x + sideOffset, base.y - offset, base.z, base.w + (team == 1 and 0 or 180))
    end

    -- Fallback defaults
    local defaults = {
        [1] = {
            vector4(-1047.0, -2972.0, 13.9, 60.0),
            vector4(-1047.0, -2978.0, 13.9, 60.0),
            vector4(-1047.0, -2984.0, 13.9, 60.0),
            vector4(-1047.0, -2990.0, 13.9, 60.0),
        },
        [2] = {
            vector4(-1027.0, -2972.0, 13.9, 120.0),
            vector4(-1027.0, -2978.0, 13.9, 120.0),
            vector4(-1027.0, -2984.0, 13.9, 120.0),
            vector4(-1027.0, -2990.0, 13.9, 120.0),
        }
    }
    return defaults[team][slot] or defaults[team][1]
end

function GetRaceSpawn(team, slot)
    -- Use map data if available
    if Local.mapData and Local.mapData.startGrid then
        local base = Local.mapData.startGrid
        local spacing = Config.Settings.spawnSpacing
        local offset = (slot - 1) * spacing
        -- Team 1 in front, Team 2 behind
        local rowOffset = team == 1 and 0 or 8
        return vector4(base.x - offset * 0.7, base.y - offset * 0.7 - rowOffset, base.z, base.w)
    end

    -- Fallback defaults
    local defaults = {
        [1] = {
            vector4(-1497.0, -2595.0, 13.9, 240.0),
            vector4(-1505.0, -2590.0, 13.9, 240.0),
            vector4(-1513.0, -2585.0, 13.9, 240.0),
            vector4(-1521.0, -2580.0, 13.9, 240.0),
        },
        [2] = {
            vector4(-1493.0, -2602.0, 13.9, 240.0),
            vector4(-1501.0, -2607.0, 13.9, 240.0),
            vector4(-1509.0, -2612.0, 13.9, 240.0),
            vector4(-1517.0, -2617.0, 13.9, 240.0),
        }
    }
    return defaults[team][slot] or defaults[team][1]
end

function GetCheckpoints()
    -- Use map data if available
    if Local.mapData and Local.mapData.checkpoints and #Local.mapData.checkpoints > 0 then
        local cps = {}
        for _, cp in ipairs(Local.mapData.checkpoints) do
            table.insert(cps, vector3(cp.x, cp.y, cp.z))
        end
        return cps
    end

    -- Fallback defaults
    return {
        vector3(-1600.0, -2714.0, 13.9),
        vector3(-1750.0, -2920.0, 13.9),
        vector3(-1850.0, -3100.0, 13.9),
        vector3(-1950.0, -3300.0, 13.9),
    }
end

-- Vehicle spawning
function SpawnPreviewVehicle(role, team, spawn)
    DeletePreviewVehicle()
    local model = role == 'runner' and Config.Vehicles.runner.model or Config.Vehicles.blocker[1].model
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
    
    local offset = vector3(3.5, 0.0, 0.0)
    Local.previewVehicle = CreateVehicle(hash, spawn.x + offset.x, spawn.y + offset.y, spawn.z, spawn.w + 90.0, false, false)
    SetEntityAsMissionEntity(Local.previewVehicle, true, true)
    FreezeEntityPosition(Local.previewVehicle, true)
    
    local color = Config.Teams[team].color
    SetVehicleCustomPrimaryColour(Local.previewVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(Local.previewVehicle, color.r, color.g, color.b)
    SetModelAsNoLongerNeeded(hash)
end

function UpdatePreviewVehicle(carIndex)
    if Local.role == 'runner' or not Local.previewVehicle then return end
    local spawn = GetLobbySpawn(Local.team, 1)
    DeletePreviewVehicle()
    
    local model = Config.Vehicles.blocker[carIndex].model
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
    
    Local.previewVehicle = CreateVehicle(hash, spawn.x + 3.5, spawn.y, spawn.z, spawn.w + 90.0, false, false)
    SetEntityAsMissionEntity(Local.previewVehicle, true, true)
    FreezeEntityPosition(Local.previewVehicle, true)
    
    local color = Config.Teams[Local.team].color
    SetVehicleCustomPrimaryColour(Local.previewVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(Local.previewVehicle, color.r, color.g, color.b)
    SetModelAsNoLongerNeeded(hash)
end

function DeletePreviewVehicle()
    if Local.previewVehicle then
        if DoesEntityExist(Local.previewVehicle) then
            SetEntityAsMissionEntity(Local.previewVehicle, false, true)
            DeleteVehicle(Local.previewVehicle)
            DeleteEntity(Local.previewVehicle)
        end
        Local.previewVehicle = nil
    end
end

function DeleteRaceVehicle()
    if Local.raceVehicle then
        if DoesEntityExist(Local.raceVehicle) then
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == Local.raceVehicle then
                TaskLeaveVehicle(ped, Local.raceVehicle, 16)
                Wait(500)
            end
            SetEntityAsMissionEntity(Local.raceVehicle, false, true)
            DeleteVehicle(Local.raceVehicle)
            DeleteEntity(Local.raceVehicle)
        end
        Local.raceVehicle = nil
    end
end

function SpawnRaceVehicle(model, spawn)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
    
    Local.raceVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetEntityAsMissionEntity(Local.raceVehicle, true, true)
    
    local color = Config.Teams[Local.team].color
    SetVehicleCustomPrimaryColour(Local.raceVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(Local.raceVehicle, color.r, color.g, color.b)
    
    FreezeEntityPosition(PlayerPedId(), false)
    SetPedIntoVehicle(PlayerPedId(), Local.raceVehicle, -1)
    SetModelAsNoLongerNeeded(hash)
end

-- Checkpoint logic and HUD updates
CreateThread(function()
    while true do
        Wait(100)
        if Local.inRace then
            local checkpoints = GetCheckpoints()
            local cp = checkpoints[Local.currentCheckpoint]
            local dist = 0

            if cp then
                dist = math.floor(#(GetEntityCoords(PlayerPedId()) - cp))
            end

            -- Update HUD
            SendNUIMessage({
                type = 'updateRaceHud',
                checkpoint = Local.currentCheckpoint - 1,
                totalCheckpoints = #checkpoints,
                distance = dist,
                positions = Local.positions or {}
            })

            -- Runner checkpoint detection
            if Local.role == 'runner' and cp then
                if dist < Config.Settings.checkpointRadius then
                    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                    TriggerServerEvent('od:checkpointReached', Local.currentCheckpoint, #checkpoints)
                    -- Store this checkpoint position for respawn
                    Local.lastCheckpointPos = cp
                    Local.currentCheckpoint = Local.currentCheckpoint + 1
                end
                -- Send progress to server for position tracking
                TriggerServerEvent('od:updateProgress', Local.currentCheckpoint, dist)
            end
        end
    end
end)

-- Draw checkpoints
CreateThread(function()
    while true do
        Wait(0)
        if Local.inRace and Local.role == 'runner' then
            local checkpoints = GetCheckpoints()
            local cp = checkpoints[Local.currentCheckpoint]
            if cp then
                local color = Config.Teams[Local.team].color
                DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0, 0, 0, 0, 0, 0,
                    Config.Settings.checkpointRadius * 2, Config.Settings.checkpointRadius * 2, 3.0,
                    color.r, color.g, color.b, 150, false, false, 2, false, nil, nil, false)
            end
        end
    end
end)

-- Hold E to respawn at last checkpoint
CreateThread(function()
    local holdTime = 3000 -- 3 seconds in ms
    while true do
        Wait(0)
        if Local.inRace then
            -- E key is control 38
            if IsControlPressed(0, 38) then
                if Local.respawnHoldStart == 0 then
                    Local.respawnHoldStart = GetGameTimer()
                end

                local elapsed = GetGameTimer() - Local.respawnHoldStart
                local progress = math.min(100, (elapsed / holdTime) * 100)
                SendNUIMessage({ type = 'showRespawnProgress', progress = progress })

                if elapsed >= holdTime then
                    -- Respawn at last checkpoint or start position
                    Local.respawnHoldStart = 0
                    SendNUIMessage({ type = 'hideRespawnProgress' })

                    local respawnPos = Local.lastCheckpointPos
                    if not respawnPos then
                        -- Use start grid position if no checkpoint reached yet
                        respawnPos = GetRaceSpawn(Local.team, 1)
                    end

                    if Local.raceVehicle and DoesEntityExist(Local.raceVehicle) then
                        SetEntityCoords(Local.raceVehicle, respawnPos.x, respawnPos.y, respawnPos.z + 1.0, false, false, false, true)
                        -- Calculate heading towards next checkpoint
                        local checkpoints = GetCheckpoints()
                        local nextCp = checkpoints[Local.currentCheckpoint]
                        if nextCp then
                            local heading = GetHeadingToPoint(respawnPos, nextCp)
                            SetEntityHeading(Local.raceVehicle, heading)
                        elseif respawnPos.w then
                            SetEntityHeading(Local.raceVehicle, respawnPos.w)
                        end
                        SetVehicleOnGroundProperly(Local.raceVehicle)
                        SetVehicleEngineOn(Local.raceVehicle, true, true, false)
                        -- Reset vehicle damage
                        SetVehicleFixed(Local.raceVehicle)
                        SetVehicleDeformationFixed(Local.raceVehicle)
                    end
                    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                    Wait(500) -- Brief cooldown
                end
            else
                if Local.respawnHoldStart > 0 then
                    Local.respawnHoldStart = 0
                    SendNUIMessage({ type = 'hideRespawnProgress' })
                end
            end
        else
            if Local.respawnHoldStart > 0 then
                Local.respawnHoldStart = 0
                SendNUIMessage({ type = 'hideRespawnProgress' })
            end
            Wait(100)
        end
    end
end)

-- Tab to toggle players list (online vs game players)
CreateThread(function()
    local tabPressed = false
    while true do
        Wait(0)
        if Local.inRace then
            -- Tab is control 37
            if IsControlJustPressed(0, 37) and not tabPressed then
                tabPressed = true
                Local.showingGamePlayers = not Local.showingGamePlayers
                if Local.showingGamePlayers then
                    SendNUIMessage({ type = 'setPlayersTitle', title = 'IN GAME' })
                    TriggerServerEvent('od:requestGamePlayers')
                else
                    SendNUIMessage({ type = 'setPlayersTitle', title = 'ONLINE' })
                    TriggerServerEvent('od:requestOnlinePlayers')
                end
            elseif not IsControlPressed(0, 37) then
                tabPressed = false
            end
        else
            Wait(100)
        end
    end
end)

-- Listen for game players update
RegisterNetEvent('od:updateGamePlayers', function(players)
    if Local.showingGamePlayers then
        SendNUIMessage({ type = 'updateOnlinePlayers', players = players })
    end
end)

-- NUI callback for joining game from browser
RegisterNUICallback('joinGame', function(data, cb)
    if data.game == 'od' then
        TriggerServerEvent('od:joinFromBrowser')
    end
    cb('ok')
end)

-- Minigames browser update
RegisterNetEvent('od:updateMinigames', function(games)
    SendNUIMessage({ type = 'updateMinigames', games = games })
end)

-- Request minigames state on resource start
CreateThread(function()
    Wait(1000)
    TriggerServerEvent('od:requestMinigames')
end)

-- Register J key for joining minigame
RegisterCommand('+joinminigame', function()
    if not Local.inLobby and not Local.inRace and not Local.inEditor then
        TriggerServerEvent('od:joinFromBrowser')
    end
end, false)
RegisterCommand('-joinminigame', function() end, false)
RegisterKeyMapping('+joinminigame', 'Join Minigame', 'keyboard', 'j')

-- Disable traffic and peds near player during lobby/race
CreateThread(function()
    while true do
        Wait(500)
        if Local.inLobby or Local.inRace then
            local pos = GetEntityCoords(PlayerPedId())
            -- Clear area of vehicles and peds
            ClearAreaOfVehicles(pos.x, pos.y, pos.z, 100.0, false, false, false, false, false)
            ClearAreaOfPeds(pos.x, pos.y, pos.z, 100.0, true)
            -- Disable vehicle and ped spawning
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetPedDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        end
    end
end)
