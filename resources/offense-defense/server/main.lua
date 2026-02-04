-- State
GameState = {
    phase = 'idle',
    players = {},
    teams = { [1] = {}, [2] = {} },
    countdown = nil,
    currentMap = nil,
}

OnlinePlayers = {}  -- [source] = { name, role }
CurrentGameId = nil -- For game history tracking
LoadedMap = nil -- Currently loaded map data

-- Get all available maps
function GetAllMaps()
    local maps = {}
    local resourceName = GetCurrentResourceName()
    -- Check for od1, od2, od3, etc. up to od99
    for i = 1, 99 do
        local mapName = 'od' .. i
        local data = LoadResourceFile(resourceName, 'maps/' .. mapName .. '.json')
        if data then
            table.insert(maps, mapName)
        end
    end
    return maps
end

-- Get next available map number
function GetNextMapNumber()
    local maps = GetAllMaps()
    local highest = 0
    for _, mapName in ipairs(maps) do
        local num = tonumber(mapName:match('od(%d+)'))
        if num and num > highest then
            highest = num
        end
    end
    return highest + 1
end

-- Load map from file
function LoadMap(mapName)
    local data = LoadResourceFile(GetCurrentResourceName(), 'maps/' .. mapName .. '.json')
    if data then
        LoadedMap = json.decode(data)
        LoadedMap.name = mapName
        print('[OD] Loaded map: ' .. mapName)
        return true
    end
    return false
end

-- Load a random map
function LoadRandomMap()
    local maps = GetAllMaps()
    if #maps > 0 then
        local randomMap = maps[math.random(#maps)]
        return LoadMap(randomMap)
    end
    return false
end

-- Load random map on start
CreateThread(function()
    Wait(100)
    if not LoadRandomMap() then
        print('[OD] No maps found, using hardcoded spawns')
    end
end)

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
    -- Use points-sorted list if available
    local list = exports['offense-defense']:GetOnlinePlayersWithPoints()
    if not list or #list == 0 then
        -- Fallback without points
        list = {}
        for src, data in pairs(OnlinePlayers) do
            table.insert(list, { name = data.name, role = data.role, points = 0, rank = 0 })
        end
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
    local nextNum = GetNextMapNumber()
    local mapName = 'od' .. nextNum
    TriggerClientEvent('od:startEditor', source, mapName)
    TriggerClientEvent('chat:addMessage', source, { args = { '^2[OD]', 'Creating new map: ' .. mapName } })
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
    
    -- Check if team already has a runner
    local hasRunner = false
    for _, pid in ipairs(GameState.teams[team]) do
        if GameState.players[pid] and GameState.players[pid].role == 'runner' then
            hasRunner = true
            break
        end
    end
    local role = hasRunner and 'blocker' or 'runner'
    GameState.players[source] = { team = team, role = role, ready = false, vehicle = 1, name = GetPlayerName(source) }
    table.insert(GameState.teams[team], source)
    
    if GameState.phase == 'idle' then
        GameState.phase = 'lobby'
        -- Load a random map for this lobby
        LoadRandomMap()
        if LoadedMap then
            TriggerClientEvent('chat:addMessage', -1, { args = { '^3[OD]', 'Map: ' .. LoadedMap.name } })
        end
    end
    
    local slotIndex = #GameState.teams[team]
    TriggerClientEvent('od:joinLobby', source, team, role, slotIndex, LoadedMap)
    BroadcastLobbyState()
    BroadcastPotPreview()
    
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
    BroadcastPotPreview()
end

function BroadcastPotPreview()
    -- Calculate estimated pot (bonus + all wagers)
    local totalPot = Config.Points.bonusPot or 0
    local wagers = {}

    for pid, data in pairs(GameState.players) do
        local wager = exports['offense-defense']:CalculateWager(pid)
        wagers[pid] = wager
        totalPot = totalPot + wager
    end

    -- Send to each player with their team size for win calculation
    for pid, data in pairs(GameState.players) do
        local teamSize = #GameState.teams[data.team]
        TriggerClientEvent('od:updatePot', pid, totalPot, wagers[pid] or 0, teamSize)
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

    -- Collect wagers into pot NOW (not during countdown, so players can't leave after paying)
    local pot = exports['offense-defense']:CollectPot()

    -- Broadcast final pot amount
    for pid, _ in pairs(GameState.players) do
        local wager = exports['offense-defense']:GetPlayerWager(pid)
        TriggerClientEvent('od:updatePot', pid, pot, wager)
    end

    -- Create game history record
    CurrentGameId = exports['offense-defense']:CreateGameRecord(GameState.currentMap)

    for pid, data in pairs(GameState.players) do
        local slotIndex = 1
        for i, p in ipairs(GameState.teams[data.team]) do
            if p == pid then slotIndex = i break end
        end
        local vehicle = data.role == 'runner' and Config.Vehicles.runner.model or Config.Vehicles.blocker[data.vehicle].model
        TriggerClientEvent('od:startRace', pid, data.team, slotIndex, vehicle, data.role, LoadedMap)
    end
end

function EndRace(winningTeam)
    -- Distribute pot and get results
    local results = {}
    if winningTeam > 0 then
        results = exports['offense-defense']:DistributePot(winningTeam, CurrentGameId)
        exports['offense-defense']:EndGameRecord(CurrentGameId, winningTeam)
        TriggerClientEvent('chat:addMessage', -1, { args = { '^2[OD]', 'Team ' .. Config.Teams[winningTeam].name .. ' WINS!' } })
    end

    -- Send results to each player with their personal +/- change
    for pid, _ in pairs(GameState.players) do
        local playerResult = results[pid] or { won = false, change = 0, newTotal = 0 }
        TriggerClientEvent('od:showResults', pid, {
            won = playerResult.won,
            change = playerResult.change,
            newTotal = playerResult.newTotal,
            winningTeam = winningTeam,
            teamName = winningTeam > 0 and Config.Teams[winningTeam].name or 'None'
        })
    end

    -- Delayed cleanup
    SetTimeout(8000, function()
        for pid, _ in pairs(GameState.players) do
            TriggerClientEvent('od:endRace', pid)
        end
        GameState.phase = 'idle'
        GameState.players = {}
        GameState.teams = { [1] = {}, [2] = {} }
        CurrentGameId = nil
        BroadcastOnlinePlayers()
    end)
end

-- Events
RegisterNetEvent('od:ready', function() SetReady(source) end)
RegisterNetEvent('od:leave', function() LeaveLobby(source) end)
RegisterNetEvent('od:selectCar', function(car) SetVehicle(source, car) end)

RegisterNetEvent('od:switchTeam', function(newTeam)
    local src = source
    local data = GameState.players[src]
    if not data then return end
    if data.ready then return end -- Can't switch if ready
    if newTeam == data.team then return end -- Already on this team
    if #GameState.teams[newTeam] >= Config.Settings.maxTeamSize then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[OD]', 'Team is full!' } })
        return
    end

    -- Remove from old team
    for i, pid in ipairs(GameState.teams[data.team]) do
        if pid == src then table.remove(GameState.teams[data.team], i) break end
    end

    -- Check if runner spot available on new team
    local hasRunner = false
    for _, pid in ipairs(GameState.teams[newTeam]) do
        if GameState.players[pid] and GameState.players[pid].role == 'runner' then
            hasRunner = true
            break
        end
    end

    -- Add to new team
    data.team = newTeam
    data.role = hasRunner and 'blocker' or data.role
    table.insert(GameState.teams[newTeam], src)

    -- Update client
    local slotIndex = #GameState.teams[newTeam]
    TriggerClientEvent('od:updatePlayer', src, newTeam, data.role, slotIndex)
    BroadcastLobbyState()
end)

RegisterNetEvent('od:switchRole', function(newRole)
    local src = source
    local data = GameState.players[src]
    if not data then return end
    if data.ready then return end -- Can't switch if ready
    if newRole == data.role then return end

    if newRole == 'runner' then
        -- Check if team already has a runner
        for _, pid in ipairs(GameState.teams[data.team]) do
            if pid ~= src and GameState.players[pid] and GameState.players[pid].role == 'runner' then
                TriggerClientEvent('chat:addMessage', src, { args = { '^1[OD]', 'Team already has a runner!' } })
                return
            end
        end
    end

    data.role = newRole
    data.vehicle = 1 -- Reset vehicle selection
    local slotIndex = 1
    for i, pid in ipairs(GameState.teams[data.team]) do
        if pid == src then slotIndex = i break end
    end
    TriggerClientEvent('od:updatePlayer', src, data.team, data.role, slotIndex)
    BroadcastLobbyState()
end)
RegisterNetEvent('od:checkpointReached', function(idx, total)
    local data = GameState.players[source]
    if data and data.role == 'runner' and idx >= total then
        EndRace(data.team)
    end
end)

-- Track runner progress for position display
RegisterNetEvent('od:updateProgress', function(checkpoint, distance)
    local data = GameState.players[source]
    if not data or data.role ~= 'runner' then return end

    data.checkpoint = checkpoint
    data.distance = distance

    -- Calculate positions
    local runners = {}
    for pid, p in pairs(GameState.players) do
        if p.role == 'runner' then
            table.insert(runners, {
                team = Config.Teams[p.team].name,
                checkpoint = p.checkpoint or 1,
                distance = p.distance or 9999
            })
        end
    end

    -- Sort by checkpoint (desc) then distance (asc)
    table.sort(runners, function(a, b)
        if a.checkpoint ~= b.checkpoint then
            return a.checkpoint > b.checkpoint
        end
        return a.distance < b.distance
    end)

    -- Broadcast to all players in race
    for pid, _ in pairs(GameState.players) do
        TriggerClientEvent('od:updatePositions', pid, runners)
    end
end)

RegisterNetEvent('od:saveMap', function(mapData)
    if not IsAdmin(source) then return end
    SaveResourceFile(GetCurrentResourceName(), 'maps/' .. mapData.name .. '.json', json.encode(mapData), -1)
    TriggerClientEvent('chat:addMessage', source, { args = { '^2[OD]', 'Map saved: ' .. mapData.name } })
end)

-- Request online players list (for Tab toggle)
RegisterNetEvent('od:requestOnlinePlayers', function()
    BroadcastOnlinePlayers()
end)

-- Request game players list (for Tab toggle)
RegisterNetEvent('od:requestGamePlayers', function()
    local src = source
    if not GameState.players[src] then return end

    local list = {}
    for pid, data in pairs(GameState.players) do
        local points = exports['offense-defense']:GetPlayerPoints(pid)
        table.insert(list, {
            name = data.name,
            role = data.role,
            team = Config.Teams[data.team].name:lower(),
            points = points or 0,
            rank = 0
        })
    end

    -- Sort by checkpoint progress (runners) or just alphabetically
    table.sort(list, function(a, b)
        return a.name < b.name
    end)

    -- Assign ranks
    for i, p in ipairs(list) do
        p.rank = i
    end

    TriggerClientEvent('od:updateGamePlayers', src, list)
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

-- Get minigames state for browser
function GetMinigamesState()
    local playerCount = 0
    local playerList = {}
    local checkpointStr = ''
    
    for pid, data in pairs(GameState.players) do
        playerCount = playerCount + 1
        table.insert(playerList, {
            name = data.name,
            team = Config.Teams[data.team].name:lower()
        })
        -- Get checkpoint progress for leading runner
        if data.role == 'runner' and data.checkpoint then
            local total = LoadedMap and LoadedMap.checkpoints and #LoadedMap.checkpoints or 4
            if checkpointStr == '' or (data.checkpoint or 0) > 0 then
                checkpointStr = (data.checkpoint - 1) .. '/' .. total
            end
        end
    end
    
    return {
        od = {
            status = GameState.phase,
            playerCount = playerCount,
            maxPlayers = Config.Settings.maxTeamSize * 2,
            players = playerList,
            checkpoint = checkpointStr ~= '' and checkpointStr or nil
        }
    }
end

-- Broadcast minigames state to all online players
function BroadcastMinigamesState()
    local state = GetMinigamesState()
    TriggerClientEvent('od:updateMinigames', -1, state)
end

-- Periodic minigames state broadcast
CreateThread(function()
    Wait(2000)
    while true do
        BroadcastMinigamesState()
        Wait(1000) -- Update every second
    end
end)

-- Request minigames state (for when player first loads)
RegisterNetEvent('od:requestMinigames', function()
    local state = GetMinigamesState()
    TriggerClientEvent('od:updateMinigames', source, state)
end)

-- Join from browser click
RegisterNetEvent('od:joinFromBrowser', function()
    JoinLobby(source)
end)

-- Broadcast player blip data during race
CreateThread(function()
    while true do
        Wait(500) -- Update every 500ms
        if GameState.phase == 'racing' then
            local blipData = {}
            for pid, data in pairs(GameState.players) do
                table.insert(blipData, {
                    serverId = pid,
                    team = data.team,
                    role = data.role
                })
            end
            -- Send to all players in the race
            for pid, _ in pairs(GameState.players) do
                TriggerClientEvent('od:updatePlayerBlips', pid, blipData)
            end
        end
    end
end)

-- Clear blips when race ends (add to EndRace cleanup)
local function ClearBlipsForAll()
    for pid, _ in pairs(GameState.players) do
        TriggerClientEvent('od:clearBlips', pid)
    end
end

-- Teleport to player command
RegisterCommand('tp', function(source, args)
    if #args < 1 then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[TP]', 'Usage: /tp <player name>' } })
        return
    end
    
    local targetName = table.concat(args, ' ')
    local targetPlayer = nil
    
    -- Find player by name (case insensitive partial match)
    for _, pid in ipairs(GetPlayers()) do
        local name = GetPlayerName(tonumber(pid))
        if name and name:lower():find(targetName:lower(), 1, true) then
            targetPlayer = tonumber(pid)
            break
        end
    end
    
    if not targetPlayer then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[TP]', 'Player not found: ' .. targetName } })
        return
    end
    
    if targetPlayer == source then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[TP]', 'Cannot teleport to yourself!' } })
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    local coords = GetEntityCoords(targetPed)
    
    TriggerClientEvent('od:teleportTo', source, coords.x, coords.y, coords.z)
    TriggerClientEvent('chat:addMessage', source, { args = { '^2[TP]', 'Teleported to ' .. GetPlayerName(targetPlayer) } })
end, false)
