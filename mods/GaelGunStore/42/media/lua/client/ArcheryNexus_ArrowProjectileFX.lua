if isServer() then
    return
end

local DEBUG_ARROW_FX = false
local MODULE_NAME = "GGS_ArcheryFX"
local COMMAND_ARROW_IMPACT_FX = "ArrowImpactFX"
local InventoryItemFactory = InventoryItemFactory
local BOW_SWING_DEBOUNCE_MS = 120
local BOW_IMPACT_DAMAGE_RADIUS = 0.90
local BOW_DAMAGE_RESTORE_GRACE_MS = 10
local BOW_IMPACT_KNOCKBACK_XY = 0.01
local BOW_IMPACT_KNOCKBACK_Z = 0.01
local BOW_GROUND_IMPACT_EPSILON = 0.04
local BOW_WALL_SEGMENT_STEP = 0.20
local BOW_ZOMBIE_SEGMENT_STEP = 0.30
local BOW_BALLISTIC_FIXED_STEP_SEC = 1.0 / 60.0
local BOW_BALLISTIC_MAX_DELTA_SEC = 0.20
local BOW_BALLISTIC_MIN_GRAVITY = 0.35
local BOW_BALLISTIC_MAX_LIFETIME_SEC = 7.5
local BOW_BALLISTIC_MAX_RANGE_MULT = 1.35
local ARCHERY_PROJECTILE_VISUAL_Z_BIAS = -0.08
local ARCHERY_AIM_MODE_IMPACT_SQUARE = "impact_square"
local ARCHERY_CURSOR_SCREEN_BIAS_Y = 16
local ARCHERY_AIM_WORLD_BIAS_X = 1.50
local ARCHERY_AIM_WORLD_BIAS_Y = 1.50

local ENABLE_ARCHERY_IMPACT_POINT = false
local ARCHERY_IMPACT_POINT_UPDATE_MS = 55
local ARCHERY_CURSOR_ZOMBIE_RADIUS = 0.75
local ARCHERY_IMPACT_POINT_GLYPH = "+"

local ARROW_FX_BY_WEAPON = {
    ["Base.Primitive_Bow"] = {
        defaultAmmoType = "Base.arrow_wood",
        defaultFlightVisualItem = "Base.arrow_wood_fly",
        defaultFloorItemType = "Base.arrow_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.22,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = BOW_IMPACT_DAMAGE_RADIUS,
        damageScale = 1.0,
        dropStartRange = 14.0,
        dropPerTile = 0.065,
        groundImpactEpsilon = BOW_GROUND_IMPACT_EPSILON,
        muzzleAttachment = "BowMuzzle",
        fallbackMuzzleModelScript = "Primitive_Bow"
    },
    ["Base.Crossbow"] = {
        defaultAmmoType = "Base.bolt_wood",
        defaultFlightVisualItem = "Base.bolt_wood_fly",
        defaultFloorItemType = "Base.bolt_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.18,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = BOW_IMPACT_DAMAGE_RADIUS,
        damageScale = 1.0,
        dropStartRange = 18.0,
        dropPerTile = 0.05,
        groundImpactEpsilon = BOW_GROUND_IMPACT_EPSILON,
        muzzleAttachment = "muzzle",
        fallbackMuzzleModelScript = "Crossbow"
    }
}

local BOW_STAT_FALLBACKS = {
    ["Base.Primitive_Bow"] = {
        tensionPower = 5.0
    },
    ["Base.Crossbow"] = {
        tensionPower = 8.0
    }
}

local ARROW_STAT_FALLBACKS = {
    ["Base.WoodShaft_Arrow"] = {
        sharpness = 0.90,
        impactImpulse = 0.01,
        flightVisualItemType = "Base.Arrow_fly",
        floorItemType = "Base.WoodShaft_Arrow",
        hitReaction = "arrow_light",
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightRenderZBias = ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    },
    ["Base.arrow_wood"] = {
        sharpness = 0.90,
        impactImpulse = 0.01,
        flightVisualItemType = "Base.arrow_wood_fly",
        floorItemType = "Base.arrow_wood",
        hitReaction = "arrow_light",
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightRenderZBias = ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    },
    ["Base.arrow_metal"] = {
        sharpness = 1.10,
        impactImpulse = 0.01,
        flightVisualItemType = "Base.arrow_metal_fly",
        floorItemType = "Base.arrow_metal",
        hitReaction = "arrow_light",
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightRenderZBias = ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    },
    ["Base.arrow_carbon"] = {
        sharpness = 1.25,
        impactImpulse = 0.01,
        flightVisualItemType = "Base.arrow_carbon_fly",
        floorItemType = "Base.arrow_carbon",
        hitReaction = "arrow_light",
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightRenderZBias = ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    },
    ["Base.bolt_wood"] = {
        sharpness = 1.00,
        impactImpulse = 0.01,
        flightVisualItemType = "Base.bolt_wood_fly",
        floorItemType = "Base.bolt_wood",
        hitReaction = "arrow_light",
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightRenderZBias = ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    },
    ["Base.bolt_metal"] = {
        sharpness = 1.20,
        impactImpulse = 0.01,
        flightVisualItemType = "Base.bolt_metal_fly",
        floorItemType = "Base.bolt_metal",
        hitReaction = "arrow_light",
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightRenderZBias = ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    },
    ["Base.bolt_carbon"] = {
        sharpness = 1.35,
        impactImpulse = 0.01,
        flightVisualItemType = "Base.bolt_carbon_fly",
        floorItemType = "Base.bolt_carbon",
        hitReaction = "arrow_light",
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightRenderZBias = ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    }
}

local activeArrowFx = {}
local suppressedBowDamage = {}
local arrowStatCache = {}
local bowMuzzleOffsetCache = {}
local handlersRegistered = false
local lastLocalBowSwingMs = 0
local archeryImpactPointCache = {
    nextRefreshMs = 0,
    worldX = nil,
    worldY = nil,
    worldZ = nil,
    screenX = nil,
    screenY = nil,
    visible = false
}

local function logArrowFx(fmt, ...)
    if not DEBUG_ARROW_FX then
        return
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if ok then
        print("[GGS ARROWFX] " .. msg)
    else
        print("[GGS ARROWFX] " .. tostring(fmt))
    end
end

local function describeArrowZombieDebug(target)
    if not target then
        return "nil"
    end

    local parts = { tostring(target) }
    if target.getX and target.getY and target.getZ then
        local okX, x = pcall(target.getX, target)
        local okY, y = pcall(target.getY, target)
        local okZ, z = pcall(target.getZ, target)
        if okX and okY and okZ then
            table.insert(parts, string.format("xyz=%.2f,%.2f,%.2f", tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0))
        end
    end
    if target.getOnlineID then
        local ok, value = pcall(target.getOnlineID, target)
        if ok and value ~= nil then
            table.insert(parts, "onlineId=" .. tostring(value))
        end
    end
    if target.getObjectID then
        local ok, value = pcall(target.getObjectID, target)
        if ok and value ~= nil then
            table.insert(parts, "objectId=" .. tostring(value))
        end
    end
    if target.getID then
        local ok, value = pcall(target.getID, target)
        if ok and value ~= nil then
            table.insert(parts, "id=" .. tostring(value))
        end
    end
    if target.getPersistentOutfitID then
        local ok, value = pcall(target.getPersistentOutfitID, target)
        if ok and value ~= nil then
            table.insert(parts, "outfit=" .. tostring(value))
        end
    end
    return table.concat(parts, " ")
end

local function describeArrowSquareDebug(square)
    if not square then
        return "nil"
    end
    local sx = square.getX and square:getX() or "?"
    local sy = square.getY and square:getY() or "?"
    local sz = square.getZ and square:getZ() or "?"
    return string.format("%s@%s,%s,%s", tostring(square), tostring(sx), tostring(sy), tostring(sz))
end

local function estimateArrowImpactZone(target, impactX, impactY, impactZ)
    if not target then
        return "world", nil, nil
    end

    local baseZ = tonumber(target.getZ and target:getZ()) or tonumber(impactZ) or 0.0
    local hitZ = tonumber(impactZ) or baseZ
    local relZ = hitZ - baseZ
    local targetX = tonumber(target.getX and target:getX()) or tonumber(impactX) or 0.0
    local targetY = tonumber(target.getY and target:getY()) or tonumber(impactY) or 0.0
    local impactPosX = tonumber(impactX) or targetX
    local impactPosY = tonumber(impactY) or targetY
    local dx = impactPosX - targetX
    local dy = impactPosY - targetY
    local lateral = math.sqrt((dx * dx) + (dy * dy))

    local zone = "legs"
    if relZ >= 1.05 then
        zone = "head"
    elseif relZ >= 0.78 then
        zone = "upper_torso"
    elseif relZ >= 0.42 then
        zone = "lower_torso"
    end

    return zone, relZ, lateral
end

local function getArrowZombieIdValue(target, methodName)
    if not (target and methodName and target[methodName]) then
        return nil
    end
    local ok, value = pcall(target[methodName], target)
    if ok and value ~= nil then
        return tostring(value)
    end
    return nil
end

local function zombieMatchesArrowTargetArgs(target, args)
    if not (target and args) then
        return false
    end

    local wantedOnline = args.targetOnlineId and tostring(args.targetOnlineId) or nil
    local wantedObject = args.targetObjectId and tostring(args.targetObjectId) or nil
    local wantedId = args.targetId and tostring(args.targetId) or nil
    local wantedOutfit = args.targetPersistentOutfitId and tostring(args.targetPersistentOutfitId) or nil

    if wantedOnline and wantedOnline ~= "" and wantedOnline == getArrowZombieIdValue(target, "getOnlineID") then
        return true
    end
    if wantedObject and wantedObject ~= "" and wantedObject == getArrowZombieIdValue(target, "getObjectID") then
        return true
    end
    if wantedId and wantedId ~= "" and wantedId == getArrowZombieIdValue(target, "getID") then
        return true
    end
    if wantedOutfit and wantedOutfit ~= "" and wantedOutfit == getArrowZombieIdValue(target, "getPersistentOutfitID") then
        return true
    end
    return false
end

local function findZombieForArrowKillFx(args)
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end

    local impactX = tonumber(args and (args.impactX or args.targetX)) or 0
    local impactY = tonumber(args and (args.impactY or args.targetY)) or 0
    local impactZ = math.floor(tonumber(args and (args.impactZ or args.targetZ)) or 0)
    local radius = math.max(2.5, tonumber(args and args.impactRadius) or 4.0)
    local minX = math.floor(impactX - radius)
    local maxX = math.ceil(impactX + radius)
    local minY = math.floor(impactY - radius)
    local maxY = math.ceil(impactY + radius)
    local best = nil
    local bestDist = nil

    for scanZ = impactZ - 1, impactZ + 1 do
        for sx = minX, maxX do
            for sy = minY, maxY do
                local square = cell:getGridSquare(sx, sy, scanZ)
                if square and square.getMovingObjects then
                    local movingObjects = square:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if moving and instanceof and instanceof(moving, "IsoZombie") then
                                if zombieMatchesArrowTargetArgs(moving, args) then
                                    return moving
                                end
                                local dx = impactX - (tonumber(moving:getX()) or 0)
                                local dy = impactY - (tonumber(moving:getY()) or 0)
                                local dist = math.sqrt((dx * dx) + (dy * dy))
                                if dist <= radius and (not bestDist or dist < bestDist) then
                                    best = moving
                                    bestDist = dist
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if cell.getZombieList then
        local okList, zombieList = pcall(cell.getZombieList, cell)
        if okList and zombieList then
            for i = 0, zombieList:size() - 1 do
                local zombie = zombieList:get(i)
                if zombie and zombieMatchesArrowTargetArgs(zombie, args) then
                    return zombie
                end
            end
        end
    end

    return best
end

local function isArrowZombieReallyDead(target)
    if not target then
        return false
    end
    if target.isDead then
        local ok, dead = pcall(target.isDead, target)
        if ok and dead then
            return true
        end
    end
    if target.isOnDeathDone then
        local ok, done = pcall(target.isOnDeathDone, target)
        if ok and done then
            return true
        end
    end
    return false
end

local function isArrowZombieTargetable(target)
    if not target then
        return false
    end
    if isArrowZombieReallyDead(target) then
        return false
    end
    if target.getHealth then
        local ok, health = pcall(target.getHealth, target)
        if ok and tonumber(health) and tonumber(health) <= 0.0 then
            return false
        end
    end
    return true
end

local function forceLocalArrowZombieDeath(target, impactX, impactY, impactZ)
    if not (target and instanceof and instanceof(target, "IsoZombie")) then
        return false, "not_zombie"
    end

    if target.setHealth then
        pcall(target.setHealth, target, 0.0)
    end
    if target.setReanimate then
        pcall(target.setReanimate, target, false)
    end
    if target.setFakeDead then
        pcall(target.setFakeDead, target, false)
    end
    if target.setForceFakeDead then
        pcall(target.setForceFakeDead, target, false)
    end

    local playerObj = getPlayer and getPlayer() or nil
    if target.Kill then
        pcall(target.Kill, target, playerObj, true)
        if isArrowZombieReallyDead(target) then
            return true, "Kill(player,true)"
        end

        pcall(target.Kill, target, playerObj)
        if isArrowZombieReallyDead(target) then
            return true, "Kill(player)"
        end
    end

    if target.die then
        pcall(target.die, target)
        if isArrowZombieReallyDead(target) then
            return true, "die()"
        end
    end

    if target.DoDeath then
        pcall(target.DoDeath, target, nil, nil, false)
        if isArrowZombieReallyDead(target) then
            return true, "DoDeath(false)"
        end

        pcall(target.DoDeath, target, nil, nil, true)
        if isArrowZombieReallyDead(target) then
            return true, "DoDeath(true)"
        end
    end

    if target.becomeCorpse then
        pcall(target.becomeCorpse, target)
        if isArrowZombieReallyDead(target) then
            return true, "becomeCorpse()"
        end
    end

    return isArrowZombieReallyDead(target), "post_check"
end

local function handleArrowImpactFxCommand(args)
    if not args then
        return
    end

    local target = findZombieForArrowKillFx(args)
    if not target then
        logArrowFx(
            "OnServerCommand ArrowImpactFX target-miss by=%s weapon=%s ammo=%s impact=%.2f,%.2f,%.2f zone=%s ids={online=%s object=%s id=%s outfit=%s}",
            tostring(args.by),
            tostring(args.weaponType),
            tostring(args.ammoType),
            tonumber(args.impactX) or 0,
            tonumber(args.impactY) or 0,
            tonumber(args.impactZ) or 0,
            tostring(args.hitZone),
            tostring(args.targetOnlineId),
            tostring(args.targetObjectId),
            tostring(args.targetId),
            tostring(args.targetPersistentOutfitId)
        )
        return
    end

    local newHealth = tonumber(args.newHealth)
    local damage = tonumber(args.damage) or 0
    local killed = args.killed and true or false
    local reason = "health_sync_only"

    if newHealth ~= nil and target.setHealth then
        pcall(target.setHealth, target, math.max(0.0, newHealth))
    end

    if not killed then
        local reaction = tostring(args.reaction or "arrow_light")
        if reaction ~= "" then
            pcall(applyArrowImpactReaction, target, reaction)
            reason = "reaction"
        end
    else
        killed, reason = forceLocalArrowZombieDeath(target, nil, nil, nil)
    end

    logArrowFx(
        "OnServerCommand ArrowImpactFX by=%s weapon=%s ammo=%s target=%s impact=%.2f,%.2f,%.2f dmg=%s hp=%s killed=%s reason=%s zone=%s relZ=%s lateral=%s attach=%s",
        tostring(args.by),
        tostring(args.weaponType),
        tostring(args.ammoType),
        describeArrowZombieDebug(target),
        tonumber(args.impactX) or 0,
        tonumber(args.impactY) or 0,
        tonumber(args.impactZ) or 0,
        tostring(damage),
        tostring(newHealth),
        tostring(killed),
        tostring(reason),
        tostring(args.hitZone),
        tostring(args.hitZoneRelZ),
        tostring(args.hitZoneLateral),
        tostring(args.attachSlot)
    )
end

local function onServerCommand(module, command, args)
    if module ~= MODULE_NAME then
        return
    end

    -- Legacy disabled:
    -- ArrowKillFX is no longer emitted by the server. Keep the client handler focused
    -- on the current ArrowImpactFX path.
    if command == COMMAND_ARROW_IMPACT_FX then
        handleArrowImpactFxCommand(args)
    end
end

local function nowMs()
    if getTimestampMs then
        local ok, value = pcall(getTimestampMs)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return math.floor((os.clock and os.clock() or 0) * 1000)
end

local function roundToGrid(v)
    if v >= 0 then
        return math.floor(v + 0.5)
    end
    return math.ceil(v - 0.5)
end

local function floorToGrid(v)
    return math.floor(tonumber(v) or 0)
end

local function clamp01(v)
    if v < 0 then
        return 0
    end
    if v > 1 then
        return 1
    end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function distance2D(ax, ay, bx, by)
    local dx = (tonumber(ax) or 0) - (tonumber(bx) or 0)
    local dy = (tonumber(ay) or 0) - (tonumber(by) or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function normalizeFullType(fullType)
    if not fullType then
        return nil
    end
    fullType = tostring(fullType)
    if fullType:sub(1, 10) == "Base.Base." then
        fullType = "Base." .. fullType:sub(11)
    end
    local colonPos = fullType:find(":", 1, true)
    if colonPos then
        local moduleName = fullType:sub(1, colonPos - 1)
        local itemName = fullType:sub(colonPos + 1)
        if moduleName ~= "" and itemName ~= "" then
            if moduleName:lower() == "base" then
                moduleName = "Base"
            end
            fullType = moduleName .. "." .. itemName
        end
    end
    if fullType:find(".", 1, true) then
        return fullType
    end
    return "Base." .. fullType
end

local function normalizeRecoverableArcheryAmmoType(fullType)
    local normalized = normalizeFullType(fullType)
    if not normalized then
        return nil
    end
    if normalized:sub(-6) == "_floor" then
        return normalized:sub(1, -7)
    end
    if normalized:sub(-4) == "_fly" then
        return normalized:sub(1, -5)
    end
    return normalized
end

local function applyIntegrationProfiles()
    local defs = rawget(_G, "GGS_BOWS")
    if not defs then
        return
    end

    local weaponDefs = defs.Weapons or {}
    for weaponType, cfg in pairs(weaponDefs) do
        local normalizedType = normalizeFullType(weaponType)
        if normalizedType and cfg then
            ARROW_FX_BY_WEAPON[normalizedType] = {
                defaultAmmoType = normalizeRecoverableArcheryAmmoType(cfg.defaultAmmoType) or "Base.arrow_wood",
                defaultFlightVisualItem = normalizeFullType(cfg.defaultFlightVisualItem)
                    or "Base.arrow_wood_fly",
                defaultFloorItemType = normalizeRecoverableArcheryAmmoType(cfg.defaultFloorItemType)
                    or normalizeRecoverableArcheryAmmoType(cfg.defaultAmmoType)
                    or "Base.arrow_wood",
                speedTilesPerSec = tonumber(cfg.speedTilesPerSec) or 15.0,
                minFlight = tonumber(cfg.minFlight) or 0.18,
                maxFlight = tonumber(cfg.maxFlight) or 1.40,
                startZBias = tonumber(cfg.startZBias) or 0.72,
                arcZ = tonumber(cfg.arcZ) or 0.22,
                worldOzMax = tonumber(cfg.worldOzMax) or 0.95,
                maxTargetDistance = tonumber(cfg.maxTargetDistance) or 55.0,
                impactDamageRadius = tonumber(cfg.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS,
                damageScale = tonumber(cfg.damageScale) or 1.0,
                dropStartRange = tonumber(cfg.dropStartRange) or 14.0,
                dropPerTile = tonumber(cfg.dropPerTile) or 0.065,
                groundImpactEpsilon = tonumber(cfg.groundImpactEpsilon) or BOW_GROUND_IMPACT_EPSILON,
                muzzleAttachment = tostring(cfg.muzzleAttachment or "BowMuzzle"),
                fallbackMuzzleModelScript = tostring(cfg.fallbackMuzzleModelScript or "Primitive_Bow")
            }
            BOW_STAT_FALLBACKS[normalizedType] = {
                tensionPower = tonumber(cfg.tensionPower) or (BOW_STAT_FALLBACKS[normalizedType] and BOW_STAT_FALLBACKS[normalizedType].tensionPower) or 5.0
            }
        end
    end

    local ammoDefs = defs.Ammo or {}
    for ammoType, stats in pairs(ammoDefs) do
        local normalizedAmmo = normalizeFullType(ammoType)
        if normalizedAmmo and stats then
            ARROW_STAT_FALLBACKS[normalizedAmmo] = {
                sharpness = tonumber(stats.sharpness) or 0.90,
                impactImpulse = tonumber(stats.impactImpulse) or 0.01,
                flightVisualItemType = normalizeFullType(stats.flightVisualItemType) or "Base.arrow_wood_fly",
                floorItemType = normalizeRecoverableArcheryAmmoType(stats.floorItemType) or normalizedAmmo,
                hitReaction = tostring(stats.hitReaction or "arrow_light"),
                flightYawOffset = tonumber(stats.flightYawOffset) or 0.0,
                flightVisualZOffset = tonumber(stats.flightVisualZOffset) or 0.0,
                flightRenderZBias = tonumber(stats.flightRenderZBias) or ARCHERY_PROJECTILE_VISUAL_Z_BIAS
            }
            if tonumber(stats.mass) ~= nil then
                ARROW_STAT_FALLBACKS[normalizedAmmo].mass = tonumber(stats.mass)
            end
        end
    end
end

applyIntegrationProfiles()

local function createInventoryItemByType(fullType)
    fullType = normalizeFullType(fullType)
    if not fullType then
        return nil
    end

    if instanceItem then
        local ok, item = pcall(instanceItem, fullType)
        if ok and item then
            return item
        end
    end

    if not InventoryItemFactory and require then
        pcall(function()
            InventoryItemFactory = require "Inventory/InventoryItemFactory"
        end)
    end
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, item = pcall(InventoryItemFactory.CreateItem, fullType)
        if ok and item then
            return item
        end
    end

    return nil
end

local function getWeaponFullType(item)
    if not item then
        return nil
    end
    if item.getFullType then
        local ok, value = pcall(item.getFullType, item)
        if ok and value then
            return normalizeFullType(value)
        end
    end
    if item.getModule and item.getType then
        local ok1, moduleName = pcall(item.getModule, item)
        local ok2, itemType = pcall(item.getType, item)
        if ok1 and ok2 and moduleName and itemType then
            return normalizeFullType(tostring(moduleName) .. "." .. tostring(itemType))
        end
    end
    return nil
end

local function getScriptItemSafe(item)
    if not (item and item.getScriptItem) then
        return nil
    end
    local ok, scriptItem = pcall(item.getScriptItem, item)
    if ok and scriptItem then
        return scriptItem
    end
    return nil
end

local function getScriptPropertyRaw(item, propName)
    local scriptItem = getScriptItemSafe(item)
    if not (scriptItem and propName) then
        return nil
    end

    if scriptItem.getProperty then
        local ok, value = pcall(scriptItem.getProperty, scriptItem, tostring(propName))
        if ok and value ~= nil and tostring(value) ~= "" then
            return value
        end
    end

    if scriptItem.getProperties then
        local okProps, props = pcall(scriptItem.getProperties, scriptItem)
        if okProps and props then
            if props.Val then
                local okVal, value = pcall(props.Val, props, tostring(propName))
                if okVal and value ~= nil and tostring(value) ~= "" then
                    return value
                end
            elseif props.get then
                local okGet, value = pcall(props.get, props, tostring(propName))
                if okGet and value ~= nil and tostring(value) ~= "" then
                    return value
                end
            end
        end
    end

    return nil
end

local function getScriptPropertyNumber(item, propName, defaultValue)
    local raw = getScriptPropertyRaw(item, propName)
    local value = tonumber(raw)
    if value ~= nil then
        return value
    end
    return defaultValue
end

local function getScriptPropertyString(item, propName, defaultValue)
    local raw = getScriptPropertyRaw(item, propName)
    if raw ~= nil then
        local s = tostring(raw)
        if s ~= "" then
            return normalizeFullType(s)
        end
    end
    return defaultValue
end

local function getInventoryItemWeight(item, defaultValue)
    if not item then
        return defaultValue
    end
    if item.getWeight then
        local ok, value = pcall(item.getWeight, item)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return defaultValue
end

local function getScriptPropertyNumberWithFallback(item, propName, defaultValue)
    local value = getScriptPropertyNumber(item, propName, nil)
    if value == nil then
        return defaultValue
    end
    return value
end

local function tryGetVectorComponent(vec, idx)
    if not vec then
        return nil
    end
    local methods = nil
    if idx == 1 then
        methods = { "x", "getX" }
    elseif idx == 2 then
        methods = { "y", "getY" }
    else
        methods = { "z", "getZ" }
    end
    for i = 1, #methods do
        local fn = vec[methods[i]]
        if fn then
            local ok, value = pcall(fn, vec)
            if ok and tonumber(value) then
                return tonumber(value)
            end
        end
    end
    return nil
end

local function getWeaponModelScriptName(weapon, cfg)
    local scriptItem = getScriptItemSafe(weapon)
    if scriptItem then
        if scriptItem.getStaticModel then
            local ok, value = pcall(scriptItem.getStaticModel, scriptItem)
            if ok and value and tostring(value) ~= "" then
                return tostring(value)
            end
        end
    end
    if weapon and weapon.getStaticModel then
        local ok, value = pcall(weapon.getStaticModel, weapon)
        if ok and value and tostring(value) ~= "" then
            return tostring(value)
        end
    end
    if cfg and cfg.fallbackMuzzleModelScript then
        return tostring(cfg.fallbackMuzzleModelScript)
    end
    return nil
end

local function getModelScriptAttachmentOffset(modelScriptName, attachmentId)
    modelScriptName = tostring(modelScriptName or "")
    attachmentId = tostring(attachmentId or "")
    if modelScriptName == "" or attachmentId == "" then
        return nil
    end

    local cacheKey = modelScriptName .. "|" .. attachmentId
    if bowMuzzleOffsetCache[cacheKey] ~= nil then
        return bowMuzzleOffsetCache[cacheKey] or nil
    end

    local scriptManager = getScriptManager and getScriptManager() or nil
    if not scriptManager then
        bowMuzzleOffsetCache[cacheKey] = false
        return nil
    end

    local modelScript = nil
    if scriptManager.getModelScript then
        local ok, value = pcall(scriptManager.getModelScript, scriptManager, modelScriptName)
        if ok and value then
            modelScript = value
        end
    end
    if not modelScript then
        bowMuzzleOffsetCache[cacheKey] = false
        return nil
    end

    local attach = nil
    if modelScript.getAttachmentById then
        local ok, value = pcall(modelScript.getAttachmentById, modelScript, attachmentId)
        if ok and value then
            attach = value
        end
    end
    if not attach then
        bowMuzzleOffsetCache[cacheKey] = false
        return nil
    end

    local offsetVec = nil
    if attach.getOffset then
        local ok, value = pcall(attach.getOffset, attach)
        if ok and value then
            offsetVec = value
        end
    end
    if not offsetVec then
        bowMuzzleOffsetCache[cacheKey] = false
        return nil
    end

    local ox = tryGetVectorComponent(offsetVec, 1) or 0.0
    local oy = tryGetVectorComponent(offsetVec, 2) or 0.0
    local oz = tryGetVectorComponent(offsetVec, 3) or 0.0
    local resolved = { x = ox, y = oy, z = oz }
    bowMuzzleOffsetCache[cacheKey] = resolved
    return resolved
end

local function applyBowMuzzleAttachmentOffset(playerObj, weapon, cfg, startX, startY, startZ, dirX, dirY)
    local attachId = (cfg and cfg.muzzleAttachment) or "BowMuzzle"
    local modelScriptName = getWeaponModelScriptName(weapon, cfg)
    local localOffset = getModelScriptAttachmentOffset(modelScriptName, attachId)
    if not localOffset then
        return startX, startY, startZ
    end

    local fx = tonumber(dirX) or 0.0
    local fy = tonumber(dirY) or 0.0
    local len = math.sqrt(fx * fx + fy * fy)
    if len < 0.0001 then
        return startX, startY, startZ
    end
    fx = fx / len
    fy = fy / len
    local rx = -fy
    local ry = fx

    -- Mapeo simple de espacio local->mundo: X lateral, Y hacia delante, Z vertical.
    startX = startX + (rx * (localOffset.x or 0.0)) + (fx * (localOffset.y or 0.0))
    startY = startY + (ry * (localOffset.x or 0.0)) + (fy * (localOffset.y or 0.0))
    startZ = startZ + (localOffset.z or 0.0)
    return startX, startY, startZ
end

local function resolveBowTensionPower(weapon)
    local weaponType = getWeaponFullType(weapon)
    local fallback = (BOW_STAT_FALLBACKS[weaponType] and BOW_STAT_FALLBACKS[weaponType].tensionPower) or 20.0
    local value = getScriptPropertyNumber(weapon, "TensionPower", nil)
    if value == nil then
        value = fallback
    end
    return math.max(0.1, tonumber(value) or fallback)
end

local function resolveBowArrowAmmoType(weapon, cfg)
    local runtime = rawget(_G, "GGS_ArcheryRuntime")
    if runtime and runtime.getLoadedAmmoType then
        local ok, loadedAmmo = pcall(runtime.getLoadedAmmoType, weapon)
        if ok and loadedAmmo then
            return normalizeRecoverableArcheryAmmoType(loadedAmmo)
        end
    end

    local fromScript = getScriptPropertyString(weapon, "ArrowAmmoItemType", nil)
    if fromScript then
        return normalizeRecoverableArcheryAmmoType(fromScript)
    end
    if cfg and cfg.defaultAmmoType then
        return normalizeRecoverableArcheryAmmoType(cfg.defaultAmmoType)
    end
    return "Base.WoodShaft_Arrow"
end

local function resolveArrowStats(ammoFullType, cfg)
    ammoFullType = normalizeRecoverableArcheryAmmoType(ammoFullType)
        or normalizeRecoverableArcheryAmmoType(cfg and cfg.defaultAmmoType)
        or "Base.WoodShaft_Arrow"
    if arrowStatCache[ammoFullType] then
        return arrowStatCache[ammoFullType]
    end

    local ammoItem = createInventoryItemByType(ammoFullType)
    local fallback = ARROW_STAT_FALLBACKS[ammoFullType] or {}
    local sharpness = getScriptPropertyNumber(ammoItem, "ArrowSharpness", nil)
    if sharpness == nil then
        if ammoItem and ammoItem.getSharpness then
            local ok, value = pcall(ammoItem.getSharpness, ammoItem)
            if ok and tonumber(value) then
                sharpness = tonumber(value)
            end
        end
    end
    if sharpness == nil then
        sharpness = getScriptPropertyNumber(ammoItem, "Sharpness", fallback.sharpness or 0.8)
    end

    local impactImpulse = getScriptPropertyNumber(ammoItem, "ArrowImpactImpulse", fallback.impactImpulse or 0.45)
    local hitReaction = nil
    do
        local rawReaction = getScriptPropertyRaw(ammoItem, "ArrowHitReaction")
        if rawReaction ~= nil and tostring(rawReaction) ~= "" then
            hitReaction = tostring(rawReaction)
        else
            hitReaction = fallback.hitReaction
        end
    end
    if hitReaction ~= nil then
        local lowered = tostring(hitReaction):lower()
        if lowered == "none" or lowered == "off" or lowered == "false" or lowered == "0" then
            hitReaction = nil
        end
    end
    local flightVisualItemType = getScriptPropertyString(ammoItem, "ArrowFlightVisualItem", fallback.flightVisualItemType)
    local floorItemType = getScriptPropertyString(ammoItem, "ArrowFloorItemType", fallback.floorItemType or ammoFullType)
    local flightYawOffset = getScriptPropertyNumber(ammoItem, "ArrowFlightYawOffset", fallback.flightYawOffset or 0.0)
    local flightVisualZOffset = getScriptPropertyNumber(ammoItem, "ArrowFlightVisualZOffset", fallback.flightVisualZOffset or 0.0)
    local flightRenderZBias = getScriptPropertyNumber(ammoItem, "ArrowFlightRenderZBias", fallback.flightRenderZBias or ARCHERY_PROJECTILE_VISUAL_Z_BIAS)
    local mass = getScriptPropertyNumber(ammoItem, "ArrowMass", nil)
    if mass == nil then
        mass = getInventoryItemWeight(ammoItem, fallback.mass or 0.08)
    end

    local resolved = {
        ammoType = ammoFullType,
        sharpness = math.max(0.0, tonumber(sharpness) or 0.8),
        impactImpulse = math.max(0.0, tonumber(impactImpulse) or 0.45),
        hitReaction = hitReaction,
        flightVisualItemType = normalizeFullType(flightVisualItemType)
            or normalizeFullType(cfg and cfg.defaultFlightVisualItem)
            or ammoFullType,
        floorItemType = normalizeRecoverableArcheryAmmoType(floorItemType) or ammoFullType,
        flightYawOffset = tonumber(flightYawOffset) or 0.0,
        flightVisualZOffset = tonumber(flightVisualZOffset) or 0.0,
        flightRenderZBias = tonumber(flightRenderZBias) or ARCHERY_PROJECTILE_VISUAL_Z_BIAS,
        mass = math.max(0.001, tonumber(mass) or 0.08)
    }

    arrowStatCache[ammoFullType] = resolved
    return resolved
end

local function looksLikeCharacter(obj)
    return obj and obj.getX and obj.getY and obj.getZ and obj.getSquare and obj.isAiming
end

local function looksLikeWeapon(obj)
    return obj and (obj.getFullType or obj.getType) and (obj.isRanged or obj.getAmmoType)
end

local function isLocalCharacter(character)
    if not character then
        return false
    end
    if character.isLocalPlayer then
        local ok, value = pcall(character.isLocalPlayer, character)
        if ok and value then
            return true
        end
    end
    local playerObj = getPlayer and getPlayer() or nil
    return playerObj ~= nil and character == playerObj
end

local function extractCharacterAndWeaponFromArgs(a, b, c, d, e, f)
    local args = { a, b, c, d, e, f }
    local character = nil
    local weapon = nil
    for i = 1, #args do
        local v = args[i]
        if not character and looksLikeCharacter(v) then
            character = v
        end
        if not weapon and looksLikeWeapon(v) then
            weapon = v
        end
    end
    return character, weapon
end

local function getWeaponDamageSnapshot(weapon)
    if not weapon then
        return nil
    end
    local minDamage = nil
    local maxDamage = nil
    if weapon.getMinDamage then
        local ok, value = pcall(weapon.getMinDamage, weapon)
        if ok and tonumber(value) then
            minDamage = tonumber(value)
        end
    end
    if weapon.getMaxDamage then
        local ok, value = pcall(weapon.getMaxDamage, weapon)
        if ok and tonumber(value) then
            maxDamage = tonumber(value)
        end
    end
    if minDamage == nil and maxDamage == nil then
        return nil
    end
    if minDamage == nil then
        minDamage = maxDamage or 0
    end
    if maxDamage == nil then
        maxDamage = minDamage or 0
    end
    local snapshot = {
        minDamage = minDamage,
        maxDamage = maxDamage
    }

    if weapon.getStopPower then
        local ok, value = pcall(weapon.getStopPower, weapon)
        if ok and tonumber(value) ~= nil then
            snapshot.stopPower = tonumber(value)
        end
    end
    if weapon.getPushBackMod then
        local ok, value = pcall(weapon.getPushBackMod, weapon)
        if ok and tonumber(value) ~= nil then
            snapshot.pushBackMod = tonumber(value)
        end
    end
    if weapon.getKnockdownMod then
        local ok, value = pcall(weapon.getKnockdownMod, weapon)
        if ok and tonumber(value) ~= nil then
            snapshot.knockdownMod = tonumber(value)
        end
    end
    if weapon.isKnockBackOnNoDeath then
        local ok, value = pcall(weapon.isKnockBackOnNoDeath, weapon)
        if ok then
            snapshot.knockBackOnNoDeath = value and true or false
        end
    elseif weapon.getKnockBackOnNoDeath then
        local ok, value = pcall(weapon.getKnockBackOnNoDeath, weapon)
        if ok then
            snapshot.knockBackOnNoDeath = value and true or false
        end
    end

    return snapshot
end

local function computeBowImpactDamage(weapon, arrowStats, cfg)
    local tensionPower = resolveBowTensionPower(weapon)
    local mass = (arrowStats and tonumber(arrowStats.mass)) or 0.08
    local sharpness = (arrowStats and tonumber(arrowStats.sharpness)) or 0.8
    local scale = (cfg and tonumber(cfg.damageScale)) or 1.0

    -- Mezcla simple y estable: tension (energia) + masa/filo (transferencia de dano).
    local damage = (tensionPower * 0.055) + (sharpness * 0.90) + (mass * 9.0)
    damage = damage * scale
    return math.max(0.10, damage)
end

local function setBowDamageZero(weapon)
    local changed = false
    if weapon and weapon.setMinDamage then
        local ok = pcall(weapon.setMinDamage, weapon, 0.0)
        changed = changed or ok
    end
    if weapon and weapon.setMaxDamage then
        local ok = pcall(weapon.setMaxDamage, weapon, 0.0)
        changed = changed or ok
    end
    if weapon and weapon.setStopPower then
        local ok = pcall(weapon.setStopPower, weapon, 0)
        changed = changed or ok
    end
    if weapon and weapon.setPushBackMod then
        local ok = pcall(weapon.setPushBackMod, weapon, 0.0)
        changed = changed or ok
    end
    if weapon and weapon.setKnockdownMod then
        local ok = pcall(weapon.setKnockdownMod, weapon, 0)
        changed = changed or ok
    end
    if weapon and weapon.setKnockBackOnNoDeath then
        local ok = pcall(weapon.setKnockBackOnNoDeath, weapon, false)
        changed = changed or ok
    end
    return changed
end

local function restoreBowDamageFromSnapshot(weapon, snapshot)
    if not (weapon and snapshot) then
        return false
    end
    local changed = false
    if weapon.setMinDamage and snapshot.minDamage ~= nil then
        local ok = pcall(weapon.setMinDamage, weapon, tonumber(snapshot.minDamage) or 0.0)
        changed = changed or ok
    end
    if weapon.setMaxDamage and snapshot.maxDamage ~= nil then
        local ok = pcall(weapon.setMaxDamage, weapon, tonumber(snapshot.maxDamage) or 0.0)
        changed = changed or ok
    end
    if weapon.setStopPower and snapshot.stopPower ~= nil then
        local ok = pcall(weapon.setStopPower, weapon, tonumber(snapshot.stopPower) or 0)
        changed = changed or ok
    end
    if weapon.setPushBackMod and snapshot.pushBackMod ~= nil then
        local ok = pcall(weapon.setPushBackMod, weapon, tonumber(snapshot.pushBackMod) or 0.0)
        changed = changed or ok
    end
    if weapon.setKnockdownMod and snapshot.knockdownMod ~= nil then
        local ok = pcall(weapon.setKnockdownMod, weapon, tonumber(snapshot.knockdownMod) or 0)
        changed = changed or ok
    end
    if weapon.setKnockBackOnNoDeath and snapshot.knockBackOnNoDeath ~= nil then
        local ok = pcall(weapon.setKnockBackOnNoDeath, weapon, snapshot.knockBackOnNoDeath and true or false)
        changed = changed or ok
    end
    return changed
end

local function suppressBowDamageUntilImpact(weapon, durationMs)
    if not weapon then
        return false
    end
    local key = tostring(weapon)
    if not key or key == "" then
        return false
    end

    local now = nowMs()
    local expiresAt = now + math.max(60, tonumber(durationMs) or 120)
    local existing = suppressedBowDamage[key]
    if existing then
        existing.expiresAtMs = math.max(existing.expiresAtMs or 0, expiresAt)
        existing.weapon = weapon
        return true
    end

    local snapshot = getWeaponDamageSnapshot(weapon)
    if not snapshot then
        return false
    end

    local changed = setBowDamageZero(weapon)
    suppressedBowDamage[key] = {
        weapon = weapon,
        snapshot = snapshot,
        expiresAtMs = expiresAt,
        changed = changed and true or false
    }
    logArrowFx("suppress bow damage weapon=%s changed=%s until=%d", tostring(getWeaponFullType(weapon)), tostring(changed), expiresAt)
    return true
end

local function updateSuppressedBowDamage()
    if type(suppressedBowDamage) ~= "table" then
        return
    end

    local hasEntries = false
    for _ in pairs(suppressedBowDamage) do
        hasEntries = true
        break
    end
    if not hasEntries then
        return
    end

    local currentMs = nowMs()
    local keysToClear = nil
    for key, entry in pairs(suppressedBowDamage) do
        if not entry or currentMs >= (tonumber(entry.expiresAtMs) or 0) then
            if entry and entry.weapon and entry.snapshot then
                local restored = restoreBowDamageFromSnapshot(entry.weapon, entry.snapshot)
                logArrowFx("restore bow damage key=%s restored=%s", tostring(key), tostring(restored))
            end
            if not keysToClear then
                keysToClear = {}
            end
            keysToClear[#keysToClear + 1] = key
        end
    end

    if keysToClear then
        for i = 1, #keysToClear do
            suppressedBowDamage[keysToClear[i]] = nil
        end
    end
end

local function toWorldInventoryObject(addResult)
    if not addResult then
        return nil, nil
    end
    if addResult.getWorldItem and addResult.getWorldItem ~= addResult then
        local ok, worldObj = pcall(addResult.getWorldItem, addResult)
        if ok and worldObj then
            return worldObj, addResult
        end
    end
    if addResult.getItem and addResult.getSquare then
        local ok, item = pcall(addResult.getItem, addResult)
        return addResult, (ok and item or nil)
    end
    return nil, nil
end

local function spawnWorldProjectileObject(square, itemOrType, ox, oy, oz)
    if not (square and square.AddWorldInventoryItem) then
        return nil, nil, nil
    end

    local item = itemOrType
    if type(itemOrType) == "string" then
        item = createInventoryItemByType(itemOrType)
    end
    if not item then
        return nil, nil, nil
    end

    local ok, result = pcall(square.AddWorldInventoryItem, square, item, tonumber(ox) or 0, tonumber(oy) or 0, tonumber(oz) or 0)
    if not ok or not result then
        return nil, nil, nil
    end

    local worldObj, worldItem = toWorldInventoryObject(result)
    if not worldObj then
        return nil, nil, nil
    end
    return worldObj, (worldItem or item), square
end

local function removeWorldProjectileObject(worldObj, fallbackSquare)
    if not worldObj then
        return false
    end

    local square = nil
    if worldObj.getSquare then
        local ok, sq = pcall(worldObj.getSquare, worldObj)
        if ok then
            square = sq
        end
    end
    if not square then
        square = fallbackSquare
    end
    if not (square and square.removeWorldObject) then
        return false
    end

    local ok = pcall(square.removeWorldObject, square, worldObj)
    return ok or false
end

local function setArrowWorldRotation(worldObj, worldItem, yawDeg)
    if yawDeg == nil then
        return false
    end
    local applied = false
    if worldItem and worldItem.setWorldZRotation then
        local ok = pcall(worldItem.setWorldZRotation, worldItem, yawDeg)
        applied = applied or (ok and true or false)
    end
    if (not applied) and worldObj and worldObj.setWorldZRotation then
        local ok = pcall(worldObj.setWorldZRotation, worldObj, yawDeg)
        applied = applied or (ok and true or false)
    end
    return applied
end

local function computeArrowYawDeg(vx, vy, yawOffset)
    local x = tonumber(vx) or 0.0
    local y = tonumber(vy) or 0.0
    if math.abs(x) < 0.0001 and math.abs(y) < 0.0001 then
        return nil
    end
    return math.deg(math.atan2(y, x)) + (tonumber(yawOffset) or 0.0)
end

local function createArrowFxVisualAt(x, y, z, visualItemType, cfg, visualZOffset, renderZBias)
    local gx = floorToGrid(x)
    local gy = floorToGrid(y)
    local gz = math.floor(tonumber(z) or 0)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return nil
    end
    local square = cell:getGridSquare(gx, gy, gz)
    if not square then
        return nil
    end

    local visualZ = (tonumber(z) or 0) + (tonumber(visualZOffset) or 0.0) + (tonumber(renderZBias) or 0.0)
    local ox = x - gx
    local oy = y - gy
    local oz = (visualZ - gz)
    oz = math.max(0.0, math.min(tonumber(cfg.worldOzMax) or 0.95, oz))

    if isClient and isClient() then
        local renderItem = createInventoryItemByType(visualItemType)
        if renderItem then
            return {
                mode = "render3d",
                renderItem = renderItem,
                renderSquare = square,
                renderRotation = 0.0,
                x = x,
                y = y,
                z = visualZ
            }
        end

        -- In MP the projectile-in-flight must never fall back to a real WorldInventoryItem,
        -- otherwise every movement step can persist as loot after reconnect/reload.
        return nil
    end

    local worldObj, worldItem, worldSquare = spawnWorldProjectileObject(square, visualItemType, ox, oy, oz)
    if not worldObj then
        return nil
    end

    return {
        mode = "world",
        worldObj = worldObj,
        worldItem = worldItem,
        worldSquare = worldSquare,
        x = x,
        y = y,
        z = visualZ
    }
end

local function moveArrowFxWorldObject(entry, px, py, pz, vx, vy)
    if not (entry and entry.worldItem) then
        return false
    end

    local gx = floorToGrid(px)
    local gy = floorToGrid(py)
    local gz = math.floor(tonumber(pz) or 0)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return false
    end

    local square = cell:getGridSquare(gx, gy, gz)
    if not square then
        return false
    end

    local ox = px - gx
    local oy = py - gy
    local visualZ = (tonumber(pz) or 0) + (tonumber(entry.flightVisualZOffset) or 0.0) + (tonumber(entry.flightRenderZBias) or 0.0)
    local oz = math.max(0.0, math.min(entry.worldOzMax or 0.95, visualZ - gz))

    if entry.worldObj then
        removeWorldProjectileObject(entry.worldObj, entry.worldSquare)
    end

    local nextObj, nextItem, nextSquare = spawnWorldProjectileObject(square, entry.worldItem, ox, oy, oz)
    if not nextObj then
        return false
    end

    entry.worldObj = nextObj
    entry.worldItem = nextItem or entry.worldItem
    entry.worldSquare = nextSquare or square
    local yawDeg = computeArrowYawDeg(vx, vy, entry.flightYawOffset)
    if yawDeg ~= nil then
        setArrowWorldRotation(entry.worldObj, entry.worldItem, yawDeg)
    end
    return true
end

local function moveArrowFxVisual(entry, px, py, pz, vx, vy)
    if not entry then
        return false
    end

    if entry.mode == "render3d" then
        if not (entry.renderItem and getCell) then
            return false
        end
        local cell = getCell()
        if not cell then
            return false
        end

        local visualZ = (tonumber(pz) or 0) + (tonumber(entry.flightVisualZOffset) or 0.0) + (tonumber(entry.flightRenderZBias) or 0.0)
        local square = cell:getGridSquare(floorToGrid(px), floorToGrid(py), math.floor(visualZ))
        if not square then
            square = cell:getGridSquare(floorToGrid(px), floorToGrid(py), 0)
        end
        if not square then
            return false
        end

        entry.renderSquare = square
        entry.renderRotation = entry.renderRotation or 0.0
        entry.x = px
        entry.y = py
        entry.z = visualZ
        local yawDeg = computeArrowYawDeg(vx, vy, entry.flightYawOffset)
        if yawDeg ~= nil then
            setArrowWorldRotation(nil, entry.renderItem, yawDeg)
            entry.renderRotation = yawDeg
        end
        return true
    end

    return moveArrowFxWorldObject(entry, px, py, pz, vx, vy)
end

local function removeArrowFxVisual(entry)
    if not entry then
        return
    end
    if entry.worldObj then
        removeWorldProjectileObject(entry.worldObj, entry.worldSquare)
    end
    entry.worldObj = nil
    entry.worldSquare = nil
    entry.renderItem = nil
    entry.renderSquare = nil
end

local function renderArrowFxVisuals()
    if not (Render3DItem and getCell) then
        return
    end

    local cell = getCell()
    if not cell then
        return
    end

    for i = 1, #activeArrowFx do
        local entry = activeArrowFx[i]
        if entry and entry.mode == "render3d" and entry.renderItem then
            local square = entry.renderSquare
            if not square then
                square = cell:getGridSquare(floorToGrid(entry.x), floorToGrid(entry.y), math.floor(entry.z or 0))
                if not square then
                    square = cell:getGridSquare(floorToGrid(entry.x), floorToGrid(entry.y), 0)
                end
                entry.renderSquare = square
            end

            if square then
                pcall(Render3DItem, entry.renderItem, square, entry.x, entry.y, entry.z, entry.renderRotation or 0.0)
            end
        end
    end
end

local function squareBlockedBetween(a, b)
    if not (a and b) or a == b then
        return false
    end
    if a.isBlockedTo then
        local ok, blocked = pcall(a.isBlockedTo, a, b)
        if ok and blocked then
            return true
        end
    end
    if a.isWindowTo then
        local ok, blocked = pcall(a.isWindowTo, a, b)
        if ok and blocked then
            return true
        end
    end
    return false
end

local function findWallCollisionAlongSegment(x1, y1, z1, x2, y2, z2)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return nil, nil, nil
    end

    local dx = (tonumber(x2) or 0) - (tonumber(x1) or 0)
    local dy = (tonumber(y2) or 0) - (tonumber(y1) or 0)
    local distance = math.sqrt(dx * dx + dy * dy)
    local steps = math.max(1, math.ceil(distance / BOW_WALL_SEGMENT_STEP))

    local prevPx = tonumber(x1) or 0
    local prevPy = tonumber(y1) or 0
    local prevPz = tonumber(z1) or 0
    local prevSq = cell:getGridSquare(floorToGrid(prevPx), floorToGrid(prevPy), math.floor(prevPz))

    for i = 1, steps do
        local t = i / steps
        local px = (tonumber(x1) or 0) + (dx * t)
        local py = (tonumber(y1) or 0) + (dy * t)
        local pz = lerp(z1, z2, t)
        local sq = cell:getGridSquare(floorToGrid(px), floorToGrid(py), math.floor(pz))
        if sq and prevSq and sq ~= prevSq then
            if squareBlockedBetween(prevSq, sq) or squareBlockedBetween(sq, prevSq) then
                return px, py, pz
            end
        end
        prevPx = px
        prevPy = py
        prevPz = pz
        prevSq = sq or prevSq
    end

    return nil, nil, nil
end

local function getGroundImpactZAt(entry, x, y, fallbackZ)
    local zFloor = math.floor(tonumber(fallbackZ) or tonumber(entry and entry.baseFloorZ) or 0)
    local cell = getCell and getCell() or nil
    if cell and cell.getGridSquare then
        local square = cell:getGridSquare(floorToGrid(x), floorToGrid(y), zFloor)
        if square and square.getZ then
            local ok, sqZ = pcall(square.getZ, square)
            if ok and tonumber(sqZ) then
                return tonumber(sqZ) + (tonumber(entry and entry.groundImpactEpsilon) or BOW_GROUND_IMPACT_EPSILON)
            end
        end
    end
    return zFloor + (tonumber(entry and entry.groundImpactEpsilon) or BOW_GROUND_IMPACT_EPSILON)
end

local function getGroundAimTargetZ(cfg, x, y, fallbackZ)
    local groundImpactEpsilon = math.max(
        0.0,
        tonumber(cfg and cfg.groundImpactEpsilon) or BOW_GROUND_IMPACT_EPSILON
    )
    local tempEntry = {
        baseFloorZ = math.floor(tonumber(fallbackZ) or 0),
        groundImpactEpsilon = groundImpactEpsilon
    }
    return getGroundImpactZAt(tempEntry, x, y, fallbackZ)
end

local function findNearestZombieAtImpact(x, y, z, radius)
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end

    local minX = math.floor(x - radius)
    local maxX = math.ceil(x + radius)
    local minY = math.floor(y - radius)
    local maxY = math.ceil(y + radius)
    local baseZ = math.floor(tonumber(z) or 0)
    local best = nil
    local bestDist = nil

    for scanZ = baseZ - 1, baseZ + 1 do
        for sx = minX, maxX do
            for sy = minY, maxY do
                local square = cell:getGridSquare(sx, sy, scanZ)
                if square and square.getMovingObjects then
                    local movingObjects = square:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if moving and instanceof and instanceof(moving, "IsoZombie") and isArrowZombieTargetable(moving) then
                                local dist = distance2D(x, y, moving:getX(), moving:getY())
                                if dist <= radius and (not bestDist or dist < bestDist) then
                                    best = moving
                                    bestDist = dist
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best, bestDist
end

local function clamp01(value)
    value = tonumber(value) or 0.0
    if value < 0.0 then
        return 0.0
    end
    if value > 1.0 then
        return 1.0
    end
    return value
end

local function computeSegmentProgress2D(x1, y1, x2, y2, px, py)
    local ax = tonumber(x1) or 0.0
    local ay = tonumber(y1) or 0.0
    local bx = tonumber(x2) or 0.0
    local by = tonumber(y2) or 0.0
    local qx = tonumber(px) or ax
    local qy = tonumber(py) or ay
    local abx = bx - ax
    local aby = by - ay
    local abLenSq = (abx * abx) + (aby * aby)
    if abLenSq <= 0.000001 then
        return 0.0
    end
    return clamp01((((qx - ax) * abx) + ((qy - ay) * aby)) / abLenSq)
end

local function distanceSqPointToSegment2D(px, py, x1, y1, x2, y2)
    local progress = computeSegmentProgress2D(x1, y1, x2, y2, px, py)
    local closestX = lerp(x1, x2, progress)
    local closestY = lerp(y1, y2, progress)
    local dx = (tonumber(px) or 0.0) - closestX
    local dy = (tonumber(py) or 0.0) - closestY
    return (dx * dx) + (dy * dy), progress, closestX, closestY
end

local function findZombieAlongSegment(x1, y1, z1, x2, y2, z2, radius)
    local cell = getCell and getCell() or nil
    if not cell then
        return nil, nil, nil, nil, nil
    end

    local radiusValue = math.max(0.10, tonumber(radius) or BOW_IMPACT_DAMAGE_RADIUS)
    local radiusSq = radiusValue * radiusValue
    local minX = math.floor(math.min(tonumber(x1) or 0.0, tonumber(x2) or 0.0) - radiusValue - 1.0)
    local maxX = math.ceil(math.max(tonumber(x1) or 0.0, tonumber(x2) or 0.0) + radiusValue + 1.0)
    local minY = math.floor(math.min(tonumber(y1) or 0.0, tonumber(y2) or 0.0) - radiusValue - 1.0)
    local maxY = math.ceil(math.max(tonumber(y1) or 0.0, tonumber(y2) or 0.0) + radiusValue + 1.0)
    local minZ = math.floor(math.min(tonumber(z1) or 0.0, tonumber(z2) or 0.0)) - 1
    local maxZ = math.floor(math.max(tonumber(z1) or 0.0, tonumber(z2) or 0.0)) + 1

    local bestZombie = nil
    local bestX, bestY, bestZ = nil, nil, nil
    local bestProgress, bestDistSq, bestZDelta = nil, nil, nil

    for scanZ = minZ, maxZ do
        for sx = minX, maxX do
            for sy = minY, maxY do
                local square = cell:getGridSquare(sx, sy, scanZ)
                if square and square.getMovingObjects then
                    local movingObjects = square:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if moving and instanceof and instanceof(moving, "IsoZombie") and isArrowZombieTargetable(moving) then
                                local zx = tonumber(moving:getX()) or sx
                                local zy = tonumber(moving:getY()) or sy
                                local distSq, progress, hitX, hitY = distanceSqPointToSegment2D(zx, zy, x1, y1, x2, y2)
                                if distSq <= radiusSq then
                                    local hitZ = lerp(z1, z2, progress)
                                    local zDelta = math.abs((tonumber(moving:getZ()) or scanZ) - hitZ)
                                    if zDelta <= 1.10 then
                                        local better = false
                                        if bestZombie == nil then
                                            better = true
                                        elseif progress < (bestProgress - 0.0001) then
                                            better = true
                                        elseif math.abs(progress - bestProgress) <= 0.0001 then
                                            if distSq < (bestDistSq - 0.0001) then
                                                better = true
                                            elseif math.abs(distSq - bestDistSq) <= 0.0001 and zDelta < (bestZDelta - 0.0001) then
                                                better = true
                                            end
                                        end

                                        if better then
                                            bestZombie = moving
                                            bestX = hitX
                                            bestY = hitY
                                            bestZ = hitZ
                                            bestProgress = progress
                                            bestDistSq = distSq
                                            bestZDelta = zDelta
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestZombie, bestX, bestY, bestZ, bestProgress
end

local function resolveSegmentZombieOrWallHit(x1, y1, z1, x2, y2, z2, radius)
    local wallX, wallY, wallZ = findWallCollisionAlongSegment(x1, y1, z1, x2, y2, z2)
    local wallProgress = nil
    if wallX ~= nil and wallY ~= nil then
        wallProgress = computeSegmentProgress2D(x1, y1, x2, y2, wallX, wallY)
    end

    local zombie, hitX, hitY, hitZ, hitProgress = findZombieAlongSegment(x1, y1, z1, x2, y2, z2, radius)
    if zombie and (wallProgress == nil or (tonumber(hitProgress) or 1.0) <= (wallProgress + 0.0001)) then
        return "zombie", zombie, hitX, hitY, hitZ, hitProgress
    end
    if wallX ~= nil and wallY ~= nil then
        return "wall", nil, wallX, wallY, wallZ, wallProgress
    end
    return nil, nil, nil, nil, nil, nil
end

local function spawnFloorArrowAtImpact(entry, impactX, impactY, impactZ)
    if not entry then
        return false
    end

    local itemType = normalizeRecoverableArcheryAmmoType(entry.arrowStats and entry.arrowStats.floorItemType)
        or normalizeRecoverableArcheryAmmoType(entry.ammoType)
        or "Base.WoodShaft_Arrow"
    local gx = floorToGrid(impactX)
    local gy = floorToGrid(impactY)
    local gz = math.floor(tonumber(impactZ) or 0)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return false
    end
    local square = cell:getGridSquare(gx, gy, gz)
    if not square then
        return false
    end

    local ox = math.max(0.0, math.min(0.99, (tonumber(impactX) or gx) - gx))
    local oy = math.max(0.0, math.min(0.99, (tonumber(impactY) or gy) - gy))
    local oz = math.max(0.0, math.min(0.95, (tonumber(impactZ) or gz) - gz))
    local worldObj, worldItem = spawnWorldProjectileObject(square, itemType, ox, oy, oz)
    if not worldObj then
        logArrowFx("floor arrow spawn failed item=%s", tostring(itemType))
        return false
    end

    if worldItem and worldItem.setWorldZRotation then
        local vx = (tonumber(entry.targetX) or 0) - (tonumber(entry.startX) or 0)
        local vy = (tonumber(entry.targetY) or 0) - (tonumber(entry.startY) or 0)
        if math.abs(vx) > 0.001 or math.abs(vy) > 0.001 then
            local yawDeg = computeArrowYawDeg(vx, vy, entry.flightYawOffset)
            if yawDeg ~= nil then
                pcall(worldItem.setWorldZRotation, worldItem, yawDeg)
            end
        end
    end

    logArrowFx("floor arrow spawned item=%s at=%d,%d,%d", tostring(itemType), gx, gy, gz)
    return true
end

local function spawnWallArrowAtImpact(entry, impactX, impactY, impactZ, vx, vy)
    if not entry then
        return false
    end

    local itemType = normalizeRecoverableArcheryAmmoType(entry.arrowStats and entry.arrowStats.floorItemType)
        or normalizeRecoverableArcheryAmmoType(entry.ammoType)
        or "Base.WoodShaft_Arrow"
    local gx = floorToGrid(impactX)
    local gy = floorToGrid(impactY)
    local gz = math.floor(tonumber(impactZ) or 0)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return false
    end
    local square = cell:getGridSquare(gx, gy, gz)
    if not square then
        return false
    end

    local visualZOffset = tonumber(entry.flightVisualZOffset) or 0.0
    local adjZ = (tonumber(impactZ) or gz) + visualZOffset
    local ox = math.max(0.0, math.min(0.99, (tonumber(impactX) or gx) - gx))
    local oy = math.max(0.0, math.min(0.99, (tonumber(impactY) or gy) - gy))
    local oz = math.max(0.0, math.min(entry.worldOzMax or 0.95, adjZ - gz))
    local worldObj, worldItem = spawnWorldProjectileObject(square, itemType, ox, oy, oz)
    if not worldObj then
        return false
    end

    local yawDeg = computeArrowYawDeg(vx, vy, entry.flightYawOffset)
    if yawDeg ~= nil then
        setArrowWorldRotation(worldObj, worldItem, yawDeg)
    end
    logArrowFx("wall arrow spawned item=%s at=%d,%d,%d", tostring(itemType), gx, gy, gz)
    return true
end

function tryAttachArrowToZombie(entry, target)
    if not (entry and target and target.setAttachedItem and target.getAttachedItem) then
        return false
    end

    local arrowItemType = normalizeRecoverableArcheryAmmoType(entry.arrowStats and entry.arrowStats.floorItemType)
        or normalizeRecoverableArcheryAmmoType(entry.ammoType)
        or "Base.WoodShaft_Arrow"
    local arrowItem = createInventoryItemByType(arrowItemType)
    if not arrowItem then
        return false
    end

    local function isSupportedAttachLocation(zombieTarget, locationName)
        if not (zombieTarget and locationName) then
            return false
        end

        local attachedItems = zombieTarget.getAttachedItems and zombieTarget:getAttachedItems() or nil
        local group = attachedItems and attachedItems.getGroup and attachedItems:getGroup() or nil
        if group then
            if group.getLocation then
                local ok, loc = pcall(group.getLocation, group, locationName)
                if ok then
                    return loc ~= nil
                end
            end
            if group.checkValid then
                local ok = pcall(group.checkValid, group, locationName)
                if ok then
                    return true
                end
            end
        end

        -- Fallback minimo para evitar excepciones conocidas en builds donde no existe esa location.
        if locationName == "Knife Back" or locationName == "Stomach" then
            return false
        end
        return true
    end

    local preferred = { "Knife Stomach", "Knife Shoulder", "Knife in Back", "Knife Left Leg", "Knife Right Leg" }
    local impactZone = tostring(entry and entry.lastEstimatedHitZone or "")
    if impactZone == "head" or impactZone == "upper_torso" then
        preferred = { "Knife Shoulder", "Knife in Back", "Knife Stomach", "Knife Left Leg", "Knife Right Leg" }
    elseif impactZone == "lower_torso" then
        preferred = { "Knife Stomach", "Knife Shoulder", "Knife in Back", "Knife Left Leg", "Knife Right Leg" }
    elseif impactZone == "legs" then
        preferred = { "Knife Left Leg", "Knife Right Leg", "Knife Stomach", "Knife Shoulder", "Knife in Back" }
    end
    local part = target.getLastHitPart and target:getLastHitPart() or nil
    if part == "Torso_Upper" then
        preferred = { "Knife Shoulder", "Knife in Back", "Knife Stomach", "Knife Left Leg", "Knife Right Leg" }
    elseif part == "Torso_Lower" then
        preferred = { "Knife Stomach", "Knife Shoulder", "Knife in Back", "Knife Left Leg", "Knife Right Leg" }
    end

    for i = 1, #preferred do
        local location = preferred[i]
        if isSupportedAttachLocation(target, location) then
            local occupied = false
            local okOcc, attached = pcall(target.getAttachedItem, target, location)
            if okOcc and attached then
                occupied = true
            end
            if (not okOcc) then
                occupied = true
            end
            if not occupied then
                local okSet = pcall(target.setAttachedItem, target, location, arrowItem)
                if okSet then
                    if isServer and isServer() and sendAttachedItem then
                        pcall(sendAttachedItem, target, location, arrowItem)
                    end
                    if target.reportEvent then
                        pcall(target.reportEvent, target, "EventAttachItem")
                    end
                    return true
                end
            end
        end
    end

    return false
end

local function applyArrowImpactReaction(target, reactionName)
    if not target then
        return false
    end

    -- Evitamos setHitReaction aca: en este flujo de dano custom puede dejar al zombie
    -- en estados inconsistentes ("freeze") segun build/anim state.
    if target.setStaggerBack then
        local ok = pcall(target.setStaggerBack, target, true)
        if ok then
            return true
        end
    end

    if target.staggerBack then
        local ok = pcall(target.staggerBack, target)
        if ok then
            return true
        end
    end

    return false
end

local function sendArrowImpactToServer(entry, explicitTarget, impactX, impactY, impactZ, segmentStartX, segmentStartY, segmentStartZ)
    if not (isClient and isClient() and sendClientCommand and entry) then
        return false
    end

    local args = {
        weaponType = entry.weaponType,
        ammoType = entry.ammoType,
        impactX = tonumber(impactX) or tonumber(entry.targetX) or 0,
        impactY = tonumber(impactY) or tonumber(entry.targetY) or 0,
        impactZ = tonumber(impactZ) or tonumber(entry.targetZ) or 0,
        impactDamage = tonumber(entry.impactDamage) or 0,
        impactRadius = tonumber(entry.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS,
        aimMode = tostring(entry.aimMode or ARCHERY_AIM_MODE_IMPACT_SQUARE),
        impactSquareX = tonumber(entry.impactSquareX),
        impactSquareY = tonumber(entry.impactSquareY),
        impactSquareZ = tonumber(entry.impactSquareZ),
        aimTargetX = tonumber(entry.targetX),
        aimTargetY = tonumber(entry.targetY),
        aimTargetZ = tonumber(entry.targetZ),
        impactReason = tostring(entry.lastImpactReason or "unknown"),
        impactProgress = tonumber(entry.lastImpactProgress),
        hitZone = tostring(entry.lastEstimatedHitZone or ""),
        hitZoneRelZ = tonumber(entry.lastEstimatedHitRelZ),
        hitZoneLateral = tonumber(entry.lastEstimatedHitLateral)
    }

    if segmentStartX ~= nil and segmentStartY ~= nil and segmentStartZ ~= nil then
        args.segmentStartX = tonumber(segmentStartX) or 0
        args.segmentStartY = tonumber(segmentStartY) or 0
        args.segmentStartZ = tonumber(segmentStartZ) or 0
    end

    if explicitTarget and explicitTarget.getX and explicitTarget.getY and explicitTarget.getZ then
        args.targetX = tonumber(explicitTarget:getX()) or args.impactX
        args.targetY = tonumber(explicitTarget:getY()) or args.impactY
        args.targetZ = tonumber(explicitTarget:getZ()) or math.floor(args.impactZ)
        if explicitTarget.getOnlineID then
            local ok, value = pcall(explicitTarget.getOnlineID, explicitTarget)
            if ok and value ~= nil then
                args.targetOnlineId = tostring(value)
            end
        end
        if explicitTarget.getObjectID then
            local ok, value = pcall(explicitTarget.getObjectID, explicitTarget)
            if ok and value ~= nil then
                args.targetObjectId = tostring(value)
            end
        end
        if explicitTarget.getID then
            local ok, value = pcall(explicitTarget.getID, explicitTarget)
            if ok and value ~= nil then
                args.targetId = tostring(value)
            end
        end
        if explicitTarget.getPersistentOutfitID then
            local ok, value = pcall(explicitTarget.getPersistentOutfitID, explicitTarget)
            if ok and value ~= nil then
                args.targetPersistentOutfitId = tostring(value)
            end
        end
    end

    local commandName = explicitTarget and "ArrowZombieHit" or "ArrowImpact"
    sendClientCommand("GGS_ArcheryFX", commandName, args)
    logArrowFx(
        "sent %s weapon=%s ammo=%s aim=%s reason=%s dmg=%.2f radius=%.2f impact=%.2f,%.2f,%.2f segmentStart=%.2f,%.2f,%s square=%s,%s,%s target=%s zone=%s ids={online=%s object=%s id=%s outfit=%s}",
        tostring(commandName),
        tostring(args.weaponType),
        tostring(args.ammoType),
        tostring(args.aimMode),
        tostring(args.impactReason),
        tonumber(args.impactDamage) or 0,
        tonumber(args.impactRadius) or 0,
        args.impactX,
        args.impactY,
        args.impactZ,
        tonumber(args.segmentStartX) or args.impactX,
        tonumber(args.segmentStartY) or args.impactY,
        tostring(args.segmentStartZ),
        tostring(args.impactSquareX),
        tostring(args.impactSquareY),
        tostring(args.impactSquareZ),
        describeArrowZombieDebug(explicitTarget),
        tostring(args.hitZone),
        tostring(args.targetOnlineId),
        tostring(args.targetObjectId),
        tostring(args.targetId),
        tostring(args.targetPersistentOutfitId)
    )
    return true
end

local function applyArrowImpactDamage(entry, explicitTarget, impactX, impactY, impactZ, segmentStartX, segmentStartY, segmentStartZ)
    if not entry then
        return false
    end
    if isClient and isClient() then
        local zone, relZ, lateral = estimateArrowImpactZone(explicitTarget, impactX, impactY, impactZ)
        entry.lastEstimatedHitZone = zone
        entry.lastEstimatedHitRelZ = relZ
        entry.lastEstimatedHitLateral = lateral
        local sent = sendArrowImpactToServer(entry, explicitTarget, impactX, impactY, impactZ, segmentStartX, segmentStartY, segmentStartZ)
        if sent and explicitTarget and entry.arrowStats and entry.arrowStats.hitReaction then
            local reaction = tostring(entry.arrowStats.hitReaction)
            if reaction ~= "" then
                pcall(applyArrowImpactReaction, explicitTarget, reaction)
            end
        end
        logArrowFx(
            "impact dispatch result sent=%s weapon=%s ammo=%s reason=%s zone=%s target=%s impact=%.2f,%.2f,%.2f",
            tostring(sent),
            tostring(entry.weaponType),
            tostring(entry.ammoType),
            tostring(entry.lastImpactReason),
            tostring(entry.lastEstimatedHitZone),
            describeArrowZombieDebug(explicitTarget),
            tonumber(impactX) or tonumber(entry.targetX) or 0,
            tonumber(impactY) or tonumber(entry.targetY) or 0,
            tonumber(impactZ) or tonumber(entry.targetZ) or 0
        )
        return sent
    end

    local radius = tonumber(entry.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS
    local x = tonumber(impactX) or tonumber(entry.targetX) or 0
    local y = tonumber(impactY) or tonumber(entry.targetY) or 0
    local z = math.floor(tonumber(impactZ) or tonumber(entry.targetZ) or 0)
    local damage = math.max(0.1, tonumber(entry.impactDamage) or 1.0)
    local target = explicitTarget or findNearestZombieAtImpact(x, y, z, radius)
    if not target then
        logArrowFx("impact no target x=%.2f y=%.2f z=%d", x, y, z)
        return false
    end
    if not isArrowZombieTargetable(target) then
        logArrowFx("impact ignored dead target=%s", tostring(target))
        return false
    end

    local zone, relZ, lateral = estimateArrowImpactZone(target, x, y, z)
    entry.lastEstimatedHitZone = zone
    entry.lastEstimatedHitRelZ = relZ
    entry.lastEstimatedHitLateral = lateral

    local hitApplied = false
    if target.getHealth and target.setHealth then
        local oldHealth = tonumber(target:getHealth()) or 1.0
        local ok = pcall(target.setHealth, target, math.max(0.0, oldHealth - damage))
        hitApplied = ok and true or false
    end

    if hitApplied and entry.arrowStats and entry.arrowStats.hitReaction then
        local reaction = tostring(entry.arrowStats.hitReaction)
        if reaction ~= "" then
            pcall(applyArrowImpactReaction, target, reaction)
        end
    end

    if hitApplied then
        pcall(tryAttachArrowToZombie, entry, target)
    end

    logArrowFx("impact damage target=%s applied=%s dmg=%.2f zone=%s relZ=%s lateral=%s", tostring(target), tostring(hitApplied), damage, tostring(zone), tostring(relZ), tostring(lateral))
    return hitApplied
end

local function computeFlightTime(distance, cfg)
    local speed = math.max(1.0, tonumber(cfg.speedTilesPerSec) or 26.0)
    local minFlight = math.max(0.05, tonumber(cfg.minFlight) or 0.12)
    local maxFlight = math.max(minFlight, tonumber(cfg.maxFlight) or 1.35)
    return math.max(minFlight, math.min(maxFlight, (tonumber(distance) or 0) / speed))
end

local function computeBallisticParams(weapon, cfg, startX, startY, startZ, targetX, targetY, targetZ, targetZombie)
    local tensionPower = resolveBowTensionPower(weapon)
    local tensionScale = math.sqrt(math.max(0.05, tensionPower) / 5.0)
    tensionScale = math.max(0.55, math.min(2.40, tensionScale))

    local baseSpeed = math.max(5.0, tonumber(cfg.speedTilesPerSec) or 15.0)
    local speed = baseSpeed * tensionScale

    local dx = (tonumber(targetX) or 0.0) - (tonumber(startX) or 0.0)
    local dy = (tonumber(targetY) or 0.0) - (tonumber(startY) or 0.0)
    local len2d = math.sqrt((dx * dx) + (dy * dy))

    if len2d < 0.001 then
        dx, dy, len2d = 0.0, 1.0, 1.0
    end

    local dirX = dx / len2d
    local dirY = dy / len2d
    local velocityX = dirX * speed
    local velocityY = dirY * speed
    local horizontalSpeed = math.sqrt((velocityX * velocityX) + (velocityY * velocityY))

    local dropPerTile = math.max(0.0, tonumber(cfg.dropPerTile) or 0.065)
    local gravityZ = math.max(BOW_BALLISTIC_MIN_GRAVITY, 2.0 * dropPerTile * math.max(1.0, horizontalSpeed))
    local minFlight = math.max(0.20, tonumber(cfg.minFlight) or 0.20)

    -- Ground aiming uses an arcade profile: the cursor defines the horizontal
    -- firing line, while the arrow gets only a small initial lift and then
    -- starts dropping naturally. Explicit zombie targets still get a direct
    -- solve so hit registration remains reliable.
    local zeroDistance = nil
    local zeroHeightZ = nil
    local velocityZ = nil
    if targetZombie then
        zeroDistance = math.max(1.0, len2d)
        zeroHeightZ = tonumber(targetZ) or tonumber(startZ) or 0.0
        local timeToZero = math.max(minFlight, zeroDistance / math.max(1.0, horizontalSpeed))
        local desiredDz = (tonumber(zeroHeightZ) or 0.0) - (tonumber(startZ) or 0.0)
        velocityZ = (desiredDz + (0.5 * gravityZ * timeToZero * timeToZero)) / math.max(0.001, timeToZero)
        velocityZ = math.max(-(speed * 0.30), math.min(speed * 0.30, velocityZ))
    else
        zeroHeightZ = tonumber(startZ) or 0.0
        zeroDistance = 0.0
        local baseLift = math.max(0.02, tonumber(cfg and cfg.arcZ) or 0.18)
        velocityZ = baseLift * math.max(0.85, math.min(1.10, 0.75 + (tensionScale * 0.15)))
        velocityZ = math.max(0.02, math.min(speed * 0.18, velocityZ))
    end

    local baseRange = math.max(5.0, tonumber(cfg.maxTargetDistance) or 55.0)
    local maxTravelDistance = math.max(8.0, baseRange * tensionScale * BOW_BALLISTIC_MAX_RANGE_MULT)

    local maxLifetimeSec = math.max(minFlight, maxTravelDistance / math.max(1.0, horizontalSpeed) + 0.55)
    maxLifetimeSec = math.min(maxLifetimeSec, BOW_BALLISTIC_MAX_LIFETIME_SEC)

    return {
        tensionScale = tensionScale,
        speed = speed,
        velocityX = velocityX,
        velocityY = velocityY,
        velocityZ = velocityZ,
        gravityZ = gravityZ,
        zeroDistance = zeroDistance,
        zeroHeightZ = zeroHeightZ,
        maxTravelDistance = maxTravelDistance,
        maxLifetimeSec = maxLifetimeSec
    }
end

local function clampTargetToRange(playerObj, x, y, z, maxDist)
    local px = playerObj:getX()
    local py = playerObj:getY()
    local dx = x - px
    local dy = y - py
    local dist = math.sqrt(dx * dx + dy * dy)
    maxDist = tonumber(maxDist) or 55.0

    if dist <= maxDist or dist <= 0 then
        return x, y, z, dist
    end

    local scale = maxDist / dist
    return px + dx * scale, py + dy * scale, z, maxDist
end

local function fallbackForwardTarget(playerObj, maxDist)
    local dir = playerObj.getForwardDirection and playerObj:getForwardDirection() or nil
    local fx = playerObj:getX()
    local fy = playerObj:getY()
    if dir and dir.getX and dir.getY then
        fx = fx + dir:getX() * maxDist
        fy = fy + dir:getY() * maxDist
    else
        fy = fy + maxDist
    end
    local fz = playerObj:getZ()
    local cell = getCell and getCell() or nil
    local square = cell and cell.getGridSquare and cell:getGridSquare(floorToGrid(fx), floorToGrid(fy), floorToGrid(fz)) or nil
    return square, maxDist, fx, fy, fz
end

local function getMouseWorldTarget(playerObj)
    if not playerObj then
        return nil, nil, nil
    end

    local pz = playerObj:getZ()
    local playerNum = playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
    local zoom = 1.0
    local core = getCore and getCore() or nil
    if core and core.getZoom then
        local ok, value = pcall(core.getZoom, core, playerNum)
        if ok and tonumber(value) and tonumber(value) > 0 then
            zoom = tonumber(value)
        end
    end

    local rawMouseX = getMouseX and getMouseX() or nil
    local rawMouseY = getMouseY and getMouseY() or nil
    local aimMouseX = rawMouseX
    local aimMouseY = rawMouseY and (rawMouseY + ARCHERY_CURSOR_SCREEN_BIAS_Y) or nil

    if ISCoordConversion and ISCoordConversion.ToWorld then
        local mx = nil
        local my = nil
        if getMouseXScaled and getMouseYScaled then
            mx = getMouseXScaled()
            my = getMouseYScaled()
            if my ~= nil then
                my = my + (ARCHERY_CURSOR_SCREEN_BIAS_Y * zoom)
            end
        end
        if mx == nil or my == nil then
            mx = aimMouseX
            my = aimMouseY
        end
        if mx ~= nil and my ~= nil then
            local ok, wx, wy = pcall(ISCoordConversion.ToWorld, mx, my, pz)
            if ok and tonumber(wx) and tonumber(wy) then
                return tonumber(wx), tonumber(wy), tonumber(pz)
            end
        end
    end

    if aimMouseX == nil or aimMouseY == nil or not (IsoUtils and IsoUtils.XToIso and IsoUtils.YToIso) then
        return nil, nil, nil
    end

    local worldX = IsoUtils.XToIso(aimMouseX * zoom, aimMouseY * zoom, pz)
    local worldY = IsoUtils.YToIso(aimMouseX * zoom, aimMouseY * zoom, pz)
    if worldX == nil or worldY == nil then
        return nil, nil, nil
    end

    return tonumber(worldX), tonumber(worldY), tonumber(pz)
end

local function findAimZombieNearCursor(worldX, worldY, baseZ)
    if worldX == nil or worldY == nil then
        return nil
    end

    local bestZombie = nil
    local bestDist = nil
    local zBase = math.floor(tonumber(baseZ) or 0)
    for z = zBase - 1, zBase + 1 do
        local zombie, dist = findNearestZombieAtImpact(worldX, worldY, z, ARCHERY_CURSOR_ZOMBIE_RADIUS)
        if zombie and (not bestDist or (tonumber(dist) or 9999) < bestDist) then
            bestZombie = zombie
            bestDist = tonumber(dist) or bestDist
        end
    end

    return bestZombie
end

local function pickAimTarget(playerObj, cfg)
    if not playerObj then
        return nil, 0, nil, nil, nil, nil, nil, nil
    end

    local maxDist = tonumber(cfg and cfg.maxTargetDistance) or 55.0
    local worldX, worldY, worldZ = getMouseWorldTarget(playerObj)
    if worldX == nil or worldY == nil then
        local fallbackSquare, fallbackDist, fx, fy, fz = fallbackForwardTarget(playerObj, maxDist)
        if not fallbackSquare then
            return nil, fallbackDist or 0, nil, nil, nil, nil, nil, "fallback_forward"
        end
        local targetZ = getGroundAimTargetZ(
            cfg,
            tonumber(fx) or (fallbackSquare:getX() + 0.5),
            tonumber(fy) or (fallbackSquare:getY() + 0.5),
            fallbackSquare:getZ() or fz or playerObj:getZ()
        )
        return fallbackSquare, fallbackDist or 0, tonumber(fx) or (fallbackSquare:getX() + 0.5), tonumber(fy) or (fallbackSquare:getY() + 0.5), targetZ, nil, nil, "fallback_forward"
    end

    local cx, cy, cz, dist = clampTargetToRange(playerObj, worldX, worldY, worldZ, maxDist)
    cx = (tonumber(cx) or 0.0) + ARCHERY_AIM_WORLD_BIAS_X
    cy = (tonumber(cy) or 0.0) + ARCHERY_AIM_WORLD_BIAS_Y
    cx, cy, cz, dist = clampTargetToRange(playerObj, cx, cy, cz, maxDist)

    local cell = getCell and getCell() or nil
    local targetZombie = findAimZombieNearCursor(cx, cy, cz)

    local square = cell and cell.getGridSquare and cell:getGridSquare(floorToGrid(cx), floorToGrid(cy), floorToGrid(cz)) or nil
    if not square then
        square = playerObj.getSquare and playerObj:getSquare() or nil
        if not square then
            local fallbackSquare, fallbackDist, fx, fy, fz = fallbackForwardTarget(playerObj, maxDist)
            if not fallbackSquare then
                return nil, fallbackDist or 0, nil, nil, nil, nil, nil, "fallback_forward"
            end
            local targetZ = getGroundAimTargetZ(
                cfg,
                tonumber(fx) or (fallbackSquare:getX() + 0.5),
                tonumber(fy) or (fallbackSquare:getY() + 0.5),
                fallbackSquare:getZ() or fz or playerObj:getZ()
            )
            return fallbackSquare, fallbackDist or 0, tonumber(fx) or (fallbackSquare:getX() + 0.5), tonumber(fy) or (fallbackSquare:getY() + 0.5), targetZ, nil, nil, "fallback_forward"
        end
    end

    local tx = tonumber(cx) or (square:getX() + 0.5)
    local ty = tonumber(cy) or (square:getY() + 0.5)
    local tz = getGroundAimTargetZ(cfg, tx, ty, tonumber(square:getZ()) or tonumber(cz) or playerObj:getZ())
    local aimMode = targetZombie and (ARCHERY_AIM_MODE_IMPACT_SQUARE .. "_zombie_hint") or ARCHERY_AIM_MODE_IMPACT_SQUARE
    return square, dist, tx, ty, tz, nil, targetZombie, aimMode
end

local function queueArrowProjectileFx(playerObj, weapon, cfg)
    local square, dist, targetX, targetY, targetZ, targetZombie, targetZombieHint, aimMode = pickAimTarget(playerObj, cfg)
    if not square then
        logArrowFx("target square missing")
        return
    end

    local dir = playerObj.getForwardDirection and playerObj:getForwardDirection() or nil
    local startX = playerObj:getX()
    local startY = playerObj:getY()
    local startZ = playerObj:getZ() + (tonumber(cfg.startZBias) or 0.72)
    local dirX, dirY = 0.0, 1.0
    if dir and dir.getX and dir.getY then
        dirX = tonumber(dir:getX()) or 0.0
        dirY = tonumber(dir:getY()) or 1.0
        startX = startX + dirX * 0.45
        startY = startY + dirY * 0.45
    else
        startY = startY + 0.45
    end

    local ammoType = resolveBowArrowAmmoType(weapon, cfg)
    local arrowStats = resolveArrowStats(ammoType, cfg)
    startX, startY, startZ = applyBowMuzzleAttachmentOffset(playerObj, weapon, cfg, startX, startY, startZ, dirX, dirY)

    targetX = tonumber(targetX) or (square:getX() + 0.5)
    targetY = tonumber(targetY) or (square:getY() + 0.5)
    targetZ = tonumber(targetZ) or getGroundAimTargetZ(cfg, targetX, targetY, square:getZ())
    local ballistic = computeBallisticParams(weapon, cfg, startX, startY, startZ, targetX, targetY, targetZ, targetZombie)
    local flightTime = ballistic.maxLifetimeSec
    local createdAt = nowMs()
    local impactDamage = computeBowImpactDamage(weapon, arrowStats, cfg)
    local tensionPower = resolveBowTensionPower(weapon)
    local baseImpactImpulse = (arrowStats and tonumber(arrowStats.impactImpulse)) or BOW_IMPACT_KNOCKBACK_XY
    local impactImpulseXY = math.max(0.05, baseImpactImpulse * (0.65 + (tensionPower * 0.012)))
    local impactImpulseZ = math.max(0.05, impactImpulseXY * 0.24)
    local visualItemType = normalizeFullType(arrowStats and arrowStats.flightVisualItemType)
        or normalizeFullType(cfg and cfg.defaultFlightVisualItem)
        or normalizeRecoverableArcheryAmmoType(ammoType)

    local visual = createArrowFxVisualAt(
        startX,
        startY,
        startZ,
        visualItemType,
        cfg,
        arrowStats and arrowStats.flightVisualZOffset,
        arrowStats and arrowStats.flightRenderZBias
    )
    if not visual then
        logArrowFx("visual spawn failed item=%s", tostring(visualItemType))
        return
    end

    visual.mode = visual.mode or "world"
    visual.startX = startX
    visual.startY = startY
    visual.startZ = startZ
    visual.targetX = targetX
    visual.targetY = targetY
    visual.targetZ = targetZ
    visual.impactSquareX = square.getX and square:getX() or nil
    visual.impactSquareY = square.getY and square:getY() or nil
    visual.impactSquareZ = square.getZ and square:getZ() or nil
    visual.aimMode = tostring(aimMode or ARCHERY_AIM_MODE_IMPACT_SQUARE)
    visual.createdAtMs = createdAt
    visual.flightMs = math.max(1, math.floor(flightTime * 1000))
    visual.maxLifetimeSec = flightTime
    visual.worldOzMax = tonumber(cfg.worldOzMax) or 0.95
    visual.weaponType = getWeaponFullType(weapon)
    visual.weapon = weapon
    visual.attacker = playerObj
    visual.ammoType = ammoType
    visual.arrowStats = arrowStats
    visual.flightYawOffset = (arrowStats and tonumber(arrowStats.flightYawOffset)) or 0.0
    visual.flightVisualZOffset = (arrowStats and tonumber(arrowStats.flightVisualZOffset)) or 0.0
    visual.flightRenderZBias = (arrowStats and tonumber(arrowStats.flightRenderZBias)) or ARCHERY_PROJECTILE_VISUAL_Z_BIAS
    visual.impactDamage = impactDamage
    visual.impactDamageRadius = tonumber(cfg.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS
    visual.impactImpulseXY = impactImpulseXY
    visual.impactImpulseZ = impactImpulseZ
    visual.prevX = startX
    visual.prevY = startY
    visual.prevZ = startZ
    visual.simX = startX
    visual.simY = startY
    visual.simZ = startZ
    visual.velocityX = ballistic.velocityX
    visual.velocityY = ballistic.velocityY
    visual.velocityZ = ballistic.velocityZ
    visual.gravityZ = ballistic.gravityZ
    visual.travelDistance = 0.0
    visual.maxTravelDistance = ballistic.maxTravelDistance
    visual.elapsedSec = 0.0
    visual.lastUpdateMs = createdAt
    visual.tensionScale = ballistic.tensionScale
    visual.baseFloorZ = square:getZ()
    visual.dropStartRange = math.max(0.0, tonumber(getScriptPropertyNumberWithFallback(weapon, "ArrowDropStartRange", cfg.dropStartRange or 14.0)) or 14.0)
    visual.dropPerTile = math.max(0.0, tonumber(getScriptPropertyNumberWithFallback(weapon, "ArrowDropPerTile", cfg.dropPerTile or 0.065)) or 0.065)
    visual.groundImpactEpsilon = math.max(0.0, tonumber(getScriptPropertyNumberWithFallback(weapon, "ArrowGroundImpactEpsilon", cfg.groundImpactEpsilon or BOW_GROUND_IMPACT_EPSILON)) or BOW_GROUND_IMPACT_EPSILON)
    visual.targetZombie = targetZombie
    visual.targetZombieHint = targetZombieHint
    table.insert(activeArrowFx, visual)

    do
        local startVx = ballistic.velocityX
        local startVy = ballistic.velocityY
        local yawDeg = computeArrowYawDeg(startVx, startVy, visual.flightYawOffset)
        if yawDeg ~= nil then
            setArrowWorldRotation(visual.worldObj, visual.renderItem or visual.worldItem, yawDeg)
            visual.renderRotation = yawDeg
        end
    end

    do
        local runtime = rawget(_G, "GGS_ArcheryRuntime")
        if runtime and runtime.onProjectileFired then
            pcall(runtime.onProjectileFired, playerObj, weapon, ammoType)
        end
    end

    if not (isClient and isClient()) then
        suppressBowDamageUntilImpact(weapon, visual.flightMs + BOW_DAMAGE_RESTORE_GRACE_MS)
    end

    logArrowFx("queued weapon=%s item=%s aim=%s square=%s dist=%.2f bias=%.2f,%.2f start=%.2f,%.2f,%.2f target=%.2f,%.2f,%.2f v=%.2f,%.2f,%.2f g=%.3f zero=%.2f life=%.2f zombieHint=%s",
        tostring(visual.weaponType), tostring(visualItemType), tostring(visual.aimMode), describeArrowSquareDebug(square), tonumber(dist) or 0, ARCHERY_AIM_WORLD_BIAS_X, ARCHERY_AIM_WORLD_BIAS_Y,
        startX, startY, startZ, targetX, targetY, targetZ,
        ballistic.velocityX, ballistic.velocityY, ballistic.velocityZ, ballistic.gravityZ,
        tonumber(ballistic.zeroDistance) or 0.0, flightTime, describeArrowZombieDebug(targetZombieHint))
end

local function updateArrowProjectileFx()
    if #activeArrowFx == 0 then
        return
    end

    local currentMs = nowMs()
    for i = #activeArrowFx, 1, -1 do
        local entry = activeArrowFx[i]
        local deltaMs = currentMs - (tonumber(entry.lastUpdateMs) or currentMs)
        local deltaSec = deltaMs / 1000.0
        if deltaSec <= 0 then
            deltaSec = BOW_BALLISTIC_FIXED_STEP_SEC
        end
        if deltaSec > BOW_BALLISTIC_MAX_DELTA_SEC then
            deltaSec = BOW_BALLISTIC_MAX_DELTA_SEC
        end
        entry.lastUpdateMs = currentMs

        local removeEntry = false
        local remainingSec = deltaSec
        while (remainingSec > 0.0001) and (not removeEntry) do
            local stepSec = math.min(BOW_BALLISTIC_FIXED_STEP_SEC, remainingSec)
            remainingSec = remainingSec - stepSec

            local segStartX = tonumber(entry.simX) or tonumber(entry.prevX) or tonumber(entry.startX) or 0.0
            local segStartY = tonumber(entry.simY) or tonumber(entry.prevY) or tonumber(entry.startY) or 0.0
            local segStartZ = tonumber(entry.simZ) or tonumber(entry.prevZ) or tonumber(entry.startZ) or 0.0

            local velX = tonumber(entry.velocityX) or 0.0
            local velY = tonumber(entry.velocityY) or 0.0
            local velZ = tonumber(entry.velocityZ) or 0.0
            local gravityZ = tonumber(entry.gravityZ) or BOW_BALLISTIC_MIN_GRAVITY

            velZ = velZ - (gravityZ * stepSec)
            local px = segStartX + (velX * stepSec)
            local py = segStartY + (velY * stepSec)
            local pz = segStartZ + (velZ * stepSec)

            entry.velocityZ = velZ
            entry.elapsedSec = (tonumber(entry.elapsedSec) or 0.0) + stepSec
            entry.travelDistance = (tonumber(entry.travelDistance) or 0.0) + distance2D(segStartX, segStartY, px, py)

            local hitKind, hitZombie, hitX, hitY, hitZ = resolveSegmentZombieOrWallHit(
                segStartX,
                segStartY,
                segStartZ,
                px, py, pz,
                tonumber(entry.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS
            )
            if hitKind == "zombie" and hitZombie then
                entry.lastImpactReason = "segment_zombie"
                logArrowFx(
                    "segment direct zombie hit weapon=%s ammo=%s reason=%s point=%.2f,%.2f,%.2f zombie=%s",
                    tostring(entry.weaponType),
                    tostring(entry.ammoType),
                    tostring(entry.lastImpactReason),
                    tonumber(hitX) or tonumber(px) or 0,
                    tonumber(hitY) or tonumber(py) or 0,
                    tonumber(hitZ) or tonumber(pz) or 0,
                    describeArrowZombieDebug(hitZombie)
                )
                pcall(applyArrowImpactDamage, entry, hitZombie, hitX, hitY, hitZ, segStartX, segStartY, segStartZ)
                removeEntry = true
                break
            elseif hitKind == "wall" then
                entry.lastImpactReason = "segment_wall"
                local wallZombie = findNearestZombieAtImpact(
                    hitX,
                    hitY,
                    math.floor(tonumber(hitZ) or 0),
                    tonumber(entry.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS
                )
                if wallZombie then
                    entry.lastImpactReason = "segment_wall_zombie"
                    logArrowFx(
                        "segment wall intercept promoted to zombie weapon=%s ammo=%s point=%.2f,%.2f,%.2f zombie=%s",
                        tostring(entry.weaponType),
                        tostring(entry.ammoType),
                        tonumber(hitX) or 0,
                        tonumber(hitY) or 0,
                        tonumber(hitZ) or 0,
                        describeArrowZombieDebug(wallZombie)
                    )
                    pcall(applyArrowImpactDamage, entry, wallZombie, hitX, hitY, hitZ, segStartX, segStartY, segStartZ)
                else
                    logArrowFx(
                        "segment wall impact world weapon=%s ammo=%s point=%.2f,%.2f,%.2f",
                        tostring(entry.weaponType),
                        tostring(entry.ammoType),
                        tonumber(hitX) or 0,
                        tonumber(hitY) or 0,
                        tonumber(hitZ) or 0
                    )
                    pcall(spawnWallArrowAtImpact, entry, hitX, hitY, hitZ, velX, velY)
                end
                removeEntry = true
                break
            end

            local groundImpactZ = getGroundImpactZAt(entry, px, py, pz)
            if pz <= groundImpactZ then
                entry.lastImpactReason = "ground"
                local groundZombie = findNearestZombieAtImpact(
                    px,
                    py,
                    math.floor(tonumber(groundImpactZ) or 0),
                    tonumber(entry.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS
                )
                if groundZombie then
                    entry.lastImpactReason = "ground_zombie"
                    logArrowFx(
                        "ground impact promoted to zombie weapon=%s ammo=%s point=%.2f,%.2f,%.2f zombie=%s",
                        tostring(entry.weaponType),
                        tostring(entry.ammoType),
                        tonumber(px) or 0,
                        tonumber(py) or 0,
                        tonumber(groundImpactZ) or 0,
                        describeArrowZombieDebug(groundZombie)
                    )
                    pcall(applyArrowImpactDamage, entry, groundZombie, px, py, groundImpactZ, segStartX, segStartY, segStartZ)
                else
                    logArrowFx(
                        "ground impact world weapon=%s ammo=%s point=%.2f,%.2f,%.2f",
                        tostring(entry.weaponType),
                        tostring(entry.ammoType),
                        tonumber(px) or 0,
                        tonumber(py) or 0,
                        tonumber(groundImpactZ) or 0
                    )
                    pcall(spawnFloorArrowAtImpact, entry, px, py, groundImpactZ)
                end
                removeEntry = true
                break
            end

            if (tonumber(entry.travelDistance) or 0.0) >= (tonumber(entry.maxTravelDistance) or math.huge) then
                entry.lastImpactReason = "range_limit"
                local rangeZombie = findNearestZombieAtImpact(
                    px,
                    py,
                    math.floor(tonumber(groundImpactZ) or 0),
                    tonumber(entry.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS
                )
                if rangeZombie then
                    entry.lastImpactReason = "range_limit_zombie"
                    pcall(applyArrowImpactDamage, entry, rangeZombie, px, py, groundImpactZ, segStartX, segStartY, segStartZ)
                else
                    logArrowFx(
                        "range limit world weapon=%s ammo=%s point=%.2f,%.2f,%.2f",
                        tostring(entry.weaponType),
                        tostring(entry.ammoType),
                        tonumber(px) or 0,
                        tonumber(py) or 0,
                        tonumber(groundImpactZ) or 0
                    )
                    pcall(spawnFloorArrowAtImpact, entry, px, py, groundImpactZ)
                end
                removeEntry = true
                break
            end

            if (tonumber(entry.elapsedSec) or 0.0) >= (tonumber(entry.maxLifetimeSec) or math.huge) then
                entry.lastImpactReason = "lifetime"
                local applied = false
                local ok, result = pcall(applyArrowImpactDamage, entry, nil, px, py, pz, segStartX, segStartY, segStartZ)
                if ok and result then
                    applied = true
                end
                if not applied then
                    logArrowFx(
                        "lifetime expiry world weapon=%s ammo=%s point=%.2f,%.2f,%.2f",
                        tostring(entry.weaponType),
                        tostring(entry.ammoType),
                        tonumber(px) or 0,
                        tonumber(py) or 0,
                        tonumber(groundImpactZ) or 0
                    )
                    pcall(spawnFloorArrowAtImpact, entry, px, py, groundImpactZ)
                end
                removeEntry = true
                break
            end

            local moved = moveArrowFxVisual(entry, px, py, pz, velX, velY)
            if not moved then
                local fallbackGroundZ = getGroundImpactZAt(entry, segStartX, segStartY, segStartZ)
                if segStartZ <= (fallbackGroundZ + 0.05) then
                    pcall(spawnFloorArrowAtImpact, entry, segStartX, segStartY, fallbackGroundZ)
                else
                    pcall(spawnWallArrowAtImpact, entry, segStartX, segStartY, segStartZ, velX, velY)
                end
                removeEntry = true
                break
            end

            entry.prevX = px
            entry.prevY = py
            entry.prevZ = pz
            entry.simX = px
            entry.simY = py
            entry.simZ = pz
        end

        if removeEntry then
            removeArrowFxVisual(entry)
            table.remove(activeArrowFx, i)
        end
    end
end

local function clearArcheryImpactPointCache()
    archeryImpactPointCache.visible = false
    archeryImpactPointCache.worldX = nil
    archeryImpactPointCache.worldY = nil
    archeryImpactPointCache.worldZ = nil
    archeryImpactPointCache.screenX = nil
    archeryImpactPointCache.screenY = nil
end

local function getLocalAimingArcheryContext()
    for playerIndex = 0, 3 do
        local playerObj = getSpecificPlayer and getSpecificPlayer(playerIndex) or nil
        if playerObj and playerObj:isAiming() and (not playerObj:isDead()) then
            local weapon = playerObj:getPrimaryHandItem()
            if weapon then
                local weaponType = getWeaponFullType(weapon)
                local cfg = ARROW_FX_BY_WEAPON[weaponType]
                if cfg and ((not weapon.getCurrentAmmoCount) or weapon:getCurrentAmmoCount() > 0) then
                    return playerObj, weapon, cfg
                end
            end
        end
    end
    return nil, nil, nil
end

local function computeProjectileStart(playerObj, weapon, cfg)
    local dir = playerObj.getForwardDirection and playerObj:getForwardDirection() or nil
    local startX = playerObj:getX()
    local startY = playerObj:getY()
    local startZ = playerObj:getZ() + (tonumber(cfg.startZBias) or 0.72)
    local dirX, dirY = 0.0, 1.0

    if dir and dir.getX and dir.getY then
        dirX = tonumber(dir:getX()) or 0.0
        dirY = tonumber(dir:getY()) or 1.0
        startX = startX + dirX * 0.45
        startY = startY + dirY * 0.45
    else
        startY = startY + 0.45
    end

    startX, startY, startZ = applyBowMuzzleAttachmentOffset(playerObj, weapon, cfg, startX, startY, startZ, dirX, dirY)
    return startX, startY, startZ
end

local function predictAimImpactPoint(playerObj, weapon, cfg)
    local square, _, targetX, targetY, targetZ = pickAimTarget(playerObj, cfg)
    if not square then
        return nil, nil, nil
    end

    local startX, startY, startZ = computeProjectileStart(playerObj, weapon, cfg)
    local ballistic = computeBallisticParams(weapon, cfg, startX, startY, startZ, targetX, targetY, targetZ, nil)

    local simX, simY, simZ = startX, startY, startZ
    local velX, velY, velZ = ballistic.velocityX, ballistic.velocityY, ballistic.velocityZ
    local elapsedSec = 0.0
    local travelDist = 0.0
    local tempEntry = {
        baseFloorZ = square:getZ(),
        groundImpactEpsilon = math.max(0.0, tonumber(getScriptPropertyNumberWithFallback(weapon, "ArrowGroundImpactEpsilon", cfg.groundImpactEpsilon or BOW_GROUND_IMPACT_EPSILON)) or BOW_GROUND_IMPACT_EPSILON)
    }
    local impactRadius = tonumber(cfg.impactDamageRadius) or BOW_IMPACT_DAMAGE_RADIUS

    while elapsedSec < ballistic.maxLifetimeSec and travelDist < ballistic.maxTravelDistance do
        local stepSec = BOW_BALLISTIC_FIXED_STEP_SEC
        local segStartX, segStartY, segStartZ = simX, simY, simZ

        velZ = velZ - (ballistic.gravityZ * stepSec)
        local px = segStartX + (velX * stepSec)
        local py = segStartY + (velY * stepSec)
        local pz = segStartZ + (velZ * stepSec)

        local hitKind, hitZombie, hitX, hitY, hitZ = resolveSegmentZombieOrWallHit(
            segStartX,
            segStartY,
            segStartZ,
            px, py, pz,
            impactRadius
        )
        if hitKind == "wall" then
            return hitX, hitY, hitZ
        end
        if hitKind == "zombie" and hitZombie then
            return hitX or px, hitY or py, hitZ or pz
        end

        local groundImpactZ = getGroundImpactZAt(tempEntry, px, py, pz)
        if pz <= groundImpactZ then
            return px, py, groundImpactZ
        end

        travelDist = travelDist + distance2D(segStartX, segStartY, px, py)
        if travelDist >= ballistic.maxTravelDistance then
            return px, py, groundImpactZ
        end

        simX, simY, simZ = px, py, pz
        elapsedSec = elapsedSec + stepSec
    end

    local fallbackGroundZ = getGroundImpactZAt(tempEntry, simX, simY, simZ)
    return simX, simY, fallbackGroundZ
end

local function worldToScreenPoint(wx, wy, wz)
    if wx == nil or wy == nil or wz == nil then
        return nil, nil
    end

    if ISCoordConversion and ISCoordConversion.ToScreen then
        local ok, sx, sy = pcall(ISCoordConversion.ToScreen, wx, wy, wz)
        if ok and tonumber(sx) and tonumber(sy) then
            return tonumber(sx), tonumber(sy)
        end
    end

    if IsoUtils and IsoUtils.XToScreen and IsoUtils.YToScreen then
        local sx = IsoUtils.XToScreen(wx, wy, wz, 0) - (getCameraOffX and getCameraOffX() or 0)
        local sy = IsoUtils.YToScreen(wx, wy, wz, 0) - (getCameraOffY and getCameraOffY() or 0)
        if tonumber(sx) and tonumber(sy) then
            return tonumber(sx), tonumber(sy)
        end
    end

    return nil, nil
end

local function refreshArcheryImpactPointCache()
    if not ENABLE_ARCHERY_IMPACT_POINT then
        clearArcheryImpactPointCache()
        return
    end

    local playerObj, weapon, cfg = getLocalAimingArcheryContext()
    if not (playerObj and weapon and cfg) then
        clearArcheryImpactPointCache()
        return
    end

    local now = nowMs()
    if archeryImpactPointCache.visible and now < (tonumber(archeryImpactPointCache.nextRefreshMs) or 0) then
        return
    end

    local wx, wy, wz = predictAimImpactPoint(playerObj, weapon, cfg)
    if wx == nil or wy == nil or wz == nil then
        clearArcheryImpactPointCache()
        archeryImpactPointCache.nextRefreshMs = now + ARCHERY_IMPACT_POINT_UPDATE_MS
        return
    end

    local sx, sy = worldToScreenPoint(wx, wy, wz)
    if sx == nil or sy == nil then
        clearArcheryImpactPointCache()
        archeryImpactPointCache.nextRefreshMs = now + ARCHERY_IMPACT_POINT_UPDATE_MS
        return
    end

    archeryImpactPointCache.worldX = wx
    archeryImpactPointCache.worldY = wy
    archeryImpactPointCache.worldZ = wz
    archeryImpactPointCache.screenX = sx
    archeryImpactPointCache.screenY = sy
    archeryImpactPointCache.visible = true
    archeryImpactPointCache.nextRefreshMs = now + ARCHERY_IMPACT_POINT_UPDATE_MS
end

local function drawArcheryImpactPoint()
    if not ENABLE_ARCHERY_IMPACT_POINT then
        return
    end

    refreshArcheryImpactPointCache()
    if not archeryImpactPointCache.visible then
        return
    end

    local textManager = getTextManager and getTextManager() or nil
    if not textManager then
        return
    end

    local sx = tonumber(archeryImpactPointCache.screenX)
    local sy = tonumber(archeryImpactPointCache.screenY)
    if sx == nil or sy == nil then
        return
    end

    textManager:DrawStringCentre(UIFont.Small, sx + 1, sy + 1, ARCHERY_IMPACT_POINT_GLYPH, 0.0, 0.0, 0.0, 0.85)
    textManager:DrawStringCentre(UIFont.Small, sx, sy, ARCHERY_IMPACT_POINT_GLYPH, 1.0, 0.25, 0.25, 0.95)
end

local function onPostUIDrawArcheryImpactPoint()
    drawArcheryImpactPoint()
end

local function queueArrowFromEventArgs(a, b, c, d, e, f)
    local character, weapon = extractCharacterAndWeaponFromArgs(a, b, c, d, e, f)
    if not (character and weapon) then
        return
    end
    if not isLocalCharacter(character) then
        return
    end

    local weaponType = getWeaponFullType(weapon)
    local cfg = ARROW_FX_BY_WEAPON[weaponType]
    if not cfg then
        return
    end

    if weapon.getCurrentAmmoCount and weapon:getCurrentAmmoCount() <= 0 then
        return
    end

    -- En SP usamos dano custom al impacto. En MP dejar el dano vanilla activo
    -- para que el hit del servidor aplique sangre/reaccion correctamente.
    if not (isClient and isClient()) then
        suppressBowDamageUntilImpact(weapon, 350)
    end

    local ms = nowMs()
    if (ms - lastLocalBowSwingMs) < BOW_SWING_DEBOUNCE_MS then
        return
    end
    lastLocalBowSwingMs = ms

    queueArrowProjectileFx(character, weapon, cfg)
end

local function onWeaponSwingArrowFx(character, weapon)
    queueArrowFromEventArgs(character, weapon)
end

local function onWeaponSwingHitPointArrowFx(a, b, c, d, e, f)
    queueArrowFromEventArgs(a, b, c, d, e, f)
end

local function onTickArrowFx()
    updateSuppressedBowDamage()
    updateArrowProjectileFx()
end

local function registerArrowFxHandlers()
    if handlersRegistered then
        return
    end
    if Events and Events.OnWeaponSwing and Events.OnWeaponSwing.Add then
        Events.OnWeaponSwing.Add(onWeaponSwingArrowFx)
    end
    if Events and Events.OnWeaponSwingHitPoint and Events.OnWeaponSwingHitPoint.Add then
        Events.OnWeaponSwingHitPoint.Add(onWeaponSwingHitPointArrowFx)
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(onTickArrowFx)
    end
    if Events and Events.RenderOpaqueObjectsInWorld and Events.RenderOpaqueObjectsInWorld.Add then
        Events.RenderOpaqueObjectsInWorld.Add(renderArrowFxVisuals)
    end
    if Events and Events.OnPostUIDraw and Events.OnPostUIDraw.Add then
        Events.OnPostUIDraw.Add(onPostUIDrawArcheryImpactPoint)
    end
    if Events and Events.OnServerCommand and Events.OnServerCommand.Add then
        Events.OnServerCommand.Add(onServerCommand)
    end
    handlersRegistered = true
    logArrowFx("handlers registered")
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(registerArrowFxHandlers)
end
if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(registerArrowFxHandlers)
end

registerArrowFxHandlers()
