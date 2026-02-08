-- Sumo - Server Side
-- Team vehicular combat: push enemies off the platform. Last team standing wins the round.
-- Best of 7: first team to 4 round wins takes the match.
-- Round timer: team with more survivors wins on timeout.

SumoGameState = {
    phase = 'idle', -- idle, lobby, countdown, playing, celebration
    players = {},
    teams = { [1] = {}, [2] = {} },
    countdown = nil,
    currentMap = nil,
    scores = { [1] = 0, [2] = 0 },
    round = 0,
    alivePlayers = {}, -- [source] = true/false
}

SumoCurrentGameId = nil
SumoLoadedMap = nil
SumoCurrentPot = 0
SumoCurrentWagers = {}

-- Map management
function SumoGetAllMaps()
    local maps = {}
    local resourceName = GetCurrentResourceName()
    for i = 1, 99 do
        local mapName = 'sumo' .. i
        local data = LoadResourceFile(resourceName, 'maps/' .. mapName .. '.json')
        if data then
            table.insert(maps, mapName)
        end
    end
    return maps
end

function SumoGetNextMapNumber()
    local maps = SumoGetAllMaps()
    local highest = 0
    for _, mapName in ipairs(maps) do
        local num = tonumber(mapName:match('sumo(%d+)'))
        if num and num > highest then highest = num end
    end
    return highest + 1
end

function SumoLoadMap(mapName)
    local data = LoadResourceFile(GetCurrentResourceName(), 'maps/' .. mapName .. '.json')
    if data then
        SumoLoadedMap = json.decode(data)
        SumoLoadedMap.name = mapName
        print('[SUMO] Loaded map: ' .. mapName)
        return true
    end
    return false
end

function SumoLoadRandomMap()
    local maps = SumoGetAllMaps()
    if #maps > 0 then
        return SumoLoadMap(maps[math.random(#maps)])
    end
    return false
end

CreateThread(function()
    Wait(100)
    if not SumoLoadRandomMap() then
        print('[SUMO] No maps found, using hardcoded spawns')
    end
end)

-- Commands
RegisterCommand('sumoedit', function(source, args)
    if not IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[SUMO]', 'Admins only!' } })
        return
    end
    local nextNum = SumoGetNextMapNumber()
    local mapName = 'sumo' .. nextNum
    TriggerClientEvent('sumo:startEditor', source, mapName)
    TriggerClientEvent('chat:addMessage', source, { args = { '^5[SUMO]', 'Creating new map: ' .. mapName } })
end, false)

RegisterCommand('sumostart', function(source)
    if Config.Sumo.Settings.allowSoloTest or IsAdmin(source) then
        SumoStartRace()
    end
end, false)

RegisterCommand('sumostop', function(source)
    if IsAdmin(source) then
        SumoEndRace(0)
    end
end, false)

-- Lobby
function SumoJoinLobby(source)
    if GameState.players[source] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[SUMO]', 'Leave Offense Defense first!' } })
        return
    end
    if RBGameState and RBGameState.players[source] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[SUMO]', 'Leave Running Back first!' } })
        return
    end
    if SumoGameState.phase == 'playing' or SumoGameState.phase == 'celebration' then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[SUMO]', 'Game in progress!' } })
        return
    end
    if SumoGameState.players[source] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[SUMO]', 'Already in lobby!' } })
        return
    end

    local team = #SumoGameState.teams[1] <= #SumoGameState.teams[2] and 1 or 2
    if #SumoGameState.teams[team] >= Config.Sumo.Settings.maxTeamSize then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[SUMO]', 'Lobby full!' } })
        return
    end

    SumoGameState.players[source] = { team = team, role = 'fighter', ready = false, vehicle = 1, name = GetPlayerName(source) }
    table.insert(SumoGameState.teams[team], source)

    if SumoGameState.phase == 'idle' then
        SumoGameState.phase = 'lobby'
        SumoLoadRandomMap()
        if SumoLoadedMap then
            TriggerClientEvent('chat:addMessage', -1, { args = { '^5[SUMO]', 'Map: ' .. SumoLoadedMap.name } })
        end
    end

    local slotIndex = #SumoGameState.teams[team]
    TriggerClientEvent('sumo:joinLobby', source, team, 'fighter', slotIndex, SumoLoadedMap)
    SumoBroadcastLobbyState()
    SumoBroadcastPotPreview()

    TriggerClientEvent('chat:addMessage', -1, { args = { '^5[SUMO]', GetPlayerName(source) .. ' joined Team ' .. Config.Teams[team].name } })
    SumoCheckAutoStart()
end

function SumoLeaveLobby(source)
    local data = SumoGameState.players[source]
    if not data then return end

    for i, pid in ipairs(SumoGameState.teams[data.team]) do
        if pid == source then table.remove(SumoGameState.teams[data.team], i) break end
    end
    SumoGameState.players[source] = nil
    TriggerClientEvent('sumo:leaveLobby', source)
    SumoBroadcastLobbyState()

    if #SumoGameState.teams[1] == 0 and #SumoGameState.teams[2] == 0 then
        SumoGameState.phase = 'idle'
    end
end

function SumoSetReady(source)
    if not SumoGameState.players[source] then return end
    SumoGameState.players[source].ready = true
    SumoBroadcastLobbyState()
    SumoCheckAutoStart()
end

function SumoSetVehicle(source, idx)
    if not SumoGameState.players[source] then return end
    SumoGameState.players[source].vehicle = math.max(1, math.min(#Config.Sumo.Vehicles, idx))
end

function SumoBroadcastLobbyState()
    local green, purple = {}, {}
    for _, pid in ipairs(SumoGameState.teams[1]) do
        local p = SumoGameState.players[pid]
        if p then table.insert(green, { name = p.name, role = p.role, ready = p.ready }) end
    end
    for _, pid in ipairs(SumoGameState.teams[2]) do
        local p = SumoGameState.players[pid]
        if p then table.insert(purple, { name = p.name, role = p.role, ready = p.ready }) end
    end
    for pid, _ in pairs(SumoGameState.players) do
        TriggerClientEvent('sumo:updateLobby', pid, green, purple)
    end
    SumoBroadcastPotPreview()
end

function SumoBroadcastPotPreview()
    local totalPot = Config.Points.bonusPot or 0
    local wagers = {}
    for pid, data in pairs(SumoGameState.players) do
        local wager = CalculateWager(pid)
        wagers[pid] = wager
        totalPot = totalPot + wager
    end
    for pid, data in pairs(SumoGameState.players) do
        local teamSize = #SumoGameState.teams[data.team]
        TriggerClientEvent('sumo:updatePot', pid, totalPot, wagers[pid] or 0, teamSize)
    end
end

function SumoCheckAutoStart()
    if SumoGameState.phase ~= 'lobby' then return end
    local allReady = true
    for _, data in pairs(SumoGameState.players) do
        if not data.ready then allReady = false break end
    end
    if allReady and (next(SumoGameState.players) ~= nil) then
        SumoStartCountdown()
    end
end

function SumoStartCountdown()
    if SumoGameState.phase == 'countdown' then return end
    SumoGameState.phase = 'countdown'
    SumoGameState.countdown = Config.Sumo.Settings.lobbyCountdown

    CreateThread(function()
        while SumoGameState.countdown > 0 and SumoGameState.phase == 'countdown' do
            for pid, _ in pairs(SumoGameState.players) do
                TriggerClientEvent('sumo:lobbyCountdown', pid, SumoGameState.countdown)
            end
            Wait(1000)
            SumoGameState.countdown = SumoGameState.countdown - 1
        end
        if SumoGameState.phase == 'countdown' then SumoStartRace() end
    end)
end

-- ============================================================
-- RACE / ROUND MANAGEMENT
-- ============================================================
function SumoStartRace()
    SumoGameState.phase = 'playing'
    SumoGameState.scores = { [1] = 0, [2] = 0 }
    SumoGameState.round = 0

    local pot = SumoCollectPot()
    for pid, _ in pairs(SumoGameState.players) do
        local wager = SumoCurrentWagers[pid] or CalculateWager(pid)
        TriggerClientEvent('sumo:updatePot', pid, pot, wager)
    end

    SumoCurrentGameId = SumoCreateGameRecord(SumoLoadedMap and SumoLoadedMap.name or 'unknown')
    SumoStartRound(true)
end

function SumoStartRound(isFirst)
    SumoGameState.round = SumoGameState.round + 1
    SumoGameState.phase = 'playing'

    -- Mark all players alive
    SumoGameState.alivePlayers = {}
    for pid, _ in pairs(SumoGameState.players) do
        SumoGameState.alivePlayers[pid] = true
    end

    -- Calculate slot indices per team
    local teamSlots = { [1] = {}, [2] = {} }
    for t = 1, 2 do
        for i, pid in ipairs(SumoGameState.teams[t]) do
            teamSlots[t][pid] = i
        end
    end

    -- Send events to all players
    for pid, data in pairs(SumoGameState.players) do
        local slotIndex = teamSlots[data.team][pid] or 1
        local vehicle = Config.Sumo.Vehicles[data.vehicle].model

        if isFirst then
            TriggerClientEvent('sumo:startRace', pid, data.team, slotIndex, vehicle, SumoLoadedMap, SumoGameState.scores)
        else
            TriggerClientEvent('sumo:nextRound', pid, data.team, slotIndex, SumoGameState.round, SumoGameState.scores, vehicle)
        end
    end

    -- Start round timer
    SumoStartRoundTimer()
end

function SumoStartRoundTimer()
    local timeLeft = Config.Sumo.Settings.roundTimeLimit

    CreateThread(function()
        while timeLeft > 0 and SumoGameState.phase == 'playing' do
            for pid, _ in pairs(SumoGameState.players) do
                TriggerClientEvent('sumo:updateRoundTimer', pid, timeLeft)
            end
            Wait(1000)
            timeLeft = timeLeft - 1
        end

        -- Time's up - team with more survivors wins
        if SumoGameState.phase == 'playing' then
            local alive1, alive2 = 0, 0
            for pid, isAlive in pairs(SumoGameState.alivePlayers) do
                if isAlive then
                    local data = SumoGameState.players[pid]
                    if data then
                        if data.team == 1 then alive1 = alive1 + 1
                        else alive2 = alive2 + 1 end
                    end
                end
            end

            local winner
            if alive1 > alive2 then
                winner = 1
            elseif alive2 > alive1 then
                winner = 2
            else
                -- Tie: random winner
                winner = math.random(1, 2)
            end

            TriggerClientEvent('chat:addMessage', -1, { args = { '^5[SUMO]', 'TIME\'S UP! Team ' .. Config.Teams[winner].name .. ' wins on survivors! (' .. alive1 .. ' vs ' .. alive2 .. ')' } })
            SumoRoundWon(winner)
        end
    end)
end

function SumoRoundWon(winningTeam)
    if SumoGameState.phase ~= 'playing' then return end
    SumoGameState.phase = 'celebration'
    SumoGameState.scores[winningTeam] = SumoGameState.scores[winningTeam] + 1

    local matchOver = SumoGameState.scores[winningTeam] >= Config.Sumo.Settings.roundsToWin

    TriggerClientEvent('chat:addMessage', -1, { args = { '^5[SUMO]', 'Team ' .. Config.Teams[winningTeam].name .. ' WINS THE ROUND! (' .. SumoGameState.scores[1] .. ' - ' .. SumoGameState.scores[2] .. ')' } })

    for pid, data in pairs(SumoGameState.players) do
        TriggerClientEvent('sumo:roundResult', pid, {
            winningTeam = winningTeam,
            teamName = Config.Teams[winningTeam].name,
            greenScore = SumoGameState.scores[1],
            purpleScore = SumoGameState.scores[2],
            matchOver = matchOver,
            won = data.team == winningTeam,
        })
    end

    SetTimeout(Config.Sumo.Settings.celebrationTime * 1000, function()
        if matchOver then
            SumoEndRace(winningTeam)
        else
            SumoStartRound(false)
        end
    end)
end

function SumoEndRace(winningTeam)
    local results = {}
    if winningTeam > 0 then
        results = SumoDistributePot(winningTeam, SumoCurrentGameId)
        SumoEndGameRecord(SumoCurrentGameId, winningTeam)
        TriggerClientEvent('chat:addMessage', -1, { args = { '^5[SUMO]', 'Team ' .. Config.Teams[winningTeam].name .. ' WINS THE MATCH! (' .. SumoGameState.scores[1] .. ' - ' .. SumoGameState.scores[2] .. ')' } })
    end

    for pid, _ in pairs(SumoGameState.players) do
        local playerResult = results[pid] or { won = false, change = 0, newTotal = 0 }
        TriggerClientEvent('sumo:showResults', pid, {
            won = playerResult.won,
            change = playerResult.change,
            newTotal = playerResult.newTotal,
            winningTeam = winningTeam,
            teamName = winningTeam > 0 and Config.Teams[winningTeam].name or 'None',
            greenScore = SumoGameState.scores[1],
            purpleScore = SumoGameState.scores[2],
        })
    end

    SetTimeout(8000, function()
        for pid, _ in pairs(SumoGameState.players) do
            TriggerClientEvent('sumo:endRace', pid)
        end
        SumoGameState.phase = 'idle'
        SumoGameState.players = {}
        SumoGameState.teams = { [1] = {}, [2] = {} }
        SumoGameState.scores = { [1] = 0, [2] = 0 }
        SumoGameState.round = 0
        SumoGameState.alivePlayers = {}
        SumoCurrentGameId = nil
        BroadcastOnlinePlayers()
    end)
end

-- Player elimination
RegisterNetEvent('sumo:playerEliminated', function()
    local src = source
    local data = SumoGameState.players[src]
    if not data then return end
    if not SumoGameState.alivePlayers[src] then return end -- already eliminated

    SumoGameState.alivePlayers[src] = false

    TriggerClientEvent('chat:addMessage', -1, { args = { '^5[SUMO]', data.name .. ' has been eliminated!' } })

    -- Notify the eliminated player
    TriggerClientEvent('sumo:eliminated', src)

    -- Broadcast alive counts
    SumoBroadcastAlive()

    -- Check if round is over
    local alive1, alive2 = 0, 0
    for pid, isAlive in pairs(SumoGameState.alivePlayers) do
        if isAlive then
            local p = SumoGameState.players[pid]
            if p then
                if p.team == 1 then alive1 = alive1 + 1
                else alive2 = alive2 + 1 end
            end
        end
    end

    if alive1 == 0 and alive2 == 0 then
        -- Both teams eliminated (shouldn't happen, but handle it)
        SumoRoundWon(math.random(1, 2))
    elseif alive1 == 0 then
        SumoRoundWon(2)
    elseif alive2 == 0 then
        SumoRoundWon(1)
    end
end)

function SumoBroadcastAlive()
    local alive1, alive2 = 0, 0
    for pid, isAlive in pairs(SumoGameState.alivePlayers) do
        if isAlive then
            local data = SumoGameState.players[pid]
            if data then
                if data.team == 1 then alive1 = alive1 + 1
                else alive2 = alive2 + 1 end
            end
        end
    end

    for pid, _ in pairs(SumoGameState.players) do
        TriggerClientEvent('sumo:updateAlive', pid, alive1, alive2)
    end
end

-- Pot management
function SumoCollectPot()
    SumoCurrentPot = Config.Points.bonusPot or 0
    SumoCurrentWagers = {}
    for pid, data in pairs(SumoGameState.players) do
        local wager = CalculateWager(pid)
        SumoCurrentWagers[pid] = wager
        SumoCurrentPot = SumoCurrentPot + wager
        if PlayerCache[pid] then
            PlayerCache[pid].points = PlayerCache[pid].points - wager
            MySQL.update('UPDATE players SET points = points - ? WHERE id = ?', { wager, PlayerCache[pid].id })
        end
    end
    BroadcastOnlinePlayers()
    return SumoCurrentPot
end

function SumoDistributePot(winningTeam, gameId)
    local winners = {}
    local losers = {}
    for pid, data in pairs(SumoGameState.players) do
        if data.team == winningTeam then
            table.insert(winners, pid)
        else
            table.insert(losers, pid)
        end
    end

    local winningsEach = #winners > 0 and math.floor(SumoCurrentPot / #winners) or 0
    local results = {}

    for _, pid in ipairs(winners) do
        local wager = SumoCurrentWagers[pid] or 0
        local change = winningsEach - wager
        if PlayerCache[pid] then
            PlayerCache[pid].points = PlayerCache[pid].points + winningsEach
            PlayerCache[pid].wins = PlayerCache[pid].wins + 1
            PlayerCache[pid].games_played = PlayerCache[pid].games_played + 1
            MySQL.update('UPDATE players SET points = points + ?, wins = wins + 1, games_played = games_played + 1 WHERE id = ?',
                { winningsEach, PlayerCache[pid].id })
            if gameId then
                MySQL.insert('INSERT INTO game_participants (game_id, player_id, team, role, wager, points_change) VALUES (?, ?, ?, ?, ?, ?)',
                    { gameId, PlayerCache[pid].id, SumoGameState.players[pid].team, 'fighter', wager, change })
            end
        end
        results[pid] = { won = true, change = change, newTotal = PlayerCache[pid] and PlayerCache[pid].points or 0 }
    end

    for _, pid in ipairs(losers) do
        local wager = SumoCurrentWagers[pid] or 0
        local change = -wager
        if PlayerCache[pid] then
            PlayerCache[pid].losses = PlayerCache[pid].losses + 1
            PlayerCache[pid].games_played = PlayerCache[pid].games_played + 1
            MySQL.update('UPDATE players SET losses = losses + 1, games_played = games_played + 1 WHERE id = ?',
                { PlayerCache[pid].id })
            if gameId then
                MySQL.insert('INSERT INTO game_participants (game_id, player_id, team, role, wager, points_change) VALUES (?, ?, ?, ?, ?, ?)',
                    { gameId, PlayerCache[pid].id, SumoGameState.players[pid].team, 'fighter', wager, change })
            end
        end
        results[pid] = { won = false, change = change, newTotal = PlayerCache[pid] and PlayerCache[pid].points or 0 }
    end

    SumoCurrentPot = 0
    SumoCurrentWagers = {}
    return results
end

function SumoCreateGameRecord(mapName)
    if not MySQL then return nil end
    return MySQL.insert.await('INSERT INTO game_history (game_type, map_name, pot_total) VALUES (?, ?, ?)',
        { 'sumo', mapName or 'unknown', SumoCurrentPot })
end

function SumoEndGameRecord(gameId, winningTeam)
    if gameId then
        MySQL.update('UPDATE game_history SET winning_team = ?, ended_at = NOW() WHERE id = ?', { winningTeam, gameId })
    end
end

-- Events
RegisterNetEvent('sumo:ready', function() SumoSetReady(source) end)
RegisterNetEvent('sumo:leave', function() SumoLeaveLobby(source) end)
RegisterNetEvent('sumo:selectCar', function(car) SumoSetVehicle(source, car) end)

RegisterNetEvent('sumo:switchTeam', function(newTeam)
    local src = source
    local data = SumoGameState.players[src]
    if not data then return end
    if data.ready then return end
    if newTeam == data.team then return end
    if #SumoGameState.teams[newTeam] >= Config.Sumo.Settings.maxTeamSize then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[SUMO]', 'Team is full!' } })
        return
    end

    for i, pid in ipairs(SumoGameState.teams[data.team]) do
        if pid == src then table.remove(SumoGameState.teams[data.team], i) break end
    end

    data.team = newTeam
    table.insert(SumoGameState.teams[newTeam], src)

    local slotIndex = #SumoGameState.teams[newTeam]
    TriggerClientEvent('sumo:updatePlayer', src, newTeam, 'fighter', slotIndex)
    SumoBroadcastLobbyState()
end)

-- No role switching in sumo
RegisterNetEvent('sumo:switchRole', function() return end)

RegisterNetEvent('sumo:requestGamePlayers', function()
    local src = source
    if not SumoGameState.players[src] then return end
    local list = {}
    for pid, data in pairs(SumoGameState.players) do
        local points = GetPlayerPoints(pid)
        local alive = SumoGameState.alivePlayers[pid] and true or false
        table.insert(list, {
            name = data.name,
            role = alive and 'alive' or 'eliminated',
            team = Config.Teams[data.team].name:lower(),
            points = points or 0,
            rank = 0
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    for i, p in ipairs(list) do p.rank = i end
    TriggerClientEvent('sumo:updateGamePlayers', src, list)
end)

RegisterNetEvent('sumo:joinFromBrowser', function()
    SumoJoinLobby(source)
end)

-- Save map from Sumo editor
RegisterNetEvent('sumo:saveMap', function(mapData)
    if not IsAdmin(source) then return end
    SaveResourceFile(GetCurrentResourceName(), 'maps/' .. mapData.name .. '.json', json.encode(mapData), -1)
    TriggerClientEvent('chat:addMessage', source, { args = { '^5[SUMO]', 'Map saved: ' .. mapData.name } })
end)

-- Handle player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    SumoLeaveLobby(src)
end)

-- Get Sumo state for minigames browser
function GetSumoMinigamesState()
    local playerCount = 0
    local playerList = {}

    for pid, data in pairs(SumoGameState.players) do
        playerCount = playerCount + 1
        table.insert(playerList, {
            name = data.name,
            team = Config.Teams[data.team].name:lower()
        })
    end

    local scoreStr = nil
    if SumoGameState.phase == 'playing' or SumoGameState.phase == 'celebration' then
        scoreStr = SumoGameState.scores[1] .. ' - ' .. SumoGameState.scores[2]
    end

    return {
        status = SumoGameState.phase,
        playerCount = playerCount,
        maxPlayers = Config.Sumo.Settings.maxTeamSize * 2,
        players = playerList,
        scores = scoreStr,
        round = SumoGameState.round,
    }
end

-- Announcements
CreateThread(function()
    Wait(15000)
    while true do
        Wait(Config.Sumo.Settings.announcementInterval)
        if SumoGameState.phase == 'idle' then
            TriggerClientEvent('chat:addMessage', -1, { args = { '^5[MINIGAMES]', 'Sumo available! /join sumo' } })
        end
    end
end)

-- Broadcast player blips during game
CreateThread(function()
    while true do
        Wait(500)
        if SumoGameState.phase == 'playing' then
            local blipData = {}
            for pid, data in pairs(SumoGameState.players) do
                table.insert(blipData, {
                    serverId = pid,
                    team = data.team,
                    alive = SumoGameState.alivePlayers[pid] or false
                })
            end
            for pid, _ in pairs(SumoGameState.players) do
                TriggerClientEvent('sumo:updatePlayerBlips', pid, blipData)
            end
        end
    end
end)

-- Broadcast alive counts periodically during play
CreateThread(function()
    while true do
        Wait(1000)
        if SumoGameState.phase == 'playing' then
            SumoBroadcastAlive()
        end
    end
end)
