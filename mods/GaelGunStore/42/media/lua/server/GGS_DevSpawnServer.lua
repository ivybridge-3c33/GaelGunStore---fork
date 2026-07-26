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

local function dumpServerParts(playerObj)
    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem()
    if not weapon then
        dbg("[GGS ServerDBG] no primary hand item")
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
        if #payload > 0 and sendServerCommand then
            pcall(sendServerCommand, playerObj, MODULE, "partList", { parts = payload })
            dbg("[GGS ServerDBG] sent partList to client (" .. #payload .. " entries)")
        end
    end
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE then
        return
    end
    if command == COMMAND_DUMP_PARTS then
        pcall(dumpServerParts, playerObj)
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
