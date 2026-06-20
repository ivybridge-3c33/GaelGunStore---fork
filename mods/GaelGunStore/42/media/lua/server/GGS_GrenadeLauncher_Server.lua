if not isServer() then
    return
end

local MODULE_NAME = "GGS_GL"
local COMMAND_FIRE = "Fire"
local COMMAND_LOAD = "Load"
local COMMAND_UNLOAD = "Unload"
local COMMAND_STANDALONE_STATE = "StandaloneState"
local COMMAND_EXPLOSION_FX = "ExplosionFX"
local COMMAND_PROJECTILE_FX = "ProjectileFX"

local DEBUG_GL = false
local MAX_TARGET_DISTANCE = 24.0
local FIRE_EXPLOSION_POWER_SCALE = 0.0625
local DAMAGE_POWER_SCALE = 0.25
local BLAST_DAMAGE_RADIUS_SCALE = 0.12
local BLAST_DAMAGE_MIN_RADIUS = 3.0
local BLAST_DAMAGE_MAX_RADIUS = 6.9
local BLAST_DAMAGE_SCALE = 3.60
local BLAST_DAMAGE_MIN = 0.45
local BLAST_DAMAGE_MAX = 3.60
local SMOKE_ENABLED = true
local SMOKE_LIFE_MIN = 300
local SMOKE_LIFE_MAX = 480
local SMOKE_START_ENERGY = 100
local PROJECTILE_ENABLED = true
local PROJECTILE_SPEED_TILES_PER_SEC = 15.0
local PROJECTILE_MIN_FLIGHT_TIME = 0.18
local PROJECTILE_MAX_FLIGHT_TIME = 1.40
local MODDATA_SELECTED_AMMO = "ggsGLSelectedAmmoType"
local MODDATA_LOADED_AMMO = "ggsGLLoadedAmmoType"
local MODDATA_STANDALONE_AMMO_COUNT = "ggsGLStandaloneAmmoCount"
local AMMO_PART_SLOT = "Ammo"
local AMMO_CONTROLLER_PART_FULLTYPE = "Base.GGS_GL_AmmoController"

local LAUNCHER_PROFILE_BY_FULLTYPE = {
    ["Base.GP30_GL"] = {
        loadedType = "Base.GP30_GL",
        emptyType = "Base.GP30_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100
    },
    ["Base.GP30_GL_empty"] = {
        loadedType = "Base.GP30_GL",
        emptyType = "Base.GP30_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100
    },
    ["Base.M203_GL"] = {
        loadedType = "Base.M203_GL",
        emptyType = "Base.M203_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100
    },
    ["Base.M203_GL_empty"] = {
        loadedType = "Base.M203_GL",
        emptyType = "Base.M203_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100
    },
    ["Base.M320_GL"] = {
        loadedType = "Base.M320_GL",
        emptyType = "Base.M320_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100
    },
    ["Base.M320_GL_empty"] = {
        loadedType = "Base.M320_GL",
        emptyType = "Base.M320_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100
    },
    ["Base.Scar_GL"] = {
        loadedType = "Base.Scar_GL",
        emptyType = "Base.Scar_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100
    },
    ["Base.Scar_GL_empty"] = {
        loadedType = "Base.Scar_GL",
        emptyType = "Base.Scar_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100
    }
}

local STANDALONE_LAUNCHER_PROFILE_BY_WEAPON = {
    ["Base.M79"] = {
        id = "M79",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        useStandaloneAmmoCount = true,
        capacity = 1
    },
    ["Base.GM94"] = {
        id = "GM94",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        useStandaloneAmmoCount = true,
        capacity = 3
    },
    ["Base.MLG"] = {
        id = "MLG",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        useStandaloneAmmoCount = true,
        capacity = 6
    },
    ["Base.RG6"] = {
        id = "RG6",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        useStandaloneAmmoCount = true,
        capacity = 6
    },
    ["Base.ChinaLake"] = {
        id = "ChinaLake",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        useStandaloneAmmoCount = true,
        capacity = 3
    },
    ["Base.RPG7"] = {
        id = "RPG7",
        ammoType = "Base.RPG7_RocketAmmo",
        explosionPower = 140,
        useStandaloneAmmoCount = true,
        capacity = 1
    }
}

local GL_AMMO_PAYLOAD_BY_FULLTYPE = {
    ["Base.GrenadeAmmo"] = {
        id = "40mm_HE",
        explosionPower = 100,
        explosionSound = "PipeBombExplode",
        damageWeaponType = "Base.HE_explosion",
        groundFire = false,
        damageRadius = 4.0,
        lethalRadius = 1.25,
        maxDamage = 120,
        minDamage = 18,
        trapProxyMode = "tick1",
        trapProxyTimer = 1,
        trapProxyCleanupTTL = 1.50,
        physicsBlastPowerScale = 1.00
    },
    ["Base.GrenadeAmmo_incendiary"] = {
        id = "40mm_Incendiary",
        explosionPower = 90,
        explosionSound = "PipeBombExplode",
        damageWeaponType = "Base.HE_explosion",
        groundFire = true,
        damageRadius = 3.4,
        lethalRadius = 0.80,
        maxDamage = 42,
        minDamage = 8,
        trapProxyMode = "tick1",
        trapProxyTimer = 1,
        trapProxyCleanupTTL = 1.50,
        physicsBlastPowerScale = 1.00,
        firePowerScale = 0.10,
        damagePowerScale = 0.20
    },
    ["Base.RPG7_RocketAmmo"] = {
        id = "RPG7_HE",
        explosionPower = 140,
        explosionSound = "PipeBombExplode",
        damageWeaponType = "Base.Rocket_explosion",
        groundFire = false,
        damageRadius = 4.8,
        lethalRadius = 1.70,
        maxDamage = 180,
        minDamage = 28,
        trapProxyMode = "tick1",
        trapProxyTimer = 1,
        trapProxyCleanupTTL = 1.50,
        physicsBlastPowerScale = 1.10,
        firePowerScale = 0.08,
        damagePowerScale = 0.30
    }
}

local pendingImpacts = {}
local activeTrapProxyCleanups = {}
local distance2D = nil

local function logGL(fmt, ...)
    if not DEBUG_GL then
        return
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if ok then
        print("[GGS GLDBG][server] " .. msg)
    else
        print("[GGS GLDBG][server] " .. tostring(fmt))
    end
end

logGL("Server grenade launcher module loaded")

local function normalizeFullType(fullType)
    if not fullType then
        return nil
    end
    fullType = tostring(fullType)
    if fullType:sub(1, 10) == "Base.Base." then
        fullType = "Base." .. fullType:sub(11)
    end
    if fullType:find(".", 1, true) then
        return fullType
    end
    return "Base." .. fullType
end

local function resolveImpactPayload(ammoType, profile)
    local normalizedAmmo = normalizeFullType(ammoType) or normalizeFullType(profile and profile.ammoType) or "Base.GrenadeAmmo"
    local payload = GL_AMMO_PAYLOAD_BY_FULLTYPE[normalizedAmmo] or nil
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100

    return {
        ammoType = normalizedAmmo,
        id = tostring(payload and payload.id or normalizedAmmo),
        explosionPower = basePower,
        explosionSound = tostring(payload and payload.explosionSound or "PipeBombExplode"),
        damageWeaponType = normalizeFullType(payload and payload.damageWeaponType) or "Base.PipeBomb",
        groundFire = payload and payload.groundFire == true,
        damageRadius = tonumber(payload and payload.damageRadius),
        lethalRadius = tonumber(payload and payload.lethalRadius),
        maxDamage = tonumber(payload and payload.maxDamage),
        minDamage = tonumber(payload and payload.minDamage),
        trapProxyMode = tostring(payload and payload.trapProxyMode or ""),
        trapProxyTimer = tonumber(payload and payload.trapProxyTimer),
        trapProxyCleanupTTL = tonumber(payload and payload.trapProxyCleanupTTL) or 1.50,
        physicsBlastPowerScale = tonumber(payload and payload.physicsBlastPowerScale) or 1.0,
        firePowerScale = tonumber(payload and payload.firePowerScale) or FIRE_EXPLOSION_POWER_SCALE,
        damagePowerScale = tonumber(payload and payload.damagePowerScale) or DAMAGE_POWER_SCALE
    }
end

local function roundToGrid(value)
    if not value then
        return 0
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
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

local function resolveProjectileImpactSquare(startX, startY, startZ, targetSquare)
    if not targetSquare then
        return nil, 0
    end

    local tx = targetSquare:getX() + 0.5
    local ty = targetSquare:getY() + 0.5
    local tz = targetSquare:getZ()
    local sz = tonumber(startZ) or tz
    local dist = distance2D(startX, startY, tx, ty)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return targetSquare, dist
    end

    local steps = math.max(1, math.ceil(dist / 0.20))
    local prevSq = cell:getGridSquare(roundToGrid(startX), roundToGrid(startY), roundToGrid(sz)) or targetSquare
    for i = 1, steps do
        local t = i / steps
        local px = startX + ((tx - startX) * t)
        local py = startY + ((ty - startY) * t)
        local pz = sz + ((tz - sz) * t)
        local sq = cell:getGridSquare(roundToGrid(px), roundToGrid(py), roundToGrid(pz)) or prevSq
        if sq and prevSq and sq ~= prevSq then
            if squareBlockedBetween(prevSq, sq) or squareBlockedBetween(sq, prevSq) then
                local impactSq = prevSq or targetSquare
                local impactDist = distance2D(startX, startY, impactSq:getX() + 0.5, impactSq:getY() + 0.5)
                return impactSq, impactDist
            end
        end
        prevSq = sq or prevSq
    end

    return targetSquare, dist
end

local function getDeltaTime()
    if GameTime and GameTime.getInstance then
        local gt = GameTime.getInstance()
        if gt and gt.getRealworldSecondsSinceLastUpdate then
            local dt = gt:getRealworldSecondsSinceLastUpdate()
            if dt and dt > 0 then
                return dt
            end
        end
    end
    return 1.0 / 60.0
end

local function getWeaponModData(weapon)
    if not (weapon and weapon.getModData) then
        return nil
    end
    return weapon:getModData()
end

local function getWeaponFullType(weapon)
    if not (weapon and weapon.getFullType) then
        return nil
    end
    return normalizeFullType(weapon:getFullType())
end

local function resolveStandaloneLauncherProfile(weapon)
    local weaponType = getWeaponFullType(weapon)
    if not weaponType then
        return nil, nil
    end
    return STANDALONE_LAUNCHER_PROFILE_BY_WEAPON[weaponType], weaponType
end

local function isStandaloneAmmoCountProfile(profile)
    return profile and profile.useStandaloneAmmoCount == true
end

local function getStandaloneAmmoCapacity(profile)
    return math.max(1, math.floor(tonumber(profile and profile.capacity) or 1))
end

local function getStandaloneAmmoCount(weapon, profile)
    if not isStandaloneAmmoCountProfile(profile) then
        return 0
    end

    local capacity = getStandaloneAmmoCapacity(profile)
    local count = nil
    if weapon and weapon.getCurrentAmmoCount then
        local ok, value = pcall(weapon.getCurrentAmmoCount, weapon)
        if ok then
            count = tonumber(value)
        end
    end
    if count == nil then
        local md = getWeaponModData(weapon)
        count = tonumber(md and md[MODDATA_STANDALONE_AMMO_COUNT]) or nil
    end

    count = math.floor(tonumber(count) or 0)
    if count < 0 then
        count = 0
    elseif count > capacity then
        count = capacity
    end
    return count
end

local function setStandaloneAmmoCount(weapon, profile, ammoCount)
    if not isStandaloneAmmoCountProfile(profile) then
        return 0
    end

    local capacity = getStandaloneAmmoCapacity(profile)
    local safeCount = math.floor(tonumber(ammoCount) or 0)
    if safeCount < 0 then
        safeCount = 0
    elseif safeCount > capacity then
        safeCount = capacity
    end

    local md = getWeaponModData(weapon)
    if md then
        md[MODDATA_STANDALONE_AMMO_COUNT] = safeCount
    end
    if weapon and weapon.setMaxAmmo then
        pcall(weapon.setMaxAmmo, weapon, capacity)
    end
    if weapon and weapon.setCurrentAmmoCount then
        pcall(weapon.setCurrentAmmoCount, weapon, safeCount)
    end
    if weapon and weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end

    return safeCount
end

local function setPreferredAmmoType(weapon, ammoType)
    local md = getWeaponModData(weapon)
    local normalized = normalizeFullType(ammoType)
    if not (md and normalized) then
        return
    end
    md[MODDATA_SELECTED_AMMO] = normalized
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
end

local function getPreferredAmmoType(weapon, profile)
    local md = getWeaponModData(weapon)
    local preferred = md and normalizeFullType(md[MODDATA_SELECTED_AMMO]) or nil
    if preferred then
        return preferred
    end
    return normalizeFullType(profile and profile.ammoType or "Base.GrenadeAmmo")
end

local function setLoadedAmmoType(weapon, ammoType)
    local md = getWeaponModData(weapon)
    local normalized = normalizeFullType(ammoType)
    if not (md and normalized) then
        return
    end
    md[MODDATA_LOADED_AMMO] = normalized
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
end

local function clearLoadedAmmoType(weapon)
    local md = getWeaponModData(weapon)
    if not md then
        return
    end
    md[MODDATA_LOADED_AMMO] = nil
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
end

local function getAmmoControllerPart(weapon)
    if not (weapon and weapon.getWeaponPart) then
        return nil
    end
    return weapon:getWeaponPart(AMMO_PART_SLOT)
end

local function hasAmmoControllerMarker(weapon)
    local md = getWeaponModData(weapon)
    if not (md and md.weaponpart) then
        return false
    end
    local marker = normalizeFullType(md.weaponpart[AMMO_PART_SLOT])
    return marker == AMMO_CONTROLLER_PART_FULLTYPE
end

local function hasAmmoControllerPart(weapon)
    return getAmmoControllerPart(weapon) ~= nil or hasAmmoControllerMarker(weapon)
end

local function getLoadedAmmoType(weapon, profile)
    local md = getWeaponModData(weapon)
    local loaded = md and normalizeFullType(md[MODDATA_LOADED_AMMO]) or nil
    if isStandaloneAmmoCountProfile(profile) then
        if getStandaloneAmmoCount(weapon, profile) > 0 then
            return loaded or getPreferredAmmoType(weapon, profile)
        end
        return nil
    end
    if loaded then
        return loaded
    end
    if hasAmmoControllerPart(weapon) then
        return getPreferredAmmoType(weapon, profile)
    end
    return nil
end

local function installAmmoControllerPart(weapon, ammoType)
    if not weapon then
        return false
    end

    local installed = false
    if weapon.setWeaponPart and instanceItem then
        local part = instanceItem(AMMO_CONTROLLER_PART_FULLTYPE)
        if part then
            installed = pcall(weapon.setWeaponPart, weapon, AMMO_PART_SLOT, part)
        end
    end

    local markerSet = false
    local md = getWeaponModData(weapon)
    if md then
        md.weaponpart = md.weaponpart or {}
        md.weaponpart[AMMO_PART_SLOT] = AMMO_CONTROLLER_PART_FULLTYPE
        markerSet = true
    end

    if not (installed or markerSet or hasAmmoControllerPart(weapon)) then
        return false
    end

    setLoadedAmmoType(weapon, ammoType)
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end

    return true
end

local function removeAmmoControllerPart(weapon)
    if not weapon then
        return false
    end

    local removed = false
    if weapon.clearWeaponPart then
        removed = pcall(weapon.clearWeaponPart, weapon, AMMO_PART_SLOT)
    end

    local md = getWeaponModData(weapon)
    if md and md.weaponpart then
        md.weaponpart[AMMO_PART_SLOT] = nil
    end

    local cleared = not hasAmmoControllerPart(weapon)
    clearLoadedAmmoType(weapon)
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end

    return removed or cleared
end

local function hasChamberedAmmo(weapon, profile)
    return getLoadedAmmoType(weapon, profile) ~= nil
end

local function computeProjectileFlightTime(distance)
    local dist = tonumber(distance) or 0
    local flight = dist / PROJECTILE_SPEED_TILES_PER_SEC
    if flight < PROJECTILE_MIN_FLIGHT_TIME then
        flight = PROJECTILE_MIN_FLIGHT_TIME
    elseif flight > PROJECTILE_MAX_FLIGHT_TIME then
        flight = PROJECTILE_MAX_FLIGHT_TIME
    end
    return flight
end

local function isPlayerAiming(playerObj)
    if not playerObj then
        return false
    end
    if not playerObj.isAiming then
        return true
    end
    local ok, aiming = pcall(playerObj.isAiming, playerObj)
    if not ok then
        return true
    end
    return aiming == true
end

local function eachInventoryItemRecursive(inventory, callback)
    if not (inventory and inventory.getItems and callback) then
        return false
    end

    local items = inventory:getItems()
    if not items then
        return false
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if callback(item) then
            return true
        end
        if item and item.IsInventoryContainer and item:IsInventoryContainer() then
            local childInv = item:getInventory()
            if childInv and eachInventoryItemRecursive(childInv, callback) then
                return true
            end
        end
    end

    return false
end

local function findPlayerWeaponById(playerObj, itemId)
    if not (playerObj and itemId) then
        return nil
    end

    local primary = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if primary and primary.IsWeapon and primary:IsWeapon() and primary.getID and primary:getID() == itemId then
        return primary
    end

    local secondary = playerObj.getSecondaryHandItem and playerObj:getSecondaryHandItem() or nil
    if secondary and secondary.IsWeapon and secondary:IsWeapon() and secondary.getID and secondary:getID() == itemId then
        return secondary
    end

    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        return nil
    end

    local found = nil
    eachInventoryItemRecursive(inventory, function(item)
        if found then
            return true
        end
        if item and item.IsWeapon and item:IsWeapon() and item.getID and item:getID() == itemId then
            found = item
            return true
        end
        return false
    end)

    return found
end

local function resolveLauncher(weapon)
    if not (weapon and weapon.getWeaponPart) then
        return nil, nil, nil, nil
    end

    local part = weapon:getWeaponPart("Stool")
    if not part or not part.getFullType then
        return nil, nil, nil, nil
    end

    local fullType = normalizeFullType(part:getFullType())
    local profile = LAUNCHER_PROFILE_BY_FULLTYPE[fullType]
    if not profile then
        return nil, fullType, nil, nil
    end

    return part, fullType, profile, profile.state
end

local function isLauncherOpenState(launcherState)
    return launcherState == "empty"
end

local function isLauncherClosedState(launcherState)
    return launcherState == "loaded"
end

local function removeOneItemFromInventory(inventory, fullType)
    local wanted = normalizeFullType(fullType)
    if not wanted then
        return false
    end

    local removed = false
    eachInventoryItemRecursive(inventory, function(item)
        if removed then
            return true
        end
        if item and item.getFullType then
            local itemType = normalizeFullType(item:getFullType())
            if itemType == wanted then
                local container = item.getContainer and item:getContainer() or nil
                if container and container.Remove then
                    pcall(container.Remove, container, item)
                    if sendRemoveItemFromContainer then
                        pcall(sendRemoveItemFromContainer, container, item)
                    end
                    removed = true
                    return true
                end
            end
        end
        return false
    end)

    return removed
end

local function resolveTargetSquare(playerObj, args)
    if not (playerObj and args) then
        return nil, "missing_args", 0
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z) or playerObj:getZ()
    if not x or not y then
        return nil, "invalid_coords", 0
    end

    local square = getCell():getGridSquare(roundToGrid(x), roundToGrid(y), roundToGrid(z))
    if not square then
        square = getCell():getGridSquare(roundToGrid(x), roundToGrid(y), roundToGrid(playerObj:getZ()))
    end
    if not square then
        square = getCell():getGridSquare(roundToGrid(x), roundToGrid(y), 0)
    end
    if not square then
        return nil, "square_not_found", 0
    end

    local dx = (square:getX() + 0.5) - playerObj:getX()
    local dy = (square:getY() + 0.5) - playerObj:getY()
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > (MAX_TARGET_DISTANCE + 1.0) then
        return nil, "out_of_range", dist
    end

    return square, nil, dist
end

local function swapLauncherPart(weapon, currentPart, targetType)
    if not (weapon and currentPart and targetType and weapon.setWeaponPart) then
        return false, "invalid_state"
    end

    local targetFullType = normalizeFullType(targetType)
    local targetPart = instanceItem and instanceItem(targetFullType) or nil
    if not targetPart then
        return false, "missing_target_item"
    end

    if currentPart.getCondition and targetPart.setCondition then
        pcall(targetPart.setCondition, targetPart, currentPart:getCondition())
    end

    local ok, err = pcall(weapon.setWeaponPart, weapon, "Stool", targetPart)
    if not ok then
        return false, tostring(err)
    end

    local md = weapon:getModData()
    md.weaponpart = md.weaponpart or {}
    md.weaponpart["Stool"] = targetFullType
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end

    return true, targetFullType
end

local function swapLauncherToEmpty(weapon, loadedPart, profile)
    if not (profile and profile.emptyType) then
        return false, "invalid_profile"
    end
    return swapLauncherPart(weapon, loadedPart, profile.emptyType)
end

local function swapLauncherToLoaded(weapon, emptyPart, profile)
    if not (profile and profile.loadedType) then
        return false, "invalid_profile"
    end
    return swapLauncherPart(weapon, emptyPart, profile.loadedType)
end

local function triggerImpactFire(square, power)
    if not square then
        return false, "square_nil"
    end
    if not (IsoFireManager and IsoFireManager.StartFire and getCell) then
        return false, "startfire_api_missing"
    end

    local fireEnergy = math.max(5, tonumber(power) or 5)
    local ok, err = pcall(IsoFireManager.StartFire, getCell(), square, true, fireEnergy)
    if not ok then
        return false, tostring(err)
    end
    return true, fireEnergy
end

local function getSmokeLife()
    if SMOKE_LIFE_MAX <= SMOKE_LIFE_MIN then
        return SMOKE_LIFE_MIN
    end
    return SMOKE_LIFE_MIN + ZombRand((SMOKE_LIFE_MAX - SMOKE_LIFE_MIN) + 1)
end

local function isSquareBlockingSmoke(square)
    if not square then
        return true
    end
    if not IsoFlagType then
        return false
    end

    local props = square.getProperties and square:getProperties() or nil
    if not (props and props.has) then
        return false
    end

    if IsoFlagType.burning and props:has(IsoFlagType.burning) then
        return true
    end
    if IsoFlagType.smoke and props:has(IsoFlagType.smoke) then
        return true
    end

    return false
end

local function findSmokeSquareNearImpact(square)
    if not square then
        return nil
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return square
    end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    local offsets = {
        { 0, 0 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 },
        { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }
    }

    for i = 1, #offsets do
        local ox = offsets[i][1]
        local oy = offsets[i][2]
        local candidate = cell:getGridSquare(x + ox, y + oy, z)
        if candidate and not isSquareBlockingSmoke(candidate) then
            return candidate
        end
    end

    return square
end

local function triggerImpactSmoke(square)
    if not SMOKE_ENABLED then
        return false, "disabled"
    end
    if not square then
        return false, "square_nil"
    end
    if not (IsoFireManager and IsoFireManager.StartSmoke and getCell) then
        return false, "startsmoke_api_missing"
    end

    local smokeSquare = findSmokeSquareNearImpact(square)
    if not smokeSquare then
        return false, "smoke_square_nil"
    end

    local smokeLife = getSmokeLife()
    local ok, err = pcall(IsoFireManager.StartSmoke, getCell(), smokeSquare, true, SMOKE_START_ENERGY, smokeLife)
    if not ok then
        return false, tostring(err)
    end

    return true, string.format("%d,%d,%d life=%d", smokeSquare:getX(), smokeSquare:getY(), smokeSquare:getZ(), smokeLife)
end

local function createExplosionDamageWeapon(square, payload)
    local weaponType = normalizeFullType(payload and payload.damageWeaponType) or "Base.PipeBomb"
    local weapon = instanceItem and instanceItem(weaponType) or nil
    if (not weapon) and weaponType ~= "Base.PipeBomb" and instanceItem then
        weapon = instanceItem("Base.PipeBomb")
    end
    if not (weapon and weapon.IsWeapon and weapon:IsWeapon()) then
        return nil
    end

    if weapon.setAttackTargetSquare and square then
        pcall(weapon.setAttackTargetSquare, weapon, square)
    end

    return weapon
end

local function removeTrapProxyObject(trap, square)
    if not trap then
        return false
    end

    local removed = false
    if trap.removeFromSquare then
        local ok = pcall(trap.removeFromSquare, trap)
        if ok then
            removed = true
        end
    end
    if trap.removeFromWorld then
        local ok = pcall(trap.removeFromWorld, trap)
        if ok then
            removed = true
        end
    end
    if square and square.RemoveTileObject then
        local ok = pcall(square.RemoveTileObject, square, trap)
        if ok then
            removed = true
        end
    end

    return removed
end

local function queueTrapProxyCleanup(trap, square, ttl)
    if not trap then
        return
    end
    table.insert(activeTrapProxyCleanups, {
        trap = trap,
        square = square,
        ttl = math.max(0.10, tonumber(ttl) or 1.50)
    })
end

local function cleanupTrapProxyCleanups(dt)
    for i = #activeTrapProxyCleanups, 1, -1 do
        local entry = activeTrapProxyCleanups[i]
        entry.ttl = (entry.ttl or 0.0) - (dt or 0.0)
        if entry.ttl <= 0 then
            removeTrapProxyObject(entry.trap, entry.square)
            table.remove(activeTrapProxyCleanups, i)
        end
    end
end

distance2D = function(x1, y1, x2, y2)
    local dx = (x1 or 0) - (x2 or 0)
    local dy = (y1 or 0) - (y2 or 0)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function computePayloadExplosionRange(payload, power)
    local baseRange = tonumber(payload and payload.explosionRange)
    if baseRange and baseRange > 0 then
        return math.max(1, math.floor(baseRange + 0.5))
    end

    local p = math.max(1, tonumber(power) or 1)
    local derived = math.max(BLAST_DAMAGE_MIN_RADIUS, math.min(BLAST_DAMAGE_MAX_RADIUS, 1.0 + (p * BLAST_DAMAGE_RADIUS_SCALE)))
    return math.max(1, math.floor(derived + 0.5))
end

local function getPhysicsBlastPower(profile, payload)
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100
    local override = tonumber(payload and payload.physicsBlastPower)
    if override and override > 0 then
        return math.max(1, math.floor(override + 0.5))
    end

    local scale = tonumber(payload and payload.physicsBlastPowerScale) or 1.0
    return math.max(1, math.floor((basePower * scale) + 0.5))
end

local function isCharacterReallyDead(character)
    if not character then
        return false, "character_nil"
    end
    if character.getSquare then
        local ok, sq = pcall(character.getSquare, character)
        if ok and sq == nil then
            return true, "square=nil"
        end
    end
    if character.getCurrentSquare then
        local ok, sq = pcall(character.getCurrentSquare, character)
        if ok and sq == nil then
            return true, "currentSquare=nil"
        end
    end
    return false, "alive"
end

local function forceZombieDeath(character, damageWeapon, attacker)
    if not (character and instanceof(character, "IsoZombie")) then
        return false, "not_zombie"
    end

    local attempts = {}
    local function tryMethod(label, fn, ...)
        if not fn then
            return false
        end
        local ok = pcall(fn, character, ...)
        table.insert(attempts, label .. "=" .. tostring(ok))
        local nowDead, nowReason = isCharacterReallyDead(character)
        if nowDead then
            return true, label .. " -> " .. nowReason
        end
        return false
    end

    if character.setHealth then
        local ok = pcall(character.setHealth, character, 0.0)
        table.insert(attempts, "setHealth(0)=" .. tostring(ok))
    end
    if character.setReanimate then
        local ok = pcall(character.setReanimate, character, false)
        table.insert(attempts, "setReanimate(false)=" .. tostring(ok))
    end
    if character.setFakeDead then
        local ok = pcall(character.setFakeDead, character, false)
        table.insert(attempts, "setFakeDead(false)=" .. tostring(ok))
    end
    if character.setForceFakeDead then
        local ok = pcall(character.setForceFakeDead, character, false)
        table.insert(attempts, "setForceFakeDead(false)=" .. tostring(ok))
    end
    if character.shouldDoInventory then
        local okShould, shouldDo = pcall(character.shouldDoInventory, character)
        table.insert(attempts, "shouldDoInventory=" .. tostring(okShould and shouldDo or okShould))
        if okShould and shouldDo and character.DoZombieInventory then
            local okInv = pcall(character.DoZombieInventory, character)
            table.insert(attempts, "DoZombieInventory()=" .. tostring(okInv))
        end
    end
    if character.DoCorpseInventory then
        local okCorpseInv = pcall(character.DoCorpseInventory, character)
        table.insert(attempts, "DoCorpseInventory()=" .. tostring(okCorpseInv))
    end
    if tryMethod("becomeCorpse()", character.becomeCorpse) then
        -- continue to network cleanup below
    end
    if NetworkZombiePacker and NetworkZombiePacker.getInstance then
        local okInst, packer = pcall(NetworkZombiePacker.getInstance)
        table.insert(attempts, "NetworkZombiePacker.getInstance=" .. tostring(okInst and packer ~= nil or false))
        if okInst and packer and packer.deleteZombie then
            local okDelete = pcall(packer.deleteZombie, packer, character)
            table.insert(attempts, "deleteZombie()=" .. tostring(okDelete))
        end
    end
    if VirtualZombieManager and VirtualZombieManager.instance then
        local vzm = VirtualZombieManager.instance
        if vzm.removeZombieFromWorld then
            local okRemove = pcall(vzm.removeZombieFromWorld, vzm, character)
            table.insert(attempts, "removeZombieFromWorld()=" .. tostring(okRemove))
        end
        if vzm.RemoveZombie then
            local okRemove2 = pcall(vzm.RemoveZombie, vzm, character)
            table.insert(attempts, "RemoveZombie()=" .. tostring(okRemove2))
        end
    end
    if character.removeFromSquare then
        local ok = pcall(character.removeFromSquare, character)
        table.insert(attempts, "removeFromSquare()=" .. tostring(ok))
    end
    if character.removeFromWorld then
        local ok = pcall(character.removeFromWorld, character)
        table.insert(attempts, "removeFromWorld()=" .. tostring(ok))
    end

    local finalDead, finalReason = isCharacterReallyDead(character)
    if finalDead then
        return true, finalReason .. " | " .. table.concat(attempts, ",")
    end
    return false, table.concat(attempts, ",")
end

-- Legacy disabled:
-- MP grenade damage no longer uses the old IsoTrap/PipeBomb detonation path.
-- The live path is the custom area damage executed from detonatePendingImpact().
-- Keeping the implementation commented preserves the investigation history without
-- leaving an apparently-available code path that is never called.
--[[
local function triggerImpactTrapExplosion(square, payload, attacker, physicsBlastPower)
    ...
end
]]

local function applyBlastDamage(square, explosionPower, attacker, payload)
    if not square then
        return 0, 0.0, 0.0, false, "square_nil"
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return 0, 0.0, 0.0, false, "cell_nil"
    end

    local power = math.max(1, tonumber(explosionPower) or 1)
    local radius = tonumber(payload and payload.damageRadius)
    if not radius or radius <= 0 then
        radius = math.max(BLAST_DAMAGE_MIN_RADIUS, math.min(BLAST_DAMAGE_MAX_RADIUS, 1.0 + (power * BLAST_DAMAGE_RADIUS_SCALE)))
    end
    local centerX = square:getX() + 0.5
    local centerY = square:getY() + 0.5
    local minX = math.floor(centerX - radius)
    local maxX = math.ceil(centerX + radius)
    local minY = math.floor(centerY - radius)
    local maxY = math.ceil(centerY + radius)
    local minZ = square:getZ()
    local maxZ = math.min(square:getZ() + 1, 8)

    local damageWeapon = nil
    local affected = 0
    local totalDamage = 0.0
    local seen = {}
    local lethalRadius = tonumber(payload and payload.lethalRadius)
    if not lethalRadius or lethalRadius <= 0 then
        lethalRadius = math.max(0.85, radius * 0.30)
    end
    local payloadMaxDamage = tonumber(payload and payload.maxDamage)
    if not payloadMaxDamage or payloadMaxDamage <= 0 then
        payloadMaxDamage = power
    end
    local payloadMinDamage = tonumber(payload and payload.minDamage)
    if payloadMinDamage == nil then
        payloadMinDamage = BLAST_DAMAGE_MIN
    end
    local candidates = 0
    local candidatesInRadius = 0
    local zombieCandidates = 0
    local playerCandidates = 0
    local hitAttempts = 0
    local hitSuccesses = 0
    local healthFallbackAttempts = 0
    local healthFallbackSuccesses = 0
    local missingHitMethod = 0
    local damageWeaponCreationFailed = false
    local lastHitError = nil
    local firstFallbackOldHealth = nil
    local firstFallbackNewHealth = nil
    local maxAppliedDamage = 0.0
    local killAttempts = 0
    local killSuccesses = 0
    local lastKillMethod = nil
    local killVerified = 0

    for z = minZ, maxZ do
        for x = minX, maxX do
            for y = minY, maxY do
                local hitSquare = cell:getGridSquare(x, y, z)
                if hitSquare and hitSquare.getMovingObjects then
                    local squareCenterX = x + 0.5
                    local squareCenterY = y + 0.5
                    local squareDist = distance2D(centerX, centerY, squareCenterX, squareCenterY)
                    local movingObjects = hitSquare:getMovingObjects()
                    if movingObjects and squareDist <= radius then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if moving and (instanceof(moving, "IsoZombie") or instanceof(moving, "IsoPlayer")) then
                                candidates = candidates + 1
                                if instanceof(moving, "IsoZombie") then
                                    zombieCandidates = zombieCandidates + 1
                                else
                                    playerCandidates = playerCandidates + 1
                                end
                                local key = tostring(moving)
                                if not seen[key] then
                                    seen[key] = true
                                    candidatesInRadius = candidatesInRadius + 1

                                    local falloff = 1.0 - (squareDist / radius)
                                    if falloff < 0 then
                                        falloff = 0
                                    end
                                    local damage = payloadMinDamage + ((payloadMaxDamage - payloadMinDamage) * falloff)
                                    if damage < BLAST_DAMAGE_MIN then
                                        damage = BLAST_DAMAGE_MIN
                                    end

                                    if not damageWeapon then
                                        damageWeapon = createExplosionDamageWeapon(square, payload)
                                        if not damageWeapon then
                                            damageWeaponCreationFailed = true
                                        end
                                    end

                                    local damaged = false
                                    if moving.Hit then
                                        missingHitMethod = missingHitMethod + 1
                                        lastHitError = "server_Hit_disabled_ballistics_nil"
                                    end

                                    if moving.getHealth and moving.setHealth then
                                        healthFallbackAttempts = healthFallbackAttempts + 1
                                        local oldHealth = tonumber(moving:getHealth()) or 1.0
                                        if instanceof(moving, "IsoZombie") and squareDist <= lethalRadius then
                                            damage = math.max(damage, oldHealth + 5.0)
                                        end
                                        local newHealth = math.max(0.0, oldHealth - damage)
                                        if not firstFallbackOldHealth then
                                            firstFallbackOldHealth = oldHealth
                                            firstFallbackNewHealth = newHealth
                                        end
                                        local okSet = pcall(moving.setHealth, moving, newHealth)
                                        damaged = okSet
                                        if okSet then
                                            healthFallbackSuccesses = healthFallbackSuccesses + 1
                                            if newHealth <= 0.0 and instanceof(moving, "IsoZombie") then
                                                killAttempts = killAttempts + 1
                                                local okKill, killMethod = forceZombieDeath(moving, damageWeapon, attacker)
                                                lastKillMethod = tostring(killMethod)
                                                if okKill then
                                                    killSuccesses = killSuccesses + 1
                                                    killVerified = killVerified + 1
                                                end
                                            end
                                        end
                                    end

                                    if damaged then
                                        affected = affected + 1
                                        totalDamage = totalDamage + damage
                                        if damage > maxAppliedDamage then
                                            maxAppliedDamage = damage
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

    local debugData = string.format(
        "cands=%d inRad=%d z=%d p=%d hit=%d/%d hpFallback=%d/%d kill=%d/%d killVerified=%d killMethod=%s missHit=%d dmgItem=%s dmgItemFail=%s maxDmg=%.2f lethalR=%.2f hp0=%.2f->%.2f lastHitErr=%s",
        candidates, candidatesInRadius, zombieCandidates, playerCandidates, hitSuccesses, hitAttempts,
        healthFallbackSuccesses, healthFallbackAttempts, killSuccesses, killAttempts, killVerified, tostring(lastKillMethod), missingHitMethod, tostring(damageWeapon ~= nil),
        tostring(damageWeaponCreationFailed), tonumber(maxAppliedDamage) or 0,
        tonumber(lethalRadius) or 0, tonumber(firstFallbackOldHealth) or -1, tonumber(firstFallbackNewHealth) or -1, tostring(lastHitError))
    logGL("Manual blast damage debug payload=%s square=%d,%d,%d %s", tostring(payload and payload.id), square:getX(), square:getY(),
        square:getZ(), debugData)
    return affected, totalDamage, radius, damageWeapon ~= nil, debugData
end

local function getScaledFireExplosionPower(profile, payload)
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100
    local scale = tonumber(payload and payload.firePowerScale) or FIRE_EXPLOSION_POWER_SCALE
    local scaledPower = math.max(1, math.floor((basePower * scale) + 0.5))
    return scaledPower, basePower
end

-- Legacy disabled:
-- After the MP blast rewrite, server-side detonation no longer consumes a separate
-- "damagePower" output. Damage now comes from applyBlastDamage() using the manual
-- power chosen in detonatePendingImpact().
--[[
local function getScaledDamagePower(profile, payload)
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100
    local scale = tonumber(payload and payload.damagePowerScale) or DAMAGE_POWER_SCALE
    local scaledPower = math.max(1, math.floor((basePower * scale) + 0.5))
    return scaledPower, basePower
end
]]

local function queuePendingImpact(pending)
    if not pending then
        return
    end
    table.insert(pendingImpacts, pending)
end

local function getSquareAtWorldPosition(cell, x, y, z, fallbackSquare)
    if not (cell and cell.getGridSquare) then
        return fallbackSquare
    end

    local square = cell:getGridSquare(roundToGrid(x), roundToGrid(y), roundToGrid(z))
    if square then
        return square
    end
    return fallbackSquare
end

local function advancePendingImpact(pending, dt)
    if not pending then
        return nil, "pending_nil"
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return nil, "cell_nil"
    end

    local startX = tonumber(pending.startX)
    local startY = tonumber(pending.startY)
    local startZ = tonumber(pending.startZ) or 0
    local targetX = tonumber(pending.targetX)
    local targetY = tonumber(pending.targetY)
    local targetZ = tonumber(pending.targetZ) or startZ
    if not (startX and startY and targetX and targetY) then
        return nil, "coords_invalid"
    end

    local targetWorldX = targetX + 0.5
    local targetWorldY = targetY + 0.5
    local totalFlightTime = math.max(PROJECTILE_MIN_FLIGHT_TIME, tonumber(pending.flightTime) or 0)
    local prevElapsed = math.max(0.0, tonumber(pending.elapsed) or 0.0)
    local nextElapsed = prevElapsed + math.max(0.0, tonumber(dt) or 0.0)
    local prevRatio = math.min(1.0, prevElapsed / totalFlightTime)
    local nextRatio = math.min(1.0, nextElapsed / totalFlightTime)

    local prevX = startX + ((targetWorldX - startX) * prevRatio)
    local prevY = startY + ((targetWorldY - startY) * prevRatio)
    local prevZ = startZ + ((targetZ - startZ) * prevRatio)
    local nextX = startX + ((targetWorldX - startX) * nextRatio)
    local nextY = startY + ((targetWorldY - startY) * nextRatio)
    local nextZ = startZ + ((targetZ - startZ) * nextRatio)

    local segmentDist = distance2D(prevX, prevY, nextX, nextY)
    local steps = math.max(1, math.ceil(segmentDist / 0.20))
    local prevSq = getSquareAtWorldPosition(cell, prevX, prevY, prevZ,
        getSquareAtWorldPosition(cell, startX, startY, startZ, nil))

    for i = 1, steps do
        local stepRatio = i / steps
        local px = prevX + ((nextX - prevX) * stepRatio)
        local py = prevY + ((nextY - prevY) * stepRatio)
        local pz = prevZ + ((nextZ - prevZ) * stepRatio)
        local sq = getSquareAtWorldPosition(cell, px, py, pz, prevSq)
        if sq and prevSq and sq ~= prevSq then
            if squareBlockedBetween(prevSq, sq) or squareBlockedBetween(sq, prevSq) then
                pending.elapsed = nextElapsed
                return prevSq or sq, "blocked"
            end
        end
        prevSq = sq or prevSq
    end

    pending.elapsed = nextElapsed
    if nextRatio >= 1.0 then
        return prevSq or getSquareAtWorldPosition(cell, targetWorldX, targetWorldY, targetZ, nil), "arrived"
    end

    return nil, "traveling"
end

local function detonatePendingImpact(pending)
    if not pending then
        return
    end

    local square = getCell():getGridSquare(pending.targetX, pending.targetY, pending.targetZ)
    if not square then
        square = getCell():getGridSquare(pending.targetX, pending.targetY, 0)
    end
    if not square then
        logGL("Detonation skipped: square missing stamp=%s x=%s y=%s z=%s", tostring(pending.stamp), tostring(pending.targetX),
            tostring(pending.targetY), tostring(pending.targetZ))
        return
    end

    local payload = resolveImpactPayload(pending.ammoType, pending.profile)
    local firePower, basePower = getScaledFireExplosionPower(pending.profile, payload)
    local ignited, igniteData = false, "disabled"
    if payload and payload.groundFire == true then
        ignited, igniteData = triggerImpactFire(square, firePower)
        if not ignited then
            logGL("Impact fire failed launcher=%s err=%s", tostring(pending.launcherType), tostring(igniteData))
        end
    end

    local smoked, smokeData = triggerImpactSmoke(square)
    if not smoked then
        logGL("Impact smoke failed launcher=%s err=%s", tostring(pending.launcherType), tostring(smokeData))
    end

    local physicsBlastPower = getPhysicsBlastPower(pending.profile, payload)
    local blastTriggered, blastData = false, "custom_area_damage"
    local affected, totalDamage, damageRadius, usedDamageWeapon, damageDebug = 0, 0.0, 0.0, false, nil
    local manualDamagePower = math.max(tonumber(physicsBlastPower) or 0, tonumber(basePower) or 0)
    affected, totalDamage, damageRadius, usedDamageWeapon, damageDebug = applyBlastDamage(square, manualDamagePower, pending.playerObj, payload)

    sendServerCommand(MODULE_NAME, COMMAND_EXPLOSION_FX, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        stamp = pending.stamp,
        by = pending.onlineId,
        launcher = pending.launcherType,
        sound = payload and payload.explosionSound,
        ammoType = payload and payload.ammoType
    })

    logGL(
        "Detonation success onlineId=%s launcher=%s ammo=%s payload=%s target=%d,%d,%d dist=%.2f firePower=%d fireEnergy=%s smoke=%s blast=%s blastData=%s physBlast=%d dmgPower=%d base=%d stamp=%s zHits=%d zDmg=%.2f zRad=%.2f dmgWpn=%s dmgDbg=%s",
        tostring(pending.onlineId), tostring(pending.launcherType), tostring(payload and payload.ammoType), tostring(payload and payload.id), square:getX(), square:getY(), square:getZ(),
        tonumber(pending.distance) or 0, firePower, tostring(igniteData), tostring(smokeData), tostring(blastTriggered), tostring(blastData), physicsBlastPower, manualDamagePower, basePower,
        tostring(pending.stamp), tonumber(affected) or 0, tonumber(totalDamage) or 0, tonumber(damageRadius) or 0,
        tostring(usedDamageWeapon), tostring(damageDebug))
end

local function resolveCommandWeapon(playerObj, args)
    if not playerObj then
        return nil
    end

    local weapon = nil
    local gunId = args and tonumber(args.gunId) or nil
    if gunId then
        weapon = findPlayerWeaponById(playerObj, gunId)
    end
    if not weapon then
        weapon = playerObj:getPrimaryHandItem()
    end
    if not (weapon and weapon.IsWeapon and weapon:IsWeapon() and weapon.isRanged and weapon:isRanged()) then
        return nil
    end
    return weapon
end

local function sendStandaloneState(playerObj, weapon, profile, reason)
    if not (playerObj and weapon and profile and sendServerCommand) then
        return
    end

    local gunId = weapon.getID and weapon:getID() or nil
    if not gunId then
        return
    end

    local count = getStandaloneAmmoCount(weapon, profile)
    local ammoType = getLoadedAmmoType(weapon, profile) or getPreferredAmmoType(weapon, profile) or profile.ammoType
    pcall(sendServerCommand, playerObj, MODULE_NAME, COMMAND_STANDALONE_STATE, {
        gunId = gunId,
        count = count,
        ammoType = normalizeFullType(ammoType),
        reason = reason
    })
    logGL("Standalone state sent onlineId=%s gunId=%s count=%s ammo=%s reason=%s",
        tostring(playerObj:getOnlineID()), tostring(gunId), tostring(count), tostring(ammoType), tostring(reason))
end

local function handleStandaloneFireCommand(playerObj, args, weapon, profile, weaponType)
    if not (playerObj and weapon and profile and weaponType) then
        return false
    end

    local currentCount = getStandaloneAmmoCount(weapon, profile)
    local clientAmmoType = normalizeFullType(args and args.ammoType)
    if currentCount <= 0 then
        local clientAmmoCount = math.floor(tonumber(args and args.clientAmmoCount) or 0)
        if args and args.vanillaShot and clientAmmoType and clientAmmoCount > 0 then
            logGL("Standalone fire accepted after vanilla ammo consume onlineId=%s weapon=%s clientAmmo=%s clientCount=%s",
                tostring(playerObj:getOnlineID()), tostring(weaponType), tostring(clientAmmoType),
                tostring(clientAmmoCount))
        else
            logGL("Standalone fire rejected: no server ammo onlineId=%s weapon=%s clientAmmo=%s clientCount=%s vanillaShot=%s",
                tostring(playerObj:getOnlineID()), tostring(weaponType), tostring(clientAmmoType),
                tostring(clientAmmoCount), tostring(args and args.vanillaShot))
            sendStandaloneState(playerObj, weapon, profile, "fire-empty")
            return true
        end
    end

    local shotAmmoType = getLoadedAmmoType(weapon, profile) or clientAmmoType or normalizeFullType(profile.ammoType or "Base.GrenadeAmmo")
    local square, reason, dist = resolveTargetSquare(playerObj, args)
    if not square then
        logGL("Standalone fire rejected: bad target reason=%s dist=%.2f onlineId=%s weapon=%s", tostring(reason),
            tonumber(dist) or 0, tostring(playerObj:getOnlineID()), tostring(weaponType))
        return true
    end

    local stamp = args and args.stamp and tostring(args.stamp) or ""
    local startX = tonumber(args and args.startX) or playerObj:getX()
    local startY = tonumber(args and args.startY) or playerObj:getY()
    local startZ = tonumber(args and args.startZ) or playerObj:getZ()
    dist = tonumber(dist) or 0
    local targetX = square:getX() + 0.5
    local targetY = square:getY() + 0.5
    local targetZ = square:getZ()
    local flightTime = PROJECTILE_ENABLED and computeProjectileFlightTime(dist) or 0

    if PROJECTILE_ENABLED then
        sendServerCommand(MODULE_NAME, COMMAND_PROJECTILE_FX, {
            startX = startX,
            startY = startY,
            startZ = startZ,
            targetX = targetX,
            targetY = targetY,
            targetZ = targetZ,
            flightTime = flightTime,
            ammoType = shotAmmoType,
            stamp = stamp,
            by = playerObj:getOnlineID(),
            launcher = weaponType
        })
    end

    if isStandaloneAmmoCountProfile(profile) then
        if getStandaloneAmmoCapacity(profile) <= 1 then
            setStandaloneAmmoCount(weapon, profile, 0)
        end
    end
    if getStandaloneAmmoCount(weapon, profile) <= 0 then
        clearLoadedAmmoType(weapon)
    end
    sendStandaloneState(playerObj, weapon, profile, "fire")

    queuePendingImpact({
        elapsed = 0,
        flightTime = flightTime,
        startX = startX,
        startY = startY,
        startZ = startZ,
        playerObj = playerObj,
        onlineId = playerObj:getOnlineID(),
        launcherType = weaponType,
        profile = profile,
        ammoType = shotAmmoType,
        targetX = square:getX(),
        targetY = square:getY(),
        targetZ = square:getZ(),
        stamp = stamp,
        distance = dist
    })

    logGL("Standalone fire queued onlineId=%s weapon=%s target=%d,%d,%d dist=%.2f stamp=%s flight=%.2f count=%d ammo=%s",
        tostring(playerObj:getOnlineID()), tostring(weaponType), square:getX(), square:getY(), square:getZ(), tonumber(dist) or 0,
        tostring(stamp), flightTime, currentCount, tostring(shotAmmoType))
    return true
end

local function handleStandaloneLoadCommand(playerObj, args, weapon, profile, weaponType)
    if not (playerObj and weapon and profile and weaponType) then
        return false
    end

    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        logGL("Standalone load rejected: inventory missing onlineId=%s weapon=%s", tostring(playerObj:getOnlineID()),
            tostring(weaponType))
        return true
    end

    local currentCount = getStandaloneAmmoCount(weapon, profile)
    local capacity = getStandaloneAmmoCapacity(profile)
    if currentCount >= capacity then
        logGL("Standalone load rejected: weapon full onlineId=%s weapon=%s count=%d/%d", tostring(playerObj:getOnlineID()),
            tostring(weaponType), currentCount, capacity)
        sendStandaloneState(playerObj, weapon, profile, "load-full")
        return true
    end

    local loadedAmmoType = getLoadedAmmoType(weapon, profile)
    local ammoType = normalizeFullType(args and args.ammoType or loadedAmmoType or profile.ammoType or "Base.GrenadeAmmo")
    if loadedAmmoType and ammoType ~= loadedAmmoType then
        ammoType = loadedAmmoType
    end

    if not removeOneItemFromInventory(inventory, ammoType) then
        logGL("Standalone load rejected: no ammo onlineId=%s weapon=%s ammo=%s", tostring(playerObj:getOnlineID()),
            tostring(weaponType), tostring(ammoType))
        return true
    end

    local nextCount = setStandaloneAmmoCount(weapon, profile, currentCount + 1)
    setPreferredAmmoType(weapon, ammoType)
    setLoadedAmmoType(weapon, ammoType)
    logGL("Standalone load success onlineId=%s weapon=%s ammo=%s count=%d/%d", tostring(playerObj:getOnlineID()),
        tostring(weaponType), tostring(ammoType), nextCount, capacity)
    sendStandaloneState(playerObj, weapon, profile, "load-success")
    return true
end

local function handleFireCommand(playerObj, args)
    if not isPlayerAiming(playerObj) then
        logGL("Fire aiming mismatch: continuing onlineId=%s", tostring(playerObj and playerObj:getOnlineID()))
    end

    local weapon = resolveCommandWeapon(playerObj, args)
    if not weapon then
        logGL("Fire rejected: no ranged weapon onlineId=%s", tostring(playerObj and playerObj:getOnlineID()))
        return
    end

    if args and args.standalone then
        local profile, weaponType = resolveStandaloneLauncherProfile(weapon)
        if handleStandaloneFireCommand(playerObj, args, weapon, profile, weaponType) then
            return
        end
    end

    local _, launcherType, profile, launcherState = resolveLauncher(weapon)
    if not profile then
        logGL("Fire rejected: launcher missing onlineId=%s launcher=%s state=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType), tostring(launcherState))
        return
    end
    if not isLauncherClosedState(launcherState) then
        logGL("Fire rejected: launcher breech open onlineId=%s launcher=%s state=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType), tostring(launcherState))
        return
    end
    local clientAmmoType = normalizeFullType(args and args.ammoType)
    if not hasChamberedAmmo(weapon, profile) then
        logGL("Fire rejected: launcher has no server chambered ammo onlineId=%s launcher=%s clientAmmo=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType), tostring(clientAmmoType))
        return
    end
    local shotAmmoType = getLoadedAmmoType(weapon, profile) or clientAmmoType or normalizeFullType(profile.ammoType or "Base.GrenadeAmmo")

    local square, reason, dist = resolveTargetSquare(playerObj, args)
    if not square then
        logGL("Fire rejected: bad target reason=%s dist=%.2f onlineId=%s", tostring(reason), tonumber(dist) or 0,
            tostring(playerObj:getOnlineID()))
        return
    end

    if not removeAmmoControllerPart(weapon) then
        logGL("Fire rejected: failed removing ammo controller launcher=%s onlineId=%s", tostring(launcherType),
            tostring(playerObj:getOnlineID()))
        return
    end

    local stamp = args and args.stamp and tostring(args.stamp) or ""
    local startX = tonumber(args and args.startX) or playerObj:getX()
    local startY = tonumber(args and args.startY) or playerObj:getY()
    local startZ = tonumber(args and args.startZ) or playerObj:getZ()
    dist = tonumber(dist) or 0
    local targetX = square:getX() + 0.5
    local targetY = square:getY() + 0.5
    local targetZ = square:getZ()
    local flightTime = PROJECTILE_ENABLED and computeProjectileFlightTime(dist) or 0

    if PROJECTILE_ENABLED then
        sendServerCommand(MODULE_NAME, COMMAND_PROJECTILE_FX, {
            startX = startX,
            startY = startY,
            startZ = startZ,
            targetX = targetX,
            targetY = targetY,
            targetZ = targetZ,
            flightTime = flightTime,
            ammoType = shotAmmoType,
            stamp = stamp,
            by = playerObj:getOnlineID(),
            launcher = launcherType
        })
    end

    queuePendingImpact({
        elapsed = 0,
        flightTime = flightTime,
        startX = startX,
        startY = startY,
        startZ = startZ,
        playerObj = playerObj,
        onlineId = playerObj:getOnlineID(),
        launcherType = launcherType,
        profile = profile,
        ammoType = shotAmmoType,
        targetX = square:getX(),
        targetY = square:getY(),
        targetZ = square:getZ(),
        stamp = stamp,
        distance = dist
    })

    logGL("Fire queued onlineId=%s launcher=%s target=%d,%d,%d dist=%.2f stamp=%s flight=%.2f",
        tostring(playerObj:getOnlineID()), tostring(launcherType), square:getX(), square:getY(), square:getZ(), tonumber(dist) or 0,
        tostring(stamp), flightTime)
end

local function handleLoadCommand(playerObj, args)
    local weapon = resolveCommandWeapon(playerObj, args)
    if not weapon then
        logGL("Load rejected: no ranged weapon onlineId=%s", tostring(playerObj and playerObj:getOnlineID()))
        return
    end

    if args and args.standalone then
        local profile, weaponType = resolveStandaloneLauncherProfile(weapon)
        if handleStandaloneLoadCommand(playerObj, args, weapon, profile, weaponType) then
            return
        end
    end

    local launcherPart, launcherType, profile, launcherState = resolveLauncher(weapon)
    if not profile then
        logGL("Load rejected: launcher missing onlineId=%s launcher=%s state=%s", tostring(playerObj:getOnlineID()),
            tostring(launcherType), tostring(launcherState))
        return
    end

    if hasChamberedAmmo(weapon, profile) then
        logGL("Load rejected: launcher already has chambered ammo onlineId=%s launcher=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType))
        return
    end

    if not (isLauncherOpenState(launcherState) or isLauncherClosedState(launcherState)) then
        logGL("Load rejected: launcher in unknown state onlineId=%s launcher=%s state=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType), tostring(launcherState))
        return
    end

    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        logGL("Load rejected: inventory missing onlineId=%s", tostring(playerObj:getOnlineID()))
        return
    end

    local ammoType = normalizeFullType(args and args.ammoType or profile.ammoType or "Base.GrenadeAmmo")
    if not removeOneItemFromInventory(inventory, ammoType) then
        logGL("Load rejected: no ammo onlineId=%s launcher=%s ammo=%s", tostring(playerObj:getOnlineID()),
            tostring(launcherType), tostring(ammoType))
        return
    end

    if isLauncherClosedState(launcherState) then
        local opened, openData = swapLauncherToEmpty(weapon, launcherPart, profile)
        if not opened then
            if inventory.AddItem then
                pcall(inventory.AddItem, inventory, ammoType)
            end
            logGL("Load rejected: open phase failed launcher=%s reason=%s", tostring(launcherType), tostring(openData))
            return
        end

        launcherPart, launcherType, profile, launcherState = resolveLauncher(weapon)
    end

    if not (launcherPart and profile and isLauncherOpenState(launcherState)) then
        if inventory.AddItem then
            pcall(inventory.AddItem, inventory, ammoType)
        end
        logGL("Load rejected: launcher not open for insert onlineId=%s launcher=%s state=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType), tostring(launcherState))
        return
    end

    if not installAmmoControllerPart(weapon, ammoType) then
        if inventory.AddItem then
            pcall(inventory.AddItem, inventory, ammoType)
        end
        logGL("Load rejected: failed to install ammo controller launcher=%s ammo=%s", tostring(launcherType),
            tostring(ammoType))
        return
    end

    local swapped, swapData = swapLauncherToLoaded(weapon, launcherPart, profile)
    if not swapped then
        removeAmmoControllerPart(weapon)
        if inventory.AddItem then
            pcall(inventory.AddItem, inventory, ammoType)
        end
        logGL("Load rejected: close phase failed launcher=%s reason=%s", tostring(launcherType), tostring(swapData))
        return
    end

    setPreferredAmmoType(weapon, ammoType)
    setLoadedAmmoType(weapon, ammoType)
    logGL("Load success onlineId=%s launcher=%s loaded=%s ammo=%s", tostring(playerObj:getOnlineID()),
        tostring(launcherType), tostring(swapData), tostring(ammoType))
end

local function handleUnloadCommand(playerObj, args)
    local weapon = resolveCommandWeapon(playerObj, args)
    if not weapon then
        logGL("Unload rejected: no ranged weapon onlineId=%s", tostring(playerObj and playerObj:getOnlineID()))
        return
    end

    local _, launcherType, profile, launcherState = resolveLauncher(weapon)
    if not profile then
        logGL("Unload rejected: launcher missing onlineId=%s launcher=%s state=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType), tostring(launcherState))
        return
    end

    local loadedAmmo = getLoadedAmmoType(weapon, profile)
    if not loadedAmmo then
        logGL("Unload rejected: launcher has no chambered ammo onlineId=%s launcher=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType))
        return
    end

    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        logGL("Unload rejected: inventory missing onlineId=%s", tostring(playerObj:getOnlineID()))
        return
    end

    if not removeAmmoControllerPart(weapon) then
        logGL("Unload rejected: failed to remove ammo controller onlineId=%s launcher=%s",
            tostring(playerObj:getOnlineID()), tostring(launcherType))
        return
    end

    if inventory.AddItem then
        pcall(inventory.AddItem, inventory, loadedAmmo)
    end

    setPreferredAmmoType(weapon, loadedAmmo)
    logGL("Unload success onlineId=%s launcher=%s ammo=%s state=%s", tostring(playerObj:getOnlineID()),
        tostring(launcherType), tostring(loadedAmmo), tostring(launcherState))
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE_NAME then
        return
    end

    if not playerObj then
        logGL("Command rejected: player=nil command=%s", tostring(command))
        return
    end

    if command == COMMAND_FIRE then
        handleFireCommand(playerObj, args)
        return
    end

    if command == COMMAND_LOAD then
        handleLoadCommand(playerObj, args)
        return
    end

    if command == COMMAND_UNLOAD then
        handleUnloadCommand(playerObj, args)
        return
    end
end

local function onTick()
    local hasPendingImpacts = #pendingImpacts > 0
    local hasTrapCleanups = #activeTrapProxyCleanups > 0
    if (not hasPendingImpacts) and (not hasTrapCleanups) then
        return
    end

    local dt = getDeltaTime()
    if hasPendingImpacts then
        for i = #pendingImpacts, 1, -1 do
            local pending = pendingImpacts[i]
            local impactSquare, reason = advancePendingImpact(pending, dt)
            if impactSquare then
                pending.targetX = impactSquare:getX()
                pending.targetY = impactSquare:getY()
                pending.targetZ = impactSquare:getZ()
                if DEBUG_GL then
                    logGL("Impact resolved stamp=%s launcher=%s reason=%s square=%d,%d,%d",
                        tostring(pending.stamp), tostring(pending.launcherType), tostring(reason), impactSquare:getX(),
                        impactSquare:getY(), impactSquare:getZ())
                end
                detonatePendingImpact(pending)
                table.remove(pendingImpacts, i)
            end
        end
    end
    cleanupTrapProxyCleanups(dt)
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(onTick)
