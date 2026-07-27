-- Server half of the workbench's dev attachment spawner.
--
-- Why this exists: risky_inspect_button's spawnDevAttachmentIntoInventory used
-- inventory:AddItem(fullType) directly on the client. Offline that is the whole story
-- and attaching works. On MP the server never learns about that item, so the part is a
-- client-side ghost: the click handler happily spawns it, stages it and queues vanilla's
-- ISUpgradeWeapon, and then the action quietly never performs -- no error, no attach, no
-- log line. Traced with [GGS ClickDBG]/[GGS DevAttach]: click fires, guards pass, the
-- spawn reports success, and attachWeaponPart is never reached.
--
-- So on MP the client asks here instead, and the item is created by the server, which
-- makes it real for both sides and lets the vanilla attach action validate.

local MODULE = "GGS"
local COMMAND_SPAWN_PART = "devSpawnPart"

local function isSpawnerEnabled()
    local sv = SandboxVars
    if sv and sv.GGSGS and sv.GGSGS.DevAttachmentSpawner == true then
        return true
    end
    return false
end

-- Find a weapon by id: hands first, then the whole inventory including nested bags.
--
-- Needed because getPrimaryHandItem() comes back nil here at exactly the wrong moment. The
-- detach request arrives right after the removal action ran, while the weapon is briefly
-- out of the character's hands, so the old `if not weapon then return end` bailed without a
-- word -- confirmed by "command received: detachPart" with neither outcome line following.
-- The server therefore never dropped its copy of the part, and the next sync handed it
-- straight back as a real part.
local function findWeaponById(playerObj, weaponId)
    if not playerObj then
        return nil
    end
    local function idOf(item)
        if not item or not item.getID then
            return nil
        end
        local ok, id = pcall(item.getID, item)
        return ok and id or nil
    end

    local primary = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem()
    if primary and (not weaponId or idOf(primary) == weaponId) then
        return primary
    end
    local secondary = playerObj.getSecondaryHandItem and playerObj:getSecondaryHandItem()
    if secondary and weaponId and idOf(secondary) == weaponId then
        return secondary
    end
    if not weaponId then
        return nil
    end

    local function search(container, depth)
        if not container or depth > 6 then
            return nil
        end
        local items = container.getItems and container:getItems()
        if not items then
            return nil
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item then
                if idOf(item) == weaponId then
                    return item
                end
                if instanceof(item, "InventoryContainer") and item.getInventory then
                    local found = search(item:getInventory(), depth + 1)
                    if found then
                        return found
                    end
                end
            end
        end
        return nil
    end

    return search(playerObj.getInventory and playerObj:getInventory(), 0)
end

local function detachServerPart(playerObj, args)
    if not args or not args.slot then
        print("[GGS ServerDBG] detachPart: no slot in args")
        return
    end
    local weapon = findWeaponById(playerObj, args.weaponId)
    if not weapon then
        print("[GGS ServerDBG] detachPart: weapon " .. tostring(args.weaponId) .. " not found")
        return
    end
    -- Find the part through getAllWeaponParts, not getWeaponPart(slot).
    --
    -- getWeaponPart(slot) returns nil here even for slots getAllWeaponParts clearly lists,
    -- so every detach request reported "nothing in slot" and the server quietly kept the
    -- whole set. That is what made a removed attachment come back: the client detached its
    -- own copy, the server's stayed intact, and the next weapon sync pulled it down again
    -- as a real part -- caught by [GGS WatchDBG] as
    --   slot Light APPEARED = Base.InsightWMX200 (realPart=Base.InsightWMX200)
    -- moments after the removal.
    -- Match on fullType first, then on the slot name, case-insensitively. Slot-name-only
    -- matching failed here: the server reported "nothing in slot Canon" on a weapon whose
    -- 4 parts were precisely the ones that then came back, Canon among them -- so the part
    -- exists and its getPartType() does not read back as the client's slot string. The
    -- failure message now lists what the server actually sees, so a mismatch is visible
    -- instead of being guessed at.
    local wanted = args.full and tostring(args.full) or nil
    local wantedSlot = tostring(args.slot):lower()
    local part, seen = nil, {}
    local okAll, all = pcall(weapon.getAllWeaponParts, weapon)
    if okAll and all then
        for i = 0, all:size() - 1 do
            local candidate = all:get(i)
            if candidate then
                local cType = candidate.getPartType and candidate:getPartType()
                local cFull = candidate.getFullType and candidate:getFullType()
                seen[#seen + 1] = tostring(cType) .. "=" .. tostring(cFull)
                if wanted and cFull and tostring(cFull) == wanted then
                    part = candidate
                    break
                end
                if cType and tostring(cType):lower() == wantedSlot then
                    part = candidate
                    break
                end
            end
        end
    end
    if not part and weapon.getWeaponPart then
        part = weapon:getWeaponPart(args.slot)
    end
    if not part then
        print("[GGS ServerDBG] detachPart: no match for slot=" .. tostring(args.slot) .. " full=" ..
                  tostring(wanted) .. "; server sees [" .. table.concat(seen, ", ") .. "]")
        -- No real part to detach, but the mirror can still be claiming one -- the server's
        -- entry outlives its part, and gatherUsedPartTypes in GGS_WeaponUpgradeSystem reads
        -- that mirror. Drop the entry on the way out instead of leaving the server insisting
        -- on a slot it cannot produce. No transmitModData, for the reason below.
        local md = weapon.getModData and weapon:getModData()
        if md and md.weaponpart and md.weaponpart[args.slot] ~= nil then
            print("[GGS ServerDBG] detachPart: clearing stale mirror entry " .. tostring(args.slot) ..
                      "=" .. tostring(md.weaponpart[args.slot]))
            md.weaponpart[args.slot] = nil
        end
        return
    end
    -- Hand the part back to the player, otherwise detaching destroys it.
    pcall(weapon.detachWeaponPart, weapon, playerObj, part)
    local inventory = playerObj.getInventory and playerObj:getInventory()
    if inventory then
        local okAdd, added = pcall(inventory.AddItem, inventory, part)
        if okAdd and added and sendAddItemToContainer then
            pcall(sendAddItemToContainer, inventory, added)
        end
    end
    local md = weapon.getModData and weapon:getModData()
    if md and md.weaponpart then
        md.weaponpart[args.slot] = nil
        -- No transmitModData: modData crosses as a whole table, so pushing from the server
        -- overwrites the client's copy wholesale -- ggsRemovedSlots included. That is the
        -- mechanism that kept undoing removals. The client has already cleared its own
        -- entry before sending this, and partList carries anything else it needs.
    end
    print("[GGS ServerDBG] detached " .. tostring(args.slot) .. " server-side")
end

-- Find any inventory item by id: hands, then the whole inventory including nested bags.
-- Same shape as findWeaponById but without the weapon assumptions.
local function findItemById(playerObj, itemId)
    if not playerObj or not itemId then
        return nil
    end
    local function idOf(item)
        if not item or not item.getID then
            return nil
        end
        local ok, id = pcall(item.getID, item)
        return ok and id or nil
    end
    local function search(container, depth)
        if not container or depth > 6 then
            return nil
        end
        local items = container.getItems and container:getItems()
        if not items then
            return nil
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item then
                if idOf(item) == itemId then
                    return item
                end
                if instanceof(item, "InventoryContainer") and item.getInventory then
                    local found = search(item:getInventory(), depth + 1)
                    if found then
                        return found
                    end
                end
            end
        end
        return nil
    end
    return search(playerObj.getInventory and playerObj:getInventory(), 0)
end

-- Server half of an attach. The client's ISUpgradeWeapon (routed through ggsDoUpgrade)
-- attaches its own real part and mirror entry, then sends this; without it the server's
-- copy of the weapon never gains the part -- the exact mirror image of the loot-gun kit,
-- where the server attaches and the client never learns. Every "two sides disagree"
-- divergence in this saga came from one of those two one-sided writes.
local function attachServerPart(playerObj, args)
    if not args or not args.full then
        print("[GGS ServerDBG] attachPart: no fullType in args")
        return
    end
    local weapon = findWeaponById(playerObj, args.weaponId)
    if not weapon then
        print("[GGS ServerDBG] attachPart: weapon " .. tostring(args.weaponId) .. " not found")
        return
    end

    -- Idempotent: the slot already holding this exact part means a duplicate command.
    local slot = args.slot
    if slot and weapon.getWeaponPart then
        local existing = weapon:getWeaponPart(slot)
        local okE, existingFull = pcall(function() return existing and existing:getFullType() end)
        if okE and existingFull == tostring(args.full) then
            print("[GGS ServerDBG] attachPart: slot " .. tostring(slot) .. " already holds " ..
                      tostring(args.full))
            return
        end
    end

    -- Prefer the player's own item, so the part is consumed rather than duplicated:
    -- first by the id the client sent, then by fullType -- the client's references
    -- oscillate with the inventory resync (staged with a container, unfindable one
    -- second later), so the id it captured is often already dead while this side
    -- verifiably holds the item (seen directly in the players.db blob). Falling back
    -- to a fresh instance is the last resort, for an item that never existed here.
    local partItem = findItemById(playerObj, args.partId)
    local okPF, partFull = pcall(function() return partItem and partItem:getFullType() end)
    if partItem and not (okPF and partFull == tostring(args.full)) then
        partItem = nil
    end
    if not partItem then
        local wantedFullType = tostring(args.full)
        local function searchByFull(container, depth)
            if not container or depth > 6 then
                return nil
            end
            local items = container.getItems and container:getItems()
            if not items then
                return nil
            end
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item then
                    local okT, t = pcall(function() return item:getFullType() end)
                    if okT and t == wantedFullType then
                        return item
                    end
                    if instanceof(item, "InventoryContainer") and item.getInventory then
                        local found = searchByFull(item:getInventory(), depth + 1)
                        if found then
                            return found
                        end
                    end
                end
            end
            return nil
        end
        partItem = searchByFull(playerObj.getInventory and playerObj:getInventory(), 0)
        if partItem then
            print("[GGS ServerDBG] attachPart: found " .. wantedFullType .. " by fullType server-side")
        end
    end
    local consumed = partItem ~= nil
    if not partItem then
        local okNew, created = pcall(instanceItem, tostring(args.full))
        partItem = okNew and created or nil
        print("[GGS ServerDBG] attachPart: item id=" .. tostring(args.partId) ..
                  " not found server-side, " .. (partItem and "instanced fresh" or "instanceItem FAILED"))
    end
    if not partItem or not instanceof(partItem, "WeaponPart") then
        print("[GGS ServerDBG] attachPart: no usable part for " .. tostring(args.full))
        return
    end

    if consumed then
        local container = partItem.getContainer and partItem:getContainer()
        if container then
            pcall(container.Remove, container, partItem)
        end
    end
    -- Raw Java on this side (no client hooks here): real part plus stat changes.
    pcall(weapon.attachWeaponPart, weapon, playerObj, partItem)

    -- Mirror entry too, exactly like GGS_MagServerFix does for clips: passive modData
    -- pushes from the server overwrite the client's table wholesale, so the server's copy
    -- must contain what the client wrote or the next push erases the client's entry --
    -- and with it the rendered model.
    local md = weapon.getModData and weapon:getModData()
    if md then
        md.weaponpart = md.weaponpart or {}
        local key = slot or (partItem.getPartType and partItem:getPartType())
        if key then
            md.weaponpart[key] = tostring(args.full)
        end
        -- Push it now. For a detach the wholesale overwrite was the enemy; for an attach
        -- it is the delivery: the client's renderer, sound profile and workbench label all
        -- read this table, and this is what makes a server-side attach visible without
        -- waiting for a passive sync.
        if weapon.transmitModData then
            pcall(weapon.transmitModData, weapon)
        end
    end

    local okAll, all = pcall(weapon.getAllWeaponParts, weapon)
    print("[GGS ServerDBG] attached " .. tostring(args.full) .. " to slot " .. tostring(slot) ..
              " (consumed=" .. tostring(consumed) .. ", totalParts=" ..
              tostring(okAll and all and all:size() or "?") .. ")")
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE then
        return
    end
    -- Entry log. A round went by with no server-side line for detachPart at all, so it was
    -- not clear whether the command was arriving and being filtered here, or never sent.
    print("[GGS ServerDBG] command received: " .. tostring(command))
    if command == "detachPart" then
        pcall(detachServerPart, playerObj, args)
        return
    end
    if command == "attachPart" then
        pcall(attachServerPart, playerObj, args)
        return
    end
    if command ~= COMMAND_SPAWN_PART then
        return
    end
    if not playerObj or not args or not args.fullType or args.fullType == "" then
        return
    end
    -- Gate server-side too: the client check can be bypassed, and this hands out free
    -- items. Same sandbox option the UI reads.
    if not isSpawnerEnabled() then
        print("[GGS DevSpawn] refused " .. tostring(args.fullType) .. ": DevAttachmentSpawner is off")
        return
    end

    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        return
    end

    local ok, item = pcall(inventory.AddItem, inventory, args.fullType)
    if not ok or not item then
        print("[GGS DevSpawn] failed to create " .. tostring(args.fullType))
        return
    end
    if item.transmitCompleteItemToClients then
        pcall(item.transmitCompleteItemToClients, item)
    end
    print(string.format("[GGS DevSpawn] created %s for %s", tostring(args.fullType),
        tostring(playerObj.getUsername and playerObj:getUsername() or "?")))
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(onClientCommand)
end
