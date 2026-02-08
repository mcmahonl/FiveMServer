-- Points System with MySQL persistence
-- Handles jackpot wagering, winner payouts, and leaderboards

PlayerCache = {} -- [source] = { id, license, points, wins, losses }
local CurrentPot = 0
local CurrentWagers = {} -- [source] = wager amount
local MySQLReady = false

-- Wait for MySQL to be ready
local function WaitForMySQL()
    if MySQLReady then return true end
    Wait(2000) -- Give oxmysql time to init
    if MySQL then
        MySQLReady = true
        return true
    end
    print('[OD Points] WARNING: MySQL not available')
    return false
end

-- Get player license identifier
function GetPlayerLicense(source)
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and id:find('license:') then
            return id
        end
    end
    return nil
end

-- Load or create player record
function LoadPlayer(source)
    WaitForMySQL()

    local license = GetPlayerLicense(source)
    if not license then return nil end

    local name = GetPlayerName(source)

    -- Try to get existing player
    local result = MySQL.single.await('SELECT id, license, name, points, wins, losses, games_played FROM players WHERE license = ?', { license })

    if result then
        -- Update name if changed
        if result.name ~= name then
            MySQL.update.await('UPDATE players SET name = ? WHERE id = ?', { name, result.id })
            result.name = name
        end
        PlayerCache[source] = result
        print('[OD Points] Loaded player: ' .. name .. ' (' .. result.points .. ' pts)')
    else
        -- Create new player with starting points
        local id = MySQL.insert.await('INSERT INTO players (license, name, points) VALUES (?, ?, ?)', { license, name, Config.Points.startingPoints })
        PlayerCache[source] = {
            id = id,
            license = license,
            name = name,
            points = Config.Points.startingPoints,
            wins = 0,
            losses = 0,
            games_played = 0
        }
        print('[OD Points] Created player: ' .. name .. ' (' .. Config.Points.startingPoints .. ' pts)')
    end

    return PlayerCache[source]
end

-- Get player points (from cache)
function GetPlayerPoints(source)
    local data = PlayerCache[source]
    return data and data.points or 0
end

-- Calculate wager (10% of points, minimum 10)
function CalculateWager(source)
    local points = GetPlayerPoints(source)
    local wager = math.floor(points * Config.Points.wagerPercent)
    return math.max(wager, Config.Points.minimumWager)
end

-- Collect wagers from all players in lobby (called at countdown start)
function CollectPot()
    CurrentPot = Config.Points.bonusPot or 0  -- Start with bonus
    CurrentWagers = {}

    for pid, data in pairs(GameState.players) do
        local wager = CalculateWager(pid)
        CurrentWagers[pid] = wager
        CurrentPot = CurrentPot + wager

        -- Deduct from player
        if PlayerCache[pid] then
            PlayerCache[pid].points = PlayerCache[pid].points - wager
            MySQL.update('UPDATE players SET points = points - ? WHERE id = ?', { wager, PlayerCache[pid].id })
        end
    end

    -- Broadcast updated points
    BroadcastOnlinePlayers()

    return CurrentPot
end

-- Distribute pot to winning team
function DistributePot(winningTeam, gameId)
    local winners = {}
    local losers = {}

    for pid, data in pairs(GameState.players) do
        if data.team == winningTeam then
            table.insert(winners, pid)
        else
            table.insert(losers, pid)
        end
    end

    -- Calculate winnings per winner
    local winningsEach = #winners > 0 and math.floor(CurrentPot / #winners) or 0

    local results = {}

    -- Award winners
    for _, pid in ipairs(winners) do
        local wager = CurrentWagers[pid] or 0
        local change = winningsEach - wager -- Net change (winnings minus what they wagered)

        if PlayerCache[pid] then
            PlayerCache[pid].points = PlayerCache[pid].points + winningsEach
            PlayerCache[pid].wins = PlayerCache[pid].wins + 1
            PlayerCache[pid].games_played = PlayerCache[pid].games_played + 1

            MySQL.update('UPDATE players SET points = points + ?, wins = wins + 1, games_played = games_played + 1 WHERE id = ?',
                { winningsEach, PlayerCache[pid].id })

            -- Record participation
            if gameId then
                MySQL.insert('INSERT INTO game_participants (game_id, player_id, team, role, wager, points_change) VALUES (?, ?, ?, ?, ?, ?)',
                    { gameId, PlayerCache[pid].id, GameState.players[pid].team, GameState.players[pid].role, wager, change })
            end
        end

        results[pid] = { won = true, change = change, newTotal = PlayerCache[pid] and PlayerCache[pid].points or 0 }
    end

    -- Record losers
    for _, pid in ipairs(losers) do
        local wager = CurrentWagers[pid] or 0
        local change = -wager

        if PlayerCache[pid] then
            PlayerCache[pid].losses = PlayerCache[pid].losses + 1
            PlayerCache[pid].games_played = PlayerCache[pid].games_played + 1

            MySQL.update('UPDATE players SET losses = losses + 1, games_played = games_played + 1 WHERE id = ?',
                { PlayerCache[pid].id })

            if gameId then
                MySQL.insert('INSERT INTO game_participants (game_id, player_id, team, role, wager, points_change) VALUES (?, ?, ?, ?, ?, ?)',
                    { gameId, PlayerCache[pid].id, GameState.players[pid].team, GameState.players[pid].role, wager, change })
            end
        end

        results[pid] = { won = false, change = change, newTotal = PlayerCache[pid] and PlayerCache[pid].points or 0 }
    end

    -- Clear pot
    CurrentPot = 0
    CurrentWagers = {}

    return results
end

-- Get leaderboard (top players by points)
function GetLeaderboard(limit)
    WaitForMySQL()
    limit = limit or 10
    return MySQL.query.await('SELECT name, points, wins, losses FROM players ORDER BY points DESC LIMIT ?', { limit })
end

-- Get online players with points, sorted by rank
function GetOnlinePlayersWithPoints()
    local list = {}
    for src, data in pairs(OnlinePlayers) do
        local points = GetPlayerPoints(src)
        table.insert(list, {
            name = data.name,
            role = data.role,
            points = points
        })
    end
    -- Sort by points descending
    table.sort(list, function(a, b) return a.points > b.points end)
    -- Add rank
    for i, p in ipairs(list) do
        p.rank = i
    end
    return list
end

-- Create game history record
function CreateGameRecord(mapName)
    WaitForMySQL()
    return MySQL.insert.await('INSERT INTO game_history (game_type, map_name, pot_total) VALUES (?, ?, ?)',
        { 'offense-defense', mapName or 'unknown', CurrentPot })
end

-- End game record
function EndGameRecord(gameId, winningTeam)
    MySQL.update('UPDATE game_history SET winning_team = ?, ended_at = NOW() WHERE id = ?', { winningTeam, gameId })
end

-- Events: Player connect/disconnect
AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function()
        Wait(1000)
        LoadPlayer(src)
        BroadcastOnlinePlayers()
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    PlayerCache[src] = nil
end)

-- Initialize existing players on resource start
CreateThread(function()
    WaitForMySQL()
    print('[OD Points] MySQL connected, loading existing players...')

    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        LoadPlayer(src)
    end
    BroadcastOnlinePlayers()
end)

-- Get a player's wager (from CurrentWagers if collected, otherwise calculate)
function GetPlayerWager(source)
    return CurrentWagers[source] or CalculateWager(source)
end

-- Export functions for main.lua
exports('GetPlayerPoints', GetPlayerPoints)
exports('CalculateWager', CalculateWager)
exports('GetPlayerWager', GetPlayerWager)
exports('CollectPot', CollectPot)
exports('DistributePot', DistributePot)
exports('GetOnlinePlayersWithPoints', GetOnlinePlayersWithPoints)
exports('CreateGameRecord', CreateGameRecord)
exports('EndGameRecord', EndGameRecord)
exports('GetCurrentPot', function() return CurrentPot end)
