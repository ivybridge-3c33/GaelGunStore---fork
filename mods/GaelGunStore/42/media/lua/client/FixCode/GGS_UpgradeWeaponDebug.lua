-- Wrapper that narrates vanilla's ISUpgradeWeapon / ISRemoveWeaponUpgrade.
--
-- This file existed before, solved one bug, and was deleted during cleanup -- a mistake,
-- because it is the only thing that shows the middle of a timed action. Current state:
-- [GGS SlotDBG] proves the double-click reaches the Canon slot with a real part in it, no
-- canRemovePart rejection is logged, and yet neither isValid-false nor complete ever
-- prints. So the action gets queued and then dies somewhere in between -- dropped by the
-- queue, cancelled, or thrown out of -- and none of those paths say anything on their own.
--
-- Pure passthrough: the original always decides, this only reports.

local function describe(action)
    if not action then
        return "nil"
    end
    local weapon, part, partType
    pcall(function()
        weapon = action.weapon and action.weapon.getFullType and action.weapon:getFullType()
    end)
    pcall(function()
        part = action.part and action.part.getFullType and action.part:getFullType() or action.part
    end)
    pcall(function()
        partType = action.partType
    end)
    return string.format("weapon=%s part=%s partType=%s", tostring(weapon), tostring(part),
        tostring(partType))
end

local function wrapAction(class, label)
    if not class or class.__ggsDebugWrapped then
        return
    end
    class.__ggsDebugWrapped = true

    local origIsValid = class.isValid
    if origIsValid then
        function class:isValid()
            local ok, result = pcall(origIsValid, self)
            if not ok then
                print(string.format("[GGS ActionDBG] %s isValid ERRORED: %s | %s", label,
                    tostring(result), describe(self)))
                return false
            end
            print(string.format("[GGS ActionDBG] %s isValid = %s | %s", label, tostring(result),
                describe(self)))
            return result
        end
    end

    local origStart = class.start
    if origStart then
        function class:start()
            print(string.format("[GGS ActionDBG] %s start | %s", label, describe(self)))
            local ok, err = pcall(origStart, self)
            if not ok then
                print(string.format("[GGS ActionDBG] %s start ERRORED: %s", label, tostring(err)))
            end
        end
    end

    local origUpdate = class.update
    if origUpdate then
        -- Not logged: runs every frame. Wrapped only so an error in it cannot pass silently.
        function class:update()
            local ok, err = pcall(origUpdate, self)
            if not ok then
                print(string.format("[GGS ActionDBG] %s update ERRORED: %s", label, tostring(err)))
            end
        end
    end

    local origPerform = class.perform
    if origPerform then
        function class:perform()
            print(string.format("[GGS ActionDBG] %s perform | %s", label, describe(self)))
            local ok, err = pcall(origPerform, self)
            if not ok then
                print(string.format("[GGS ActionDBG] %s perform ERRORED: %s", label, tostring(err)))
            end
        end
    end

    local origStop = class.stop
    if origStop then
        function class:stop()
            print(string.format("[GGS ActionDBG] %s stop (cancelled) | %s", label, describe(self)))
            pcall(origStop, self)
        end
    end

    local origWaitToStart = class.waitToStart
    if origWaitToStart then
        function class:waitToStart()
            local ok, result = pcall(origWaitToStart, self)
            if ok and result then
                print(string.format("[GGS ActionDBG] %s waitToStart = true (still waiting) | %s",
                    label, describe(self)))
            end
            return ok and result or false
        end
    end

    print("[GGS ActionDBG] wrapped " .. label)
end

local function wrapAll()
    wrapAction(ISUpgradeWeapon, "ISUpgradeWeapon")
    wrapAction(ISRemoveWeaponUpgrade, "ISRemoveWeaponUpgrade")
end

-- Both timings: the classes may not exist yet at file load, and OnGameStart runs after
-- vanilla's timed actions are defined.
wrapAll()
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(wrapAll)
end
