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
local COMMAND_DUMP_PARTS = "dumpParts"

local function isSpawnerEnabled()
    local sv = SandboxVars
    if sv and sv.GGSGS and sv.GGSGS.DevAttachmentSpawner == true then
        return true
    end
    return false
end

-- Dumps the SERVER's view of the weapon the player is holding, so it can be compared
-- with the client's [GGS PartDBG] dump of the same item at the same moment.
--
-- Needed because the evidence now points at a split: the gun carries
-- GGS_WeaponAutoUpgraded = true, so applyWeaponSlots really did attach its required
-- Handguard and Stock (and possibly a suppressor) at spawn -- and the character in the
-- world visibly wears them -- yet on the client getAllWeaponParts() and md.weaponpart
-- both report nothing but the magazine. If this prints parts the client cannot see,
-- the parts exist and simply never reach the client, which is exactly why inspect shows
-- None, the suppressor does not quieten the shot, and nothing can be removed.
-- Verbose per-request dump. Off by default: this now runs on every equip as well as on
-- every workbench open, and the interesting line (what got synced) is printed either way.
-- Flip to true to get the full server-side picture of a weapon again.
local VERBOSE = false
local function dbg(message)
    if VERBOSE then
        print(message)
    end
end

local function dumpServerParts(playerObj, args)
    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem()
    if not weapon then
        dbg("[GGS ServerDBG] no primary hand item")
        return
    end
    -- Both sides resolve "the weapon" independently through getPrimaryHandItem, and they
    -- can disagree for a moment -- which showed up as the part list flapping between 0
    -- and 4 entries, so the client alternately pruned a gun's mirror with another item's
    -- list and then had the parts pushed back. Carry the id and refuse to answer for
    -- anything else.
    local okId, weaponId = pcall(weapon.getID, weapon)
    if args and args.weaponId and okId and weaponId ~= args.weaponId then
        dbg("[GGS ServerDBG] weapon mismatch: client asked about " .. tostring(args.weaponId) ..
                ", holding " .. tostring(weaponId))
        return
    end
    local okType, fullType = pcall(weapon.getFullType, weapon)
    dbg("[GGS ServerDBG] weapon=" .. tostring(okType and fullType or "?"))

    local realList = {}
    local okAll, all = pcall(weapon.getAllWeaponParts, weapon)
    if okAll and all then
        for i = 0, all:size() - 1 do
            local part = all:get(i)
            if part then
                realList[#realList + 1] = tostring(part.getPartType and part:getPartType() or "?") .. "=" ..
                                              tostring(part.getFullType and part:getFullType() or "?")
            end
        end
    else
        realList[#realList + 1] = "<getAllWeaponParts unavailable>"
    end
    dbg("[GGS ServerDBG] real parts (" .. #realList .. "): " .. table.concat(realList, ", "))

    local mirrorList = {}
    local okMd, md = pcall(weapon.getModData, weapon)
    if okMd and md and md.weaponpart then
        for slot, ft in pairs(md.weaponpart) do
            mirrorList[#mirrorList + 1] = tostring(slot) .. "=" .. tostring(ft)
        end
    end
    dbg("[GGS ServerDBG] modData mirror (" .. #mirrorList .. "): " .. table.concat(mirrorList, ", "))
    dbg("[GGS ServerDBG] autoUpgradedFlag=" ..
              tostring(okMd and md and md.GGS_WeaponAutoUpgraded or "nil"))

    -- Measured on the same weapon at the same tick:
    --   server real parts (6): Canon=NST_Silencer, Handguard=ar15_hg_reflex_carbon,
    --                          Stock=ar15_sba3_stock, Light=InsightWMX200,
    --                          Stool=M203_GL, Clip=Clip_556Clip
    --   client real parts (1): Clip=Clip_556Clip
    -- applyWeaponSlots attached all of those at spawn (GGS_WeaponAutoUpgraded = true) and
    -- they never reached the client, so every client-side reader saw an empty gun: the
    -- workbench slots drew IGUI_NONE, the suppressor profile found no Canon and left the
    -- shot at full volume, and removal had nothing to remove. It also made the parts show
    -- up in the attach list, where clicking them failed with hasPart=false -- they were
    -- never in the inventory, they were already on the gun.
    --
    -- So mirror the real parts into md.weaponpart and transmit. modData does cross the
    -- wire, and md.weaponpart is what AWCWF_RenderPart and the mirror-aware readers use.
    if okMd and md then
        md.weaponpart = md.weaponpart or {}
        local synced = {}
        if okAll and all then
            for i = 0, all:size() - 1 do
                local part = all:get(i)
                local partType = part and part.getPartType and part:getPartType()
                local partFull = part and part.getFullType and part:getFullType()
                if partType and partFull and md.weaponpart[partType] ~= partFull then
                    md.weaponpart[partType] = partFull
                    synced[#synced + 1] = tostring(partType) .. "=" .. tostring(partFull)
                end
            end
        end
        if #synced > 0 then
            if weapon.transmitModData then
                pcall(weapon.transmitModData, weapon)
            end
            print("[GGS ServerDBG] synced to client (" .. #synced .. "): " .. table.concat(synced, ", "))
        else
            dbg("[GGS ServerDBG] nothing to sync")
        end

        -- Do not rely on transmitModData reaching the client: send the list explicitly
        -- and let the client write its own copy (GGS_PartSyncClient.lua). Measured proof
        -- that this is needed will be in the logs either way -- the previous round showed
        -- the server syncing 5 parts while the client's own dump, taken 7ms earlier, still
        -- had one. With an explicit command there is no ambiguity about arrival.
        local payload = {}
        if okAll and all then
            for i = 0, all:size() - 1 do
                local part = all:get(i)
                local partType = part and part.getPartType and part:getPartType()
                local partFull = part and part.getFullType and part:getFullType()
                if partType and partFull then
                    payload[#payload + 1] = { slot = tostring(partType), full = tostring(partFull) }
                end
            end
        end
        -- Always send, even when the list is empty: the client treats this as the whole
        -- truth and prunes anything not in it, which is how stale entries left behind by
        -- a removal get cleaned up. Skipping the empty case would leave a gun whose last
        -- attachment was removed showing ghosts forever.
        if sendServerCommand then
            pcall(sendServerCommand, playerObj, MODULE, "partList", { parts = payload, weaponId = (okId and weaponId or nil) })
            dbg("[GGS ServerDBG] sent partList to client (" .. #payload .. " entries)")
        end
    end
end

-- The client detaches on its own copy; without this the server keeps the part attached
-- and the next sync re-adds it to the mirror, so a removed attachment comes back.
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
        if weapon.transmitModData then
            pcall(weapon.transmitModData, weapon)
        end
    end
    print("[GGS ServerDBG] detached " .. tostring(args.slot) .. " server-side")
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE then
        return
    end
    -- Entry log. A round went by with no server-side line for detachPart at all, so it was
    -- not clear whether the command was arriving and being filtered here, or never sent.
    print("[GGS ServerDBG] command received: " .. tostring(command))
    if command == COMMAND_DUMP_PARTS then
        pcall(dumpServerParts, playerObj, args)
        return
    end
    if command == "detachPart" then
        pcall(detachServerPart, playerObj, args)
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
