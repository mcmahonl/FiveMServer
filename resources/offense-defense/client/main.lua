Local = {
    inLobby = false,
    inRace = false,
    inEditor = false,
    team = nil,
    role = nil,
    previewVehicle = nil,
    raceVehicle = nil,
    currentCheckpoint = 1,
    mapData = nil,
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

-- Online players update
RegisterNetEvent('od:updateOnline', function(players)
    SendNUIMessage({ type = 'updateOnlinePlayers', players = players })
end)

-- Join lobby
RegisterNetEvent('od:joinLobby', function(team, role, slotIndex)
    Local.inLobby = true
    Local.team = team
    Local.role = role
    
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
end)

RegisterNetEvent('od:updateLobby', function(green, purple)
    SendNUIMessage({ type = 'updateLobby', players = { green = green, purple = purple } })
end)

RegisterNetEvent('od:lobbyCountdown', function(seconds)
    SendNUIMessage({ type = 'updateTimer', time = seconds, label = 'STARTING' })
    PlaySoundFrontend(-1, 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
end)

-- Start race
RegisterNetEvent('od:startRace', function(team, slotIndex, vehicleModel, role)
    Local.inLobby = false
    Local.inRace = true
    Local.team = team
    Local.role = role
    Local.currentCheckpoint = 1
    
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideLobby' })
    DeletePreviewVehicle()
    
    local spawn = GetRaceSpawn(team, slotIndex)
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
    end)
end)

RegisterNetEvent('od:endRace', function()
    Local.inRace = false
    if Local.raceVehicle and DoesEntityExist(Local.raceVehicle) then
        DeleteEntity(Local.raceVehicle)
    end
    Local.raceVehicle = nil
    SendNUIMessage({ type = 'hideRaceCountdown' })
end)

-- Spawns (with fallback defaults)
function GetLobbySpawn(team, slot)
    -- TODO: Load from map file
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
    if Local.previewVehicle and DoesEntityExist(Local.previewVehicle) then
        DeleteEntity(Local.previewVehicle)
    end
    Local.previewVehicle = nil
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

-- Checkpoint logic
CreateThread(function()
    while true do
        Wait(100)
        if Local.inRace and Local.role == 'runner' then
            local checkpoints = GetCheckpoints()
            local cp = checkpoints[Local.currentCheckpoint]
            if cp then
                local dist = #(GetEntityCoords(PlayerPedId()) - cp)
                if dist < Config.Settings.checkpointRadius then
                    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                    TriggerServerEvent('od:checkpointReached', Local.currentCheckpoint, #checkpoints)
                    Local.currentCheckpoint = Local.currentCheckpoint + 1
                end
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
