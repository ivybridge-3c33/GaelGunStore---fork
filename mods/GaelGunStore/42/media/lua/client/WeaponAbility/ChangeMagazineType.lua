require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISEjectMagazine"
require "TimedActions/ISInsertMagazine"

local function ggsText(key)
    local text = getText(key)
    if text and text ~= key then
        return text
    end
    return key
end

local function shortType(typeName)
    if not typeName then
        return nil
    end
    local raw = tostring(typeName)
    local short = raw:match("([^.]+)$")
    return short or raw
end

local function fullType(typeName)
    if not typeName then
        return nil
    end
    local raw = tostring(typeName)
    if raw:find("%.") then
        return raw
    end
    return "Base." .. raw
end

local function instanceItemSafe(typeName)
    if not (typeName and instanceItem) then
        return nil
    end
    local ok, item = pcall(instanceItem, typeName)
    if ok then
        return item
    end
    return nil
end

local function resolveClipPartFromMagType(typeName)
    local map = _G.AWCWF_MagazineTypeToPart
    if not (map and typeName) then
        return nil
    end

    local clipType = map[typeName] or map[shortType(typeName)]
    if not clipType then
        return nil
    end

    clipType = tostring(clipType)
    if clipType:find("Clip_", 1, true) then
        if clipType:find("%.") then
            return clipType
        end
        return "Base." .. clipType
    end
    if clipType:find("%.") then
        return clipType
    end
    return "Base." .. clipType
end

local function setMagazineTypeSafe(weapon, magType)
    if not (weapon and weapon.setMagazineType and magType) then
        return false
    end

    local tried = {}
    local variants = {
        tostring(magType),
        shortType(magType),
        fullType(magType),
    }

    for i = 1, #variants do
        local value = variants[i]
        if value and not tried[value] then
            tried[value] = true
            local ok = pcall(weapon.setMagazineType, weapon, value)
            if ok then
                return true
            end
        end
    end
    return false
end

local function resolveCanonicalMagType(weapon, requestedMag)
    local requestedShort = shortType(requestedMag)
    local byWeapon = _G.AWCWF_WeaponMagazineType
    if byWeapon and weapon and weapon.getType then
        local allowed = byWeapon[weapon:getType()]
        if allowed then
            for i = 1, #allowed do
                if shortType(allowed[i]) == requestedShort then
                    return tostring(allowed[i])
                end
            end
        end
    end
    return requestedShort
end

local function weaponAllowsMagazine(weapon, requestedMag)
    local byWeapon = _G.AWCWF_WeaponMagazineType
    if not (byWeapon and weapon and weapon.getType) then
        return true
    end

    local allowed = byWeapon[weapon:getType()]
    if not allowed then
        return true
    end

    local requestedShort = shortType(requestedMag)
    for i = 1, #allowed do
        if shortType(allowed[i]) == requestedShort then
            return true
        end
    end
    return false
end

local function eachItemRecursive(container, visit)
    if not (container and visit) then
        return false
    end
    local items = container.getItems and container:getItems() or nil
    if not items then
        return false
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if visit(item) then
                return true
            end
            if instanceof(item, "InventoryContainer") and item.getInventory then
                if eachItemRecursive(item:getInventory(), visit) then
                    return true
                end
            end
        end
    end
    return false
end

local function selectBestMagazine(inventory, magType)
    if not (inventory and magType) then
        return nil
    end

    local targetShort = shortType(magType)
    local targetFull = fullType(magType)
    local bestItem = nil
    local bestAmmo = -1
    local bestCondition = -1

    eachItemRecursive(inventory, function(item)
        local itemFull = item.getFullType and item:getFullType() or nil
        if not itemFull then
            return false
        end

        if itemFull ~= targetFull and shortType(itemFull) ~= targetShort then
            return false
        end

        local ammo = item.getCurrentAmmoCount and item:getCurrentAmmoCount() or 0
        ammo = tonumber(ammo) or 0
        local condition = item.getCondition and item:getCondition() or 0
        condition = tonumber(condition) or 0

        if ammo > bestAmmo or (ammo == bestAmmo and condition > bestCondition) then
            bestItem = item
            bestAmmo = ammo
            bestCondition = condition
        end
        return false
    end)

    return bestItem
end

local function resolveMaxAmmoForType(magType, fallbackWeapon)
    local magItem = instanceItemSafe(fullType(magType)) or instanceItemSafe(shortType(magType))
    if magItem and magItem.getMaxAmmo then
        local ok, maxAmmo = pcall(magItem.getMaxAmmo, magItem)
        if ok and maxAmmo then
            return tonumber(maxAmmo)
        end
    end

    if fallbackWeapon and fallbackWeapon.getMaxAmmo then
        local ok, maxAmmo = pcall(fallbackWeapon.getMaxAmmo, fallbackWeapon)
        if ok and maxAmmo then
            return tonumber(maxAmmo)
        end
    end
    return nil
end

local function syncHandsModel(playerObj, weapon)
    if not (playerObj and weapon) then
        return
    end

    if syncHandWeaponFields then
        pcall(syncHandWeaponFields, playerObj, weapon)
    end

    local primary = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if primary == weapon then
        local isTwoHand = weapon.isTwoHandWeapon and weapon:isTwoHandWeapon() or false
        local secondary = playerObj.getSecondaryHandItem and playerObj:getSecondaryHandItem() or nil
        if isTwoHand and secondary ~= weapon and playerObj.setSecondaryHandItem then
            pcall(playerObj.setSecondaryHandItem, playerObj, weapon)
        elseif (not isTwoHand) and secondary == weapon and playerObj.setSecondaryHandItem then
            pcall(playerObj.setSecondaryHandItem, playerObj, nil)
        end
    end

    if playerObj.resetEquippedHandsModels then
        playerObj:resetEquippedHandsModels()
    end
    if playerObj.resetModelNextFrame then
        playerObj:resetModelNextFrame()
    end
end

local function applyClipVisualFromMagazineType(weapon, magType)
    if not weapon then
        return
    end

    local md = weapon.getModData and weapon:getModData() or nil
    if md then
        md.weaponpart = md.weaponpart or {}
    end

    local hasClip = weapon.isContainsClip and weapon:isContainsClip() or false
    local clipFull = resolveClipPartFromMagType(magType)

    if hasClip and clipFull and weapon.setWeaponPart then
        local clipItem = instanceItemSafe(clipFull)
        if clipItem and instanceof(clipItem, "WeaponPart") then
            pcall(weapon.setWeaponPart, weapon, "Clip", clipItem)
            if md then
                md.weaponpart["Clip"] = clipFull
                md.lastClipType = clipFull
            end
        end
    elseif (not hasClip) and weapon.clearWeaponPart then
        pcall(weapon.clearWeaponPart, weapon, "Clip")
        if md then
            md.weaponpart["Clip"] = nil
        end
    end
end

local SetMagTypeAction = ISBaseTimedAction:derive("SetMagTypeAction")

function SetMagTypeAction:isValid()
    return self.gun ~= nil
end

function SetMagTypeAction:start()
    self.stopOnWalk = false
    self.stopOnRun = false
end

function SetMagTypeAction:update()
end

function SetMagTypeAction:perform()
    if self.gun then
        setMagazineTypeSafe(self.gun, self.magType)
        if self.maxAmmo and self.maxAmmo > 0 and self.gun.setMaxAmmo then
            pcall(self.gun.setMaxAmmo, self.gun, self.maxAmmo)
        end
    end
    ISBaseTimedAction.perform(self)
end

function SetMagTypeAction:new(character, gun, magType, maxAmmo)
    local o = ISBaseTimedAction.new(self, character)
    o.gun = gun
    o.magType = magType
    o.maxAmmo = maxAmmo
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = 1
    return o
end

local PostSwapAction = ISBaseTimedAction:derive("PostSwapAction")

function PostSwapAction:isValid()
    return self.gun ~= nil
end

function PostSwapAction:start()
    self.stopOnWalk = false
    self.stopOnRun = false
end

function PostSwapAction:update()
end

function PostSwapAction:perform()
    if self.gun then
        local md = self.gun.getModData and self.gun:getModData() or nil
        if md then
            md.MagazineTypeNow = self.magType
            md.__ggsPreferredMagFull = self.magType
            md.__ggsPreferredMagType = self.magType
        end

        if self.hadRoundChambered and self.gun.setRoundChambered then
            pcall(self.gun.setRoundChambered, self.gun, true)
        end

        applyClipVisualFromMagazineType(self.gun, self.magType)

        if self.gun.transmitModData then
            pcall(self.gun.transmitModData, self.gun)
        end
    end

    syncHandsModel(self.character, self.gun)
    ISBaseTimedAction.perform(self)
end

function PostSwapAction:new(character, gun, magType, hadRoundChambered)
    local o = ISBaseTimedAction.new(self, character)
    o.gun = gun
    o.magType = magType
    o.hadRoundChambered = hadRoundChambered
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = 1
    return o
end

local function restorePreferredMagazineType(playerObj, weapon)
    if not (playerObj and weapon) then
        return false
    end
    if not (weapon.IsWeapon and weapon:IsWeapon() and weapon.isRanged and weapon:isRanged()) then
        return false
    end

    local md = weapon.getModData and weapon:getModData() or nil
    if not md then
        return false
    end

    local preferred = md.__ggsPreferredMagFull or md.__ggsPreferredMagType or md.MagazineTypeNow
    if not preferred then
        return false
    end

    if not weaponAllowsMagazine(weapon, preferred) then
        return false
    end

    local selectedType = resolveCanonicalMagType(weapon, preferred)
    local selectedMax = resolveMaxAmmoForType(selectedType, weapon)

    setMagazineTypeSafe(weapon, selectedType)
    if selectedMax and selectedMax > 0 and weapon.setMaxAmmo then
        pcall(weapon.setMaxAmmo, weapon, selectedMax)
    end

    if selectedMax and selectedMax > 0 and weapon.getCurrentAmmoCount and weapon.setCurrentAmmoCount then
        local okAmmo, currentAmmo = pcall(weapon.getCurrentAmmoCount, weapon)
        if okAmmo and currentAmmo and currentAmmo > selectedMax then
            pcall(weapon.setCurrentAmmoCount, weapon, selectedMax)
        end
    end

    md.MagazineTypeNow = selectedType
    md.__ggsPreferredMagFull = selectedType
    md.__ggsPreferredMagType = selectedType
    applyClipVisualFromMagazineType(weapon, selectedType)

    if weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
    syncHandsModel(playerObj, weapon)
    return true
end

function ChangeMagazine(playerObj, mainGun, magazineType, _tag, need)
    if need == false then
        return false
    end

    playerObj = playerObj or getPlayer()
    if not (playerObj and mainGun and magazineType) then
        return false
    end
    if not (mainGun.IsWeapon and mainGun:IsWeapon() and mainGun.isRanged and mainGun:isRanged()) then
        return false
    end
    if not weaponAllowsMagazine(mainGun, magazineType) then
        return false
    end

    local selectedType = resolveCanonicalMagType(mainGun, magazineType)
    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    local selectedMagItem = selectBestMagazine(inventory, selectedType)

    if not selectedMagItem then
        if playerObj.Say then
            playerObj:Say(ggsText("IGUI_GGS_NoMagazine"))
        end
        return false
    end

    local selectedFull = selectedMagItem.getFullType and selectedMagItem:getFullType() or fullType(selectedType)
    local selectedMax = selectedMagItem.getMaxAmmo and selectedMagItem:getMaxAmmo() or nil
    selectedMax = tonumber(selectedMax) or resolveMaxAmmoForType(selectedFull, mainGun)

    local hadRoundChambered = mainGun.isRoundChambered and mainGun:isRoundChambered() or false
    local hadClip = mainGun.isContainsClip and mainGun:isContainsClip() or false
    if not hadClip and mainGun.getWeaponPart then
        hadClip = mainGun:getWeaponPart("Clip") ~= nil
    end

    local md = mainGun.getModData and mainGun:getModData() or nil
    if md then
        md.MagazineTypeNow = selectedFull
        md.__ggsPreferredMagFull = selectedFull
        md.__ggsPreferredMagType = selectedFull
        if isClient() and sendClientCommand then
            sendClientCommand("GGS", "SetPreferredMag", {
                gunId = mainGun.getID and mainGun:getID() or nil,
                magFull = selectedFull
            })
        end
        if mainGun.transmitModData then
            pcall(mainGun.transmitModData, mainGun)
        end
    end

    if hadClip and ISEjectMagazine then
        ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, mainGun))
    end

    ISTimedActionQueue.add(SetMagTypeAction:new(playerObj, mainGun, selectedFull, selectedMax))

    if ISInsertMagazine then
        local insertAction = ISInsertMagazine:new(playerObj, mainGun, selectedMagItem)
        insertAction.__ggsDesiredMagFull = selectedFull
        if selectedMagItem and selectedMagItem.getID then
            local okId, itemId = pcall(selectedMagItem.getID, selectedMagItem)
            if okId and itemId then
                insertAction.__ggsDesiredMagId = itemId
            end
        end
        ISTimedActionQueue.add(insertAction)
    end

    ISTimedActionQueue.add(PostSwapAction:new(playerObj, mainGun, selectedFull, hadRoundChambered))
    return true
end

local function onEquipPrimaryRestore(playerObj, item)
    restorePreferredMagazineType(playerObj, item)
end

local function onGameStartRestore()
    local playerObj = getPlayer()
    if not playerObj then
        return
    end
    restorePreferredMagazineType(playerObj, playerObj:getPrimaryHandItem())
end

local function installMagazinePersistenceHooks()
    if _G.__ggsMagPersistenceHooksInstalled then
        return
    end
    _G.__ggsMagPersistenceHooksInstalled = true

    if Events and Events.OnEquipPrimary and Events.OnEquipPrimary.Add then
        Events.OnEquipPrimary.Add(onEquipPrimaryRestore)
    end
    if Events and Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(onGameStartRestore)
    end
end

installMagazinePersistenceHooks()
