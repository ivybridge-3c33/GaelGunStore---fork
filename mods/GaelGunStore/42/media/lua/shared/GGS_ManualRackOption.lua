require "TimedActions/ISReloadWeaponAction"
pcall(require, "TimedActions/ISTimedActionQueue")
pcall(require, "TimedActions/ISRackFirearm")

local function sandboxBool(section, key, defaultValue)
    local root = SandboxVars
    local value = root and root[section] and root[section][key] or nil
    if value == nil then
        return defaultValue
    end
    local t = type(value)
    if t == "boolean" then
        return value
    end
    if t == "number" then
        return value ~= 0
    end
    if t == "string" then
        local n = string.lower(value)
        return n == "true" or n == "1" or n == "yes" or n == "on"
    end
    return defaultValue
end

local function isManualRackEnabled()
    return sandboxBool("GGSGS", "ManualRack", false)
end

local function isRackAction(action)
    if not action then
        return false
    end
    if action.Type == "ISRackFirearm" then
        return true
    end
    return ISRackFirearm and getmetatable(action) == ISRackFirearm
end

local function patchReloadAction()
    if not ISReloadWeaponAction or ISReloadWeaponAction.__ggsManualRackPatched then
        return
    end
    ISReloadWeaponAction.__ggsManualRackPatched = true

    local originalCanRack = ISReloadWeaponAction.canRack
    ISReloadWeaponAction.canRack = function(weapon, ...)
        if isManualRackEnabled() and weapon and weapon.isRanged and weapon:isRanged() then
            return true
        end
        if originalCanRack then
            return originalCanRack(weapon, ...)
        end
        return false
    end

    local originalAttackFinished = ISReloadWeaponAction.OnPlayerAttackFinished
    local wrappedAttackFinished = function(playerObj, weapon)
        if isManualRackEnabled() then
            return
        end
        if originalAttackFinished then
            return originalAttackFinished(playerObj, weapon)
        end
    end
    ISReloadWeaponAction.OnPlayerAttackFinished = wrappedAttackFinished

    if Events and Events.OnPlayerAttackFinished then
        pcall(Events.OnPlayerAttackFinished.Remove, originalAttackFinished)
        pcall(Events.OnPlayerAttackFinished.Remove, wrappedAttackFinished)
        pcall(Events.OnPlayerAttackFinished.Add, wrappedAttackFinished)
    end
end

local function patchTimedActionQueue()
    if not ISTimedActionQueue or ISTimedActionQueue.__ggsManualRackPatched then
        return
    end
    ISTimedActionQueue.__ggsManualRackPatched = true

    local originalAddAfter = ISTimedActionQueue.addAfter
    ISTimedActionQueue.addAfter = function(previousAction, action, ...)
        if isManualRackEnabled() and isRackAction(action) then
            return
        end
        return originalAddAfter(previousAction, action, ...)
    end
end

local function applyManualRackPatches()
    if not ISReloadWeaponAction then
        pcall(require, "TimedActions/ISReloadWeaponAction")
    end
    if not ISTimedActionQueue then
        pcall(require, "TimedActions/ISTimedActionQueue")
    end
    if not ISRackFirearm then
        pcall(require, "TimedActions/ISRackFirearm")
    end
    patchReloadAction()
    patchTimedActionQueue()
end

applyManualRackPatches()
if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(applyManualRackPatches)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(applyManualRackPatches)
end
