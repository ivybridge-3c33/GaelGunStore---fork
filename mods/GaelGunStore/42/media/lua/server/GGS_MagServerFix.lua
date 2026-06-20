-- Server-side: align magazineType and modData when installing/removing clips.

if not isServer() then
    return
end

require "GGS_MagMapping"

local function patchClassMetaMethod(class, methodName, createPatch)
    if not __classmetatables or not class then
        return
    end
    local metatable = __classmetatables[class]
    if not metatable or not metatable.__index then
        return
    end
    local originalMethod = metatable.__index[methodName]
    if not originalMethod then
        return
    end
    metatable.__index[methodName] = createPatch(originalMethod)
end

local MAG_DEBUG = false

local function normalizeClipFull(fullType)
    if _G.GGS_MagMapping then
        return _G.GGS_MagMapping.normalizeClipFull(fullType)
    end
    return fullType
end

local function clipPartToMagType(clipType)
    if _G.GGS_MagMapping then
        return _G.GGS_MagMapping.clipPartToMagType(clipType)
    end
    return nil
end

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "setWeaponPart", function(orig)
    return function(item, partType, weaponpart, isReal, setOnly)
        if not instanceof(item, "HandWeapon") then
            return
        end
        if weaponpart == nil then
            pcall(item.clearWeaponPart, item, partType)
        else
            -- Siempre llamar al original para que realmente instale la parte.
            orig(item, partType, weaponpart)
        end

        local fullType = weaponpart and normalizeClipFull(weaponpart:getFullType()) or nil
        local md = item:getModData()
        md.weaponpart = md.weaponpart or {}

        if partType == "Clip" and fullType then
            md.lastClipType = fullType
            md.lastClipContains = true
            if MAG_DEBUG then
                print(string.format("[GGS MagDebug server] setWeaponPart type=%s fullType=%s", tostring(partType), tostring(fullType)))
            end
        end

        md.weaponpart[partType] = fullType
        if partType == "Clip" and weaponpart and item.setMagazineType then
            local magType = clipPartToMagType(fullType)
            if magType then
                item:setMagazineType(magType)
                md.MagazineTypeNow = magType
            end
        end

        if item.transmitModData then
            item:transmitModData()
        end
    end
end)

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "setContainsClip", function(orig)
    return function(item, bool)
        orig(item, bool)
        local md = item:getModData()
        md.weaponpart = md.weaponpart or {}
        if bool then
            local pendingMag = md.__ggsPendingInsertMag
            local currentMag = pendingMag or (item.getMagazineType and item:getMagazineType()) or md.MagazineTypeNow
            -- MP fix: prefer the magazine currently being inserted over stale modData.
            local fullClip = nil
            if _G.GGS_MagMapping then
                fullClip = _G.GGS_MagMapping.magTypeToClipPart(currentMag)
            end
            if not fullClip then
                fullClip = normalizeClipFull(md.weaponpart["Clip"] or md.lastClipType)
            end
            if fullClip then
                md.weaponpart["Clip"] = fullClip
                md.lastClipType = fullClip
                md.lastClipContains = true
                local magType = clipPartToMagType(fullClip) or currentMag
                if magType and item.setMagazineType then
                    item:setMagazineType(magType)
                    md.MagazineTypeNow = magType
                end
                if MAG_DEBUG then
                    print(string.format("[GGS MagDebug server] setContainsClip=true type=%s", tostring(fullClip)))
                end
            elseif MAG_DEBUG then
                print("[GGS MagDebug server] setContainsClip=true but no clip type found; keeping lastClipType")
            end
        else
            -- Clip retirado: marcar estado pero conservar lastClipType por si se vuelve a instalar igual.
            md.weaponpart["Clip"] = nil
            md.lastClipContains = false
            if MAG_DEBUG then
                print("[GGS MagDebug server] setContainsClip=false cleared clip state (lastClipType preserved)")
            end
        end
        md.__ggsPendingInsertMag = nil
        if item.transmitModData then
            item:transmitModData()
        end
    end
end)

