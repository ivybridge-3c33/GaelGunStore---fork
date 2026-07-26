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
    -- Boolean render-gate for AWCWF_RenderPart.lua:221 ONLY.
    -- Do NOT call AWCWF_AdditionalParts.GetPlayerModelList(player) here: in this B42
    -- build it routes into the framework's spfunction -> getJavaFieldNum, which calls
    -- the debug-only Java API getNumClassFields(). Outside of -debug that throws
    -- "Not in debug" EVERY frame, which aborts Apply_Effect so NO attachment or
    -- magazine models render at all (this is the "แต่ง/แม็ก ไม่ขึ้น model" bug).
    -- The return value is used only as a truthy gate, so the HandWeapon itself
    -- (the thing being rendered) is all that is needed.
    return weapon
end
AWCWF_AdditionalParts.GetWeaponModelInstance = ggsGetWeaponModelInstance
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(function() AWCWF_AdditionalParts.GetWeaponModelInstance = ggsGetWeaponModelInstance end)
end

-- On for one more round. AWCWF_RenderPart reads getModData().weaponpart, so the model
-- showing a part proves the mirror got written; inspect and the suppressor read the
-- real vanilla part and see nothing. The suspect is the "skip non-WeaponPart" branch
-- in setWeaponPart below, which skips orig() but still writes the mirror -- exactly
-- that split. Its debugAttach line will say so. Costs ~5000 lines a session because
-- something clears Hide_Beam every frame; turn off once confirmed.
local DEBUG_ATTACH = false
local function debugAttach(fmt, ...)
    if DEBUG_ATTACH then
        print(string.format(fmt, ...))
    end
end

-- Every bail-out here used to be silent, so a patch that never installed looked
-- exactly like a patch that installed and did nothing -- which cost a whole
-- debugging round. These prints fire once at load, not per call, so they are cheap
-- to keep. If a "FAILED" line shows up in console.txt, the modData mirror below is
-- not wired in at all and getWeaponPart is plain vanilla.
local function patchClassMetaMethod(class, methodName, createPatch)
    if not __classmetatables then
        print("[GGS Patch] FAILED " .. tostring(methodName) .. ": __classmetatables is nil")
        return
    end
    local metatable = __classmetatables[class]
    if not metatable or not metatable.__index then
        print("[GGS Patch] FAILED " .. tostring(methodName) .. ": no metatable/__index for class")
        return
    end
    local originalMethod = metatable.__index[methodName]
    if not originalMethod then
        print("[GGS Patch] FAILED " .. tostring(methodName) .. ": method not found on class")
        return
    end
    metatable.__index[methodName] = createPatch(originalMethod)
    print("[GGS Patch] installed " .. tostring(methodName))
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
    -- Attaching something clears the tombstone left by a removal (see
    -- ISRemoveWeaponUpgrade_FIX.lua), so the slot is allowed to sync again.
    if fullType and md.ggsRemovedSlots then
        md.ggsRemovedSlots[partType] = nil
    end
    -- Who puts a part back? After a removal the mirror was seen holding Canon again
    -- before the next sync even arrived ("partList received (6), mirror already current"),
    -- so the re-add happens on this client, through here. Magazine traffic is constant and
    -- uninteresting, so only real attachment slots are reported.
    if partType ~= "Clip" and partType ~= "ClipUI" then
        print("[GGS MirrorDBG] " .. tostring(partType) .. " -> " .. tostring(fullType) ..
                  " on " .. tostring(item.getFullType and item:getFullType() or "?"))
    end
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
        -- Keep this opt-IN. Making the mirror the default (isReal ~= true) was tried
        -- and had to be reverted: it hands callers instanceItem(cached), a fresh
        -- instance that only exists in Lua. The workbench slot buttons take their
        -- slotItem straight from getWeaponPart, so with a phantom in there
        -- attachmentButton:onMouseDoubleClick stopped early-returning and queued
        -- ISRemoveWeaponUpgrade for a part that was never really attached. The Java
        -- side cannot see this Lua mirror, so the action's part resolved to null and
        -- AWCWF's ISRemoveWeaponUpgrade_FIX.perform died on getType of null -- which
        -- killed the whole timed-action queue, including any attach queued behind it.
        -- Diagnostics also showed the premise was wrong: on MP this mirror only ever
        -- held Clip, never a suppressor, so there was nothing for a fallback to find.
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

-- Pure logger, no behaviour change: calls through to the original and returns whatever
-- it returns. Only setWeaponPart/getWeaponPart/RemoveAllRealPart were ever hooked, so
-- an attach that goes through attachWeaponPart -- which is what vanilla's
-- ISUpgradeWeapon timed action uses -- left no trace at all AND never reached
-- syncWeaponPartModData, meaning no mirror entry either. That would explain a session
-- log showing only Clip while the player had just attached something.
local function ggsLogPassthrough(label)
    return function(orig)
        return function(item, ...)
            if DEBUG_ATTACH then
                local described = {}
                for i = 1, select("#", ...) do
                    local a = select(i, ...)
                    local shown = type(a)
                    if a ~= nil and type(a) ~= "string" and type(a) ~= "number" then
                        local ok, ft = pcall(function() return a.getFullType and a:getFullType() end)
                        if ok and ft then
                            shown = tostring(ft)
                        end
                    end
                    described[#described + 1] = tostring(shown)
                end
                debugAttach("[GGS AttachDBG] %s item=%s args=[%s]", label,
                    tostring(item and item.getFullType and item:getFullType() or "?"),
                    table.concat(described, ", "))
            end
            return orig(item, ...)
        end
    end
end

patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "setWeaponPart", AWCWF_AdditionalParts.setWeaponPart)
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "getWeaponPart", AWCWF_AdditionalParts.getWeaponPart)
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "RemoveAllRealPart", AWCWF_AdditionalParts.RemoveAllRealPart)
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "attachWeaponPart", ggsLogPassthrough("attachWeaponPart"))
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "detachWeaponPart", ggsLogPassthrough("detachWeaponPart"))

debugAttach("[GGS AttachDBG] AWCWF_AdditionalParts simplificado cargado (modData sync, sin limpieza de partes).")
