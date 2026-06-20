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

local function resolveClipPartFromMagazineType(magType)
    local map = _G.AWCWF_MagazineTypeToPart
    if not (map and magType) then
        return nil
    end

    local key = magKey(magType)
    local clipType = map[magType] or (key and map[key]) or nil
    if not clipType then
        return nil
    end
    return normalizeClipFull(clipType)
end

local function supportsClipVisual(weapon, loaded)
    if not weapon then
        return false
    end
    if loaded then
        return true
    end
    if weapon.getMagazineType and weapon:getMagazineType() ~= nil then
        return true
    end
    local byWeapon = _G.AWCWF_WeaponMagazineType
    if byWeapon and weapon.getType then
        return byWeapon[weapon:getType()] ~= nil
    end
    return false
end

local function refreshWeaponModel(playerObj, weapon)
    if syncHandWeaponFields then
        pcall(syncHandWeaponFields, playerObj, weapon)
    end
    if playerObj and playerObj.resetEquippedHandsModels then
        playerObj:resetEquippedHandsModels()
    end
    if playerObj and playerObj.resetModelNextFrame then
        playerObj:resetModelNextFrame()
    end
end

local function syncClipTypeToServer(weapon, md, clipFull)
    if not (isClient() and sendClientCommand and weapon and md and clipFull) then
        return
    end
    local gunId = weapon.getID and weapon:getID() or nil
    if md.lastSentClipType == clipFull and md.lastSentClipGunId == gunId then
        return
    end
    md.lastSentClipType = clipFull
    md.lastSentClipGunId = gunId
    sendClientCommand("GGS", "SetClipType", {
        gunId = gunId,
        clipType = clipFull
    })
end

local function showMagazine(playerObj)
    local weapon = playerObj and playerObj:getPrimaryHandItem() or nil
    if not (weapon and weapon.IsWeapon and weapon:IsWeapon() and weapon.isRanged and weapon:isRanged()) then
        return
    end

    local loaded = weapon.isContainsClip and weapon:isContainsClip() or false
    if not supportsClipVisual(weapon, loaded) then
        return
    end

    local md = weapon:getModData()
    md.weaponpart = md.weaponpart or {}

    local currentPart = weapon.getWeaponPart and weapon:getWeaponPart("Clip") or nil
    local currentFull = currentPart and currentPart.getFullType and normalizeClipFull(currentPart:getFullType()) or nil
    local magType = weapon.getMagazineType and weapon:getMagazineType() or nil
    local expectedFull = resolveClipPartFromMagazineType(magType)
    local changed = false

    if loaded then
        if not expectedFull then
            expectedFull = currentFull or md.lastClipType or md.weaponpart["Clip"]
            expectedFull = normalizeClipFull(expectedFull)
        end

        if expectedFull and currentFull ~= expectedFull and weapon.setWeaponPart then
            local clipItem = instanceItem and instanceItem(expectedFull) or nil
            if clipItem and instanceof(clipItem, "WeaponPart") then
                local ok = pcall(weapon.setWeaponPart, weapon, "Clip", clipItem)
                if ok then
                    currentFull = expectedFull
                    changed = true
                end
            end
        end

        if expectedFull then
            md.weaponpart["Clip"] = expectedFull
            md.lastClipType = expectedFull
            md._ggs_lastAppliedClip = expectedFull
            syncClipTypeToServer(weapon, md, expectedFull)
        end
    else
        if currentFull and weapon.clearWeaponPart then
            local ok = pcall(weapon.clearWeaponPart, weapon, "Clip")
            if ok then
                changed = true
            end
        end
        if currentFull then
            md.lastClipType = currentFull
            md.weaponpart["Clip"] = currentFull
        end
        md._ggs_lastAppliedClip = nil
    end

    if changed then
        refreshWeaponModel(playerObj, weapon)
    end
end

Events.OnPlayerUpdate.Add(showMagazine)
