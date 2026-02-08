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
    'license:262c5c9e7a9f0346914fd42b4ae722dae5c1ee09',
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
    defaultMap = 'od1',
}

Config.Points = {
    startingPoints = 10000,
    wagerPercent = 0.10,  -- 10% of total points
    minimumWager = 100,
    bonusPot = 1000,  -- Extra points added to every jackpot
}

-- Sumo Configuration
Config.Sumo = {
    Vehicles = {
        -- Heavy/Ramming
        { model = 'phantomw', label = 'Phantom Wedge' },
        { model = 'rampbuggy', label = 'Ramp Buggy' },
        { model = 'monster', label = 'Vapid Monster Truck' },
        { model = 'halftrack', label = 'Half-Track' },
        { model = 'menacer', label = 'HVY Menacer' },
        { model = 'chernobog', label = 'Chernobog' },
        -- Supers
        { model = 'autarch', label = 'Overflod Autarch' },
        { model = 'cyclone', label = 'Coil Cyclone' },
        { model = 'gp1', label = 'Progen GP1' },
        { model = 'xa21', label = 'Ocelot XA-21' },
        { model = 'penetrator', label = 'Ocelot Penetrator' },
        { model = 'entityxf', label = 'Overflod Entity XF' },
        { model = 'entity2', label = 'Overflod Entity XXR' },
        { model = 't20', label = 'Progen T20' },
        { model = 'turismor', label = 'Grotti Turismo R' },
        { model = 'cheetah', label = 'Grotti Cheetah' },
        { model = 'zentorno', label = 'Pegassi Zentorno' },
        -- Sports/Muscle
        { model = 'revolter', label = 'Ubermacht Revolter' },
        { model = 'neon', label = 'Pfister Neon' },
        { model = 'raiden', label = 'Coil Raiden' },
        { model = 'schafter4', label = 'Benefactor Schafter V12' },
        { model = 'feltzer3', label = 'Stirling GT' },
        { model = 'dominator', label = 'Vapid Dominator' },
        { model = 'faction2', label = 'Willard Faction Custom' },
        { model = 'buccaneer2', label = 'Albany Buccaneer Custom' },
        { model = 'sultanrs', label = 'Karin Sultan RS' },
        -- Off-Road/Special
        { model = 'kamacho', label = 'Canis Kamacho' },
        { model = 'dunebuggy', label = 'Dune FAV' },
        { model = 'bifta', label = 'BF Bifta' },
        { model = 'injection', label = 'BF Injection' },
        { model = 'rebel2', label = 'Karin Rebel' },
        { model = 'sandking', label = 'Vapid Sandking' },
        -- Compact/Meme
        { model = 'panto', label = 'Benefactor Panto' },
        { model = 'issi2', label = 'Weeny Issi' },
        { model = 'mamba', label = 'Declasse Mamba' },
    },
    Settings = {
        maxTeamSize = 4,
        minPlayersToStart = 2,
        lobbyCountdown = 30,
        raceCountdown = 5,
        spawnSpacing = 6.0,
        announcementInterval = 120000,
        allowSoloTest = true,
        defaultMap = 'sumo1',
        roundsToWin = 4,
        celebrationTime = 5,
        roundTimeLimit = 60,
        arenaRadius = 50.0,
        eliminationDropHeight = 10.0,
    },
}

-- Running Back Configuration
Config.RB = {
    Vehicles = {
        runner = { model = 'panto', label = 'Benefactor Panto' },
        blocker = {
            { model = 'insurgent', label = 'HVY Insurgent' },
            { model = 'nightshark', label = 'HVY Nightshark' },
            { model = 'tezeract', label = 'Pegassi Tezeract' },
        }
    },
    Settings = {
        maxTeamSize = 4,
        minPlayersToStart = 2,
        lobbyCountdown = 30,
        raceCountdown = 5,
        endZoneRadius = 25.0,
        endZoneDistance = 15.0, -- how far behind spawn the end zone center is
        spawnSpacing = 6.0,
        announcementInterval = 120000,
        allowSoloTest = true,
        defaultMap = 'rb1',
        roundsToWin = 4,
        celebrationTime = 5,
        roundTimeLimit = 90, -- seconds per round before defense wins
    },
}
