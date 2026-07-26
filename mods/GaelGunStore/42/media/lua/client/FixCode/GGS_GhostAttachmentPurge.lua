-- Purge ghost weapon-part models stuck on the player as attached items.
--
-- Third data layer, after the real Java part map and the md.weaponpart mirror: AWCWF
-- draws the held weapon's parts by attaching Base.TempNilItem props to the player at
-- "<bone>[]<PartType>" locations (AWCWF_RenderPart, the player:setAttachedItem at the
-- bottom of Apply_Effect), and attached items PERSIST in the character save. Its cleanup
-- only ever collects items whose fullType is Base.TempNilItem, so anything else parked at
-- a part location is invisible to it forever: never compared, never removed, redrawn
-- every session.
--
-- Why this file exists: a suppressor stayed visible on the character while
-- [GGS PartDBG] showed the gun's BOTH stores empty of it under every key --
--   real=[Scope, Stock, Handguard, Grip, Light, Stool, Clip]
--   mirror=[Handguard, Stock, Light, Stool, Scope, Grip, Clip]
-- so nothing that reads the weapon can be drawing it; only an attached item on the
-- character fits. This dumps what is actually attached (the missing piece of every
-- earlier round) and removes what cannot be justified:
--   - a non-TempNilItem at a part location: never legitimate, remove always.
--   - a TempNilItem at a part location with no matching mirror entry on any carried
--     weapon: stale prop; safe to remove because AWCWF rebuilds valid ones from the
--     mirror within a frame.

local TEMP_ITEM = "Base.TempNilItem"
local TICKS_BETWEEN_SCANS = 600

-- Fallback copy of AWCWF_AdditionalParts.partlist, for load-order safety.
local FALLBACK_SLOTS = {"Scope", "Mount", "Canon", "Stock", "Handguard", "Hanguard", "Grip", "Laser", "Light",
                        "Stool", "R_Scope", "L_Scope", "Skin", "Sling", "RecoilPad", "Misc", "Clip", "ClipUI",
                        "Hide_Beam", "Barrel", "Barrel_Shroud", "AMMO"}

local function partSlotSet()
    local set = {}
    local list = (AWCWF_AdditionalParts and AWCWF_AdditionalParts.partlist) or FALLBACK_SLOTS
    for _, slot in ipairs(list) do
        set[slot] = true
    end
    return set
end

-- "Bip01_Prop1[]Canon" -> "Canon"; nil for locations that are not AWCWF part props.
local function locationSlot(location)
    if not location then
        return nil
    end
    local _, after = string.match(tostring(location), "(.-)%[%](.+)")
    return after
end

-- Every mirror entry on every weapon the player carries in hand or attached (back,
-- holster): those are the entries AWCWF_RenderPart draws props for, so a prop matching
-- one of them is legitimate.
local function collectJustifiedSlots(playerObj)
    local justified = {}
    local function addFrom(weapon)
        if not weapon or not instanceof(weapon, "HandWeapon") then
            return
        end
        local md = weapon.getModData and weapon:getModData()
        if md and md.weaponpart then
            for slot in pairs(md.weaponpart) do
                justified[slot] = true
            end
        end
    end
    addFrom(playerObj:getPrimaryHandItem())
    addFrom(playerObj:getSecondaryHandItem())
    local attached = playerObj.getAttachedItems and playerObj:getAttachedItems()
    if attached and attached.size then
        for i = 0, attached:size() - 1 do
            local entry = attached:get(i)
            local item = entry and entry.getItem and entry:getItem()
            if item and instanceof(item, "HandWeapon") and item:getFullType() ~= TEMP_ITEM then
                addFrom(item)
            end
        end
    end
    return justified
end

local function purgeGhostAttachments(playerObj, label)
    playerObj = playerObj or getPlayer()
    if not playerObj or not playerObj.getAttachedItems then
        return
    end
    local attached = playerObj:getAttachedItems()
    if not attached or not attached.size then
        return
    end

    local slots = partSlotSet()
    local justified = collectJustifiedSlots(playerObj)
    local report, doomed = {}, {}

    for i = 0, attached:size() - 1 do
        local entry = attached:get(i)
        local item = entry and entry.getItem and entry:getItem()
        if item then
            local location = entry.getLocation and entry:getLocation()
            local slot = locationSlot(location)
            local full = tostring(item.getFullType and item:getFullType())
            local sprite = tostring(item.getWeaponSprite and item:getWeaponSprite())
            report[#report + 1] = tostring(location) .. "=" .. full .. "/" .. sprite
            if slot and slots[slot] then
                if full ~= TEMP_ITEM then
                    -- A real item parked at a part-prop location. No code path does this
                    -- on purpose; it renders forever because AWCWF's cleanup cannot see it.
                    doomed[#doomed + 1] = { item = item, why = "non-temp item at part location " .. tostring(location) }
                elseif not justified[slot] then
                    doomed[#doomed + 1] = { item = item, why = "no mirror entry justifies " .. tostring(location) }
                end
            end
        end
    end

    -- The dump is the point as much as the purge: every earlier round lacked exactly this
    -- list. One line per scan that found part props at all.
    if #report > 0 then
        print("[GGS GhostDBG] " .. tostring(label) .. " attached=[" .. table.concat(report, ", ") .. "]")
    end
    for _, d in ipairs(doomed) do
        print("[GGS GhostDBG] removing ghost prop (" .. d.why .. ") sprite=" ..
                  tostring(d.item.getWeaponSprite and d.item:getWeaponSprite()))
        pcall(playerObj.removeAttachedItem, playerObj, d.item)
    end
end

local tickCounter = 0
local function onTick()
    tickCounter = tickCounter + 1
    if tickCounter < TICKS_BETWEEN_SCANS then
        return
    end
    tickCounter = 0
    purgeGhostAttachments(getPlayer(), "tick")
end

if Events and Events.OnEquipPrimary and Events.OnEquipPrimary.Add then
    Events.OnEquipPrimary.Add(function(playerObj)
        purgeGhostAttachments(playerObj, "equip")
    end)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(function()
        purgeGhostAttachments(getPlayer(), "gamestart")
    end)
end
if Events and Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(onTick)
end
