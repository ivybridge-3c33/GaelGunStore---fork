-- Override of AWCWF's client/FixCode/ISUpgradeWeapon_FIX.lua (GaelGunStore B42 fork).
--
-- Attaching parts did nothing on a co-op server while working perfectly offline. Traced
-- with [GGS ClickDBG] / [GGS ActionDBG]: the click fires, every guard passes, the part
-- reaches the player's inventory, ISUpgradeWeapon:start runs -- then isValid() returns
-- false, the queue drops the action without a word, and attachWeaponPart is never
-- called. Nothing logs it, which is why this looked like a broken render/sync system for
-- so long. Slots read IGUI_NONE and suppressors stayed loud simply because no part was
-- ever attached.
--
-- The cause is the branch below. AWCWF's isValid does different things on MP and SP, and
-- the MP branch additionally demands that the WEAPON be found in the player's inventory
-- by id:
--     inv:containsID(part:getID()) and inv:containsID(weapon:getID())
-- while the offline branch only ever checks the part. But the weapon being upgraded is
-- the one in the player's hands, and an equipped item is not matched by that lookup, so
-- on MP the condition cannot pass -- for any part, on any weapon. Offline never
-- evaluates it at all. That asymmetry is the entire "works offline, dead online" split.
--
-- Fix: keep the intent -- you must really have the part, and the weapon must really be
-- yours -- but count the weapon as present when it is the item in hand. Everything below
-- isValid is AWCWF's code kept verbatim, since overriding their file replaces all of it.

-- containsID / contains only look at the container itself, not at bags inside it. The
-- part list in the workbench is built with collectWeaponPartsRecursive, which DOES
-- descend into sub-containers, so a suppressor sitting in a backpack is offered by the
-- UI and then rejected here -- observed as
--   [GGS UpgradeFix] isValid false: hasPart=false hasWeapon=true
-- with the part visibly listed and clickable. So also accept an item whose container
-- belongs to this character, which is the same reach the UI has.
-- Mirrors collectWeaponPartsRecursive in risky_inspect_selectAttachmentPane: descend
-- through nested containers and match on identity or item id. Depth-capped so a weird
-- container graph cannot spin.
local function ggsFindItemRecursive(container, target, depth)
    if not container or not target or depth > 6 then
        return false
    end
    local items = container.getItems and container:getItems()
    if not items then
        return false
    end
    local targetId = target.getID and target:getID() or nil
    for i = 0, items:size() - 1 do
        local candidate = items:get(i)
        if candidate then
            if candidate == target then
                return true
            end
            if targetId and candidate.getID and candidate:getID() == targetId then
                return true
            end
            if instanceof(candidate, "InventoryContainer") and candidate.getInventory then
                if ggsFindItemRecursive(candidate:getInventory(), target, depth + 1) then
                    return true
                end
            end
        end
    end
    return false
end

local function ggsInventoryHas(character, inventory, item)
    if not inventory or not item then
        return false
    end
    local ok, result = pcall(function()
        return inventory:containsID(item:getID())
    end)
    if ok and result then
        return true
    end
    ok, result = pcall(function()
        return inventory:contains(item)
    end)
    if ok and result == true then
        return true
    end
    ok, result = pcall(function()
        local container = item.getContainer and item:getContainer()
        if not container then
            return false
        end
        if container == inventory then
            return true
        end
        return container.isInCharacterInventory and container:isInCharacterInventory(character) or false
    end)
    if ok and result == true then
        return true
    end
    -- Last resort, and the one that actually matches the UI: walk the inventory the same
    -- way risky_inspect_selectAttachmentPane's collectWeaponPartsRecursive does, into
    -- every nested container. Observed with five different parts in a row --
    --   [GGS UpgradeFix] isValid false: hasPart=false hasWeapon=true
    -- while the pane listed each of them as owned (devSpawnMissing=nil), so the item was
    -- reachable to the UI and invisible to containsID/contains/isInCharacterInventory.
    -- If the list can offer it, this action has to accept it.
    ok, result = pcall(ggsFindItemRecursive, inventory, item, 0)
    return ok and result == true
end

-- A LIVE item of the given fullType anywhere in the inventory tree: one that still has a
-- container. The MP inventory resync replaces item objects wholesale -- container and ID
-- both die on the old reference -- so an action holding a pre-resync reference can only
-- recover by fullType. Proven necessary from the server save: the player blob held the
-- suppressor while every lookup on the clicked reference failed.
local function ggsFindLiveItemByFullType(container, fullType, depth)
    if not container or not fullType or depth > 6 then
        return nil
    end
    local items = container.getItems and container:getItems()
    if not items then
        return nil
    end
    for i = 0, items:size() - 1 do
        local candidate = items:get(i)
        if candidate then
            if candidate.getFullType and candidate:getFullType() == fullType and
                candidate.getContainer and candidate:getContainer() ~= nil then
                return candidate
            end
            if instanceof(candidate, "InventoryContainer") and candidate.getInventory then
                local found = ggsFindLiveItemByFullType(candidate:getInventory(), fullType, depth + 1)
                if found then
                    return found
                end
            end
        end
    end
    return nil
end

local function ggsCharacterHoldsWeapon(character, weapon)
    if not character or not weapon then
        return false
    end
    local ok, result = pcall(function()
        return character:getPrimaryHandItem() == weapon or character:getSecondaryHandItem() == weapon
    end)
    return ok and result == true
end

function ISUpgradeWeapon:isValid()

    if self.weapon:getWeaponPart(self.part:getPartType()) then
        return false
    end
    -- AWCWF exempts Hide_Beam from the inventory checks entirely; preserved.
    if self.part:getPartType() == "Hide_Beam" then
        return true
    end
    local inventory = self.character:getInventory()
    local hasPart = ggsInventoryHas(self.character, inventory, self.part)
    if not hasPart then
        -- Dead reference recovery, at the action level so every queue path heals (the
        -- workbench button has its own copy of this, vanilla's context menu does not).
        local okF, wantedFull = pcall(function() return self.part:getFullType() end)
        local live = okF and wantedFull and ggsFindLiveItemByFullType(inventory, wantedFull, 0) or nil
        if live then
            print("[GGS UpgradeFix] re-resolved dead part reference " .. tostring(wantedFull) ..
                      " to live item id=" .. tostring(live.getID and live:getID()))
            self.part = live
            hasPart = true
        end
    end
    local hasWeapon = ggsInventoryHas(self.character, inventory, self.weapon) or
                          ggsCharacterHoldsWeapon(self.character, self.weapon)
    if not hasPart or not hasWeapon then
        print(string.format("[GGS UpgradeFix] isValid false: hasPart=%s hasWeapon=%s part=%s weapon=%s",
            tostring(hasPart), tostring(hasWeapon),
            tostring(self.part and self.part.getFullType and self.part:getFullType()),
            tostring(self.weapon and self.weapon.getFullType and self.weapon:getFullType())))
        -- hasPart=false with the part visibly listed in the pane means it is one of the
        -- un-owned "potential attachments" the pane always shows (riskyShowPotentialAttachment
        -- is hardcoded true), not a lookup failure. Dump both stores anyway: on the runs where
        -- attach and remove both refuse, the state of the whole weapon is the thing worth
        -- having, and AWCWF_RenderPart draws from every mirror key -- so a part still on the
        -- model while every slot reads empty shows up here under whatever key it is filed as.
        local mirror = {}
        local md = self.weapon and self.weapon.getModData and self.weapon:getModData()
        if md and md.weaponpart then
            for k, v in pairs(md.weaponpart) do
                mirror[#mirror + 1] = tostring(k) .. "=" .. tostring(v)
            end
        end
        local real = {}
        local okAll, all = pcall(self.weapon.getAllWeaponParts, self.weapon)
        if okAll and all then
            for i = 0, all:size() - 1 do
                local p = all:get(i)
                if p then
                    real[#real + 1] = tostring(p.getPartType and p:getPartType()) .. "=" ..
                                          tostring(p.getFullType and p:getFullType())
                end
            end
        end
        print("[GGS PartDBG] attach refused real=[" .. table.concat(real, ", ") .. "] mirror=[" ..
                  table.concat(mirror, ", ") .. "]")
        -- WHERE the part item actually lives. hasPart=false fired for an item some UI
        -- could clearly still offer, and four store dumps later that is the one question
        -- no line answers. getContainer names the holder; a floor/world container or nil
        -- here is the whole explanation, since ggsInventoryHas only reaches containers
        -- under the character.
        local contDesc = "nil"
        local okC, cont = pcall(function() return self.part and self.part:getContainer() end)
        if okC and cont then
            local okT, cType = pcall(function() return cont:getType() end)
            local okP, parent = pcall(function()
                local p = cont.getParent and cont:getParent()
                if p and p.getFullType then
                    return p:getFullType()
                end
                local ch = cont.getCharacter and cont:getCharacter()
                return ch and tostring(ch.getUsername and ch:getUsername() or "character") or nil
            end)
            contDesc = tostring(okT and cType or "?") .. " parent=" .. tostring(okP and parent or "?")
        end
        local okW, hasWorld = pcall(function() return self.part and self.part:getWorldItem() ~= nil end)
        print("[GGS PartDBG] part location: container=" .. contDesc ..
                  " worldItem=" .. tostring(okW and hasWorld))
    end
    return hasPart and hasWeapon
end

-- All the attach work lives here, and BOTH perform and complete route into it.
--
-- Same third fault as the removal, on the attach side. Vanilla ISUpgradeWeapon puts the
-- whole job in complete() -- attachWeaponPart, syncHandWeaponFields, removing the part
-- from the inventory -- and its perform() only clears job deltas. Nothing in
-- ISBaseTimedAction calls complete(); the engine does, and on MP it does not. Session
-- 21:40 showed the result end to end: two clicks, guards passed, action ran, and
-- [GGS PartDBG] still read real=[Clip] mirror=[Clip] -- attachWeaponPart was never
-- reached, which is also why [GGS AttachFix] never printed. Offline complete() runs and
-- attaching works, same split as everything else in this family.
local function ggsDoUpgrade(self)
    if self.__ggsUpgradeDone then
        return true
    end
    self.__ggsUpgradeDone = true

    if not self.weapon or not self.part then
        print("[GGS UpgradeFix] doUpgrade: weapon or part is nil, skipping")
        return true
    end

    -- Capture identity before anything consumes the item.
    local okFull, partFull = pcall(self.part.getFullType, self.part)
    local okSlot, partSlot = pcall(self.part.getPartType, self.part)
    local okPid, partId = pcall(self.part.getID, self.part)

    print("[GGS UpgradeFix] attaching " .. tostring(okFull and partFull) .. " to slot " ..
              tostring(okSlot and partSlot) .. " of " ..
              tostring(self.weapon.getFullType and self.weapon:getFullType()))

    -- Vanilla complete()'s body. attachWeaponPart routes through AWCWF's wrapper, which
    -- writes the mirror, and through our setWeaponPart hook, which forces the real part
    -- (see AWCWF_AdditionalParts_GGS).
    self.weapon:attachWeaponPart(self.character, self.part)
    if syncHandWeaponFields then
        pcall(syncHandWeaponFields, self.character, self.weapon)
    end
    -- Remove from the container that actually holds it; vanilla assumes the root
    -- inventory, which silently no-ops for anything else.
    local container = (self.part.getContainer and self.part:getContainer()) or self.character:getInventory()
    if container then
        pcall(container.Remove, container, self.part)
        if sendRemoveItemFromContainer then
            pcall(sendRemoveItemFromContainer, container, self.part)
        end
    end
    if self.character.setSecondaryHandItem and self.character:getSecondaryHandItem() == self.part then
        self.character:setSecondaryHandItem(nil)
    end

    -- Tell the server. Its copy of the weapon never sees any of the client-side Lua, so
    -- without this the attach exists on one side only -- the exact mirror image of the
    -- loot-gun kit (server-only parts), and the source of every "two sides disagree"
    -- divergence this family produced. The server attaches its own real part and writes
    -- its own md.weaponpart entry (GGS_DevSpawnServer, attachPart).
    if isClient and isClient() and sendClientCommand then
        local okId, weaponId = pcall(self.weapon.getID, self.weapon)
        local okSend, err = pcall(sendClientCommand, self.character, "GGS", "attachPart", {
            weaponId = (okId and weaponId or nil),
            partId = (okPid and partId or nil),
            full = (okFull and partFull or nil),
            slot = (okSlot and partSlot or nil),
        })
        print("[GGS UpgradeFix] sent attachPart full=" .. tostring(okFull and partFull) .. " weaponId=" ..
                  tostring(okId and weaponId or "nil") .. " ok=" .. tostring(okSend) ..
                  (okSend and "" or (" err=" .. tostring(err))))
    end

    -- Verify both stores, loudly, in the same shape as the removal's exit line.
    local realNow = self.weapon:getWeaponPart(okSlot and partSlot or "?")
    local md = self.weapon.getModData and self.weapon:getModData()
    local mirrorNow = md and md.weaponpart and okSlot and md.weaponpart[partSlot] or nil
    print("[GGS UpgradeFix] done slot=" .. tostring(okSlot and partSlot) .. " real=" ..
              tostring(realNow and realNow.getFullType and realNow:getFullType() or realNow) ..
              " mirror=" .. tostring(mirrorNow))
    return true
end

local old_ISUpgradeWeapon_perform = ISUpgradeWeapon.perform
function ISUpgradeWeapon:perform()
    ggsDoUpgrade(self)
    old_ISUpgradeWeapon_perform(self)
    local partType = self.part:getPartType()
    if partType == "Laser" then
        local modData = self.part:getModData()
        if modData.LaserBatteryReamin then
            self.weapon:getModData().LaserBatteryReamin = modData.LaserBatteryReamin
        else
            self.weapon:getModData().LaserBatteryReamin = 100
        end
    end
    if partType == "Light" then
        local modData = self.part:getModData()
        if modData.LightBatteryReamin then
            self.weapon:getModData().LightBatteryReamin = modData.LightBatteryReamin
        else
            self.weapon:getModData().LightBatteryReamin = 100
        end
    end
end

-- Kept so any path that does call complete() still works; idempotent with perform()
-- thanks to the flag. Vanilla's complete() body is fully replaced by ggsDoUpgrade.
function ISUpgradeWeapon:complete()
    return ggsDoUpgrade(self)
end

function ISUpgradeWeapon:new(character, weapon, part, maxtime)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon;
    o.part = part;
    o.maxTime = maxtime or o:getDuration();

    return o;
end
