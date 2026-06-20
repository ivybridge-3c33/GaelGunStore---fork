if isServer() then
    return
end

if __GGS_GL_CLIENT_MODULE_LOADED then
    return
end
__GGS_GL_CLIENT_MODULE_LOADED = true

pcall(require, "ISUI/ISRadialMenu")
pcall(require, "TimedActions/ISBaseTimedAction")

local MODULE_NAME = "GGS_GL"
local COMMAND_FIRE = "Fire"
local COMMAND_LOAD = "Load"
local COMMAND_UNLOAD = "Unload"
COMMAND_STANDALONE_STATE = "StandaloneState"
local COMMAND_EXPLOSION_FX = "ExplosionFX"
local COMMAND_PROJECTILE_FX = "ProjectileFX"

local function ggsText(key)
    local text = getText(key)
    if text and text ~= key then
        return text
    end
    return key
end

local DEBUG_GL = false
local MAX_TARGET_DISTANCE = 24.0
local CLIENT_FIRE_COOLDOWN = 0.25
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
local FX_MARKER_LIFETIME = 0.30
local FX_ANIM_FRAME_STEP = 0.16
local FX_ANIM_START_RATIO = 0.50
local FX_MARKER_OFFSET_X = 0
local FX_MARKER_OFFSET_Y = 0
local FX_MARKER_OFFSET_Z = 0
local PROJECTILE_ENABLED = true
local PROJECTILE_SPEED_TILES_PER_SEC = 15.0
local PROJECTILE_MIN_FLIGHT_TIME = 0.18
local PROJECTILE_MAX_FLIGHT_TIME = 1.40
local PROJECTILE_MARKER_TTL = 0.30
local PROJECTILE_TEXTURE_PATH = "media/textures/effects/Ammo_spr.png"
local PROJECTILE_WORLD_ITEM_FULLTYPE = "Base.GrenadeAmmo"
local PROJECTILE_WORLD_ITEM_SCALE = 1.25
local PROJECTILE_WORLD_Z_BIAS = 0.70
local PROJECTILE_WORLD_ITEM_OZ_MAX = 0.95
local EXPLOSION_SOUND_EVENT = "PipeBombExplode"
local RELOAD_ACTION_BASE_TIME = 42
local RELOAD_HOLD_MENU_DELAY_MS = 300
local RELOAD_ANIM_ACTION = CharacterActionAnims and CharacterActionAnims.Reload or "Reload"
local RELOAD_ANIM_TYPE = "ggs_gl_launcher"
local MODDATA_SELECTED_AMMO = "ggsGLSelectedAmmoType"
local MODDATA_LOADED_AMMO = "ggsGLLoadedAmmoType"
local MODDATA_STANDALONE_AMMO_COUNT = "ggsGLStandaloneAmmoCount"
local STAMP_TTL = 6.0
local AMMO_PART_SLOT = "Ammo"
local AMMO_CONTROLLER_PART_FULLTYPE = "Base.GGS_GL_AmmoController"

local DEFAULT_KEY = Keyboard and Keyboard.KEY_G or 34
local DEFAULT_STANDALONE_RELOAD_KEY = Keyboard and Keyboard.KEY_R or 19

local LAUNCHER_PROFILE_BY_FULLTYPE = {
    ["Base.GP30_GL"] = {
        loadedType = "Base.GP30_GL",
        emptyType = "Base.GP30_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    },
    ["Base.GP30_GL_empty"] = {
        loadedType = "Base.GP30_GL",
        emptyType = "Base.GP30_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    },
    ["Base.M203_GL"] = {
        loadedType = "Base.M203_GL",
        emptyType = "Base.M203_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    },
    ["Base.M203_GL_empty"] = {
        loadedType = "Base.M203_GL",
        emptyType = "Base.M203_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    },
    ["Base.M320_GL"] = {
        loadedType = "Base.M320_GL",
        emptyType = "Base.M320_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    },
    ["Base.M320_GL_empty"] = {
        loadedType = "Base.M320_GL",
        emptyType = "Base.M320_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    },
    ["Base.Scar_GL"] = {
        loadedType = "Base.Scar_GL",
        emptyType = "Base.Scar_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "loaded",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    },
    ["Base.Scar_GL_empty"] = {
        loadedType = "Base.Scar_GL",
        emptyType = "Base.Scar_GL_empty",
        ammoType = "Base.GrenadeAmmo",
        state = "empty",
        explosionPower = 100,
        launchSound = "LauncherShoot"
    }
}

-- Lanzadores standalone (arma completa) que usan la misma logica de proyectil/explosion custom.
local STANDALONE_LAUNCHER_PROFILE_BY_WEAPON = {
    ["Base.M79"] = {
        id = "M79",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        launchSound = "LauncherShoot",
        useStandaloneAmmoCount = true,
        capacity = 1,
        mpSupported = true
    },
    ["Base.GM94"] = {
        id = "GM94",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        launchSound = "LauncherShoot",
        useStandaloneAmmoCount = true,
        capacity = 3,
        mpSupported = true
    },
    ["Base.MLG"] = {
        id = "MLG",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        launchSound = "LauncherShoot",
        useStandaloneAmmoCount = true,
        capacity = 6,
        mpSupported = true
    },
    ["Base.RG6"] = {
        id = "RG6",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        launchSound = "LauncherShoot",
        useStandaloneAmmoCount = true,
        capacity = 6,
        mpSupported = true
    },
    ["Base.ChinaLake"] = {
        id = "ChinaLake",
        ammoType = "Base.GrenadeAmmo",
        explosionPower = 100,
        launchSound = "LauncherShoot",
        useStandaloneAmmoCount = true,
        capacity = 3,
        mpSupported = true
    },
    ["Base.RPG7"] = {
        id = "RPG7",
        ammoType = "Base.RPG7_RocketAmmo",
        explosionPower = 140,
        launchSound = "LauncherShoot",
        useStandaloneAmmoCount = true,
        capacity = 1,
        mpSupported = true,
        ammoPartType = "Base.AMMO_rocket_part",
        ammoVisualPartSlot = "AMMO",
        deferVisualInstallUntilReloadEnds = true
    }
}

-- Payloads de municion desacoplan "launcher" de "efecto en impacto".
-- Escalable para HE / incendiaria / humo / rockets sin duplicar logica del GL.
local GL_AMMO_PAYLOAD_BY_FULLTYPE = {
    ["Base.GrenadeAmmo"] = {
        id = "40mm_HE",
        explosionPower = 100,
        explosionSound = "PipeBombExplode",
        physicsHitReaction = "PipeBomb",
        damageWeaponType = "Base.HE_explosion",
        damageRadius = 4.0,
        lethalRadius = 1.25,
        maxDamage = 120,
        minDamage = 18,
        physicsBlastPowerScale = 1.00,
        trapProxyMode = "tick1",
        trapProxyTimer = 1,
        trapProxyCleanupTTL = 1.50
    },
    ["Base.GrenadeAmmo_incendiary"] = {
        id = "40mm_Incendiary",
        explosionPower = 90,
        explosionSound = "PipeBombExplode",
        physicsHitReaction = "PipeBomb",
        damageWeaponType = "Base.HE_explosion",
        damageRadius = 3.4,
        lethalRadius = 0.80,
        maxDamage = 42,
        minDamage = 8,
        physicsBlastPowerScale = 1.00,
        trapProxyMode = "tick1",
        trapProxyTimer = 1,
        trapProxyCleanupTTL = 1.50,
        firePowerScale = 0.10,
        damagePowerScale = 0.20
    },
    ["Base.RPG7_RocketAmmo"] = {
        id = "RPG7_HE",
        explosionPower = 140,
        explosionSound = "PipeBombExplode",
        physicsHitReaction = "PipeBomb",
        damageWeaponType = "Base.Rocket_explosion",
        damageRadius = 4.8,
        lethalRadius = 1.70,
        maxDamage = 180,
        minDamage = 28,
        physicsBlastPowerScale = 1.10,
        trapProxyMode = "tick1",
        trapProxyTimer = 1,
        trapProxyCleanupTTL = 1.50,
        firePowerScale = 0.08,
        damagePowerScale = 0.30
    }
}

local FX_TEXTURE_PATHS = {
    "media/textures/effects/explosionG_0.png",
    "media/textures/effects/explosionG_1.png",
    "media/textures/effects/explosionG_2.png",
    "media/textures/effects/explosionG_3.png",
    "media/textures/effects/explosionG_4.png",
    "media/textures/effects/explosionG_5.png",
    "media/textures/effects/explosionG_6.png",
    "media/textures/effects/explosionG_7.png",
    "media/textures/effects/explosionG_8.png",
    "media/textures/effects/explosionG_9.png"
}

local loadedFxTextureNames = nil
local activeExplosionMarkers = {}
local projectileTextureName = nil
local activeProjectileMarkers = {}
local activeTrapProxyCleanups = {}
local pendingImpacts = {}
local seenStamps = {}
local projectileStamps = {}
local fireCooldown = 0.0
local keyHandlerRegistered = false
local weaponSwingHandlerRegistered = false
__GGS_GL_PLAYER_ATTACK_FINISHED_HANDLER_REGISTERED = __GGS_GL_PLAYER_ATTACK_FINISHED_HANDLER_REGISTERED or false
local serverHandlerRegistered = false
local tickHandlerRegistered = false
local timedActionClassReady = false
local gKeyHoldState = {
    pressedMs = nil,
    consumedByRadial = false
}
local standaloneReloadKeyDebounceUntilMs = 0
local distance2D = nil
getScaledFireExplosionPower = nil
getScaledDamagePower = nil
getPhysicsBlastPower = nil
resolveImpactPayload = nil

local function logGL(fmt, ...)
    if not DEBUG_GL then
        return
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if ok then
        print("[GGS GLDBG] " .. msg)
    else
        print("[GGS GLDBG] " .. tostring(fmt))
    end
end

logGL("Client grenade launcher module loaded")

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

resolveImpactPayload = function(ammoType, profile)
    local normalizedAmmo = normalizeFullType(ammoType) or normalizeFullType(profile and profile.ammoType) or "Base.GrenadeAmmo"
    local payload = GL_AMMO_PAYLOAD_BY_FULLTYPE[normalizedAmmo] or nil
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100

    return {
        ammoType = normalizedAmmo,
        id = tostring(payload and payload.id or normalizedAmmo),
        explosionPower = basePower,
        explosionSound = tostring(payload and payload.explosionSound or EXPLOSION_SOUND_EVENT or ""),
        physicsHitReaction = tostring(payload and payload.physicsHitReaction or "PipeBomb"),
        damageWeaponType = normalizeFullType(payload and payload.damageWeaponType) or "Base.PipeBomb",
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

local function nowSeconds()
    if GameTime and GameTime.getInstance then
        local gt = GameTime.getInstance()
        if gt and gt.getWorldAgeHours then
            return gt:getWorldAgeHours() * 3600.0
        end
    end
    return os.time()
end

local function buildStamp(playerObj)
    local onlineId = -1
    if playerObj and playerObj.getOnlineID then
        onlineId = playerObj:getOnlineID()
    end
    return string.format("%0.3f-%s-%06d", nowSeconds(), tostring(onlineId), ZombRand(1000000))
end

local function getLaunchKey()
    local core = getCore and getCore() or nil
    if core and core.getKey then
        local key = core:getKey("LauchGrenadelauncherat")
        if key and key > 0 then
            return key
        end
    end
    return DEFAULT_KEY
end

local function getStandaloneReloadKey()
    -- El usuario pidio R para RPG7 standalone; dejamos fallback directo a la tecla R.
    return DEFAULT_STANDALONE_RELOAD_KEY
end

local function isLaunchKeyDown()
    local key = getLaunchKey()
    if isKeyDown then
        local ok, down = pcall(isKeyDown, key)
        if ok then
            return down == true
        end
    end
    if Keyboard and Keyboard.isKeyDown then
        local ok, down = pcall(Keyboard.isKeyDown, key)
        if ok then
            return down == true
        end
    end
    return false
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

local function roundToGrid(value)
    if not value then
        return 0
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function ggsGLSquareBlockedBetween(a, b)
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

function ggsGLResolveImpactSquare(startX, startY, startZ, targetSquare)
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
            if ggsGLSquareBlockedBetween(prevSq, sq) or ggsGLSquareBlockedBetween(sq, prevSq) then
                local impactSq = prevSq or targetSquare
                local impactDist = distance2D(startX, startY, impactSq:getX() + 0.5, impactSq:getY() + 0.5)
                return impactSq, impactDist
            end
        end
        prevSq = sq or prevSq
    end

    return targetSquare, dist
end

local function clamp01(value)
    if not value then
        return 0.0
    end
    if value < 0.0 then
        return 0.0
    end
    if value > 0.99 then
        return 0.99
    end
    return value
end

local function isPlayerAiming(playerObj)
    if not playerObj then
        return false
    end
    if not playerObj.isAiming then
        return false
    end
    local ok, aiming = pcall(playerObj.isAiming, playerObj)
    if not ok then
        return false
    end
    return aiming == true
end

local function getNowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    return math.floor(nowSeconds() * 1000)
end

local function hasQueuedTimedAction(playerObj)
    if not (playerObj and ISTimedActionQueue and ISTimedActionQueue.queues) then
        return false
    end
    local queue = ISTimedActionQueue.queues[playerObj]
    return queue and queue.queue and #queue.queue > 0
end

local function getWeaponModData(weapon)
    if not (weapon and weapon.getModData) then
        return nil
    end
    return weapon:getModData()
end

local function shortTypeName(fullType)
    local norm = normalizeFullType(fullType)
    if not norm then
        return nil
    end
    return norm:gsub("^Base%.", "")
end

local function getWeaponFullType(weapon)
    if not (weapon and weapon.getFullType) then
        return nil
    end
    return normalizeFullType(weapon:getFullType())
end

function resolveStandaloneLauncherProfile(weapon)
    local weaponType = getWeaponFullType(weapon)
    if not weaponType then
        return nil, nil
    end
    return STANDALONE_LAUNCHER_PROFILE_BY_WEAPON[weaponType], weaponType
end

function isStandaloneAmmoCountProfile(profile)
    return profile and profile.useStandaloneAmmoCount == true
end

function getStandaloneAmmoCapacity(profile)
    return math.max(1, math.floor(tonumber(profile and profile.capacity) or 1))
end

function getStandaloneAmmoCount(weapon, profile)
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

function setStandaloneAmmoCount(weapon, profile, ammoCount)
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

function isStandaloneMpSupported(profile)
    return profile and profile.mpSupported == true
end

local function getPreferredAmmoType(weapon, profile)
    local md = getWeaponModData(weapon)
    local selected = md and normalizeFullType(md[MODDATA_SELECTED_AMMO]) or nil
    if selected then
        return selected
    end
    local fallback = profile and profile.ammoType or "Base.GrenadeAmmo"
    return normalizeFullType(fallback)
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
    local marker = md.weaponpart[AMMO_PART_SLOT]
    return marker ~= nil and marker ~= ""
end

local function hasAmmoControllerPart(weapon)
    return getAmmoControllerPart(weapon) ~= nil or hasAmmoControllerMarker(weapon)
end

local function getLoadedAmmoType(weapon, profile)
    local md = getWeaponModData(weapon)
    local loaded = md and normalizeFullType(md[MODDATA_LOADED_AMMO]) or nil
    if isStandaloneAmmoCountProfile(profile) then
        if getStandaloneAmmoCount(weapon, profile) > 0 then
            return loaded or normalizeFullType(getPreferredAmmoType(weapon, profile) or profile and profile.ammoType or
                "Base.GrenadeAmmo")
        end
        return nil
    end
    if loaded then
        return loaded
    end
    -- Standalone launchers (e.g. RPG7) use explicit modData state and must not
    -- infer "loaded" from parts/markers, or they can become effectively infinite.
    if profile and profile.useModDataLoadStateOnly then
        return nil
    end
    if hasAmmoControllerPart(weapon) then
        return normalizeFullType(getPreferredAmmoType(weapon, profile) or profile and profile.ammoType or "Base.GrenadeAmmo")
    end
    return nil
end

local function setLoadedAmmoType(weapon, ammoType)
    local md = getWeaponModData(weapon)
    if not md then
        return
    end
    md[MODDATA_LOADED_AMMO] = normalizeFullType(ammoType)
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
end

function setLoadedAmmoTypeLocalOnly(weapon, ammoType)
    local md = getWeaponModData(weapon)
    if md then
        md[MODDATA_LOADED_AMMO] = normalizeFullType(ammoType)
    end
end

function setPreferredAmmoTypeLocalOnly(weapon, ammoType)
    local md = getWeaponModData(weapon)
    if md then
        md[MODDATA_SELECTED_AMMO] = normalizeFullType(ammoType)
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

function clearLoadedAmmoTypeLocalOnly(weapon)
    local md = getWeaponModData(weapon)
    if md then
        md[MODDATA_LOADED_AMMO] = nil
    end
end

function setStandaloneAmmoCountLocalOnly(weapon, profile, ammoCount)
    if not isStandaloneAmmoCountProfile(profile) then
        return
    end
    local safeCount = math.max(0, math.floor(tonumber(ammoCount) or 0))
    local md = getWeaponModData(weapon)
    if md then
        md[MODDATA_STANDALONE_AMMO_COUNT] = safeCount
    end
    if weapon and weapon.setCurrentAmmoCount then
        pcall(weapon.setCurrentAmmoCount, weapon, safeCount)
    end
end

local function removeAmmoControllerLocalOnly(weapon)
    if not weapon then
        return
    end
    if weapon.setWeaponPart then
        pcall(weapon.setWeaponPart, weapon, AMMO_PART_SLOT, nil)
    end
    if weapon.clearWeaponPart then
        pcall(weapon.clearWeaponPart, weapon, AMMO_PART_SLOT)
    end
    local md = getWeaponModData(weapon)
    if md and md.weaponpart then
        md.weaponpart[AMMO_PART_SLOT] = nil
    end
    clearLoadedAmmoTypeLocalOnly(weapon)
end

local function installAmmoControllerPart(weapon, ammoType, partTypeOverride)
    if not weapon then
        return false
    end

    local partType = normalizeFullType(partTypeOverride or AMMO_CONTROLLER_PART_FULLTYPE) or AMMO_CONTROLLER_PART_FULLTYPE
    local installed = false
    if weapon.setWeaponPart and instanceItem then
        local part = instanceItem(partType)
        if part then
            installed = pcall(weapon.setWeaponPart, weapon, AMMO_PART_SLOT, part)
        end
    end

    local markerSet = false
    local md = getWeaponModData(weapon)
    if md then
        md.weaponpart = md.weaponpart or {}
        md.weaponpart[AMMO_PART_SLOT] = partType
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

local function installWeaponPartOnSlot(weapon, slotName, partType)
    local slot = tostring(slotName or "")
    local fullType = normalizeFullType(partType)
    if not weapon or slot == "" or not fullType then
        return false
    end
    if not (weapon.setWeaponPart and instanceItem) then
        return false
    end

    local part = instanceItem(fullType)
    if not part then
        return false
    end

    local ok, applied = pcall(weapon.setWeaponPart, weapon, slot, part)
    if not ok then
        return false
    end
    if applied == false then
        return false
    end

    local mountedMatches = false
    local mounted = weapon.getWeaponPart and weapon:getWeaponPart(slot) or nil
    if mounted and mounted.getFullType and normalizeFullType(mounted:getFullType()) == fullType then
        mountedMatches = true
    end

    local md = getWeaponModData(weapon)
    local markerSet = false
    if md then
        md.weaponpart = md.weaponpart or {}
        md.weaponpart[slot] = fullType
        markerSet = true
    end
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
    return mountedMatches or markerSet
end

local function removeWeaponPartFromSlot(weapon, slotName)
    local slot = tostring(slotName or "")
    if not weapon or slot == "" then
        return false
    end

    local hadMarker = false
    local md = getWeaponModData(weapon)
    if md and md.weaponpart and md.weaponpart[slot] ~= nil and md.weaponpart[slot] ~= "" then
        hadMarker = true
    end
    if slot == "AMMO" then
        debugRpg7VisualState("remove-slot-before", weapon)
    end

    local removed = false
    if weapon.setWeaponPart then
        removed = pcall(weapon.setWeaponPart, weapon, slot, nil) or removed
    end
    if weapon.clearWeaponPart then
        removed = pcall(weapon.clearWeaponPart, weapon, slot) or removed
    end

    if md and md.weaponpart then
        md.weaponpart[slot] = nil
    end
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
    if slot == "AMMO" then
        logGL("RPG7 remove slot=%s removed=%s hadMarker=%s", tostring(slot), tostring(removed), tostring(hadMarker))
        debugRpg7VisualState("remove-slot-after", weapon)
    end
    return removed or hadMarker
end

function refreshEquippedWeaponVisual(playerObj)
    if not playerObj then
        return
    end
    if playerObj.resetEquippedHandsModels then
        pcall(playerObj.resetEquippedHandsModels, playerObj)
    end
    if playerObj.resetModelNextFrame then
        pcall(playerObj.resetModelNextFrame, playerObj)
    end
end

function debugRpg7VisualState(label, weapon)
    if not DEBUG_GL then
        return
    end
    if (getWeaponFullType and getWeaponFullType(weapon) or nil) ~= "Base.RPG7" then
        return
    end

    local md = getWeaponModData(weapon)
    local loadedAmmo = md and normalizeFullType(md[MODDATA_LOADED_AMMO]) or nil
    local markerAmmo = md and md.weaponpart and normalizeFullType(md.weaponpart["Ammo"]) or nil
    local markerAMMO = md and md.weaponpart and normalizeFullType(md.weaponpart["AMMO"]) or nil
    local markerClip = md and md.weaponpart and normalizeFullType(md.weaponpart["Clip"]) or nil
    local realAmmo = nil
    local realAMMO = nil
    local realClip = nil

    if weapon and weapon.getWeaponPart then
        local ok1, p1 = pcall(weapon.getWeaponPart, weapon, "Ammo")
        if ok1 and p1 and p1.getFullType then
            realAmmo = normalizeFullType(p1:getFullType())
        end
        local ok2, p2 = pcall(weapon.getWeaponPart, weapon, "AMMO")
        if ok2 and p2 and p2.getFullType then
            realAMMO = normalizeFullType(p2:getFullType())
        end
        local ok3, p3 = pcall(weapon.getWeaponPart, weapon, "Clip")
        if ok3 and p3 and p3.getFullType then
            realClip = normalizeFullType(p3:getFullType())
        end
    end

    logGL("RPG7 state [%s] loaded=%s mAmmo=%s mAMMO=%s mClip=%s rAmmo=%s rAMMO=%s rClip=%s",
        tostring(label), tostring(loadedAmmo), tostring(markerAmmo), tostring(markerAMMO), tostring(markerClip),
        tostring(realAmmo), tostring(realAMMO), tostring(realClip))
end

function getStandaloneVisualPartSlots(profile)
    local out = {}
    local seen = {}

    local function add(slot)
        slot = tostring(slot or "")
        if slot == "" or seen[slot] then
            return
        end
        seen[slot] = true
        out[#out + 1] = slot
    end

    add(profile and profile.ammoVisualPartSlot)
    add("AMMO")
    add("Clip")
    return out
end

function weaponHasPartOnSlot(weapon, slotName, expectedPartType)
    if not (weapon and weapon.getWeaponPart) then
        return false
    end
    local slot = tostring(slotName or "")
    if slot == "" then
        return false
    end
    local ok, part = pcall(weapon.getWeaponPart, weapon, slot)
    if not ok then
        part = nil
    end
    local expected = normalizeFullType(expectedPartType)
    if part and part.getFullType then
        if not expected then
            return true
        end
        if normalizeFullType(part:getFullType()) == expected then
            return true
        end
    end

    local md = getWeaponModData(weapon)
    local marker = md and md.weaponpart and normalizeFullType(md.weaponpart[slot]) or nil
    if not marker then
        return false
    end
    if not expected then
        return true
    end
    return marker == expected
end

local removeAmmoControllerPart = nil

function syncStandaloneLauncherVisualPart(playerObj, weapon, profile)
    if not (weapon and profile) then
        return false
    end
    local partType = normalizeFullType(profile.ammoPartType)
    if not partType then
        return false
    end
    local slots = getStandaloneVisualPartSlots(profile)
    if #slots == 0 then
        return false
    end

    local loaded = getLoadedAmmoType(weapon, profile) ~= nil
    local hasVisual = false
    for i = 1, #slots do
        if weaponHasPartOnSlot(weapon, slots[i], partType) then
            hasVisual = true
            break
        end
    end
    local changed = false

    if loaded and (not hasVisual) and profile.deferVisualInstallUntilReloadEnds and playerObj and hasQueuedTimedAction and
        hasQueuedTimedAction(playerObj) then
        if profile.id == "RPG7" then
            logGL("RPG7 sync install deferred: timed action queue busy")
        end
        return false
    end

    if loaded and not hasVisual then
        if profile.id == "RPG7" then
            debugRpg7VisualState("sync-install-before", weapon)
        end
        for i = 1, #slots do
            local slot = slots[i]
            if installWeaponPartOnSlot(weapon, slot, partType) then
                changed = true
                if profile.id == "RPG7" then
                    logGL("RPG7 sync install slot=%s ok=true", tostring(slot))
                end
                break
            elseif profile.id == "RPG7" then
                logGL("RPG7 sync install slot=%s ok=false", tostring(slot))
            end
        end
        if profile.id == "RPG7" then
            debugRpg7VisualState("sync-install-after", weapon)
        end
    elseif (not loaded) and hasVisual then
        if profile.id == "RPG7" then
            debugRpg7VisualState("sync-remove-before", weapon)
        end
        for i = 1, #slots do
            local removedThis = removeWeaponPartFromSlot(weapon, slots[i]) or false
            if profile.id == "RPG7" then
                logGL("RPG7 sync remove slot=%s removed=%s", tostring(slots[i]), tostring(removedThis))
            end
            changed = removedThis or changed
        end
        if profile.id == "RPG7" then
            debugRpg7VisualState("sync-remove-after", weapon)
        end
    end

    if changed then
        refreshEquippedWeaponVisual(playerObj)
        if profile.id == "RPG7" then
            logGL("RPG7 sync refresh changed=%s loaded=%s", tostring(changed), tostring(loaded))
        end
    end

    return changed
end

function syncStandaloneLauncherState(playerObj, weapon, profile)
    if not (weapon and profile) then
        return false
    end

    local changed = false
    if isStandaloneAmmoCountProfile(profile) then
        local capacity = getStandaloneAmmoCapacity(profile)
        local liveCount = getStandaloneAmmoCount(weapon, profile)
        local md = getWeaponModData(weapon)
        local mdCount = tonumber(md and md[MODDATA_STANDALONE_AMMO_COUNT]) or 0
        local liveMax = nil
        if weapon.getMaxAmmo then
            local okMax, value = pcall(weapon.getMaxAmmo, weapon)
            if okMax then
                liveMax = tonumber(value) or 0
            end
        end

        if md and mdCount ~= liveCount then
            md[MODDATA_STANDALONE_AMMO_COUNT] = liveCount
            if weapon.transmitModData then
                pcall(weapon.transmitModData, weapon)
            end
            changed = true
        end
        if liveMax ~= capacity and weapon.setMaxAmmo then
            pcall(weapon.setMaxAmmo, weapon, capacity)
            changed = true
        end
        if profile.id == "RPG7" and hasAmmoControllerPart(weapon) then
            removeAmmoControllerPart(weapon)
            changed = true
        end
        if liveCount <= 0 and md and md[MODDATA_LOADED_AMMO] ~= nil then
            clearLoadedAmmoType(weapon)
            changed = true
        elseif liveCount > 0 then
            local desiredAmmoType = normalizeFullType(profile.ammoType)
            if md and normalizeFullType(md[MODDATA_LOADED_AMMO]) ~= desiredAmmoType then
                setLoadedAmmoType(weapon, desiredAmmoType)
                changed = true
            end
        end
    end

    if profile.ammoPartType then
        local visualChanged = syncStandaloneLauncherVisualPart(playerObj, weapon, profile)
        changed = visualChanged or changed
    end

    return changed
end

removeAmmoControllerPart = function(weapon)
    if not weapon then
        return false
    end
    debugRpg7VisualState("remove-controller-before", weapon)

    local removed = false
    if weapon.setWeaponPart then
        removed = pcall(weapon.setWeaponPart, weapon, AMMO_PART_SLOT, nil) or removed
    end
    if weapon.clearWeaponPart then
        removed = pcall(weapon.clearWeaponPart, weapon, AMMO_PART_SLOT) or removed
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
    if getWeaponFullType and getWeaponFullType(weapon) == "Base.RPG7" then
        logGL("RPG7 remove controller result removed=%s cleared=%s", tostring(removed), tostring(cleared))
    end
    debugRpg7VisualState("remove-controller-after", weapon)

    return removed or cleared
end

local function hasChamberedAmmo(weapon, profile)
    return getLoadedAmmoType(weapon, profile) ~= nil
end

local function ensureFxTextures()
    if loadedFxTextureNames and #loadedFxTextureNames > 0 then
        return loadedFxTextureNames
    end

    loadedFxTextureNames = {}
    for _, path in ipairs(FX_TEXTURE_PATHS) do
        local tex = getTexture(path)
        if tex and tex.getName then
            table.insert(loadedFxTextureNames, tex:getName())
        else
            logGL("FX texture missing: %s", tostring(path))
        end
    end

    logGL("FX textures loaded=%d", #loadedFxTextureNames)
    return loadedFxTextureNames
end

local function ensureProjectileTextureName()
    if projectileTextureName then
        return projectileTextureName
    end
    local tex = getTexture and getTexture(PROJECTILE_TEXTURE_PATH) or nil
    if tex and tex.getName then
        projectileTextureName = tex:getName()
        logGL("Projectile texture loaded=%s", tostring(projectileTextureName))
    else
        projectileTextureName = nil
        logGL("Projectile texture missing path=%s", tostring(PROJECTILE_TEXTURE_PATH))
    end
    return projectileTextureName
end

local function markStampSeen(stamp)
    if not stamp or stamp == "" then
        return
    end
    seenStamps[tostring(stamp)] = STAMP_TTL
end

local function isStampSeen(stamp)
    if not stamp or stamp == "" then
        return false
    end
    return seenStamps[tostring(stamp)] ~= nil
end

local function updateSeenStamps(dt)
    for stamp, ttl in pairs(seenStamps) do
        ttl = ttl - dt
        if ttl <= 0 then
            seenStamps[stamp] = nil
        else
            seenStamps[stamp] = ttl
        end
    end
end

local function markProjectileStampSeen(stamp)
    if not stamp or stamp == "" then
        return
    end
    projectileStamps[tostring(stamp)] = STAMP_TTL
end

local function isProjectileStampSeen(stamp)
    if not stamp or stamp == "" then
        return false
    end
    return projectileStamps[tostring(stamp)] ~= nil
end

local function updateProjectileStamps(dt)
    for stamp, ttl in pairs(projectileStamps) do
        ttl = ttl - dt
        if ttl <= 0 then
            projectileStamps[stamp] = nil
        else
            projectileStamps[stamp] = ttl
        end
    end
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

local function getMarkerSquare(baseSquare)
    if not baseSquare then
        return nil
    end

    local markerX = baseSquare:getX() + FX_MARKER_OFFSET_X
    local markerY = baseSquare:getY() + FX_MARKER_OFFSET_Y
    local markerZ = baseSquare:getZ() + FX_MARKER_OFFSET_Z
    local markerSquare = getCell():getGridSquare(markerX, markerY, markerZ)
    if markerSquare then
        return markerSquare
    end

    return baseSquare
end

local function playExplosionSoundAtSquare(square, soundName)
    if not square then
        return
    end

    local eventName = soundName
    if not eventName or eventName == "" then
        eventName = EXPLOSION_SOUND_EVENT
    end
    if not eventName or eventName == "" then
        return
    end

    local soundManager = getSoundManager and getSoundManager() or nil
    if soundManager and soundManager.PlayWorldSound then
        pcall(soundManager.PlayWorldSound, soundManager, eventName, square, 0, 0, 0, false)
        return
    end

    if square.playSound then
        pcall(square.playSound, square, eventName)
    end
end

local function addExplosionMarker(square, stamp, soundName)
    if not square then
        return
    end

    playExplosionSoundAtSquare(square, soundName)

    local markers = getIsoMarkers and getIsoMarkers() or nil
    if not (markers and markers.addIsoMarker) then
        logGL("addExplosionMarker failed: getIsoMarkers unavailable")
        return
    end

    local markerSquare = getMarkerSquare(square)
    if not markerSquare then
        logGL("addExplosionMarker failed: markerSquare=nil")
        return
    end

    local fxNames = ensureFxTextures()
    local marker = nil
    local x, y, z = markerSquare:getX(), markerSquare:getY(), markerSquare:getZ()

    if #fxNames > 0 then
        local startFrame = math.max(1, math.floor((#fxNames * FX_ANIM_START_RATIO) + 0.5))
        if startFrame > #fxNames then
            startFrame = #fxNames
        end

        marker = markers:addIsoMarker(fxNames[startFrame], markerSquare, 1.0, 1.0, 1.0, 1.0)
        if marker then
            table.insert(activeExplosionMarkers, {
                marker = marker,
                x = x,
                y = y,
                z = z,
                frame = startFrame,
                frameTime = 0.0,
                frameStep = FX_ANIM_FRAME_STEP,
                frameNames = fxNames
            })
        end
    else
        marker = markers:addIsoMarker(FX_TEXTURE_PATHS[1], markerSquare, 1.0, 1.0, 1.0, 1.0)
        if marker then
            table.insert(activeExplosionMarkers, {
                marker = marker,
                ttl = FX_MARKER_LIFETIME
            })
        end
    end

    if marker then
        logGL("Explosion marker created stamp=%s square=%d,%d,%d src=%d,%d,%d", tostring(stamp), x, y, z,
            square:getX(), square:getY(), square:getZ())
    else
        logGL("Explosion marker creation failed stamp=%s square=%d,%d,%d src=%d,%d,%d", tostring(stamp), x, y, z,
            square:getX(), square:getY(), square:getZ())
    end
end

local function createProjectileMarkerAt(x, y, z)
    local markers = getIsoMarkers and getIsoMarkers() or nil
    if not (markers and markers.addIsoMarker and getCell) then
        return nil
    end

    local square = getCell():getGridSquare(roundToGrid(x), roundToGrid(y), roundToGrid(z or 0))
    if not square then
        square = getCell():getGridSquare(roundToGrid(x), roundToGrid(y), 0)
    end
    if not square then
        return nil
    end

    local texName = ensureProjectileTextureName()
    if not texName then
        return nil
    end

    return markers:addIsoMarker(texName, square, 1.0, 1.0, 1.0, 1.0), square
end

local function isWorldInventoryObject(obj)
    return obj and obj.getSquare and obj.removeFromSquare and obj.removeFromWorld
end

local function getWorldObjectSquare(obj)
    if not (obj and obj.getSquare) then
        return nil
    end
    local ok, square = pcall(obj.getSquare, obj)
    if ok then
        return square
    end
    return nil
end

local function resolveWorldInventoryObject(rawObj, rawItem)
    if isWorldInventoryObject(rawObj) then
        return rawObj
    end

    if rawObj and rawObj.getWorldItem then
        local ok, worldObj = pcall(rawObj.getWorldItem, rawObj)
        if ok and isWorldInventoryObject(worldObj) then
            return worldObj
        end
    end

    if rawItem and rawItem.getWorldItem then
        local ok, worldObj = pcall(rawItem.getWorldItem, rawItem)
        if ok and isWorldInventoryObject(worldObj) then
            return worldObj
        end
    end

    return nil
end

local function spawnWorldProjectileObject(square, item, ox, oy, oz)
    if not (square and item and square.AddWorldInventoryItem) then
        return nil, item
    end

    local ok, spawned = pcall(square.AddWorldInventoryItem, square, item, ox, oy, oz)
    if not ok then
        return nil, item
    end

    local worldObj = resolveWorldInventoryObject(spawned, item)
    if not worldObj then
        return nil, item
    end

    if spawned and spawned.getWorldItem then
        return worldObj, spawned
    end

    return worldObj, item
end

local function removeWorldProjectileObject(worldObj, fallbackSquare)
    local obj = resolveWorldInventoryObject(worldObj, nil)
    if not obj then
        return false
    end

    local removed = false
    local square = getWorldObjectSquare(obj) or fallbackSquare
    if square and square.removeWorldObject then
        local ok = pcall(square.removeWorldObject, square, obj)
        if ok then
            removed = true
        end
    end
    if obj.removeFromSquare then
        local ok = pcall(obj.removeFromSquare, obj)
        if ok then
            removed = true
        end
    end
    if obj.removeFromWorld then
        local ok = pcall(obj.removeFromWorld, obj)
        if ok then
            removed = true
        end
    end

    return removed
end

local function createProjectileWorldObjectAt(x, y, z, ammoType, vx, vy)
    if not getCell then
        return nil
    end

    local itemType = normalizeFullType(ammoType or PROJECTILE_WORLD_ITEM_FULLTYPE) or PROJECTILE_WORLD_ITEM_FULLTYPE
    local item = instanceItem and instanceItem(itemType) or nil
    if not item and itemType ~= PROJECTILE_WORLD_ITEM_FULLTYPE and instanceItem then
        itemType = PROJECTILE_WORLD_ITEM_FULLTYPE
        item = instanceItem(itemType)
    end
    if not item then
        return nil
    end

    if item.setWorldScale then
        pcall(item.setWorldScale, item, PROJECTILE_WORLD_ITEM_SCALE)
    end
    if item.setWorldZRotation then
        pcall(item.setWorldZRotation, item, math.deg(math.atan2(vy or 0.0, vx or 1.0)))
    end

    local gz = math.floor(z or 0)
    local gx = math.floor(x)
    local gy = math.floor(y)
    local square = getCell():getGridSquare(gx, gy, gz)
    if not square then
        square = getCell():getGridSquare(gx, gy, 0)
    end
    if not square then
        return nil
    end

    local ox = clamp01(x - square:getX())
    local oy = clamp01(y - square:getY())
    local oz = math.max(0.0, math.min(PROJECTILE_WORLD_ITEM_OZ_MAX, (z or 0) - square:getZ()))

    local obj, spawnedItem = spawnWorldProjectileObject(square, item, ox, oy, oz)
    if not obj then
        return nil
    end

    local objSquare = getWorldObjectSquare(obj) or square
    return {
        mode = "world",
        worldObj = obj,
        worldItem = spawnedItem or item,
        worldSquare = objSquare,
        x = objSquare:getX(),
        y = objSquare:getY(),
        z = objSquare:getZ(),
        itemType = itemType
    }
end

local function removeProjectileVisual(entry)
    if not entry then
        return
    end

    entry.worldObj = resolveWorldInventoryObject(entry.worldObj, entry.worldItem)
    if entry.worldObj then
        removeWorldProjectileObject(entry.worldObj, entry.worldSquare)
    end
    if entry.marker and entry.marker.remove then
        pcall(entry.marker.remove, entry.marker)
    end

    entry.worldObj = nil
    entry.worldSquare = nil
    entry.renderItem = nil
    entry.renderSquare = nil
    entry.marker = nil
end

local function moveProjectileWorldObject(entry, px, py, pz, vx, vy)
    if not (entry and entry.worldItem and getCell) then
        return false
    end

    entry.worldObj = resolveWorldInventoryObject(entry.worldObj, entry.worldItem)
    entry.worldSquare = getWorldObjectSquare(entry.worldObj) or entry.worldSquare

    local gz = math.floor(pz or 0)
    local gx = math.floor(px)
    local gy = math.floor(py)
    local square = getCell():getGridSquare(gx, gy, gz)
    if not square then
        square = getCell():getGridSquare(gx, gy, 0)
    end
    if not square then
        return false
    end

    local ox = clamp01(px - square:getX())
    local oy = clamp01(py - square:getY())
    local oz = math.max(0.0, math.min(PROJECTILE_WORLD_ITEM_OZ_MAX, (pz or 0) - square:getZ()))

    local needsRespawn = (entry.worldSquare ~= square) or (entry.worldObj == nil)
    if not needsRespawn and entry.worldObj.setOffset then
        local ok = pcall(entry.worldObj.setOffset, entry.worldObj, ox, oy, oz)
        if not ok then
            needsRespawn = true
        end
    elseif not needsRespawn then
        needsRespawn = true
    end

    if needsRespawn then
        removeWorldProjectileObject(entry.worldObj, entry.worldSquare)

        local nextObj, nextItem = spawnWorldProjectileObject(square, entry.worldItem, ox, oy, oz)
        if not nextObj then
            return false
        end

        entry.worldObj = nextObj
        entry.worldItem = nextItem or entry.worldItem
        entry.worldSquare = getWorldObjectSquare(nextObj) or square
    end

    if entry.worldItem and entry.worldItem.setWorldZRotation then
        pcall(entry.worldItem.setWorldZRotation, entry.worldItem, math.deg(math.atan2(vy or 0.0, vx or 1.0)))
    end

    entry.x = square:getX()
    entry.y = square:getY()
    entry.z = square:getZ()
    return true
end

local function moveProjectileMarker(entry, gx, gy, gz, markers)
    if not (entry and entry.marker) then
        return false
    end

    local markerExpired = entry.marker.isRemoved and entry.marker:isRemoved()
    if markerExpired then
        return false
    end

    if gx ~= entry.x or gy ~= entry.y or gz ~= entry.z then
        if entry.marker.remove then
            pcall(entry.marker.remove, entry.marker)
        end

        local nextMarker = nil
        if markers and markers.addIsoMarker and getCell then
            local square = getCell():getGridSquare(gx, gy, gz)
            if not square then
                square = getCell():getGridSquare(gx, gy, 0)
            end
            if square then
                local texName = ensureProjectileTextureName()
                if texName then
                    nextMarker = markers:addIsoMarker(texName, square, 1.0, 1.0, 1.0, 1.0)
                end
            end
        end

        if not nextMarker then
            return false
        end

        entry.marker = nextMarker
        entry.x = gx
        entry.y = gy
        entry.z = gz
    end

    return true
end

local function createProjectileVisualAt(x, y, z, ammoType, vx, vy)
    -- En MP, dibujar el item con Render3DItem evita spawnear WorldInventoryItem reales.
    if isClient() then
        local itemType = normalizeFullType(ammoType or PROJECTILE_WORLD_ITEM_FULLTYPE) or PROJECTILE_WORLD_ITEM_FULLTYPE
        local item = instanceItem and instanceItem(itemType) or nil
        if not item and itemType ~= PROJECTILE_WORLD_ITEM_FULLTYPE and instanceItem then
            itemType = PROJECTILE_WORLD_ITEM_FULLTYPE
            item = instanceItem(itemType)
        end
        if item then
            local rotation = math.deg(math.atan2(vy or 0.0, vx or 1.0))
            if item.setWorldScale then
                pcall(item.setWorldScale, item, PROJECTILE_WORLD_ITEM_SCALE)
            end
            if item.setWorldZRotation then
                pcall(item.setWorldZRotation, item, rotation)
            end
            return {
                mode = "render3d",
                renderItem = item,
                renderRotation = rotation,
                x = x,
                y = y,
                z = z,
                itemType = itemType
            }
        end
    else
        local world = createProjectileWorldObjectAt(x, y, z, ammoType, vx, vy)
        if world then
            return world
        end
    end

    local marker, square = createProjectileMarkerAt(x, y, z)
    if not marker then
        return nil
    end

    return {
        mode = "marker",
        marker = marker,
        x = square and square:getX() or roundToGrid(x),
        y = square and square:getY() or roundToGrid(y),
        z = square and square:getZ() or roundToGrid(z)
    }
end

local function queueProjectileVisual(args)
    if not PROJECTILE_ENABLED then
        return
    end
    if not args then
        return
    end

    local stamp = args.stamp and tostring(args.stamp) or ""
    if isProjectileStampSeen(stamp) then
        logGL("Projectile FX duplicate ignored stamp=%s", tostring(stamp))
        return
    end

    local sx = tonumber(args.startX)
    local sy = tonumber(args.startY)
    local sz = tonumber(args.startZ) or 0
    local tx = tonumber(args.targetX)
    local ty = tonumber(args.targetY)
    local tz = tonumber(args.targetZ) or 0
    local ammoType = normalizeFullType(args.ammoType)
    local flightTime = tonumber(args.flightTime)
    if not (sx and sy and tx and ty) then
        logGL("Projectile FX invalid args stamp=%s", tostring(stamp))
        return
    end

    flightTime = math.max(PROJECTILE_MIN_FLIGHT_TIME, tonumber(flightTime) or computeProjectileFlightTime(
        distance2D(sx, sy, tx, ty)))

    local visualStartZ = sz + PROJECTILE_WORLD_Z_BIAS
    local visualTargetZ = tz + PROJECTILE_WORLD_Z_BIAS
    local visual = createProjectileVisualAt(sx, sy, visualStartZ, ammoType, tx - sx, ty - sy)
    if not visual then
        logGL("Projectile FX visual creation failed stamp=%s ammo=%s", tostring(stamp), tostring(ammoType))
        return
    end

    markProjectileStampSeen(stamp)
    local entry = {
        stamp = stamp,
        mode = visual.mode,
        marker = visual.marker,
        worldObj = visual.worldObj,
        worldItem = visual.worldItem,
        worldSquare = visual.worldSquare,
        renderItem = visual.renderItem,
        renderSquare = visual.renderSquare,
        renderRotation = visual.renderRotation,
        itemType = visual.itemType,
        ammoType = ammoType,
        startX = sx,
        startY = sy,
        startZ = visualStartZ,
        targetX = tx,
        targetY = ty,
        targetZ = visualTargetZ,
        duration = flightTime,
        elapsed = 0.0,
        x = visual.x,
        y = visual.y,
        z = visual.z,
        ttl = PROJECTILE_MARKER_TTL
    }
    table.insert(activeProjectileMarkers, entry)

    logGL(
        "Projectile FX queued stamp=%s mode=%s item=%s start=%.2f,%.2f,%.2f target=%.2f,%.2f,%.2f flight=%.2f",
        tostring(stamp), tostring(entry.mode), tostring(entry.itemType or entry.ammoType), sx, sy, sz, tx, ty, tz, flightTime)
end

local function cleanupProjectileMarkers(dt)
    local markers = getIsoMarkers and getIsoMarkers() or nil
    for i = #activeProjectileMarkers, 1, -1 do
        local entry = activeProjectileMarkers[i]
        if entry.mode == "world" then
            entry.worldObj = resolveWorldInventoryObject(entry.worldObj, entry.worldItem)
            entry.worldSquare = getWorldObjectSquare(entry.worldObj) or entry.worldSquare
        end
        local hasVisual = (entry.mode == "world" and entry.worldObj ~= nil) or
            (entry.mode == "render3d" and entry.renderItem ~= nil) or
            (entry.mode ~= "world" and entry.mode ~= "render3d" and entry.marker ~= nil)
        if not hasVisual then
            table.remove(activeProjectileMarkers, i)
        else
            entry.elapsed = (entry.elapsed or 0.0) + dt
            local t = 1.0
            if (entry.duration or 0) > 0 then
                t = math.min(1.0, entry.elapsed / entry.duration)
            end

            local px = entry.startX + ((entry.targetX - entry.startX) * t)
            local py = entry.startY + ((entry.targetY - entry.startY) * t)
            local pz = entry.startZ + ((entry.targetZ - entry.startZ) * t)

            local moved = false
            if entry.mode == "world" then
                moved = moveProjectileWorldObject(entry, px, py, pz, entry.targetX - entry.startX, entry.targetY - entry.startY)
            elseif entry.mode == "render3d" then
                local cell = getCell and getCell() or nil
                if cell then
                    local square = cell:getGridSquare(roundToGrid(px), roundToGrid(py), math.floor(pz or 0))
                    if not square then
                        square = cell:getGridSquare(roundToGrid(px), roundToGrid(py), 0)
                    end
                    if square then
                        entry.renderSquare = square
                        entry.x = px
                        entry.y = py
                        entry.z = pz
                        moved = true
                    end
                end
            else
                moved = moveProjectileMarker(entry, roundToGrid(px), roundToGrid(py), roundToGrid(pz), markers)
            end

            if not moved then
                removeProjectileVisual(entry)
                table.remove(activeProjectileMarkers, i)
            elseif t >= 1.0 then
                entry.ttl = (entry.ttl or PROJECTILE_MARKER_TTL) - dt
                if entry.ttl <= 0 then
                    removeProjectileVisual(entry)
                    table.remove(activeProjectileMarkers, i)
                end
            end
        end
    end
end

local function renderProjectileVisuals()
    if not (Render3DItem and getCell) then
        return
    end

    local cell = getCell()
    if not cell then
        return
    end

    for i = 1, #activeProjectileMarkers do
        local entry = activeProjectileMarkers[i]
        if entry and entry.mode == "render3d" and entry.renderItem then
            local square = entry.renderSquare
            if not square then
                square = cell:getGridSquare(roundToGrid(entry.x), roundToGrid(entry.y), math.floor(entry.z or 0))
                if not square then
                    square = cell:getGridSquare(roundToGrid(entry.x), roundToGrid(entry.y), 0)
                end
                entry.renderSquare = square
            end

            if square then
                pcall(Render3DItem, entry.renderItem, square, entry.x, entry.y, entry.z, entry.renderRotation or 0.0)
            end
        end
    end
end

local function cleanupMarkers(dt)
    local markers = getIsoMarkers and getIsoMarkers() or nil
    for i = #activeExplosionMarkers, 1, -1 do
        local entry = activeExplosionMarkers[i]
        if entry.ttl then
            entry.ttl = entry.ttl - dt
            if entry.ttl <= 0 or not entry.marker or (entry.marker.isRemoved and entry.marker:isRemoved()) then
                if entry.marker and entry.marker.remove then
                    pcall(entry.marker.remove, entry.marker)
                end
                table.remove(activeExplosionMarkers, i)
            end
        else
            if not (entry.marker and entry.frame and entry.frameNames and markers and markers.addIsoMarker) then
                if entry.marker and entry.marker.remove then
                    pcall(entry.marker.remove, entry.marker)
                end
                table.remove(activeExplosionMarkers, i)
            else
                local step = entry.frameStep or FX_ANIM_FRAME_STEP
                entry.frameTime = (entry.frameTime or 0.0) + dt
                if entry.frameTime >= step then
                    entry.frameTime = entry.frameTime - step
                    entry.frame = entry.frame + 1

                    if entry.frame > #entry.frameNames then
                        if entry.marker and entry.marker.remove then
                            pcall(entry.marker.remove, entry.marker)
                        end
                        table.remove(activeExplosionMarkers, i)
                    else
                        if entry.marker and entry.marker.remove then
                            pcall(entry.marker.remove, entry.marker)
                        end
                        local square = getCell():getGridSquare(entry.x, entry.y, entry.z)
                        if not square then
                            square = getCell():getGridSquare(entry.x, entry.y, 0)
                        end
                        if not square then
                            table.remove(activeExplosionMarkers, i)
                        else
                            local nextMarker = markers:addIsoMarker(entry.frameNames[entry.frame], square, 1.0, 1.0, 1.0, 1.0)
                            if nextMarker then
                                entry.marker = nextMarker
                            else
                                table.remove(activeExplosionMarkers, i)
                            end
                        end
                    end
                end
            end
        end
    end
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

local function playLaunchSound(playerObj, soundName)
    if not playerObj or not soundName or soundName == "" then
        return
    end

    local square = playerObj.getSquare and playerObj:getSquare() or nil
    local soundManager = getSoundManager and getSoundManager() or nil
    if square and soundManager and soundManager.PlayWorldSound then
        local ok = pcall(soundManager.PlayWorldSound, soundManager, soundName, square, 0, 0, 0, false)
        if ok then
            return
        end
    end

    if playerObj.playSound then
        pcall(playerObj.playSound, playerObj, soundName)
    end
end

local function triggerImpactFireAt(square, explosionPower)
    if not square then
        return false, "square_nil"
    end

    if not (IsoFireManager and IsoFireManager.StartFire and getCell) then
        return false, "startfire_api_missing"
    end

    local fireEnergy = math.max(5, tonumber(explosionPower) or 5)
    local ok, err = pcall(IsoFireManager.StartFire, getCell(), square, true, fireEnergy)
    if ok then
        logGL("Impact fire local at %d,%d,%d firePower=%s fireEnergy=%s", square:getX(), square:getY(), square:getZ(),
            tostring(explosionPower), tostring(fireEnergy))
        return true, fireEnergy
    end

    logGL("Local impact fire failed: %s", tostring(err))
    return false, tostring(err)
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

local function triggerImpactSmokeAt(square)
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

local function triggerImpactBlastAt(square, explosionPower)
    if not square then
        return false, "square_nil"
    end
    if not (IsoFireManager and IsoFireManager.explode and getCell) then
        return false, "explode_api_missing"
    end

    local blastPower = math.max(1, tonumber(explosionPower) or 1)
    local ok, err = pcall(IsoFireManager.explode, getCell(), square, blastPower)
    if not ok then
        return false, tostring(err)
    end

    return true, tostring(blastPower)
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

local function triggerImpactTrapExplosionAt(square, payload, attacker, physicsBlastPower)
    if not square then
        return false, "square_nil"
    end
    if not (IsoTrap and IsoTrap.new and getCell) then
        return false, "isotrap_api_missing"
    end

    local payloadWeaponType = normalizeFullType(payload and payload.damageWeaponType) or "Base.PipeBomb"
    local trapItem = instanceItem and instanceItem(payloadWeaponType) or nil
    if (not trapItem) and payloadWeaponType ~= "Base.PipeBomb" and instanceItem then
        trapItem = instanceItem("Base.PipeBomb")
    end
    if not trapItem then
        return false, "trap_item_nil"
    end

    -- Alinear el item con el cuadrado impactado ayuda a algunas rutas internas.
    if trapItem.setAttackTargetSquare then
        pcall(trapItem.setAttackTargetSquare, trapItem, square)
    end

    local trap = nil
    local okTrap, trapOrErr = pcall(IsoTrap.new, attacker, trapItem, getCell(), square)
    if okTrap then
        trap = trapOrErr
    else
        local okTrap2, trapOrErr2 = pcall(IsoTrap.new, trapItem, getCell(), square)
        if okTrap2 then
            trap = trapOrErr2
        else
            return false, "isotrap_new_failed:" .. tostring(trapOrErr2 or trapOrErr)
        end
    end

    if not trap then
        return false, "isotrap_nil"
    end

    local blastPower = math.max(1, tonumber(physicsBlastPower) or tonumber(payload and payload.explosionPower) or 100)
    local blastRange = computePayloadExplosionRange(payload, blastPower)
    local useProxyTrap1Tick = tostring(payload and payload.trapProxyMode or "") == "tick1"

    if trap.setExplosionPower then
        pcall(trap.setExplosionPower, trap, blastPower)
    end
    if trap.setExplosionRange then
        pcall(trap.setExplosionRange, trap, blastRange)
    end
    if trap.setExplosionSound and payload and payload.explosionSound and payload.explosionSound ~= "" then
        pcall(trap.setExplosionSound, trap, payload.explosionSound)
    end
    if trap.setInstantExplosion then
        pcall(trap.setInstantExplosion, trap, not useProxyTrap1Tick)
    end
    if trap.setTimerBeforeExplosion then
        local proxyTimer = tonumber(payload and payload.trapProxyTimer)
        if proxyTimer == nil then
            proxyTimer = 1
        end
        if useProxyTrap1Tick and proxyTimer <= 0 then
            -- B42 parece tratar 0 como "no countdown" y no entra al ragdoll vanilla.
            proxyTimer = 1
        end
        pcall(trap.setTimerBeforeExplosion, trap, useProxyTrap1Tick and proxyTimer or 0)
    end

    if square.AddTileObject then
        pcall(square.AddTileObject, square, trap)
    end
    if trap.addToWorld then
        pcall(trap.addToWorld, trap)
    end

    -- Modo proxy: dejar que la trampa vanilla procese su propia explosion en el siguiente tick.
    -- Evita triggerExplosion(...) porque en B42 nos arma/spawnea un PipeBomb sin ragdoll.
    if useProxyTrap1Tick then
        queueTrapProxyCleanup(trap, square, payload and payload.trapProxyCleanupTTL)
        return true, string.format("isotrap proxy1tick item=%s power=%d range=%d", tostring(payloadWeaponType), blastPower, blastRange)
    end

    -- Probar rutas de detonacion; algunas builds exponen firmas distintas.
    local triggerOk = false
    local triggerErr = nil
    local triggerMethod = nil
    local trapCleaned = false

    local function markTrigger(ok, err, label)
        if ok then
            triggerOk = true
            triggerMethod = label
            return true
        end
        triggerErr = err or triggerErr
        return false
    end

    local function cleanupTrapObject()
        if trapCleaned or (not trap) then
            return
        end
        trapCleaned = true
        removeTrapProxyObject(trap, square)
    end

    -- Ruta directa de IsoTrap (suele aplicar mejor la logica vanilla que triggerExplosion()).
    if trap.explodeTrap then
        local okX, errX = pcall(trap.explodeTrap, trap)
        markTrigger(okX, errX, "explodeTrap()")
    end

    if (not triggerOk) and trap.processInstantExplosion then
        local okPI, errPI = pcall(trap.processInstantExplosion, trap)
        markTrigger(okPI, errPI, "processInstantExplosion()")
    end

    -- triggerExplosion(...) en B42 acepta boolean, pero en esta ruta nos arma/spawnea la PipeBomb
    -- en el impacto sin dar el ragdoll deseado. Se evita para no dejar basura ni errores.

    if (not triggerOk) and trap.instantExplosion then
        local okD, errD = pcall(trap.instantExplosion, trap)
        markTrigger(okD, errD, "instantExplosion()")
        if (not triggerOk) then
            local okE, errE = pcall(trap.instantExplosion, trap, square)
            markTrigger(okE, errE, "instantExplosion(square)")
        end
    end

    if not triggerOk then
        -- Evitar dejar un objeto trampa colgado si fallo la detonacion.
        cleanupTrapObject()
        return false, "isotrap_trigger_failed:" .. tostring(triggerErr)
    end

    -- Limpieza defensiva: si la API no se autodestruye, no queremos dejar un PipeBomb spawneado.
    cleanupTrapObject()

    return true, string.format("isotrap method=%s item=%s power=%d range=%d", tostring(triggerMethod), tostring(payloadWeaponType), blastPower, blastRange)
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

distance2D = function(x1, y1, x2, y2)
    local dx = (x1 or 0) - (x2 or 0)
    local dy = (y1 or 0) - (y2 or 0)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function applyPhysicsHitReaction(zombie, reactionName)
    if not zombie then
        return false
    end

    local reaction = tostring(reactionName or "PipeBomb")
    local applied = false
    if zombie.setHitReaction then
        local ok = pcall(zombie.setHitReaction, zombie, reaction)
        if ok then
            applied = true
        end
    end
    if (not applied) and zombie.setVariable then
        local ok = pcall(zombie.setVariable, zombie, "ZombieHitReaction", reaction)
        if ok then
            applied = true
        end
    end

    -- Ayuda a entrar en el estado físico sin forzar un setOnFloor que mate el impulso.
    if zombie.knockDown then
        pcall(zombie.knockDown, zombie, true)
    end

    return applied
end

local function isPhysicsHitReactionEnabledOption()
    if not (getCore and getCore()) then
        return false
    end
    local core = getCore()
    if not (core and core.getOptionUsePhysicsHitReaction) then
        return false
    end
    local ok, enabled = pcall(core.getOptionUsePhysicsHitReaction, core)
    if not ok then
        return false
    end
    return enabled == true
end

function ggsGLApplyExplosionReactionFx(square, ammoType, stamp)
    if not square then
        return
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return
    end

    local payload = resolveImpactPayload and resolveImpactPayload(ammoType, nil) or nil
    local power = math.max(1, tonumber(payload and payload.explosionPower) or 100)
    local radius = tonumber(payload and payload.damageRadius)
    if not radius or radius <= 0 then
        radius = math.max(BLAST_DAMAGE_MIN_RADIUS, math.min(BLAST_DAMAGE_MAX_RADIUS, 1.0 + (power * BLAST_DAMAGE_RADIUS_SCALE)))
    end
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

    local centerX = square:getX() + 0.5
    local centerY = square:getY() + 0.5
    local minX = math.floor(centerX - radius)
    local maxX = math.ceil(centerX + radius)
    local minY = math.floor(centerY - radius)
    local maxY = math.ceil(centerY + radius)
    local z = square:getZ()
    local seen = {}
    local affected = 0
    local localKills = 0
    local physicsRagdollOptionEnabled = isPhysicsHitReactionEnabledOption()

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
                        if moving and instanceof(moving, "IsoZombie") then
                            local key = tostring(moving)
                            if not seen[key] then
                                seen[key] = true
                                local falloff = 1.0 - (squareDist / radius)
                                if falloff < 0 then
                                    falloff = 0
                                end
                                local damage = payloadMinDamage + ((payloadMaxDamage - payloadMinDamage) * falloff)
                                if damage < BLAST_DAMAGE_MIN then
                                    damage = BLAST_DAMAGE_MIN
                                end

                                local kdx = moving:getX() - centerX
                                local kdy = moving:getY() - centerY
                                local kdist = math.sqrt((kdx * kdx) + (kdy * kdy))
                                if kdist > 0 then
                                    kdx = kdx / kdist
                                    kdy = kdy / kdist
                                else
                                    local angle = ZombRand(360) * (math.pi / 180.0)
                                    kdx = math.cos(angle)
                                    kdy = math.sin(angle)
                                end

                                local knockForce = falloff * (power / 20.0)
                                local usedPhysicsRagdoll = applyPhysicsHitReaction(moving,
                                    payload and payload.physicsHitReaction or "PipeBomb")
                                if moving.setThrowingVelocityX and moving.setThrowingVelocityY then
                                    local xyMul = 5.0
                                    local zMul = 3.4
                                    if usedPhysicsRagdoll and physicsRagdollOptionEnabled then
                                        xyMul = 2.4
                                        zMul = 2.1
                                    end

                                    pcall(moving.setThrowingVelocityX, moving, kdx * knockForce * xyMul)
                                    pcall(moving.setThrowingVelocityY, moving, kdy * knockForce * xyMul)
                                    if moving.setThrowingVelocityZ then
                                        local zImpulse = math.max(0.45, knockForce * zMul)
                                        pcall(moving.setThrowingVelocityZ, moving, zImpulse)
                                    end
                                end

                                if moving.getHealth and moving.setHealth then
                                    local okHealth, oldHealth = pcall(moving.getHealth, moving)
                                    if okHealth and tonumber(oldHealth) then
                                        local appliedDamage = damage
                                        if squareDist <= lethalRadius then
                                            appliedDamage = math.max(appliedDamage, tonumber(oldHealth) + 5.0)
                                        end
                                        local newHealth = math.max(0.0, tonumber(oldHealth) - appliedDamage)
                                        pcall(moving.setHealth, moving, newHealth)
                                        if newHealth <= 0.0 then
                                            local killed = false
                                            if moving.Kill then
                                                killed = pcall(moving.Kill, moving, getPlayer and getPlayer() or nil, true)
                                                if (not killed) then
                                                    killed = pcall(moving.Kill, moving, getPlayer and getPlayer() or nil)
                                                end
                                            end
                                            if (not killed) and moving.die then
                                                killed = pcall(moving.die, moving)
                                            end
                                            if killed then
                                                localKills = localKills + 1
                                            end
                                        end
                                    end
                                end
                                affected = affected + 1
                            end
                        end
                    end
                end
            end
        end
    end

    logGL("ExplosionFX reaction applied stamp=%s ammo=%s square=%d,%d,%d radius=%.2f lethalR=%.2f zombies=%d localKills=%d",
        tostring(stamp), tostring(ammoType), square:getX(), square:getY(), square:getZ(), radius, lethalRadius, affected,
        localKills)
end

local function applyBlastDamage(square, explosionPower, attacker, payload)
    if not square then
        return 0, 0.0, 0.0, false
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return 0, 0.0, 0.0, false
    end

    local power = math.max(1, tonumber(explosionPower) or 1)
    local radius = math.max(BLAST_DAMAGE_MIN_RADIUS, math.min(BLAST_DAMAGE_MAX_RADIUS, 1.0 + (power * BLAST_DAMAGE_RADIUS_SCALE)))
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
    local physicsRagdollOptionEnabled = isPhysicsHitReactionEnabledOption()

    for z = minZ, maxZ do
        for x = minX, maxX do
            for y = minY, maxY do
                local hitSquare = cell:getGridSquare(x, y, z)
                if hitSquare and hitSquare.getMovingObjects then
                    local movingObjects = hitSquare:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if moving and (instanceof(moving, "IsoZombie") or instanceof(moving, "IsoPlayer")) then
                                local key = tostring(moving)
                                if not seen[key] then
                                    local dist = distance2D(centerX, centerY, moving:getX(), moving:getY())
                                    if dist <= radius then
                                        seen[key] = true

                                        local falloff = 1.0 - (dist / radius)
                                        if falloff < 0 then
                                            falloff = 0
                                        end
                                        local damage = (power / 20.0) * BLAST_DAMAGE_SCALE * (0.35 + (0.65 * falloff))
                                        if damage < BLAST_DAMAGE_MIN then
                                            damage = BLAST_DAMAGE_MIN
                                        elseif damage > BLAST_DAMAGE_MAX then
                                            damage = BLAST_DAMAGE_MAX
                                        end

                                        if not damageWeapon then
                                            damageWeapon = createExplosionDamageWeapon(square, payload)
                                        end

                                        local damaged = false
                                        if damageWeapon and attacker and moving.Hit then
                                            local ok = pcall(moving.Hit, moving, damageWeapon, attacker, damage, false, 1.0)
                                            damaged = ok
                                        end

                                        if not damaged and moving.getHealth and moving.setHealth then
                                            local oldHealth = tonumber(moving:getHealth()) or 1.0
                                            local newHealth = math.max(0.0, oldHealth - damage)
                                            damaged = pcall(moving.setHealth, moving, newHealth)
                                        end

                                        if damaged then
                                            affected = affected + 1
                                            totalDamage = totalDamage + damage
                                        end

                                        -- Ragdoll / knockback: replicar comportamiento de pipebomb vanilla
                                        local knockForce = falloff * (power / 20.0)
                                        if knockForce > 0 and instanceof(moving, "IsoZombie") then
                                            -- Calcular direccion de salida desde el centro de la explosion
                                            local kdx = moving:getX() - centerX
                                            local kdy = moving:getY() - centerY
                                            local kdist = math.sqrt(kdx * kdx + kdy * kdy)
                                            if kdist > 0 then
                                                kdx = kdx / kdist
                                                kdy = kdy / kdist
                                            else
                                                -- Zombie exactamente en el centro: direccion aleatoria
                                                local angle = ZombRand(360) * (math.pi / 180.0)
                                                kdx = math.cos(angle)
                                                kdy = math.sin(angle)
                                            end

                                            local usedPhysicsRagdoll = applyPhysicsHitReaction(moving,
                                                payload and payload.physicsHitReaction or "PipeBomb")

                                            -- Empuje manual: se aplica siempre.
                                            -- Si la reaccion fisica vanilla esta activa, lo usamos como "assist";
                                            -- si no, este empuje produce el efecto de salir despedido.
                                            if moving.setThrowingVelocityX and moving.setThrowingVelocityY then
                                                local xyMul = 5.0
                                                local zMul = 3.4
                                                if usedPhysicsRagdoll and physicsRagdollOptionEnabled then
                                                    xyMul = 2.4
                                                    zMul = 2.1
                                                end

                                                pcall(moving.setThrowingVelocityX, moving, kdx * knockForce * xyMul)
                                                pcall(moving.setThrowingVelocityY, moving, kdy * knockForce * xyMul)
                                                if moving.setThrowingVelocityZ then
                                                    local zImpulse = math.max(0.45, knockForce * zMul)
                                                    pcall(moving.setThrowingVelocityZ, moving, zImpulse)
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
        end
    end

    return affected, totalDamage, radius, damageWeapon ~= nil
end

local function detonateImpact(playerObj, launcherType, profile, square, stamp, distance, ammoType, sourceTag, prearmedBlast)
    local payload = resolveImpactPayload(ammoType, profile)
    local firePower, basePower = getScaledFireExplosionPower(profile, payload)
    local fireStarted, fireData = false, "disabled"
    if payload and payload.groundFire == true then
        fireStarted, fireData = triggerImpactFireAt(square, firePower)
        if not fireStarted then
            logGL("%s impact fire failed launcher=%s err=%s", tostring(sourceTag or "local"), tostring(launcherType),
                tostring(fireData))
        end
    end

    local smoked, smokeData = triggerImpactSmokeAt(square)
    if not smoked then
        logGL("%s smoke failed launcher=%s err=%s", tostring(sourceTag or "local"), tostring(launcherType), tostring(smokeData))
    end

    local physicsBlastPower = getPhysicsBlastPower(profile, payload)
    local damagePower = math.max(tonumber(physicsBlastPower) or 0, tonumber(basePower) or 0)
    local blastTriggered, blastData = false, nil
    if prearmedBlast and prearmedBlast.triggered then
        blastTriggered = true
        blastData = tostring(prearmedBlast.data or "isotrap proxy1tick")
        if not blastData:find(" prearmed", 1, true) then
            blastData = blastData .. " prearmed"
        end
        local prearmedPhys = tonumber(prearmedBlast.physicsBlastPower)
        if prearmedPhys and prearmedPhys > 0 then
            physicsBlastPower = prearmedPhys
        end
    else
        blastTriggered, blastData = triggerImpactTrapExplosionAt(square, payload, playerObj, physicsBlastPower)
        if not blastTriggered then
            blastTriggered, blastData = triggerImpactBlastAt(square, physicsBlastPower)
        end
    end
    local proxyTrap1TickArmed = blastTriggered and tostring(payload and payload.trapProxyMode or "") == "tick1" and
        (tostring(blastData or ""):find("proxy1tick", 1, true) ~= nil)
    -- applyBlastDamage siempre se ejecuta para garantizar ragdoll/knockback en zombies,
    -- independientemente de si la API de explode() funcionó o no.
    local affected, totalDamage, damageRadius, usedDamageWeapon = 0, 0.0, 0.0, false
    if proxyTrap1TickArmed then
        logGL("%s manual blast damage skipped launcher=%s reason=proxy1tick", tostring(sourceTag or "local"),
            tostring(launcherType))
    else
        affected, totalDamage, damageRadius, usedDamageWeapon = applyBlastDamage(square, damagePower, playerObj, payload)
    end
    if not blastTriggered then
        logGL("%s blast API unavailable, using manual damage only launcher=%s", tostring(sourceTag or "local"),
            tostring(launcherType))
    end
    markStampSeen(stamp)
    addExplosionMarker(square, stamp, payload and payload.explosionSound)

    logGL(
        "%s detonation success launcher=%s ammo=%s payload=%s target=%d,%d,%d dist=%.2f stamp=%s firePower=%d fireEnergy=%s smoke=%s blast=%s blastData=%s physBlast=%d dmgPower=%d base=%d zHits=%d zDmg=%.2f zRad=%.2f dmgWpn=%s",
        tostring(sourceTag or "local"), tostring(launcherType), tostring(payload and payload.ammoType), tostring(payload and payload.id),
        square:getX(), square:getY(), square:getZ(), tonumber(distance) or 0, tostring(stamp), firePower,
        tostring(fireData), tostring(smokeData), tostring(blastTriggered), tostring(blastData), physicsBlastPower, damagePower, basePower,
        tonumber(affected) or 0, tonumber(totalDamage) or 0, tonumber(damageRadius) or 0, tostring(usedDamageWeapon))
    return true
end

local function tryPrearmPendingImpactProxy(pending)
    if not (pending and getCell and resolveImpactPayload and triggerImpactTrapExplosionAt) then
        return false
    end
    if pending.prearmedBlast and pending.prearmedBlast.triggered then
        return true
    end

    local payload = resolveImpactPayload(pending.ammoType, pending.profile)
    if tostring(payload and payload.trapProxyMode or "") ~= "tick1" then
        return false
    end

    local proxyTimer = tonumber(payload and payload.trapProxyTimer)
    if proxyTimer == nil or proxyTimer <= 0 then
        proxyTimer = 1
    end
    local ttl = tonumber(pending.ttl) or 0
    if ttl > proxyTimer then
        return false
    end

    local cell = getCell()
    if not cell then
        return false
    end
    local square = cell:getGridSquare(pending.x, pending.y, pending.z)
    if not square then
        square = cell:getGridSquare(pending.x, pending.y, 0)
    end
    if not square then
        return false
    end

    local physicsBlastPower = getPhysicsBlastPower and getPhysicsBlastPower(pending.profile, payload) or
        (tonumber(payload and payload.explosionPower) or tonumber(pending.profile and pending.profile.explosionPower) or 100)
    local ok, data = triggerImpactTrapExplosionAt(square, payload, pending.playerObj, physicsBlastPower)
    if not ok then
        return false
    end

    pending.prearmedBlast = {
        triggered = true,
        data = tostring(data),
        physicsBlastPower = tonumber(physicsBlastPower) or 0
    }
    logGL("SP proxy trap prearmed stamp=%s ttl=%.2f target=%d,%d,%d data=%s", tostring(pending.stamp), ttl, pending.x, pending.y,
        pending.z, tostring(data))
    return true
end

local function queuePendingImpact(playerObj, launcherType, profile, square, stamp, distance, ammoType, flightTime)
    if not (playerObj and launcherType and profile and square) then
        return false
    end
    local entry = {
        playerObj = playerObj,
        launcherType = launcherType,
        profile = profile,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        stamp = stamp,
        distance = tonumber(distance) or 0,
        ammoType = normalizeFullType(ammoType),
        ttl = tonumber(flightTime) or PROJECTILE_MIN_FLIGHT_TIME
    }
    table.insert(pendingImpacts, entry)
    -- Para tiros cortos, intentar prearmar de inmediato minimiza el desfase del proxy trap.
    tryPrearmPendingImpactProxy(entry)
    return true
end

local function processPendingImpacts(dt)
    for i = #pendingImpacts, 1, -1 do
        local pending = pendingImpacts[i]
        pending.ttl = pending.ttl - dt
        if pending.ttl > 0 then
            tryPrearmPendingImpactProxy(pending)
        end
        if pending.ttl <= 0 then
            local square = getCell():getGridSquare(pending.x, pending.y, pending.z)
            if not square then
                square = getCell():getGridSquare(pending.x, pending.y, 0)
            end
            if square then
                detonateImpact(pending.playerObj, pending.launcherType, pending.profile, square, pending.stamp,
                    pending.distance, pending.ammoType, "SP", pending.prearmedBlast)
            else
                logGL("SP detonation skipped: square missing x=%s y=%s z=%s", tostring(pending.x), tostring(pending.y),
                    tostring(pending.z))
            end
            table.remove(pendingImpacts, i)
        end
    end
end

getScaledFireExplosionPower = function(profile, payload)
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100
    local scale = tonumber(payload and payload.firePowerScale) or FIRE_EXPLOSION_POWER_SCALE
    local scaledPower = math.max(1, math.floor((basePower * scale) + 0.5))
    return scaledPower, basePower
end

getScaledDamagePower = function(profile, payload)
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100
    local scale = tonumber(payload and payload.damagePowerScale) or DAMAGE_POWER_SCALE
    local scaledPower = math.max(1, math.floor((basePower * scale) + 0.5))
    return scaledPower, basePower
end

getPhysicsBlastPower = function(profile, payload)
    local basePower = tonumber(payload and payload.explosionPower) or tonumber(profile and profile.explosionPower) or 100
    local override = tonumber(payload and payload.physicsBlastPower)
    if override and override > 0 then
        return math.max(1, math.floor(override + 0.5))
    end

    local scale = tonumber(payload and payload.physicsBlastPowerScale) or 1.0
    return math.max(1, math.floor((basePower * scale) + 0.5))
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

local function inventoryHasItem(inventory, fullType)
    local wanted = normalizeFullType(fullType)
    if not wanted then
        return false
    end

    local found = false
    eachInventoryItemRecursive(inventory, function(item)
        if found then
            return true
        end
        if item and item.getFullType then
            local itemType = normalizeFullType(item:getFullType())
            if itemType == wanted then
                found = true
                return true
            end
        end
        return false
    end)
    return found
end

local function resolveAmmoTypeForLoad(playerObj, weapon, profile)
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        return nil
    end

    local preferred = normalizeFullType(getPreferredAmmoType(weapon, profile) or profile and profile.ammoType or
        "Base.GrenadeAmmo")
    if preferred and inventoryHasItem(inventory, preferred) then
        return preferred
    end

    local preferredLower = preferred and preferred:lower() or nil
    local fallback = nil
    eachInventoryItemRecursive(inventory, function(item)
        if fallback then
            return true
        end
        if item and item.getFullType then
            local itemType = normalizeFullType(item:getFullType())
            if itemType and GL_AMMO_PAYLOAD_BY_FULLTYPE[itemType] then
                local lower = itemType:lower()
                local sameFamily = false
                if preferredLower then
                    if lower == preferredLower then
                        sameFamily = true
                    elseif lower:sub(1, #preferredLower + 1) == (preferredLower .. "_") then
                        sameFamily = true
                    elseif preferredLower:sub(1, 16) == "base.grenadeammo" and lower:sub(1, 16) == "base.grenadeammo" then
                        sameFamily = true
                    end
                end
                if sameFamily then
                    fallback = itemType
                    return true
                end
            end
        end
        return false
    end)

    return fallback
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
                    removed = true
                    return true
                end
            end
        end
        return false
    end)

    return removed
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

function applyStandaloneStateFromServer(args)
    local playerObj = getPlayer and getPlayer() or nil
    if not (playerObj and args and args.gunId) then
        return false
    end

    local weapon = findPlayerWeaponById(playerObj, tonumber(args.gunId))
    if not weapon then
        return false
    end

    local profile, weaponType = resolveStandaloneLauncherProfile(weapon)
    if not profile then
        return false
    end

    local ammoType = normalizeFullType(args.ammoType or profile.ammoType)
    local count = tonumber(args.count) or 0
    setStandaloneAmmoCountLocalOnly(weapon, profile, count)
    if count > 0 and ammoType then
        setPreferredAmmoTypeLocalOnly(weapon, ammoType)
        setLoadedAmmoTypeLocalOnly(weapon, ammoType)
    else
        clearLoadedAmmoTypeLocalOnly(weapon)
    end

    refreshEquippedWeaponVisual(playerObj)
    logGL("Standalone state synced weapon=%s count=%s ammo=%s reason=%s",
        tostring(weaponType), tostring(count), tostring(ammoType), tostring(args.reason))
    return true
end

local function resolveLauncherPart(weapon)
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

local function swapLauncherPart(weapon, currentPart, targetType)
    if not (weapon and currentPart and targetType and weapon.setWeaponPart) then
        return false
    end

    local targetFullType = normalizeFullType(targetType)
    local targetPart = instanceItem and instanceItem(targetFullType) or nil
    if not targetPart then
        logGL("swapLauncherPart failed: cannot instance %s", tostring(targetFullType))
        return false
    end

    if currentPart.getCondition and targetPart.setCondition then
        pcall(targetPart.setCondition, targetPart, currentPart:getCondition())
    end

    local ok, err = pcall(weapon.setWeaponPart, weapon, "Stool", targetPart)
    if not ok then
        logGL("swapLauncherPart failed setWeaponPart err=%s", tostring(err))
        return false
    end

    local md = weapon:getModData()
    md.weaponpart = md.weaponpart or {}
    md.weaponpart["Stool"] = targetFullType
    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end

    logGL("Launcher swapped part=%s", tostring(targetFullType))
    return true
end

local function swapLauncherPartToEmpty(weapon, loadedPart, profile)
    if not (profile and profile.emptyType) then
        return false
    end
    return swapLauncherPart(weapon, loadedPart, profile.emptyType)
end

local function swapLauncherPartToLoaded(weapon, emptyPart, profile)
    if not (profile and profile.loadedType) then
        return false
    end
    return swapLauncherPart(weapon, emptyPart, profile.loadedType)
end

function launcherTypeMatchesProfile(profile, actualType, expectedType)
    local actual = normalizeFullType(actualType)
    local expected = normalizeFullType(expectedType)
    if not expected then
        return true
    end
    if actual == expected then
        return true
    end
    if not (profile and actual) then
        return false
    end
    return actual == normalizeFullType(profile.loadedType) or actual == normalizeFullType(profile.emptyType)
end

function mirrorLauncherLoadedStateLocal(playerObj, weapon, ammoType)
    local launcherPart, launcherType, profile, state = resolveLauncherPart(weapon)
    if not (weapon and launcherPart and profile) then
        return false
    end

    local targetType = normalizeFullType(profile.loadedType)
    if targetType and not isLauncherClosedState(state) and weapon.setWeaponPart and instanceItem then
        local targetPart = instanceItem(targetType)
        if targetPart then
            if launcherPart.getCondition and targetPart.setCondition then
                pcall(targetPart.setCondition, targetPart, launcherPart:getCondition())
            end
            pcall(weapon.setWeaponPart, weapon, "Stool", targetPart)
            local md = getWeaponModData(weapon)
            if md then
                md.weaponpart = md.weaponpart or {}
                md.weaponpart["Stool"] = targetType
            end
            logGL("MP local launcher mirrored loaded part=%s from=%s", tostring(targetType), tostring(launcherType))
        end
    end

    local controllerType = normalizeFullType(AMMO_CONTROLLER_PART_FULLTYPE)
    if weapon.setWeaponPart and instanceItem and controllerType then
        local controller = instanceItem(controllerType)
        if controller then
            pcall(weapon.setWeaponPart, weapon, AMMO_PART_SLOT, controller)
        end
    end
    local md = getWeaponModData(weapon)
    if md then
        md.weaponpart = md.weaponpart or {}
        md.weaponpart[AMMO_PART_SLOT] = controllerType
    end

    setPreferredAmmoTypeLocalOnly(weapon, ammoType or profile.ammoType)
    setLoadedAmmoTypeLocalOnly(weapon, ammoType or profile.ammoType)
    refreshEquippedWeaponVisual(playerObj)
    return true
end

local function ensureLauncherOpenSinglePlayer(weapon, profile)
    local launcherPart, _, _, launcherState = resolveLauncherPart(weapon)
    if not (launcherPart and profile) then
        return false
    end
    if isLauncherOpenState(launcherState) then
        return true
    end
    return swapLauncherPartToEmpty(weapon, launcherPart, profile)
end

local function ensureLauncherClosedSinglePlayer(weapon, profile)
    local launcherPart, _, _, launcherState = resolveLauncherPart(weapon)
    if not (launcherPart and profile) then
        return false
    end
    if isLauncherClosedState(launcherState) then
        return true
    end
    return swapLauncherPartToLoaded(weapon, launcherPart, profile)
end

local function loadLauncherSinglePlayer(playerObj, weapon, _launcherPart, launcherType, profile, ammoTypeOverride)
    if not (playerObj and weapon and profile) then
        return false
    end

    local ammoType = normalizeFullType(ammoTypeOverride or getPreferredAmmoType(weapon, profile) or profile.ammoType or
        "Base.GrenadeAmmo")
    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        logGL("Load aborted: no inventory")
        return false
    end

    if not ensureLauncherOpenSinglePlayer(weapon, profile) then
        logGL("Load aborted: failed to open launcher=%s", tostring(launcherType))
        return false
    end

    if not removeOneItemFromInventory(inventory, ammoType) then
        logGL("Load aborted: ammo missing type=%s launcher=%s", tostring(ammoType), tostring(launcherType))
        return false
    end

    if not installAmmoControllerPart(weapon, ammoType) then
        if inventory.AddItem then
            pcall(inventory.AddItem, inventory, ammoType)
        end
        logGL("Load aborted: failed to install ammo controller launcher=%s ammo=%s", tostring(launcherType),
            tostring(ammoType))
        return false
    end

    if not ensureLauncherClosedSinglePlayer(weapon, profile) then
        removeAmmoControllerPart(weapon)
        if inventory.AddItem then
            pcall(inventory.AddItem, inventory, ammoType)
        end
        logGL("Load aborted: failed to close launcher=%s", tostring(launcherType))
        return false
    end

    fireCooldown = CLIENT_FIRE_COOLDOWN
    setPreferredAmmoType(weapon, ammoType)
    setLoadedAmmoType(weapon, ammoType)
    logGL("Load success launcher=%s ammo=%s", tostring(launcherType), tostring(ammoType))
    return true
end

local function loadStandaloneLauncherSinglePlayer(playerObj, weapon, weaponType, profile, ammoTypeOverride)
    if not (playerObj and weapon and profile) then
        return false
    end

    local currentCount = getStandaloneAmmoCount(weapon, profile)
    local loadedAmmoType = getLoadedAmmoType(weapon, profile)
    local ammoType = normalizeFullType(ammoTypeOverride or loadedAmmoType or getPreferredAmmoType(weapon, profile) or
        profile.ammoType)
    if not ammoType then
        logGL("Standalone load aborted: ammoType=nil weapon=%s", tostring(weaponType))
        return false
    end

    if isStandaloneAmmoCountProfile(profile) then
        local capacity = getStandaloneAmmoCapacity(profile)
        if currentCount >= capacity then
            logGL("Standalone load ignored: magazine full weapon=%s count=%d/%d", tostring(weaponType), currentCount, capacity)
            return false
        end

        if loadedAmmoType and loadedAmmoType ~= ammoType then
            ammoType = loadedAmmoType
        end
    elseif loadedAmmoType then
        logGL("Standalone load ignored: already loaded weapon=%s ammo=%s", tostring(weaponType),
            tostring(loadedAmmoType))
        return false
    end

    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        logGL("Standalone load aborted: no inventory weapon=%s", tostring(weaponType))
        return false
    end

    if not removeOneItemFromInventory(inventory, ammoType) then
        logGL("Standalone load aborted: ammo missing weapon=%s ammo=%s", tostring(weaponType), tostring(ammoType))
        return false
    end

    if isStandaloneAmmoCountProfile(profile) then
        local capacity = getStandaloneAmmoCapacity(profile)
        local nextCount = setStandaloneAmmoCount(weapon, profile, currentCount + 1)
        setPreferredAmmoType(weapon, ammoType)
        setLoadedAmmoType(weapon, ammoType)
        fireCooldown = CLIENT_FIRE_COOLDOWN
        logGL("Standalone load success weapon=%s ammo=%s count=%d/%d mode=count", tostring(weaponType), tostring(ammoType),
            nextCount, capacity)
        return true
    end

    local controllerPartOverride = profile and profile.ammoPartType or nil
    if profile and profile.useModDataLoadStateOnly then
        -- RPG7: keep slot "Ammo" as invisible controller; the visible rocket goes on slot "AMMO".
        controllerPartOverride = nil
    end

    if not installAmmoControllerPart(weapon, ammoType, controllerPartOverride) then
        if inventory.AddItem then
            pcall(inventory.AddItem, inventory, ammoType)
        end
        logGL("Standalone load aborted: failed ammo part install weapon=%s part=%s ammo=%s", tostring(weaponType),
            tostring(controllerPartOverride or AMMO_CONTROLLER_PART_FULLTYPE), tostring(ammoType))
        return false
    end

    setPreferredAmmoType(weapon, ammoType)
    setLoadedAmmoType(weapon, ammoType)
    if not (profile and profile.deferVisualInstallUntilReloadEnds) then
        local okSync, errSync = pcall(syncStandaloneLauncherVisualPart, playerObj, weapon, profile)
        if not okSync then
            logGL("Standalone load warning: visual sync failed weapon=%s err=%s", tostring(weaponType), tostring(errSync))
        end
    elseif profile and profile.id == "RPG7" then
        logGL("RPG7 visual install deferred until reload ends")
    end
    fireCooldown = CLIENT_FIRE_COOLDOWN
    logGL("Standalone load success weapon=%s ammo=%s part=%s visual=%s", tostring(weaponType), tostring(ammoType),
        tostring(controllerPartOverride or AMMO_CONTROLLER_PART_FULLTYPE), tostring(profile.ammoPartType))
    return true
end

local ISGGSOpenLauncherAction = nil
local ISGGSLoadLauncherAction = nil
local ISGGSLoadStandaloneLauncherAction = nil

local function clearReloadAnimVars(character)
    if character and character.clearVariable then
        pcall(character.clearVariable, character, "isLoading")
        pcall(character.clearVariable, character, "isRacking")
        pcall(character.clearVariable, character, "isUnloading")
        pcall(character.clearVariable, character, "WeaponReloadType")
    end
end

local function getLauncherReloadAnimType(weapon)
    if weapon then
        local weaponType = getWeaponFullType and getWeaponFullType(weapon) or nil
        if weaponType == "Base.M79" then
            return "m79reload"
        end
        if weaponType == "Base.RPG7" or weaponType == "Base.M202A1" then
            return "rpgreload"
        end

        if weapon.getWeaponReloadType then
            local ok, value = pcall(weapon.getWeaponReloadType, weapon)
            if ok and value ~= nil then
                value = tostring(value)
                if value == "m79reload" or value == "rpgreload" then
                    return value
                end
            end
        end

        local scriptItem = weapon.getScriptItem and weapon:getScriptItem() or nil
        if scriptItem and scriptItem.getProperty then
            local ok, value = pcall(scriptItem.getProperty, scriptItem, "WeaponReloadType")
            if ok and value ~= nil then
                value = tostring(value)
                if value == "m79reload" or value == "rpgreload" then
                    return value
                end
            end
        end
    end

    return RELOAD_ANIM_TYPE
end

local function isStandaloneRackReloadAnimType(reloadAnimType)
    return reloadAnimType == "m79reload" or reloadAnimType == "rpgreload"
end

local function applyReloadAnimVars(action, weapon, skipHandModelOverride)
    if action.setOverrideHandModels and not skipHandModelOverride then
        action:setOverrideHandModels(weapon, nil)
    end
    if action.setAnimVariable then
        local reloadAnimType = getLauncherReloadAnimType(weapon)
        action:setAnimVariable("WeaponReloadType", reloadAnimType)
        action:setAnimVariable("isLoading", true)
        logGL("Reload anim vars weapon=%s type=%s", tostring(getWeaponFullType and getWeaponFullType(weapon) or nil),
            tostring(reloadAnimType))
    end
    if action.setActionAnim then
        action:setActionAnim(RELOAD_ANIM_ACTION)
    end
    if action.character and action.character.reportEvent then
        pcall(action.character.reportEvent, action.character, "EventReloading")
    end
end

local function ensureLoadActionClass()
    if timedActionClassReady then
        return ISGGSOpenLauncherAction ~= nil and ISGGSLoadLauncherAction ~= nil and ISGGSLoadStandaloneLauncherAction ~= nil
    end
    timedActionClassReady = true

    if not ISBaseTimedAction then
        pcall(require, "TimedActions/ISBaseTimedAction")
    end
    if not ISBaseTimedAction then
        logGL("Load action disabled: ISBaseTimedAction missing")
        return false
    end

    ISGGSOpenLauncherAction = ISBaseTimedAction:derive("ISGGSOpenLauncherAction")

    function ISGGSOpenLauncherAction:isValid()
        if not (self.character and self.weaponId) then
            return false
        end

        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        if not (weapon and weapon.IsWeapon and weapon:IsWeapon() and weapon.isRanged and weapon:isRanged()) then
            return false
        end

        local launcherPart, launcherType, profile, state = resolveLauncherPart(weapon)
        if not (launcherPart and profile) then
            return false
        end
        if self.launcherType and launcherType ~= self.launcherType then
            return false
        end

        return isLauncherClosedState(state)
    end

    function ISGGSOpenLauncherAction:start()
        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        if not weapon then
            self:forceStop()
            return
        end

        self.weapon = weapon
        applyReloadAnimVars(self, weapon)
        logGL("Open action started weaponId=%s launcher=%s", tostring(self.weaponId), tostring(self.launcherType))
    end

    function ISGGSOpenLauncherAction:stop()
        clearReloadAnimVars(self.character)
        logGL("Open action stopped/cancelled weaponId=%s launcher=%s", tostring(self.weaponId), tostring(self.launcherType))
        ISBaseTimedAction.stop(self)
    end

    function ISGGSOpenLauncherAction:perform()
        clearReloadAnimVars(self.character)

        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        if weapon then
            local launcherPart, launcherType, profile, state = resolveLauncherPart(weapon)
            if launcherPart and profile and isLauncherClosedState(state) then
                swapLauncherPartToEmpty(weapon, launcherPart, profile)
                logGL("Open action applied launcher=%s", tostring(launcherType))
            end
        end

        ISBaseTimedAction.perform(self)
    end

    function ISGGSOpenLauncherAction:new(character, weaponId, launcherType)
        local o = ISBaseTimedAction.new(self, character)
        o.stopOnRun = false
        o.stopOnWalk = false
        o.stopOnAim = false
        o.maxTime = RELOAD_ACTION_BASE_TIME
        o.weaponId = weaponId
        o.launcherType = launcherType
        return o
    end

    ISGGSLoadLauncherAction = ISBaseTimedAction:derive("ISGGSLoadLauncherAction")

    function ISGGSLoadLauncherAction:isValid()
        local function fail(reason)
            if not self._invalidReasonLogged then
                self._invalidReasonLogged = true
                logGL("Load action invalid weaponId=%s launcher=%s ammo=%s reason=%s", tostring(self.weaponId),
                    tostring(self.launcherType), tostring(self.ammoType), tostring(reason))
            end
            return false
        end

        if not (self.character and self.weaponId) then
            return fail("missing_character_or_weaponid")
        end

        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        if not (weapon and weapon.IsWeapon and weapon:IsWeapon() and weapon.isRanged and weapon:isRanged()) then
            return fail("weapon_not_found_or_not_ranged")
        end

        local launcherPart, launcherType, profile, state = resolveLauncherPart(weapon)
        if not (launcherPart and profile and (isLauncherOpenState(state) or isLauncherClosedState(state))) then
            return fail("launcher_missing")
        end
        if not launcherTypeMatchesProfile(profile, launcherType, self.launcherType) then
            return fail("launcher_type_mismatch")
        end
        if self._loadApplied then
            self._invalidReasonLogged = nil
            return true
        end

        local inventory = self.character.getInventory and self.character:getInventory() or nil
        if inventoryHasItem(inventory, self.ammoType) then
            self._invalidReasonLogged = nil
            return true
        end

        local fallbackAmmo = resolveAmmoTypeForLoad(self.character, weapon, profile)
        if fallbackAmmo then
            self.ammoType = fallbackAmmo
            self._invalidReasonLogged = nil
            return true
        end

        return fail("ammo_missing")
    end

    function ISGGSLoadLauncherAction:start()
        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        if not weapon then
            self:forceStop()
            return
        end

        self.weapon = weapon
        applyReloadAnimVars(self, weapon)
        logGL("Load action started weaponId=%s launcher=%s ammo=%s", tostring(self.weaponId), tostring(self.launcherType),
            tostring(self.ammoType))
        if isClient() then
            self:applyLoad()
        end
    end

    function ISGGSLoadLauncherAction:stop()
        clearReloadAnimVars(self.character)
        logGL("Load action stopped/cancelled weaponId=%s launcher=%s ammo=%s", tostring(self.weaponId),
            tostring(self.launcherType), tostring(self.ammoType))
        ISBaseTimedAction.stop(self)
    end

    function ISGGSLoadLauncherAction:applyLoad()
        if self._loadApplied then
            return
        end
        self._loadApplied = true

        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        local profile = nil
        if weapon then
            setPreferredAmmoType(weapon, self.ammoType)
            local _, _, resolvedProfile = resolveLauncherPart(weapon)
            profile = resolvedProfile
        end

        local args = {
            gunId = self.weaponId,
            ammoType = self.ammoType,
            stamp = buildStamp(self.character)
        }

        if isClient() and sendClientCommand then
            sendClientCommand(MODULE_NAME, COMMAND_LOAD, args)
            if weapon and profile then
                mirrorLauncherLoadedStateLocal(self.character, weapon, self.ammoType)
            end
            fireCooldown = CLIENT_FIRE_COOLDOWN
            logGL("Load action perform sent server command weaponId=%s ammo=%s", tostring(self.weaponId),
                tostring(self.ammoType))
        elseif weapon then
            local launcherPart, launcherType, profile = resolveLauncherPart(weapon)
            if launcherPart and profile then
                loadLauncherSinglePlayer(self.character, weapon, launcherPart, launcherType, profile, self.ammoType)
            end
        end
    end

    function ISGGSLoadLauncherAction:perform()
        clearReloadAnimVars(self.character)
        self:applyLoad()

        ISBaseTimedAction.perform(self)
    end

    function ISGGSLoadLauncherAction:new(character, weaponId, launcherType, ammoType)
        local o = ISBaseTimedAction.new(self, character)
        o.stopOnRun = false
        o.stopOnWalk = false
        o.stopOnAim = false
        o.maxTime = RELOAD_ACTION_BASE_TIME
        o.weaponId = weaponId
        o.launcherType = launcherType
        o.ammoType = normalizeFullType(ammoType or "Base.GrenadeAmmo")
        return o
    end

    ISGGSLoadStandaloneLauncherAction = ISBaseTimedAction:derive("ISGGSLoadStandaloneLauncherAction")

    function ISGGSLoadStandaloneLauncherAction:isValid()
        local function fail(reason)
            if not self._invalidReasonLogged then
                self._invalidReasonLogged = true
                logGL("Standalone load action invalid weaponId=%s weapon=%s ammo=%s reason=%s", tostring(self.weaponId),
                    tostring(self.weaponType), tostring(self.ammoType), tostring(reason))
            end
            return false
        end

        if not (self.character and self.weaponId) then
            return fail("missing_character_or_weaponid")
        end

        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        if not (weapon and weapon.IsWeapon and weapon:IsWeapon()) then
            return fail("weapon_not_found")
        end

        local profile, weaponType = resolveStandaloneLauncherProfile(weapon)
        if not profile then
            return fail("not_standalone_launcher")
        end
        if self.weaponType and weaponType ~= self.weaponType then
            return fail("weapon_type_mismatch")
        end
        if self._loadApplied then
            self._invalidReasonLogged = nil
            return true
        end
        if isStandaloneAmmoCountProfile(profile) then
            local currentCount = getStandaloneAmmoCount(weapon, profile)
            if currentCount >= getStandaloneAmmoCapacity(profile) then
                return fail("already_full")
            end
        elseif getLoadedAmmoType(weapon, profile) then
            return fail("already_loaded")
        end

        local inventory = self.character.getInventory and self.character:getInventory() or nil
        if inventoryHasItem(inventory, self.ammoType) then
            self._invalidReasonLogged = nil
            return true
        end

        local fallbackAmmo = resolveAmmoTypeForLoad(self.character, weapon, profile)
        if fallbackAmmo then
            self.ammoType = fallbackAmmo
            self._invalidReasonLogged = nil
            return true
        end

        return fail("ammo_missing")
    end

    function ISGGSLoadStandaloneLauncherAction:start()
        local weapon = findPlayerWeaponById(self.character, self.weaponId)
        if not weapon then
            self:forceStop()
            return
        end
        self.weapon = weapon
        self.reloadAnimType = getLauncherReloadAnimType(weapon)
        applyReloadAnimVars(self, weapon, true)
        logGL("Standalone load action started weaponId=%s weapon=%s ammo=%s", tostring(self.weaponId), tostring(self.weaponType),
            tostring(self.ammoType))
        if isClient() then
            self:applyLoad()
        end
    end

    function ISGGSLoadStandaloneLauncherAction:applyLoad()
        if self._loadApplied then
            return
        end
        self._loadApplied = true

        local weapon = self.weapon or findPlayerWeaponById(self.character, self.weaponId)
        local profile = nil
        local weaponType = nil
        if weapon then
            profile, weaponType = resolveStandaloneLauncherProfile(weapon)
            setPreferredAmmoType(weapon, self.ammoType)
        end

        local args = {
            gunId = self.weaponId,
            ammoType = self.ammoType,
            stamp = buildStamp(self.character),
            standalone = true
        }

        if isClient() and sendClientCommand and isStandaloneMpSupported(profile) then
            sendClientCommand(MODULE_NAME, COMMAND_LOAD, args)
            fireCooldown = CLIENT_FIRE_COOLDOWN
            logGL("Standalone load action anim apply sent server command weaponId=%s weapon=%s ammo=%s",
                tostring(self.weaponId), tostring(weaponType or self.weaponType), tostring(self.ammoType))
        elseif isClient() then
            logGL("Standalone load action anim apply MP not implemented weaponId=%s weapon=%s",
                tostring(self.weaponId), tostring(weaponType or self.weaponType))
        elseif weapon and profile then
            loadStandaloneLauncherSinglePlayer(self.character, weapon, weaponType, profile, self.ammoType)
        end
    end

    function ISGGSLoadStandaloneLauncherAction:animEvent(event, parameter)
        local weapon = self.weapon or findPlayerWeaponById(self.character, self.weaponId)

        if event == "loadFinished" then
            self:applyLoad()
            if self.setAnimVariable and isStandaloneRackReloadAnimType(self.reloadAnimType or getLauncherReloadAnimType(weapon)) then
                self:setAnimVariable("isLoading", false)
                self:setAnimVariable("isRacking", true)
                return
            end
            self:forceComplete()
            return
        end

        if event == "rackingFinished" then
            self:forceComplete()
            return
        end

        if event == "playReloadSound" and weapon then
            if parameter == "load" then
                if weapon.getInsertAmmoSound and weapon:getInsertAmmoSound() then
                    self.character:playSound(weapon:getInsertAmmoSound())
                end
            elseif parameter == "insertAmmoStart" then
                if not self.playedInsertAmmoStartSound and weapon.getInsertAmmoStartSound and weapon:getInsertAmmoStartSound() then
                    self.playedInsertAmmoStartSound = true
                    self.character:playSound(weapon:getInsertAmmoStartSound())
                end
            elseif parameter == "ejectAmmoStart" then
                if weapon.getEjectAmmoStartSound and weapon:getEjectAmmoStartSound() then
                    self.character:playSound(weapon:getEjectAmmoStartSound())
                end
            elseif parameter == "rack" then
                if weapon.getRackSound and weapon:getRackSound() then
                    self.character:playSound(weapon:getRackSound())
                end
            end
            return
        end

        if event == "changeWeaponSprite" and parameter and parameter ~= "" then
            if parameter ~= "original" then
                self:setOverrideHandModels(parameter, nil)
            elseif weapon then
                self:setOverrideHandModels(weapon, nil)
            end
        end
    end

    function ISGGSLoadStandaloneLauncherAction:stop()
        clearReloadAnimVars(self.character)
        logGL("Standalone load action stopped/cancelled weaponId=%s weapon=%s ammo=%s", tostring(self.weaponId),
            tostring(self.weaponType), tostring(self.ammoType))
        ISBaseTimedAction.stop(self)
    end

    function ISGGSLoadStandaloneLauncherAction:perform()
        self:applyLoad()
        clearReloadAnimVars(self.character)
        ISBaseTimedAction.perform(self)
    end

    function ISGGSLoadStandaloneLauncherAction:new(character, weaponId, weaponType, ammoType)
        local o = ISBaseTimedAction.new(self, character)
        o.stopOnRun = false
        o.stopOnWalk = false
        o.stopOnAim = false
        o.useProgressBar = false
        o.maxTime = isClient() and (RELOAD_ACTION_BASE_TIME * 2) or -1
        o.weaponId = weaponId
        o.weaponType = normalizeFullType(weaponType)
        o.ammoType = normalizeFullType(ammoType)
        return o
    end

    return true
end

local function clampTargetToRange(playerObj, x, y, z)
    local px = playerObj:getX()
    local py = playerObj:getY()
    local dx = x - px
    local dy = y - py
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= MAX_TARGET_DISTANCE then
        return x, y, z, dist
    end

    local scale = MAX_TARGET_DISTANCE / dist
    return px + dx * scale, py + dy * scale, z, MAX_TARGET_DISTANCE
end

local function fallbackForwardSquare(playerObj)
    local dir = playerObj.getForwardDirection and playerObj:getForwardDirection() or nil
    local fx = playerObj:getX()
    local fy = playerObj:getY()
    if dir and dir.getX and dir.getY then
        fx = fx + dir:getX() * 8.0
        fy = fy + dir:getY() * 8.0
    else
        fy = fy + 8.0
    end
    local fz = playerObj:getZ()
    local square = getCell():getGridSquare(roundToGrid(fx), roundToGrid(fy), roundToGrid(fz))
    return square, 8.0
end

local function pickTargetSquare(playerObj)
    local pz = playerObj:getZ()
    local playerNum = playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
    local zoom = 1.0
    local core = getCore and getCore() or nil
    if core and core.getZoom then
        local ok, value = pcall(core.getZoom, core, playerNum)
        if ok and value and value > 0 then
            zoom = value
        end
    end

    local mouseX = getMouseX and getMouseX() or nil
    local mouseY = getMouseY and getMouseY() or nil
    if not mouseX or not mouseY then
        logGL("pickTargetSquare fallback: mouse coordinates unavailable")
        return fallbackForwardSquare(playerObj)
    end

    local worldX = IsoUtils and IsoUtils.XToIso and IsoUtils.XToIso(mouseX * zoom, mouseY * zoom, pz) or nil
    local worldY = IsoUtils and IsoUtils.YToIso and IsoUtils.YToIso(mouseX * zoom, mouseY * zoom, pz) or nil
    if not worldX or not worldY then
        logGL("pickTargetSquare fallback: world conversion failed")
        return fallbackForwardSquare(playerObj)
    end

    local clampedX, clampedY, clampedZ, dist = clampTargetToRange(playerObj, worldX, worldY, pz)
    local square = getCell():getGridSquare(roundToGrid(clampedX), roundToGrid(clampedY), roundToGrid(clampedZ))
    if not square then
        square = getCell():getGridSquare(roundToGrid(clampedX), roundToGrid(clampedY), 0)
    end

    if not square then
        logGL("pickTargetSquare fallback: no square at world position")
        return fallbackForwardSquare(playerObj)
    end

    return square, dist
end

local function isGrenadeAmmoType(fullType)
    local norm = normalizeFullType(fullType)
    if not norm then
        return false
    end
    return norm:lower():sub(1, 16) == "base.grenadeammo"
end

local function collectAmmoTypesForRadial(playerObj, weapon, profile)
    local result = {}
    local seen = {}

    local function addType(fullType)
        local norm = normalizeFullType(fullType)
        if not norm then
            return
        end
        if not isGrenadeAmmoType(norm) then
            return
        end
        if seen[norm] then
            return
        end
        seen[norm] = true
        table.insert(result, norm)
    end

    addType(getPreferredAmmoType(weapon, profile))
    addType(getLoadedAmmoType(weapon, profile))
    addType(profile and profile.ammoType or "Base.GrenadeAmmo")

    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    eachInventoryItemRecursive(inventory, function(item)
        if item and item.getFullType then
            addType(item:getFullType())
        end
        return false
    end)

    table.sort(result)
    return result
end

local function resolveAmmoIcon(ammoType)
    local item = nil
    if instanceItem and ammoType then
        local ok, spawned = pcall(instanceItem, ammoType)
        if ok then
            item = spawned
        end
    end
    if item and item.getTexture then
        return item:getTexture()
    end
    return nil
end

local function centerRadialMenu(menu, playerNum)
    if not (menu and getPlayerScreenLeft and getPlayerScreenTop and getPlayerScreenWidth and getPlayerScreenHeight) then
        return
    end
    local x = getPlayerScreenLeft(playerNum)
    local y = getPlayerScreenTop(playerNum)
    local w = getPlayerScreenWidth(playerNum)
    local h = getPlayerScreenHeight(playerNum)
    x = x + (w / 2)
    y = y + (h / 2)
    menu:setX(x - (menu:getWidth() / 2))
    menu:setY(y - (menu:getHeight() / 2))
end

local function unloadLauncherAmmoSinglePlayer(playerObj, weapon, launcherType, profile)
    if not (playerObj and weapon and profile) then
        return false
    end

    local loadedAmmo = getLoadedAmmoType(weapon, profile)
    if not loadedAmmo then
        logGL("Unload ignored: launcher has no chambered ammo launcher=%s", tostring(launcherType))
        return false
    end

    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        logGL("Unload aborted: no inventory launcher=%s", tostring(launcherType))
        return false
    end

    if not removeAmmoControllerPart(weapon) then
        logGL("Unload aborted: failed to remove ammo controller launcher=%s", tostring(launcherType))
        return false
    end

    if inventory.AddItem then
        pcall(inventory.AddItem, inventory, loadedAmmo)
    end

    setPreferredAmmoType(weapon, loadedAmmo)
    fireCooldown = CLIENT_FIRE_COOLDOWN
    logGL("Unload success launcher=%s ammo=%s", tostring(launcherType), tostring(loadedAmmo))
    return true
end

local function requestUnloadLauncherAmmo(playerObj, weapon, launcherType, profile)
    local loadedAmmo = getLoadedAmmoType(weapon, profile)
    if not loadedAmmo then
        return false
    end

    local weaponId = weapon and weapon.getID and weapon:getID() or nil
    if isClient() and sendClientCommand and weaponId then
        sendClientCommand(MODULE_NAME, COMMAND_UNLOAD, {
            gunId = weaponId,
            ammoType = loadedAmmo,
            stamp = buildStamp(playerObj)
        })
        fireCooldown = CLIENT_FIRE_COOLDOWN
        logGL("Unload command sent weaponId=%s launcher=%s ammo=%s", tostring(weaponId), tostring(launcherType),
            tostring(loadedAmmo))
        return true
    end

    return unloadLauncherAmmoSinglePlayer(playerObj, weapon, launcherType, profile)
end

local function buildLauncherStatusText(weapon, profile, launcherState)
    local loadedAmmo = getLoadedAmmoType(weapon, profile)
    local breechState = isLauncherOpenState(launcherState) and ggsText("IGUI_GGS_GLOpen") or ggsText("IGUI_GGS_GLClosed")
    if loadedAmmo then
        return string.format(ggsText("IGUI_GGS_GLStatusLoaded"), shortTypeName(loadedAmmo) or ggsText("IGUI_GGS_GLUnknownAmmo"), breechState)
    end
    return string.format(ggsText("IGUI_GGS_GLStatusEmpty"), breechState)
end

local function openLauncherRadial(playerObj, weapon, launcherType, profile, launcherState)
    if not (playerObj and weapon and profile and getPlayerRadialMenu) then
        return false
    end
    if not isPlayerAiming(playerObj) then
        logGL("Radial ignored: player not aiming")
        return false
    end
    if hasQueuedTimedAction(playerObj) then
        logGL("Radial ignored: timed action queue busy")
        return false
    end

    local playerNum = playerObj:getPlayerNum()
    local menu = getPlayerRadialMenu(playerNum)
    if not menu then
        return false
    end
    if menu:isReallyVisible() then
        menu:removeFromUIManager()
        return true
    end

    menu:clear()
    menu:addSlice(buildLauncherStatusText(weapon, profile, launcherState), nil, function() end)

    local ammoTypes = collectAmmoTypesForRadial(playerObj, weapon, profile)
    local preferredAmmo = getPreferredAmmoType(weapon, profile)
    local loadedAmmo = getLoadedAmmoType(weapon, profile)
    local selectedCount = 0

    if loadedAmmo then
        local unloadLabel = ggsText("IGUI_GGS_GLUnload") .. "\n" .. (shortTypeName(loadedAmmo) or loadedAmmo)
        local unloadIcon = resolveAmmoIcon(loadedAmmo)
        menu:addSlice(unloadLabel, unloadIcon, function()
            requestUnloadLauncherAmmo(playerObj, weapon, launcherType, profile)
            menu:removeFromUIManager()
        end)
        selectedCount = selectedCount + 1
    end

    for i = 1, #ammoTypes do
        local ammoType = ammoTypes[i]
        local label = shortTypeName(ammoType) or ammoType
        if loadedAmmo and loadedAmmo == ammoType then
            label = label .. "\n" .. ggsText("IGUI_GGS_GLInChamberSuffix")
        elseif preferredAmmo == ammoType then
            label = label .. "\n" .. ggsText("IGUI_GGS_GLSelectedSuffix")
        end
        local icon = resolveAmmoIcon(ammoType)
        menu:addSlice(label, icon, function()
            setPreferredAmmoType(weapon, ammoType)
            logGL("Radial ammo selected launcher=%s ammo=%s", tostring(launcherType), tostring(ammoType))
            if playerObj and playerObj.Say then
                local msg = string.format(ggsText("IGUI_GGS_GLSelectedMessage"), shortTypeName(ammoType) or ammoType)
                pcall(playerObj.Say, playerObj, msg)
            end
            menu:removeFromUIManager()
        end)
        selectedCount = selectedCount + 1
    end

    if selectedCount == 0 then
        menu:addSlice(ggsText("IGUI_GGS_GLNoGrenades40mm"), nil, function() end)
    end

    centerRadialMenu(menu, playerNum)
    menu:addToUIManager()
    logGL("Radial opened launcher=%s state=%s options=%d", tostring(launcherType), tostring(launcherState), selectedCount)
    return true
end

local function handleExplosionFxCommand(args)
    if not args then
        logGL("ExplosionFX args=nil")
        return
    end

    local stamp = args.stamp and tostring(args.stamp) or nil
    if isStampSeen(stamp) then
        logGL("ExplosionFX duplicate ignored stamp=%s", tostring(stamp))
        return
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z) or 0
    if not x or not y then
        logGL("ExplosionFX invalid coords args=%s", tostring(args))
        return
    end

    local square = getCell():getGridSquare(roundToGrid(x), roundToGrid(y), roundToGrid(z))
    if not square then
        square = getCell():getGridSquare(roundToGrid(x), roundToGrid(y), 0)
    end
    if not square then
        logGL("ExplosionFX no square at %s,%s,%s", tostring(x), tostring(y), tostring(z))
        return
    end

    markStampSeen(stamp)
    for i = #activeProjectileMarkers, 1, -1 do
        local entry = activeProjectileMarkers[i]
        if entry and entry.stamp == stamp then
            removeProjectileVisual(entry)
            table.remove(activeProjectileMarkers, i)
        end
    end
    addExplosionMarker(square, stamp, args and args.sound)
    ggsGLApplyExplosionReactionFx(square, args and args.ammoType, stamp)
end

local function handleProjectileFxCommand(args)
    if not args then
        return
    end
    queueProjectileVisual(args)
end

local function onServerCommand(module, command, args)
    if module ~= MODULE_NAME then
        return
    end

    if command == COMMAND_EXPLOSION_FX then
        logGL("OnServerCommand ExplosionFX by=%s stamp=%s", tostring(args and args.by), tostring(args and args.stamp))
        handleExplosionFxCommand(args)
        return
    end

    if command == COMMAND_PROJECTILE_FX then
        logGL("OnServerCommand ProjectileFX by=%s stamp=%s", tostring(args and args.by), tostring(args and args.stamp))
        handleProjectileFxCommand(args)
        return
    end

    if command == COMMAND_STANDALONE_STATE then
        applyStandaloneStateFromServer(args)
    end
end

local function fireLauncherSinglePlayer(playerObj, weapon, launcherPart, launcherType, profile, square, stamp, distance)
    local shotAmmoType = getLoadedAmmoType(weapon, profile)
    if not shotAmmoType then
        logGL("SP fire aborted: launcher has no chambered ammo launcher=%s", tostring(launcherType))
        return
    end

    if not removeAmmoControllerPart(weapon) then
        logGL("SP fire aborted: failed to remove ammo controller launcher=%s", tostring(launcherType))
        return
    end

    if not ensureLauncherClosedSinglePlayer(weapon, profile) then
        logGL("SP fire warning: failed to force launcher closed launcher=%s", tostring(launcherType))
    end

    local startX = playerObj:getX()
    local startY = playerObj:getY()
    local startZ = playerObj:getZ()
    local impactSquare, impactDistance = ggsGLResolveImpactSquare(startX, startY, startZ, square)
    impactSquare = impactSquare or square
    distance = tonumber(impactDistance) or tonumber(distance) or 0
    local targetX = impactSquare:getX() + 0.5
    local targetY = impactSquare:getY() + 0.5
    local targetZ = impactSquare:getZ()
    local flightTime = computeProjectileFlightTime(distance)

    queueProjectileVisual({
        stamp = stamp,
        startX = startX,
        startY = startY,
        startZ = startZ,
        targetX = targetX,
        targetY = targetY,
        targetZ = targetZ,
        ammoType = shotAmmoType,
        flightTime = flightTime
    })
    queuePendingImpact(playerObj, launcherType, profile, impactSquare, stamp, distance, shotAmmoType, flightTime)
    playLaunchSound(playerObj, profile.launchSound)
    fireCooldown = CLIENT_FIRE_COOLDOWN
    logGL("SP fire queued launcher=%s target=%d,%d,%d dist=%.2f stamp=%s flight=%.2f", tostring(launcherType), impactSquare:getX(),
        impactSquare:getY(), impactSquare:getZ(), tonumber(distance) or 0, tostring(stamp), flightTime)
end

local function fireStandaloneLauncherSinglePlayer(playerObj, weapon, weaponType, profile, square, stamp, distance)
    local shotAmmoType = getLoadedAmmoType(weapon, profile)
    if not shotAmmoType then
        logGL("SP standalone fire aborted: no chambered ammo weapon=%s", tostring(weaponType))
        return false
    end

    if isStandaloneAmmoCountProfile(profile) then
        local currentCount = getStandaloneAmmoCount(weapon, profile)
        if currentCount <= 0 then
            logGL("SP standalone fire aborted: ammo count empty weapon=%s", tostring(weaponType))
            return false
        end
    else
        debugRpg7VisualState("fire-before-remove", weapon)
        removeAmmoControllerPart(weapon)
        debugRpg7VisualState("fire-after-remove-controller", weapon)
        if profile and profile.useModDataLoadStateOnly and profile.ammoPartType and weapon and weapon.getWeaponPart then
            local stuckAmmo = weapon:getWeaponPart(AMMO_PART_SLOT)
            if stuckAmmo and stuckAmmo.getFullType and normalizeFullType(stuckAmmo:getFullType()) ==
                normalizeFullType(profile.ammoPartType) then
                logGL("RPG7 fire sanitize: replacing stuck Ammo visual with controller")
                installWeaponPartOnSlot(weapon, AMMO_PART_SLOT, AMMO_CONTROLLER_PART_FULLTYPE)
                debugRpg7VisualState("fire-after-controller-sanitize", weapon)
            end
        end
    end

    local startX = playerObj:getX()
    local startY = playerObj:getY()
    local startZ = playerObj:getZ()
    local impactSquare, impactDistance = ggsGLResolveImpactSquare(startX, startY, startZ, square)
    impactSquare = impactSquare or square
    distance = tonumber(impactDistance) or tonumber(distance) or 0
    local targetX = impactSquare:getX() + 0.5
    local targetY = impactSquare:getY() + 0.5
    local targetZ = impactSquare:getZ()
    local flightTime = computeProjectileFlightTime(distance)

    queueProjectileVisual({
        stamp = stamp,
        startX = startX,
        startY = startY,
        startZ = startZ,
        targetX = targetX,
        targetY = targetY,
        targetZ = targetZ,
        ammoType = shotAmmoType,
        flightTime = flightTime
    })
    queuePendingImpact(playerObj, weaponType, profile, impactSquare, stamp, distance, shotAmmoType, flightTime)
    if profile and profile.ammoPartType then
        local okSync, errSync = pcall(syncStandaloneLauncherVisualPart, playerObj, weapon, profile)
        if not okSync then
            logGL("SP standalone fire warning: visual sync failed weapon=%s err=%s", tostring(weaponType), tostring(errSync))
        end
    end
    if profile and profile.id == "RPG7" then
        debugRpg7VisualState("fire-after-sync", weapon)
        -- Force a refresh on fire so the rocket attachment disappears immediately.
        refreshEquippedWeaponVisual(playerObj)
        debugRpg7VisualState("fire-after-refresh", weapon)
    end
    playLaunchSound(playerObj, profile.launchSound)
    fireCooldown = CLIENT_FIRE_COOLDOWN
    logGL("SP standalone fire queued weapon=%s target=%d,%d,%d dist=%.2f stamp=%s flight=%.2f ammo=%s count=%d",
        tostring(weaponType), impactSquare:getX(), impactSquare:getY(), impactSquare:getZ(), tonumber(distance) or 0, tostring(stamp), flightTime,
        tostring(shotAmmoType), getStandaloneAmmoCount(weapon, profile))
    return true
end

local function requestLauncherFire()
    if fireCooldown > 0 then
        logGL("Fire blocked by cooldown %.3f", fireCooldown)
        return
    end

    local playerObj = getPlayer and getPlayer() or nil
    if not playerObj then
        logGL("Fire ignored: player=nil")
        return
    end

    if not isPlayerAiming(playerObj) then
        logGL("Fire/Load ignored: player not aiming")
        return
    end
    if hasQueuedTimedAction(playerObj) then
        logGL("Fire/Load ignored: timed action queue busy")
        return
    end

    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if not (weapon and weapon.IsWeapon and weapon:IsWeapon() and weapon.isRanged and weapon:isRanged()) then
        logGL("Fire ignored: primary item is not ranged weapon")
        return
    end

    local launcherPart, launcherType, profile, launcherState = resolveLauncherPart(weapon)
    if not profile then
        logGL("Fire ignored: no grenade launcher on Stool slot (found=%s)", tostring(launcherType))
        return
    end

    local chamberedAmmoType = getLoadedAmmoType(weapon, profile)
    if not chamberedAmmoType then
        if hasQueuedTimedAction(playerObj) then
            logGL("Load ignored: timed action queue busy")
            return
        end

        local ammoType = resolveAmmoTypeForLoad(playerObj, weapon, profile)
        if not ammoType then
            logGL("Load ignored: no compatible grenade ammo launcher=%s", tostring(launcherType))
            return
        end

        if ensureLoadActionClass() and ISTimedActionQueue and ISGGSLoadLauncherAction then
            local weaponId = weapon.getID and weapon:getID() or nil
            if weaponId then
                if isLauncherClosedState(launcherState) and ISGGSOpenLauncherAction then
                    ISTimedActionQueue.add(ISGGSOpenLauncherAction:new(playerObj, weaponId, launcherType))
                    logGL("Open action queued launcher=%s", tostring(launcherType))
                end
                ISTimedActionQueue.add(ISGGSLoadLauncherAction:new(playerObj, weaponId, launcherType, ammoType))
                fireCooldown = CLIENT_FIRE_COOLDOWN
                logGL("Load action queued launcher=%s ammo=%s", tostring(launcherType), tostring(ammoType))
                return
            end
        end

        if isLauncherClosedState(launcherState) then
            ensureLauncherOpenSinglePlayer(weapon, profile)
        end
        loadLauncherSinglePlayer(playerObj, weapon, launcherPart, launcherType, profile, ammoType)
        return
    end

    if not isLauncherClosedState(launcherState) then
        logGL("Fire ignored: launcher breech open launcher=%s", tostring(launcherType))
        return
    end

    local square, distance = pickTargetSquare(playerObj)
    if not square then
        logGL("Fire aborted: target square=nil")
        return
    end

    local stamp = buildStamp(playerObj)
    local args = {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        startX = playerObj:getX(),
        startY = playerObj:getY(),
        startZ = playerObj:getZ(),
        gunId = weapon.getID and weapon:getID() or nil,
        stamp = stamp,
        ammoType = chamberedAmmoType
    }

    logGL("Fire request launcher=%s target=%d,%d,%d dist=%.2f stamp=%s client=%s", tostring(launcherType), args.x, args.y,
        args.z, tonumber(distance) or 0, tostring(stamp), tostring(isClient()))

    if isClient() and sendClientCommand then
        playLaunchSound(playerObj, profile.launchSound)
        sendClientCommand(MODULE_NAME, COMMAND_FIRE, args)
        removeAmmoControllerLocalOnly(weapon)
        refreshEquippedWeaponVisual(playerObj)
        fireCooldown = CLIENT_FIRE_COOLDOWN
        return
    end

    fireLauncherSinglePlayer(playerObj, weapon, launcherPart, launcherType, profile, square, stamp, distance)
end

local function requestStandaloneLauncherReload(playerObj, weapon)
    playerObj = playerObj or (getPlayer and getPlayer() or nil)
    if not playerObj then
        return false
    end
    if hasQueuedTimedAction(playerObj) then
        logGL("Standalone reload ignored: timed action queue busy")
        return false
    end

    weapon = weapon or (playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil)
    if not (weapon and weapon.IsWeapon and weapon:IsWeapon()) then
        return false
    end

    local profile, weaponType = resolveStandaloneLauncherProfile(weapon)
    if not profile then
        return false
    end
    if isStandaloneAmmoCountProfile(profile) then
        local currentCount = getStandaloneAmmoCount(weapon, profile)
        local capacity = getStandaloneAmmoCapacity(profile)
        if currentCount >= capacity then
            logGL("Standalone reload ignored: weapon full weapon=%s count=%d/%d", tostring(weaponType), currentCount, capacity)
            return false
        end
    elseif getLoadedAmmoType(weapon, profile) then
        local okSync, syncChanged = pcall(syncStandaloneLauncherVisualPart, playerObj, weapon, profile)
        if okSync and syncChanged then
            logGL("Standalone reload resynced visual part weapon=%s", tostring(weaponType))
            return true
        elseif not okSync then
            logGL("Standalone reload warning: visual resync failed weapon=%s", tostring(weaponType))
        end
        logGL("Standalone reload ignored: weapon already loaded weapon=%s", tostring(weaponType))
        return false
    end

    local ammoType = getLoadedAmmoType(weapon, profile) or resolveAmmoTypeForLoad(playerObj, weapon, profile)
    if not ammoType then
        logGL("Standalone reload ignored: ammo missing weapon=%s preferred=%s", tostring(weaponType),
            tostring(profile.ammoType))
        return false
    end

    if ensureLoadActionClass() and ISTimedActionQueue and ISGGSLoadStandaloneLauncherAction then
        local weaponId = weapon.getID and weapon:getID() or nil
        if weaponId then
            ISTimedActionQueue.add(ISGGSLoadStandaloneLauncherAction:new(playerObj, weaponId, weaponType, ammoType))
            fireCooldown = CLIENT_FIRE_COOLDOWN
            logGL("Standalone load action queued weapon=%s ammo=%s", tostring(weaponType), tostring(ammoType))
            return true
        end
    end

    if isClient() and isStandaloneMpSupported(profile) then
        setPreferredAmmoType(weapon, ammoType)
        sendClientCommand(MODULE_NAME, COMMAND_LOAD, {
            gunId = weapon.getID and weapon:getID() or nil,
            ammoType = ammoType,
            stamp = buildStamp(playerObj),
            standalone = true
        })
        fireCooldown = CLIENT_FIRE_COOLDOWN
        logGL("Standalone reload command sent weapon=%s ammo=%s", tostring(weaponType), tostring(ammoType))
        return true
    elseif isClient() then
        logGL("Standalone reload MP not implemented yet weapon=%s", tostring(weaponType))
        return false
    end

    return loadStandaloneLauncherSinglePlayer(playerObj, weapon, weaponType, profile, ammoType)
end

GGS_RequestStandaloneLauncherReload = requestStandaloneLauncherReload

local function requestStandaloneLauncherFireByClick(playerObj, weapon)
    if fireCooldown > 0 then
        return false
    end
    if not (playerObj and weapon) then
        return false
    end
    if not isPlayerAiming(playerObj) then
        return false
    end
    if hasQueuedTimedAction(playerObj) then
        return false
    end

    local profile, weaponType = resolveStandaloneLauncherProfile(weapon)
    if not profile then
        return false
    end

    local chamberedAmmoType = getLoadedAmmoType(weapon, profile)
    local standaloneCount = getStandaloneAmmoCount(weapon, profile)
    if not chamberedAmmoType and not (isClient() and isStandaloneMpSupported(profile)) then
        logGL("Standalone fire ignored: weapon=%s not loaded", tostring(weaponType))
        return true
    end
    if isClient() and isStandaloneMpSupported(profile) and standaloneCount <= 0 and not chamberedAmmoType then
        logGL("Standalone fire ignored: weapon=%s no local ammo count=%d", tostring(weaponType), standaloneCount)
        return true
    end
    if not chamberedAmmoType and isClient() and isStandaloneMpSupported(profile) then
        chamberedAmmoType = getPreferredAmmoType(weapon, profile) or normalizeFullType(profile.ammoType)
        logGL("Standalone fire MP deferred load validation to server weapon=%s ammo=%s count=%d",
            tostring(weaponType), tostring(chamberedAmmoType), standaloneCount)
    end

    local square, distance = pickTargetSquare(playerObj)
    if not square then
        logGL("Standalone fire aborted: target square=nil weapon=%s", tostring(weaponType))
        return true
    end

    local stamp = buildStamp(playerObj)
    if isClient() and sendClientCommand and isStandaloneMpSupported(profile) then
        playLaunchSound(playerObj, profile.launchSound)
        sendClientCommand(MODULE_NAME, COMMAND_FIRE, {
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            startX = playerObj:getX(),
            startY = playerObj:getY(),
            startZ = playerObj:getZ(),
            gunId = weapon.getID and weapon:getID() or nil,
            ammoType = chamberedAmmoType,
            vanillaShot = true,
            clientAmmoCount = standaloneCount,
            stamp = stamp,
            standalone = true
        })
        if getStandaloneAmmoCapacity(profile) <= 1 then
            setStandaloneAmmoCountLocalOnly(weapon, profile, 0)
            clearLoadedAmmoTypeLocalOnly(weapon)
        elseif getStandaloneAmmoCount(weapon, profile) <= 0 then
            setStandaloneAmmoCountLocalOnly(weapon, profile, 0)
            clearLoadedAmmoTypeLocalOnly(weapon)
        end
        refreshEquippedWeaponVisual(playerObj)
        fireCooldown = CLIENT_FIRE_COOLDOWN
        logGL("Standalone fire command sent weapon=%s stamp=%s", tostring(weaponType), tostring(stamp))
        return true
    elseif isClient() then
        -- MP standalone todavia no tiene backend de servidor para dano/explosion.
        logGL("Standalone fire MP not implemented yet weapon=%s stamp=%s", tostring(weaponType), tostring(stamp))
        return true
    end

    fireStandaloneLauncherSinglePlayer(playerObj, weapon, weaponType, profile, square, stamp, distance)
    return true
end

local function onWeaponSwing(character, weapon)
    if not (character and weapon) then
        return
    end

    local localPlayer = getPlayer and getPlayer() or nil
    if not localPlayer or character ~= localPlayer then
        return
    end

    requestStandaloneLauncherFireByClick(character, weapon)
end

function onPlayerAttackFinished(playerObj, weapon)
    onWeaponSwing(playerObj, weapon)
end

local function onLaunchKeyStartPressed(key)
    if key ~= getLaunchKey() then
        return
    end
    if gKeyHoldState.pressedMs then
        return
    end
    gKeyHoldState.pressedMs = getNowMs()
    gKeyHoldState.consumedByRadial = false
end

local function onLaunchKeyKeepPressed(key)
    if key ~= getLaunchKey() then
        return
    end
    if not gKeyHoldState.pressedMs or gKeyHoldState.consumedByRadial then
        return
    end

    if (getNowMs() - gKeyHoldState.pressedMs) < RELOAD_HOLD_MENU_DELAY_MS then
        return
    end

    local playerObj = getPlayer and getPlayer() or nil
    if not playerObj then
        return
    end

    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if not (weapon and weapon.IsWeapon and weapon:IsWeapon() and weapon.isRanged and weapon:isRanged()) then
        return
    end

    local _, launcherType, profile, launcherState = resolveLauncherPart(weapon)
    if not profile then
        return
    end

    if openLauncherRadial(playerObj, weapon, launcherType, profile, launcherState) then
        gKeyHoldState.consumedByRadial = true
    end
end

local function processLaunchKeyRelease()
    if not gKeyHoldState.pressedMs then
        return
    end
    if isLaunchKeyDown() then
        return
    end
    local consumed = gKeyHoldState.consumedByRadial
    gKeyHoldState.pressedMs = nil
    gKeyHoldState.consumedByRadial = false
    if consumed then
        return
    end
    requestLauncherFire()
end

local function onTick()
    local dt = getDeltaTime()
    processLaunchKeyRelease()
    if fireCooldown > 0 then
        fireCooldown = math.max(0.0, fireCooldown - dt)
    end
    cleanupProjectileMarkers(dt)
    cleanupMarkers(dt)
    cleanupTrapProxyCleanups(dt)
    processPendingImpacts(dt)
    updateSeenStamps(dt)
    updateProjectileStamps(dt)
    local playerObj = getPlayer and getPlayer() or nil
    if playerObj then
        local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
        local profile = weapon and resolveStandaloneLauncherProfile(weapon) or nil
        if profile then
            local okSync = pcall(syncStandaloneLauncherState, playerObj, weapon, profile)
            if not okSync then
                -- Avoid blocking projectile/explosion processing if visual slot probing fails.
            end
        end
    end
end

local function registerHandlers()
    ensureFxTextures()

    if not keyHandlerRegistered and Events then
        if Events.OnKeyStartPressed and Events.OnKeyStartPressed.Add then
            Events.OnKeyStartPressed.Add(onLaunchKeyStartPressed)
        end
        if Events.OnKeyPressed and Events.OnKeyPressed.Add then
            -- B42 can dispatch either StartPressed or Pressed depending on input context.
            Events.OnKeyPressed.Add(onLaunchKeyStartPressed)
        end
        if Events.OnKeyKeepPressed and Events.OnKeyKeepPressed.Add then
            Events.OnKeyKeepPressed.Add(onLaunchKeyKeepPressed)
        end
        keyHandlerRegistered = true
        logGL("Key handler registered key=%s", tostring(getLaunchKey()))
    end

    if not serverHandlerRegistered and Events and Events.OnServerCommand and Events.OnServerCommand.Add then
        Events.OnServerCommand.Add(onServerCommand)
        serverHandlerRegistered = true
        logGL("Server command handler registered")
    end

    if not weaponSwingHandlerRegistered and Events and Events.OnWeaponSwing and Events.OnWeaponSwing.Add then
        Events.OnWeaponSwing.Add(onWeaponSwing)
        weaponSwingHandlerRegistered = true
        logGL("Weapon swing handler registered")
    end

    if not __GGS_GL_PLAYER_ATTACK_FINISHED_HANDLER_REGISTERED and Events and Events.OnPlayerAttackFinished and Events.OnPlayerAttackFinished.Add then
        Events.OnPlayerAttackFinished.Add(onPlayerAttackFinished)
        __GGS_GL_PLAYER_ATTACK_FINISHED_HANDLER_REGISTERED = true
        logGL("Player attack finished handler registered")
    end

    if not tickHandlerRegistered and Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(onTick)
        if Events.RenderOpaqueObjectsInWorld and Events.RenderOpaqueObjectsInWorld.Add then
            Events.RenderOpaqueObjectsInWorld.Add(renderProjectileVisuals)
        end
        tickHandlerRegistered = true
        logGL("Tick/projectile render handler registered")
    end
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(registerHandlers)
end
if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(registerHandlers)
end

registerHandlers()
