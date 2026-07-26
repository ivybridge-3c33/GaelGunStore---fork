-- Client half of the weapon-part sync.
--
-- Measured on one weapon at one tick, server vs client:
--   server real parts (6): Canon=NST_Silencer, Handguard=ar15_hg_reflex_carbon,
--                          Stock=ar15_sba3_stock, Light=InsightWMX200,
--                          Stool=M203_GL, Clip=Clip_556Clip
--   client real parts (1): Clip=Clip_556Clip
--
-- applyWeaponSlots attaches those at spawn (the gun carries GGS_WeaponAutoUpgraded =
-- true) and they never arrive here, so every client-side reader saw a bare gun: the
-- workbench slots drew IGUI_NONE, the suppressor profile found no Canon and left the shot
-- at full volume, removal had nothing to remove -- and the same parts turned up in the
-- attach list, where clicking them failed with hasPart=false because they were never in
-- the inventory, they were already bolted to the gun. Offline none of this happens: one
-- Lua state holds the parts, so every reader agrees.
--
-- The server now sends its part list explicitly (GGS_DevSpawnServer.lua) instead of
-- trusting modData to cross on its own, and this writes it into md.weaponpart -- the
-- table AWCWF_RenderPart draws from and that the mirror-aware readers consult via
-- getWeaponPart(slot, false).

local MODULE = "GGS"

local function applyPartList(args)
    local playerObj = getPlayer()
    if not playerObj or not args or type(args.parts) ~= "table" then
        return
    end
    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem()
    if not weapon or not weapon.getModData then
        print("[GGS PartSync] no weapon in hand, ignoring partList")
        return
    end
    -- Only apply a list that is about the gun currently in hand. Without this the two
    -- sides could be talking about different items -- seen as the list flapping between
    -- 0 and 4 entries, which pruned a gun's mirror with another item's contents and then
    -- pushed the parts back, so a removed suppressor kept reappearing on the model.
    if args.weaponId then
        local okId, weaponId = pcall(weapon.getID, weapon)
        if okId and weaponId ~= args.weaponId then
            print("[GGS PartSync] ignoring partList for another item (got " ..
                      tostring(args.weaponId) .. ", holding " .. tostring(weaponId) .. ")")
            return
        end
    end

    -- Single source of truth: make the real part map match the server, and let the
    -- setWeaponPart hook keep md.weaponpart in step on its own.
    --
    -- Writing only the mirror is what produced the mess this replaced. Different readers
    -- consult different stores -- the world model reads the mirror, the workbench label
    -- read real-then-mirror, the slot buttons and the removal action read real only, the
    -- suppressor read real-then-mirror, and the window's refresh token read real only -- so
    -- a mirror-only entry showed up in some places and not others, could not be removed,
    -- and reappeared on the next sync. Attaching for real collapses all of that: every
    -- reader sees the same thing, and the special cases built around the mirror go away.
    local md = weapon:getModData()
    md.weaponpart = md.weaponpart or {}
    local written = {}
    local present = {}
    local removed = md.ggsRemovedSlots or {}
    for _, entry in ipairs(args.parts) do
        if entry and entry.slot and entry.full and not removed[entry.slot] then
            present[entry.slot] = true
            local okReal, real = pcall(weapon.getWeaponPart, weapon, entry.slot, true)
            local haveIt = okReal and real and real.getFullType and real:getFullType() == entry.full
            if not haveIt then
                local okNew, part = pcall(instanceItem, entry.full)
                if okNew and part and instanceof(part, "WeaponPart") then
                    pcall(weapon.setWeaponPart, weapon, entry.slot, part)
                    written[#written + 1] = tostring(entry.slot) .. "=" .. tostring(entry.full)
                else
                    -- Could not build the part; fall back to the mirror so at least the
                    -- model and the label know about it.
                    md.weaponpart[entry.slot] = entry.full
                    written[#written + 1] = tostring(entry.slot) .. "=" .. tostring(entry.full) .. "(mirror-only)"
                end
            end
        end
    end

    -- Treat the server's list as the whole truth and drop anything else, so the mirror
    -- self-heals. Removing a part used to leave its entry behind, and a stale entry is
    -- a ghost attachment: the workbench label still names it (the label falls back to the
    -- mirror) while the slot button, which reads the real part, has nothing -- so it
    -- cannot be double-clicked off, and the in-game right-click menu does not offer it
    -- either. The model keeps wearing it too.
    --
    -- Clip and ClipUI are exempt: magazine state is driven client-side and does not
    -- always appear in the server's part list.
    local pruned = {}
    for slot in pairs(md.weaponpart) do
        if not present[slot] and slot ~= "Clip" and slot ~= "ClipUI" then
            pruned[#pruned + 1] = tostring(slot)
        end
    end
    for _, slot in ipairs(pruned) do
        -- Clear the real part as well, through setWeaponPart so the hook clears the mirror
        -- with it. Dropping only the mirror entry left the real part attached and the two
        -- stores disagreed again.
        pcall(weapon.setWeaponPart, weapon, slot, nil)
        md.weaponpart[slot] = nil
    end

    if #written > 0 or #pruned > 0 then
        print("[GGS PartSync] mirror updated -- added/changed " .. #written ..
                  " (" .. table.concat(written, ", ") .. "), removed " .. #pruned ..
                  " (" .. table.concat(pruned, ", ") .. ")")
    else
        print("[GGS PartSync] partList received (" .. #args.parts .. "), mirror already current")
    end
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= "partList" then
        return
    end
    pcall(applyPartList, args)
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
end

-- Ask on equip as well, not just when the workbench opens. Otherwise a player has to
-- open inspect once before their suppressor starts working, which is exactly the kind of
-- invisible prerequisite that made this take so long to find.
local function requestSync(playerObj, weapon)
    if not (isClient and isClient()) or not sendClientCommand then
        return
    end
    if not weapon or not weapon.IsWeapon or not weapon:IsWeapon() then
        return
    end
    local okId, weaponId = pcall(weapon.getID, weapon)
    pcall(sendClientCommand, playerObj or getPlayer(), MODULE, "dumpParts", { weaponId = (okId and weaponId or nil) })
end

if Events and Events.OnEquipPrimary then
    Events.OnEquipPrimary.Add(requestSync)
end

-- Watcher: report when a slot reappears on the held weapon.
--
-- After a removal the part comes back on the first shot, and [GGS MirrorDBG] stays silent,
-- so md.weaponpart is not being written from Lua at all -- the only thing that can do that
-- is the server pushing its whole modData table over (transmitModData), which lands
-- Java-side and skips every hook. This says exactly when a slot returns, so it can be
-- lined up against the shot, and prints the real/mirror state at that moment.
local ggsWatchedId, ggsWatchedSlots = nil, {}

local function watchHeldWeapon()
    local playerObj = getPlayer()
    if not playerObj then
        return
    end
    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem()
    if not weapon or not weapon.getModData or not weapon.IsWeapon or not weapon:IsWeapon() then
        ggsWatchedId, ggsWatchedSlots = nil, {}
        return
    end
    local okId, id = pcall(weapon.getID, weapon)
    if not okId then
        return
    end
    if ggsWatchedId ~= id then
        ggsWatchedId, ggsWatchedSlots = id, {}
    end

    local md = weapon:getModData()
    local now = {}
    if md and md.weaponpart then
        for slot, full in pairs(md.weaponpart) do
            if slot ~= "Clip" and slot ~= "ClipUI" then
                now[slot] = full
            end
        end
    end

    for slot, full in pairs(now) do
        if ggsWatchedSlots[slot] == nil then
            local okReal, real = pcall(weapon.getWeaponPart, weapon, slot, true)
            print(string.format("[GGS WatchDBG] slot %s APPEARED = %s (realPart=%s)", tostring(slot),
                tostring(full), tostring(okReal and real and real.getFullType and real:getFullType() or "nil")))
        end
    end
    for slot in pairs(ggsWatchedSlots) do
        if now[slot] == nil then
            print("[GGS WatchDBG] slot " .. tostring(slot) .. " GONE")
        end
    end
    ggsWatchedSlots = now
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(function(playerObj)
        if playerObj == getPlayer() then
            pcall(watchHeldWeapon)
        end
    end)
end
