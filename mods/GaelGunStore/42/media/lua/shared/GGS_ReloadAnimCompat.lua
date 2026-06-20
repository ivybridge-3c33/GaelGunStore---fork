require "TimedActions/ISReloadWeaponAction"
pcall(require, "TimedActions/ISRackFirearm")
pcall(require, "TimedActions/ISUnloadBulletsFromFirearm")

local FORCED_RELOAD_TYPES = {
    ["Base.M79"] = "m79reload",
    ["Base.RPG7"] = "rpgreload",
    ["Base.M202A1"] = "rpgreload",
    ["Base.DoubleBarrelShotgun"] = "doublebarrelizh58",
    ["Base.DoubleBarrelShotgunSawnoff"] = "doublebarrelizh58sawn",
}

local DOUBLE_BARREL_LIKE_TYPES = {
    ["doublebarrelshotgun"] = true,
    ["doublebarrelshotgunsawn"] = true,
    ["doublebarrelcondor"] = true,
    ["doublebarrelcondorsawn"] = true,
    ["doublebarrelizh58"] = true,
    ["doublebarrelizh58sawn"] = true,
    ["m79reload"] = true,
    ["rpgreload"] = true,
}

local VANILLA_RELOAD_TYPES = {
    ["shotgun"] = true,
    ["revolver"] = true,
    ["boltaction"] = true,
    ["boltactionnomag"] = true,
    ["handgun"] = true,
    ["doublebarrelshotgun"] = true,
    ["doublebarrelshotgunsawn"] = true,
}

local function compatLog(message)
    if log and DebugType and DebugType.Action then
        pcall(log, DebugType.Action, "[GGS ReloadCompat] " .. tostring(message))
    end
end

if not (isServer and isServer()) then
    local ok, err = pcall(require, "PartAbility/Stool/GrenadeLauncher_SetFunction")
    compatLog(string.format("GL click module require ok=%s err=%s", tostring(ok), tostring(err)))
end

local function normalizeString(value)
    if value == nil then
        return nil
    end
    local text = tostring(value)
    if text == "" or text == "nil" then
        return nil
    end
    return text
end

local function getWeaponFullType(weapon)
    if not (weapon and weapon.getFullType) then
        return nil
    end
    local ok, value = pcall(weapon.getFullType, weapon)
    if not ok then
        return nil
    end
    return normalizeString(value)
end

local function getScriptReloadType(weapon)
    if not weapon then
        return nil
    end

    local scriptItem = weapon.getScriptItem and weapon:getScriptItem() or nil
    if not (scriptItem and scriptItem.getProperty) then
        return nil
    end

    local ok, value = pcall(scriptItem.getProperty, scriptItem, "WeaponReloadType")
    if not ok then
        return nil
    end

    return normalizeString(value)
end

local function getWeaponReloadTypeString(weapon)
    if not (weapon and weapon.getWeaponReloadType) then
        return nil
    end

    local ok, value = pcall(weapon.getWeaponReloadType, weapon)
    if not ok then
        return nil
    end

    return normalizeString(value)
end

local function resolveReloadAnimType(weapon)
    local fullType = getWeaponFullType(weapon)
    if fullType and FORCED_RELOAD_TYPES[fullType] then
        return FORCED_RELOAD_TYPES[fullType]
    end

    local scriptReloadType = getScriptReloadType(weapon)
    if scriptReloadType then
        return scriptReloadType
    end

    return getWeaponReloadTypeString(weapon)
end

local function getWeaponLabel(weapon)
    return getWeaponFullType(weapon) or getWeaponReloadTypeString(weapon) or "unknown"
end

local function applyReloadTypeVariable(action, weapon)
    if not (action and action.setAnimVariable) then
        return nil
    end

    local reloadType = resolveReloadAnimType(weapon)
    if reloadType then
        action:setAnimVariable("WeaponReloadType", reloadType)
    end
    return reloadType
end

local function applyWeaponSpriteOverride(action, gun, parameter)
    if not (action and parameter and parameter ~= "") then
        return false
    end

    if parameter ~= "original" then
        if action.setOverrideHandModelsString then
            action:setOverrideHandModelsString(parameter, nil)
        else
            action:setOverrideHandModels(parameter, nil)
        end
        return true
    end

    if gun and action.setOverrideHandModels then
        action:setOverrideHandModels(gun, nil)
        return true
    end

    return false
end

local function getReloadServerBaseTime(reloadType)
    if reloadType == "shotgun" then
        return 833
    end
    if reloadType == "revolver" then
        return 950
    end
    if reloadType == "boltactionnomag" then
        return 590
    end
    if DOUBLE_BARREL_LIKE_TYPES[reloadType] then
        return 2500
    end
    return 1000
end

local function shouldForceReloadType(reloadType)
    return reloadType ~= nil and not VANILLA_RELOAD_TYPES[reloadType]
end

local function overridePendingReloadType(player, gun)
    if not player then
        return
    end

    local weapon = gun
    if not weapon and player.getPrimaryHandItem then
        weapon = player:getPrimaryHandItem()
    end
    if not weapon then
        return
    end

    local reloadType = resolveReloadAnimType(weapon)
    if not shouldForceReloadType(reloadType) then
        return
    end

    if player.setVariable then
        player:setVariable("WeaponReloadType", reloadType)
        compatLog(string.format("button override gun=%s type=%s", getWeaponLabel(weapon), tostring(reloadType)))
    end
end

local function patchReloadWeaponAction()
    if not ISReloadWeaponAction or ISReloadWeaponAction.__ggsReloadAnimCompatPatched then
        return
    end

    ISReloadWeaponAction.__ggsReloadAnimCompatPatched = true

    ISReloadWeaponAction.start = function(self)
        if isClient() then
            self.gun = self.character:getInventory():getItemById(self.gun:getID())
        end

        self:setOverrideHandModels(self.gun, nil)
        local reloadType = applyReloadTypeVariable(self, self.gun)
        self:setAnimVariable("isLoading", true)
        self.ammoCountStart = self.gun:getCurrentAmmoCount()
        self.gun:setJobType(getText("IGUI_JobType_LoadBulletsIntoFirearm"))
        self.gun:setJobDelta(0.0)
        self:initVars()
        self:setActionAnim(CharacterActionAnims.Reload)
        self.character:reportEvent("EventReloading")
        self:ejectSpentRounds()
        compatLog(string.format("reload start gun=%s type=%s", getWeaponLabel(self.gun), tostring(reloadType)))

        if not self.bullets then
            self:forceStop()
        end
    end

    ISReloadWeaponAction.serverStart = function(self)
        self:initVars()
        if isServer() then
            self:ejectSpentRounds()
            if not self.bullets then
                self.netAction:forceComplete()
            end
        end

        local reloadType = resolveReloadAnimType(self.gun)
        local baseTime = getReloadServerBaseTime(reloadType)
        emulateAnimEvent(self.netAction, ISReloadWeaponAction.getReloadTime(self.character, baseTime), "loadFinished", nil)
    end

    local originalAnimEvent = ISReloadWeaponAction.animEvent
    ISReloadWeaponAction.animEvent = function(self, event, parameter)
        if event == "changeWeaponSprite" and applyWeaponSpriteOverride(self, self and self.gun, parameter) then
            return
        end
        return originalAnimEvent(self, event, parameter)
    end
end

local function patchRackFirearm()
    if not ISRackFirearm or ISRackFirearm.__ggsReloadAnimCompatPatched then
        return
    end

    ISRackFirearm.__ggsReloadAnimCompatPatched = true

    ISRackFirearm.start = function(self)
        if isClient() then
            self.gun = self.character:getInventory():getItemById(self.gun:getID())
        end

        if not ISReloadWeaponAction.canRack(self.gun) then
            self:forceComplete()
            return
        end

        local reloadType = applyReloadTypeVariable(self, self.gun)

        if self.gun:haveChamber() then
            self:setAnimVariable("isRacking", true)
        else
            self:setAnimVariable("isUnloading", true)
        end

        self:setAnimVariable("RackAiming", self.character:isAiming())
        if self.character:isAiming() then
            self.character:setAimingDelay(self.character:getAimingDelay() + self.gun:getAimingTime() * (0.15 - self.character:getPerkLevel(Perks.Reloading) * 0.01))
        end
        self:setOverrideHandModels(self.gun, nil)
        self:setActionAnim(CharacterActionAnims.Reload)
        self.character:reportEvent("EventReloading")
        self:ejectSpentRounds()
        self:initVars()
        compatLog(string.format("rack start gun=%s type=%s", getWeaponLabel(self.gun), tostring(reloadType)))
    end

    local originalAnimEvent = ISRackFirearm.animEvent
    ISRackFirearm.animEvent = function(self, event, parameter)
        if event == "changeWeaponSprite" and applyWeaponSpriteOverride(self, self and self.gun, parameter) then
            return
        end
        return originalAnimEvent(self, event, parameter)
    end
end

local function patchUnloadFirearm()
    if not ISUnloadBulletsFromFirearm or ISUnloadBulletsFromFirearm.__ggsReloadAnimCompatPatched then
        return
    end

    ISUnloadBulletsFromFirearm.__ggsReloadAnimCompatPatched = true

    ISUnloadBulletsFromFirearm.start = function(self)
        if isClient() then
            self.gun = self.character:getInventory():getItemById(self.gun:getID())
        end

        self.gun:setJobType(getText("IGUI_JobType_UnloadBulletsFromFirearm"))
        local reloadType = applyReloadTypeVariable(self, self.gun)
        self:setAnimVariable("isUnloading", true)
        self:setActionAnim(CharacterActionAnims.Reload)
        self.ammoCountStart = self.gun:getCurrentAmmoCount()
        self.gun:setJobDelta(0.0)
        self:setOverrideHandModels(self.gun, nil)
        self:initVars()
        compatLog(string.format("unload start gun=%s type=%s", getWeaponLabel(self.gun), tostring(reloadType)))
    end

    local originalAnimEvent = ISUnloadBulletsFromFirearm.animEvent
    ISUnloadBulletsFromFirearm.animEvent = function(self, event, parameter)
        if event == "changeWeaponSprite" and applyWeaponSpriteOverride(self, self and self.gun, parameter) then
            return
        end
        return originalAnimEvent(self, event, parameter)
    end
end

local function applyReloadAnimCompatibilityPatches()
    if not ISReloadWeaponAction then
        pcall(require, "TimedActions/ISReloadWeaponAction")
    end
    if not ISRackFirearm then
        pcall(require, "TimedActions/ISRackFirearm")
    end
    if not ISUnloadBulletsFromFirearm then
        pcall(require, "TimedActions/ISUnloadBulletsFromFirearm")
    end

    patchReloadWeaponAction()
    patchRackFirearm()
    patchUnloadFirearm()
end

local function registerReloadCompatEvents()
    if _G.__ggsReloadCompatEventsRegistered then
        return
    end

    _G.__ggsReloadCompatEventsRegistered = true

    if Events and Events.OnPressReloadButton and Events.OnPressReloadButton.Add then
        Events.OnPressReloadButton.Add(overridePendingReloadType)
    end
    if Events and Events.OnPressRackButton and Events.OnPressRackButton.Add then
        Events.OnPressRackButton.Add(overridePendingReloadType)
    end
end

applyReloadAnimCompatibilityPatches()
registerReloadCompatEvents()
compatLog("patches applied")

if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(applyReloadAnimCompatibilityPatches)
    Events.OnGameBoot.Add(registerReloadCompatEvents)
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(applyReloadAnimCompatibilityPatches)
    Events.OnGameStart.Add(registerReloadCompatEvents)
end
