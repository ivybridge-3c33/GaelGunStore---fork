-- Minimal, safe sync to eject the installed magazine type (MP/SP) without touching models.

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

local function magTypeToClipPart(magType)
    if _G.GGS_MagMapping then
        return _G.GGS_MagMapping.magTypeToClipPart(magType)
    end
    return nil
end

local function toMagFullType(magType)
    if not magType then
        return nil
    end
    if _G.GGS_MagMapping and _G.GGS_MagMapping.toFullType then
        return _G.GGS_MagMapping.toFullType(magType)
    end
    if tostring(magType):find("%.") then
        return tostring(magType)
    end
    return "Base." .. tostring(magType)
end

local function magTxLog(message)
    if _G.GGS_MAG_DEBUG == true then
        print("[GGS MagTx] " .. tostring(message))
    end
end

local function getMagazineInventory(action)
    local character = action and action.character
    if character and character.getInventory then
        return character:getInventory()
    end
    return nil
end

local function getWeaponMagazine(weapon)
    if not weapon then
        return nil
    end
    if weapon.getMagazine then
        local okMag, mag = pcall(weapon.getMagazine, weapon)
        if okMag and mag then
            return mag
        end
    end
    if weapon.getClip then
        local okClip, clip = pcall(weapon.getClip, weapon)
        if okClip and clip then
            return clip
        end
    end
    if weapon.getCurrentMagazine then
        local okCurrent, current = pcall(weapon.getCurrentMagazine, weapon)
        if okCurrent and current then
            return current
        end
    end
    return nil
end

local function collectTrackedMagazineTypes(expectedMag)
    local seen = {}
    local list = {}
    local function addType(typeName)
        local full = toMagFullType(typeName)
        if full and not seen[full] then
            seen[full] = true
            list[#list + 1] = full
        end
    end

    addType(expectedMag)
    local map = _G.AWCWF_MagazineTypeToPart
    if map then
        for magType, _ in pairs(map) do
            addType(magType)
        end
    end
    return list
end

local function snapshotMagazineCounts(inventory, trackedTypes)
    local snapshot = {}
    for i = 1, #trackedTypes do
        local fullType = trackedTypes[i]
        snapshot[fullType] = 0
    end
    local total = 0
    if not inventory then
        return snapshot, 0
    end
    local trackedSet = {}
    for i = 1, #trackedTypes do
        trackedSet[trackedTypes[i]] = true
    end
    local function collectFromContainer(container)
        if not container then
            return
        end
        local items = container:getItems()
        if not items then
            return
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item and item.getFullType and item:getFullType() or nil
            if fullType and trackedSet[fullType] then
                snapshot[fullType] = (snapshot[fullType] or 0) + 1
                total = total + 1
            end
            if item and instanceof(item, "InventoryContainer") then
                collectFromContainer(item:getInventory())
            end
        end
    end
    collectFromContainer(inventory)
    return snapshot, total
end

local function snapshotDiff(beforeSnapshot, afterSnapshot)
    local parts = {}
    for fullType, beforeCount in pairs(beforeSnapshot) do
        local afterCount = afterSnapshot[fullType] or 0
        local delta = afterCount - beforeCount
        if delta ~= 0 then
            parts[#parts + 1] = string.format("%s:%+d", tostring(fullType), delta)
        end
    end
    table.sort(parts)
    if #parts == 0 then
        return "none"
    end
    return table.concat(parts, ", ")
end

local function safeBool(value)
    if value then
        return "true"
    end
    return "false"
end

local function safeValue(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function safeGunName(gun)
    if not gun then
        return "nil"
    end
    local gunType = gun.getType and gun:getType() or nil
    if gunType and gunType ~= "" then
        return tostring(gunType)
    end
    local display = gun.getDisplayName and gun:getDisplayName() or nil
    if display and display ~= "" then
        return tostring(display)
    end
    return "unknown"
end

local function buildTxId()
    local randomPart = (ZombRand and ZombRand(1000000)) or math.random(0, 999999)
    return string.format("%s-%d", tostring(getTimestampMs and getTimestampMs() or 0), randomPart)
end

local function createCompensationMagazine(inventory, magFullType, ammoCount)
    if not inventory or not magFullType then
        return false
    end
    local created = inventory:AddItem(magFullType)
    if not created then
        return false
    end
    if created.setCurrentAmmoCount then
        pcall(created.setCurrentAmmoCount, created, math.max(0, tonumber(ammoCount) or 0))
    end
    return true
end

local function safeGetMagazineAmmoItemKey(magazine)
    if not magazine or not magazine.getAmmoType then
        return nil
    end
    local okAmmo, ammoType = pcall(magazine.getAmmoType, magazine)
    if not okAmmo or not ammoType then
        return nil
    end
    if not ammoType.getItemKey then
        return nil
    end
    local okKey, itemKey = pcall(ammoType.getItemKey, ammoType)
    if not okKey or not itemKey or itemKey == "" then
        return nil
    end
    return itemKey
end

local function getMagazineMaxFromType(magTypeFull, gun)
    local maxAmmo = nil
    if magTypeFull and instanceItem then
        local okMag, magItem = pcall(instanceItem, magTypeFull)
        if okMag and magItem and magItem.getMaxAmmo then
            local okMax, m = pcall(magItem.getMaxAmmo, magItem)
            if okMax then
                maxAmmo = tonumber(m)
            end
        end
    end
    if (not maxAmmo or maxAmmo <= 0) and gun and gun.getMaxAmmo then
        local okGun, gunMax = pcall(gun.getMaxAmmo, gun)
        if okGun then
            maxAmmo = tonumber(gunMax)
        end
    end
    if not maxAmmo then
        return nil
    end
    return math.floor(maxAmmo)
end

local function isMagazineFullForReload(gun)
    if not gun or not gun.getMagazineType or not gun.getCurrentAmmoCount then
        return false, nil, nil, nil
    end
    local magTypeFull = toMagFullType(gun:getMagazineType())
    if not magTypeFull then
        return false, nil, nil, nil
    end
    local current = tonumber(gun:getCurrentAmmoCount()) or 0
    local maxAmmo = getMagazineMaxFromType(magTypeFull, gun)
    if not maxAmmo or maxAmmo <= 0 then
        return false, current, maxAmmo, magTypeFull
    end
    return current >= maxAmmo, current, maxAmmo, magTypeFull
end

local function eachInventoryItemRecursive(container, visit)
    if not container or not visit then
        return
    end
    local items = container:getItems()
    if not items then
        return
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            visit(item)
            if instanceof(item, "InventoryContainer") then
                eachInventoryItemRecursive(item:getInventory(), visit)
            end
        end
    end
end

local function findItemByIdRecursive(container, itemId)
    if not container or not itemId then
        return nil
    end
    local found = nil
    eachInventoryItemRecursive(container, function(item)
        local id = item and item.getID and item:getID() or nil
        if id == itemId then
            found = item
            return true
        end
        return false
    end)
    return found
end

local function findBestItemByFullTypeRecursive(container, fullType)
    if not container or not fullType then
        return nil
    end
    local best = nil
    local bestAmmo = -1
    local bestCond = -1
    eachInventoryItemRecursive(container, function(item)
        local itemFull = item and item.getFullType and item:getFullType() or nil
        if itemFull == fullType then
            local ammo = item.getCurrentAmmoCount and item:getCurrentAmmoCount() or 0
            ammo = tonumber(ammo) or 0
            local cond = item.getCondition and item:getCondition() or 0
            cond = tonumber(cond) or 0
            if ammo > bestAmmo or (ammo == bestAmmo and cond > bestCond) then
                best = item
                bestAmmo = ammo
                bestCond = cond
            end
        end
        return false
    end)
    return best
end

local function buildCompatibleMagazineSet(gun, fallbackMagType)
    local set = {}
    local function addType(typeName)
        local full = toMagFullType(typeName)
        if full then
            set[full] = true
        end
    end
    addType(fallbackMagType)
    if not gun or not gun.getType then
        return set
    end
    local weaponType = gun:getType()
    local byWeapon = _G.AWCWF_WeaponMagazineType
    local allowed = byWeapon and byWeapon[weaponType] or nil
    if allowed then
        for i = 1, #allowed do
            addType(allowed[i])
        end
    end
    return set
end

local function pickBestCompatibleMagazine(playerObj, compatibleSet, requirePositiveAmmo)
    if not playerObj or not compatibleSet then
        return nil
    end
    local inv = playerObj.getInventory and playerObj:getInventory() or nil
    if not inv then
        return nil
    end

    local bestItem = nil
    local bestAmmo = -1
    local bestCond = -1
    eachInventoryItemRecursive(inv, function(item)
        local fullType = item and item.getFullType and item:getFullType() or nil
        if fullType and compatibleSet[fullType] then
            local ammo = item.getCurrentAmmoCount and item:getCurrentAmmoCount() or 0
            ammo = tonumber(ammo) or 0
            if (not requirePositiveAmmo) or ammo > 0 then
                local cond = item.getCondition and item:getCondition() or 0
                cond = tonumber(cond) or 0
                if ammo > bestAmmo or (ammo == bestAmmo and cond > bestCond) then
                    bestItem = item
                    bestAmmo = ammo
                    bestCond = cond
                end
            end
        end
    end)
    return bestItem
end

local function queueEjectInsert(playerObj, gun, magItem, txId, reason, currentMag, maxAmmo)
    if not (playerObj and gun and magItem and ISTimedActionQueue and ISEjectMagazine and ISInsertMagazine) then
        return false
    end
    magTxLog(string.format(
        "tx=%s reloadR %s gun=%s magCurrent=%s max=%s insert=%s insertAmmo=%s",
        txId,
        reason,
        safeGunName(gun),
        safeValue(currentMag),
        safeValue(maxAmmo),
        safeValue(magItem.getFullType and magItem:getFullType() or nil),
        safeValue(magItem.getCurrentAmmoCount and magItem:getCurrentAmmoCount() or nil)
    ))
    ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, gun))
    ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magItem))
    return true
end

-- Keep weaponpart["Clip"] updated and transmitted when clip changes.
patchClassMetaMethod(zombie.inventory.types.HandWeapon.class, "setWeaponPart", function(orig)
    return function(item, partType, weaponpart, ...)
        local result = orig(item, partType, weaponpart)
        if not instanceof(item, "HandWeapon") then
            return result
        end
        if partType ~= "Clip" then
            return result
        end

        local fullType = weaponpart and normalizeClipFull(weaponpart:getFullType()) or nil
        local md = item:getModData()
        md.weaponpart = md.weaponpart or {}
        md.weaponpart["Clip"] = fullType

        if fullType then
            md.lastClipType = fullType
            local magType = clipPartToMagType(fullType)
            if magType and item.setMagazineType then
                pcall(item.setMagazineType, item, magType)
            end
            if magType then
                md.MagazineTypeNow = magType
            end
        end

        if item.transmitModData then
            item:transmitModData()
        end
        return result
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
            -- When inserting a different magazine class, trust current mag type first.
            local fullClip = magTypeToClipPart(currentMag)
            if not fullClip then
                fullClip = normalizeClipFull(md.weaponpart["Clip"] or md.lastClipType)
            end
            if fullClip then
                md.weaponpart["Clip"] = fullClip
                md.lastClipType = fullClip
                local magType = clipPartToMagType(fullClip) or currentMag
                if magType and item.setMagazineType then
                    pcall(item.setMagazineType, item, magType)
                end
                if magType then
                    md.MagazineTypeNow = magType
                end
            end
        else
            md.weaponpart["Clip"] = nil
            -- conserve lastClipType to help the next insert know what was last used
        end
        md.__ggsPendingInsertMag = nil
        if item.transmitModData then
            item:transmitModData()
        end
    end
end)

-- Guard vanilla bullet-loading-in-magazine flow against nil/desync states.
local function patchLoadBulletsInMagazine()
    if not ISLoadBulletsInMagazine then
        pcall(require, "TimedActions/ISLoadBulletsInMagazine")
    end
    if not ISLoadBulletsInMagazine or ISLoadBulletsInMagazine.__ggsLoadBulletsGuardPatched then
        return
    end
    ISLoadBulletsInMagazine.__ggsLoadBulletsGuardPatched = true

    local origStart = ISLoadBulletsInMagazine.start
    if type(origStart) == "function" then
        ISLoadBulletsInMagazine.start = function(self, ...)
            local txId = buildTxId()
            if not self or not self.character or not self.magazine then
                magTxLog(string.format("tx=%s loadMag start guarded (invalid action state)", txId))
                if self and self.forceStop then
                    pcall(self.forceStop, self)
                end
                return
            end
            local itemKey = safeGetMagazineAmmoItemKey(self.magazine)
            if not itemKey then
                magTxLog(string.format(
                    "tx=%s loadMag start guarded gun=%s magazine=%s reason=no_ammo_key",
                    txId,
                    safeGunName(self.gun),
                    safeValue(self.magazine.getFullType and self.magazine:getFullType())
                ))
                if self.forceStop then
                    pcall(self.forceStop, self)
                end
                return
            end
            local ok, err = pcall(origStart, self, ...)
            if not ok then
                magTxLog(string.format("tx=%s loadMag start exception=%s", txId, safeValue(err)))
                if self.forceStop then
                    pcall(self.forceStop, self)
                end
            end
        end
    end

    local origIsLoadFinished = ISLoadBulletsInMagazine.isLoadFinished
    if type(origIsLoadFinished) == "function" then
        ISLoadBulletsInMagazine.isLoadFinished = function(self, ...)
            if not self or not self.character or not self.magazine then
                magTxLog("loadMag isLoadFinished guarded (invalid action state)")
                return true
            end
            local itemKey = safeGetMagazineAmmoItemKey(self.magazine)
            if not itemKey then
                magTxLog(string.format(
                    "loadMag isLoadFinished guarded magazine=%s reason=no_ammo_key",
                    safeValue(self.magazine.getFullType and self.magazine:getFullType())
                ))
                return true
            end
            local ok, result = pcall(origIsLoadFinished, self, ...)
            if not ok then
                magTxLog(string.format("loadMag isLoadFinished exception=%s", safeValue(result)))
                return true
            end
            return result
        end
    end

    local origAnimEvent = ISLoadBulletsInMagazine.animEvent
    if type(origAnimEvent) == "function" then
        ISLoadBulletsInMagazine.animEvent = function(self, event, parameter)
            if not self then
                return
            end
            local ok, err = pcall(origAnimEvent, self, event, parameter)
            if ok then
                return
            end
            magTxLog(string.format(
                "loadMag animEvent exception event=%s magazine=%s err=%s",
                safeValue(event),
                safeValue(self.magazine and self.magazine.getFullType and self.magazine:getFullType()),
                safeValue(err)
            ))
            -- Fail closed: complete action instead of letting the timed action loop in broken state.
            if event == "InsertBullet" or event == "loadFinished" then
                self.loadFinished = true
                if isServer() and self.netAction and self.netAction.forceComplete then
                    pcall(self.netAction.forceComplete, self.netAction)
                end
            end
        end
    end
end

-- R key helper: if current detachable magazine is already full, eject only.
local function patchBeginAutomaticReload()
    if not ISReloadWeaponAction then
        pcall(require, "TimedActions/ISReloadWeaponAction")
    end
    if not ISReloadWeaponAction or ISReloadWeaponAction.__ggsBeginReloadPatched then
        return
    end
    local origBegin = ISReloadWeaponAction.BeginAutomaticReload
    if type(origBegin) ~= "function" then
        return
    end
    ISReloadWeaponAction.__ggsBeginReloadPatched = true
    ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun, ...)
        if gun and gun.getMagazineType and gun:getMagazineType() and gun.isContainsClip and gun:isContainsClip() and playerObj then
            local full, current, maxAmmo, magTypeFull = isMagazineFullForReload(gun)
            local compatibleSet = buildCompatibleMagazineSet(gun, magTypeFull)
            if not ISEjectMagazine then
                pcall(require, "TimedActions/ISEjectMagazine")
            end
            if not ISInsertMagazine then
                pcall(require, "TimedActions/ISInsertMagazine")
            end

            -- Empty inserted mag + compatible loaded mag available: do eject+insert in one key press.
            if tonumber(current) and tonumber(current) <= 0 then
                local candidateLoaded = pickBestCompatibleMagazine(playerObj, compatibleSet, true)
                if candidateLoaded then
                    local txId = buildTxId()
                    if queueEjectInsert(playerObj, gun, candidateLoaded, txId, "empty-mag swap", current, maxAmmo) then
                        return
                    end
                end
            end

            -- Full inserted mag: avoid vanilla load-loop bug and keep one-press behavior.
            if full and ISEjectMagazine and ISTimedActionQueue then
                local txId = buildTxId()
                local hasSpareCompatible = pickBestCompatibleMagazine(playerObj, compatibleSet, false) ~= nil
                local installedMag = getWeaponMagazine(gun)
                if hasSpareCompatible and installedMag and ISInsertMagazine then
                    if queueEjectInsert(playerObj, gun, installedMag, txId, "full-mag swap", current, maxAmmo) then
                        return
                    end
                end
                magTxLog(string.format(
                    "tx=%s reloadR full-mag eject-only gun=%s mag=%s current=%s max=%s",
                    txId,
                    safeGunName(gun),
                    safeValue(magTypeFull),
                    safeValue(current),
                    safeValue(maxAmmo)
                ))
                ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, gun))
                return
            end
        end
        return origBegin(playerObj, gun, ...)
    end
end

-- Transactional eject wrapper with diagnostics and optional server/SP compensation.
local function patchEjectMagazine()
    if not ISEjectMagazine or ISEjectMagazine.__ggsMagPatchedSafe then
        return
    end
    ISEjectMagazine.__ggsMagPatchedSafe = true
    local origUnload = ISEjectMagazine.unloadAmmo
    ISEjectMagazine.unloadAmmo = function(self, ...)
        local txId = buildTxId()
        local gun = self and self.gun
        if not gun or not gun.getModData then
            magTxLog(string.format("tx=%s begin gun=nil", txId))
            return origUnload(self, ...)
        end

        local md = gun:getModData()
        md.weaponpart = md.weaponpart or {}

        local installedPart = gun.getWeaponPart and gun:getWeaponPart("Clip") or nil
        local installedClipType = installedPart and installedPart.getFullType and normalizeClipFull(installedPart:getFullType()) or nil
        if installedClipType then
            md.weaponpart["Clip"] = installedClipType
            md.lastClipType = installedClipType
        end

        local clipType = normalizeClipFull(installedClipType or md.weaponpart["Clip"] or md.lastClipType)
        local magFromClip = clipPartToMagType(clipType)
        local currentMag = gun.getMagazineType and gun:getMagazineType() or md.MagazineTypeNow
        local expectedMag = toMagFullType(magFromClip or currentMag)
        local beforeAmmo = gun.getCurrentAmmoCount and gun:getCurrentAmmoCount() or 0
        local hadClipBefore = gun.isContainsClip and gun:isContainsClip() or (md.weaponpart["Clip"] ~= nil)

        if magFromClip and gun.setMagazineType then
            pcall(gun.setMagazineType, gun, magFromClip)
            md.MagazineTypeNow = magFromClip
        end

        local inventory = getMagazineInventory(self)
        local trackedTypes = collectTrackedMagazineTypes(expectedMag)
        local beforeSnapshot, beforeTotal = snapshotMagazineCounts(inventory, trackedTypes)

        magTxLog(string.format(
            "tx=%s begin gun=%s hadClip=%s clip=%s magCurrent=%s magExpected=%s ammo=%s totalBefore=%d",
            txId,
            safeGunName(gun),
            safeBool(hadClipBefore),
            safeValue(clipType),
            safeValue(currentMag),
            safeValue(expectedMag),
            safeValue(beforeAmmo),
            beforeTotal
        ))

        local result = origUnload(self, ...)

        local hasClipAfter = gun.isContainsClip and gun:isContainsClip() or false
        local afterSnapshot, afterTotal = snapshotMagazineCounts(inventory, trackedTypes)
        local expectedAfter = beforeTotal
        if hadClipBefore and not hasClipAfter then
            expectedAfter = beforeTotal + 1
        end

        local compensated = false
        local missing = 0
        if hadClipBefore and not hasClipAfter and afterTotal < expectedAfter then
            missing = expectedAfter - afterTotal
            if expectedMag and not isClient() then
                for i = 1, missing do
                    local ammoForItem = (i == 1) and beforeAmmo or 0
                    if createCompensationMagazine(inventory, expectedMag, ammoForItem) then
                        compensated = true
                    end
                end
                afterSnapshot, afterTotal = snapshotMagazineCounts(inventory, trackedTypes)
            elseif isClient() then
                magTxLog(string.format(
                    "tx=%s missing=%d expectedMag=%s (client observed only, waiting for server)",
                    txId,
                    missing,
                    safeValue(expectedMag)
                ))
            end
        end

        magTxLog(string.format(
            "tx=%s end gun=%s hasClip=%s totalAfter=%d expectedAfter=%d missing=%d compensated=%s diff=%s",
            txId,
            safeGunName(gun),
            safeBool(hasClipAfter),
            afterTotal,
            expectedAfter,
            missing,
            safeBool(compensated),
            snapshotDiff(beforeSnapshot, afterSnapshot)
        ))

        return result
    end
end

Events.OnGameBoot.Add(patchLoadBulletsInMagazine)
Events.OnGameStart.Add(patchLoadBulletsInMagazine)
Events.OnGameBoot.Add(patchBeginAutomaticReload)
Events.OnGameStart.Add(patchBeginAutomaticReload)
Events.OnGameBoot.Add(patchEjectMagazine)
Events.OnGameStart.Add(patchEjectMagazine)

local function resolveInsertMagazine(self)
    if not self then
        return nil
    end
    local magazine = self.magazine
    if magazine and magazine.getID then
        local okId, id = pcall(magazine.getID, magazine)
        if okId and id then
            self.__ggsInsertMagId = id
        end
    end
    local inventory = getMagazineInventory(self)
    local desiredType = nil
    if self and self.__ggsDesiredMagFull then
        desiredType = toMagFullType(self.__ggsDesiredMagFull)
    end
    if not desiredType and self and self.gun and self.gun.getModData then
        local md = self.gun:getModData()
        desiredType = toMagFullType(md and md.__ggsPreferredMagFull)
    end
    if inventory and self and self.__ggsDesiredMagId then
        local byDesiredId = nil
        if inventory.getItemById then
            byDesiredId = inventory:getItemById(self.__ggsDesiredMagId)
        end
        if not byDesiredId then
            byDesiredId = findItemByIdRecursive(inventory, self.__ggsDesiredMagId)
        end
        if byDesiredId then
            magazine = byDesiredId
            self.magazine = byDesiredId
            self.__ggsInsertMagId = self.__ggsDesiredMagId
        end
    end
    if inventory and self.__ggsInsertMagId then
        local fresh = nil
        if inventory.getItemById then
            fresh = inventory:getItemById(self.__ggsInsertMagId)
        end
        if not fresh then
            fresh = findItemByIdRecursive(inventory, self.__ggsInsertMagId)
        end
        if fresh then
            magazine = fresh
            self.magazine = fresh
        end
    end

    if inventory and self then
        local magazineContainer = magazine and magazine.getContainer and magazine:getContainer() or nil
        if not magazineContainer then
            if not desiredType and self.gun and self.gun.getMagazineType then
                desiredType = toMagFullType(self.gun:getMagazineType())
            end
            if not desiredType and self.magazine and self.magazine.getFullType then
                desiredType = toMagFullType(self.magazine:getFullType())
            end
            local fallback = findBestItemByFullTypeRecursive(inventory, desiredType)
            if fallback then
                magazine = fallback
                self.magazine = fallback
                if fallback.getID then
                    local okId, id = pcall(fallback.getID, fallback)
                    if okId and id then
                        self.__ggsInsertMagId = id
                    end
                end
            end
        end
    end

    -- Force selected/preferred magazine type when action carries a stale magazine reference.
    if inventory and desiredType then
        local currentType = toMagFullType(magazine and magazine.getFullType and magazine:getFullType() or nil)
        if currentType ~= desiredType then
            local forced = findBestItemByFullTypeRecursive(inventory, desiredType)
            if forced then
                magTxLog(string.format(
                    "insert resolve override desired=%s current=%s forced=%s",
                    safeValue(desiredType),
                    safeValue(currentType),
                    safeValue(forced.getFullType and forced:getFullType() or nil)
                ))
                magazine = forced
                self.magazine = forced
                if forced.getID then
                    local okId, id = pcall(forced.getID, forced)
                    if okId and id then
                        self.__ggsInsertMagId = id
                    end
                end
            end
        end
    end

    return magazine
end

local function readMagazineAmmo(magazine, fallbackAmmo)
    local ammo = fallbackAmmo
    if magazine and magazine.getCurrentAmmoCount then
        local okAmmo, value = pcall(magazine.getCurrentAmmoCount, magazine)
        if okAmmo and value ~= nil then
            ammo = tonumber(value)
        end
    end
    ammo = tonumber(ammo)
    if ammo == nil then
        ammo = 0
    end
    if ammo < 0 then
        ammo = 0
    end
    return ammo
end

local function resolveMagazineForRemoval(self, gun, magazine, inventory)
    if not inventory then
        return magazine
    end

    local function isInContainer(item)
        local c = item and item.getContainer and item:getContainer() or nil
        return c and c.contains and c:contains(item)
    end

    if magazine and isInContainer(magazine) then
        return magazine
    end

    local candidateId = nil
    if self and self.__ggsDesiredMagId then
        candidateId = self.__ggsDesiredMagId
    elseif self and self.__ggsInsertMagId then
        candidateId = self.__ggsInsertMagId
    elseif magazine and magazine.getID then
        local okId, id = pcall(magazine.getID, magazine)
        if okId then
            candidateId = id
        end
    end

    if candidateId then
        local byId = findItemByIdRecursive(inventory, candidateId)
        if byId and isInContainer(byId) then
            return byId
        end
    end

    local desiredType = nil
    if self and self.__ggsDesiredMagFull then
        desiredType = toMagFullType(self.__ggsDesiredMagFull)
    end
    if not desiredType and gun and gun.getModData then
        local md = gun:getModData()
        desiredType = toMagFullType(md and md.__ggsPreferredMagFull)
    end
    if not desiredType and gun and gun.getMagazineType then
        desiredType = toMagFullType(gun:getMagazineType())
    end
    if not desiredType and magazine and magazine.getFullType then
        local okType, fullType = pcall(magazine.getFullType, magazine)
        if okType then
            desiredType = toMagFullType(fullType)
        end
    end

    if desiredType then
        local byType = findBestItemByFullTypeRecursive(inventory, desiredType)
        if byType and isInContainer(byType) then
            return byType
        end
    end

    return magazine
end

local function applyInsertMagazineFallback(self, gun, magazine, ammoCount)
    local character = self and self.character
    local inventory = getMagazineInventory(self)
    if not (character and gun and magazine and inventory) then
        return false
    end

    magazine = resolveMagazineForRemoval(self, gun, magazine, inventory)
    local sourceContainer = magazine.getContainer and magazine:getContainer() or nil
    if sourceContainer and sourceContainer.contains and sourceContainer:contains(magazine) then
        sourceContainer:Remove(magazine)
        if sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, sourceContainer, magazine)
        end
    elseif inventory.contains and inventory:contains(magazine) then
        inventory:Remove(magazine)
        if sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, inventory, magazine)
        end
    end

    if character.removeFromHands then
        pcall(character.removeFromHands, character, magazine)
    end
    if gun.setCurrentAmmoCount then
        pcall(gun.setCurrentAmmoCount, gun, ammoCount)
    end
    if gun.setContainsClip then
        pcall(gun.setContainsClip, gun, true)
    end
    if character.clearVariable then
        pcall(character.clearVariable, character, "isLoading")
        pcall(character.clearVariable, character, "WeaponReloadType")
    end
    if syncHandWeaponFields then
        pcall(syncHandWeaponFields, character, gun)
    end
    return true
end

local function performInsertMagazineLoad(self, gun, magazine)
    local character = self and self.character
    local inventory = getMagazineInventory(self)
    if not (character and gun and magazine and inventory) then
        return false
    end

    magazine = resolveMagazineForRemoval(self, gun, magazine, inventory)
    local sourceContainer = magazine.getContainer and magazine:getContainer() or inventory
    local removed = false
    if sourceContainer and sourceContainer.contains and sourceContainer:contains(magazine) then
        sourceContainer:Remove(magazine)
        if sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, sourceContainer, magazine)
        end
        removed = true
    elseif inventory.contains and inventory:contains(magazine) then
        inventory:Remove(magazine)
        if sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, inventory, magazine)
        end
        removed = true
    end

    if character.removeFromHands then
        pcall(character.removeFromHands, character, magazine)
    end

    local ammoCount = readMagazineAmmo(magazine, 0)
    if gun.setCurrentAmmoCount then
        pcall(gun.setCurrentAmmoCount, gun, ammoCount)
    end
    if gun.setContainsClip then
        pcall(gun.setContainsClip, gun, true)
    end
    if character.clearVariable then
        pcall(character.clearVariable, character, "isLoading")
    end

    if not isServer() and not isClient() and gun.isRoundChambered and gun.getCurrentAmmoCount and gun.getAmmoPerShoot and
        not gun:isRoundChambered() and gun:getCurrentAmmoCount() >= gun:getAmmoPerShoot() and ISRackFirearm and
        ISTimedActionQueue then
        ISTimedActionQueue.addAfter(self, ISRackFirearm:new(character, gun))
    end

    if syncHandWeaponFields then
        pcall(syncHandWeaponFields, character, gun)
    end

    return removed
end

-- Ensure inserted magazine type is authoritative in MP/SP before clip state is committed.
local function patchInsertMagazine()
    if not ISInsertMagazine then
        pcall(require, "TimedActions/ISInsertMagazine")
    end
    if not ISInsertMagazine or ISInsertMagazine.__ggsMagInsertPatched then
        return
    end
    local origIsValid = ISInsertMagazine.isValid
    if type(origIsValid) == "function" then
        ISInsertMagazine.isValid = function(self, ...)
            local character = self and self.character
            local gun = self and self.gun
            if not character or not gun then
                return false
            end
            if not isClient() and not self.loadFinished then
                if gun.isContainsClip and gun:isContainsClip() then
                    return false
                end
                if self.magazine then
                    local resolved = resolveInsertMagazine(self)
                    if not resolved then
                        return false
                    end
                    local inventory = getMagazineInventory(self)
                    if not inventory then
                        return false
                    end
                    local sourceContainer = resolved.getContainer and resolved:getContainer() or nil
                    if not sourceContainer then
                        return false
                    end
                    local resolvedId = resolved.getID and resolved:getID() or nil
                    if resolvedId and not findItemByIdRecursive(inventory, resolvedId) then
                        return false
                    end
                end
            end
            return character:getPrimaryHandItem() == gun
        end
    end

    local origStart = ISInsertMagazine.start
    if type(origStart) == "function" then
        ISInsertMagazine.start = function(self, ...)
            if self and self.magazine and self.magazine.getID then
                local okId, id = pcall(self.magazine.getID, self.magazine)
                if okId and id then
                    self.__ggsInsertMagId = id
                end
            end
            if self and self.gun and self.gun.getModData then
                local md = self.gun:getModData()
                if md and md.__ggsPreferredMagFull then
                    self.__ggsDesiredMagFull = self.__ggsDesiredMagFull or md.__ggsPreferredMagFull
                end
            end
            local result = origStart(self, ...)
            local mag = resolveInsertMagazine(self)
            if self then
                self.__ggsInsertSavedAmmo = readMagazineAmmo(mag, self.__ggsInsertSavedAmmo)
            end
            return result
        end
    end
    local origServerStart = ISInsertMagazine.serverStart
    if type(origServerStart) == "function" then
        ISInsertMagazine.serverStart = function(self, ...)
            if self and self.magazine and self.magazine.getID then
                local okId, id = pcall(self.magazine.getID, self.magazine)
                if okId and id then
                    self.__ggsInsertMagId = id
                end
            end
            if self and self.gun and self.gun.getModData then
                local md = self.gun:getModData()
                if md and md.__ggsPreferredMagFull then
                    self.__ggsDesiredMagFull = self.__ggsDesiredMagFull or md.__ggsPreferredMagFull
                end
            end
            local result = origServerStart(self, ...)
            local mag = resolveInsertMagazine(self)
            if self then
                self.__ggsInsertSavedAmmo = readMagazineAmmo(mag, self.__ggsInsertSavedAmmo)
            end
            return result
        end
    end
    local origLoad = ISInsertMagazine.loadAmmo
    if type(origLoad) ~= "function" then
        return
    end
    ISInsertMagazine.__ggsMagInsertPatched = true
    ISInsertMagazine.loadAmmo = function(self, ...)
        local gun = self and self.gun
        local mag = resolveInsertMagazine(self)
        if self then
            self.__ggsInsertSavedAmmo = readMagazineAmmo(mag, self.__ggsInsertSavedAmmo)
        end
        local magFull = toMagFullType(mag and mag.getFullType and mag:getFullType() or nil)
        local txId = buildTxId()
        local inventory = getMagazineInventory(self)
        local trackedTypes = collectTrackedMagazineTypes(magFull)
        local beforeSnapshot, beforeTotal = snapshotMagazineCounts(inventory, trackedTypes)
        local beforeSelected = (magFull and beforeSnapshot[magFull]) or 0
        local magAmmoBefore = self and self.__ggsInsertSavedAmmo or readMagazineAmmo(mag, nil)
        local magCurrent = gun and gun.getMagazineType and gun:getMagazineType() or nil

        magTxLog(string.format(
            "tx=%s insert begin gun=%s insertMag=%s desired=%s insertAmmo=%s magCurrent=%s totalBefore=%d selectedBefore=%d",
            txId,
            safeGunName(gun),
            safeValue(magFull),
            safeValue(self and self.__ggsDesiredMagFull or nil),
            safeValue(magAmmoBefore),
            safeValue(magCurrent),
            beforeTotal,
            beforeSelected
        ))

        if gun and magFull and gun.getModData then
            local md = gun:getModData()
            md.weaponpart = md.weaponpart or {}
            md.__ggsPendingInsertMag = magFull
            md.MagazineTypeNow = magFull
            if gun.setMagazineType then
                pcall(gun.setMagazineType, gun, magFull)
            end
        end

        local directApplied = performInsertMagazineLoad(self, gun, mag)
        local loadOk = true
        local result = nil
        if not directApplied then
            local resultOrErr = nil
            loadOk, resultOrErr = pcall(origLoad, self, ...)
            if not loadOk then
                magTxLog(string.format(
                    "tx=%s insert exception gun=%s insertMag=%s err=%s",
                    txId,
                    safeGunName(gun),
                    safeValue(magFull),
                    safeValue(resultOrErr)
                ))
            else
                result = resultOrErr
            end
        end

        local hasClipAfterLoad = gun and gun.isContainsClip and gun:isContainsClip() or false
        local fallbackApplied = false
        if not hasClipAfterLoad and gun and mag then
            fallbackApplied = applyInsertMagazineFallback(self, gun, mag, readMagazineAmmo(mag, magAmmoBefore))
            if fallbackApplied then
                magTxLog(string.format(
                    "tx=%s insert fallback-applied gun=%s insertMag=%s",
                    txId,
                    safeGunName(gun),
                    safeValue(magFull)
                ))
            end
        end

        if gun and magFull and gun.getModData then
            local md = gun:getModData()
            md.weaponpart = md.weaponpart or {}
            if gun.setMagazineType then
                pcall(gun.setMagazineType, gun, magFull)
            end
            if _G.GGS_MagMapping then
                local hasClipNow = gun.isContainsClip and gun:isContainsClip() or false
                local clipFull, resolvedMag = _G.GGS_MagMapping.syncFromMagazine(gun, {
                    magFull = magFull,
                    installPart = hasClipNow
                })
                if clipFull then
                    md.weaponpart["Clip"] = clipFull
                    md.lastClipType = clipFull
                end
                if resolvedMag then
                    md.MagazineTypeNow = resolvedMag
                    md.__ggsPreferredMagFull = resolvedMag
                else
                    md.MagazineTypeNow = magFull
                    md.__ggsPreferredMagFull = magFull
                end
            else
                md.MagazineTypeNow = magFull
                md.__ggsPreferredMagFull = magFull
            end
            md.__ggsPendingInsertMag = nil
            if gun.transmitModData then
                gun:transmitModData()
            end
        end

        local afterSnapshot, afterTotal = snapshotMagazineCounts(inventory, trackedTypes)
        local afterSelected = (magFull and afterSnapshot[magFull]) or 0
        local hasClipAfter = gun and gun.isContainsClip and gun:isContainsClip() or false
        local expectedAfterTotal = beforeTotal
        local expectedAfterSelected = beforeSelected
        if magFull and hasClipAfter then
            expectedAfterTotal = math.max(0, beforeTotal - 1)
            expectedAfterSelected = math.max(0, beforeSelected - 1)
        end
        local missingTotal = math.max(0, expectedAfterTotal - afterTotal)
        local missingSelected = math.max(0, expectedAfterSelected - afterSelected)
        local insertedMagNow = gun and gun.getMagazineType and gun:getMagazineType() or nil
        local compensated = false
        if magFull and not hasClipAfter and afterSelected < beforeSelected and not isClient() then
            local toRestore = beforeSelected - afterSelected
            for i = 1, toRestore do
                if createCompensationMagazine(inventory, magFull, (i == 1) and magAmmoBefore or 0) then
                    compensated = true
                end
            end
            if compensated then
                afterSnapshot, afterTotal = snapshotMagazineCounts(inventory, trackedTypes)
                afterSelected = (magFull and afterSnapshot[magFull]) or 0
            end
        elseif magFull and not hasClipAfter and afterSelected < beforeSelected and isClient() then
            magTxLog(string.format(
                "tx=%s insert no-clip and selected dropped (client observed, waiting for server) insertMag=%s",
                txId,
                safeValue(magFull)
            ))
        end

        magTxLog(string.format(
            "tx=%s insert end gun=%s insertMag=%s magNow=%s hasClip=%s fallback=%s compensated=%s totalAfter=%d expectedTotal=%d missingTotal=%d selectedAfter=%d expectedSelected=%d missingSelected=%d diff=%s",
            txId,
            safeGunName(gun),
            safeValue(magFull),
            safeValue(insertedMagNow),
            safeBool(hasClipAfter),
            safeBool(fallbackApplied),
            safeBool(compensated),
            afterTotal,
            expectedAfterTotal,
            missingTotal,
            afterSelected,
            expectedAfterSelected,
            missingSelected,
            snapshotDiff(beforeSnapshot, afterSnapshot)
        ))
        if self then
            self.__ggsInsertSavedAmmo = nil
            self.__ggsInsertMagId = nil
            self.__ggsDesiredMagFull = nil
            self.__ggsDesiredMagId = nil
        end
        return result
    end
end

Events.OnGameBoot.Add(patchInsertMagazine)
Events.OnGameStart.Add(patchInsertMagazine)

local function findPlayerWeaponById(playerObj, itemId)
    if not playerObj then
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

-- Server-side: accept sync updates from client.
local function onClientCommand(module, command, playerObj, args)
    if module ~= "GGS" then
        return
    end
    if not playerObj or not playerObj.getPrimaryHandItem then
        return
    end

    local gun = nil
    local gunId = args and args.gunId or nil
    if gunId then
        gun = findPlayerWeaponById(playerObj, gunId)
    end
    if not gun then
        gun = playerObj:getPrimaryHandItem()
    end
    if not (gun and gun.IsWeapon and gun:IsWeapon()) then
        return
    end

    if command == "SetClipType" then
        local clipType = args and args.clipType
        if not clipType then
            return
        end
        clipType = normalizeClipFull(clipType)
        local md = gun:getModData()
        md.weaponpart = md.weaponpart or {}
        md.weaponpart["Clip"] = clipType
        md.lastClipType = clipType
        local magType = clipPartToMagType(clipType)
        if magType and gun.setMagazineType then
            pcall(gun.setMagazineType, gun, magType)
        end
        if magType then
            md.MagazineTypeNow = magType
            md.__ggsPreferredMagFull = magType
        end
        if gun.transmitModData then
            gun:transmitModData()
        end
        return
    end

    if command == "SetPreferredMag" then
        local magFull = args and args.magFull
        magFull = toMagFullType(magFull)
        if not magFull then
            return
        end
        local md = gun:getModData()
        md.weaponpart = md.weaponpart or {}
        md.__ggsPreferredMagFull = magFull
        md.MagazineTypeNow = magFull
        if gun.setMagazineType then
            pcall(gun.setMagazineType, gun, magFull)
        end
        if gun.transmitModData then
            gun:transmitModData()
        end
        magTxLog(string.format("server preferred mag set gun=%s mag=%s", safeGunName(gun), safeValue(magFull)))
        return
    end
end

Events.OnClientCommand.Add(onClientCommand)

