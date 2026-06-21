-- GGS attachment diagnostic. Temporary.
-- Logs every attached part on the held weapon so we can see exactly what is
-- installed on a contorting gun (e.g. a deployed bipod). Remove after.
-- Output: [GGS_PART] in console.txt / DebugLog.

local tick = 0

local function dump()
    tick = tick + 1
    if tick % 120 ~= 0 then return end

    local p = getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
    if not p then return end
    local w = p:getPrimaryHandItem()
    if not w or not instanceof(w, "HandWeapon") then return end

    local md = w:getModData().weaponpart
    if not md then
        print("[GGS_PART] " .. tostring(w:getFullType()) .. " : (no weaponpart modData)")
        return
    end
    local parts = {}
    for slot, partId in pairs(md) do
        table.insert(parts, tostring(slot) .. "=" .. tostring(partId))
    end
    table.sort(parts)
    print("[GGS_PART] " .. tostring(w:getFullType()) .. " parts: " .. table.concat(parts, " | "))
end

Events.OnPlayerUpdate.Add(dump)
print("[GGS_PART] part diagnostic loaded")
