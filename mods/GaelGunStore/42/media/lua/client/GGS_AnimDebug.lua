-- GGS animation diagnostic. Temporary.
-- Logs the held weapon + character animation variables/state so we can
-- compare a contorting gun (MK18) against a working one (e.g. G27).
-- Output: console.txt / DebugLog, prefixed [GGS_ANIM]. Remove after diagnosis.

local VARS = {
    "Weapon", "WeaponType", "Type", "isAiming", "Aim", "AimWhileWalking",
    "FloorAiming", "PerformingAction", "WeaponAimType", "TacticalPosture",
    "WeaponReloadType", "Lean_Left", "Lean_Right", "isLoading", "isRacking",
    "isUnloading", "RackAiming", "Reloading", "Shooting", "FireWeapon",
}

local tick = 0

local function gv(p, n)
    local ok, v = pcall(function() return p:getVariableString(n) end)
    if ok and v ~= nil and tostring(v) ~= "" then return tostring(v) end
    return "-"
end

local function probe(obj, name)
    local ok, v = pcall(function() return obj[name](obj) end)
    if ok then return tostring(v) end
    return "n/a"
end

local function dump()
    tick = tick + 1
    if tick % 60 ~= 0 then return end -- ~1s

    local p = getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
    if not p then return end
    local w = p:getPrimaryHandItem()
    if not w or not instanceof(w, "HandWeapon") then return end

    print(string.format("[GGS_ANIM] gun=%s sprite=%s aiming=%s swingAnim=%s fireMode=%s",
        tostring(w:getFullType()), tostring(w:getWeaponSprite()),
        probe(p, "isAiming"), probe(w, "getSwingAnim"), probe(w, "getFireMode")))

    local line = "[GGS_ANIM]   vars:"
    for _, n in ipairs(VARS) do
        local val = gv(p, n)
        if val ~= "-" then line = line .. " " .. n .. "=" .. val end
    end
    print(line)

    -- current animation state name (probe several possible APIs)
    local aa = nil
    pcall(function() aa = p:getAdvancedAnimator() end)
    if aa then
        print("[GGS_ANIM]   animState=" .. probe(aa, "getCurrentStateName")
            .. " curAnim=" .. probe(aa, "getCurrentClipName"))
    end
end

Events.OnPlayerUpdate.Add(dump)
print("[GGS_ANIM] anim diagnostic loaded")
