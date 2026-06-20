local function getLocalPlayer(playerIndex)
    if getSpecificPlayer then
        local playerObj = getSpecificPlayer(playerIndex or 0)
        if playerObj then
            return playerObj
        end
    end
    return getPlayer()
end

local function ensureInspectWindowPos(playerObj)
    if not playerObj then
        return
    end
    if playerObj:getModData().inspectWindowPos == nil then
        playerObj:getModData().inspectWindowPos = {100, 100}
    end
end

local function openInspectWindow(playerObj)
    if not playerObj then
        return
    end

    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not weapon:IsWeapon() then
        return
    end

    ensureInspectWindowPos(playerObj)

    if riskyInspectWindow == nil or not riskyInspectWindow:getIsVisible() then
        riskyInspectWindow = riskyUI:new(playerObj:getModData().inspectWindowPos[1], playerObj:getModData().inspectWindowPos[2], 0, 0)
        riskyInspectWindow:addToUIManager()
        riskyInspectWindow.resizable = false
        riskyInspectWindow.collapsable = false
        riskyInspectWindow:renderInventory()
    else
        riskyInspectWindow:close()
        riskyInspectWindow = nil
    end
end

-- Read-only isolation mode:
-- add a context option that only opens the UI for the equipped weapon.
riskyUI.createInventoryMenuEntry = function(_player, _context, _items)
    local playerObj = getLocalPlayer(_player)
    if not playerObj or not _context then
        return
    end

    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not weapon:IsWeapon() then
        return
    end

    _context:addOption(getText('IGUI_RISKY_INSPECT_WEAPON'), nil, function()
        openInspectWindow(playerObj)
    end)
end
Events.OnFillInventoryObjectContextMenu.Add(riskyUI.createInventoryMenuEntry)

riskyUI.onAttack = function(_character, _weapon)
    if riskyInspectWindow ~= nil and riskyInspectWindow:getIsVisible() then
        riskyInspectWindow:close()
        riskyInspectWindow = nil
    end
end
Events.OnWeaponSwing.Add(riskyUI.onAttack)

riskyUI.onGameStart = function()
    ensureInspectWindowPos(getPlayer())
end
Events.OnGameStart.Add(riskyUI.onGameStart)

riskyUI.onCreatePlayer = function(playerIndex, player)
    ensureInspectWindowPos(player)
end
Events.OnCreatePlayer.Add(riskyUI.onCreatePlayer)

riskyUI.inspectOnKey = function(_keyPressed)
    if _keyPressed == getCore():getKey("OpenWindownCat") then
        openInspectWindow(getPlayer())
    end
end

local function registerInspectHotkey()
    Events.OnKeyPressed.Add(riskyUI.inspectOnKey)
end
Events.OnGameStart.Add(registerInspectHotkey)
