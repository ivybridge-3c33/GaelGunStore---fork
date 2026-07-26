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

    local md = weapon:getModData()
    md.weaponpart = md.weaponpart or {}
    local written = {}
    for _, entry in ipairs(args.parts) do
        if entry and entry.slot and entry.full then
            if md.weaponpart[entry.slot] ~= entry.full then
                md.weaponpart[entry.slot] = entry.full
                written[#written + 1] = tostring(entry.slot) .. "=" .. tostring(entry.full)
            end
        end
    end

    if #written > 0 then
        print("[GGS PartSync] wrote " .. #written .. " part(s) into the local mirror: " ..
                  table.concat(written, ", "))
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
    pcall(sendClientCommand, playerObj or getPlayer(), MODULE, "dumpParts", {})
end

if Events and Events.OnEquipPrimary then
    Events.OnEquipPrimary.Add(requestSync)
end
