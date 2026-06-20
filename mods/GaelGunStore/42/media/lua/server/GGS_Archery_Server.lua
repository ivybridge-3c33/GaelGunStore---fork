local MODULE_NAME = "GGS_ArcheryFX"
local COMMAND_ARROW_IMPACT = "ArrowImpact"
local COMMAND_ARROW_ZOMBIE_HIT = "ArrowZombieHit"
local COMMAND_ARROW_IMPACT_FX = "ArrowImpactFX"
local DEBUG_ARCHERY_SERVER = false
local ARCHERY_BOW_DAMAGE_MULT = 1.00
local ARCHERY_CROSSBOW_DAMAGE_MULT = 1.15
local ARCHERY_BOW_MIN_DAMAGE = 0.10
local ARCHERY_CROSSBOW_MIN_DAMAGE = 0.25
local ARCHERY_BOW_HEALTH_SCALE = 0.22
local ARCHERY_CROSSBOW_HEALTH_SCALE = 0.30
local ARCHERY_BOW_HEALTH_MIN = 0.05
local ARCHERY_CROSSBOW_HEALTH_MIN = 0.08
local ARCHERY_MICRO_IMPACT_MIN_RADIUS = 0.18
local ARCHERY_MICRO_IMPACT_MAX_RADIUS = 0.50
local ARCHERY_MICRO_IMPACT_SCALE = 0.40
local ARCHERY_MICRO_IMPACT_ASSIST_RADIUS = 1.10
local ARCHERY_DAMAGE_ACCUM_KEY = "ggsArcheryDamageAccum"
GGS_ArcheryServer = GGS_ArcheryServer or {}

local function logArchery(fmt, ...)
    if not DEBUG_ARCHERY_SERVER then
        return
    end
    local ok, msg = pcall(string.format, fmt, ...)
    if ok then
        print("[GGS ARCHERY][server] " .. msg)
    else
        print("[GGS ARCHERY][server] " .. tostring(fmt))
    end
end

local function describeZombieDebug(zombie)
    if not zombie then
        return "nil"
    end

    local parts = { tostring(zombie) }
    if zombie.getX and zombie.getY and zombie.getZ then
        local okX, x = pcall(zombie.getX, zombie)
        local okY, y = pcall(zombie.getY, zombie)
        local okZ, z = pcall(zombie.getZ, zombie)
        if okX and okY and okZ then
            table.insert(parts, string.format("xyz=%.2f,%.2f,%.2f", tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0))
        end
    end
    if zombie.getOnlineID then
        local ok, value = pcall(zombie.getOnlineID, zombie)
        if ok and value ~= nil then
            table.insert(parts, "onlineId=" .. tostring(value))
        end
    end
    if zombie.getObjectID then
        local ok, value = pcall(zombie.getObjectID, zombie)
        if ok and value ~= nil then
            table.insert(parts, "objectId=" .. tostring(value))
        end
    end
    if zombie.getID then
        local ok, value = pcall(zombie.getID, zombie)
        if ok and value ~= nil then
            table.insert(parts, "id=" .. tostring(value))
        end
    end
    if zombie.getPersistentOutfitID then
        local ok, value = pcall(zombie.getPersistentOutfitID, zombie)
        if ok and value ~= nil then
            table.insert(parts, "outfit=" .. tostring(value))
        end
    end
    return table.concat(parts, " ")
end

local function describeArgsTargetDebug(args)
    if not args then
        return "nil"
    end
    return string.format(
        "aim=%s reason=%s impact=%.2f,%.2f,%s segmentStart=%.2f,%.2f,%s target=%.2f,%.2f,%s square=%s,%s,%s ids={online=%s object=%s id=%s outfit=%s} zone=%s relZ=%s lateral=%s",
        tostring(args.aimMode),
        tostring(args.impactReason),
        tonumber(args.impactX) or 0,
        tonumber(args.impactY) or 0,
        tostring(args.impactZ),
        tonumber(args.segmentStartX) or tonumber(args.impactX) or 0,
        tonumber(args.segmentStartY) or tonumber(args.impactY) or 0,
        tostring(args.segmentStartZ),
        tonumber(args.targetX) or tonumber(args.impactX) or 0,
        tonumber(args.targetY) or tonumber(args.impactY) or 0,
        tostring(args.targetZ),
        tostring(args.impactSquareX),
        tostring(args.impactSquareY),
        tostring(args.impactSquareZ),
        tostring(args.targetOnlineId),
        tostring(args.targetObjectId),
        tostring(args.targetId),
        tostring(args.targetPersistentOutfitId),
        tostring(args.hitZone),
        tostring(args.hitZoneRelZ),
        tostring(args.hitZoneLateral)
    )
end

local function estimateArcheryImpactZone(zombie, impactX, impactY, impactZ)
    if not zombie then
        return "world", nil, nil
    end

    local zx = tonumber(zombie.getX and zombie:getX()) or tonumber(impactX) or 0.0
    local zy = tonumber(zombie.getY and zombie:getY()) or tonumber(impactY) or 0.0
    local zz = tonumber(zombie.getZ and zombie:getZ()) or tonumber(impactZ) or 0.0
    local hitZ = tonumber(impactZ) or zz
    local relZ = hitZ - zz
    local impactPosX = tonumber(impactX) or zx
    local impactPosY = tonumber(impactY) or zy
    local dx = impactPosX - zx
    local dy = impactPosY - zy
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

local function buildArrowImpactFxArgs(playerObj, weaponType, ammoType, zombie, sourceLabel, impactX, impactY, impactZ, damage, oldHealth, newHealth, hitReaction, hitZone, hitZoneRelZ, hitZoneLateral, attachSlot)
    if not zombie then
        return nil
    end

    local args = {
        by = playerObj and playerObj.getOnlineID and playerObj:getOnlineID() or -1,
        weaponType = weaponType,
        ammoType = ammoType,
        source = sourceLabel,
        impactX = tonumber(impactX) or (zombie.getX and zombie:getX()) or 0,
        impactY = tonumber(impactY) or (zombie.getY and zombie:getY()) or 0,
        impactZ = tonumber(impactZ) or (zombie.getZ and zombie:getZ()) or 0,
        damage = tonumber(damage) or 0,
        oldHealth = tonumber(oldHealth) or 0,
        newHealth = tonumber(newHealth) or 0,
        reaction = tostring(hitReaction or "arrow_light"),
        hitZone = tostring(hitZone or ""),
        hitZoneRelZ = tonumber(hitZoneRelZ),
        hitZoneLateral = tonumber(hitZoneLateral),
        attachSlot = tostring(attachSlot or "")
    }

    if zombie.getX then
        local ok, value = pcall(zombie.getX, zombie)
        if ok and tonumber(value) then
            args.targetX = tonumber(value)
        end
    end
    if zombie.getY then
        local ok, value = pcall(zombie.getY, zombie)
        if ok and tonumber(value) then
            args.targetY = tonumber(value)
        end
    end
    if zombie.getZ then
        local ok, value = pcall(zombie.getZ, zombie)
        if ok and tonumber(value) then
            args.targetZ = tonumber(value)
        end
    end
    if zombie.getOnlineID then
        local ok, value = pcall(zombie.getOnlineID, zombie)
        if ok and value ~= nil then
            args.targetOnlineId = tostring(value)
        end
    end
    if zombie.getObjectID then
        local ok, value = pcall(zombie.getObjectID, zombie)
        if ok and value ~= nil then
            args.targetObjectId = tostring(value)
        end
    end
    if zombie.getID then
        local ok, value = pcall(zombie.getID, zombie)
        if ok and value ~= nil then
            args.targetId = tostring(value)
        end
    end
    if zombie.getPersistentOutfitID then
        local ok, value = pcall(zombie.getPersistentOutfitID, zombie)
        if ok and value ~= nil then
            args.targetPersistentOutfitId = tostring(value)
        end
    end

    return args
end

local function sendArrowImpactFx(args)
    if not (sendServerCommand and args) then
        return false
    end

    sendServerCommand(MODULE_NAME, COMMAND_ARROW_IMPACT_FX, args)
    logArchery(
        "impact-fx sent by=%s weapon=%s ammo=%s impact=%.2f,%.2f,%.2f dmg=%.2f hp=%.2f->%.2f killed=%s ids={online=%s object=%s id=%s outfit=%s}",
        tostring(args.by),
        tostring(args.weaponType),
        tostring(args.ammoType),
        tonumber(args.impactX) or 0,
        tonumber(args.impactY) or 0,
        tonumber(args.impactZ) or 0,
        tonumber(args.damage) or 0,
        tonumber(args.oldHealth) or 0,
        tonumber(args.newHealth) or 0,
        tostring(args.killed),
        tostring(args.targetOnlineId),
        tostring(args.targetObjectId),
        tostring(args.targetId),
        tostring(args.targetPersistentOutfitId)
    )
    return true
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
    if not fullType:find(".", 1, true) then
        fullType = "Base." .. fullType
    end
    return fullType
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

local function distance2D(ax, ay, bx, by)
    local dx = (tonumber(ax) or 0) - (tonumber(bx) or 0)
    local dy = (tonumber(ay) or 0) - (tonumber(by) or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function resolveMicroImpactRadius(requestedRadius)
    local requested = tonumber(requestedRadius) or 0.90
    local scaled = requested * ARCHERY_MICRO_IMPACT_SCALE
    return math.max(ARCHERY_MICRO_IMPACT_MIN_RADIUS, math.min(ARCHERY_MICRO_IMPACT_MAX_RADIUS, scaled))
end

local function getWeaponFullType(weapon)
    if not weapon then
        return nil
    end
    if weapon.getFullType then
        local ok, value = pcall(weapon.getFullType, weapon)
        if ok and value then
            return normalizeFullType(value)
        end
    end
    if weapon.getType then
        local ok, value = pcall(weapon.getType, weapon)
        if ok and value then
            return normalizeFullType(value)
        end
    end
    return nil
end

local function getBowProfile(fullType)
    local defs = rawget(_G, "GGS_BOWS")
    if defs and defs.getWeaponProfile then
        local ok, profile = pcall(defs.getWeaponProfile, fullType)
        if ok and profile then
            return profile
        end
    end
    return defs and defs.Weapons and defs.Weapons[normalizeFullType(fullType)] or nil
end

local function getAmmoProfile(fullType)
    local defs = rawget(_G, "GGS_BOWS")
    if defs and defs.getAmmoProfile then
        local ok, profile = pcall(defs.getAmmoProfile, fullType)
        if ok and profile then
            return profile
        end
    end
    return defs and defs.Ammo and defs.Ammo[normalizeFullType(fullType)] or nil
end

local recentAttachments = {}

local function consumeRecentAttachment(zombie, attacker, weaponType)
    local zombieKey = tostring(zombie)
    local attackerKey = attacker and attacker.getOnlineID and tostring(attacker:getOnlineID()) or "sp"
    local key = attackerKey .. "|" .. tostring(weaponType or "unknown") .. "|" .. zombieKey
    local current = nowMs()
    local expiresAt = tonumber(recentAttachments[key]) or 0
    if expiresAt > current then
        return true
    end
    recentAttachments[key] = current + 260
    return false
end

local function resolveEquippedBow(playerObj, wantedType)
    if not playerObj then
        return nil, nil, nil
    end

    local wanted = normalizeFullType(wantedType)
    local primary = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    local secondary = playerObj.getSecondaryHandItem and playerObj:getSecondaryHandItem() or nil
    local candidates = { primary, secondary }

    for i = 1, #candidates do
        local weapon = candidates[i]
        local fullType = getWeaponFullType(weapon)
        local profile = getBowProfile(fullType)
        if weapon and profile and ((not wanted) or fullType == wanted) then
            return weapon, fullType, profile
        end
    end

    for i = 1, #candidates do
        local weapon = candidates[i]
        local fullType = getWeaponFullType(weapon)
        local profile = getBowProfile(fullType)
        if weapon and profile then
            return weapon, fullType, profile
        end
    end

    return nil, nil, nil
end

local function isZombieUsable(zombie)
    if not (zombie and instanceof and instanceof(zombie, "IsoZombie")) then
        return false
    end
    if zombie.isDead then
        local ok, dead = pcall(zombie.isDead, zombie)
        if ok and dead then
            return false
        end
    end
    if zombie.getSquare then
        local ok, square = pcall(zombie.getSquare, zombie)
        if ok and square == nil then
            return false
        end
    end
    return true
end

local function getZombieIdentityMap(zombie)
    if not zombie then
        return nil
    end

    local ids = {}
    if zombie.getOnlineID then
        local ok, value = pcall(zombie.getOnlineID, zombie)
        if ok and value ~= nil then
            ids.onlineId = tostring(value)
        end
    end
    if zombie.getObjectID then
        local ok, value = pcall(zombie.getObjectID, zombie)
        if ok and value ~= nil then
            ids.objectId = tostring(value)
        end
    end
    if zombie.getID then
        local ok, value = pcall(zombie.getID, zombie)
        if ok and value ~= nil then
            ids.id = tostring(value)
        end
    end
    if zombie.getPersistentOutfitID then
        local ok, value = pcall(zombie.getPersistentOutfitID, zombie)
        if ok and value ~= nil then
            ids.persistentOutfitId = tostring(value)
        end
    end

    return ids
end

local function zombieMatchesTargetArgs(zombie, args)
    if not (zombie and args) then
        return false
    end

    local ids = getZombieIdentityMap(zombie)
    if not ids then
        return false
    end

    if args.targetOnlineId and ids.onlineId and tostring(args.targetOnlineId) == ids.onlineId then
        return true
    end
    if args.targetObjectId and ids.objectId and tostring(args.targetObjectId) == ids.objectId then
        return true
    end
    if args.targetId and ids.id and tostring(args.targetId) == ids.id then
        return true
    end
    if args.targetPersistentOutfitId and ids.persistentOutfitId and tostring(args.targetPersistentOutfitId) == ids.persistentOutfitId then
        return true
    end

    return false
end

local function findNearestZombieNearImpact(impactX, impactY, impactZ, searchRadius, targetX, targetY, targetZ)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return nil, nil
    end

    local refX = tonumber(targetX) or tonumber(impactX) or 0
    local refY = tonumber(targetY) or tonumber(impactY) or 0
    local refZ = math.floor(tonumber(targetZ) or tonumber(impactZ) or 0)
    local impactZFloor = math.floor(tonumber(impactZ) or refZ)
    local radius = math.max(0.5, tonumber(searchRadius) or 1.2)
    local baseX = tonumber(impactX) or refX
    local baseY = tonumber(impactY) or refY
    local minX = math.floor(math.min(baseX, refX) - radius - 1)
    local maxX = math.ceil(math.max(baseX, refX) + radius + 1)
    local minY = math.floor(math.min(baseY, refY) - radius - 1)
    local maxY = math.ceil(math.max(baseY, refY) + radius + 1)

    local best = nil
    local bestScore = nil
    for z = math.min(refZ, impactZFloor) - 1, math.max(refZ, impactZFloor) + 1 do
        for sx = minX, maxX do
            for sy = minY, maxY do
                local square = cell:getGridSquare(sx, sy, z)
                if square and square.getMovingObjects then
                    local movingObjects = square:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if isZombieUsable(moving) then
                                local zx = tonumber(moving:getX()) or sx
                                local zy = tonumber(moving:getY()) or sy
                                local impactDist = distance2D(impactX, impactY, zx, zy)
                                if impactDist <= radius then
                                    local refDist = distance2D(refX, refY, zx, zy)
                                    local score = refDist + (impactDist * 0.35)
                                    if (not bestScore) or score < bestScore then
                                        best = moving
                                        bestScore = score
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best, bestScore
end

local function findZombieAtMicroImpactPoint(impactX, impactY, impactZ, impactRadius, args)
    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return nil, nil
    end

    local radius = math.max(ARCHERY_MICRO_IMPACT_MIN_RADIUS,
        math.min(ARCHERY_MICRO_IMPACT_MAX_RADIUS, tonumber(impactRadius) or ARCHERY_MICRO_IMPACT_MIN_RADIUS))
    local baseX = tonumber(impactX) or 0
    local baseY = tonumber(impactY) or 0
    local baseZ = math.floor(tonumber(impactZ) or 0)
    local minX = math.floor(baseX - radius - 1)
    local maxX = math.ceil(baseX + radius + 1)
    local minY = math.floor(baseY - radius - 1)
    local maxY = math.ceil(baseY + radius + 1)
    local best = nil
    local bestScore = nil

    for z = baseZ - 1, baseZ + 1 do
        for sx = minX, maxX do
            for sy = minY, maxY do
                local square = cell:getGridSquare(sx, sy, z)
                if square and square.getMovingObjects then
                    local movingObjects = square:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if isZombieUsable(moving) then
                                local zx = tonumber(moving:getX()) or sx
                                local zy = tonumber(moving:getY()) or sy
                                local zz = math.floor(tonumber(moving:getZ()) or z)
                                local impactDist = distance2D(baseX, baseY, zx, zy)
                                local zDelta = math.abs(zz - baseZ)
                                if impactDist <= radius and zDelta <= 1 then
                                    local score = impactDist + (zDelta * 0.15)
                                    if zombieMatchesTargetArgs(moving, args) then
                                        score = score - 0.10
                                    end
                                    if (not bestScore) or score < bestScore then
                                        best = moving
                                        bestScore = score
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best, bestScore
end

local function findTargetZombieByArgs(impactX, impactY, impactZ, searchRadius, args)
    if not args then
        return nil
    end
    if not (args.targetOnlineId or args.targetObjectId or args.targetId or args.targetPersistentOutfitId) then
        return nil
    end

    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return nil
    end

    local refX = tonumber(args.targetX) or tonumber(impactX) or 0
    local refY = tonumber(args.targetY) or tonumber(impactY) or 0
    local refZ = math.floor(tonumber(args.targetZ) or tonumber(impactZ) or 0)
    local radius = math.max(1.5, tonumber(searchRadius) or 1.5)
    local minX = math.floor(refX - radius - 1)
    local maxX = math.ceil(refX + radius + 1)
    local minY = math.floor(refY - radius - 1)
    local maxY = math.ceil(refY + radius + 1)

    for z = refZ - 1, refZ + 1 do
        for sx = minX, maxX do
            for sy = minY, maxY do
                local square = cell:getGridSquare(sx, sy, z)
                if square and square.getMovingObjects then
                    local movingObjects = square:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local moving = movingObjects:get(i)
                            if isZombieUsable(moving) and zombieMatchesTargetArgs(moving, args) then
                                logArchery("target-by-ids matched %s from %s", describeZombieDebug(moving), describeArgsTargetDebug(args))
                                return moving
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function getGlobalZombieList()
    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end

    if cell.getZombieList then
        local ok, list = pcall(cell.getZombieList, cell)
        if ok and list then
            return list
        end
    end

    return nil
end

local function findTargetZombieInGlobalList(refX, refY, refZ, searchRadius, args)
    local zombieList = getGlobalZombieList()
    if not zombieList then
        return nil
    end

    local best = nil
    local bestScore = nil
    local radius = math.max(1.5, tonumber(searchRadius) or 1.5)
    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if isZombieUsable(zombie) then
            local zx = tonumber(zombie:getX()) or 0
            local zy = tonumber(zombie:getY()) or 0
            local zz = math.floor(tonumber(zombie:getZ()) or 0)
            local dist = distance2D(refX, refY, zx, zy)
            local zDelta = math.abs(zz - math.floor(tonumber(refZ) or 0))
            local idMatch = zombieMatchesTargetArgs(zombie, args)
            if idMatch or (dist <= radius and zDelta <= 1) then
                local score = dist + (zDelta * 0.35)
                if idMatch then
                    score = score - 1000
                end
                if (not bestScore) or score < bestScore then
                    best = zombie
                    bestScore = score
                end
            end
        end
    end

    return best, bestScore
end

local function buildNearbyZombieDebug(refX, refY, refZ, searchRadius, args)
    local zombieList = getGlobalZombieList()
    if not zombieList then
        return "globalZombieList=nil"
    end

    local radius = math.max(1.5, tonumber(searchRadius) or 1.5)
    local out = {}
    local count = 0
    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if isZombieUsable(zombie) then
            local zx = tonumber(zombie:getX()) or 0
            local zy = tonumber(zombie:getY()) or 0
            local zz = math.floor(tonumber(zombie:getZ()) or 0)
            local dist = distance2D(refX, refY, zx, zy)
            local zDelta = math.abs(zz - math.floor(tonumber(refZ) or 0))
            if dist <= (radius + 2.0) and zDelta <= 1 then
                count = count + 1
                if count <= 5 then
                    local matched = zombieMatchesTargetArgs(zombie, args)
                    out[#out + 1] = string.format("cand%d={%s dist=%.2f match=%s}", count, describeZombieDebug(zombie), dist, tostring(matched))
                end
            end
        end
    end

    if count == 0 then
        return "nearbyCandidates=0"
    end
    return string.format("nearbyCandidates=%d %s", count, table.concat(out, " | "))
end

local function lerp(a, b, t)
    return (tonumber(a) or 0.0) + (((tonumber(b) or 0.0) - (tonumber(a) or 0.0)) * (tonumber(t) or 0.0))
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

local function findZombieAlongImpactSegment(x1, y1, z1, x2, y2, z2, impactRadius, args)
    if x1 == nil or y1 == nil or z1 == nil then
        return nil, nil, nil, nil, nil
    end

    local cell = getCell and getCell() or nil
    if not (cell and cell.getGridSquare) then
        return nil, nil, nil, nil, nil
    end

    local radius = math.max(ARCHERY_MICRO_IMPACT_MIN_RADIUS, tonumber(impactRadius) or ARCHERY_MICRO_IMPACT_MIN_RADIUS)
    local radiusSq = radius * radius
    local minX = math.floor(math.min(tonumber(x1) or 0.0, tonumber(x2) or 0.0) - radius - 1.0)
    local maxX = math.ceil(math.max(tonumber(x1) or 0.0, tonumber(x2) or 0.0) + radius + 1.0)
    local minY = math.floor(math.min(tonumber(y1) or 0.0, tonumber(y2) or 0.0) - radius - 1.0)
    local maxY = math.ceil(math.max(tonumber(y1) or 0.0, tonumber(y2) or 0.0) + radius + 1.0)
    local minZ = math.floor(math.min(tonumber(z1) or 0.0, tonumber(z2) or 0.0)) - 1
    local maxZ = math.floor(math.max(tonumber(z1) or 0.0, tonumber(z2) or 0.0)) + 1

    local bestZombie = nil
    local bestX, bestY, bestZ = nil, nil, nil
    local bestProgress, bestDistSq, bestZDelta, bestIdMatch = nil, nil, nil, false

    for scanZ = minZ, maxZ do
        for sx = minX, maxX do
            for sy = minY, maxY do
                local square = cell:getGridSquare(sx, sy, scanZ)
                if square and square.getMovingObjects then
                    local movingObjects = square:getMovingObjects()
                    if movingObjects then
                        for i = 0, movingObjects:size() - 1 do
                            local zombie = movingObjects:get(i)
                            if isZombieUsable(zombie) then
                                local zx = tonumber(zombie:getX()) or sx
                                local zy = tonumber(zombie:getY()) or sy
                                local distSq, progress, hitX, hitY = distanceSqPointToSegment2D(zx, zy, x1, y1, x2, y2)
                                if distSq <= radiusSq then
                                    local hitZ = lerp(z1, z2, progress)
                                    local zDelta = math.abs((tonumber(zombie:getZ()) or scanZ) - hitZ)
                                    if zDelta <= 1.10 then
                                        local idMatch = zombieMatchesTargetArgs(zombie, args)
                                        local better = false
                                        if bestZombie == nil then
                                            better = true
                                        elseif progress < (bestProgress - 0.05) then
                                            better = true
                                        elseif math.abs(progress - bestProgress) <= 0.05 then
                                            if idMatch and not bestIdMatch then
                                                better = true
                                            elseif idMatch == bestIdMatch then
                                                if distSq < (bestDistSq - 0.0001) then
                                                    better = true
                                                elseif math.abs(distSq - bestDistSq) <= 0.0001 and zDelta < (bestZDelta - 0.0001) then
                                                    better = true
                                                end
                                            end
                                        end

                                        if better then
                                            bestZombie = zombie
                                            bestX = hitX
                                            bestY = hitY
                                            bestZ = hitZ
                                            bestProgress = progress
                                            bestDistSq = distSq
                                            bestZDelta = zDelta
                                            bestIdMatch = idMatch
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

local function resolveArcheryImpactZombie(impactX, impactY, impactZ, impactRadius, args)
    local microRadius = resolveMicroImpactRadius(impactRadius)
    local assistRadius = math.max(ARCHERY_MICRO_IMPACT_ASSIST_RADIUS, tonumber(impactRadius) or 0.90)

    local segmentStartX = tonumber(args and args.segmentStartX)
    local segmentStartY = tonumber(args and args.segmentStartY)
    local segmentStartZ = tonumber(args and args.segmentStartZ)
    if segmentStartX ~= nil and segmentStartY ~= nil and segmentStartZ ~= nil then
        local segmentZombie, segmentX, segmentY, segmentZ, segmentProgress = findZombieAlongImpactSegment(
            segmentStartX,
            segmentStartY,
            segmentStartZ,
            impactX,
            impactY,
            impactZ,
            impactRadius,
            args
        )
        if segmentZombie then
            return segmentZombie, "segment", microRadius, segmentProgress, segmentX, segmentY, segmentZ
        end
    end

    local targetZombie, score = findZombieAtMicroImpactPoint(impactX, impactY, impactZ, microRadius, args)
    if targetZombie then
        return targetZombie, "micro", microRadius, score, impactX, impactY, impactZ
    end

    targetZombie = findTargetZombieByArgs(impactX, impactY, impactZ, assistRadius, args)
    if targetZombie then
        return targetZombie, "id_fallback", microRadius, nil, impactX, impactY, impactZ
    end

    targetZombie = findNearestZombieNearImpact(
        impactX,
        impactY,
        impactZ,
        assistRadius,
        tonumber(args and args.targetX) or impactX,
        tonumber(args and args.targetY) or impactY,
        tonumber(args and args.targetZ) or impactZ
    )
    if targetZombie then
        return targetZombie, "near_fallback", microRadius, nil, impactX, impactY, impactZ
    end

    targetZombie = findTargetZombieInGlobalList(
        tonumber(args and args.targetX) or impactX,
        tonumber(args and args.targetY) or impactY,
        tonumber(args and args.targetZ) or impactZ,
        assistRadius,
        args
    )
    if targetZombie then
        return targetZombie, "global_fallback", microRadius, nil, impactX, impactY, impactZ
    end

    return nil, "miss", microRadius, nil, impactX, impactY, impactZ
end

local function chooseAttachLocation(zombie, impactZone)
    local preferred = { "Knife Stomach", "Knife Shoulder", "Knife in Back", "Knife Left Leg", "Knife Right Leg" }
    if impactZone == "head" or impactZone == "upper_torso" then
        preferred = { "Knife Shoulder", "Knife in Back", "Knife Stomach", "Knife Left Leg", "Knife Right Leg" }
    elseif impactZone == "lower_torso" then
        preferred = { "Knife Stomach", "Knife Shoulder", "Knife in Back", "Knife Left Leg", "Knife Right Leg" }
    elseif impactZone == "legs" then
        preferred = { "Knife Left Leg", "Knife Right Leg", "Knife Stomach", "Knife Shoulder", "Knife in Back" }
    else
        local part = zombie and zombie.getLastHitPart and zombie:getLastHitPart() or nil
        if part == "Torso_Upper" then
            preferred = { "Knife Shoulder", "Knife in Back", "Knife Stomach", "Knife Left Leg", "Knife Right Leg" }
        elseif part == "Torso_Lower" then
            preferred = { "Knife Stomach", "Knife Shoulder", "Knife in Back", "Knife Left Leg", "Knife Right Leg" }
        end
    end

    for i = 1, #preferred do
        local location = preferred[i]
        local occupied = false
        if zombie.getAttachedItem then
            local ok, attached = pcall(zombie.getAttachedItem, zombie, location)
            occupied = ok and attached ~= nil or (not ok)
        end
        if not occupied then
            return location
        end
    end

    return nil
end

local function getLoadedAmmoType(weapon, profile)
    if not weapon then
        return normalizeRecoverableArcheryAmmoType(profile and profile.defaultAmmoType)
    end
    if weapon.getCurrentAmmoCount and weapon:getCurrentAmmoCount() <= 0 then
        return nil
    end
    local md = weapon.getModData and weapon:getModData() or nil
    local loaded = md and md.ggsLoadedAmmoType or nil
    if loaded then
        return normalizeRecoverableArcheryAmmoType(loaded)
    end
    return normalizeRecoverableArcheryAmmoType(profile and profile.defaultAmmoType)
end

local function computeBowImpactDamage(weapon, profile, ammoProfile)
    local tensionPower = tonumber(profile and profile.tensionPower) or 5.0
    local mass = tonumber(ammoProfile and ammoProfile.mass) or 0.08
    local sharpness = tonumber(ammoProfile and ammoProfile.sharpness) or 0.8
    local scale = tonumber(profile and profile.damageScale) or 1.0
    local weaponClass = tostring(profile and profile.class or "bow")
    local mult = weaponClass == "crossbow" and ARCHERY_CROSSBOW_DAMAGE_MULT or ARCHERY_BOW_DAMAGE_MULT
    local minDamage = weaponClass == "crossbow" and ARCHERY_CROSSBOW_MIN_DAMAGE or ARCHERY_BOW_MIN_DAMAGE
    local damage = (tensionPower * 0.055) + (sharpness * 0.90) + (mass * 9.0)
    damage = damage * scale * mult
    local healthScale = weaponClass == "crossbow" and ARCHERY_CROSSBOW_HEALTH_SCALE or ARCHERY_BOW_HEALTH_SCALE
    local healthMin = weaponClass == "crossbow" and ARCHERY_CROSSBOW_HEALTH_MIN or ARCHERY_BOW_HEALTH_MIN
    return math.max(healthMin, math.max(minDamage, damage) * healthScale)
end

local function getAccumulatedArcheryDamage(zombie)
    if not (zombie and zombie.getModData) then
        return 0.0
    end
    local md = zombie:getModData()
    return math.max(0.0, tonumber(md and md[ARCHERY_DAMAGE_ACCUM_KEY]) or 0.0)
end

local function addAccumulatedArcheryDamage(zombie, damage)
    if not (zombie and zombie.getModData) then
        return math.max(0.0, tonumber(damage) or 0.0)
    end
    local md = zombie:getModData()
    local nextValue = math.max(0.0, (tonumber(md and md[ARCHERY_DAMAGE_ACCUM_KEY]) or 0.0) + (tonumber(damage) or 0.0))
    md[ARCHERY_DAMAGE_ACCUM_KEY] = nextValue
    return nextValue
end

local function clearAccumulatedArcheryDamage(zombie)
    if not (zombie and zombie.getModData) then
        return
    end
    local md = zombie:getModData()
    if md then
        md[ARCHERY_DAMAGE_ACCUM_KEY] = nil
    end
end

local function snapZombieToReportedPosition(zombie, x, y, z)
    if not zombie then
        return false
    end

    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if x == nil or y == nil then
        return false
    end

    local zx = zombie.getX and tonumber(zombie:getX()) or nil
    local zy = zombie.getY and tonumber(zombie:getY()) or nil
    if zx ~= nil and zy ~= nil then
        local dx = zx - x
        local dy = zy - y
        local dist = math.sqrt((dx * dx) + (dy * dy))
        if dist > 8.00 then
            return false
        end
    end

    local cell = getCell and getCell() or nil
    local targetSquare = nil
    if cell and cell.getGridSquare then
        targetSquare = cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
        if (not targetSquare) and z ~= nil then
            targetSquare = cell:getGridSquare(math.floor(x), math.floor(y), 0)
        end
    end
    local currentSquare = zombie.getCurrentSquare and zombie:getCurrentSquare() or nil
    if currentSquare and currentSquare ~= targetSquare and currentSquare.getMovingObjects then
        local okList, movingObjects = pcall(currentSquare.getMovingObjects, currentSquare)
        if okList and movingObjects and movingObjects.remove then
            pcall(movingObjects.remove, movingObjects, zombie)
        end
    end
    if targetSquare then
        if zombie.setCurrent then
            pcall(zombie.setCurrent, zombie, targetSquare)
        end
        if zombie.setCurrentSquare then
            pcall(zombie.setCurrentSquare, zombie, targetSquare)
        end
        if zombie.setSquare then
            pcall(zombie.setSquare, zombie, targetSquare)
        end
        if targetSquare.getMovingObjects then
            local okList, movingObjects = pcall(targetSquare.getMovingObjects, targetSquare)
            if okList and movingObjects and movingObjects.contains and movingObjects.add then
                local okContains, contains = pcall(movingObjects.contains, movingObjects, zombie)
                if (not okContains) or (not contains) then
                    pcall(movingObjects.add, movingObjects, zombie)
                end
            elseif okList and movingObjects and movingObjects.add then
                pcall(movingObjects.add, movingObjects, zombie)
            end
        end
    end

    if zombie.setX then
        pcall(zombie.setX, zombie, x)
    end
    if zombie.setY then
        pcall(zombie.setY, zombie, y)
    end
    if z ~= nil and zombie.setZ then
        pcall(zombie.setZ, zombie, z)
    end
    if zombie.setLx then
        pcall(zombie.setLx, zombie, x)
    end
    if zombie.setLy then
        pcall(zombie.setLy, zombie, y)
    end
    if z ~= nil and zombie.setLz then
        pcall(zombie.setLz, zombie, z)
    end
    if zombie.setNx then
        pcall(zombie.setNx, zombie, x)
    end
    if zombie.setNy then
        pcall(zombie.setNy, zombie, y)
    end
    if z ~= nil and zombie.setNz then
        pcall(zombie.setNz, zombie, z)
    end
    if zombie.ensureOnTile then
        pcall(zombie.ensureOnTile, zombie)
    end
    return true
end

local function attachArrowToZombie(zombie, arrowItemType, impactZone)
    if not (zombie and arrowItemType and zombie.setAttachedItem) then
        return false, "attach_prereq_missing"
    end

    local item = instanceItem and instanceItem(arrowItemType) or nil
    if not item then
        return false, "arrow_item_nil"
    end

    local location = chooseAttachLocation(zombie, impactZone)
    if not location then
        return false, "attach_slot_unavailable"
    end

    local okSet = pcall(zombie.setAttachedItem, zombie, location, item)
    if not okSet then
        return false, "setAttachedItem_failed"
    end

    if sendAttachedItem then
        pcall(sendAttachedItem, zombie, location, item)
    end
    if zombie.reportEvent then
        pcall(zombie.reportEvent, zombie, "EventAttachItem")
    end

    return true, location
end

local function isCharacterReallyDead(character)
    if not character then
        return false, "nil"
    end
    if character.isDead then
        local ok, dead = pcall(character.isDead, character)
        if ok and dead then
            return true, "isDead=true"
        end
    end
    if character.isOnDeathDone then
        local ok, done = pcall(character.isOnDeathDone, character)
        if ok and done then
            return true, "deathDone=true"
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

local function forceZombieDeath(zombie, killer, weapon)
    if not (zombie and instanceof and instanceof(zombie, "IsoZombie")) then
        return false, "not_zombie"
    end

    clearAccumulatedArcheryDamage(zombie)

    local attempts = {}
    local function tryMethod(label, fn, ...)
        local alreadyDead, alreadyReason = isCharacterReallyDead(zombie)
        if alreadyDead then
            return true, "already_dead -> " .. tostring(alreadyReason)
        end
        if not fn then
            return false
        end
        local ok = pcall(fn, zombie, ...)
        attempts[#attempts + 1] = label .. "=" .. tostring(ok)
        local nowDead, nowReason = isCharacterReallyDead(zombie)
        if nowDead then
            return true, label .. " -> " .. nowReason
        end
        return false
    end

    if zombie.setHealth then
        local ok = pcall(zombie.setHealth, zombie, 0.0)
        attempts[#attempts + 1] = "setHealth(0)=" .. tostring(ok)
    end
    if zombie.setReanimate then
        local ok = pcall(zombie.setReanimate, zombie, false)
        attempts[#attempts + 1] = "setReanimate(false)=" .. tostring(ok)
    end
    if zombie.setFakeDead then
        local ok = pcall(zombie.setFakeDead, zombie, false)
        attempts[#attempts + 1] = "setFakeDead(false)=" .. tostring(ok)
    end
    if zombie.setForceFakeDead then
        local ok = pcall(zombie.setForceFakeDead, zombie, false)
        attempts[#attempts + 1] = "setForceFakeDead(false)=" .. tostring(ok)
    end
    if tryMethod("Kill(killer,true)", zombie.Kill, killer, true) then
        -- verified in helper
    end
    if tryMethod("Kill(killer)", zombie.Kill, killer) then
        -- verified in helper
    end
    if tryMethod("Kill(nil,true)", zombie.Kill, nil, true) then
        -- verified in helper
    end
    if tryMethod("Kill(nil)", zombie.Kill, nil) then
        -- verified in helper
    end
    if tryMethod("die()", zombie.die) then
        -- verified in helper
    end
    if tryMethod("DoDeath(killer,weapon,false)", zombie.DoDeath, killer, weapon, false) then
        -- verified in helper
    end
    if tryMethod("DoDeath(killer,weapon,true)", zombie.DoDeath, killer, weapon, true) then
        -- verified in helper
    end
    if tryMethod("DoDeath(nil,nil,false)", zombie.DoDeath, nil, nil, false) then
        -- verified in helper
    end
    if tryMethod("DoDeath(nil,nil,true)", zombie.DoDeath, nil, nil, true) then
        -- verified in helper
    end

    local dead, reason = isCharacterReallyDead(zombie)
    if dead then
        return true, reason .. " attempts=" .. table.concat(attempts, ",")
    end
    return false, "no_kill_method attempts=" .. table.concat(attempts, ",")
end

local function applyArcheryImpactToZombie(playerObj, weapon, weaponType, profile, ammoType, zombie, damageOverride, sourceLabel, impactX, impactY, impactZ, targetX, targetY, targetZ)
    if not (playerObj and weapon and profile and isZombieUsable(zombie)) then
        logArchery(
            "impact rejected src=%s reason=prereq_missing onlineId=%s weapon=%s zombie=%s",
            tostring(sourceLabel),
            tostring(playerObj and playerObj.getOnlineID and playerObj:getOnlineID() or "nil"),
            tostring(weaponType),
            tostring(zombie)
        )
        return false, "prereq_missing"
    end
    ammoType = normalizeFullType(ammoType) or getLoadedAmmoType(weapon, profile) or normalizeFullType(profile.defaultAmmoType)
    local ammoProfile = getAmmoProfile(ammoType)
    local damage = tonumber(damageOverride)
    local computedDamage = computeBowImpactDamage(weapon, profile, ammoProfile)
    logArchery(
        "impact formula src=%s onlineId=%s weapon=%s ammo=%s class=%s tension=%.2f scale=%.2f sharp=%.2f mass=%.2f override=%s computed=%.2f",
        tostring(sourceLabel),
        tostring(playerObj:getOnlineID()),
        tostring(weaponType),
        tostring(ammoType),
        tostring(profile and profile.class or "nil"),
        tonumber(profile and profile.tensionPower) or 5.0,
        tonumber(profile and profile.damageScale) or 1.0,
        tonumber(ammoProfile and ammoProfile.sharpness) or 0.8,
        tonumber(ammoProfile and ammoProfile.mass) or 0.08,
        tostring(damageOverride),
        tonumber(computedDamage) or 0
    )
    if damage == nil then
        damage = computedDamage
    else
        damage = math.max(damage, computedDamage)
    end
    damage = math.max(0.10, math.min(12.0, damage))

    local oldHealth = zombie.getHealth and tonumber(zombie:getHealth()) or 1.0
    local newHealth = math.max(0.0, oldHealth - damage)
    local oldAccum = getAccumulatedArcheryDamage(zombie)
    local damaged = false
    local setHealthOk = false
    if zombie.setHealth then
        local ok = pcall(zombie.setHealth, zombie, newHealth)
        setHealthOk = ok and true or false
        damaged = setHealthOk
    end
    local postHealth = zombie.getHealth and tonumber(zombie:getHealth()) or nil
    local newAccum = addAccumulatedArcheryDamage(zombie, damage)
    logArchery(
        "impact health-check src=%s onlineId=%s weapon=%s ammo=%s old=%.2f target=%.2f post=%s setHealthOk=%s accum=%.2f->%.2f killThreshold=%.2f zombie=%s",
        tostring(sourceLabel),
        tostring(playerObj:getOnlineID()),
        tostring(weaponType),
        tostring(ammoType),
        tonumber(oldHealth) or 0,
        tonumber(newHealth) or 0,
        tostring(postHealth),
        tostring(setHealthOk),
        tonumber(oldAccum) or 0,
        tonumber(newAccum) or 0,
        0,
        describeZombieDebug(zombie)
    )
    if not damaged then
        logArchery(
            "impact rejected src=%s reason=setHealth_failed onlineId=%s weapon=%s ammo=%s oldHealth=%s newHealth=%s zombie=%s",
            tostring(sourceLabel),
            tostring(playerObj:getOnlineID()),
            tostring(weaponType),
            tostring(ammoType),
            tostring(oldHealth),
            tostring(newHealth),
            tostring(zombie)
        )
        return false, "setHealth_failed"
    end

    local arrowItemType = normalizeRecoverableArcheryAmmoType(ammoProfile and ammoProfile.floorItemType)
        or normalizeRecoverableArcheryAmmoType(ammoType)
        or "Base.WoodShaft_Arrow"
    local impactZone, hitZoneRelZ, hitZoneLateral = estimateArcheryImpactZone(zombie, impactX, impactY, impactZ)
    local attached, attachData = false, "attach_skipped_recent"
    if not consumeRecentAttachment(zombie, playerObj, weaponType) then
        attached, attachData = attachArrowToZombie(zombie, arrowItemType, impactZone)
    end

    local lethalImpact = newHealth <= 0.0
    local impactFxSent = false
    local killed, killMethod = false, nil
    local impactFxArgs = buildArrowImpactFxArgs(
        playerObj,
        weaponType,
        ammoType,
        zombie,
        sourceLabel,
        impactX,
        impactY,
        impactZ,
        damage,
        oldHealth,
        newHealth,
        ammoProfile and ammoProfile.hitReaction,
        impactZone,
        hitZoneRelZ,
        hitZoneLateral,
        attachData
    )
    if lethalImpact then
        snapZombieToReportedPosition(zombie, targetX or impactX, targetY or impactY, targetZ or impactZ)
        killed, killMethod = forceZombieDeath(zombie, playerObj, weapon)
    else
        if zombie.setStaggerBack then
            pcall(zombie.setStaggerBack, zombie, true)
        elseif zombie.staggerBack then
            pcall(zombie.staggerBack, zombie)
        end
    end
    if impactFxArgs then
        impactFxArgs.killed = (killed or lethalImpact) and true or false
        impactFxArgs.kill = tostring(killMethod)
        impactFxSent = sendArrowImpactFx(impactFxArgs)
    end

    logArchery(
        "impact applied src=%s onlineId=%s weapon=%s ammo=%s dmg=%.2f computed=%.2f health=%.2f->%.2f zone=%s relZ=%s lateral=%s attached=%s attach=%s killed=%s kill=%s impactFx=%s",
        tostring(sourceLabel), tostring(playerObj:getOnlineID()), tostring(weaponType), tostring(ammoType), damage, computedDamage,
        oldHealth, newHealth, tostring(impactZone), tostring(hitZoneRelZ), tostring(hitZoneLateral), tostring(attached), tostring(attachData), tostring(killed), tostring(killMethod), tostring(impactFxSent)
    )
    return true, tostring(attached and attachData or killMethod or "ok")
end

local function handleArrowImpact(playerObj, args)
    if not playerObj or not args then
        return
    end

    local weapon, weaponType, profile = resolveEquippedBow(playerObj, args.weaponType)
    if not (weapon and profile) then
        logArchery("impact rejected: no supported bow onlineId=%s wanted=%s", tostring(playerObj:getOnlineID()), tostring(args.weaponType))
        return
    end

    local impactX = tonumber(args.impactX)
    local impactY = tonumber(args.impactY)
    local impactZ = tonumber(args.impactZ) or playerObj:getZ()
    if impactX == nil or impactY == nil then
        logArchery("impact rejected: bad coords onlineId=%s", tostring(playerObj:getOnlineID()))
        return
    end

    local maxDist = math.max(8.0, tonumber(profile.maxTargetDistance) or 55.0)
    local dist = distance2D(playerObj:getX(), playerObj:getY(), impactX, impactY)
    if dist > (maxDist * 1.6) then
        logArchery("impact rejected: out of range onlineId=%s weapon=%s dist=%.2f", tostring(playerObj:getOnlineID()), tostring(weaponType), dist)
        return
    end

    local impactRadius = tonumber(args.impactRadius) or tonumber(profile.impactDamageRadius) or 0.90
    impactRadius = math.max(0.10, math.min(2.25, impactRadius))
    local targetZombie, resolutionMode, microRadius, resolutionScore, resolvedImpactX, resolvedImpactY, resolvedImpactZ =
        resolveArcheryImpactZombie(impactX, impactY, impactZ, impactRadius, args)
    if not targetZombie then
        logArchery(
            "impact missed on server onlineId=%s weapon=%s impact=%.2f,%.2f,%.2f microR=%.2f %s",
            tostring(playerObj:getOnlineID()),
            tostring(weaponType),
            impactX,
            impactY,
            impactZ,
            tonumber(microRadius) or 0,
            buildNearbyZombieDebug(tonumber(args.targetX) or impactX, tonumber(args.targetY) or impactY, tonumber(args.targetZ) or impactZ, math.max(ARCHERY_MICRO_IMPACT_ASSIST_RADIUS, impactRadius), args)
        )
        return
    end
    local applyImpactX = tonumber(resolvedImpactX) or impactX
    local applyImpactY = tonumber(resolvedImpactY) or impactY
    local applyImpactZ = tonumber(resolvedImpactZ) or impactZ
    logArchery(
        "impact resolved src=client_impact mode=%s microR=%.2f score=%s onlineId=%s weapon=%s impact=%.2f,%.2f,%.2f target=%s from %s",
        tostring(resolutionMode),
        tonumber(microRadius) or 0,
        tostring(resolutionScore),
        tostring(playerObj:getOnlineID()),
        tostring(weaponType),
        applyImpactX,
        applyImpactY,
        applyImpactZ,
        describeZombieDebug(targetZombie),
        describeArgsTargetDebug(args)
    )

    if zombieMatchesTargetArgs(targetZombie, args) then
        snapZombieToReportedPosition(targetZombie, tonumber(args.targetX) or impactX, tonumber(args.targetY) or impactY, tonumber(args.targetZ) or impactZ)
    end

    applyArcheryImpactToZombie(
        playerObj,
        weapon,
        weaponType,
        profile,
        args.ammoType,
        targetZombie,
        tonumber(args.impactDamage),
        "client_impact",
        applyImpactX,
        applyImpactY,
        applyImpactZ,
        tonumber(args.targetX) or impactX,
        tonumber(args.targetY) or impactY,
        tonumber(args.targetZ) or impactZ
    )
end

local function handleArrowZombieHit(playerObj, args)
    if not playerObj or not args then
        return
    end

    local weapon, weaponType, profile = resolveEquippedBow(playerObj, args.weaponType)
    if not (weapon and profile) then
        logArchery("zombie-hit rejected: no supported bow onlineId=%s wanted=%s", tostring(playerObj:getOnlineID()), tostring(args.weaponType))
        return
    end

    local targetX = tonumber(args.targetX) or tonumber(args.impactX)
    local targetY = tonumber(args.targetY) or tonumber(args.impactY)
    local targetZ = tonumber(args.targetZ) or tonumber(args.impactZ) or playerObj:getZ()
    if targetX == nil or targetY == nil then
        logArchery("zombie-hit rejected: bad coords onlineId=%s", tostring(playerObj:getOnlineID()))
        return
    end

    local maxDist = math.max(8.0, tonumber(profile.maxTargetDistance) or 55.0)
    local dist = distance2D(playerObj:getX(), playerObj:getY(), targetX, targetY)
    if dist > (maxDist * 1.6) then
        logArchery("zombie-hit rejected: out of range onlineId=%s weapon=%s dist=%.2f", tostring(playerObj:getOnlineID()), tostring(weaponType), dist)
        return
    end

    local impactRadius = tonumber(args.impactRadius) or tonumber(profile.impactDamageRadius) or 0.90
    impactRadius = math.max(0.10, math.min(2.25, impactRadius))

    local targetZombie, resolutionMode, microRadius, resolutionScore, resolvedImpactX, resolvedImpactY, resolvedImpactZ =
        resolveArcheryImpactZombie(
            tonumber(args.impactX) or targetX,
            tonumber(args.impactY) or targetY,
            tonumber(args.impactZ) or targetZ,
            impactRadius,
            args
        )
    if not targetZombie then
        logArchery(
            "zombie-hit missed on server onlineId=%s weapon=%s target=%.2f,%.2f,%.2f microR=%.2f %s",
            tostring(playerObj:getOnlineID()),
            tostring(weaponType),
            targetX,
            targetY,
            targetZ,
            tonumber(microRadius) or 0,
            buildNearbyZombieDebug(targetX, targetY, targetZ, math.max(ARCHERY_MICRO_IMPACT_ASSIST_RADIUS, impactRadius), args)
        )
        return
    end
    local applyImpactX = tonumber(resolvedImpactX) or tonumber(args.impactX) or targetX
    local applyImpactY = tonumber(resolvedImpactY) or tonumber(args.impactY) or targetY
    local applyImpactZ = tonumber(resolvedImpactZ) or tonumber(args.impactZ) or targetZ
    logArchery(
        "impact resolved src=client_zombie_hit mode=%s microR=%.2f score=%s onlineId=%s weapon=%s impact=%.2f,%.2f,%.2f target=%s from %s",
        tostring(resolutionMode),
        tonumber(microRadius) or 0,
        tostring(resolutionScore),
        tostring(playerObj:getOnlineID()),
        tostring(weaponType),
        applyImpactX,
        applyImpactY,
        applyImpactZ,
        describeZombieDebug(targetZombie),
        describeArgsTargetDebug(args)
    )

    if zombieMatchesTargetArgs(targetZombie, args) then
        snapZombieToReportedPosition(targetZombie, targetX, targetY, targetZ)
    end

    applyArcheryImpactToZombie(
        playerObj,
        weapon,
        weaponType,
        profile,
        args.ammoType,
        targetZombie,
        tonumber(args.impactDamage),
        "client_zombie_hit",
        applyImpactX,
        applyImpactY,
        applyImpactZ,
        targetX,
        targetY,
        targetZ
    )
end

function GGS_ArcheryServer.onHitZombie(zombie, attacker, bodyPart, weapon)
    if not (attacker and weapon and zombie and instanceof and instanceof(zombie, "IsoZombie")) then
        return false
    end

    local weaponType = getWeaponFullType(weapon)
    local profile = getBowProfile(weaponType)
    if not profile then
        return false
    end

    local ammoType = getLoadedAmmoType(weapon, profile)
    logArchery(
        "on-hit zombie attach-only onlineId=%s weapon=%s ammo=%s zombie=%s",
        tostring(attacker.getOnlineID and attacker:getOnlineID() or "sp"),
        tostring(weaponType),
        tostring(ammoType),
        tostring(zombie)
    )
    local ammoProfile = getAmmoProfile(ammoType)
    local arrowItemType = normalizeRecoverableArcheryAmmoType(ammoProfile and ammoProfile.floorItemType)
        or normalizeRecoverableArcheryAmmoType(ammoType)
        or "Base.WoodShaft_Arrow"
    if not consumeRecentAttachment(zombie, attacker, weaponType) then
        attachArrowToZombie(zombie, arrowItemType)
    end
    return true
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE_NAME then
        return
    end
    logArchery(
        "command recv=%s onlineId=%s weapon=%s ammo=%s %s",
        tostring(command),
        tostring(playerObj and playerObj.getOnlineID and playerObj:getOnlineID() or "nil"),
        tostring(args and args.weaponType),
        tostring(args and args.ammoType),
        describeArgsTargetDebug(args)
    )
    if command == COMMAND_ARROW_IMPACT then
        handleArrowImpact(playerObj, args)
    elseif command == COMMAND_ARROW_ZOMBIE_HIT then
        handleArrowZombieHit(playerObj, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnHitZombie.Add(GGS_ArcheryServer.onHitZombie)
