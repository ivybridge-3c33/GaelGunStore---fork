-- Server-side fallback recovery for rare MP magazine loss.
-- Conservative rule: restore only if old magazine ID vanished and inventory count dropped.

if not isServer() then
    return
end

require "GGS_MagMapping"

local MOD = "GGS MagRecovery"
local DEBUG = false
local CHECK_DELAY_TICKS = 90
local TRACK_INTERVAL_TICKS = 2
local RESTORED_TTL_TICKS = 36000
local SEARCH_RADIUS = 1

local function dlog(msg)
    if DEBUG then
        print("[" .. MOD .. "] " .. tostring(msg))
    end
end

local function logRestore(msg)
    print("[" .. MOD .. "] " .. tostring(msg))
end

local function toMagFullType(typeName)
    if not typeName then
        return nil
    end
    if _G.GGS_MagMapping and _G.GGS_MagMapping.toFullType then
        return _G.GGS_MagMapping.toFullType(typeName)
    end
    if tostring(typeName):find("%.") then
        return tostring(typeName)
    end
    return "Base." .. tostring(typeName)
end

local function weaponHasMagazineState(weapon)
    if not weapon or not weapon.IsWeapon or not weapon:IsWeapon() then
        return false
    end
    if weapon.getMagazineType and weapon:getMagazineType() then
        return true
    end
    if weapon.getMagazine and weapon:getMagazine() then
        return true
    end
    if weapon.getClip and weapon:getClip() then
        return true
    end
    if weapon.isContainsClip and weapon:isContainsClip() then
        return true
    end
    return false
end

local function getTrackedWeapon(player)
    if not player then
        return nil
    end
    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    if weaponHasMagazineState(primary) then
        return primary
    end
    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if weaponHasMagazineState(secondary) then
        return secondary
    end
    return nil
end

local function getWeaponMagazine(weapon)
    if weapon and weapon.getMagazine then
        local ok, mag = pcall(weapon.getMagazine, weapon)
        if ok then
            return mag
        end
    end
    if weapon and weapon.getClip then
        local ok, mag = pcall(weapon.getClip, weapon)
        if ok then
            return mag
        end
    end
    if weapon and weapon.getCurrentMagazine then
        local ok, mag = pcall(weapon.getCurrentMagazine, weapon)
        if ok then
            return mag
        end
    end
    return nil
end

local function getItemId(item)
    if item and item.getID then
        local ok, id = pcall(item.getID, item)
        if ok then
            return id
        end
    end
    return nil
end

local function getMagType(weapon, magazine)
    if magazine and magazine.getFullType then
        local ok, full = pcall(magazine.getFullType, magazine)
        if ok and full and full ~= "" then
            return tostring(full)
        end
    end
    if weapon and weapon.getMagazineType then
        local ok, mag = pcall(weapon.getMagazineType, weapon)
        if ok and mag and mag ~= "" then
            return toMagFullType(mag)
        end
    end
    return nil
end

local function getMagAmmo(weapon, magazine)
    if magazine and magazine.getCurrentAmmoCount then
        local ok, ammo = pcall(magazine.getCurrentAmmoCount, magazine)
        if ok and ammo ~= nil then
            return tonumber(ammo) or 0
        end
    end
    if magazine and magazine.getAmmoCount then
        local ok, ammo = pcall(magazine.getAmmoCount, magazine)
        if ok and ammo ~= nil then
            return tonumber(ammo) or 0
        end
    end
    if weapon and weapon.getCurrentAmmoCount then
        local ok, ammo = pcall(weapon.getCurrentAmmoCount, weapon)
        if ok and ammo ~= nil then
            return tonumber(ammo) or 0
        end
    end
    return 0
end

local function weaponHasMagazineId(weapon, targetId)
    if not weapon or not targetId then
        return false
    end
    if not (weapon.IsWeapon and weapon:IsWeapon()) then
        return false
    end
    local mag = getWeaponMagazine(weapon)
    return getItemId(mag) == targetId
end

local function countFullTypeRecursive(container, fullType)
    if not container or not fullType then
        return 0
    end
    local items = container:getItems()
    if not items then
        return 0
    end
    local count = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local itemType = item.getFullType and item:getFullType() or nil
            if itemType == fullType then
                count = count + 1
            end
            if instanceof(item, "InventoryContainer") then
                count = count + countFullTypeRecursive(item:getInventory(), fullType)
            end
        end
    end
    return count
end

local function findItemByIdRecursive(container, targetId)
    if not container or not targetId then
        return false
    end
    local items = container:getItems()
    if not items then
        return false
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if item.getID and item:getID() == targetId then
                return true
            end
            if weaponHasMagazineId(item, targetId) then
                return true
            end
            if instanceof(item, "InventoryContainer") then
                if findItemByIdRecursive(item:getInventory(), targetId) then
                    return true
                end
            end
        end
    end
    return false
end

local function findItemByIdAroundPlayer(player, targetId)
    if not player or not targetId then
        return false
    end

    if findItemByIdRecursive(player:getInventory(), targetId) then
        return true
    end

    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    if primary and primary.getID and primary:getID() == targetId then
        return true
    end
    if weaponHasMagazineId(primary, targetId) then
        return true
    end
    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if secondary and secondary.getID and secondary:getID() == targetId then
        return true
    end
    if weaponHasMagazineId(secondary, targetId) then
        return true
    end

    local square = player:getSquare()
    if not square then
        return false
    end

    for dx = -SEARCH_RADIUS, SEARCH_RADIUS do
        for dy = -SEARCH_RADIUS, SEARCH_RADIUS do
            local s = getSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            if s then
                local worldObjs = s:getWorldObjects()
                if worldObjs then
                    for i = 0, worldObjs:size() - 1 do
                        local wo = worldObjs:get(i)
                        if wo and instanceof(wo, "WorldInventoryItem") then
                            local item = wo:getItem()
                            if item and item.getID and item:getID() == targetId then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

local function getOnlinePlayerByID(targetId)
    local players = getOnlinePlayers()
    if not players then
        return nil
    end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p and p.getOnlineID and p:getOnlineID() == targetId then
            return p
        end
    end
    return nil
end

local function addMagazineToPlayer(player, magType, ammo)
    if not player or not magType then
        return false
    end
    local full = toMagFullType(magType)
    if not full then
        return false
    end
    if ScriptManager and ScriptManager.instance and not ScriptManager.instance:getItem(full) then
        dlog("skip restore, unknown script item " .. tostring(full))
        return false
    end
    local inv = player:getInventory()
    if not inv then
        return false
    end
    local item = inv:AddItem(full)
    if not item then
        return false
    end
    if item.setCurrentAmmoCount then
        local safeAmmo = math.max(0, tonumber(ammo) or 0)
        pcall(item.setCurrentAmmoCount, item, safeAmmo)
    end
    if sendAddItemToContainer then
        pcall(sendAddItemToContainer, inv, item)
    end
    return true
end

local lastByPlayer = {}
local pendingJobs = {}
local queuedByMagId = {}
local restoredByMagId = {}
local tickCounter = 0

local function queueRecoveryJob(playerId, prevState)
    if not prevState or not prevState.magID or not prevState.magType then
        return
    end
    if queuedByMagId[prevState.magID] then
        return
    end
    if restoredByMagId[prevState.magID] then
        return
    end
    queuedByMagId[prevState.magID] = true
    pendingJobs[#pendingJobs + 1] = {
        playerID = playerId,
        oldMagID = prevState.magID,
        oldType = prevState.magType,
        oldAmmo = prevState.magAmmo,
        invCountBefore = prevState.invCount,
        ticks = 0,
    }
    dlog(string.format("queued oldMagID=%s type=%s", tostring(prevState.magID), tostring(prevState.magType)))
end

local function trackPlayer(player)
    if not player then
        return
    end
    local playerId = player:getOnlineID()
    if playerId == nil then
        return
    end

    local weapon = getTrackedWeapon(player)
    if not weapon then
        lastByPlayer[playerId] = nil
        return
    end

    local mag = getWeaponMagazine(weapon)
    local state = {
        weaponID = getItemId(weapon),
        magID = getItemId(mag),
        magType = getMagType(weapon, mag),
        magAmmo = getMagAmmo(weapon, mag),
        invCount = nil,
    }
    if state.magType then
        state.invCount = countFullTypeRecursive(player:getInventory(), state.magType)
    end

    local prev = lastByPlayer[playerId]
    if prev
        and prev.weaponID ~= nil
        and state.weaponID ~= nil
        and prev.weaponID == state.weaponID
        and prev.magID ~= nil
        and prev.magID ~= state.magID then
        queueRecoveryJob(playerId, prev)
    end

    lastByPlayer[playerId] = state
end

local function processRecoveryJobs()
    if #pendingJobs == 0 then
        return
    end

    local i = 1
    while i <= #pendingJobs do
        local job = pendingJobs[i]
        job.ticks = job.ticks + 1

        if job.ticks >= CHECK_DELAY_TICKS then
            local restored = false
            local player = getOnlinePlayerByID(job.playerID)
            if player and job.oldMagID and job.oldType then
                local existsById = findItemByIdAroundPlayer(player, job.oldMagID)
                local afterCount = countFullTypeRecursive(player:getInventory(), job.oldType)
                local beforeCount = tonumber(job.invCountBefore)
                if beforeCount == nil then
                    beforeCount = afterCount
                end

                local countDropped = afterCount < beforeCount
                local zeroToZeroEdge = (beforeCount == 0 and afterCount == 0)
                if (not existsById) and (countDropped or zeroToZeroEdge) then
                    if not restoredByMagId[job.oldMagID] then
                        restored = addMagazineToPlayer(player, job.oldType, job.oldAmmo)
                        if restored then
                            restoredByMagId[job.oldMagID] = tickCounter
                            logRestore(string.format(
                                "restored missing magazine id=%s type=%s ammo=%s before=%d after=%d",
                                tostring(job.oldMagID),
                                tostring(job.oldType),
                                tostring(job.oldAmmo),
                                tonumber(beforeCount) or -1,
                                tonumber(afterCount) or -1
                            ))
                        end
                    end
                end
            end

            queuedByMagId[job.oldMagID] = nil
            pendingJobs[i] = pendingJobs[#pendingJobs]
            pendingJobs[#pendingJobs] = nil
            if not restored then
                -- keep i, swapped element not processed yet
            end
        else
            i = i + 1
        end
    end
end

local function cleanupRecoveredCache()
    for magId, restoredTick in pairs(restoredByMagId) do
        if (tickCounter - restoredTick) > RESTORED_TTL_TICKS then
            restoredByMagId[magId] = nil
        end
    end
end

Events.OnTick.Add(function()
    tickCounter = tickCounter + 1

    if tickCounter % TRACK_INTERVAL_TICKS == 0 then
        local players = getOnlinePlayers()
        if players then
            for i = 0, players:size() - 1 do
                local p = players:get(i)
                if p then
                    trackPlayer(p)
                end
            end
        end
    end

    processRecoveryJobs()

    if tickCounter % 600 == 0 then
        cleanupRecoveredCache()
    end
end)
