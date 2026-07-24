-- Override of AWCWF's media/lua/shared/WeaponPartSort.lua (GaelGunStore B42 fork).
--
-- Why: AWCWF registers CheckAdd on OnGameBoot. On MP, Core.ResetLua re-fires
-- OnGameBoot from ConnectToServerState.receiveServerOptions, and at that point
-- instanceItem() can come back null -> NPE in Item.InstanceItem
-- (setAlcoholPower on a null item) -> the loop aborts partway, so every item
-- after the failure never gets its DisplayCategory/OnCreate applied. Result:
-- GGS guns missing from the admin/debug item list and from loot on MP.
-- SP never hits it (no ConnectToServerState -> no ResetLua -> single pass).
--
-- Fix: pcall the instanceItem call so one bad item cannot kill the whole pass,
-- and print which item failed so the real culprit can be fixed at the source.
-- Everything else is byte-faithful to AWCWF's original, including the
-- pre-existing `not x == "Tool"` quirk on the melee branch (left alone on
-- purpose -- changing it would alter AWCWF behaviour, not fix this bug).

local function TweakItem(item, field, value)
    local item = ScriptManager.instance:getItem(item)
    item:DoParam(field .. " = " .. value);
end

local function CheckAdd()
    local items = getAllItems();
    for i = 0, items:size() - 1 do
        local item = items:get(i);
        if ScriptManager.instance:getItem(item:getFullName()) then
            -- GGS fork guard (original: local RealItem = instanceItem(item:getFullName());)
            local ok, RealItem = pcall(instanceItem, item:getFullName());
            if not ok then
                print("[GGS] WeaponPartSort: instanceItem failed for " .. tostring(item:getFullName()));
                RealItem = nil;
            end
            if RealItem then
                if AWCWF_WeaponMustPartList[RealItem:getType()] then
                    TweakItem(item:getFullName(), "OnCreate", "SpawnInitPart.OnCreatePart");
                end
                if RealItem:IsWeapon() then
                    if RealItem:isRanged() then
                        TweakItem(item:getFullName(), "DisplayCategory", "WepFire");
                    else
                        if not RealItem:getDisplayCategory() == "Tool" then
                            TweakItem(item:getFullName(), "DisplayCategory", "WepMelee");
                        end
                    end
                end
                if RealItem:getCategory() == "Ammo" then
                    if RealItem:getMaxAmmo() then
                        TweakItem(item:getFullName(), "DisplayCategory", "WepAmmoMag");
                    else
                        TweakItem(item:getFullName(), "DisplayCategory", "Ammo");
                    end
                end
                if RealItem:getCategory() == "WeaponPart" then
                    local PartType = RealItem:getPartType();
                    if PartType then
                        TweakItem(item:getFullName(), "DisplayCategory", PartType);
                    end
                end
            end
        end
    end
end

Events.OnGameBoot.Add(CheckAdd)
