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
local function ggsFindLiveItemByFullType(container, fullType, depth, wantedCondition)
    if not container or not fullType or depth > 6 then
        return nil, nil
    end
    local items = container.getItems and container:getItems()
    if not items then
        return nil, nil
    end
    local fallback = nil
    for i = 0, items:size() - 1 do
        local candidate = items:get(i)
        if candidate then
            if candidate.getFullType and candidate:getFullType() == fullType and
                candidate.getContainer and candidate:getContainer() ~= nil then
                if wantedCondition == nil then
                    return candidate, candidate
                end
                local okC, cond = pcall(function() return candidate:getCondition() end)
                if okC and cond == wantedCondition then
                    return candidate, candidate
                end
                fallback = fallback or candidate
            end
            if instanceof(candidate, "InventoryContainer") and candidate.getInventory then
                local exact, fb = ggsFindLiveItemByFullType(candidate:getInventory(), fullType, depth + 1,
                    wantedCondition)
                if exact then
                    return exact, exact
                end
                fallback = fallback or fb
            end
        end
    end
    return nil, fallback
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
    -- Mirror-occupied counts too: after a server-side attach this client holds no real
    -- part, only the pushed md.weaponpart entry, and re-queuing an attach into that slot
    -- just loops the server request. Hide_Beam is exempt -- AWCWF toggles it through
    -- setWeaponPart every frame, so its mirror entry is transient by design.
    if self.part:getPartType() ~= "Hide_Beam" then
        local mdOcc = self.weapon.getModData and self.weapon:getModData()
        local mirrorOcc = mdOcc and mdOcc.weaponpart and mdOcc.weaponpart[self.part:getPartType()]
        if mirrorOcc and mirrorOcc ~= "" then
            return false
        end
    end
    -- AWCWF exempts Hide_Beam from the inventory checks entirely; preserved.
    if self.part:getPartType() == "Hide_Beam" then
        return true
    end
    local inventory = self.character:getInventory()
    local hasPart = ggsInventoryHas(self.character, inventory, self.part)
    if not hasPart then
        -- The part can be IN THE PLAYER'S HANDS: vanilla's context-menu flow
        -- (ISInventoryPaneContextMenu.onUpgradeWeapon) equips the part into a hand before
        -- queueing this action, and an in-hand / mid-transfer item has no container -- so
        -- every container walk above misses it. This was the whole "invisible phase":
        -- the census saw the item before the click and not after, because from the click
        -- onward it sat in the hand, and the fallback then attached for free (the mint).
        local okHand, inHand = pcall(function()
            return self.character:getSecondaryHandItem() == self.part or
                       self.character:getPrimaryHandItem() == self.part
        end)
        if okHand and inHand then
            print("[GGS UpgradeFix] part is in hand (vanilla equips it before attaching); accepting")
            hasPart = true
        end
    end
    if not hasPart then
        -- Dead reference recovery, at the action level so every queue path heals (the
        -- workbench button has its own copy of this, vanilla's context menu does not).
        local okF, wantedFull = pcall(function() return self.part:getFullType() end)
        -- Prefer the twin whose condition matches the dead reference, so a phantom
        -- fresh-condition entry cannot be picked over the player's real worn part.
        local okC, wantCond = pcall(function() return self.part:getCondition() end)
        local live = nil
        if okF and wantedFull then
            local exact, fallback = ggsFindLiveItemByFullType(inventory, wantedFull, 0, (okC and wantCond) or nil)
            live = exact or fallback
        end
        if live then
            print("[GGS UpgradeFix] re-resolved dead part reference " .. tostring(wantedFull) ..
                      " to live item id=" .. tostring(live.getID and live:getID()))
            self.part = live
            hasPart = true
        elseif isClient and isClient() and sendClientCommand and okF and wantedFull and
            not self.__ggsServerAttachRequested then
            -- No live twin either: the item oscillates with the inventory resync -- it was
            -- staged WITH a container and became unfindable within a second, session after
            -- session -- while the server verifiably holds it (players.db blob). Stop
            -- fighting the resync on this side: ask the server to do the attach with its
            -- own copy. It consumes its real item, attaches through raw Java, and writes
            -- md.weaponpart[slot]; the modData push then feeds the renderer, the sound
            -- profile (mirror fallback) and the workbench label on this side, so the
            -- attach is functional even if the client never gets its own real part.
            self.__ggsServerAttachRequested = true
            local okId, weaponId = pcall(self.weapon.getID, self.weapon)
            local okSlot, slot = pcall(function() return self.part:getPartType() end)
            local okCond, cond = pcall(function() return self.part:getCondition() end)
            local okSend = pcall(sendClientCommand, self.character, "GGS", "attachPart", {
                weaponId = (okId and weaponId or nil),
                full = wantedFull,
                slot = (okSlot and slot or nil),
                condition = (okCond and cond or nil),
            })
            print("[GGS UpgradeFix] no live item client-side; asked the SERVER to attach " ..
                      tostring(wantedFull) .. " (sent=" .. tostring(okSend) .. ")")
            -- Optimistic mirror write, immediately. On this path nothing is attached
            -- client-side until the server's modData push lands, and a shot fired inside
            -- that one-or-two-second window is loud -- the sound profile and the renderer
            -- both read this table. The server's push then confirms (or corrects) it.
            local mdW = self.weapon.getModData and self.weapon:getModData()
            if okSlot and slot and mdW then
                mdW.weaponpart = mdW.weaponpart or {}
                mdW.weaponpart[slot] = wantedFull
            end
            -- Record the unpaid debt. This path is otherwise a FREE attach: at this
            -- moment the player's item is in the invisible phase of the inventory
            -- oscillation, so neither side can find it to consume -- proven by the
            -- id census: the original (#53661400@55) survived the attach untouched,
            -- the gun's part came back as a NEW engine-made object (#837542428@55),
            -- and removal left the player with both. The scanner in
            -- GGS_GhostAttachmentPurge consumes one matching item the moment it
            -- resurfaces and then clears the entry.
            if mdW then
                mdW.ggsPendingConsume = mdW.ggsPendingConsume or {}
                mdW.ggsPendingConsume[wantedFull] = (okC and wantCond) or -1
                print("[GGS UpgradeFix] pending consume recorded: " .. tostring(wantedFull) ..
                          " @" .. tostring((okC and wantCond) or "any"))
            end
            if self.character and self.character.Say then
                pcall(self.character.Say, self.character, getText("IGUI_GGS_DevAttachmentRequested"))
            end
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
        -- Condition rides along so a server-side instanceItem fallback does not mint a
        -- factory-fresh 100% twin of a worn part.
        local okCond, partCond = pcall(function() return self.part:getCondition() end)
        local okSend, err = pcall(sendClientCommand, self.character, "GGS", "attachPart", {
            weaponId = (okId and weaponId or nil),
            partId = (okPid and partId or nil),
            full = (okFull and partFull or nil),
            slot = (okSlot and partSlot or nil),
            condition = (okCond and partCond or nil),
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
