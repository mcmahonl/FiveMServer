-- Running Back - Client Side
-- Football-inspired mode: Runner (Panto) reaches the end zone while Blockers protect
-- Best of 7: first team to 4 round wins takes the match
-- Teams alternate offense/defense each round. Offense = 1 runner + blockers, Defense = all blockers.

RBLocal = {
    inLobby = false,
    inRace = false,
    team = nil,
    role = nil,
    previewVehicle = nil,
    raceVehicle = nil,
    mapData = nil,
    respawnHoldStart = 0,
    showingGamePlayers = false,
    reachedEndZone = false,
    offenseTeam = nil,
    roundTimer = nil,
}

-- ============================================================
-- RB MAP EDITOR
-- Map format: { name, team1Spawn{x,y,z,w}, team2Spawn{x,y,z,w} }
-- ============================================================
RBEditor = {
    active = false,
    mapName = 'untitled',
    team1Spawn = nil,
    team2Spawn = nil,
}

RegisterNetEvent('rb:startEditor', function(mapName)
    RBEditor.active = true
    RBEditor.mapName = mapName
    RBEditor.team1Spawn = nil
    RBEditor.team2Spawn = nil

    SendNUIMessage({
        type = 'showEditor',
        game = 'rb',
        mapName = mapName,
        hasTeam1 = false,
        hasTeam2 = false,
    })
    TriggerEvent('chat:addMessage', { args = { '^2[RB EDITOR]', 'Editor started. Press 1 for Team 1 spawn, 2 for Team 2 spawn. End zones are auto-placed behind each spawn.' } })
end)

function RBExitEditor()
    RBEditor.active = false
    SendNUIMessage({ type = 'hideEditor' })
    TriggerEvent('chat:addMessage', { args = { '^1[RB EDITOR]', 'Editor closed.' } })
end

function RBUpdateEditorUI()
    SendNUIMessage({
        type = 'updateEditor',
        game = 'rb',
        mapName = RBEditor.mapName,
        hasTeam1 = RBEditor.team1Spawn ~= nil,
        hasTeam2 = RBEditor.team2Spawn ~= nil,
    })
end

CreateThread(function()
    while true do
        Wait(0)
        if RBEditor.active then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            -- 1 = Set Team 1 Spawn (green)
            if IsControlJustPressed(0, 157) then -- numpad 1 / key "1"
                RBEditor.team1Spawn = { x = pos.x, y = pos.y, z = pos.z, w = heading }
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^2[RB EDITOR]', 'Team 1 (Green) spawn set' } })
                RBUpdateEditorUI()
            end

            -- 2 = Set Team 2 Spawn (purple)
            if IsControlJustPressed(0, 158) then -- numpad 2 / key "2"
                RBEditor.team2Spawn = { x = pos.x, y = pos.y, z = pos.z, w = heading }
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^2[RB EDITOR]', 'Team 2 (Purple) spawn set' } })
                RBUpdateEditorUI()
            end

            -- E = Remove last set item (team2 first, then team1)
            if IsControlJustPressed(0, 38) then
                if RBEditor.team2Spawn then
                    RBEditor.team2Spawn = nil
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[RB EDITOR]', 'Removed Team 2 spawn' } })
                elseif RBEditor.team1Spawn then
                    RBEditor.team1Spawn = nil
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[RB EDITOR]', 'Removed Team 1 spawn' } })
                end
                RBUpdateEditorUI()
            end

            -- Z = Save map
            if IsControlJustPressed(0, 20) then
                if not RBEditor.team1Spawn then
                    TriggerEvent('chat:addMessage', { args = { '^1[RB EDITOR]', 'Set Team 1 spawn first! (1)' } })
                elseif not RBEditor.team2Spawn then
                    TriggerEvent('chat:addMessage', { args = { '^1[RB EDITOR]', 'Set Team 2 spawn first! (2)' } })
                else
                    local mapData = {
                        name = RBEditor.mapName,
                        team1Spawn = RBEditor.team1Spawn,
                        team2Spawn = RBEditor.team2Spawn,
                    }
                    TriggerServerEvent('rb:saveMap', mapData)
                    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', false)
                end
            end

            -- Draw markers
            if RBEditor.team1Spawn then
                local t = RBEditor.team1Spawn
                DrawMarker(1, t.x, t.y, t.z - 1.0, 0, 0, 0, 0, 0, 0, 6.0, 6.0, 2.0, 50, 205, 50, 150, false, false, 2, false, nil, nil, false)
                DrawText3D(t.x, t.y, t.z + 2.0, 'TEAM 1')
                -- Draw heading arrow
                local rad = math.rad(t.w)
                local ax = t.x - math.sin(rad) * 4.0
                local ay = t.y + math.cos(rad) * 4.0
                DrawMarker(1, ax, ay, t.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 2.0, 50, 205, 50, 200, false, false, 2, false, nil, nil, false)
            end

            if RBEditor.team2Spawn then
                local t = RBEditor.team2Spawn
                DrawMarker(1, t.x, t.y, t.z - 1.0, 0, 0, 0, 0, 0, 0, 6.0, 6.0, 2.0, 148, 0, 211, 150, false, false, 2, false, nil, nil, false)
                DrawText3D(t.x, t.y, t.z + 2.0, 'TEAM 2')
                local rad = math.rad(t.w)
                local ax = t.x - math.sin(rad) * 4.0
                local ay = t.y + math.cos(rad) * 4.0
                DrawMarker(1, ax, ay, t.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 2.0, 148, 0, 211, 200, false, false, 2, false, nil, nil, false)
            end

            -- Draw calculated end zones when both spawns are set
            if RBEditor.team1Spawn and RBEditor.team2Spawn then
                local dist = Config.RB.Settings.endZoneDistance
                -- End zone behind team 1 (team 2's runner targets this)
                local t1 = RBEditor.team1Spawn
                local rad1 = math.rad(t1.w)
                local ez1x = t1.x + math.sin(rad1) * dist
                local ez1y = t1.y - math.cos(rad1) * dist
                DrawMarker(1, ez1x, ez1y, t1.z - 1.0, 0, 0, 0, 0, 0, 0, Config.RB.Settings.endZoneRadius * 2, Config.RB.Settings.endZoneRadius * 2, 3.0, 255, 215, 0, 100, false, false, 2, false, nil, nil, false)
                DrawText3D(ez1x, ez1y, t1.z + 2.0, 'END ZONE 1')

                -- End zone behind team 2 (team 1's runner targets this)
                local t2 = RBEditor.team2Spawn
                local rad2 = math.rad(t2.w)
                local ez2x = t2.x + math.sin(rad2) * dist
                local ez2y = t2.y - math.cos(rad2) * dist
                DrawMarker(1, ez2x, ez2y, t2.z - 1.0, 0, 0, 0, 0, 0, 0, Config.RB.Settings.endZoneRadius * 2, Config.RB.Settings.endZoneRadius * 2, 3.0, 255, 215, 0, 100, false, false, 2, false, nil, nil, false)
                DrawText3D(ez2x, ez2y, t2.z + 2.0, 'END ZONE 2')
            end

            -- ESC = Exit editor
            if IsControlJustPressed(0, 200) then
                RBExitEditor()
            end
        end
    end
end)

-- ============================================================
-- NUI CALLBACKS
-- ============================================================
RegisterNUICallback('rb_ready', function(_, cb) TriggerServerEvent('rb:ready') cb('ok') end)
RegisterNUICallback('rb_leave', function(_, cb) TriggerServerEvent('rb:leave') cb('ok') end)
RegisterNUICallback('rb_selectCar', function(data, cb)
    TriggerServerEvent('rb:selectCar', data.car)
    RBUpdatePreviewVehicle(data.car)
    cb('ok')
end)
RegisterNUICallback('rb_switchTeam', function(data, cb) TriggerServerEvent('rb:switchTeam', data.team) cb('ok') end)
-- switchRole is disabled for RB (roles auto-assigned per round), but keep callback for NUI compat
RegisterNUICallback('rb_switchRole', function(data, cb) cb('ok') end)

-- ============================================================
-- LOBBY
-- ============================================================
RegisterNetEvent('rb:joinLobby', function(team, role, slotIndex, mapData)
    RBLocal.inLobby = true
    RBLocal.team = team
    RBLocal.role = role
    RBLocal.mapData = mapData

    local spawn = RBGetLobbySpawn(team, slotIndex)

    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    FreezeEntityPosition(ped, true)

    RBSpawnPreviewVehicle(role, team, spawn)

    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'showLobby', team = team, role = role, game = 'rb' })
    GiveAllWeapons()
end)

RegisterNetEvent('rb:leaveLobby', function()
    RBLocal.inLobby = false
    FreezeEntityPosition(PlayerPedId(), false)
    RBDeletePreviewVehicle()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideLobby' })
    SpawnAtRandomRoad(true)
end)

RegisterNetEvent('rb:updatePlayer', function(team, role, slotIndex)
    RBLocal.team = team
    RBLocal.role = role
    RBDeletePreviewVehicle()
    local spawn = RBGetLobbySpawn(team, slotIndex)
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.w)
    RBSpawnPreviewVehicle(role, team, spawn)
    SendNUIMessage({ type = 'showLobby', team = team, role = role, game = 'rb' })
    GiveAllWeapons()
end)

RegisterNetEvent('rb:updateLobby', function(green, purple)
    SendNUIMessage({ type = 'updateLobby', players = { green = green, purple = purple } })
end)

RegisterNetEvent('rb:lobbyCountdown', function(seconds)
    SendNUIMessage({ type = 'updateTimer', time = seconds, label = 'STARTING' })
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end)

RegisterNetEvent('rb:updatePot', function(pot, wager, teamSize)
    SendNUIMessage({ type = 'updatePot', pot = pot, wager = wager, teamSize = teamSize or 1 })
end)

RegisterNetEvent('rb:showResults', function(data)
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
RegisterNetEvent('rb:updateRoundTimer', function(seconds)
    RBLocal.roundTimer = seconds
end)

-- ============================================================
-- RACE START (first round - creates vehicles)
-- ============================================================
RegisterNetEvent('rb:startRace', function(team, slotIndex, vehicleModel, role, mapData, scores, offenseTeam)
    RBLocal.inLobby = false
    RBLocal.inRace = true
    RBLocal.team = team
    RBLocal.role = role
    RBLocal.mapData = mapData
    RBLocal.showingGamePlayers = false
    RBLocal.reachedEndZone = false
    RBLocal.offenseTeam = offenseTeam

    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hideLobby' })
    RBDeletePreviewVehicle()

    local spawn = RBGetRaceSpawn(team, slotIndex)
    RBSpawnRaceVehicle(vehicleModel, spawn)

    FreezeEntityPosition(RBLocal.raceVehicle, true)

    -- Show initial score
    SendNUIMessage({ type = 'updateRoundScore', greenScore = scores[1] or 0, purpleScore = scores[2] or 0 })

    local offTeamName = offenseTeam == 1 and 'GREEN' or 'PURPLE'

    CreateThread(function()
        for i = Config.RB.Settings.raceCountdown, 1, -1 do
            SendNUIMessage({ type = 'showRaceCountdown', number = tostring(i), text = 'ROUND 1 - ' .. offTeamName .. ' OFFENSE' })
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            Wait(1000)
        end
        SendNUIMessage({ type = 'showRaceCountdown', number = 'GO', text = '' })
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        FreezeEntityPosition(RBLocal.raceVehicle, false)
        GiveAllWeapons()
        Wait(1000)
        SendNUIMessage({ type = 'hideRaceCountdown' })
        SendNUIMessage({ type = 'showRaceHud', game = 'rb' })
    end)
end)

-- ============================================================
-- NEXT ROUND (delete old vehicle, spawn new one for new role)
-- ============================================================
RegisterNetEvent('rb:nextRound', function(team, slotIndex, round, scores, role, vehicleModel, offenseTeam)
    RBLocal.reachedEndZone = false
    RBLocal.role = role
    RBLocal.offenseTeam = offenseTeam

    -- Hide round result
    SendNUIMessage({ type = 'hideRoundResult' })

    -- Update score display
    SendNUIMessage({ type = 'updateRoundScore', greenScore = scores[1] or 0, purpleScore = scores[2] or 0 })

    local spawn = RBGetRaceSpawn(team, slotIndex)

    -- Warp ped out of old vehicle and delete it
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        SetEntityCoords(ped, spawn.x, spawn.y, spawn.z + 2.0, false, false, false, true)
    end
    if RBLocal.raceVehicle and DoesEntityExist(RBLocal.raceVehicle) then
        SetEntityAsMissionEntity(RBLocal.raceVehicle, false, true)
        DeleteVehicle(RBLocal.raceVehicle)
        DeleteEntity(RBLocal.raceVehicle)
        RBLocal.raceVehicle = nil
    end

    -- Spawn new vehicle for this round's role
    RBSpawnRaceVehicle(vehicleModel, spawn)
    FreezeEntityPosition(RBLocal.raceVehicle, true)

    local offTeamName = offenseTeam == 1 and 'GREEN' or 'PURPLE'

    CreateThread(function()
        for i = Config.RB.Settings.raceCountdown, 1, -1 do
            SendNUIMessage({ type = 'showRaceCountdown', number = tostring(i), text = 'ROUND ' .. round .. ' - ' .. offTeamName .. ' OFFENSE' })
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            Wait(1000)
        end
        SendNUIMessage({ type = 'showRaceCountdown', number = 'GO', text = '' })
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
        if RBLocal.raceVehicle and DoesEntityExist(RBLocal.raceVehicle) then
            FreezeEntityPosition(RBLocal.raceVehicle, false)
        end
        GiveAllWeapons()
        Wait(1000)
        SendNUIMessage({ type = 'hideRaceCountdown' })
        SendNUIMessage({ type = 'showRaceHud', game = 'rb' })
    end)
end)

-- ============================================================
-- ROUND RESULT (celebration overlay, freeze vehicles)
-- ============================================================
RegisterNetEvent('rb:roundResult', function(data)
    -- Freeze vehicle during celebration
    if RBLocal.raceVehicle and DoesEntityExist(RBLocal.raceVehicle) then
        FreezeEntityPosition(RBLocal.raceVehicle, true)
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

RegisterNetEvent('rb:updatePositions', function(positions)
    RBLocal.positions = positions
end)

-- ============================================================
-- END RACE (match over - full cleanup)
-- ============================================================
RegisterNetEvent('rb:endRace', function()
    RBLocal.inRace = false
    RBLocal.reachedEndZone = false
    RBLocal.offenseTeam = nil
    RBLocal.roundTimer = nil
    RBClearAllPlayerBlips()
    RBLocal.showingGamePlayers = false
    RBDeleteRaceVehicle()
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
function RBGetLobbySpawn(team, slot)
    if RBLocal.mapData then
        local spawn = team == 1 and RBLocal.mapData.team1Spawn or RBLocal.mapData.team2Spawn
        if spawn then
            local spacing = Config.RB.Settings.spawnSpacing
            local rad = math.rad(spawn.w)
            -- Offset sideways from spawn based on slot
            local sideOffset = (slot - 1) * spacing
            local sideX = math.cos(rad) * sideOffset
            local sideY = math.sin(rad) * sideOffset
            return vector4(spawn.x + sideX, spawn.y + sideY, spawn.z, spawn.w)
        end
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

function RBGetRaceSpawn(team, slot)
    if RBLocal.mapData then
        local spawn = team == 1 and RBLocal.mapData.team1Spawn or RBLocal.mapData.team2Spawn
        if spawn then
            local spacing = Config.RB.Settings.spawnSpacing
            local rad = math.rad(spawn.w)
            -- Runner at front (slot 1), blockers behind
            local behindOffset = (slot - 1) * spacing
            local behindX = math.sin(rad) * behindOffset
            local behindY = -math.cos(rad) * behindOffset
            return vector4(spawn.x + behindX, spawn.y + behindY, spawn.z, spawn.w)
        end
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

-- Returns the end zone the runner is targeting (behind the defense team's spawn)
-- Both offense and defense players use this so everyone sees the same end zone
function RBGetTargetEndZone()
    if RBLocal.mapData and RBLocal.offenseTeam then
        local defenseTeam = RBLocal.offenseTeam == 1 and 2 or 1
        local defenseSpawn = defenseTeam == 1 and RBLocal.mapData.team1Spawn or RBLocal.mapData.team2Spawn
        if defenseSpawn then
            local dist = Config.RB.Settings.endZoneDistance
            local rad = math.rad(defenseSpawn.w)
            -- "Behind" = opposite of facing direction
            local ezX = defenseSpawn.x + math.sin(rad) * dist
            local ezY = defenseSpawn.y - math.cos(rad) * dist
            return vector3(ezX, ezY, defenseSpawn.z)
        end
    end
    -- Fallback default
    return vector3(-1600.0, -2714.0, 13.9)
end

-- ============================================================
-- VEHICLE SPAWNING
-- ============================================================
function RBSpawnPreviewVehicle(role, team, spawn)
    RBDeletePreviewVehicle()
    local model = Config.RB.Vehicles.blocker[1].model -- everyone is blocker in lobby
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    local offset = vector3(3.5, 0.0, 0.0)
    RBLocal.previewVehicle = CreateVehicle(hash, spawn.x + offset.x, spawn.y + offset.y, spawn.z, spawn.w + 90.0, false, false)
    SetEntityAsMissionEntity(RBLocal.previewVehicle, true, true)
    FreezeEntityPosition(RBLocal.previewVehicle, true)

    local color = Config.Teams[team].color
    SetVehicleCustomPrimaryColour(RBLocal.previewVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(RBLocal.previewVehicle, color.r, color.g, color.b)
    SetModelAsNoLongerNeeded(hash)
end

function RBUpdatePreviewVehicle(carIndex)
    if not RBLocal.previewVehicle then return end
    local spawn = RBGetLobbySpawn(RBLocal.team, 1)
    RBDeletePreviewVehicle()

    local model = Config.RB.Vehicles.blocker[carIndex].model
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    RBLocal.previewVehicle = CreateVehicle(hash, spawn.x + 3.5, spawn.y, spawn.z, spawn.w + 90.0, false, false)
    SetEntityAsMissionEntity(RBLocal.previewVehicle, true, true)
    FreezeEntityPosition(RBLocal.previewVehicle, true)

    local color = Config.Teams[RBLocal.team].color
    SetVehicleCustomPrimaryColour(RBLocal.previewVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(RBLocal.previewVehicle, color.r, color.g, color.b)
    SetModelAsNoLongerNeeded(hash)
end

function RBDeletePreviewVehicle()
    if RBLocal.previewVehicle then
        if DoesEntityExist(RBLocal.previewVehicle) then
            SetEntityAsMissionEntity(RBLocal.previewVehicle, false, true)
            DeleteVehicle(RBLocal.previewVehicle)
            DeleteEntity(RBLocal.previewVehicle)
        end
        RBLocal.previewVehicle = nil
    end
end

function RBDeleteRaceVehicle()
    if RBLocal.raceVehicle then
        if DoesEntityExist(RBLocal.raceVehicle) then
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == RBLocal.raceVehicle then
                TaskLeaveVehicle(ped, RBLocal.raceVehicle, 16)
                Wait(500)
            end
            SetEntityAsMissionEntity(RBLocal.raceVehicle, false, true)
            DeleteVehicle(RBLocal.raceVehicle)
            DeleteEntity(RBLocal.raceVehicle)
        end
        RBLocal.raceVehicle = nil
    end
end

function RBSpawnRaceVehicle(model, spawn)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    RBLocal.raceVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetEntityAsMissionEntity(RBLocal.raceVehicle, true, true)

    local color = Config.Teams[RBLocal.team].color
    SetVehicleCustomPrimaryColour(RBLocal.raceVehicle, color.r, color.g, color.b)
    SetVehicleCustomSecondaryColour(RBLocal.raceVehicle, color.r, color.g, color.b)

    FreezeEntityPosition(PlayerPedId(), false)
    SetPedIntoVehicle(PlayerPedId(), RBLocal.raceVehicle, -1)
    SetModelAsNoLongerNeeded(hash)
end

-- ============================================================
-- END ZONE DETECTION + HUD UPDATES
-- ============================================================
CreateThread(function()
    while true do
        Wait(100)
        if RBLocal.inRace then
            local endZone = RBGetTargetEndZone()
            local dist = math.floor(#(GetEntityCoords(PlayerPedId()) - endZone))

            SendNUIMessage({
                type = 'updateRaceHud',
                game = 'rb',
                distance = dist,
                timer = RBLocal.roundTimer,
                role = RBLocal.role,
                offenseTeam = RBLocal.offenseTeam,
                myTeam = RBLocal.team,
                positions = RBLocal.positions or {}
            })

            -- Runner end zone detection
            if RBLocal.role == 'runner' and not RBLocal.reachedEndZone then
                if dist < Config.RB.Settings.endZoneRadius then
                    RBLocal.reachedEndZone = true
                    TriggerServerEvent('rb:reachedEndZone')
                    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', false)
                end
                TriggerServerEvent('rb:updateProgress', dist)
            end
        end
    end
end)

-- ============================================================
-- DRAW END ZONE MARKER (during race, visible to ALL players)
-- ============================================================
CreateThread(function()
    while true do
        Wait(0)
        if RBLocal.inRace then
            local endZone = RBGetTargetEndZone()
            -- Gold end zone circle (visible to everyone)
            DrawMarker(1, endZone.x, endZone.y, endZone.z - 1.0, 0, 0, 0, 0, 0, 0,
                Config.RB.Settings.endZoneRadius * 2, Config.RB.Settings.endZoneRadius * 2, 3.0,
                255, 215, 0, 150, false, false, 2, false, nil, nil, false)
            -- White trophy marker above (only for runner)
            if RBLocal.role == 'runner' and not RBLocal.reachedEndZone then
                DrawMarker(4, endZone.x, endZone.y, endZone.z + 2.0, 0, 0, 0, 0, 0, 0,
                    2.0, 2.0, 2.0,
                    255, 255, 255, 200, true, false, 2, true, nil, nil, false)
            end
        end
    end
end)

-- ============================================================
-- HOLD E TO RESPAWN
-- ============================================================
CreateThread(function()
    local holdTime = 3000
    while true do
        Wait(0)
        if RBLocal.inRace then
            if IsControlPressed(0, 38) then
                if RBLocal.respawnHoldStart == 0 then
                    RBLocal.respawnHoldStart = GetGameTimer()
                end

                local elapsed = GetGameTimer() - RBLocal.respawnHoldStart
                local progress = math.min(100, (elapsed / holdTime) * 100)
                SendNUIMessage({ type = 'showRespawnProgress', progress = progress })

                if elapsed >= holdTime then
                    RBLocal.respawnHoldStart = 0
                    SendNUIMessage({ type = 'hideRespawnProgress' })

                    -- Respawn at team spawn
                    local spawn = RBGetRaceSpawn(RBLocal.team, 1)

                    if RBLocal.raceVehicle and DoesEntityExist(RBLocal.raceVehicle) then
                        SetEntityCoords(RBLocal.raceVehicle, spawn.x, spawn.y, spawn.z + 1.0, false, false, false, true)
                        -- Face toward end zone
                        local endZone = RBGetTargetEndZone()
                        local heading = GetHeadingToPoint(spawn, endZone)
                        SetEntityHeading(RBLocal.raceVehicle, heading)
                        SetVehicleOnGroundProperly(RBLocal.raceVehicle)
                        SetVehicleEngineOn(RBLocal.raceVehicle, true, true, false)
                        SetVehicleFixed(RBLocal.raceVehicle)
                        SetVehicleDeformationFixed(RBLocal.raceVehicle)
                    end
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    Wait(500)
                end
            else
                if RBLocal.respawnHoldStart > 0 then
                    RBLocal.respawnHoldStart = 0
                    SendNUIMessage({ type = 'hideRespawnProgress' })
                end
            end
        else
            if RBLocal.respawnHoldStart > 0 then
                RBLocal.respawnHoldStart = 0
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
        if RBLocal.inRace then
            if IsControlJustPressed(0, 37) and not tabPressed then
                tabPressed = true
                RBLocal.showingGamePlayers = not RBLocal.showingGamePlayers
                if RBLocal.showingGamePlayers then
                    SendNUIMessage({ type = 'setPlayersTitle', title = 'IN GAME' })
                    TriggerServerEvent('rb:requestGamePlayers')
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

RegisterNetEvent('rb:updateGamePlayers', function(players)
    if RBLocal.showingGamePlayers then
        SendNUIMessage({ type = 'updateOnlinePlayers', players = players })
    end
end)

-- NUI callback for joining from browser
RegisterNUICallback('joinGame', function(data, cb)
    if data.game == 'rb' then
        TriggerServerEvent('rb:joinFromBrowser')
    end
    cb('ok')
end)

-- ============================================================
-- DISABLE NPC TRAFFIC AND PEDS (during lobby AND race)
-- ============================================================
-- Per-frame density suppression
CreateThread(function()
    while true do
        Wait(0)
        if RBLocal.inLobby or RBLocal.inRace then
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetPedDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        end
    end
end)

-- Periodic cleanup of existing NPC vehicles/peds in a large radius
CreateThread(function()
    while true do
        Wait(2000)
        if RBLocal.inLobby or RBLocal.inRace then
            local pos = GetEntityCoords(PlayerPedId())
            ClearAreaOfVehicles(pos.x, pos.y, pos.z, 1500.0, false, false, false, false, false)
            ClearAreaOfPeds(pos.x, pos.y, pos.z, 1500.0, true)
        end
    end
end)

-- ============================================================
-- PLAYER BLIPS
-- ============================================================
RBPlayerBlips = {}

local RB_BLIP_SPRITE_RUNNER = 309
local RB_BLIP_SPRITE_BLOCKER = 304

function RBUpdatePlayerBlip(playerId, team, role)
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then return end

    if RBPlayerBlips[playerId] then
        RemoveBlip(RBPlayerBlips[playerId])
        RBPlayerBlips[playerId] = nil
    end

    if playerId == PlayerId() then return end

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, role == 'runner' and RB_BLIP_SPRITE_RUNNER or RB_BLIP_SPRITE_BLOCKER)
    SetBlipColour(blip, Config.Teams[team].blipColor)
    SetBlipScale(blip, role == 'runner' and 1.0 or 0.8)
    SetBlipAsShortRange(blip, false)
    SetBlipDisplay(blip, 2)

    RBPlayerBlips[playerId] = blip
end

function RBClearAllPlayerBlips()
    for playerId, blip in pairs(RBPlayerBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    RBPlayerBlips = {}
end

RegisterNetEvent('rb:updatePlayerBlips', function(players)
    if not RBLocal.inRace then
        RBClearAllPlayerBlips()
        return
    end

    local seenPlayers = {}
    for _, data in ipairs(players) do
        local playerId = GetPlayerFromServerId(data.serverId)
        if playerId ~= -1 then
            RBUpdatePlayerBlip(playerId, data.team, data.role)
            seenPlayers[playerId] = true
        end
    end

    for playerId, blip in pairs(RBPlayerBlips) do
        if not seenPlayers[playerId] then
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
            RBPlayerBlips[playerId] = nil
        end
    end
end)
