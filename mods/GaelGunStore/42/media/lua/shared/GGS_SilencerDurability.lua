-- Temporarily disabled while isolating timed-action bridge crashes.
-- Silencer sound/light systems stay active without durability wear.
if true then
    return
end

local GGSPartDurability = {}

local DEFAULT_PART_CONDITION_MAX = 100
local BREAK_SOUND_EVENT = "BreakAtt"
local SKIP_CLIP_PART_WEAR = true
local DEFAULT_ATTACHMENTS_LOWER_CHANCE = 200
local DEFAULT_SILENCERS_LOWER_CHANCE = 200

local SLOT_ALIAS_TO_CANONICAL = {
    Hanguard = "Handguard",
    Mag = "Clip",
}

local FALLBACK_CHILD_SLOTS = {
    Handguard = {"Grip", "Laser", "Light", "Stool"},
    Mount = {"Scope", "L_Scope", "Laser", "Light", "Stock"},
}

local SLOT_ALIASES = {
    Handguard = {"Hanguard"},
    Clip = {"Mag"},
}

local function normalizeSlot(slot)
    if not slot then
        return slot
    end
    return SLOT_ALIAS_TO_CANONICAL[slot] or slot
end

local function getSandboxValue(key)
    local root = SandboxVars or nil
    if not root then
        return nil
    end

    local value = nil
    if root.GGSGS then
        value = root.GGSGS[key]
    end
    if value == nil and root.GGS then
        value = root.GGS[key]
    end
    return value
end

local function getSandboxBoolean(key, defaultValue)
    local value = getSandboxValue(key)
    if value == nil then
        return defaultValue
    end

    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end
    if type(value) == "string" then
        local lower = value:lower()
        return lower == "true" or lower == "1" or lower == "yes"
    end

    return defaultValue
end

local function getSandboxNumber(key, defaultValue, minValue)
    local value = getSandboxValue(key)
    if value == nil then
        return defaultValue
    end

    local numberValue = nil
    if type(value) == "number" then
        numberValue = value
    elseif type(value) == "string" then
        numberValue = tonumber(value)
    elseif type(value) == "boolean" then
        numberValue = value and 1 or 0
    end

    if numberValue == nil then
        return defaultValue
    end

    numberValue = math.floor(numberValue + 0.5)
    if minValue ~= nil and numberValue < minValue then
        numberValue = minValue
    end
    return numberValue
end

local function isWeaponPart(item)
    if not item then
        return false
    end
    if instanceof(item, "WeaponPart") then
        return true
    end
    return false
end

local function hasPartTag(part, tag)
    if not part or not tag or not part.hasTag then
        return false
    end
    local ok, result = pcall(part.hasTag, part, tag)
    return ok and result == true
end

local function isSilencerPart(part)
    if not isWeaponPart(part) then
        return false
    end

    local partType = normalizeSlot(part.getPartType and part:getPartType() or nil)
    if partType then
        local lowerPartType = tostring(partType):lower()
        if lowerPartType == "canon" or lowerPartType == "silencer" or lowerPartType == "suppressor" then
            return true
        end
    end

    if hasPartTag(part, "silencers") or hasPartTag(part, "silencer") or hasPartTag(part, "suppressor") then
        return true
    end

    local ids = tostring(part.getType and part:getType() or "") .. " " ..
        tostring(part.getFullType and part:getFullType() or "")
    local lowerIds = ids:lower()
    return lowerIds:find("silencer", 1, true) ~= nil or lowerIds:find("suppressor", 1, true) ~= nil
end

local function shouldWearPart(part)
    if not isWeaponPart(part) then
        return false
    end
    if SKIP_CLIP_PART_WEAR then
        local partType = normalizeSlot(part.getPartType and part:getPartType() or nil)
        if partType == "Clip" then
            return false
        end
    end
    return true
end

local function getConfiguredLowerChances()
    local attachmentsLowerChance = getSandboxNumber("AttachmentsLowerChance", nil, 1)
    if attachmentsLowerChance == nil then
        attachmentsLowerChance = getSandboxNumber("attachments_lower_chance", DEFAULT_ATTACHMENTS_LOWER_CHANCE, 1)
    end

    local silencersLowerChance = getSandboxNumber("SilencersLowerChance", nil, 1)
    if silencersLowerChance == nil then
        silencersLowerChance = getSandboxNumber("silencers_lower_chance", DEFAULT_SILENCERS_LOWER_CHANCE, 1)
    end

    return attachmentsLowerChance, silencersLowerChance
end

local function getPartLowerChance(part, attachmentsLowerChance, silencersLowerChance)
    if isSilencerPart(part) then
        return silencersLowerChance
    end
    return attachmentsLowerChance
end

local function rollWearChance(lowerChance)
    if lowerChance <= 1 then
        return true
    end
    if ZombRand then
        return ZombRand(lowerChance) == 0
    end
    return math.random(lowerChance) == 1
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function ensurePartCondition(part, forceMax)
    if not isWeaponPart(part) then
        return 0, 0
    end

    local maxCondition = part.getConditionMax and part:getConditionMax() or 0
    if maxCondition <= 0 and part.setConditionMax then
        maxCondition = DEFAULT_PART_CONDITION_MAX
        part:setConditionMax(maxCondition)
    end

    if maxCondition <= 0 then
        return 0, 0
    end

    local condition = part.getCondition and part:getCondition() or maxCondition
    if condition <= 0 then
        condition = maxCondition
    end

    condition = clamp(condition, 0, maxCondition)
    if forceMax then
        condition = maxCondition
    end

    if part.setCondition then
        part:setCondition(condition)
    end

    return maxCondition, condition
end

local function playBreakSound(player)
    if not player then
        return
    end
    if player.playSound then
        pcall(player.playSound, player, BREAK_SOUND_EVENT)
    end
end

local function inventoryContains(inventory, item)
    return inventory and item and inventory.contains and inventory:contains(item)
end

local function tryAddToInventory(player, item)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory or not item then
        return false
    end
    if inventoryContains(inventory, item) then
        return true
    end

    local hasRoom = true
    if inventory.hasRoomFor then
        local ok, room = pcall(inventory.hasRoomFor, inventory, player, item)
        if ok and room == false then
            hasRoom = false
        end
    end

    if hasRoom and inventory.AddItem then
        pcall(inventory.AddItem, inventory, item)
    end

    return inventoryContains(inventory, item)
end

local function dropToPlayerSquare(player, item)
    local square = player and player.getSquare and player:getSquare() or nil
    if not square or not item then
        return false
    end
    local ok = pcall(square.AddWorldInventoryItem, square, item, 0.0, 0.0, 0.0)
    return ok == true
end

local function ensurePartInInventoryOrGround(player, part)
    if not player or not part then
        return
    end

    local inventory = player:getInventory()
    if inventoryContains(inventory, part) then
        return
    end

    if tryAddToInventory(player, part) then
        return
    end

    dropToPlayerSquare(player, part)
end

local function removePartFromInventory(player, part)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory or not part then
        return
    end
    if inventory:contains(part) then
        inventory:Remove(part)
    end
end

local function getWeaponPartBySlot(weapon, slot)
    if not weapon or not slot then
        return nil
    end

    local part = weapon:getWeaponPart(slot)
    if part then
        return part
    end

    local canonical = normalizeSlot(slot)
    if canonical ~= slot then
        part = weapon:getWeaponPart(canonical)
        if part then
            return part
        end
    end

    local aliases = SLOT_ALIASES[canonical]
    if aliases then
        for _, alias in ipairs(aliases) do
            part = weapon:getWeaponPart(alias)
            if part then
                return part
            end
        end
    end

    return nil
end

local function appendUniqueSlot(result, seen, slot)
    local normalized = normalizeSlot(slot)
    if not normalized then
        return
    end
    if seen[normalized] then
        return
    end
    seen[normalized] = true
    table.insert(result, normalized)
end

local function getChildSlotsForPart(part)
    local result = {}
    local seen = {}

    local partType = normalizeSlot(part and part.getPartType and part:getPartType() or nil)
    local fallback = FALLBACK_CHILD_SLOTS[partType]
    if fallback then
        for _, slot in ipairs(fallback) do
            appendUniqueSlot(result, seen, slot)
        end
    end

    local allowByAttachment = rawget(_G, "AWCWF_AttAllowAttachments")
    if allowByAttachment and part and part.getFullType then
        local fullType = part:getFullType()
        local dynamicSlots = allowByAttachment[fullType]
        if dynamicSlots then
            for _, slot in ipairs(dynamicSlots) do
                appendUniqueSlot(result, seen, slot)
            end
        end
    end

    return result
end

local function collectChildren(weapon, parentPart)
    local children = {}
    local seen = {}

    for _, slot in ipairs(getChildSlotsForPart(parentPart)) do
        local child = getWeaponPartBySlot(weapon, slot)
        if child and child ~= parentPart and not seen[child] then
            seen[child] = true
            table.insert(children, child)
        end
    end

    return children
end

local function detachPart(player, weapon, part, keepPart)
    if not weapon or not part then
        return
    end

    pcall(weapon.detachWeaponPart, weapon, player, part)

    if keepPart then
        ensurePartInInventoryOrGround(player, part)
    else
        removePartFromInventory(player, part)
    end
end

local function detachChildrenRecursive(player, weapon, parentPart, visited)
    if not parentPart or visited[parentPart] then
        return
    end
    visited[parentPart] = true

    local children = collectChildren(weapon, parentPart)
    for _, child in ipairs(children) do
        detachChildrenRecursive(player, weapon, child, visited)
        detachPart(player, weapon, child, true)
    end
end

local function breakPart(player, weapon, part)
    if not weapon or not part then
        return
    end

    local visited = {}
    detachChildrenRecursive(player, weapon, part, visited)
    detachPart(player, weapon, part, false)
    playBreakSound(player)
end

local function canProcessWeapon(player, weapon)
    if not player or not weapon then
        return false
    end
    if not instanceof(weapon, "HandWeapon") then
        return false
    end
    if not weapon.isRanged or not weapon:isRanged() then
        return false
    end
    return true
end

local function wearWeaponPartsOnShot(player, weapon)
    if isServer() and not isClient() then
        return
    end
    if not getSandboxBoolean("weaponpart_wear_by_shot", false) then
        return
    end
    if not canProcessWeapon(player, weapon) then
        return
    end
    if not weapon.getAllWeaponParts then
        return
    end

    local parts = weapon:getAllWeaponParts()
    if not parts then
        return
    end

    local attachmentsLowerChance, silencersLowerChance = getConfiguredLowerChances()
    local toBreak = {}
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if shouldWearPart(part) then
            local lowerChance = getPartLowerChance(part, attachmentsLowerChance, silencersLowerChance)
            if lowerChance and rollWearChance(lowerChance) then
                local maxCondition, currentCondition = ensurePartCondition(part, false)
                if maxCondition > 0 then
                    local remaining = clamp(currentCondition - 1, 0, maxCondition)
                    part:setCondition(remaining)
                    if remaining <= 0 then
                        table.insert(toBreak, part)
                    end
                end
            end
        end
    end

    for _, part in ipairs(toBreak) do
        breakPart(player, weapon, part)
    end
end

local function refreshInventoryPartConditionCaps(player)
    if isServer() and not isClient() then
        return
    end
    if not player or not player.getInventory then
        return
    end

    local inventory = player:getInventory()
    if not inventory or not inventory.getAllEvalRecurse then
        return
    end
    if not ArrayList or not ArrayList.new then
        return
    end

    local parts = inventory:getAllEvalRecurse(function(item)
        return isWeaponPart(item)
    end, ArrayList.new())

    for i = 0, parts:size() - 1 do
        ensurePartCondition(parts:get(i), false)
    end
end

local inventoryRefreshTick = 0
local function onPlayerUpdate(player)
    inventoryRefreshTick = (inventoryRefreshTick + 1) % 180
    if inventoryRefreshTick ~= 0 then
        return
    end
    refreshInventoryPartConditionCaps(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnWeaponSwing.Add(wearWeaponPartsOnShot)
