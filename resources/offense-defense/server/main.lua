-- State
GameState = {
    phase = 'idle',
    players = {},
    teams = { [1] = {}, [2] = {} },
    countdown = nil,
    currentMap = nil,
}

OnlinePlayers = {}  -- [source] = { name, role }

-- Check if player is admin
function IsAdmin(source)
    local name = GetPlayerName(source)
    for _, admin in ipairs(Config.Admins) do
        if name == admin then return true end
    end
    -- Also check identifiers
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        for _, admin in ipairs(Config.Admins) do
            if id:find(admin) then return true end
        end
    end
    return false
end

function GetPlayerRole(source)
    return IsAdmin(source) and 'admin' or 'player'
end

-- Track online players
AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    Wait(100)
end)

AddEventHandler('playerJoining', function()
    local src = source
    local name = GetPlayerName(src)
    OnlinePlayers[src] = { name = name, role = GetPlayerRole(src) }
    BroadcastOnlinePlayers()
end)

AddEventHandler('playerDropped', function()
    local src = source
    OnlinePlayers[src] = nil
    LeaveLobby(src)
    BroadcastOnlinePlayers()
end)

function BroadcastOnlinePlayers()
    local list = {}
    for src, data in pairs(OnlinePlayers) do
        table.insert(list, { name = data.name, role = data.role })
    end
    TriggerClientEvent('od:updateOnline', -1, list)
end

-- Initialize online players on resource start
CreateThread(function()
    Wait(1000)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        OnlinePlayers[src] = { name = GetPlayerName(src), role = GetPlayerRole(src) }
    end
    BroadcastOnlinePlayers()
end)

-- Commands
RegisterCommand('join', function(source, args)
    local game = args[1]
    if game == 'od' then
        JoinLobby(source)
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[SERVER]', 'Try: /join od' } })
    end
end, false)

RegisterCommand('odedit', function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[OD]', 'Admins only!' } })
        return
    end
    local mapName = args[1] or 'untitled'
    TriggerClientEvent('od:startEditor', source, mapName)
end, false)

RegisterCommand('odstart', function(source)
    if Config.Settings.allowSoloTest or IsAdmin(source) then
        StartRace()
    end
end, false)

RegisterCommand('odstop', function(source)
    if IsAdmin(source) then
        EndRace(0)
    end
end, false)

-- Lobby
function JoinLobby(source)
    if GameState.phase == 'racing' then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[OD]', 'Race in progress!' } })
        return
    end
    if GameState.players[source] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[OD]', 'Already in lobby!' } })
        return
    end
    
    local team = #GameState.teams[1] <= #GameState.teams[2] and 1 or 2
    if #GameState.teams[team] >= Config.Settings.maxTeamSize then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[OD]', 'Lobby full!' } })
        return
    end
    
    local role = #GameState.teams[team] == 0 and 'runner' or 'blocker'
    GameState.players[source] = { team = team, role = role, ready = false, vehicle = 1, name = GetPlayerName(source) }
    table.insert(GameState.teams[team], source)
    
    if GameState.phase == 'idle' then GameState.phase = 'lobby' end
    
    local slotIndex = #GameState.teams[team]
    TriggerClientEvent('od:joinLobby', source, team, role, slotIndex)
    BroadcastLobbyState()
    
    TriggerClientEvent('chat:addMessage', -1, { args = { '^2[OD]', GetPlayerName(source) .. ' joined Team ' .. Config.Teams[team].name .. ' as ' .. role:upper() } })
    CheckAutoStart()
end

function LeaveLobby(source)
    local data = GameState.players[source]
    if not data then return end
    
    for i, pid in ipairs(GameState.teams[data.team]) do
        if pid == source then table.remove(GameState.teams[data.team], i) break end
    end
    GameState.players[source] = nil
    TriggerClientEvent('od:leaveLobby', source)
    BroadcastLobbyState()
    
    if #GameState.teams[1] == 0 and #GameState.teams[2] == 0 then
        GameState.phase = 'idle'
    end
end

function SetReady(source)
    if not GameState.players[source] then return end
    GameState.players[source].ready = true
    BroadcastLobbyState()
    CheckAutoStart()
end

function SetVehicle(source, idx)
    if not GameState.players[source] then return end
    if GameState.players[source].role == 'runner' then return end
    GameState.players[source].vehicle = math.max(1, math.min(3, idx))
end

function BroadcastLobbyState()
    local green, purple = {}, {}
    for _, pid in ipairs(GameState.teams[1]) do
        local p = GameState.players[pid]
        if p then table.insert(green, { name = p.name, role = p.role, ready = p.ready }) end
    end
    for _, pid in ipairs(GameState.teams[2]) do
        local p = GameState.players[pid]
        if p then table.insert(purple, { name = p.name, role = p.role, ready = p.ready }) end
    end
    for pid, _ in pairs(GameState.players) do
        TriggerClientEvent('od:updateLobby', pid, green, purple)
    end
end

function CheckAutoStart()
    if GameState.phase ~= 'lobby' then return end
    local allReady = true
    for _, data in pairs(GameState.players) do
        if not data.ready then allReady = false break end
    end
    if allReady and (next(GameState.players) ~= nil) then
        StartCountdown()
    end
end

function StartCountdown()
    if GameState.phase == 'countdown' then return end
    GameState.phase = 'countdown'
    GameState.countdown = Config.Settings.lobbyCountdown
    
    CreateThread(function()
        while GameState.countdown > 0 and GameState.phase == 'countdown' do
            for pid, _ in pairs(GameState.players) do
                TriggerClientEvent('od:lobbyCountdown', pid, GameState.countdown)
            end
            Wait(1000)
            GameState.countdown = GameState.countdown - 1
        end
        if GameState.phase == 'countdown' then StartRace() end
    end)
end

function StartRace()
    GameState.phase = 'racing'
    
    for pid, data in pairs(GameState.players) do
        local slotIndex = 1
        for i, p in ipairs(GameState.teams[data.team]) do
            if p == pid then slotIndex = i break end
        end
        local vehicle = data.role == 'runner' and Config.Vehicles.runner.model or Config.Vehicles.blocker[data.vehicle].model
        TriggerClientEvent('od:startRace', pid, data.team, slotIndex, vehicle, data.role)
    end
end

function EndRace(winningTeam)
    if winningTeam > 0 then
        TriggerClientEvent('chat:addMessage', -1, { args = { '^2[OD]', 'Team ' .. Config.Teams[winningTeam].name .. ' WINS!' } })
    end
    for pid, _ in pairs(GameState.players) do
        TriggerClientEvent('od:endRace', pid)
    end
    GameState.phase = 'idle'
    GameState.players = {}
    GameState.teams = { [1] = {}, [2] = {} }
end

-- Events
RegisterNetEvent('od:ready', function() SetReady(source) end)
RegisterNetEvent('od:leave', function() LeaveLobby(source) end)
RegisterNetEvent('od:selectCar', function(car) SetVehicle(source, car) end)
RegisterNetEvent('od:checkpointReached', function(idx, total)
    local data = GameState.players[source]
    if data and data.role == 'runner' and idx >= total then
        EndRace(data.team)
    end
end)

RegisterNetEvent('od:saveMap', function(mapData)
    if not IsAdmin(source) then return end
    SaveResourceFile(GetCurrentResourceName(), 'maps/' .. mapData.name .. '.json', json.encode(mapData), -1)
    TriggerClientEvent('chat:addMessage', source, { args = { '^2[OD]', 'Map saved: ' .. mapData.name } })
end)

-- Announcements
CreateThread(function()
    Wait(5000)
    TriggerClientEvent('chat:addMessage', -1, { args = { '^3[MINIGAMES]', 'Offense Defense available! /join od' } })
    while true do
        Wait(Config.Settings.announcementInterval)
        if GameState.phase == 'idle' then
            TriggerClientEvent('chat:addMessage', -1, { args = { '^3[MINIGAMES]', 'Offense Defense available! /join od' } })
        end
    end
end)
