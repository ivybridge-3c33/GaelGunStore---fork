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
        -- Visibility on the removal path: the queue discards an action whose isValid is
        -- false without a word, and the ActionDBG wrapper that used to show this was
        -- removed during cleanup. One line per attempt.
        print("[GGS RemoveFix] isValid false: no real part in slot " .. tostring(self.partType))
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

-- All the removal work lives here, and BOTH perform and complete route into it.
--
-- Vanilla puts the detach in complete() and its perform() only does queue bookkeeping;
-- nothing in ISBaseTimedAction ever calls complete(), so the engine does -- and on MP it
-- does not. Traced with [GGS ActionDBG]: isValid returns true every frame, perform runs,
-- and complete never fires, so the action "succeeded" while the part stayed bolted on.
-- Offline the engine does call complete(), which is exactly why removal works there and
-- nowhere else. Doing the work in perform(), which demonstrably runs, fixes it; the flag
-- keeps it from happening twice where complete() is called as well.
local function ggsDoRemoval(self)
    if self.__ggsRemovalDone then
        return true
    end
    self.__ggsRemovalDone = true

    print("[GGS RemoveFix] removing slot=" .. tostring(self.partType) .. " from " ..
              tostring(self.weapon and self.weapon.getFullType and self.weapon:getFullType()))

    local part = self.weapon:getWeaponPart(self.partType)
    if not part then
        print("[GGS RemoveFix] no part in slot " .. tostring(self.partType) .. ", nothing to remove")
        return true
    end

    self.weapon:detachWeaponPart(self.character, part)

    -- detachWeaponPart clears the real part but leaves md.weaponpart holding the entry,
    -- and that mirror is what AWCWF_RenderPart draws from and what the workbench label
    -- falls back to. Without this the part landed in the inventory while the model kept
    -- wearing it and the slot kept showing its name.
    local md = self.weapon.getModData and self.weapon:getModData()
    if md and md.weaponpart and md.weaponpart[self.partType] ~= nil then
        md.weaponpart[self.partType] = nil
    end

    if md and self.weapon.transmitModData then
        pcall(self.weapon.transmitModData, self.weapon)
    end
    -- Tell the server too. Its copy still has the part attached, so the next sync -- which
    -- fires on equip and on workbench open -- would put the entry straight back.
    -- Log the send. Last round produced no server-side line at all -- neither the success
    -- nor the "nothing in slot" path -- so it is not yet established that the command is
    -- even leaving the client.
    local amClient = isClient and isClient() or false
    if amClient and sendClientCommand then
        local okId, weaponId = pcall(self.weapon.getID, self.weapon)
        -- Send the part's fullType as well as the slot name. Matching on the slot alone
        -- failed server-side -- "nothing in slot Canon (getAllWeaponParts had 4 parts)"
        -- while those 4 were exactly the set that came back, Canon included -- so the
        -- part is there and its getPartType() simply does not read back as "Canon" over
        -- there. fullType is unambiguous.
        local okFull, partFull = pcall(part.getFullType, part)
        local okSend, err = pcall(sendClientCommand, self.character, "GGS", "detachPart", {
            slot = tostring(self.partType),
            full = (okFull and partFull or nil),
            weaponId = (okId and weaponId or nil),
        })
        print("[GGS RemoveFix] sent detachPart slot=" .. tostring(self.partType) .. " weaponId=" ..
                  tostring(okId and weaponId or "nil") .. " ok=" .. tostring(okSend) ..
                  (okSend and "" or (" err=" .. tostring(err))))
    else
        print("[GGS RemoveFix] NOT sending detachPart: isClient=" .. tostring(amClient) ..
                  " sendClientCommand=" .. tostring(sendClientCommand ~= nil))
    end

    if syncHandWeaponFields then
        syncHandWeaponFields(self.character, self.weapon)
    end

    local added = self.character:getInventory():AddItem(part)
    if added then
        if self.partType == "Laser" then
            added:getModData().LaserBatteryReamin = self.weapon:getModData().LaserBatteryReamin
            self.weapon:getModData().LaserBatteryReamin = nil
        end
        if self.partType == "Light" then
            added:getModData().LightBatteryReamin = self.weapon:getModData().LightBatteryReamin
            self.weapon:getModData().LightBatteryReamin = nil
        end
        if sendAddItemToContainer then
            sendAddItemToContainer(self.character:getInventory(), added)
        end
    end

    -- AWCWF's own follow-up, with the nil guard their version lacks.
    local stillThere = self.weapon:getWeaponPart(self.partType)
    if stillThere and AWCWF_LaserAndGunLightSet and AWCWF_LaserAndGunLightSet[stillThere:getType()] then
        if self.weapon:getWeaponPart("Hide_Beam") then
            self.weapon:setWeaponPart("Hide_Beam", nil)
        end
    end

    return true
end

local old_ISRemoveWeaponUpgrade_perform = ISRemoveWeaponUpgrade.perform
function ISRemoveWeaponUpgrade:perform()
    ggsDoRemoval(self)
    old_ISRemoveWeaponUpgrade_perform(self)
end

-- Kept so any path that does call complete() still works, and so it stays idempotent
-- with perform() thanks to the flag.
function ISRemoveWeaponUpgrade:complete()
    return ggsDoRemoval(self)
end

function ISRemoveWeaponUpgrade:new(character, weapon, partType, maxTime)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon;
    o.partType = partType;
    o.maxTime = maxTime or o:getDuration();
    return o;
end
