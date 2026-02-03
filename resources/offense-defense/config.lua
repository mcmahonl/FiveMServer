Config = {}

-- Permission roles
Config.Roles = {
    admin = {
        canEdit = true,
        canForceStart = true,
        canStop = true,
    },
    player = {
        canEdit = false,
        canForceStart = false,
        canStop = false,
    }
}

-- Admin list (by identifier)
Config.Admins = {
    'mcmahonl',  -- Add Steam/license identifiers here
}

Config.Teams = {
    [1] = { name = 'Green', color = { r = 50, g = 205, b = 50 }, hexColor = '#32CD32', blipColor = 2 },
    [2] = { name = 'Purple', color = { r = 148, g = 0, b = 211 }, hexColor = '#9400D3', blipColor = 27 }
}

Config.Vehicles = {
    runner = { model = 'voodoo', label = 'Declasse Voodoo' },
    blocker = {
        { model = 'insurgent', label = 'HVY Insurgent' },
        { model = 'kuruma2', label = 'Karin Kuruma (Armored)' },
        { model = 'zentorno', label = 'Pegassi Zentorno' },
    }
}

Config.Settings = {
    maxTeamSize = 4,
    minPlayersToStart = 2,
    lobbyCountdown = 30,
    raceCountdown = 5,
    checkpointRadius = 20.0,
    spawnSpacing = 6.0,
    announcementInterval = 120000,
    allowSoloTest = true,
    defaultMap = 'test',
}
