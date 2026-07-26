-- Override of AWCWF's client/FixCode/ISRemoveWeaponUpgrade_FIX.lua (GaelGunStore fork).
--
-- Caught in the Lua debugger with part = nil at their line 20:
--     local part = self.weapon:getWeaponPart(self.partType)
--     if AWCWF_LaserAndGunLightSet[part:getType()] then      -- boom
-- and in console.txt as
--     [GGS ActionDBG] ISRemoveWeaponUpgrade perform ERRORED: java.lang.RuntimeException
--
-- Same shape as the ISUpgradeWeapon bug next door: isValid takes a different branch on
-- MP, and that branch returns before the check that actually matters. Offline the code
-- falls through to `return self.weapon:getWeaponPart(self.partType) ~= nil`, so trying
-- to remove from an empty slot is refused harmlessly. On MP it returns on the weapon
-- check alone, never asking whether a part is there at all -- so perform() runs against
-- an empty slot, reads nil, and dies. The thrown error killed the whole timed-action
-- queue with it, taking down any attach queued behind it.
--
-- Fix: require the part on MP too, and nil-guard perform/complete. Everything else is
-- AWCWF's code, kept as-is since overriding their file replaces all of it.

function ISRemoveWeaponUpgrade:isValid()
    -- Nothing in the slot means nothing to remove -- checked on every branch now.
    if not self.weapon or not self.weapon:getWeaponPart(self.partType) then
        return self.partType == "Hide_Beam"
    end
    if isClient() then
        return self.character:getInventory():containsID(self.weapon:getID()) or self.partType == "Hide_Beam" or
                   self.character:getPrimaryHandItem() == self.weapon or
                   self.character:getSecondaryHandItem() == self.weapon
    end
    if not self.character:getInventory():contains(self.weapon) then
        if self.partType == "Hide_Beam" then
            return true
        end
        if self.character:getPrimaryHandItem() ~= self.weapon and
            self.character:getSecondaryHandItem() ~= self.weapon then
            return false
        end
    end
    return true
end

local old_ISRemoveWeaponUpgrade_perform = ISRemoveWeaponUpgrade.perform
function ISRemoveWeaponUpgrade:perform()
    old_ISRemoveWeaponUpgrade_perform(self)
    local part = self.weapon:getWeaponPart(self.partType)
    -- The nil guard AWCWF is missing. Their version calls part:getType() straight away.
    if part and AWCWF_LaserAndGunLightSet and AWCWF_LaserAndGunLightSet[part:getType()] then
        if self.weapon:getWeaponPart("Hide_Beam") then
            self.weapon:setWeaponPart("Hide_Beam", nil)
        end
    end
end

function ISRemoveWeaponUpgrade:complete()
    local part = self.weapon:getWeaponPart(self.partType)
    if not part then
        -- Nothing attached: bail out instead of handing nil to detachWeaponPart/AddItem.
        print("[GGS RemoveFix] complete: no part in slot " .. tostring(self.partType) .. ", nothing to remove")
        return true
    end
    self.weapon:detachWeaponPart(self.character, part)
    syncHandWeaponFields(self.character, self.weapon)
    local added = self.character:getInventory():AddItem(part);
    if added then
        if self.partType == "Laser" then
            added:getModData().LaserBatteryReamin = self.weapon:getModData().LaserBatteryReamin
            self.weapon:getModData().LaserBatteryReamin = nil
        end
        if self.partType == "Light" then
            added:getModData().LightBatteryReamin = self.weapon:getModData().LightBatteryReamin
            self.weapon:getModData().LightBatteryReamin = nil
        end
        sendAddItemToContainer(self.character:getInventory(), added);
    end
    return true
end

function ISRemoveWeaponUpgrade:new(character, weapon, partType, maxTime)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon;
    o.partType = partType;
    o.maxTime = maxTime or o:getDuration();
    return o;
end
