-- Sumo - Client Side
-- Team vehicular combat: push enemies off the platform. Last team standing wins.
-- Best of 7: first team to 4 round wins takes the match.

SumoLocal = {
    inLobby = false,
    inRace = false,
    team = nil,
    vehicle = 1,
    previewVehicle = nil,
    raceVehicle = nil,
    mapData = nil,
    eliminated = false,
    arenaCenter = nil,
    arenaRadius = nil,
    arenaZ = nil,
    roundTimer = nil,
    respawnHoldStart = 0,
    showingGamePlayers = false,
    aliveGreen = 0,
    alivePurple = 0,
}

-- ============================================================
-- SUMO MAP EDITOR
-- Map format: { name, team1Spawn{x,y,z,w}, team2Spawn{x,y,z,w}, arenaCenter{x,y,z}, arenaRadius }
-- ============================================================
SumoEditor = {
    active = false,
    mapName = 'untitled',
    team1Spawn = nil,
    team2Spawn = nil,
    arenaCenter = nil,
    arenaRadius = Config.Sumo.Settings.arenaRadius,
}

RegisterNetEvent('sumo:startEditor', function(mapName)
    SumoEditor.active = true
    SumoEditor.mapName = mapName
    SumoEditor.team1Spawn = nil
    SumoEditor.team2Spawn = nil
    SumoEditor.arenaCenter = nil
    SumoEditor.arenaRadius = Config.Sumo.Settings.arenaRadius

    SendNUIMessage({
        type = 'showEditor',
        game = 'sumo',
        mapName = mapName,
        hasTeam1 = false,
        hasTeam2 = false,
    })
    TriggerEvent('chat:addMessage', { args = { '^5[SUMO EDITOR]', 'Editor started. 1=Team1 spawn, 2=Team2 spawn, 3=Arena center, +/-=Adjust radius, Z=Save' } })
end)

function SumoExitEditor()
    SumoEditor.active = false
    SendNUIMessage({ type = 'hideEditor' })
    TriggerEvent('chat:addMessage', { args = { '^1[SUMO EDITOR]', 'Editor closed.' } })
end

function SumoUpdateEditorUI()
    SendNUIMessage({
        type = 'updateEditor',
        game = 'sumo',
        mapName = SumoEditor.mapName,
        hasTeam1 = SumoEditor.team1Spawn ~= nil,
        hasTeam2 = SumoEditor.team2Spawn ~= nil,
    })
end

CreateThread(function()
    while true do
        Wait(0)
        if SumoEditor.active then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            -- 1 = Set Team 1 Spawn (green)
            if IsControlJustPressed(0, 157) then
                SumoEditor.team1Spawn = { x = pos.x, y = pos.y, z = pos.z, w = heading }
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^5[SUMO EDITOR]', 'Team 1 (Green) spawn set' } })
                SumoUpdateEditorUI()
            end

            -- 2 = Set Team 2 Spawn (purple)
            if IsControlJustPressed(0, 158) then
                SumoEditor.team2Spawn = { x = pos.x, y = pos.y, z = pos.z, w = heading }
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^5[SUMO EDITOR]', 'Team 2 (Purple) spawn set' } })
                SumoUpdateEditorUI()
            end

            -- 3 = Set arena center
            if IsControlJustPressed(0, 160) then -- key "3"
                SumoEditor.arenaCenter = { x = pos.x, y = pos.y, z = pos.z }
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^5[SUMO EDITOR]', 'Arena center set (radius: ' .. SumoEditor.arenaRadius .. ')' } })
            end

            -- Arrow Up / + = increase radius
            if IsControlJustPressed(0, 172) then -- arrow up
                SumoEditor.arenaRadius = SumoEditor.arenaRadius + 5.0
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^5[SUMO EDITOR]', 'Radius: ' .. SumoEditor.arenaRadius } })
            end

            -- Arrow Down / - = decrease radius
            if IsControlJustPressed(0, 173) then -- arrow down
                SumoEditor.arenaRadius = math.max(10.0, SumoEditor.arenaRadius - 5.0)
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^5[SUMO EDITOR]', 'Radius: ' .. SumoEditor.arenaRadius } })
            end

            -- E = Remove last set item
            if IsControlJustPressed(0, 38) then
                if SumoEditor.arenaCenter then
                    SumoEditor.arenaCenter = nil
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[SUMO EDITOR]', 'Removed arena center' } })
                elseif SumoEditor.team2Spawn then
                    SumoEditor.team2Spawn = nil
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[SUMO EDITOR]', 'Removed Team 2 spawn' } })
                elseif SumoEditor.team1Spawn then
                    SumoEditor.team1Spawn = nil
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[SUMO EDITOR]', 'Removed Team 1 spawn' } })
                end
                SumoUpdateEditorUI()
            end

            -- Z = Save map
            if IsControlJustPressed(0, 20) then
                if not SumoEditor.team1Spawn then
                    TriggerEvent('chat:addMessage', { args = { '^1[SUMO EDITOR]', 'Set Team 1 spawn first! (1)' } })
                elseif not SumoEditor.team2Spawn then
                    TriggerEvent('chat:addMessage', { args = { '^1[SUMO EDITOR]', 'Set Team 2 spawn first! (2)' } })
                else
                    -- Auto-calculate arena center if not manually set
                    local center = SumoEditor.arenaCenter
                    if not center then
                        center = {
                            x = (SumoEditor.team1Spawn.x + SumoEditor.team2Spawn.x) / 2,
                            y = (SumoEditor.team1Spawn.y + SumoEditor.team2Spawn.y) / 2,
                            z = (SumoEditor.team1Spawn.z + SumoEditor.team2Spawn.z) / 2,
                        }
                    end
                    local mapData = {
                        name = SumoEditor.mapName,
                        team1Spawn = SumoEditor.team1Spawn,
                        team2Spawn = SumoEditor.team2Spawn,
                        arenaCenter = center,
                        arenaRadius = SumoEditor.arenaRadius,
                    }
                    TriggerServerEvent('sumo:saveMap', mapData)
                    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', false)
                end
            end

            -- Draw markers
            if SumoEditor.team1Spawn then
                local t = SumoEditor.team1Spawn
                DrawMarker(1, t.x, t.y, t.z - 1.0, 0, 0, 0, 0, 0, 0, 6.0, 6.0, 2.0, 50, 205, 50, 150, false, false, 2, false, nil, nil, false)
                DrawText3D(t.x, t.y, t.z + 2.0, 'TEAM 1')
            end

            if SumoEditor.team2Spawn then
                local t = SumoEditor.team2Spawn
                DrawMarker(1, t.x, t.y, t.z - 1.0, 0, 0, 0, 0, 0, 0, 6.0, 6.0, 2.0, 148, 0, 211, 150, false, false, 2, false, nil, nil, false)
                DrawText3D(t.x, t.y, t.z + 2.0, 'TEAM 2')
            end

            -- Draw arena boundary
            local center = SumoEditor.arenaCenter
            if not center and SumoEditor.team1Spawn and SumoEditor.team2Spawn then
                center = {
                    x = (SumoEditor.team1Spawn.x + SumoEditor.team2Spawn.x) / 2,
                    y = (SumoEditor.team1Spawn.y + SumoEditor.team2Spawn.y) / 2,
                    z = (SumoEditor.team1Spawn.z + SumoEditor.team2Spawn.z) / 2,
                }
            end
            if center then
                DrawMarker(1, center.x, center.y, center.z - 1.0, 0, 0, 0, 0, 0, 0,
                    SumoEditor.arenaRadius * 2, SumoEditor.arenaRadius * 2, 1.0,
                    255, 100, 0, 80, false, false, 2, false, nil, nil, false)
                DrawText3D(center.x, center.y, center.z + 3.0, 'ARENA (r=' .. SumoEditor.arenaRadius .. ')')
            end

            -- ESC = Exit editor
            if IsControlJustPressed(0, 200) then
                SumoExitEditor()
            end
        end
    end
end)

-- ============================================================
-- NUI CALLBACKS
-- ============================================================
RegisterNUICallback('sumo_ready', function(_, cb) TriggerServerEvent('sumo:ready') cb('ok') end)
RegisterNUICallback('sumo_leave', function(_, cb) TriggerServerEvent('sumo:leave') cb('ok') end)
RegisterNUICallback('sumo_selectCar', function(data, cb)
    TriggerServerEvent('sumo:selectCar', data.car)
    SumoUpdatePreviewVehicle(data.car)
    cb('ok')
end)
RegisterNUICallback('sumo_switchTeam', function(data, cb) TriggerServerEvent('sumo:switchTeam', data.team) cb('ok') end)
RegisterNUICallback('sumo_switchRole', function(data, cb) cb('ok') end)

-- ============================================================
-- LOBBY
-- ============================================================
RegisterNetEvent('sumo:joinLobby', function(team, role, slotIndex, mapData)
    SumoLocal.inLobby = true
    SumoLocal.team = team
    SumoLocal.mapData = mapData
    SumoLocal.eliminated = false

    local spawn = SumoGetLobbySpawn(team, slotIndex)

    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    FreezeEntityPosition(ped, true)

    SumoSpawnPreviewVehicle(team, spawn)

    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'showLobby', team = team, role = 'fighter', game = 'sumo' })
    GiveAllWeapons()
end)

RegisterNetEvent('sumo:leaveLobby', function()
    SumoLocal.inLobby = false
    FreezeEntityPosition(PlayerPedId(), false)
    SumoDeletePreviewVehicle()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideLobby' })
    SpawnAtRandomRoad(true)
end)

RegisterNetEvent('sumo:updatePlayer', function(team, role, slotIndex)
    SumoLocal.team = team
    SumoDeletePreviewVehicle()
    local spawn = SumoGetLobbySpawn(team, slotIndex)
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    SumoSpawnPreviewVehicle(team, spawn)
    SendNUIMessage({ type = 'showLobby', team = team, role = 'fighter', game = 'sumo' })
    GiveAllWeapons()
end)

RegisterNetEvent('sumo:updateLobby', function(green, purple)
    SendNUIMessage({ type = 'updateLobby', players = { green = green, purple = purple } })
end)

RegisterNetEvent('sumo:lobbyCountdown', function(seconds)
    SendNUIMessage({ type = 'updateTimer', time = seconds, label = 'STARTING' })
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end)

RegisterNetEvent('sumo:updatePot', function(pot, wager, teamSize)
    SendNUIMessage({ type = 'updatePot', pot = pot, wager = wager, teamSize = teamSize or 1 })
end)

RegisterNetEvent('sumo:showResults', function(data)
    SendNUIMessage({ type = 'showResults', data = data })
    if data.won then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    else
        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    end
end)

-- ============================================================
-- ROUND TIMER
-- ============================================================
RegisterNetEvent('sumo:updateRoundTimer', function(seconds)
    SumoLocal.roundTimer = seconds
end)

-- ============================================================
-- ALIVE COUNTS
-- ============================================================
RegisterNetEvent('sumo:updateAlive', function(green, purple)
    SumoLocal.aliveGreen = green
    SumoLocal.alivePurple = purple
end)

-- ============================================================
-- RACE START (first round)
-- ============================================================
RegisterNetEvent('sumo:startRace', function(team, slotIndex, vehicleModel, mapData, scores)
    SumoLocal.inLobby = false
    SumoLocal.inRace = true
    SumoLocal.team = team
    SumoLocal.mapData = mapData
    SumoLocal.showingGamePlayers = false
    SumoLocal.eliminated = false

    -- Set arena data
    if mapData then
        SumoLocal.arenaCenter = mapData.arenaCenter and vector3(mapData.arenaCenter.x, mapData.arenaCenter.y, mapData.arenaCenter.z) or nil
        SumoLocal.arenaRadius = mapData.arenaRadius or Config.Sumo.Settings.arenaRadius
        SumoLocal.arenaZ = mapData.arenaCenter and mapData.arenaCenter.z or nil
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideLobby' })
    SumoDeletePreviewVehicle()

    local spawn = SumoGetRaceSpawn(team, slotIndex)
    SumoSpawnRaceVehicle(vehicleModel, spawn)

    FreezeEntityPosition(SumoLocal.raceVehicle, true)

    SendNUIMessage({ type = 'updateRoundScore', greenScore = scores[1] or 0, purpleScore = scores[2] or 0 })

    CreateThread(function()
        for i = Config.Sumo.Settings.raceCountdown, 1, -1 do
            SendNUIMessage({ type = 'showRaceCountdown', number = tostring(i), text = 'ROUND 1 - SUMO' })
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            Wait(1000)
        end
        SendNUIMessage({ type = 'showRaceCountdown', number = 'GO', text = 'PUSH THEM OFF!' })
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        FreezeEntityPosition(SumoLocal.raceVehicle, false)
        GiveAllWeapons()
        Wait(1000)
        SendNUIMessage({ type = 'hideRaceCountdown' })
        SendNUIMessage({ type = 'showRaceHud', game = 'sumo' })
    end)
end)

-- ============================================================
-- NEXT ROUND
-- ============================================================
RegisterNetEvent('sumo:nextRound', function(team, slotIndex, round, scores, vehicleModel)
    SumoLocal.eliminated = false

    SendNUIMessage({ type = 'hideRoundResult' })
    SendNUIMessage({ type = 'updateRoundScore', greenScore = scores[1] or 0, purpleScore = scores[2] or 0 })

    local spawn = SumoGetRaceSpawn(team, slotIndex)

    -- Warp out and delete old vehicle
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        SetEntityCoords(ped, spawn.x, spawn.y, spawn.z + 2.0, false, false, false, true)
    end
    if SumoLocal.raceVehicle and DoesEntityExist(SumoLocal.raceVehicle) then
        SetEntityAsMissionEntity(SumoLocal.raceVehicle, false, true)
        DeleteVehicle(SumoLocal.raceVehicle)
        DeleteEntity(SumoLocal.raceVehicle)
        SumoLocal.raceVehicle = nil
    end

    SumoSpawnRaceVehicle(vehicleModel, spawn)
    FreezeEntityPosition(SumoLocal.raceVehicle, true)

    CreateThread(function()
        for i = Config.Sumo.Settings.raceCountdown, 1, -1 do
            SendNUIMessage({ type = 'showRaceCountdown', number = tostring(i), text = 'ROUND ' .. round .. ' - SUMO' })
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            Wait(1000)
        end
        SendNUIMessage({ type = 'showRaceCountdown', number = 'GO', text = 'PUSH THEM OFF!' })
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        if SumoLocal.raceVehicle and DoesEntityExist(SumoLocal.raceVehicle) then
            FreezeEntityPosition(SumoLocal.raceVehicle, false)
        end
        GiveAllWeapons()
        Wait(1000)
        SendNUIMessage({ type = 'hideRaceCountdown' })
        SendNUIMessage({ type = 'showRaceHud', game = 'sumo' })
    end)
end)

-- ============================================================
-- ROUND RESULT
-- ============================================================
RegisterNetEvent('sumo:roundResult', function(data)
    if SumoLocal.raceVehicle and DoesEntityExist(SumoLocal.raceVehicle) then
        FreezeEntityPosition(SumoLocal.raceVehicle, true)
    end

    SendNUIMessage({
        type = 'showRoundResult',
        won = data.won,
        teamName = data.teamName,
        greenScore = data.greenScore,
        purpleScore = data.purpleScore,
        matchOver = data.matchOver,
    })

    if data.won then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    else
        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    end
end)

-- ============================================================
-- ELIMINATION
-- ============================================================
RegisterNetEvent('sumo:eliminated', function()
    SumoLocal.eliminated = true
    -- Freeze the vehicle
    if SumoLocal.raceVehicle and DoesEntityExist(SumoLocal.raceVehicle) then
        FreezeEntityPosition(SumoLocal.raceVehicle, true)
    end
end)

-- ============================================================
-- END RACE
-- ============================================================
RegisterNetEvent('sumo:endRace', function()
    SumoLocal.inRace = false
    SumoLocal.eliminated = false
    SumoLocal.roundTimer = nil
    SumoLocal.aliveGreen = 0
    SumoLocal.alivePurple = 0
    SumoClearAllPlayerBlips()
    SumoLocal.showingGamePlayers = false
    SumoDeleteRaceVehicle()
    SendNUIMessage({ type = 'hideRaceCountdown' })
    SendNUIMessage({ type = 'hideRaceHud' })
    SendNUIMessage({ type = 'hideRespawnProgress' })
    SendNUIMessage({ type = 'hideRoundResult' })
    SendNUIMessage({ type = 'setPlayersTitle', title = 'ONLINE' })
    SpawnAtRandomRoad(true)
end)

-- ============================================================
-- SPAWN HELPERS
-- ============================================================
function SumoGetLobbySpawn(team, slot)
    if SumoLocal.mapData then
        local spawn = team == 1 and SumoLocal.mapData.team1Spawn or SumoLocal.mapData.team2Spawn
        if spawn then
            local spacing = Config.Sumo.Settings.spawnSpacing
            local rad = math.rad(spawn.w)
            local sideOffset = (slot - 1) * spacing
            local sideX = math.cos(rad) * sideOffset
            local sideY = math.sin(rad) * sideOffset
            return vector4(spawn.x + sideX, spawn.y + sideY, spawn.z, spawn.w)
        end
    end

    -- Fallback defaults
    local defaults = {
        [1] = { vector4(-1047.0, -2972.0, 13.9, 60.0), vector4(-1047.0, -2978.0, 13.9, 60.0), vector4(-1047.0, -2984.0, 13.9, 60.0), vector4(-1047.0, -2990.0, 13.9, 60.0) },
        [2] = { vector4(-1027.0, -2972.0, 13.9, 120.0), vector4(-1027.0, -2978.0, 13.9, 120.0), vector4(-1027.0, -2984.0, 13.9, 120.0), vector4(-1027.0, -2990.0, 13.9, 120.0) }
    }
    return defaults[team][slot] or defaults[team][1]
end

function SumoGetRaceSpawn(team, slot)
    if SumoLocal.mapData then
        local spawn = team == 1 and SumoLocal.mapData.team1Spawn or SumoLocal.mapData.team2Spawn
        if spawn then
            local spacing = Config.Sumo.Settings.spawnSpacing
            local rad = math.rad(spawn.w)
            local sideOffset = (slot - 1) * spacing
            local sideX = math.cos(rad) * sideOffset
            local sideY = math.sin(rad) * sideOffset
            return vector4(spawn.x + sideX, spawn.y + sideY, spawn.z, spawn.w)
        end
    end

    local defaults = {
        [1] = { vector4(-1497.0, -2595.0, 13.9, 240.0), vector4(-1505.0, -2590.0, 13.9, 240.0), vector4(-1513.0, -2585.0, 13.9, 240.0), vector4(-1521.0, -2580.0, 13.9, 240.0) },
        [2] = { vector4(-1493.0, -2602.0, 13.9, 240.0), vector4(-1501.0, -2607.0, 13.9, 240.0), vector4(-1509.0, -2612.0, 13.9, 240.0), vector4(-1517.0, -2617.0, 13.9, 240.0) }
    }
    return defaults[team][slot] or defaults[team][1]
end

-- ============================================================
-- VEHICLE SPAWNING
-- ============================================================
function SumoSpawnPreviewVehicle(team, spawn)
    SumoDeletePreviewVehicle()
    local model = Config.Sumo.Vehicles[SumoLocal.vehicle or 1].model
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    local offset = vector3(3.5, 0.0, 0.0)
    SumoLocal.previewVehicle = CreateVehicle(hash, spawn.x + offset.x, spawn.y + offset.y, spawn.z, spawn.w + 90.0, false, false)
    SetEntityAsMissionEntity(SumoLocal.previewVehicle, true, true)
    FreezeEntityPosition(SumoLocal.previewVehicle, true)

    local color = Config.Teams[team].color
    SetVehicleCustomPrimaryColour(SumoLocal.previewVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(SumoLocal.previewVehicle, color.r, color.g, color.b)
    SetModelAsNoLongerNeeded(hash)
end

function SumoUpdatePreviewVehicle(carIndex)
    if not SumoLocal.previewVehicle then return end
    SumoLocal.vehicle = carIndex
    local spawn = SumoGetLobbySpawn(SumoLocal.team, 1)
    SumoDeletePreviewVehicle()

    local model = Config.Sumo.Vehicles[carIndex].model
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    SumoLocal.previewVehicle = CreateVehicle(hash, spawn.x + 3.5, spawn.y, spawn.z, spawn.w + 90.0, false, false)
    SetEntityAsMissionEntity(SumoLocal.previewVehicle, true, true)
    FreezeEntityPosition(SumoLocal.previewVehicle, true)

    local color = Config.Teams[SumoLocal.team].color
    SetVehicleCustomPrimaryColour(SumoLocal.previewVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(SumoLocal.previewVehicle, color.r, color.g, color.b)
    SetModelAsNoLongerNeeded(hash)
end

function SumoDeletePreviewVehicle()
    if SumoLocal.previewVehicle then
        if DoesEntityExist(SumoLocal.previewVehicle) then
            SetEntityAsMissionEntity(SumoLocal.previewVehicle, false, true)
            DeleteVehicle(SumoLocal.previewVehicle)
            DeleteEntity(SumoLocal.previewVehicle)
        end
        SumoLocal.previewVehicle = nil
    end
end

function SumoDeleteRaceVehicle()
    if SumoLocal.raceVehicle then
        if DoesEntityExist(SumoLocal.raceVehicle) then
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == SumoLocal.raceVehicle then
                TaskLeaveVehicle(ped, SumoLocal.raceVehicle, 16)
                Wait(500)
            end
            SetEntityAsMissionEntity(SumoLocal.raceVehicle, false, true)
            DeleteVehicle(SumoLocal.raceVehicle)
            DeleteEntity(SumoLocal.raceVehicle)
        end
        SumoLocal.raceVehicle = nil
    end
end

function SumoSpawnRaceVehicle(model, spawn)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    SumoLocal.raceVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetEntityAsMissionEntity(SumoLocal.raceVehicle, true, true)

    local color = Config.Teams[SumoLocal.team].color
    SetVehicleCustomPrimaryColour(SumoLocal.raceVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(SumoLocal.raceVehicle, color.r, color.g, color.b)

    FreezeEntityPosition(PlayerPedId(), false)
    SetPedIntoVehicle(PlayerPedId(), SumoLocal.raceVehicle, -1)
    SetModelAsNoLongerNeeded(hash)
end

-- ============================================================
-- ARENA BOUNDARY DETECTION (every 100ms)
-- ============================================================
CreateThread(function()
    while true do
        Wait(100)
        if SumoLocal.inRace and not SumoLocal.eliminated and SumoLocal.arenaCenter then
            local pos = GetEntityCoords(PlayerPedId())
            local dist2D = math.sqrt(
                (pos.x - SumoLocal.arenaCenter.x) ^ 2 +
                (pos.y - SumoLocal.arenaCenter.y) ^ 2
            )
            local dropHeight = SumoLocal.arenaZ and (SumoLocal.arenaZ - pos.z) or 0

            if dist2D > SumoLocal.arenaRadius or dropHeight > Config.Sumo.Settings.eliminationDropHeight then
                TriggerServerEvent('sumo:playerEliminated')
            end
        end
    end
end)

-- ============================================================
-- DRAW ARENA BOUNDARY (every frame during race)
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if SumoLocal.inRace and SumoLocal.arenaCenter then
            -- Orange ring boundary
            DrawMarker(1, SumoLocal.arenaCenter.x, SumoLocal.arenaCenter.y, SumoLocal.arenaCenter.z - 1.0,
                0, 0, 0, 0, 0, 0,
                SumoLocal.arenaRadius * 2, SumoLocal.arenaRadius * 2, 1.0,
                255, 100, 0, 60, false, false, 2, false, nil, nil, false)
        end
    end
end)

-- ============================================================
-- SUMO RACE HUD UPDATE (every 100ms)
-- ============================================================
CreateThread(function()
    while true do
        Wait(100)
        if SumoLocal.inRace then
            SendNUIMessage({
                type = 'updateRaceHud',
                game = 'sumo',
                timer = SumoLocal.roundTimer,
                aliveGreen = SumoLocal.aliveGreen,
                alivePurple = SumoLocal.alivePurple,
                eliminated = SumoLocal.eliminated,
            })
        end
    end
end)

-- ============================================================
-- HOLD E TO RESPAWN (only if alive and within arena)
-- ============================================================
CreateThread(function()
    local holdTime = 3000
    while true do
        Wait(0)
        if SumoLocal.inRace and not SumoLocal.eliminated then
            if IsControlPressed(0, 38) then
                if SumoLocal.respawnHoldStart == 0 then
                    SumoLocal.respawnHoldStart = GetGameTimer()
                end

                local elapsed = GetGameTimer() - SumoLocal.respawnHoldStart
                local progress = math.min(100, (elapsed / holdTime) * 100)
                SendNUIMessage({ type = 'showRespawnProgress', progress = progress })

                if elapsed >= holdTime then
                    SumoLocal.respawnHoldStart = 0
                    SendNUIMessage({ type = 'hideRespawnProgress' })

                    local spawn = SumoGetRaceSpawn(SumoLocal.team, 1)

                    if SumoLocal.raceVehicle and DoesEntityExist(SumoLocal.raceVehicle) then
                        SetEntityCoords(SumoLocal.raceVehicle, spawn.x, spawn.y, spawn.z + 1.0, false, false, false, true)
                        SetEntityHeading(SumoLocal.raceVehicle, spawn.w)
                        SetVehicleOnGroundProperly(SumoLocal.raceVehicle)
                        SetVehicleEngineOn(SumoLocal.raceVehicle, true, true, false)
                        SetVehicleFixed(SumoLocal.raceVehicle)
                        SetVehicleDeformationFixed(SumoLocal.raceVehicle)
                    end
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    Wait(500)
                end
            else
                if SumoLocal.respawnHoldStart > 0 then
                    SumoLocal.respawnHoldStart = 0
                    SendNUIMessage({ type = 'hideRespawnProgress' })
                end
            end
        else
            if SumoLocal.respawnHoldStart > 0 then
                SumoLocal.respawnHoldStart = 0
                SendNUIMessage({ type = 'hideRespawnProgress' })
            end
            Wait(100)
        end
    end
end)

-- ============================================================
-- TAB TO TOGGLE PLAYERS LIST
-- ============================================================
CreateThread(function()
    local tabPressed = false
    while true do
        Wait(0)
        if SumoLocal.inRace then
            if IsControlJustPressed(0, 37) and not tabPressed then
                tabPressed = true
                SumoLocal.showingGamePlayers = not SumoLocal.showingGamePlayers
                if SumoLocal.showingGamePlayers then
                    SendNUIMessage({ type = 'setPlayersTitle', title = 'IN GAME' })
                    TriggerServerEvent('sumo:requestGamePlayers')
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

RegisterNetEvent('sumo:updateGamePlayers', function(players)
    if SumoLocal.showingGamePlayers then
        SendNUIMessage({ type = 'updateOnlinePlayers', players = players })
    end
end)

-- ============================================================
-- DISABLE NPC TRAFFIC AND PEDS (during lobby AND race)
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if SumoLocal.inLobby or SumoLocal.inRace then
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetPedDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if SumoLocal.inLobby or SumoLocal.inRace then
            local pos = GetEntityCoords(PlayerPedId())
            ClearAreaOfVehicles(pos.x, pos.y, pos.z, 1500.0, false, false, false, false, false)
            ClearAreaOfPeds(pos.x, pos.y, pos.z, 1500.0, true)
        end
    end
end)

-- ============================================================
-- PLAYER BLIPS
-- ============================================================
SumoPlayerBlips = {}

function SumoUpdatePlayerBlip(playerId, team, alive)
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then return end

    if SumoPlayerBlips[playerId] then
        RemoveBlip(SumoPlayerBlips[playerId])
        SumoPlayerBlips[playerId] = nil
    end

    if playerId == PlayerId() then return end

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, alive and 304 or 274) -- shield or skull
    SetBlipColour(blip, Config.Teams[team].blipColor)
    SetBlipScale(blip, alive and 0.8 or 0.6)
    SetBlipAsShortRange(blip, false)
    SetBlipDisplay(blip, 2)

    SumoPlayerBlips[playerId] = blip
end

function SumoClearAllPlayerBlips()
    for playerId, blip in pairs(SumoPlayerBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    SumoPlayerBlips = {}
end

RegisterNetEvent('sumo:updatePlayerBlips', function(players)
    if not SumoLocal.inRace then
        SumoClearAllPlayerBlips()
        return
    end

    local seenPlayers = {}
    for _, data in ipairs(players) do
        local playerId = GetPlayerFromServerId(data.serverId)
        if playerId ~= -1 then
            SumoUpdatePlayerBlip(playerId, data.team, data.alive)
            seenPlayers[playerId] = true
        end
    end

    for playerId, blip in pairs(SumoPlayerBlips) do
        if not seenPlayers[playerId] then
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
            SumoPlayerBlips[playerId] = nil
        end
    end
end)
