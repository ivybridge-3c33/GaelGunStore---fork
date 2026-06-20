-- Compatibility guard for Inventory Tetris on B42 builds where IsoPlayer:isNPC()
-- is not exposed client-side. Inventory Tetris calls it every few ticks, causing
-- a continuous "Object tried to call nil" error.

local MODULE = "GGS InventoryTetrisCompat"
local patched = false
local validateHandler = nil
local mainGridTickHandler = nil
local TETRIS_MOD_IDS = {
    INVENTORY_TETRIS = true,
    InventoryTetris = true,
}

local function logCompat(message)
    print("[" .. MODULE .. "] " .. tostring(message))
end

local function collectionContains(collection, value)
    if not collection or not value then
        return false
    end

    if type(collection.contains) == "function" then
        local ok, contains = pcall(function()
            return collection:contains(value)
        end)
        if ok and contains then
            return true
        end
    end

    if type(collection.size) == "function" and type(collection.get) == "function" then
        local okSize, size = pcall(function()
            return collection:size()
        end)
        if okSize and size then
            for i = 0, size - 1 do
                local okValue, item = pcall(function()
                    return collection:get(i)
                end)
                if okValue and item == value then
                    return true
                end
            end
        end
    end

    if type(collection) == "table" then
        for _, item in pairs(collection) do
            if item == value then
                return true
            end
        end
    end

    return false
end

local function isInventoryTetrisActive()
    if type(getActivatedMods) ~= "function" then
        return InventoryTetris and true or nil
    end

    local ok, activeMods = pcall(getActivatedMods)
    if not ok or not activeMods then
        return InventoryTetris and true or nil
    end

    for modId in pairs(TETRIS_MOD_IDS) do
        if collectionContains(activeMods, modId) then
            return true
        end
    end

    return false
end

local function safeIsNPC(playerObj)
    if not playerObj then
        return false
    end
    if type(playerObj.isNPC) ~= "function" then
        return false
    end
    local ok, result = pcall(function()
        return playerObj:isNPC()
    end)
    return ok and result == true
end

local function safeIsDead(playerObj)
    if not playerObj then
        return true
    end
    if type(playerObj.isDead) ~= "function" then
        return false
    end
    local ok, result = pcall(function()
        return playerObj:isDead()
    end)
    return ok and result == true
end

local function wipeTable(tbl)
    if not tbl then
        return
    end
    if table and type(table.wipe) == "function" then
        table.wipe(tbl)
        return
    end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function patchValidateEquippedItems()
    local ok, monitor = pcall(require, "InventoryTetris/System/ValidateEquippedItemsSystem")
    if not ok or type(monitor) ~= "table" or type(monitor.validateEquippedItems) ~= "function" then
        return false
    end

    if Events and Events.OnPlayerUpdate and Events.OnPlayerUpdate.Remove then
        Events.OnPlayerUpdate.Remove(monitor.validateEquippedItems)
        if validateHandler then
            Events.OnPlayerUpdate.Remove(validateHandler)
        end
    end

    local ticksByPlayer = {}
    validateHandler = function(playerObj)
        if not playerObj or safeIsNPC(playerObj) then
            return
        end

        local okPlayerNum, playerNum = pcall(function()
            return playerObj:getPlayerNum()
        end)
        if not okPlayerNum or playerNum == nil then
            return
        end

        local tick = ticksByPlayer[playerNum] or 0
        if tick < 15 then
            ticksByPlayer[playerNum] = tick + 1
            return
        end
        ticksByPlayer[playerNum] = 0

        local okPrimary, primHand = pcall(function()
            return playerObj:getPrimaryHandItem()
        end)
        if okPrimary and primHand then
            local okContainer, container = pcall(function()
                return primHand:getContainer()
            end)
            if okContainer and not container then
                playerObj:setPrimaryHandItem(nil)
            end
        end

        local okSecondary, secHand = pcall(function()
            return playerObj:getSecondaryHandItem()
        end)
        if okSecondary and secHand then
            local okContainer, container = pcall(function()
                return secHand:getContainer()
            end)
            if okContainer and not container then
                playerObj:setSecondaryHandItem(nil)
            end
        end
    end

    monitor.validateEquippedItems = validateHandler
    if Events and Events.OnPlayerUpdate and Events.OnPlayerUpdate.Add then
        Events.OnPlayerUpdate.Add(validateHandler)
    end
    return true
end

local function patchMainGridRefresh()
    local ok, ItemContainerGrid = pcall(require, "InventoryTetris/Model/ItemContainerGrid")
    if not ok or type(ItemContainerGrid) ~= "table" or type(ItemContainerGrid.new) ~= "function" then
        return false
    end

    ItemContainerGrid._ggsPlayerMainGrids = ItemContainerGrid._ggsPlayerMainGrids or {}
    ItemContainerGrid._playerMainGrids = {}

    ItemContainerGrid._getPlayerMainGrid = function(playerObj, playerNum)
        if not playerObj then
            return nil
        end

        local okInventory, inventory = pcall(function()
            return playerObj:getInventory()
        end)
        if not okInventory or not inventory then
            return nil
        end

        local containerGrid = ItemContainerGrid._ggsPlayerMainGrids[playerNum]
        if containerGrid and containerGrid.inventory ~= inventory then
            containerGrid = nil
        end
        if not containerGrid then
            containerGrid = ItemContainerGrid:new(inventory, playerNum)
            ItemContainerGrid._ggsPlayerMainGrids[playerNum] = containerGrid
        end

        ItemContainerGrid._playerMainGrids[playerNum] = nil
        return containerGrid
    end

    if mainGridTickHandler and Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(mainGridTickHandler)
    end

    mainGridTickHandler = function()
        ItemContainerGrid._playerMainGrids = {}

        for playerNum, grid in pairs(ItemContainerGrid._ggsPlayerMainGrids) do
            local playerObj = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
            if not playerObj or safeIsDead(playerObj) or safeIsNPC(playerObj) then
                ItemContainerGrid._ggsPlayerMainGrids[playerNum] = nil
            elseif grid and type(grid.shouldRefresh) == "function" and type(grid.refresh) == "function" then
                local okRefresh, shouldRefresh = pcall(function()
                    return grid:shouldRefresh()
                end)
                if okRefresh and shouldRefresh then
                    pcall(function()
                        grid:refresh()
                    end)
                end
            end
        end

        if type(ItemContainerGrid._gridCache) == "table" then
            for _, grids in pairs(ItemContainerGrid._gridCache) do
                wipeTable(grids)
            end
        end
    end

    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(mainGridTickHandler)
    end
    return true
end

local function applyPatch()
    local active = isInventoryTetrisActive()
    if active ~= true then
        return false, active == false and "inactive" or "unknown"
    end
    if not InventoryTetris then
        return false, "pending"
    end

    local okValidate = patchValidateEquippedItems()
    local okGrid = patchMainGridRefresh()
    if okValidate and okGrid then
        if not patched then
            logCompat("Inventory Tetris isNPC fallback installed")
        end
        patched = true
        return true, "patched"
    end
    return false, "pending"
end

local function retryPatch()
    local ok, reason = applyPatch()
    if (ok or reason == "inactive") and Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(retryPatch)
    end
end

if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(applyPatch)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(applyPatch)
end
if Events and Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(retryPatch)
end
