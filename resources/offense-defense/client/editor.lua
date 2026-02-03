-- Race Editor
Editor = {
    active = false,
    mapName = 'untitled',
    checkpoints = {},
    lobbySpawn = nil,
    startGrid = nil,
}

RegisterNetEvent('od:startEditor', function(mapName)
    Editor.active = true
    Editor.mapName = mapName
    Editor.checkpoints = {}
    Editor.lobbySpawn = nil
    Editor.startGrid = nil
    
    SendNUIMessage({ type = 'showEditor', mapName = mapName, checkpoints = 0, hasLobby = false, hasGrid = false })
    TriggerEvent('chat:addMessage', { args = { '^2[EDITOR]', 'Editor started. Drive the route and press E to add checkpoints.' } })
end)

function ExitEditor()
    Editor.active = false
    SendNUIMessage({ type = 'hideEditor' })
    TriggerEvent('chat:addMessage', { args = { '^1[EDITOR]', 'Editor closed.' } })
end

function UpdateEditorUI()
    SendNUIMessage({
        type = 'updateEditor',
        mapName = Editor.mapName,
        checkpoints = #Editor.checkpoints,
        hasLobby = Editor.lobbySpawn ~= nil,
        hasGrid = Editor.startGrid ~= nil,
    })
end

-- Editor controls
CreateThread(function()
    while true do
        Wait(0)
        if Editor.active then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            
            -- X = Add checkpoint
            if IsControlJustPressed(0, 73) then  -- X
                table.insert(Editor.checkpoints, { x = pos.x, y = pos.y, z = pos.z })
                PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^2[EDITOR]', 'Checkpoint ' .. #Editor.checkpoints .. ' added' } })
                UpdateEditorUI()
            end

            -- E = Remove last (checkpoints first, then grid, then lobby)
            if IsControlJustPressed(0, 38) then  -- E
                if #Editor.checkpoints > 0 then
                    table.remove(Editor.checkpoints)
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[EDITOR]', 'Removed checkpoint. Total: ' .. #Editor.checkpoints } })
                elseif Editor.startGrid then
                    Editor.startGrid = nil
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[EDITOR]', 'Removed start grid' } })
                elseif Editor.lobbySpawn then
                    Editor.lobbySpawn = nil
                    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                    TriggerEvent('chat:addMessage', { args = { '^1[EDITOR]', 'Removed lobby spawn' } })
                end
                UpdateEditorUI()
            end

            -- H = Set lobby spawn
            if IsControlJustPressed(0, 74) then  -- H
                Editor.lobbySpawn = { x = pos.x, y = pos.y, z = pos.z, w = heading }
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^2[EDITOR]', 'Lobby spawn set' } })
                UpdateEditorUI()
            end
            
            -- G = Set start grid
            if IsControlJustPressed(0, 47) then  -- G
                Editor.startGrid = { x = pos.x, y = pos.y, z = pos.z, w = heading }
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                TriggerEvent('chat:addMessage', { args = { '^2[EDITOR]', 'Start grid position set' } })
                UpdateEditorUI()
            end
            
            -- Z = Save
            if IsControlJustPressed(0, 20) then  -- Z
                if #Editor.checkpoints < 2 then
                    TriggerEvent('chat:addMessage', { args = { '^1[EDITOR]', 'Need at least 2 checkpoints!' } })
                elseif not Editor.lobbySpawn then
                    TriggerEvent('chat:addMessage', { args = { '^1[EDITOR]', 'Set lobby spawn first! (H)' } })
                elseif not Editor.startGrid then
                    TriggerEvent('chat:addMessage', { args = { '^1[EDITOR]', 'Set start grid first! (G)' } })
                else
                    local mapData = {
                        name = Editor.mapName,
                        checkpoints = Editor.checkpoints,
                        lobbySpawn = Editor.lobbySpawn,
                        startGrid = Editor.startGrid,
                    }
                    TriggerServerEvent('od:saveMap', mapData)
                    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', false)
                end
            end
            
            -- Draw existing checkpoints
            for i, cp in ipairs(Editor.checkpoints) do
                DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0, 0, 0, 0, 0, 0, 8.0, 8.0, 2.0, 255, 200, 0, 150, false, false, 2, false, nil, nil, false)
                DrawText3D(cp.x, cp.y, cp.z + 2.0, tostring(i))
            end
            
            -- Draw lobby spawn
            if Editor.lobbySpawn then
                DrawMarker(1, Editor.lobbySpawn.x, Editor.lobbySpawn.y, Editor.lobbySpawn.z - 1.0, 0, 0, 0, 0, 0, 0, 6.0, 6.0, 2.0, 0, 255, 0, 150, false, false, 2, false, nil, nil, false)
                DrawText3D(Editor.lobbySpawn.x, Editor.lobbySpawn.y, Editor.lobbySpawn.z + 2.0, 'LOBBY')
            end
            
            -- Draw start grid
            if Editor.startGrid then
                DrawMarker(1, Editor.startGrid.x, Editor.startGrid.y, Editor.startGrid.z - 1.0, 0, 0, 0, 0, 0, 0, 6.0, 6.0, 2.0, 0, 100, 255, 150, false, false, 2, false, nil, nil, false)
                DrawText3D(Editor.startGrid.x, Editor.startGrid.y, Editor.startGrid.z + 2.0, 'START')
            end

            -- ESC = Exit editor
            if IsControlJustPressed(0, 200) then  -- ESC
                ExitEditor()
            end
        end
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.4, 0.4)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextOutline()
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end
