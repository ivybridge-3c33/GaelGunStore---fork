if isServer() then
    return
end

require "TimedActions/ISBaseTimedAction"
pcall(require, "ISUI/ISRadialMenu")

local runtime = rawget(_G, "GGS_ArcheryRuntime") or {}
_G.GGS_ArcheryRuntime = runtime

local RELOAD_HOLD_MENU_DELAY_MS = 280
local DEFAULT_RELOAD_KEY = Keyboard and Keyboard.KEY_R or 19
local MODDATA_SELECTED_AMMO = "ggsSelectedAmmoType"

local function ggsText(key)
    local text = getText(key)
    if text and text ~= key then
        return text
    end
    return key
end

local reloadHoldState = {
    pressedMs = nil,
    consumedByRadial = false,
    pendingReload = false,
    playerNum = 0
}
local reloadKeyHooksInstalled = false

local getLoadedAmmoType
local syncWeaponVisual
local requestArcheryReload

local function normalizeFullType(fullType)
    if GGS_BOWS and GGS_BOWS.normalizeFullType then
        return GGS_BOWS.normalizeFullType(fullType)
    end
    if not fullType then
        return nil
    end
    fullType = tostring(fullType)
    if fullType:find(".", 1, true) then
        return fullType
    end
    return "Base." .. fullType
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
        local okM, moduleName = pcall(item.getModule, item)
        local okT, itemType = pcall(item.getType, item)
        if okM and okT and moduleName and itemType then
            return normalizeFullType(tostring(moduleName) .. "." .. tostring(itemType))
        end
    end
    return nil
end

local function getWeaponProfile(weapon)
    if not (GGS_BOWS and GGS_BOWS.getWeaponProfile) then
        return nil
    end
    return GGS_BOWS.getWeaponProfile(getWeaponFullType(weapon))
end

local function getAmmoProfile(ammoFullType)
    if not (GGS_BOWS and GGS_BOWS.getAmmoProfile) then
        return nil
    end
    return GGS_BOWS.getAmmoProfile(normalizeFullType(ammoFullType))
end

local function syncWeaponNet(playerObj, weapon)
    if syncHandWeaponFields then
        pcall(syncHandWeaponFields, playerObj, weapon)
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

local function shortTypeName(fullType)
    local normalized = normalizeFullType(fullType)
    if not normalized then
        return nil
    end
    local short = normalized:match("([^.]+)$")
    return short or normalized
end

local function getReloadKey()
    local core = getCore and getCore() or nil
    if core and core.getKey then
        local names = {
            "ReloadWeapon",
            "Reload Weapon",
            "Reload"
        }
        for i = 1, #names do
            local ok, value = pcall(core.getKey, core, names[i])
            if ok and tonumber(value) and tonumber(value) > 0 then
                return tonumber(value)
            end
        end
    end
    return DEFAULT_RELOAD_KEY
end

local function isReloadKeyEvent(key)
    local k = tonumber(key)
    if not k then
        return false
    end
    if k == DEFAULT_RELOAD_KEY then
        return true
    end

    local mapped = getReloadKey()
    if mapped and mapped > 0 and k == mapped then
        return true
    end

    local core = getCore and getCore() or nil
    if core and core.isKey then
        local names = {
            "ReloadWeapon",
            "Reload Weapon",
            "Reload"
        }
        for i = 1, #names do
            local ok, isMatch = pcall(core.isKey, core, names[i], k)
            if ok and isMatch then
                return true
            end
        end
    end
    return false
end

local function isReloadKeyDown()
    local key = getReloadKey()
    if isKeyDown then
        local ok, value = pcall(isKeyDown, key)
        if ok then
            return value == true
        end
    end
    if key ~= DEFAULT_RELOAD_KEY and isKeyDown then
        local ok, value = pcall(isKeyDown, DEFAULT_RELOAD_KEY)
        if ok and value == true then
            return true
        end
    end
    if Keyboard and Keyboard.isKeyDown then
        local ok, value = pcall(Keyboard.isKeyDown, key)
        if ok then
            return value == true
        end
    end
    if key ~= DEFAULT_RELOAD_KEY and Keyboard and Keyboard.isKeyDown then
        local ok, value = pcall(Keyboard.isKeyDown, DEFAULT_RELOAD_KEY)
        if ok and value == true then
            return true
        end
    end
    return false
end

local function centerRadialMenu(menu, playerNum)
    local x = getPlayerScreenLeft(playerNum)
    local y = getPlayerScreenTop(playerNum)
    local w = getPlayerScreenWidth(playerNum)
    local h = getPlayerScreenHeight(playerNum)
    x = x + w / 2
    y = y + h / 2
    menu:setX(x - menu:getWidth() / 2)
    menu:setY(y - menu:getHeight() / 2)
end

local function normalizeSelectedAmmoType(ammoType)
    local normalized = normalizeFullType(ammoType)
    if not normalized then
        return nil
    end

    if normalized:sub(-6) == "_floor" then
        local base = normalized:sub(1, -7)
        if getAmmoProfile(base) then
            return base
        end
    end
    if normalized:sub(-4) == "_fly" then
        local base = normalized:sub(1, -5)
        if getAmmoProfile(base) then
            return base
        end
    end
    return normalized
end

local function ammoTypeMatchesSelection(ammoType, selectedAmmoType)
    local ammoNormalized = normalizeFullType(ammoType)
    local selected = normalizeSelectedAmmoType(selectedAmmoType)
    if not (ammoNormalized and selected) then
        return false
    end
    if ammoNormalized == selected then
        return true
    end

    local selectedProfile = getAmmoProfile(selected)
    local selectedFloor = selectedProfile and normalizeFullType(selectedProfile.floorItemType) or nil
    if selectedFloor and ammoNormalized == selectedFloor then
        return true
    end

    return normalizeSelectedAmmoType(ammoNormalized) == selected
end

local function getSelectedAmmoType(weapon, profile)
    local md = weapon and weapon.getModData and weapon:getModData() or nil
    local selected = md and md[MODDATA_SELECTED_AMMO] or nil
    selected = normalizeSelectedAmmoType(selected)
    if selected then
        return selected
    end
    return normalizeSelectedAmmoType(profile and profile.defaultAmmoType)
end

local function setSelectedAmmoType(weapon, ammoType)
    local md = weapon and weapon.getModData and weapon:getModData() or nil
    local selected = normalizeSelectedAmmoType(ammoType)
    if not (md and selected) then
        return false
    end
    md[MODDATA_SELECTED_AMMO] = selected
    if weapon and weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
    return true
end

runtime.getSelectedAmmoType = function(weapon)
    local profile = getWeaponProfile(weapon)
    return getSelectedAmmoType(weapon, profile)
end

runtime.setSelectedAmmoType = function(weapon, ammoType)
    return setSelectedAmmoType(weapon, ammoType)
end

local function buildAmmoPriorityForSelection(profile, selectedAmmoType)
    local src = (profile and profile.ammoPriority) or {}
    local selected = normalizeSelectedAmmoType(selectedAmmoType)
    if not selected then
        return src
    end

    local dst = {}
    local seen = {}
    for i = 1, #src do
        local fullType = normalizeFullType(src[i])
        if fullType and ammoTypeMatchesSelection(fullType, selected) and not seen[fullType] then
            seen[fullType] = true
            dst[#dst + 1] = fullType
        end
    end
    for i = 1, #src do
        local fullType = normalizeFullType(src[i])
        if fullType and not seen[fullType] then
            seen[fullType] = true
            dst[#dst + 1] = fullType
        end
    end
    return dst
end

local function collectSelectableAmmoTypes(profile)
    local result = {}
    local seen = {}
    local ammoPriority = (profile and profile.ammoPriority) or {}

    for i = 1, #ammoPriority do
        local selectedType = normalizeSelectedAmmoType(ammoPriority[i])
        if selectedType and not seen[selectedType] then
            seen[selectedType] = true
            result[#result + 1] = selectedType
        end
    end
    return result
end

local function resolveAmmoTexture(ammoType)
    local fullType = normalizeSelectedAmmoType(ammoType)
    if not (fullType and instanceItem) then
        return nil
    end
    local item = instanceItem(fullType)
    if item and item.getTexture then
        return item:getTexture()
    end
    return nil
end

local function buildAmmoSliceLabel(ammoType, isSelected, isLoaded)
    local label = shortTypeName(ammoType) or tostring(ammoType)
    if isLoaded then
        label = label .. "\n" .. ggsText("IGUI_GGS_AmmoLoadedSuffix")
    elseif isSelected then
        label = label .. "\n" .. ggsText("IGUI_GGS_AmmoSelectedSuffix")
    end
    return label
end

local function openArcheryAmmoRadial(playerObj, weapon, profile)
    if not (playerObj and weapon and profile and getPlayerRadialMenu) then
        return false
    end

    local playerNum = playerObj:getPlayerNum()
    local menu = getPlayerRadialMenu(playerNum)
    if not menu then
        return false
    end

    local ammoTypes = collectSelectableAmmoTypes(profile)
    if #ammoTypes == 0 then
        return false
    end

    if menu.isReallyVisible and menu:isReallyVisible() then
        menu:removeFromUIManager()
    end

    local selected = getSelectedAmmoType(weapon, profile)
    local loaded = normalizeSelectedAmmoType(getLoadedAmmoType(weapon, profile))

    menu:clear()
    for i = 1, #ammoTypes do
        local ammoType = ammoTypes[i]
        local isSelected = (selected == ammoType)
        local isLoaded = (loaded == ammoType)
        local label = buildAmmoSliceLabel(ammoType, isSelected, isLoaded)
        local icon = resolveAmmoTexture(ammoType)
        menu:addSlice(label, icon, function()
            setSelectedAmmoType(weapon, ammoType)
            syncWeaponVisual(playerObj, weapon, profile)
            menu:removeFromUIManager()
        end)
    end

    centerRadialMenu(menu, playerNum)
    menu:addToUIManager()
    return true
end

local function clearReloadHoldState()
    reloadHoldState.pressedMs = nil
    reloadHoldState.consumedByRadial = false
    reloadHoldState.pendingReload = false
    reloadHoldState.playerNum = 0
end

local function beginReloadHold(playerObj)
    local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
    reloadHoldState.pressedMs = nowMs()
    reloadHoldState.consumedByRadial = false
    reloadHoldState.pendingReload = true
    reloadHoldState.playerNum = playerNum
end

local function processReloadHoldState()
    if not reloadHoldState.pendingReload then
        return
    end

    local playerObj = nil
    if getSpecificPlayer then
        playerObj = getSpecificPlayer(reloadHoldState.playerNum or 0)
    end
    if not playerObj and getPlayer then
        playerObj = getPlayer()
    end
    if not playerObj then
        clearReloadHoldState()
        return
    end

    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    local profile = getWeaponProfile(weapon)
    local keyDown = isReloadKeyDown()

    if profile and keyDown and not reloadHoldState.consumedByRadial and reloadHoldState.pressedMs then
        local elapsed = nowMs() - reloadHoldState.pressedMs
        if elapsed >= RELOAD_HOLD_MENU_DELAY_MS then
            if openArcheryAmmoRadial(playerObj, weapon, profile) then
                reloadHoldState.consumedByRadial = true
            end
        end
    end

    if keyDown then
        return
    end

    local consumedByRadial = reloadHoldState.consumedByRadial
    clearReloadHoldState()

    if consumedByRadial then
        return
    end

    if profile then
        requestArcheryReload(playerObj, weapon)
    end
end

local function onReloadKeyStartPressed(key)
    if not isReloadKeyEvent(key) then
        return
    end
    if reloadHoldState.pendingReload then
        return
    end

    local playerObj = getPlayer and getPlayer() or nil
    local weapon = playerObj and playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    local profile = getWeaponProfile(weapon)
    if not profile then
        return
    end

    beginReloadHold(playerObj)
end

local function onReloadKeyKeepPressed(key)
    if not isReloadKeyEvent(key) then
        return
    end
    if not reloadHoldState.pendingReload then
        return
    end
    if reloadHoldState.consumedByRadial then
        return
    end

    local playerObj = getPlayer and getPlayer() or nil
    local weapon = playerObj and playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    local profile = getWeaponProfile(weapon)
    if not (playerObj and weapon and profile) then
        return
    end

    local elapsed = nowMs() - (reloadHoldState.pressedMs or 0)
    if elapsed < RELOAD_HOLD_MENU_DELAY_MS then
        return
    end

    if openArcheryAmmoRadial(playerObj, weapon, profile) then
        reloadHoldState.consumedByRadial = true
    end
end

getLoadedAmmoType = function(weapon, profile)
    if not weapon then
        return nil
    end
    if weapon.getCurrentAmmoCount and weapon:getCurrentAmmoCount() <= 0 then
        return nil
    end
    local md = weapon.getModData and weapon:getModData() or nil
    local loaded = md and md.ggsLoadedAmmoType or nil
    if loaded then
        return normalizeSelectedAmmoType(loaded)
    end
    if profile and profile.defaultAmmoType then
        return normalizeSelectedAmmoType(profile.defaultAmmoType)
    end
    return nil
end

runtime.getLoadedAmmoType = function(weapon)
    local profile = getWeaponProfile(weapon)
    return getLoadedAmmoType(weapon, profile)
end

local function getVisualPartSlot(profile)
    if profile and profile.visualPartSlot and tostring(profile.visualPartSlot) ~= "" then
        return tostring(profile.visualPartSlot)
    end
    return "AMMO"
end

local function getWeaponPartBySlot(weapon, slot)
    if not (weapon and weapon.getWeaponPart and slot) then
        return nil
    end
    local part = weapon:getWeaponPart(slot)
    if part then
        return part
    end
    if slot == "AMMO" then
        return weapon:getWeaponPart("Ammo")
    end
    if slot == "Ammo" then
        return weapon:getWeaponPart("AMMO")
    end
    return nil
end

local function removeVisualPart(weapon, profile)
    if not (weapon and weapon.detachWeaponPart) then
        return false
    end
    local slot = getVisualPartSlot(profile)
    local part = getWeaponPartBySlot(weapon, slot)
    if part then
        pcall(weapon.detachWeaponPart, weapon, part)
        return true
    end
    return false
end

local function installVisualPartForAmmo(weapon, ammoType, profile)
    if not (weapon and weapon.attachWeaponPart and ammoType) then
        return false
    end
    local ammoProfile = getAmmoProfile(ammoType)
    local partType = ammoProfile and ammoProfile.weaponPart or nil
    partType = normalizeFullType(partType)
    if not partType then
        return false
    end

    local slot = getVisualPartSlot(profile)
    local existing = getWeaponPartBySlot(weapon, slot)
    if existing and existing.getFullType then
        local okType, existingType = pcall(existing.getFullType, existing)
        if okType and normalizeFullType(existingType) == partType then
            return false
        end
    end

    if existing then
        pcall(weapon.detachWeaponPart, weapon, existing)
    end

    local partItem = instanceItem and instanceItem(partType) or nil
    if not partItem then
        return false
    end

    local ok = pcall(weapon.attachWeaponPart, weapon, partItem)
    return ok and true or false
end

local function setWeaponSpriteIfNeeded(playerObj, weapon, spriteName)
    if not (weapon and spriteName and weapon.setWeaponSprite) then
        return false
    end
    local current = weapon.getWeaponSprite and weapon:getWeaponSprite() or nil
    if current == spriteName then
        return false
    end
    pcall(weapon.setWeaponSprite, weapon, spriteName)
    if playerObj and playerObj.resetEquippedHandsModels then
        pcall(playerObj.resetEquippedHandsModels, playerObj)
    end
    return true
end

syncWeaponVisual = function(playerObj, weapon, profile)
    if not (weapon and profile) then
        return false
    end

    local changed = false
    local md = weapon.getModData and weapon:getModData() or nil
    local isLoaded = weapon.getCurrentAmmoCount and (weapon:getCurrentAmmoCount() > 0) or false
    local loadedAmmoType = getLoadedAmmoType(weapon, profile)

    if isLoaded and loadedAmmoType then
        if installVisualPartForAmmo(weapon, loadedAmmoType, profile) then
            changed = true
        end
    else
        if removeVisualPart(weapon, profile) then
            changed = true
        end
    end

    if profile.class == "crossbow" then
        local cocked = md and md.ggsCrossbowCocked or false
        local useReady = isLoaded or cocked
        local desired = useReady and profile.readyWeaponSprite or profile.baseWeaponSprite
        if desired and setWeaponSpriteIfNeeded(playerObj, weapon, desired) then
            changed = true
        end
    end

    if changed then
        syncWeaponNet(playerObj, weapon)
    end
    return changed
end

runtime.syncWeaponVisual = syncWeaponVisual

local function findFirstAmmoItem(playerObj, ammoPriority)
    if not (playerObj and playerObj.getInventory and ammoPriority) then
        return nil, nil
    end
    local inventory = playerObj:getInventory()
    if not inventory then
        return nil, nil
    end

    for i = 1, #ammoPriority do
        local fullType = normalizeFullType(ammoPriority[i])
        if fullType then
            local item = inventory:getFirstTypeRecurse(fullType)
            if item then
                return item, fullType
            end
        end
    end
    return nil, nil
end

local function consumeAmmoItem(playerObj, ammoFullType)
    if not (playerObj and ammoFullType and playerObj.getInventory) then
        return false
    end

    local inventory = playerObj:getInventory()
    if not inventory then
        return false
    end

    local item = inventory:getFirstTypeRecurse(ammoFullType)
    if not item then
        return false
    end

    local container = item.getContainer and item:getContainer() or nil
    if container and container.Remove then
        container:Remove(item)
        if sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, container, item)
        end
    else
        inventory:Remove(item)
        if sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, inventory, item)
        end
    end
    return true
end

local function clearReloadAnimVars(character)
    if not character then
        return
    end
    if character.clearVariable then
        pcall(character.clearVariable, character, "isLoading")
        pcall(character.clearVariable, character, "WeaponReloadType")
    end
end

local function getArcheryReloadAnimType(weapon)
    if not weapon then
        return nil
    end

    local scriptItem = weapon.getScriptItem and weapon:getScriptItem() or nil
    if scriptItem and scriptItem.getProperty then
        local ok, value = pcall(scriptItem.getProperty, scriptItem, "WeaponReloadType")
        if ok and value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end

    local profile = getWeaponProfile(weapon)
    if profile and profile.class == "crossbow" then
        return "doublebarrelcondor"
    end
    return "REX5"
end

local function applyReloadAnimVars(action, weapon)
    if not (action and weapon) then
        return
    end
    if action.setAnimVariable then
        local reloadAnimType = getArcheryReloadAnimType(weapon)
        if reloadAnimType then
            action:setAnimVariable("WeaponReloadType", reloadAnimType)
        end
        action:setAnimVariable("isLoading", true)
    end
    if action.setActionAnim and CharacterActionAnims and CharacterActionAnims.Reload then
        action:setActionAnim(CharacterActionAnims.Reload)
    end
    if action.character and action.character.reportEvent then
        pcall(action.character.reportEvent, action.character, "EventReloading")
    end
    if action.setOverrideHandModels then
        action:setOverrideHandModels(weapon, nil)
    end
end

local ISGGSArcheryReloadAction = ISBaseTimedAction:derive("ISGGSArcheryReloadAction")

function ISGGSArcheryReloadAction:isValid()
    if not (self.character and self.weapon) then
        return false
    end
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISGGSArcheryReloadAction:start()
    applyReloadAnimVars(self, self.weapon)
    if self.weapon and self.weapon.setJobType then
        self.weapon:setJobType(getText("IGUI_JobType_LoadBulletsIntoFirearm"))
        self.weapon:setJobDelta(0.0)
    end
end

function ISGGSArcheryReloadAction:update()
    if self.weapon and self.weapon.setJobDelta and self.maxTime and self.maxTime > 0 then
        -- B42 timed actions may not expose getTimeLeft(); use job delta when available.
        local delta = 0.0
        if self.getJobDelta then
            local ok, value = pcall(self.getJobDelta, self)
            if ok and tonumber(value) then
                delta = tonumber(value)
            end
        end
        self.weapon:setJobDelta(math.max(0.0, math.min(1.0, delta)))
    end
end

function ISGGSArcheryReloadAction:stop()
    clearReloadAnimVars(self.character)
    if self.weapon and self.weapon.setJobDelta then
        self.weapon:setJobDelta(0.0)
    end
    ISBaseTimedAction.stop(self)
end

function ISGGSArcheryReloadAction:perform()
    local weapon = self.weapon
    local character = self.character
    if weapon and character then
        local md = weapon.getModData and weapon:getModData() or nil
        if md then
            if self.mode == "cock" then
                md.ggsCrossbowCocked = true
            elseif self.mode == "load" and self.ammoType then
                if consumeAmmoItem(character, self.ammoType) then
                    if weapon.setCurrentAmmoCount then
                        pcall(weapon.setCurrentAmmoCount, weapon, 1)
                    end
                    md.ggsLoadedAmmoType = normalizeSelectedAmmoType(self.ammoType) or self.ammoType
                    if self.profile and self.profile.requiresCock then
                        md.ggsCrossbowCocked = true
                    end
                end
            end
        end
        syncWeaponVisual(character, weapon, self.profile)
    end
    clearReloadAnimVars(self.character)
    if self.weapon and self.weapon.setJobDelta then
        self.weapon:setJobDelta(0.0)
    end
    ISBaseTimedAction.perform(self)
end

function ISGGSArcheryReloadAction:new(character, weapon, profile, mode, ammoType)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = true
    o.weapon = weapon
    o.profile = profile
    o.mode = mode
    o.ammoType = ammoType
    o.useProgressBar = false
    local duration = 30
    if mode == "cock" then
        duration = tonumber(profile and profile.cockDuration) or 30
    elseif mode == "load" then
        duration = tonumber(profile and profile.loadDuration) or tonumber(profile and profile.reloadDuration) or 30
    end
    o.maxTime = math.max(1, math.floor(duration))
    return o
end

requestArcheryReload = function(playerObj, weapon)
    local profile = getWeaponProfile(weapon)
    if not profile then
        return false
    end

    if not (playerObj and weapon and ISTimedActionQueue) then
        return true
    end

    local md = weapon.getModData and weapon:getModData() or nil
    local isLoaded = weapon.getCurrentAmmoCount and (weapon:getCurrentAmmoCount() > 0) or false
    if isLoaded then
        syncWeaponVisual(playerObj, weapon, profile)
        return true
    end

    if profile.requiresCock and md and not md.ggsCrossbowCocked then
        ISTimedActionQueue.add(ISGGSArcheryReloadAction:new(playerObj, weapon, profile, "cock", nil))
        return true
    end

    local selectedAmmoType = getSelectedAmmoType(weapon, profile)
    local prioritizedAmmo = buildAmmoPriorityForSelection(profile, selectedAmmoType)
    local _, ammoFullType = findFirstAmmoItem(playerObj, prioritizedAmmo)
    if not ammoFullType then
        syncWeaponVisual(playerObj, weapon, profile)
        return true
    end

    ISTimedActionQueue.add(ISGGSArcheryReloadAction:new(playerObj, weapon, profile, "load", ammoFullType))
    return true
end

local reloadPatched = false
local originalBeginAutomaticReload = nil

local function patchAutomaticReload()
    if reloadPatched then
        return
    end
    if not ISReloadWeaponAction then
        pcall(require, "TimedActions/ISReloadWeaponAction")
    end
    if not (ISReloadWeaponAction and ISReloadWeaponAction.BeginAutomaticReload) then
        return
    end

    originalBeginAutomaticReload = ISReloadWeaponAction.BeginAutomaticReload
    ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)
        local profile = getWeaponProfile(gun)
        if profile then
            local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or 0
            if reloadHoldState.pendingReload and reloadHoldState.playerNum == playerNum then
                return true
            end

            beginReloadHold(playerObj)
            return true
        end
        return originalBeginAutomaticReload(playerObj, gun)
    end

    reloadPatched = true
end

local function installReloadKeyHooks()
    if reloadKeyHooksInstalled then
        return
    end
    if not Events then
        return
    end
    if Events.OnKeyStartPressed and Events.OnKeyStartPressed.Add then
        Events.OnKeyStartPressed.Add(onReloadKeyStartPressed)
    end
    if Events.OnKeyPressed and Events.OnKeyPressed.Add then
        Events.OnKeyPressed.Add(onReloadKeyStartPressed)
    end
    if Events.OnKeyKeepPressed and Events.OnKeyKeepPressed.Add then
        Events.OnKeyKeepPressed.Add(onReloadKeyKeepPressed)
    end
    reloadKeyHooksInstalled = true
end

runtime.onProjectileFired = function(playerObj, weapon, firedAmmoType)
    local profile = getWeaponProfile(weapon)
    if not profile then
        return
    end

    local md = weapon and weapon.getModData and weapon:getModData() or nil
    if md then
        md.ggsLoadedAmmoType = nil
        if profile.requiresCock then
            md.ggsCrossbowCocked = false
        end
    end

    if weapon and weapon.getCurrentAmmoCount and weapon.setCurrentAmmoCount then
        local current = tonumber(weapon:getCurrentAmmoCount()) or 0
        if current > 0 then
            pcall(weapon.setCurrentAmmoCount, weapon, math.max(0, current - 1))
        end
    end

    syncWeaponVisual(playerObj, weapon, profile)
    syncWeaponNet(playerObj, weapon)
end

local function onPlayerUpdate(playerObj)
    if not (playerObj and playerObj.isLocalPlayer and playerObj:isLocalPlayer()) then
        return
    end
    local weapon = playerObj:getPrimaryHandItem()
    local profile = getWeaponProfile(weapon)
    if profile then
        syncWeaponVisual(playerObj, weapon, profile)
    end
end

patchAutomaticReload()
installReloadKeyHooks()

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(patchAutomaticReload)
    Events.OnGameStart.Add(installReloadKeyHooks)
end

if Events and Events.OnPlayerUpdate and Events.OnPlayerUpdate.Add then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end

if Events and Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(processReloadHoldState)
end
