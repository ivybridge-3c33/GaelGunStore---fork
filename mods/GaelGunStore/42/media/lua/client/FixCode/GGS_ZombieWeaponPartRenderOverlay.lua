-- Render GGS/AWCWF weapon parts on zombie attached weapons.
--
-- Vanilla attached weapons render only the base item. The old AWCWF path renders
-- parts by attaching invisible TempNilItem placeholders to body bones using the
-- part model as WeaponSprite. This is the same idea, scoped to nearby zombies and
-- only updated when the attached weapon/part signature changes.

local cos = math.cos
local sin = math.sin

local SCAN_RADIUS = 24
local TICKS_BETWEEN_SCANS = 120
local MAX_ZOMBIES_PER_SCAN = 24
local TEMP_ITEM_TYPE = "Base.TempNilItem"

local partlist = (AWCWF_AdditionalParts and AWCWF_AdditionalParts.partlist) or {
    "Scope",
    "Mount",
    "Canon",
    "Stock",
    "Handguard",
    "Hanguard",
    "Grip",
    "Laser",
    "Light",
    "Stool",
    "R_Scope",
    "L_Scope",
    "Skin",
    "Sling",
    "RecoilPad",
    "Misc",
    "Clip",
    "ClipUI",
    "Hide_Beam",
    "Barrel",
    "Barrel_Shroud",
    "AMMO",
}

local stateByZombie = setmetatable({}, { __mode = "k" })
local tickCounter = 0
local registered = false

local function rotatePoint(a, b, c, alpha, beta, gamma)
    local radAlpha = math.rad(alpha)
    local radBeta = math.rad(beta)
    local radGamma = math.rad(gamma)

    local y1 = b * cos(radAlpha) - c * sin(radAlpha)
    local z1 = b * sin(radAlpha) + c * cos(radAlpha)
    local x1 = a

    local x2 = x1 * cos(radBeta) + z1 * sin(radBeta)
    local y2 = y1
    local z2 = -x1 * sin(radBeta) + z1 * cos(radBeta)

    local x3 = x2 * cos(radGamma) - y2 * sin(radGamma)
    local y3 = x2 * sin(radGamma) + y2 * cos(radGamma)
    local z3 = z2

    return x3, y3, z3
end

local function safeInstanceOf(object, className)
    if not object or not className or not instanceof then
        return false
    end

    local ok, result = pcall(instanceof, object, className)
    return ok and result == true
end

local function normalizeFullType(fullType)
    if not fullType or fullType == "" then
        return nil
    end
    fullType = tostring(fullType)
    if not fullType:find("%.", 1) then
        return "Base." .. fullType
    end
    return fullType
end

local function normalizeClipFullType(fullType)
    fullType = normalizeFullType(fullType)
    if not fullType then
        return nil
    end
    if fullType:find("Clip_", 1, true) then
        return fullType
    end
    local moduleName, itemName = fullType:match("([^%.]+)%.(.+)")
    if moduleName and itemName then
        return moduleName .. ".Clip_" .. itemName
    end
    return fullType
end

local function normalizePartFullType(partType, fullType)
    if partType == "Clip" or partType == "ClipUI" then
        return normalizeClipFullType(fullType)
    end
    return normalizeFullType(fullType)
end

local function getWeaponPartMap(weapon)
    local modData = weapon and weapon.getModData and weapon:getModData() or nil
    local weaponpart = modData and modData.weaponpart or nil
    if not weaponpart then
        return nil
    end

    for _, fullType in pairs(weaponpart) do
        if fullType and fullType ~= "" then
            return weaponpart
        end
    end

    return nil
end

local function isRenderableWeapon(weapon)
    if not safeInstanceOf(weapon, "HandWeapon") then
        return false
    end
    if weapon.getFullType and weapon:getFullType() == TEMP_ITEM_TYPE then
        return false
    end
    return getWeaponPartMap(weapon) ~= nil
end

local function isTempOverlayItem(item)
    if not (item and item.getFullType) then
        return false
    end
    if item:getFullType() ~= TEMP_ITEM_TYPE then
        return false
    end
    local modData = item.getModData and item:getModData() or nil
    return modData and modData.GGS_ZombiePartOverlay == true
end

local function getCharacterBodyModel(character)
    if character and character.isFemale and character:isFemale() then
        return "FemaleBody"
    end
    return "MaleBody"
end

local function getPartModelScript(fullType)
    fullType = normalizeFullType(fullType)
    if not fullType or not ScriptManager or not ScriptManager.instance then
        return nil, nil
    end

    local model = ScriptManager.instance:getModelScript(fullType)
    if model then
        return model, fullType
    end

    local scriptItem = ScriptManager.instance:getItem(fullType)
    local modelName = nil
    if scriptItem then
        modelName = (scriptItem.getWorldStaticModel and scriptItem:getWorldStaticModel()) or
            (scriptItem.getStaticModel and scriptItem:getStaticModel()) or nil
        if modelName and modelName ~= "" and tostring(modelName) ~= "null" then
            modelName = tostring(modelName)
            if not modelName:find("%.") then
                local moduleName = scriptItem.getModuleName and scriptItem:getModuleName() or "Base"
                modelName = moduleName .. "." .. modelName
            end
            model = ScriptManager.instance:getModelScript(modelName)
            if model then
                return model, modelName
            end
        end
    end

    return nil, fullType
end

local function getWeaponModelScript(weapon)
    if not (weapon and weapon.getModule and weapon.getWeaponSprite and ScriptManager and ScriptManager.instance) then
        return nil
    end

    local sprite = weapon:getWeaponSprite()
    if not sprite or sprite == "" or tostring(sprite) == "nil" then
        return nil
    end

    return ScriptManager.instance:getModelScript(weapon:getModule() .. "." .. sprite)
end

local function sanitizeLocationToken(value)
    value = tostring(value or "")
    value = value:gsub("[^%w_]", "_")
    if value == "" then
        return "unknown"
    end
    return value
end

local function getAttachedLocationName(attachedItem)
    if not attachedItem or not attachedItem.getLocation then
        return nil
    end

    local ok, location = pcall(attachedItem.getLocation, attachedItem)
    if ok and location and location ~= "" then
        return tostring(location)
    end

    return nil
end

local function getAttachedItemInventoryItem(attachedItem)
    if attachedItem and attachedItem.getItem then
        local ok, item = pcall(attachedItem.getItem, attachedItem)
        if ok then
            return item
        end
    end
    return nil
end

local function addOverlayLocation(locationList, character, attachedItem, weapon, partType, partFullType)
    local weaponModel = getWeaponModelScript(weapon)
    local partModel, partModelName = getPartModelScript(partFullType)
    if not (weaponModel and partModel and partModelName) then
        return
    end

    local locationName = getAttachedLocationName(attachedItem)
    if not locationName then
        return
    end

    local group = AttachedLocations and AttachedLocations.getGroup and AttachedLocations.getGroup("Human")
    if not group then
        return
    end

    local attachLocation = group:getOrCreateLocation(locationName)
    local bodyAttachmentId = attachLocation and attachLocation:getAttachmentName() or nil
    if not bodyAttachmentId then
        return
    end

    local bodyModel = ScriptManager.instance:getModelScript(getCharacterBodyModel(character))
    local bodyAttachment = bodyModel and bodyModel:getAttachmentById(bodyAttachmentId) or nil
    if not bodyAttachment then
        return
    end

    local weaponAttachment = weaponModel:getAttachmentById(partType)
    if not weaponAttachment then
        weaponAttachment = ModelAttachment.new(partType)
    end

    local partOffset = weaponAttachment:getOffset()
    local partRotate = weaponAttachment:getRotate()
    local partScale = weaponAttachment:getScale()
    local bodyOffset = bodyAttachment:getOffset()
    local bodyRotate = bodyAttachment:getRotate()
    local bone = bodyAttachment:getBone()
    if not bone then
        return
    end

    local x, y, z = rotatePoint(partOffset:x(), partOffset:y(), partOffset:z(), 0, 0, bodyRotate:z())
    x, y, z = rotatePoint(x, y, z, 0, bodyRotate:y(), 0)
    x, y, z = rotatePoint(x, y, z, bodyRotate:x(), 0, 0)

    local dynamicLocation = table.concat({
        bone,
        tostring(partType),
        sanitizeLocationToken(locationName),
        sanitizeLocationToken(weapon:getWeaponSprite()),
    }, "[]")
    locationList[dynamicLocation] = {
        part = partModelName,
        x = bodyOffset:x() + x,
        y = bodyOffset:y() + y,
        z = bodyOffset:z() + z,
        rx = partRotate:x() + bodyRotate:x(),
        ry = partRotate:y() + bodyRotate:y(),
        rz = partRotate:z() + bodyRotate:z(),
        scale = partScale,
    }
end

local function buildLocationList(character)
    local locationList = {}
    if not (character and character.getAttachedItems) then
        return locationList
    end

    local attachedItems = character:getAttachedItems()
    if not (attachedItems and attachedItems.size and attachedItems.get) then
        return locationList
    end

    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        local weapon = getAttachedItemInventoryItem(attachedItem)
        if isRenderableWeapon(weapon) then
            local weaponParts = getWeaponPartMap(weapon)
            for _, partType in ipairs(partlist) do
                local partFullType = normalizePartFullType(partType, weaponParts[partType])
                if partFullType and partFullType ~= "" then
                    addOverlayLocation(locationList, character, attachedItem, weapon, partType, partFullType)
                end
            end
        end
    end

    return locationList
end

local function buildSignature(locationList)
    local keys = {}
    for location in pairs(locationList) do
        keys[#keys + 1] = location
    end
    table.sort(keys)

    local parts = {}
    for i = 1, #keys do
        local location = keys[i]
        local data = locationList[location]
        parts[#parts + 1] = table.concat({
            location,
            data.part or "",
            tostring(data.x or 0),
            tostring(data.y or 0),
            tostring(data.z or 0),
            tostring(data.rx or 0),
            tostring(data.ry or 0),
            tostring(data.rz or 0),
        }, "|")
    end

    return table.concat(parts, "||")
end

local function collectExistingOverlayItems(character)
    local overlays = {}
    if not (character and character.getAttachedItems) then
        return overlays
    end

    local attachedItems = character:getAttachedItems()
    if not (attachedItems and attachedItems.size and attachedItems.get) then
        return overlays
    end

    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        local item = getAttachedItemInventoryItem(attachedItem)
        if isTempOverlayItem(item) then
            local location = getAttachedLocationName(attachedItem)
            if location then
                overlays[location] = item
            end
        end
    end

    return overlays
end

local function removeOverlayItem(character, item)
    if character and item and character.removeAttachedItem then
        pcall(character.removeAttachedItem, character, item)
    end
end

local function applyOverlayLocations(character, locationList)
    local group = AttachedLocations and AttachedLocations.getGroup and AttachedLocations.getGroup("Human")
    local bodyModel = ScriptManager and ScriptManager.instance and
        ScriptManager.instance:getModelScript(getCharacterBodyModel(character)) or nil
    if not (group and bodyModel and character and character.setAttachedItem) then
        return
    end

    local existing = collectExistingOverlayItems(character)
    for location, item in pairs(existing) do
        if not locationList[location] then
            removeOverlayItem(character, item)
        end
    end

    for location, data in pairs(locationList) do
        local modelAttachment = bodyModel:getAttachmentById(location)
        if not modelAttachment then
            modelAttachment = ModelAttachment.new(location)
        end

        local bone = location:match("^(.-)%[%]")
        if not bone then
            bone = "Bip01_BackPack"
        end

        local offset = modelAttachment:getOffset()
        local rotate = modelAttachment:getRotate()
        offset:set(data.x or 0, data.y or 0, data.z or 0)
        rotate:set(data.rx or 0, data.ry or 0, data.rz or 0)
        modelAttachment:setScale(data.scale or 1)
        bodyModel:addAttachment(modelAttachment):setBone(bone)

        local loc = group:getOrCreateLocation(location)
        loc:setAttachmentName(location)

        local item = existing[location] or (instanceItem and instanceItem(TEMP_ITEM_TYPE) or nil)
        if item then
            local modData = item:getModData()
            modData.GGS_ZombiePartOverlay = true
            item:setWeaponSprite(data.part)
            pcall(character.setAttachedItem, character, location, item)
        end
    end
end

local function clearCharacterOverlays(character)
    local existing = collectExistingOverlayItems(character)
    for _, item in pairs(existing) do
        removeOverlayItem(character, item)
    end
    stateByZombie[character] = nil
end

local function updateCharacterOverlay(character)
    local locationList = buildLocationList(character)
    local signature = buildSignature(locationList)
    local state = stateByZombie[character]

    if state and state.signature == signature then
        return
    end

    applyOverlayLocations(character, locationList)
    stateByZombie[character] = {
        signature = signature,
    }
end

local function isNearAnyPlayer(zombie)
    if not (zombie and zombie.getX and zombie.getY) then
        return true
    end

    local zx = zombie:getX()
    local zy = zombie:getY()
    local maxDistSq = SCAN_RADIUS * SCAN_RADIUS
    local sawPlayer = false

    if getSpecificPlayer then
        for playerIndex = 0, 3 do
            local ok, playerObj = pcall(getSpecificPlayer, playerIndex)
            if ok and playerObj and playerObj.getX and playerObj.getY then
                sawPlayer = true
                local dx = zx - playerObj:getX()
                local dy = zy - playerObj:getY()
                if (dx * dx + dy * dy) <= maxDistSq then
                    return true
                end
            end
        end
    end

    if not sawPlayer and getPlayer then
        local ok, playerObj = pcall(getPlayer)
        if ok and playerObj and playerObj.getX and playerObj.getY then
            local dx = zx - playerObj:getX()
            local dy = zy - playerObj:getY()
            return (dx * dx + dy * dy) <= maxDistSq
        end
    end

    return false
end

local function updateNearbyZombieOverlays()
    if not getCell then
        return
    end

    local cell = getCell()
    local zombies = cell and cell.getZombieList and cell:getZombieList() or nil
    if not (zombies and zombies.size and zombies.get) then
        return
    end

    local checked = 0
    for i = 0, zombies:size() - 1 do
        if checked >= MAX_ZOMBIES_PER_SCAN then
            return
        end

        local zombie = zombies:get(i)
        if zombie and isNearAnyPlayer(zombie) then
            checked = checked + 1
            updateCharacterOverlay(zombie)
        end
    end
end

local function onTickZombieWeaponPartOverlay()
    tickCounter = tickCounter + 1
    if tickCounter < TICKS_BETWEEN_SCANS then
        return
    end
    tickCounter = 0
    updateNearbyZombieOverlays()
end

local function registerZombieWeaponPartOverlay()
    if registered then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(onTickZombieWeaponPartOverlay)
        registered = true
    end
end

if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(registerZombieWeaponPartOverlay)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(registerZombieWeaponPartOverlay)
end
if Events and Events.OnZombieDead and Events.OnZombieDead.Add then
    Events.OnZombieDead.Add(clearCharacterOverlays)
end
registerZombieWeaponPartOverlay()
