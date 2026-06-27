--[[
    Sistema de accesorios para GaelGunStore.
    Permite definir accesorios por arma.
    Copyright GaelGunStore
]]
local AttachmentRules = AWCWF_AttachmentRules or {}
AWCWF_AttachmentRules = AttachmentRules

AttachmentRules.aliasToCanonical = {
    Mag = "Clip",
    Hanguard = "Handguard"
}

local specialSlotMap = {
    ClipType = "Clip"
}

local slotConflictPairs = AWCWF_SlotConflictRules or {}
-- Tabla de conflictos por defecto:
table.insert(slotConflictPairs, {"Mount", "L_Scope"})
table.insert(slotConflictPairs, {"Laser", "Light"})
table.insert(slotConflictPairs, {"Scope", "L_Scope"})
table.insert(slotConflictPairs, {"Stool", "Barrel_Shroud"})
table.insert(slotConflictPairs, {"Stool", "Grip"})
local slotConflictMap = {}

local canonicalToAliases = {}
for alias, canonical in pairs(AttachmentRules.aliasToCanonical) do
    canonicalToAliases[canonical] = canonicalToAliases[canonical] or {}
    table.insert(canonicalToAliases[canonical], alias)
end

local function normalizeSlot(slot)
    if not slot then
        return slot
    end
    slot = specialSlotMap[slot] or slot
    return AttachmentRules.aliasToCanonical[slot] or slot
end

local function addConflict(source, target)
    if not source or not target or source == target then
        return
    end
    slotConflictMap[source] = slotConflictMap[source] or {}
    slotConflictMap[source][target] = true
end

local function buildSlotConflictMap()
    for _, group in ipairs(slotConflictPairs) do
        if type(group) == "table" then
            local normalized = {}
            for _, entry in ipairs(group) do
                local canonical = normalizeSlot(entry)
                if canonical then
                    table.insert(normalized, canonical)
                end
            end
            for i = 1, #normalized do
                for j = i + 1, #normalized do
                    addConflict(normalized[i], normalized[j])
                    addConflict(normalized[j], normalized[i])
                end
            end
        end
    end
end

buildSlotConflictMap()

local function isHandgunLike(weapon)
    if not weapon then
        return false
    end
    local anim = weapon.getSwingAnim and weapon:getSwingAnim() or nil
    if anim == "Handgun" or anim == "Pistol" then
        return true
    end
    if weapon.isTwoHandWeapon and weapon:isTwoHandWeapon() == false then
        return true
    end
    return false
end

local function addSlotAliasEntries(set, canonical)
    local aliasList = canonicalToAliases[canonical]
    if aliasList then
        for _, alias in ipairs(aliasList) do
            set[alias] = true
        end
    end
end

local function addSlotToSet(set, slot)
    if not slot then
        return
    end
    set[slot] = true
    local canonical = normalizeSlot(slot)
    set[canonical] = true
    addSlotAliasEntries(set, canonical)
end

local function getPartList()
    if AWCWF_AdditionalParts and AWCWF_AdditionalParts.partlist then
        return AWCWF_AdditionalParts.partlist
    end
    return {}
end

local function getAttachmentForSlot(weapon, slot)
    if not weapon or not slot then
        return nil
    end
    local part = weapon:getWeaponPart(slot)
    if part then
        return part, slot
    end
    local canonical = normalizeSlot(slot)
    if canonical ~= slot then
        part = weapon:getWeaponPart(canonical)
        if part then
            return part, canonical
        end
    end
    local aliasList = canonicalToAliases[canonical]
    if aliasList then
        for _, alias in ipairs(aliasList) do
            part = weapon:getWeaponPart(alias)
            if part then
                return part, alias
            end
        end
    end
    return nil
end

local function isSlotBlockedByConflict(weapon, slot)
    if not weapon or not slot then
        return false
    end
    local canonical = normalizeSlot(slot)
    local conflicts = slotConflictMap[canonical]
    if not conflicts then
        return false
    end
    for conflictSlot in pairs(conflicts) do
        -- Laser/Light conflict only applies to handgun-like weapons
        if (canonical == "Laser" and conflictSlot == "Light") or (canonical == "Light" and conflictSlot == "Laser") then
            if isHandgunLike(weapon) then
                local blockingPart = getAttachmentForSlot(weapon, conflictSlot)
                if blockingPart then
                    return true
                end
            end
        else
            local blockingPart = getAttachmentForSlot(weapon, conflictSlot)
            if blockingPart then
                return true
            end
        end
    end
    return false
end

local function slotsMatch(slotA, slotB)
    if slotA == slotB then
        return true
    end
    if not slotA or not slotB then
        return false
    end
    return normalizeSlot(slotA) == normalizeSlot(slotB)
end

local function isSlotSuppressedByExclusion(part, slot, weapon)
    if not part or not slot or not weapon then
        return false
    end
    if not AWCWF_AttSlotExclusions then
        return false
    end
    local rules = AWCWF_AttSlotExclusions[part:getFullType()]
    if not rules then
        return false
    end
    for _, group in ipairs(rules) do
        local slotInGroup
        for _, groupSlot in ipairs(group) do
            if slotsMatch(groupSlot, slot) then
                slotInGroup = true
                break
            end
        end
        if slotInGroup then
            for _, groupSlot in ipairs(group) do
                if not slotsMatch(groupSlot, slot) then
                    local blockingPart = getAttachmentForSlot(weapon, groupSlot)
                    if blockingPart then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function AttachmentRules.getVisibleSlots(weapon)
    local function compute()
        if not weapon or not weapon.getFullType then
            return {}
        end
        local config = AWCWF_GunAllowAttachments and AWCWF_GunAllowAttachments[weapon:getFullType()]
        -- Fallback mode for isolation: when a weapon has no explicit config,
        -- expose slots instead of hiding all of them.
        if not config or (type(config) == "table" and #config == 0) then
            return nil
        end
        local allowed = {}
        for _, slot in ipairs(config) do
            addSlotToSet(allowed, slot)
        end
        for _, slotName in ipairs(getPartList()) do
            local part = getAttachmentForSlot(weapon, slotName)
            if part then
                addSlotToSet(allowed, slotName)
                addSlotToSet(allowed, part:getPartType())
                local unlocks = AWCWF_AttAllowAttachments and AWCWF_AttAllowAttachments[part:getFullType()]
                if unlocks then
                    for _, unlockedSlot in ipairs(unlocks) do
                        if not isSlotSuppressedByExclusion(part, unlockedSlot, weapon) then
                            addSlotToSet(allowed, unlockedSlot)
                        end
                    end
                end
            end
        end
        return allowed
    end
    local ok, result = pcall(compute)
    if not ok then
        print("GGS: getVisibleSlots error -> defaulting to open slots: " .. tostring(result))
        return nil
    end
    return result
end

function AttachmentRules.isSlotVisible(weapon, slot, cached)
    if not slot then
        return true
    end
    if isSlotBlockedByConflict(weapon, slot) then
        return false
    end
    local allowed = cached
    if allowed == nil then
        allowed = AttachmentRules.getVisibleSlots(weapon)
    end
    if allowed == nil then
        return true
    end
    if allowed[slot] then
        return true
    end
    local canonical = normalizeSlot(slot)
    if allowed[canonical] then
        return true
    end
    local aliasList = canonicalToAliases[canonical]
    if aliasList then
        for _, alias in ipairs(aliasList) do
            if allowed[alias] then
                return true
            end
        end
    end
    return false
end

function AttachmentRules.canInstallOnWeapon(weapon, part, cached)
    if not weapon or not part then
        return false
    end
    local slot = part:getPartType()
    if not slot then
        return true
    end
    return AttachmentRules.isSlotVisible(weapon, slot, cached)
end

function AttachmentRules.getBlockingChildren(weapon, part)
    if not weapon or not part then
        return nil
    end
    local unlocks = AWCWF_AttAllowAttachments and AWCWF_AttAllowAttachments[part:getFullType()]
    if not unlocks then
        return nil
    end
    local result
    for _, slot in ipairs(unlocks) do
        local child, resolvedSlot = getAttachmentForSlot(weapon, slot)
        if child then
            result = result or {}
            table.insert(result, {slot = resolvedSlot or slot, part = child})
        end
    end
    return result
end

function AttachmentRules.canRemovePart(weapon, part)
    -- Block removing a part while child parts are still mounted on it (e.g. a
    -- grip/bipod/light on the handguard). Removing the parent first orphaned the
    -- children and crashed the game to the main menu. The UI shows a "remove X
    -- first" message so each part can still be removed, just children-first.
    local blocking = AttachmentRules.getBlockingChildren(weapon, part)
    if blocking and #blocking > 0 then
        return false, blocking
    end
    return true
end

function AttachmentRules.getAttachment(weapon, slot)
    return getAttachmentForSlot(weapon, slot)
end

return AttachmentRules
