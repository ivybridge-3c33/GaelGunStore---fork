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

    -- Seed the modData mirror before asking AWCWF to detach.
    --
    -- This is the whole "fine solo, dead on a server" split, and it is not in our code:
    -- AWCWF's client/AWCWF_AdditionalParts.lua REPLACES HandWeapon.detachWeaponPart and
    -- never calls the Java original. Its entire body -- the setWeaponPart(slot, nil) that
    -- actually removes the part, the stat reversal, onDetach -- sits behind one gate:
    --     weaponpart:getFullType() == item:getModData().weaponpart[weaponpart:getPartType()]
    -- so the mirror has to already name this part or nothing happens at all, silently.
    --
    -- A part the player attached passes: the attach path writes the mirror. A part a loot
    -- gun was kitted with does not. GGSWeaponUpgrades' attachPart calls
    -- weapon:attachWeaponPart(nil, partItem) on the SERVER, and AWCWF's hook lives under
    -- client/, so it is not loaded there -- Java attaches a real part and no mirror entry
    -- is ever written. The gate then fails on the client for every one of those parts, the
    -- detach is skipped without a word, the part stays bolted on, and the AddItem below
    -- hands the player a duplicate. Offline the same server code runs inside the client's
    -- Lua state, so the hook DOES write the mirror and removal works -- which is exactly
    -- why this only ever showed up on a server.
    --
    -- Seeding rather than bypassing on purpose: it keeps AWCWF's stat reversal and
    -- onDetach, which is what the Java method they replaced would have done.
    local md = self.weapon.getModData and self.weapon:getModData()
    local okSlot, partSlot = pcall(part.getPartType, part)
    local okFull, partFull = pcall(part.getFullType, part)
    if md and okFull and partFull then
        md.weaponpart = md.weaponpart or {}
        -- The gate reads the part's own getPartType(); the UI hands us the slot string.
        -- They are normally the same, but seed both so a mismatch cannot reintroduce the
        -- silent no-op.
        if okSlot and partSlot and md.weaponpart[partSlot] ~= partFull then
            print("[GGS RemoveFix] seeding mirror " .. tostring(partSlot) .. "=" .. tostring(partFull) ..
                      " (was " .. tostring(md.weaponpart[partSlot]) .. ") so AWCWF's detach gate passes")
            md.weaponpart[partSlot] = partFull
        end
        if md.weaponpart[self.partType] ~= partFull then
            md.weaponpart[self.partType] = partFull
        end
    end

    self.weapon:detachWeaponPart(self.character, part)

    -- Verify, because AWCWF's detach reports nothing either way. If the real part is still
    -- in the slot the gate failed anyway; force it out through setWeaponPart, which routes
    -- into clearWeaponPart plus our own belt-and-braces removal in
    -- AWCWF_AdditionalParts_GGS. Loud on purpose: every round of "removal succeeded, part
    -- still there" came from nothing here checking.
    local leftover = self.weapon:getWeaponPart(self.partType)
    if leftover then
        print("[GGS RemoveFix] detachWeaponPart left slot " .. tostring(self.partType) ..
                  " occupied, forcing clear")
        pcall(self.weapon.setWeaponPart, self.weapon, self.partType, nil)
        if okSlot and partSlot and partSlot ~= self.partType then
            pcall(self.weapon.setWeaponPart, self.weapon, partSlot, nil)
        end
    end

    -- detachWeaponPart clears the real part but leaves md.weaponpart holding the entry,
    -- and that mirror is what AWCWF_RenderPart draws from and what the workbench label
    -- falls back to. Without this the part landed in the inventory while the model kept
    -- wearing it and the slot kept showing its name.
    if md and md.weaponpart then
        md.weaponpart[self.partType] = nil
        if okSlot and partSlot then
            md.weaponpart[partSlot] = nil
        end
    end

    if md and self.weapon.transmitModData then
        pcall(self.weapon.transmitModData, self.weapon)
    end
    -- Tell the server too, so its own copy of the weapon drops the part instead of holding
    -- a set the client no longer agrees with. Confirmed arriving: the client's send and the
    -- server's "command received: detachPart" both show up in the same tick.
    local amClient = isClient and isClient() or false
    if amClient and sendClientCommand then
        local okId, weaponId = pcall(self.weapon.getID, self.weapon)
        -- Send the part's fullType as well as the slot name. Matching on the slot alone
        -- failed server-side -- "nothing in slot Canon (getAllWeaponParts had 4 parts)"
        -- while those 4 were exactly the set that came back, Canon included -- so the
        -- part is there and its getPartType() simply does not read back as "Canon" over
        -- there. fullType is unambiguous.
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

    -- Only hand the part back once the slot is genuinely empty. While AWCWF's gate was
    -- failing this ran unconditionally, so every attempt on a loot gun gave the player a
    -- second copy of a part that was still attached. If the slot is somehow still occupied
    -- after the force-clear above, say so and hand nothing over rather than duplicating it.
    local stillOccupied = self.weapon:getWeaponPart(self.partType)
    if stillOccupied then
        print("[GGS RemoveFix] slot " .. tostring(self.partType) ..
                  " STILL occupied after forced clear, not handing the part over")
    end

    local added = not stillOccupied and self.character:getInventory():AddItem(part) or nil
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
