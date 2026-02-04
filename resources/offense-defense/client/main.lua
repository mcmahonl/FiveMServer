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
    -- Lamborghini
    'svj63', 'veneno', 'urus', 'lp700r', 'huracanst', 'lambose',
    -- Ferrari
    'laferrari', 'fxxk', 'f812', '488', 'mig',
    -- McLaren
    'senna', '720s', 'mcst', '675lt', 'gtr96',
    -- Koenigsegg
    'agerars', 'regera',
    -- Bugatti
    'bolide',
    -- Porsche
    'taycan', 'cgt',
    -- Other hypercars
    'lykan', 'wmfenyr', 'tr22'
}

-- Modern car colors for hypercars
HypercarColors = {
    { name = 'Ice White', paint = 3, r = 255, g = 255, b = 255 },           -- Matte white
    { name = 'Murdered Out', paint = 3, r = 15, g = 15, b = 15 },           -- Matte black
    { name = 'Matte Forest Green', paint = 3, r = 34, g = 85, b = 51 },     -- Matte forest green
    { name = 'Midnight Purple', paint = 3, r = 75, g = 0, b = 130 },        -- Matte purple
    { name = 'Matte Gray', paint = 3, r = 80, g = 80, b = 80 },             -- Matte gray
    { name = 'Nardo Gray', paint = 3, r = 140, g = 140, b = 140 },          -- Nardo gray
    { name = 'Racing Red', paint = 1, r = 200, g = 25, b = 25 },            -- Metallic red
    { name = 'Electric Blue', paint = 1, r = 0, g = 100, b = 255 },         -- Metallic blue
    { name = 'British Racing Green', paint = 1, r = 0, g = 66, b = 37 },    -- Metallic BRG
    { name = 'Miami Blue', paint = 1, r = 0, g = 180, b = 225 },            -- Metallic Miami blue
    { name = 'Lava Orange', paint = 1, r = 255, g = 90, b = 0 },            -- Metallic orange
    { name = 'Chrome', paint = 4, r = 255, g = 255, b = 255 },              -- Chrome
}

function ApplyRandomHypercarColor(vehicle)
    local color = HypercarColors[math.random(#HypercarColors)]
    
    -- Set paint type (0=normal, 1=metallic, 2=pearl, 3=matte, 4=metal/chrome)
    SetVehicleModKit(vehicle, 0)
    
    if color.paint == 4 then
        -- Chrome
        SetVehicleColours(vehicle, 120, 120) -- Chrome color index
    else
        SetVehicleModColor_1(vehicle, color.paint, 0, 0)
        SetVehicleModColor_2(vehicle, color.paint, 0)
        SetVehicleCustomPrimaryColour(vehicle, color.r, color.g, color.b)
        SetVehicleCustomSecondaryColour(vehicle, color.r, color.g, color.b)
    end
    
    -- Black out trim for murdered out look
    SetVehicleExtraColours(vehicle, 0, 0) -- Pearlescent black, wheel color black
end
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
    GiveAllWeapons()
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

    -- Find nearest road node to get a safe spawn point
    local foundRoad, roadPos, roadHeading = GetClosestVehicleNodeWithHeading(spawn.x, spawn.y, spawn.z, 1, 3.0, 0)
    
    local finalX, finalY, finalZ, finalHeading
    if foundRoad then
        finalX, finalY, finalZ = roadPos.x, roadPos.y, roadPos.z
        finalHeading = roadHeading
    else
        -- Fallback to original coords
        finalX, finalY, finalZ = spawn.x, spawn.y, spawn.z
        finalHeading = spawn.w
    end

    -- Request collision at the spawn location
    RequestCollisionAtCoord(finalX, finalY, finalZ)
    Wait(500)

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
            -- Create vehicle first, then place on ground
            Local.freeRoamVehicle = CreateVehicle(hash, finalX, finalY, finalZ + 2.0, finalHeading, true, false)
            SetVehicleOnGroundProperly(Local.freeRoamVehicle)
            SetEntityHeading(Local.freeRoamVehicle, finalHeading)
            SetPedIntoVehicle(ped, Local.freeRoamVehicle, -1)
            SetModelAsNoLongerNeeded(hash)
            
            -- Extra safety: make sure vehicle is right-side up
            SetEntityRotation(Local.freeRoamVehicle, 0.0, 0.0, finalHeading, 2, true)
            PlaceObjectOnGroundProperly(Local.freeRoamVehicle)
            -- Apply random hypercar color
            ApplyRandomHypercarColor(Local.freeRoamVehicle)
        end
    else
        SetEntityCoords(ped, finalX, finalY, finalZ + 1.0, false, false, false, true)
        SetEntityHeading(ped, finalHeading)
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
    GiveAllWeapons()
end)

RegisterNetEvent('od:updateLobby', function(green, purple)
    SendNUIMessage({ type = 'updateLobby', players = { green = green, purple = purple } })
end)

RegisterNetEvent('od:lobbyCountdown', function(seconds)
    SendNUIMessage({ type = 'updateTimer', time = seconds, label = 'STARTING' })
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end)

RegisterNetEvent('od:updatePot', function(pot, wager, teamSize)
    SendNUIMessage({ type = 'updatePot', pot = pot, wager = wager, teamSize = teamSize or 1 })
end)

RegisterNetEvent('od:showResults', function(data)
    SendNUIMessage({ type = 'showResults', data = data })
    if data.won then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    else
        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
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
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            Wait(1000)
        end
        SendNUIMessage({ type = 'showRaceCountdown', number = 'GO', text = '' })
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        FreezeEntityPosition(Local.raceVehicle, false)
        GiveAllWeapons()
        Wait(1000)
        SendNUIMessage({ type = 'hideRaceCountdown' })
        SendNUIMessage({ type = 'showRaceHud' })
    end)
end)

RegisterNetEvent('od:endRace', function()
    Local.inRace = false
    ClearAllPlayerBlips()
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
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerServerEvent('od:checkpointReached', Local.currentCheckpoint, #checkpoints)
                    -- Store this checkpoint position for respawn
                    Local.lastCheckpointPos = cp
                    Local.currentCheckpoint = Local.currentCheckpoint + 1
                    -- Show final checkpoint notification if next is last
                    if Local.currentCheckpoint == #checkpoints then
                        SendNUIMessage({ type = 'showFinalCheckpoint' })
                    end
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
                local isLastCheckpoint = Local.currentCheckpoint == #checkpoints
                
                if isLastCheckpoint then
                    -- Finish line - checkered flag marker (type 4)
                    DrawMarker(4, cp.x, cp.y, cp.z + 2.0, 0, 0, 0, 0, 0, 0,
                        2.0, 2.0, 2.0,
                        255, 255, 255, 200, true, false, 2, true, nil, nil, false)
                    -- Also draw a gold cylinder underneath
                    DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0, 0, 0, 0, 0, 0,
                        Config.Settings.checkpointRadius * 2, Config.Settings.checkpointRadius * 2, 3.0,
                        255, 215, 0, 180, false, false, 2, false, nil, nil, false)
                else
                    -- Regular checkpoint
                    DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0, 0, 0, 0, 0, 0,
                        Config.Settings.checkpointRadius * 2, Config.Settings.checkpointRadius * 2, 3.0,
                        color.r, color.g, color.b, 150, false, false, 2, false, nil, nil, false)
                end
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
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
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

-- Disable traffic and peds near player during lobby only
CreateThread(function()
    while true do
        Wait(500)
        if Local.inLobby then
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

-- Player blips for minimap
PlayerBlips = {}

-- Blip sprites: Runner = race flag, Blocker = shield
local BLIP_SPRITE_RUNNER = 309  -- Race finish flag
local BLIP_SPRITE_BLOCKER = 304 -- Shield/helmet

-- Create or update a player blip
function UpdatePlayerBlip(playerId, team, role)
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then return end
    
    -- Remove existing blip for this player
    if PlayerBlips[playerId] then
        RemoveBlip(PlayerBlips[playerId])
        PlayerBlips[playerId] = nil
    end
    
    -- Don't create blip for local player
    if playerId == PlayerId() then return end
    
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, role == 'runner' and BLIP_SPRITE_RUNNER or BLIP_SPRITE_BLOCKER)
    SetBlipColour(blip, Config.Teams[team].blipColor)
    SetBlipScale(blip, role == 'runner' and 1.0 or 0.8)
    SetBlipAsShortRange(blip, false)
    
    -- Show on minimap
    SetBlipDisplay(blip, 2)
    
    PlayerBlips[playerId] = blip
end

-- Remove all player blips
function ClearAllPlayerBlips()
    for playerId, blip in pairs(PlayerBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    PlayerBlips = {}
end

-- Receive player data from server and update blips
RegisterNetEvent('od:updatePlayerBlips', function(players)
    if not Local.inRace then
        ClearAllPlayerBlips()
        return
    end
    
    -- Track which players we've seen this update
    local seenPlayers = {}
    
    for _, data in ipairs(players) do
        local playerId = GetPlayerFromServerId(data.serverId)
        if playerId ~= -1 then
            UpdatePlayerBlip(playerId, data.team, data.role)
            seenPlayers[playerId] = true
        end
    end
    
    -- Remove blips for players no longer in the list
    for playerId, blip in pairs(PlayerBlips) do
        if not seenPlayers[playerId] then
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
            PlayerBlips[playerId] = nil
        end
    end
end)

-- Clear blips when race ends (hook into existing endRace)

-- Give all weapons to player
function GiveAllWeapons()
    local ped = PlayerPedId()
    local weapons = {
        -- Pistols
        'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL',
        'WEAPON_STUNGUN', 'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_HEAVYPISTOL',
        'WEAPON_VINTAGEPISTOL', 'WEAPON_FLAREGUN', 'WEAPON_MARKSMANPISTOL',
        'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION', 'WEAPON_CERAMICPISTOL',
        -- SMGs
        'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG',
        'WEAPON_COMBATPDW', 'WEAPON_MACHINEPISTOL', 'WEAPON_MINISMG', 'WEAPON_RAYCARBINE',
        -- Shotguns
        'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN',
        'WEAPON_ASSAULTSHOTGUN', 'WEAPON_BULLPUPSHOTGUN', 'WEAPON_MUSKET',
        'WEAPON_HEAVYSHOTGUN', 'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN', 'WEAPON_COMBATSHOTGUN',
        -- Assault Rifles
        'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE',
        'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE',
        'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE', 'WEAPON_BULLPUPRIFLE_MK2',
        'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE', 'WEAPON_TACTICALRIFLE',
        -- Machine Guns
        'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_GUSENBERG',
        -- Sniper Rifles
        'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2',
        'WEAPON_MARKSMANRIFLE', 'WEAPON_MARKSMANRIFLE_MK2',
        -- Heavy Weapons
        'WEAPON_RPG', 'WEAPON_GRENADELAUNCHER', 'WEAPON_MINIGUN', 'WEAPON_FIREWORK',
        'WEAPON_RAILGUN', 'WEAPON_HOMINGLAUNCHER', 'WEAPON_COMPACTLAUNCHER', 'WEAPON_RAYMINIGUN',
        -- Throwables
        'WEAPON_GRENADE', 'WEAPON_BZGAS', 'WEAPON_SMOKEGRENADE', 'WEAPON_FLARE',
        'WEAPON_MOLOTOV', 'WEAPON_STICKYBOMB', 'WEAPON_PROXMINE', 'WEAPON_SNOWBALL',
        'WEAPON_PIPEBOMB', 'WEAPON_BALL',
        -- Melee
        'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT',
        'WEAPON_GOLFCLUB', 'WEAPON_CROWBAR', 'WEAPON_BOTTLE', 'WEAPON_SWITCHBLADE',
        'WEAPON_DAGGER', 'WEAPON_HATCHET', 'WEAPON_MACHETE', 'WEAPON_FLASHLIGHT',
        'WEAPON_KNUCKLE', 'WEAPON_POOLCUE', 'WEAPON_WRENCH', 'WEAPON_BATTLEAXE', 'WEAPON_STONE_HATCHET',
    }
    
    for _, weapon in ipairs(weapons) do
        local hash = GetHashKey(weapon)
        GiveWeaponToPed(ped, hash, 9999, false, false)
    end
end

-- Teleport to player event
RegisterNetEvent('od:teleportTo', function(x, y, z)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        SetEntityCoords(vehicle, x, y, z + 1.0, false, false, false, true)
        SetVehicleOnGroundProperly(vehicle)
    else
        SetEntityCoords(ped, x, y, z + 1.0, false, false, false, true)
    end
end)

-- Debug command to give weapons
RegisterCommand('giveweapons', function()
    print('[OD] Giving all weapons...')
    GiveAllWeapons()
    print('[OD] Done giving weapons')
end, false)

-- Car HUD - shows vehicle name and speed
CreateThread(function()
    local wasInVehicle = false
    while true do
        Wait(100) -- Update 10 times per second
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            -- Player is driving a vehicle
            if not wasInVehicle then
                SendNUIMessage({ type = 'showCarHud' })
                wasInVehicle = true
            end
            
            -- Get vehicle display name
            local model = GetEntityModel(vehicle)
            local displayName = GetDisplayNameFromVehicleModel(model)
            local makeName = GetMakeNameFromVehicleModel(model)
            local labelName = GetLabelText(displayName)
            
            -- For addon cars, use the text entry directly
            if labelName == "NULL" or labelName == displayName then
                labelName = GetLabelText(displayName:lower())
            end
            if labelName == "NULL" or labelName == displayName:lower() then
                labelName = displayName:upper()
            end
            
            -- Add make name if available
            local makeLabelName = GetLabelText(makeName)
            if makeLabelName ~= "NULL" and makeLabelName ~= "" then
                labelName = makeLabelName .. " " .. labelName
            end
            
            -- Get speed in MPH (game uses m/s, multiply by 2.236936 for mph)
            local speed = GetEntitySpeed(vehicle)
            local speedMph = math.floor(speed * 2.236936)
            
            SendNUIMessage({
                type = 'updateCarHud',
                name = labelName,
                speed = speedMph
            })
        else
            -- Player is not in a vehicle
            if wasInVehicle then
                SendNUIMessage({ type = 'hideCarHud' })
                wasInVehicle = false
            end
        end
    end
end)
