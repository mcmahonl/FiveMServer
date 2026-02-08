-- Running Back - Server Side
-- Football-inspired mode: Runner (Panto) reaches the end zone while Blockers protect
-- Best of 7: first team to 4 round wins takes the match
-- Teams alternate offense/defense each round. Offense = 1 runner + blockers, Defense = all blockers.

RBGameState = {
    phase = 'idle', -- idle, lobby, countdown, playing, celebration
    players = {},
    teams = { [1] = {}, [2] = {} },
    countdown = nil,
    currentMap = nil,
    scores = { [1] = 0, [2] = 0 },
    round = 0,
    offenseTeam = nil, -- which team is on offense this round
    runnerIdx = { [1] = 0, [2] = 0 }, -- rotating index for runner selection per team
}

RBCurrentGameId = nil
RBLoadedMap = nil
RBCurrentPot = 0
RBCurrentWagers = {}

-- Map management
function RBGetAllMaps()
    local maps = {}
    local resourceName = GetCurrentResourceName()
    for i = 1, 99 do
        local mapName = 'rb' .. i
        local data = LoadResourceFile(resourceName, 'maps/' .. mapName .. '.json')
        if data then
            table.insert(maps, mapName)
        end
    end
    return maps
end

function RBGetNextMapNumber()
    local maps = RBGetAllMaps()
    local highest = 0
    for _, mapName in ipairs(maps) do
        local num = tonumber(mapName:match('rb(%d+)'))
        if num and num > highest then highest = num end
    end
    return highest + 1
end

function RBLoadMap(mapName)
    local data = LoadResourceFile(GetCurrentResourceName(), 'maps/' .. mapName .. '.json')
    if data then
        RBLoadedMap = json.decode(data)
        RBLoadedMap.name = mapName
        print('[RB] Loaded map: ' .. mapName)
        return true
    end
    return false
end

function RBLoadRandomMap()
    local maps = RBGetAllMaps()
    if #maps > 0 then
        return RBLoadMap(maps[math.random(#maps)])
    end
    return false
end

CreateThread(function()
    Wait(100)
    if not RBLoadRandomMap() then
        print('[RB] No maps found, using hardcoded spawns')
    end
end)

-- Commands
RegisterCommand('rbedit', function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[RB]', 'Admins only!' } })
        return
    end
    local nextNum = RBGetNextMapNumber()
    local mapName = 'rb' .. nextNum
    TriggerClientEvent('rb:startEditor', source, mapName)
    TriggerClientEvent('chat:addMessage', source, { args = { '^6[RB]', 'Creating new map: ' .. mapName } })
end, false)

RegisterCommand('rbstart', function(source)
    if Config.RB.Settings.allowSoloTest or IsAdmin(source) then
        RBStartRace()
    end
end, false)

RegisterCommand('rbstop', function(source)
    if IsAdmin(source) then
        RBEndRace(0)
    end
end, false)

-- Lobby
function RBJoinLobby(source)
    if GameState.players[source] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[RB]', 'Leave Offense Defense first!' } })
        return
    end
    if SumoGameState and SumoGameState.players[source] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[RB]', 'Leave Sumo first!' } })
        return
    end
    if RBGameState.phase == 'playing' or RBGameState.phase == 'celebration' then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[RB]', 'Game in progress!' } })
        return
    end
    if RBGameState.players[source] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[RB]', 'Already in lobby!' } })
        return
    end

    local team = #RBGameState.teams[1] <= #RBGameState.teams[2] and 1 or 2
    if #RBGameState.teams[team] >= Config.RB.Settings.maxTeamSize then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[RB]', 'Lobby full!' } })
        return
    end

    -- Everyone is a blocker in lobby; runner is auto-assigned per round
    RBGameState.players[source] = { team = team, role = 'blocker', ready = false, vehicle = 1, name = GetPlayerName(source) }
    table.insert(RBGameState.teams[team], source)

    if RBGameState.phase == 'idle' then
        RBGameState.phase = 'lobby'
        RBLoadRandomMap()
        if RBLoadedMap then
            TriggerClientEvent('chat:addMessage', -1, { args = { '^3[RB]', 'Map: ' .. RBLoadedMap.name } })
        end
    end

    local slotIndex = #RBGameState.teams[team]
    TriggerClientEvent('rb:joinLobby', source, team, 'blocker', slotIndex, RBLoadedMap)
    RBBroadcastLobbyState()
    RBBroadcastPotPreview()

    TriggerClientEvent('chat:addMessage', -1, { args = { '^6[RB]', GetPlayerName(source) .. ' joined Team ' .. Config.Teams[team].name } })
    RBCheckAutoStart()
end

function RBLeaveLobby(source)
    local data = RBGameState.players[source]
    if not data then return end

    for i, pid in ipairs(RBGameState.teams[data.team]) do
        if pid == source then table.remove(RBGameState.teams[data.team], i) break end
    end
    RBGameState.players[source] = nil
    TriggerClientEvent('rb:leaveLobby', source)
    RBBroadcastLobbyState()

    if #RBGameState.teams[1] == 0 and #RBGameState.teams[2] == 0 then
        RBGameState.phase = 'idle'
    end
end

function RBSetReady(source)
    if not RBGameState.players[source] then return end
    RBGameState.players[source].ready = true
    RBBroadcastLobbyState()
    RBCheckAutoStart()
end

function RBSetVehicle(source, idx)
    if not RBGameState.players[source] then return end
    -- Car selection is saved per player and persists throughout the game
    RBGameState.players[source].vehicle = math.max(1, math.min(3, idx))
end

function RBBroadcastLobbyState()
    local green, purple = {}, {}
    for _, pid in ipairs(RBGameState.teams[1]) do
        local p = RBGameState.players[pid]
        if p then table.insert(green, { name = p.name, role = p.role, ready = p.ready }) end
    end
    for _, pid in ipairs(RBGameState.teams[2]) do
        local p = RBGameState.players[pid]
        if p then table.insert(purple, { name = p.name, role = p.role, ready = p.ready }) end
    end
    for pid, _ in pairs(RBGameState.players) do
        TriggerClientEvent('rb:updateLobby', pid, green, purple)
    end
    RBBroadcastPotPreview()
end

function RBBroadcastPotPreview()
    local totalPot = Config.Points.bonusPot or 0
    local wagers = {}
    for pid, data in pairs(RBGameState.players) do
        local wager = CalculateWager(pid)
        wagers[pid] = wager
        totalPot = totalPot + wager
    end
    for pid, data in pairs(RBGameState.players) do
        local teamSize = #RBGameState.teams[data.team]
        TriggerClientEvent('rb:updatePot', pid, totalPot, wagers[pid] or 0, teamSize)
    end
end

function RBCheckAutoStart()
    if RBGameState.phase ~= 'lobby' then return end
    local allReady = true
    for _, data in pairs(RBGameState.players) do
        if not data.ready then allReady = false break end
    end
    if allReady and (next(RBGameState.players) ~= nil) then
        RBStartCountdown()
    end
end

function RBStartCountdown()
    if RBGameState.phase == 'countdown' then return end
    RBGameState.phase = 'countdown'
    RBGameState.countdown = Config.RB.Settings.lobbyCountdown

    CreateThread(function()
        while RBGameState.countdown > 0 and RBGameState.phase == 'countdown' do
            for pid, _ in pairs(RBGameState.players) do
                TriggerClientEvent('rb:lobbyCountdown', pid, RBGameState.countdown)
            end
            Wait(1000)
            RBGameState.countdown = RBGameState.countdown - 1
        end
        if RBGameState.phase == 'countdown' then RBStartRace() end
    end)
end

-- ============================================================
-- RACE / ROUND MANAGEMENT
-- ============================================================
function RBStartRace()
    RBGameState.phase = 'playing'
    RBGameState.scores = { [1] = 0, [2] = 0 }
    RBGameState.round = 0
    RBGameState.runnerIdx = { [1] = 0, [2] = 0 }

    local pot = RBCollectPot()
    for pid, _ in pairs(RBGameState.players) do
        local wager = RBCurrentWagers[pid] or CalculateWager(pid)
        TriggerClientEvent('rb:updatePot', pid, pot, wager)
    end

    RBCurrentGameId = RBCreateGameRecord(RBLoadedMap and RBLoadedMap.name or 'unknown')
    RBStartRound(true)
end

function RBStartRound(isFirst)
    RBGameState.round = RBGameState.round + 1
    RBGameState.phase = 'playing'

    -- Alternate offense: odd rounds = team 1, even rounds = team 2
    RBGameState.offenseTeam = ((RBGameState.round - 1) % 2) + 1
    local defenseTeam = RBGameState.offenseTeam == 1 and 2 or 1

    -- If offense team is empty, defense auto-wins this round
    local offensePlayers = RBGameState.teams[RBGameState.offenseTeam]
    if #offensePlayers == 0 then
        TriggerClientEvent('chat:addMessage', -1, { args = { '^6[RB]', 'No players on offense - defense wins round ' .. RBGameState.round .. '!' } })
        SetTimeout(1000, function()
            RBRoundWon(defenseTeam)
        end)
        return
    end

    -- Pick runner from offense team (rotating among team members)
    RBGameState.runnerIdx[RBGameState.offenseTeam] = (RBGameState.runnerIdx[RBGameState.offenseTeam] % #offensePlayers) + 1
    local runnerPid = offensePlayers[RBGameState.runnerIdx[RBGameState.offenseTeam]]

    -- Assign round roles: runner for the picked player, blocker for everyone else
    for pid, data in pairs(RBGameState.players) do
        if pid == runnerPid then
            data.roundRole = 'runner'
        else
            data.roundRole = 'blocker'
        end
        data.distance = nil
    end

    -- Calculate slot indices: runner gets slot 1 on offense
    local offenseSlots = {}
    offenseSlots[runnerPid] = 1
    local blockerSlot = 2
    for _, pid in ipairs(offensePlayers) do
        if pid ~= runnerPid then
            offenseSlots[pid] = blockerSlot
            blockerSlot = blockerSlot + 1
        end
    end

    local defensePlayers = RBGameState.teams[defenseTeam]
    local defenseSlots = {}
    for i, pid in ipairs(defensePlayers) do
        defenseSlots[pid] = i
    end

    -- Announce the round
    local offTeamName = Config.Teams[RBGameState.offenseTeam].name
    local runnerName = RBGameState.players[runnerPid] and RBGameState.players[runnerPid].name or 'Unknown'
    TriggerClientEvent('chat:addMessage', -1, { args = { '^6[RB]', 'Round ' .. RBGameState.round .. ': ' .. offTeamName .. ' on OFFENSE (Runner: ' .. runnerName .. ')' } })

    -- Send events to all players
    for pid, data in pairs(RBGameState.players) do
        local slotIndex
        if data.team == RBGameState.offenseTeam then
            slotIndex = offenseSlots[pid] or 1
        else
            slotIndex = defenseSlots[pid] or 1
        end

        local vehicle = data.roundRole == 'runner' and Config.RB.Vehicles.runner.model or Config.RB.Vehicles.blocker[data.vehicle].model

        if isFirst then
            TriggerClientEvent('rb:startRace', pid, data.team, slotIndex, vehicle, data.roundRole, RBLoadedMap, RBGameState.scores, RBGameState.offenseTeam)
        else
            TriggerClientEvent('rb:nextRound', pid, data.team, slotIndex, RBGameState.round, RBGameState.scores, data.roundRole, vehicle, RBGameState.offenseTeam)
        end
    end

    -- Start round timer
    RBStartRoundTimer()
end

function RBStartRoundTimer()
    local timeLeft = Config.RB.Settings.roundTimeLimit

    CreateThread(function()
        while timeLeft > 0 and RBGameState.phase == 'playing' do
            for pid, _ in pairs(RBGameState.players) do
                TriggerClientEvent('rb:updateRoundTimer', pid, timeLeft)
            end
            Wait(1000)
            timeLeft = timeLeft - 1
        end

        -- Time's up - defense wins the round
        if RBGameState.phase == 'playing' then
            local defenseTeam = RBGameState.offenseTeam == 1 and 2 or 1
            TriggerClientEvent('chat:addMessage', -1, { args = { '^6[RB]', 'TIME\'S UP! Defense wins the round!' } })
            RBRoundWon(defenseTeam)
        end
    end)
end

function RBRoundWon(winningTeam)
    if RBGameState.phase ~= 'playing' then return end
    RBGameState.phase = 'celebration'
    RBGameState.scores[winningTeam] = RBGameState.scores[winningTeam] + 1

    local matchOver = RBGameState.scores[winningTeam] >= Config.RB.Settings.roundsToWin

    TriggerClientEvent('chat:addMessage', -1, { args = { '^6[RB]', 'Team ' .. Config.Teams[winningTeam].name .. ' SCORES! (' .. RBGameState.scores[1] .. ' - ' .. RBGameState.scores[2] .. ')' } })

    for pid, data in pairs(RBGameState.players) do
        TriggerClientEvent('rb:roundResult', pid, {
            winningTeam = winningTeam,
            teamName = Config.Teams[winningTeam].name,
            greenScore = RBGameState.scores[1],
            purpleScore = RBGameState.scores[2],
            matchOver = matchOver,
            won = data.team == winningTeam,
        })
    end

    SetTimeout(Config.RB.Settings.celebrationTime * 1000, function()
        if matchOver then
            RBEndRace(winningTeam)
        else
            RBStartRound(false)
        end
    end)
end

function RBEndRace(winningTeam)
    local results = {}
    if winningTeam > 0 then
        results = RBDistributePot(winningTeam, RBCurrentGameId)
        RBEndGameRecord(RBCurrentGameId, winningTeam)
        TriggerClientEvent('chat:addMessage', -1, { args = { '^6[RB]', 'Team ' .. Config.Teams[winningTeam].name .. ' WINS THE MATCH! (' .. RBGameState.scores[1] .. ' - ' .. RBGameState.scores[2] .. ')' } })
    end

    for pid, _ in pairs(RBGameState.players) do
        local playerResult = results[pid] or { won = false, change = 0, newTotal = 0 }
        TriggerClientEvent('rb:showResults', pid, {
            won = playerResult.won,
            change = playerResult.change,
            newTotal = playerResult.newTotal,
            winningTeam = winningTeam,
            teamName = winningTeam > 0 and Config.Teams[winningTeam].name or 'None',
            greenScore = RBGameState.scores[1],
            purpleScore = RBGameState.scores[2],
        })
    end

    SetTimeout(8000, function()
        for pid, _ in pairs(RBGameState.players) do
            TriggerClientEvent('rb:endRace', pid)
        end
        RBGameState.phase = 'idle'
        RBGameState.players = {}
        RBGameState.teams = { [1] = {}, [2] = {} }
        RBGameState.scores = { [1] = 0, [2] = 0 }
        RBGameState.round = 0
        RBGameState.offenseTeam = nil
        RBCurrentGameId = nil
        BroadcastOnlinePlayers()
    end)
end

-- Pot management
function RBCollectPot()
    RBCurrentPot = Config.Points.bonusPot or 0
    RBCurrentWagers = {}
    for pid, data in pairs(RBGameState.players) do
        local wager = CalculateWager(pid)
        RBCurrentWagers[pid] = wager
        RBCurrentPot = RBCurrentPot + wager
        if PlayerCache[pid] then
            PlayerCache[pid].points = PlayerCache[pid].points - wager
            MySQL.update('UPDATE players SET points = points - ? WHERE id = ?', { wager, PlayerCache[pid].id })
        end
    end
    BroadcastOnlinePlayers()
    return RBCurrentPot
end

function RBDistributePot(winningTeam, gameId)
    local winners = {}
    local losers = {}
    for pid, data in pairs(RBGameState.players) do
        if data.team == winningTeam then
            table.insert(winners, pid)
        else
            table.insert(losers, pid)
        end
    end

    local winningsEach = #winners > 0 and math.floor(RBCurrentPot / #winners) or 0
    local results = {}

    for _, pid in ipairs(winners) do
        local wager = RBCurrentWagers[pid] or 0
        local change = winningsEach - wager
        if PlayerCache[pid] then
            PlayerCache[pid].points = PlayerCache[pid].points + winningsEach
            PlayerCache[pid].wins = PlayerCache[pid].wins + 1
            PlayerCache[pid].games_played = PlayerCache[pid].games_played + 1
            MySQL.update('UPDATE players SET points = points + ?, wins = wins + 1, games_played = games_played + 1 WHERE id = ?',
                { winningsEach, PlayerCache[pid].id })
            if gameId then
                MySQL.insert('INSERT INTO game_participants (game_id, player_id, team, role, wager, points_change) VALUES (?, ?, ?, ?, ?, ?)',
                    { gameId, PlayerCache[pid].id, RBGameState.players[pid].team, RBGameState.players[pid].role, wager, change })
            end
        end
        results[pid] = { won = true, change = change, newTotal = PlayerCache[pid] and PlayerCache[pid].points or 0 }
    end

    for _, pid in ipairs(losers) do
        local wager = RBCurrentWagers[pid] or 0
        local change = -wager
        if PlayerCache[pid] then
            PlayerCache[pid].losses = PlayerCache[pid].losses + 1
            PlayerCache[pid].games_played = PlayerCache[pid].games_played + 1
            MySQL.update('UPDATE players SET losses = losses + 1, games_played = games_played + 1 WHERE id = ?',
                { PlayerCache[pid].id })
            if gameId then
                MySQL.insert('INSERT INTO game_participants (game_id, player_id, team, role, wager, points_change) VALUES (?, ?, ?, ?, ?, ?)',
                    { gameId, PlayerCache[pid].id, RBGameState.players[pid].team, RBGameState.players[pid].role, wager, change })
            end
        end
        results[pid] = { won = false, change = change, newTotal = PlayerCache[pid] and PlayerCache[pid].points or 0 }
    end

    RBCurrentPot = 0
    RBCurrentWagers = {}
    return results
end

function RBCreateGameRecord(mapName)
    if not MySQL then return nil end
    return MySQL.insert.await('INSERT INTO game_history (game_type, map_name, pot_total) VALUES (?, ?, ?)',
        { 'running-back', mapName or 'unknown', RBCurrentPot })
end

function RBEndGameRecord(gameId, winningTeam)
    if gameId then
        MySQL.update('UPDATE game_history SET winning_team = ?, ended_at = NOW() WHERE id = ?', { winningTeam, gameId })
    end
end

-- Events
RegisterNetEvent('rb:ready', function() RBSetReady(source) end)
RegisterNetEvent('rb:leave', function() RBLeaveLobby(source) end)
RegisterNetEvent('rb:selectCar', function(car) RBSetVehicle(source, car) end)

RegisterNetEvent('rb:switchTeam', function(newTeam)
    local src = source
    local data = RBGameState.players[src]
    if not data then return end
    if data.ready then return end
    if newTeam == data.team then return end
    if #RBGameState.teams[newTeam] >= Config.RB.Settings.maxTeamSize then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[RB]', 'Team is full!' } })
        return
    end

    for i, pid in ipairs(RBGameState.teams[data.team]) do
        if pid == src then table.remove(RBGameState.teams[data.team], i) break end
    end

    data.team = newTeam
    table.insert(RBGameState.teams[newTeam], src)

    local slotIndex = #RBGameState.teams[newTeam]
    TriggerClientEvent('rb:updatePlayer', src, newTeam, 'blocker', slotIndex)
    RBBroadcastLobbyState()
end)

-- Roles are auto-assigned per round, no manual switching
RegisterNetEvent('rb:switchRole', function(newRole)
    return
end)

-- Runner reached the end zone
RegisterNetEvent('rb:reachedEndZone', function()
    local data = RBGameState.players[source]
    if data and data.roundRole == 'runner' then
        RBRoundWon(data.team)
    end
end)

-- Track runner distance to end zone
RegisterNetEvent('rb:updateProgress', function(distance)
    local data = RBGameState.players[source]
    if not data or data.roundRole ~= 'runner' then return end

    data.distance = distance

    local runners = {}
    for pid, p in pairs(RBGameState.players) do
        if p.roundRole == 'runner' then
            table.insert(runners, {
                team = Config.Teams[p.team].name,
                distance = p.distance or 9999
            })
        end
    end

    for pid, _ in pairs(RBGameState.players) do
        TriggerClientEvent('rb:updatePositions', pid, runners)
    end
end)

RegisterNetEvent('rb:requestGamePlayers', function()
    local src = source
    if not RBGameState.players[src] then return end
    local list = {}
    for pid, data in pairs(RBGameState.players) do
        local points = GetPlayerPoints(pid)
        table.insert(list, {
            name = data.name,
            role = data.roundRole or data.role,
            team = Config.Teams[data.team].name:lower(),
            points = points or 0,
            rank = 0
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    for i, p in ipairs(list) do p.rank = i end
    TriggerClientEvent('rb:updateGamePlayers', src, list)
end)

RegisterNetEvent('rb:joinFromBrowser', function()
    RBJoinLobby(source)
end)

-- Save map from RB editor
RegisterNetEvent('rb:saveMap', function(mapData)
    if not IsAdmin(source) then return end
    SaveResourceFile(GetCurrentResourceName(), 'maps/' .. mapData.name .. '.json', json.encode(mapData), -1)
    TriggerClientEvent('chat:addMessage', source, { args = { '^6[RB]', 'Map saved: ' .. mapData.name } })
end)

-- Handle player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    RBLeaveLobby(src)
end)

-- Get RB state for minigames browser
function GetRBMinigamesState()
    local playerCount = 0
    local playerList = {}

    for pid, data in pairs(RBGameState.players) do
        playerCount = playerCount + 1
        table.insert(playerList, {
            name = data.name,
            team = Config.Teams[data.team].name:lower()
        })
    end

    local scoreStr = nil
    if RBGameState.phase == 'playing' or RBGameState.phase == 'celebration' then
        scoreStr = RBGameState.scores[1] .. ' - ' .. RBGameState.scores[2]
    end

    return {
        status = RBGameState.phase,
        playerCount = playerCount,
        maxPlayers = Config.RB.Settings.maxTeamSize * 2,
        players = playerList,
        scores = scoreStr,
        round = RBGameState.round,
    }
end

-- Announcements
CreateThread(function()
    Wait(10000)
    while true do
        Wait(Config.RB.Settings.announcementInterval)
        if RBGameState.phase == 'idle' then
            TriggerClientEvent('chat:addMessage', -1, { args = { '^6[MINIGAMES]', 'Running Back available! /join rb' } })
        end
    end
end)

-- Broadcast player blips during game
CreateThread(function()
    while true do
        Wait(500)
        if RBGameState.phase == 'playing' then
            local blipData = {}
            for pid, data in pairs(RBGameState.players) do
                table.insert(blipData, {
                    serverId = pid,
                    team = data.team,
                    role = data.roundRole or data.role
                })
            end
            for pid, _ in pairs(RBGameState.players) do
                TriggerClientEvent('rb:updatePlayerBlips', pid, blipData)
            end
        end
    end
end)
