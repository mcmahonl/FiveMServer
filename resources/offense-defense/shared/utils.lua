Utils = {}

function Utils.GetTeamName(teamId)
    return Config.Teams[teamId] and Config.Teams[teamId].name or 'Unknown'
end

function Utils.GetTeamColor(teamId)
    return Config.Teams[teamId] and Config.Teams[teamId].color or {r=255,g=255,b=255}
end
