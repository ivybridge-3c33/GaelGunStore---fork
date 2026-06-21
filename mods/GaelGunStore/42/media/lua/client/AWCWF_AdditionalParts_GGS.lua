AWCWF_AdditionalParts = AWCWF_AdditionalParts or {}  -- additive: keep framework funcs (GetWeaponModelInstance etc.)

-- B42 render-gate fix.
-- AWCWF_RenderPart.lua:221 bails (no parts drawn -> magazine/attachments never
-- render) unless AWCWF_AdditionalParts.GetWeaponModelInstance() returns truthy.
-- The framework's version matches the held weapon by comparing
-- spfunction(instance,"m_modelScript"):getMeshName() against the weapon model's
-- mesh name. In this B42 build spfunction(...,"m_modelScript") returns nil for
-- every player sub-model (verified: all instance meshes = nil), so the match
-- never succeeds and it always returns nil. It is used ONLY as a boolean gate
-- (RenderPart.lua:221), so return truthy whenever the player actually has model
-- instances (i.e. the weapon is being rendered).
local function ggsGetWeaponModelInstance(player, weapon)
    if not player or not weapon then return nil end
    if not instanceof(weapon, "HandWeapon") then return nil end
    local list = AWCWF_AdditionalParts.GetPlayerModelList and AWCWF_AdditionalParts.GetPlayerModelList(player)
    if list and list:size() > 0 then
        return weapon
    end
    return nil
end
AWCWF_AdditionalParts.GetWeaponModelInstance = ggsGetWeaponModelInstance
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(function() AWCWF_AdditionalParts.GetWeaponModelInstance = ggsGetWeaponModelInstance end)
end

local DEBUG_ATTACH = false
local function debugAttach(fmt, ...)
    if DEBUG_ATTACH then
        print(string.format(fmt, ...))
    end
end

local function patchClassMetaMethod(class, methodName, createPatch)
    if not __classmetatables then
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

AWCWF_AdditionalParts.partlist = {"Scope", "Mount", "Canon", "Stock", "Handguard", "Hanguard", "Grip", "Laser", "Light",
                                  "Stool", "R_Scope", "L_Scope", "Skin", "Sling", "RecoilPad", "Misc", "Clip", "ClipUI",
                                  "Hide_Beam", "Barrel", "Barrel_Shroud","AMMO"}

local function normalizeClipFull(fullType)
    if not fullType then return fullType end
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

local function syncWeaponPartModData(item, partType, fullType)
    if not item or not partType then
        return
    end
        if partType == "Clip" or partType == "ClipUI" then
            fullType = normalizeClipFull(fullType)
        end
    local md = item:getModData()
    md.weaponpart = md.weaponpart or {}
    if md.weaponpart[partType] == fullType then
        return
    end
    md.weaponpart[partType] = fullType
    if item.transmitModData then
        item:transmitModData()
    end
end

AWCWF_AdditionalParts.setWeaponPart = function(orig)
    AWCWF_AdditionalParts._origSetWeaponPart = orig
    return function(item, partType, weaponpart, isReal, setOnly)
        if not instanceof(item, "HandWeapon") then
            return
        end
        local md = item:getModData()
        md.weaponpart = md.weaponpart or {}
        local cached = md.weaponpart[partType]
        local currentReal = AWCWF_AdditionalParts._origGetWeaponPart and AWCWF_AdditionalParts._origGetWeaponPart(item,
            partType) or nil
        local fullType = weaponpart and weaponpart:getFullType() or nil
        debugAttach("[GGS AttachDBG] setWeaponPart hook item=%s type=%s part=%s isReal=%s setOnly=%s",
            tostring(item:getFullType()), tostring(partType), tostring(fullType), tostring(isReal), tostring(setOnly))
        if weaponpart and currentReal and currentReal.getFullType and currentReal:getFullType() == fullType and isReal ~= false then
            syncWeaponPartModData(item, partType, fullType)
            return
        end
        if weaponpart == nil then
            if not currentReal and not cached then
                syncWeaponPartModData(item, partType, nil)
                return
            end
            orig(item, partType, nil)
            if AWCWF_AdditionalParts._origGetWeaponPart then
                local still = AWCWF_AdditionalParts._origGetWeaponPart(item, partType)
                if still then
                    AWCWF_AdditionalParts._origSetWeaponPart(item, partType, nil)
                end
                if AWCWF_AdditionalParts._origGetWeaponPart(item, partType) then
                    local partsMap = item.getAllWeaponParts and item:getAllWeaponParts()
                    if partsMap and partsMap.remove then
                        partsMap:remove(partType)
                    end
                end
            end
            syncWeaponPartModData(item, partType, nil)
            return
        end
        if weaponpart and not instanceof(weaponpart, "WeaponPart") then
            if partType ~= "Clip" then
                debugAttach("[GGS AttachDBG] skip non-WeaponPart for type=%s (%s)", tostring(partType),
                    tostring(fullType))
            end
        else
            if partType == "Clip" or partType == "ClipUI" then
                fullType = normalizeClipFull(fullType)
                if weaponpart and weaponpart.getFullType and weaponpart:getFullType() ~= fullType then
                    local resolved = instanceItem(fullType)
                    if resolved and instanceof(resolved, "WeaponPart") then
                        weaponpart = resolved
                    end
                end
                orig(item, partType, weaponpart)
            else
                orig(item, partType, weaponpart)
            end
        end
        syncWeaponPartModData(item, partType, fullType)
    end
end

AWCWF_AdditionalParts.getWeaponPart = function(orig)
    AWCWF_AdditionalParts._origGetWeaponPart = orig
    return function(item, partType, isReal)
        if not instanceof(item, "HandWeapon") then
            return orig(item, partType)
        end
        local real = orig(item, partType)
        if real then
            return real
        end
        if isReal == false then
            local md = item:getModData()
            md.weaponpart = md.weaponpart or {}
            local cached = md.weaponpart[partType]
            if cached then
                return instanceItem(cached)
            end
        end
        return real
    end
end

AWCWF_AdditionalParts.RemoveAllRealPart = function(orig)
    return function(item)
        return
    end
end

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "setWeaponPart", AWCWF_AdditionalParts.setWeaponPart)
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "getWeaponPart", AWCWF_AdditionalParts.getWeaponPart)
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "RemoveAllRealPart", AWCWF_AdditionalParts.RemoveAllRealPart)

debugAttach("[GGS AttachDBG] AWCWF_AdditionalParts simplificado cargado (modData sync, sin limpieza de partes).")
