-- Shared helpers to map magazine items <-> clip weapon parts.
-- Keeps clip parts as the visual source of truth and derives magazine type from them.

local M = _G.GGS_MagMapping or {}
_G.GGS_MagMapping = M

local function toFullType(typeName)
    if not typeName or typeName == "" then
        return nil
    end
    if typeName:find("%.") then
        return typeName
    end
    return "Base." .. typeName
end

local function magKey(typeName)
    if not typeName or typeName == "" then
        return nil
    end
    if typeName:find("%.") then
        return typeName:match("([^.]+)$")
    end
    return typeName
end

local function normalizeClipFull(fullType)
    if not fullType or fullType == "" then
        return nil
    end
    if fullType:find("Clip_", 1, true) then
        if fullType:find("%.") then
            return fullType
        end
        return "Base." .. fullType
    end
    local moduleName, rest = fullType:match("([^%.]+)%.(.+)")
    if moduleName and rest then
        return moduleName .. ".Clip_" .. rest
    end
    return fullType
end

local function hasScriptItem(fullType)
    if not fullType then
        return false
    end
    if not ScriptManager or not ScriptManager.instance then
        return true
    end
    return ScriptManager.instance:getItem(fullType) ~= nil
end

local function getMagToPartMap()
    return _G.AWCWF_MagazineTypeToPart
end

local function ensureReverseMap()
    local map = getMagToPartMap()
    if not map then
        return
    end
    local size = 0
    for _ in pairs(map) do
        size = size + 1
    end
    if M._reverseMap and M._reverseSize == size then
        return
    end
    local reverse = {}
    for magType, clipType in pairs(map) do
        local magFull = toFullType(magType)
        if hasScriptItem(magFull) then
            local clipFull = normalizeClipFull(clipType)
            if clipFull then
                reverse[clipFull] = magFull
            end
        end
    end
    M._reverseMap = reverse
    M._reverseSize = size
end

function M.magTypeToClipPart(magType)
    if not magType then
        return nil
    end
    local map = getMagToPartMap()
    if map then
        local key = magKey(magType)
        local clip = map[magType] or (key and map[key]) or nil
        if clip then
            return normalizeClipFull(clip)
        end
    end
    -- Fallback: derive from magazine name (Clip_<MagName>).
    local full = toFullType(magType)
    local fallback = normalizeClipFull(full)
    if fallback and hasScriptItem(fallback) then
        return fallback
    end
    return nil
end

function M.clipPartToMagType(clipType)
    if not clipType then
        return nil
    end
    local clipFull = normalizeClipFull(clipType)
    ensureReverseMap()
    if M._reverseMap and M._reverseMap[clipFull] then
        return M._reverseMap[clipFull]
    end
    local map = getMagToPartMap()
    if map then
        local moduleName, rest = clipFull:match("^([^%.]+)%.Clip_(.+)$")
        if rest then
            local key = rest
            if map[key] or map[toFullType(key)] then
                return toFullType(key)
            end
        end
    end
    -- Fallback: strip Clip_ prefix to get magazine item.
    local moduleName, rest = clipFull:match("^([^%.]+)%.Clip_(.+)$")
    if rest then
        local magFull = moduleName .. "." .. rest
        if hasScriptItem(magFull) then
            return magFull
        end
    end
    return nil
end

function M.syncFromPart(weapon, opts)
    if not weapon or not weapon.getModData then
        return nil
    end
    local md = weapon:getModData()
    md.weaponpart = md.weaponpart or {}

    local clipFull = opts and opts.clipFull
    if not clipFull and weapon.getWeaponPart then
        local part = weapon:getWeaponPart("Clip")
        if part and part.getFullType then
            clipFull = part:getFullType()
        end
    end
    clipFull = normalizeClipFull(clipFull or md.weaponpart["Clip"] or md.lastClipType)
    if not clipFull then
        return nil
    end
    local magFull = M.clipPartToMagType(clipFull)
    if magFull and weapon.setMagazineType then
        weapon:setMagazineType(magFull)
    end
    if magFull and opts and opts.setMaxAmmo and weapon.setMaxAmmo then
        local magItem = instanceItem and instanceItem(magFull) or nil
        if magItem and magItem.getMaxAmmo then
            weapon:setMaxAmmo(magItem:getMaxAmmo())
        end
    end
    if magFull then
        md.MagazineTypeNow = magFull
    end
    md.weaponpart["Clip"] = clipFull
    md.lastClipType = clipFull
    return magFull, clipFull
end

function M.syncFromMagazine(weapon, opts)
    if not weapon or not weapon.getModData then
        return nil
    end
    local md = weapon:getModData()
    md.weaponpart = md.weaponpart or {}
    local magFull = opts and opts.magFull
    if not magFull and weapon.getMagazineType then
        magFull = weapon:getMagazineType()
    end
    magFull = magFull or md.MagazineTypeNow
    if not magFull then
        return nil
    end
    local clipFull = M.magTypeToClipPart(magFull)
    if clipFull then
        md.weaponpart["Clip"] = clipFull
        md.lastClipType = clipFull
        md.MagazineTypeNow = magFull
        if opts and opts.installPart and weapon.setWeaponPart then
            local clipItem = instanceItem and instanceItem(clipFull) or nil
            if clipItem and instanceof(clipItem, "WeaponPart") then
                -- B42 uses setWeaponPart(partType, weaponPart); avoid legacy flags.
                pcall(weapon.setWeaponPart, weapon, "Clip", clipItem)
            end
        end
    end
    return clipFull, magFull
end

M.toFullType = toFullType
M.magKey = magKey
M.normalizeClipFull = normalizeClipFull

return M
