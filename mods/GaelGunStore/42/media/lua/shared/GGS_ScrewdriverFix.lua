-- GGS_ScrewdriverFix.lua
-- Fixes a vanilla B42 (42.17) bug in the Java-side ItemCodeOnTest.hasScrewdriver,
-- which every weapon part's CanAttach/CanDetach script test points at.
-- The vanilla implementation has the isBroken() check inverted:
--   * carrying ANY broken screwdriver in the main inventory -> attach/detach
--     blocked for every weapon part on every gun
--   * carrying no screwdriver at all -> allowed
-- canAttach/canDetach resolve the callback by name through
-- LuaManager.getFunctionObject("ItemCodeOnTest.hasScrewdriver"), which looks up
-- the Lua global environment first, so shadowing the global here replaces the
-- broken Java implementation everywhere (context menu, inspect UI, timed action).
--
-- Set to true to enforce the check the way vanilla intended it: you need at
-- least one working (non-broken) screwdriver anywhere in your inventory,
-- bags included. Default false = attach/detach freely.
local REQUIRE_WORKING_SCREWDRIVER = false

local function predicateNotBroken(item)
    return item and not item:isBroken()
end

local function hasWorkingScrewdriver(character)
    if not character or not character.getInventory then
        return true
    end
    local inv = character:getInventory()
    if not inv then
        return true
    end
    local ok, result = pcall(function()
        return inv:containsTagEvalRecurse(ItemTag.SCREWDRIVER, predicateNotBroken)
    end)
    if not ok then
        -- Never let the fix itself block removal.
        return true
    end
    return result
end

ItemCodeOnTest = {
    hasScrewdriver = function(character, weapon, part)
        if REQUIRE_WORKING_SCREWDRIVER then
            return hasWorkingScrewdriver(character)
        end
        return true
    end,
}
