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
    end
    return hasPart and hasWeapon
end

local old_ISUpgradeWeapon_perform = ISUpgradeWeapon.perform
function ISUpgradeWeapon:perform()
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

function ISUpgradeWeapon:new(character, weapon, part, maxtime)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon;
    o.part = part;
    o.maxTime = maxtime or o:getDuration();

    return o;
end
