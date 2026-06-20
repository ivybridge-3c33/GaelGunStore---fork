local DEFAULT_VOLUME_MOD = 0.35
local DEFAULT_RADIUS_MOD = 0.25

local function safeLower(value)
    if not value then
        return ""
    end
    return tostring(value):lower()
end

local function hasPartTag(part, tag)
    if not part or not tag or not part.hasTag then
        return false
    end
    local ok, result = pcall(part.hasTag, part, tag)
    return ok and result == true
end

local function isSuppressorPart(part)
    if not part then
        return false
    end

    local partType = safeLower(part.getPartType and part:getPartType() or "")
    if partType ~= "" and partType ~= "canon" then
        return false
    end

    local nameBlob = safeLower(part.getType and part:getType() or "") .. " " ..
        safeLower(part.getFullType and part:getFullType() or "") .. " " ..
        safeLower(part.getDisplayName and part:getDisplayName() or "")

    if nameBlob:find("choke", 1, true) then
        return false
    end

    if nameBlob:find("silencer", 1, true) or nameBlob:find("suppressor", 1, true) then
        return true
    end

    if nameBlob:find("ductaped", 1, true) or nameBlob:find("oilfilter", 1, true) then
        return true
    end

    return hasPartTag(part, "silencers") or hasPartTag(part, "silencer") or hasPartTag(part, "suppressor")
end

local function getDefaultSilencedSound(weapon, part, baseSwingSound)
    local partName = safeLower(part and (part.getType and part:getType() or part.getFullType and part:getFullType() or "") or "")
    if partName:find("oilfilter", 1, true) then
        return "OilFilter_Silencer_shoot"
    end
    if partName:find("waterbottle", 1, true) or partName:find("ductaped", 1, true) then
        return "WaterBottle_ductaped_Shoot"
    end

    local ammoType = safeLower(weapon and weapon.getAmmoType and weapon:getAmmoType() or "")
    local swing = safeLower(baseSwingSound)

    if ammoType:find("12g", 1, true) or ammoType:find("shot", 1, true) or swing:find("shotgun", 1, true) then
        return "Shotgun_s"
    end

    if swing:find("revolver", 1, true) then
        return "Pistol2_s"
    end

    if ammoType:find("9mm", 1, true)
        or ammoType:find("45", 1, true)
        or ammoType:find("44", 1, true)
        or ammoType:find("38", 1, true)
        or ammoType:find("357", 1, true)
        or ammoType:find("22", 1, true)
        or ammoType:find("380", 1, true)
        or ammoType:find("57", 1, true)
        or ammoType:find("46", 1, true)
        or ammoType:find("50ae", 1, true) then
        return "Pistol_s"
    end

    return "Rifle_s"
end

local function resolveConfiguredProfile(slotConfig, part)
    if type(slotConfig) ~= "table" or not part then
        return nil
    end

    local partType = part.getType and part:getType() or nil
    if partType and type(slotConfig[partType]) == "table" then
        return slotConfig[partType]
    end

    local fullType = part.getFullType and part:getFullType() or nil
    if fullType and type(slotConfig[fullType]) == "table" then
        return slotConfig[fullType]
    end

    return nil
end

local function applyProfile(weapon, baseVolume, baseRadius, baseSwingSound, profile, defaultSound)
    local volumeModifier = tonumber(profile.SoundVolumeModifier) or DEFAULT_VOLUME_MOD
    local radiusModifier = tonumber(profile.SoundRadiusModifier) or DEFAULT_RADIUS_MOD
    local silencedSound = profile.SilenceSound
    if not silencedSound or silencedSound == "" then
        silencedSound = defaultSound
    end

    if volumeModifier < 0 then
        volumeModifier = 0
    end
    if radiusModifier < 0 then
        radiusModifier = 0
    end

    local newVolume = math.floor(baseVolume * volumeModifier + 0.5)
    local newRadius = math.floor(baseRadius * radiusModifier + 0.5)
    if newVolume < 0 then
        newVolume = 0
    end
    if newRadius < 0 then
        newRadius = 0
    end

    weapon:setSoundVolume(newVolume)
    weapon:setSoundRadius(newRadius)
    weapon:setSwingSound(silencedSound or baseSwingSound)
end

local function SoundChange(playerObj, weapon)
    if not weapon then
        if not playerObj then
            playerObj = getPlayer()
        end
        if not playerObj then
            return
        end
        weapon = playerObj:getPrimaryHandItem()
        if not weapon then
            return
        end
    end

    if not weapon:IsWeapon() or not weapon:isRanged() then
        return
    end

    local scriptItem = weapon:getScriptItem()
    if not scriptItem then
        return
    end

    local baseVolume = tonumber(scriptItem:getSoundVolume()) or tonumber(weapon.getSoundVolume and weapon:getSoundVolume() or 0) or 0
    local baseRadius = tonumber(scriptItem:getSoundRadius()) or tonumber(weapon.getSoundRadius and weapon:getSoundRadius() or 0) or 0
    local baseSwingSound = scriptItem:getSwingSound()

    weapon:setSoundVolume(baseVolume)
    weapon:setSoundRadius(baseRadius)
    weapon:setSwingSound(baseSwingSound)

    local suppressorProfile = nil
    local suppressorDefaultSound = nil

    for slotName, slotConfig in pairs(AWCWF_SilencerSet or {}) do
        local part = weapon:getWeaponPart(slotName)
        if part then
            local configured = resolveConfiguredProfile(slotConfig, part)
            if configured then
                suppressorProfile = configured
                suppressorDefaultSound = getDefaultSilencedSound(weapon, part, baseSwingSound)
                break
            end

            if isSuppressorPart(part) then
                suppressorProfile = {
                    SoundVolumeModifier = DEFAULT_VOLUME_MOD,
                    SoundRadiusModifier = DEFAULT_RADIUS_MOD
                }
                suppressorDefaultSound = getDefaultSilencedSound(weapon, part, baseSwingSound)
                break
            end
        end
    end

    if not suppressorProfile then
        local allParts = weapon.getAllWeaponParts and weapon:getAllWeaponParts() or nil
        if allParts then
            for i = 0, allParts:size() - 1 do
                local part = allParts:get(i)
                if isSuppressorPart(part) then
                    suppressorProfile = {
                        SoundVolumeModifier = DEFAULT_VOLUME_MOD,
                        SoundRadiusModifier = DEFAULT_RADIUS_MOD
                    }
                    suppressorDefaultSound = getDefaultSilencedSound(weapon, part, baseSwingSound)
                    break
                end
            end
        end
    end

    if suppressorProfile then
        applyProfile(weapon, baseVolume, baseRadius, baseSwingSound, suppressorProfile, suppressorDefaultSound)
    end
end

local function onPlayerUpdate(playerObj)
    if not playerObj then
        return
    end

    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then
        return
    end

    SoundChange(playerObj, weapon)
end

if Events and Events.OnEquipPrimary and Events.OnEquipPrimary.Add then
    Events.OnEquipPrimary.Add(SoundChange)
end
if Events and Events.OnEquipSecondary and Events.OnEquipSecondary.Add then
    Events.OnEquipSecondary.Add(SoundChange)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(SoundChange)
end
if Events and Events.OnPlayerUpdate and Events.OnPlayerUpdate.Add then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end
