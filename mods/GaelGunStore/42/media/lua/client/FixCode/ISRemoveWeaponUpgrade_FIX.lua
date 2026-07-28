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

-- What slot does this mirror value's part really belong to? Resolved from the item
-- script, so it does not matter what key the entry was filed under.
local function ggsResolvePartType(fullType)
    if not fullType or fullType == "" then
        return nil
    end
    local full = tostring(fullType)
    if not full:find("%.") then
        full = "Base." .. full
    end
    local ok, resolved = pcall(instanceItem, full)
    if not ok or not resolved or not instanceof(resolved, "WeaponPart") then
        return nil
    end
    local ok2, partType = pcall(resolved.getPartType, resolved)
    return ok2 and partType or nil
end

-- Every mirror entry that claims this slot, with no real part behind it. Phantoms, and
-- they need removing just as much as a real part does -- more, since nothing else can
-- shift them. Guns kitted before the attach fix in AWCWF_AdditionalParts_GGS carry these:
-- the part draws on the character (the renderer reads the mirror) but no reader Java-side
-- can see it, and the old "no real part in slot" isValid refused to remove it forever.
--
-- Matched by KEY OR BY VALUE, not key alone. Proven necessary in game: a gun still
-- visibly wearing its suppressor answered "nothing in slot Canon (no real part, no mirror
-- entry)" -- both stores empty under the Canon key -- while AWCWF_RenderPart draws every
-- key of md.weaponpart, so the surviving entry is simply filed under some other key, where
-- every key-based clear misses it and the ghost outlives all of them. Resolving each
-- value's real PartType catches it wherever it sits.
local function ggsMirroredOnly(weapon, partType)
    if not weapon or weapon:getWeaponPart(partType) then
        return nil
    end
    local md = weapon.getModData and weapon:getModData()
    if not md or not md.weaponpart then
        return nil
    end
    local hits = nil
    for k, v in pairs(md.weaponpart) do
        if v and v ~= "" and (k == partType or ggsResolvePartType(v) == partType) then
            hits = hits or {}
            hits[k] = tostring(v)
        end
    end
    return hits
end

-- Both representations of the whole weapon, on one line.
--
-- Put it on the refusal paths, not behind a successful operation: the previous exit-state
-- dump lived at the end of ggsDoRemoval, so it only printed when removal already worked and
-- said nothing on the runs that mattered. AWCWF_RenderPart iterates EVERY key of
-- md.weaponpart, so a part still drawn while the slot being removed reads empty in both
-- stores means the entry is filed under a different key -- this is what names it.
local function ggsDumpPartState(weapon, label)
    if not weapon then
        return
    end
    local mirror = {}
    local md = weapon.getModData and weapon:getModData()
    if md and md.weaponpart then
        for k, v in pairs(md.weaponpart) do
            mirror[#mirror + 1] = tostring(k) .. "=" .. tostring(v)
        end
    end
    local real = {}
    local okAll, all = pcall(weapon.getAllWeaponParts, weapon)
    if okAll and all then
        for i = 0, all:size() - 1 do
            local p = all:get(i)
            if p then
                real[#real + 1] = tostring(p.getPartType and p:getPartType()) .. "=" ..
                                      tostring(p.getFullType and p:getFullType())
            end
        end
    end
    -- The weapon's own model names too. With all four part stores proven clean (client
    -- real, client mirror, character props, server real) while a suppressor still drew on
    -- the gun, the item's swapped weaponSprite/model is the only drawer left standing --
    -- and nothing was printing it.
    local okSprite, sprite = pcall(function() return weapon:getWeaponSprite() end)
    local okWorld, worldModel = pcall(function()
        local m = weapon.getWorldStaticModel and weapon:getWorldStaticModel()
        return m and tostring(m) or nil
    end)
    print("[GGS PartDBG] " .. tostring(label) .. " weapon=" ..
              tostring(weapon.getFullType and weapon:getFullType()) .. " real=[" ..
              table.concat(real, ", ") .. "] mirror=[" .. table.concat(mirror, ", ") ..
              "] sprite=" .. tostring(okSprite and sprite) ..
              " worldModel=" .. tostring(okWorld and worldModel))
end

function ISRemoveWeaponUpgrade:isValid()
    if not self.weapon then
        return false
    end
    if not self.weapon:getWeaponPart(self.partType) and not ggsMirroredOnly(self.weapon, self.partType) then
        -- Locally empty is NOT the same as empty on MP. The G17 saga proved it: every
        -- local store read clean (real=[Clip], mirror=[Clip], props clean) while the gun
        -- visibly wore a suppressor and something kept queueing Canon removals with a
        -- part our own workbench button never saw -- a real part the engine replicates
        -- back from the server in bursts, caught by whoever reads at the right moment.
        -- Refusing here is what kept the detach request from EVER reaching the server,
        -- so the divergence could never heal. Accept on MP and let ggsDoRemoval ask the
        -- side that actually holds the part.
        if not self.__ggsDumpedEmpty then
            self.__ggsDumpedEmpty = true
            ggsDumpPartState(self.weapon, "slot empty locally, slot=" .. tostring(self.partType))
        end
        if isClient and isClient() then
            return true
        end
        -- Offline there is no second side to ask; empty really is empty.
        print("[GGS RemoveFix] isValid false: nothing in slot " .. tostring(self.partType) ..
                  " (no real part, no mirror entry)")
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
        -- Phantom: mirror entries with no real part. Drop every entry claiming this slot,
        -- under whatever key it sits -- the mirror is what the renderer reads, so this is
        -- what actually takes the model off the character -- and ask the server to hand
        -- over its real copy if it has one. Deliberately not instanceItem() here, since a
        -- client-made item is a ghost the server never learns about, and that is its own
        -- family of bugs.
        local mirrorHits = ggsMirroredOnly(self.weapon, self.partType)
        if mirrorHits then
            local md = self.weapon:getModData()
            local okId, weaponId = pcall(self.weapon.getID, self.weapon)
            for k, full in pairs(mirrorHits) do
                print("[GGS RemoveFix] mirror-only entry " .. tostring(k) .. "=" .. full ..
                          " claims slot " .. tostring(self.partType) ..
                          ", clearing it and asking the server for the real one")
                md.weaponpart[k] = nil
                if isClient and isClient() and sendClientCommand then
                    pcall(sendClientCommand, self.character, "GGS", "detachPart", {
                        slot = tostring(k),
                        full = full,
                        weaponId = (okId and weaponId or nil),
                    })
                end
            end
            if self.weapon.transmitModData then
                pcall(self.weapon.transmitModData, self.weapon)
            end
            return true
        end
        -- Local stores empty, no mirror phantom either. On MP the server's copy can still
        -- hold a real part this client cannot see -- that is exactly the replication
        -- tug-of-war state -- so send the detach anyway. The server hands the part item
        -- back if it has one, clears its own mirror entry, and once its copy is clean the
        -- replication stops pushing the model back. Its reply line also finally shows us
        -- what that side actually holds ("detached ... server-side" or "no match; server
        -- sees [...]").
        if isClient and isClient() and sendClientCommand then
            local okId, weaponId = pcall(self.weapon.getID, self.weapon)
            local okSend = pcall(sendClientCommand, self.character, "GGS", "detachPart", {
                slot = tostring(self.partType),
                weaponId = (okId and weaponId or nil),
            })
            print("[GGS RemoveFix] local stores empty; asked the server to detach slot " ..
                      tostring(self.partType) .. " (sent=" .. tostring(okSend) .. ")")
            if self.character and self.character.resetModelNextFrame then
                pcall(self.character.resetModelNextFrame, self.character)
            end
            return true
        end
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
        -- And any entry for the same slot filed under a different key. That is the ghost:
        -- the renderer draws every mirror key, so an entry the key-based clears above miss
        -- keeps the part on the character's model forever, with both stores reading empty
        -- under the slot's own name.
        local strays = ggsMirroredOnly(self.weapon, self.partType)
        if strays then
            for k, v in pairs(strays) do
                print("[GGS RemoveFix] clearing stray mirror entry " .. tostring(k) .. "=" .. v)
                md.weaponpart[k] = nil
            end
        end
    end

    if md and self.weapon.transmitModData then
        pcall(self.weapon.transmitModData, self.weapon)
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

    -- Settle the attach debt instead of handing back, when there is one. A fallback
    -- attach ("Requesting part from the server") consumes NOTHING -- the player's item is
    -- in the invisible phase of the inventory oscillation at that moment, so neither side
    -- can find it -- and the part that ends up on the gun is a NEW engine-made object.
    -- Proven by the id census: original NST#53661400@55 survived the attach, the gun gave
    -- back NST#837542428@55, and the player ended up with both (the engine-made one a
    -- server-unknown ghost: unusable, undroppable). When the debt marker is present the
    -- original item still exists, so the correct hand-back is NO hand-back.
    -- The ledger lives in a local table (GGS_AttachDebts, keyed by weapon id), NOT in
    -- modData: the modData version evaporated the moment the server pushed its copy of
    -- the table, so removal handed the part back debt-free and the duplicate returned.
    local debtSettled = false
    local okWid, wid = pcall(self.weapon.getID, self.weapon)
    if okWid and wid and GGS_AttachDebts and GGS_AttachDebts[wid] and okFull and partFull and
        GGS_AttachDebts[wid][partFull] ~= nil then
        GGS_AttachDebts[wid][partFull] = nil
        debtSettled = true
        print("[GGS RemoveFix] attach debt settled: NOT handing this part back (the original " ..
                  tostring(partFull) .. " was never consumed and is still owned)")
    end

    -- Identity of the object leaving the gun and of the object landing in the bag: the
    -- "extra 100% part" investigation needs to know whether these are the same item, and
    -- what condition the gun-side object really carried.
    local okPC, partCond = pcall(function() return part:getCondition() end)
    print("[GGS RemoveFix] handing back part id=" .. tostring(part.getID and part:getID()) ..
              " cond=" .. tostring(okPC and partCond) .. (debtSettled and " -> SKIPPED (debt)" or ""))

    -- The hand-back has exactly ONE owner per mode. On MP the SERVER creates the returned
    -- item (in detachServerPart, from the condition and battery values sent below) and it
    -- syncs down like any loot pickup. The old way -- client AddItem + sendAddItemToContainer
    -- -- left a display echo next to the real item every removal: the server's broadcast of
    -- the add came back as a second, server-unknown twin in the panel (unusable,
    -- undroppable, cleared only by relog). Server truth stayed correct the whole time; the
    -- echo was pure UI, but the player cannot tell an echo from a dup, so the client-side
    -- add is gone. Single-player keeps the local AddItem: there is no other side.
    local amClient = isClient and isClient() or false
    local wantItem = (not stillOccupied) and (not debtSettled)
    local added = nil
    if wantItem and not amClient then
        added = self.character:getInventory():AddItem(part)
        if added then
            if self.partType == "Laser" then
                added:getModData().LaserBatteryReamin = self.weapon:getModData().LaserBatteryReamin
                self.weapon:getModData().LaserBatteryReamin = nil
            end
            if self.partType == "Light" then
                added:getModData().LightBatteryReamin = self.weapon:getModData().LightBatteryReamin
                self.weapon:getModData().LightBatteryReamin = nil
            end
        end
    end

    -- Battery state rides to the server with the command; the weapon-side entry is
    -- cleared here so it cannot be double-claimed.
    local batteryLaser, batteryLight = nil, nil
    if wantItem and amClient then
        local mdBat = self.weapon:getModData()
        if self.partType == "Laser" then
            batteryLaser = mdBat.LaserBatteryReamin
            mdBat.LaserBatteryReamin = nil
        end
        if self.partType == "Light" then
            batteryLight = mdBat.LightBatteryReamin
            mdBat.LightBatteryReamin = nil
        end
    end

    if amClient and sendClientCommand then
        local okId, weaponId = pcall(self.weapon.getID, self.weapon)
        local okSend, err = pcall(sendClientCommand, self.character, "GGS", "detachPart", {
            slot = tostring(self.partType),
            full = (okFull and partFull or nil),
            weaponId = (okId and weaponId or nil),
            -- wantItem asks the server to hand the item back (its own detached part when
            -- it has one, else a fresh instance at the sent condition). False when the
            -- attach debt already settled the books or the slot refused to empty.
            wantItem = wantItem,
            condition = (okPC and partCond or nil),
            batteryLaser = batteryLaser,
            batteryLight = batteryLight,
        })
        print("[GGS RemoveFix] sent detachPart slot=" .. tostring(self.partType) .. " weaponId=" ..
                  tostring(okId and weaponId or "nil") .. " wantItem=" .. tostring(wantItem) ..
                  " cond=" .. tostring(okPC and partCond) ..
                  " ok=" .. tostring(okSend) .. (okSend and "" or (" err=" .. tostring(err))))
    elseif not amClient then
        print("[GGS RemoveFix] SP hand-back added=" .. tostring(added ~= nil))
    else
        print("[GGS RemoveFix] NOT sending detachPart: sendClientCommand=" ..
                  tostring(sendClientCommand ~= nil))
    end

    -- Exit state, both representations, one line. AWCWF_RenderPart:186 builds the held
    -- weapon's models from md.weaponpart alone and runs on OnPlayerUpdate, so a part still
    -- drawn on the character after this can only mean a mirror entry survived -- and this
    -- says which key it survived under. Real vs mirror is the distinction that matters on
    -- every one of these bugs, so print both rather than guessing later.
    local mirrorLeft = {}
    if md and md.weaponpart then
        for k, v in pairs(md.weaponpart) do
            mirrorLeft[#mirrorLeft + 1] = tostring(k) .. "=" .. tostring(v)
        end
    end
    print("[GGS RemoveFix] done slot=" .. tostring(self.partType) .. " real=" ..
              tostring(self.weapon:getWeaponPart(self.partType)) .. " mirror=[" ..
              table.concat(mirrorLeft, ", ") .. "]")

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
