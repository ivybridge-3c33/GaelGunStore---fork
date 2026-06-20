require "ISUI/ISRadialMenu"
pcall(require, "WeaponAbility/ChangeMagazineType")

local function ggsText(key)
    local text = getText(key)
    if text and text ~= key then
        return text
    end
    return key
end

local function getLocalPlayer()
    if getSpecificPlayer then
        local playerObj = getSpecificPlayer(0)
        if playerObj then
            return playerObj
        end
    end
    return getPlayer and getPlayer() or nil
end

local function shortType(typeName)
    if not typeName then
        return nil
    end
    local raw = tostring(typeName)
    local short = raw:match("([^.]+)$")
    return short or raw
end

local function fullType(typeName)
    if not typeName then
        return nil
    end
    local raw = tostring(typeName)
    if raw:find("%.") then
        return raw
    end
    return "Base." .. raw
end

local function instanceItemSafe(typeName)
    if not (typeName and instanceItem) then
        return nil
    end
    local ok, item = pcall(instanceItem, typeName)
    if ok then
        return item
    end
    return nil
end

local function eachItemRecursive(container, visit)
    if not (container and visit) then
        return
    end
    local items = container.getItems and container:getItems() or nil
    if not items then
        return
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            visit(item)
            if instanceof(item, "InventoryContainer") and item.getInventory then
                eachItemRecursive(item:getInventory(), visit)
            end
        end
    end
end

local function getWeapon(playerObj)
    if not playerObj then
        return nil
    end
    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if not weapon then
        return nil
    end
    if not (weapon.IsWeapon and weapon:IsWeapon()) then
        return nil
    end
    if not (weapon.isRanged and weapon:isRanged()) then
        return nil
    end
    return weapon
end

local function getAllowedMagazineTypes(weapon)
    local result = {}
    local seen = {}
    local byWeapon = _G.AWCWF_WeaponMagazineType
    if not (byWeapon and weapon and weapon.getType) then
        return result
    end
    local allowed = byWeapon[weapon:getType()]
    if not allowed then
        return result
    end
    for i = 1, #allowed do
        local magType = tostring(allowed[i])
        local key = shortType(magType)
        if key and not seen[key] then
            seen[key] = true
            result[#result + 1] = magType
        end
    end
    return result
end

local function getInventoryMagStats(playerObj, magType)
    local stats = {
        count = 0,
        bestItem = nil,
        bestAmmo = -1,
        bestMax = 0
    }

    if not playerObj then
        return stats
    end
    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        return stats
    end

    local targetShort = shortType(magType)
    local targetFull = fullType(magType)

    eachItemRecursive(inventory, function(item)
        local itemFull = item.getFullType and item:getFullType() or nil
        if not itemFull then
            return
        end
        if itemFull ~= targetFull and shortType(itemFull) ~= targetShort then
            return
        end

        stats.count = stats.count + 1
        local ammo = item.getCurrentAmmoCount and item:getCurrentAmmoCount() or 0
        ammo = tonumber(ammo) or 0
        local maxAmmo = item.getMaxAmmo and item:getMaxAmmo() or 0
        maxAmmo = tonumber(maxAmmo) or 0
        if ammo > stats.bestAmmo then
            stats.bestAmmo = ammo
            stats.bestMax = maxAmmo
            stats.bestItem = item
        end
    end)

    if not stats.bestItem then
        stats.bestItem = instanceItemSafe(targetFull) or instanceItemSafe(targetShort)
        if stats.bestItem and stats.bestItem.getMaxAmmo then
            stats.bestMax = tonumber(stats.bestItem:getMaxAmmo()) or 0
            stats.bestAmmo = 0
        end
    end

    return stats
end

local function centerMenu(menu, playerNum)
    local x = getPlayerScreenLeft(playerNum)
    local y = getPlayerScreenTop(playerNum)
    local w = getPlayerScreenWidth(playerNum)
    local h = getPlayerScreenHeight(playerNum)
    x = x + w / 2
    y = y + h / 2
    menu:setX(x - menu:getWidth() / 2)
    menu:setY(y - menu:getHeight() / 2)
end

local function canOpenRadial(playerObj)
    if not playerObj or playerObj:isDead() then
        return false
    end
    if UIManager.getSpeedControls and UIManager.getSpeedControls() and
        UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then
        return false
    end
    if playerObj.isAiming and playerObj:isAiming() then
        return false
    end
    local queue = ISTimedActionQueue and ISTimedActionQueue.queues and ISTimedActionQueue.queues[playerObj] or nil
    if queue and queue.queue and #queue.queue > 0 then
        return false
    end
    return true
end

local function buildSliceLabel(magType, stats, isCurrent)
    local name = shortType(magType) or tostring(magType)
    local ammo = stats.bestAmmo >= 0 and stats.bestAmmo or 0
    local maxAmmo = stats.bestMax > 0 and stats.bestMax or 0
    local label = string.format("%s\n%d/%d x%d", name, ammo, maxAmmo, stats.count)
    if isCurrent then
        label = label .. "\n*Actual"
    end
    return label
end

local function hasMagSwapCandidates(playerObj, weapon)
    playerObj = playerObj or getLocalPlayer()
    weapon = weapon or getWeapon(playerObj)
    if not (playerObj and weapon) then
        return false
    end
    local allowedMagTypes = getAllowedMagazineTypes(weapon)
    if #allowedMagTypes <= 1 then
        return false
    end
    for i = 1, #allowedMagTypes do
        local stats = getInventoryMagStats(playerObj, allowedMagTypes[i])
        if stats and stats.count and stats.count > 0 then
            return true
        end
    end
    return false
end

local function openMagSwapRadial(playerObj, weapon, forceOpen)
    playerObj = playerObj or getLocalPlayer()
    if not canOpenRadial(playerObj) then
        return
    end

    weapon = weapon or getWeapon(playerObj)
    if not weapon then
        return
    end

    local playerNum = playerObj:getPlayerNum()
    local menu = getPlayerRadialMenu(playerNum)
    if menu:isReallyVisible() and not forceOpen then
        menu:removeFromUIManager()
        return
    end
    if menu:isReallyVisible() and forceOpen then
        menu:removeFromUIManager()
    end

    local allowedMagTypes = getAllowedMagazineTypes(weapon)
    if #allowedMagTypes == 0 then
        if playerObj.Say then
            playerObj:Say(ggsText("IGUI_GGS_NoMultiMagazine"))
        end
        return
    end

    menu:clear()
    local currentShort = shortType(weapon.getMagazineType and weapon:getMagazineType() or nil)
    local hasAvailable = false

    for i = 1, #allowedMagTypes do
        local magType = allowedMagTypes[i]
        local stats = getInventoryMagStats(playerObj, magType)
        local isCurrent = currentShort == shortType(magType)
        local label = buildSliceLabel(magType, stats, isCurrent)
        local icon = stats.bestItem and stats.bestItem.getTexture and stats.bestItem:getTexture() or nil
        if stats.count > 0 then
            hasAvailable = true
        end

        menu:addSlice(label, icon, function()
            menu:removeFromUIManager()
            local currentWeapon = getWeapon(playerObj)
            if not currentWeapon then
                return
            end
            if stats.count <= 0 then
                if playerObj.Say then
                    playerObj:Say(ggsText("IGUI_GGS_NoMagazine"))
                end
                return
            end
            if ChangeMagazine then
                ChangeMagazine(playerObj, currentWeapon, magType, "Radial", true)
            end
        end)
    end

    if not hasAvailable then
        if playerObj.Say then
            playerObj:Say(ggsText("IGUI_GGS_NoCompatibleMagazines"))
        end
        return
    end

    centerMenu(menu, playerNum)
    menu:addToUIManager()
end

_G.GGS_MagSwapRadial = _G.GGS_MagSwapRadial or {}
_G.GGS_MagSwapRadial.open = openMagSwapRadial
_G.GGS_MagSwapRadial.hasCandidates = hasMagSwapCandidates
