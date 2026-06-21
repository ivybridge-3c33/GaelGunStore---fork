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

    -- character state machine (high level)
    local stateName = "?"
    pcall(function()
        local st = p:getCurrentState()
        if st then stateName = st:getClass():getSimpleName() end
    end)
    print("[GGS_ANIM]   charState=" .. stateName
        .. " recoil=" .. probe(p, "getRecoilDelay")
        .. " bodyDmg=" .. probe(p, "isOnFire"))

    -- advanced animator: probe many possible methods
    local aa = nil
    pcall(function() aa = p:getAdvancedAnimator() end)
    if aa then
        print("[GGS_ANIM]   aa: state=" .. probe(aa, "getCurrentStateName")
            .. " clip=" .. probe(aa, "getCurrentClipName")
            .. " anim=" .. probe(aa, "getCurrentAnimationName")
            .. " primary=" .. probe(aa, "getPrimaryStateName"))
    end

    -- attached items (AWCWF renders parts here; a bad one can drag the pose)
    local n = "?"
    pcall(function() n = tostring(p:getAttachedItems() and p:getAttachedItems():size()) end)
    print("[GGS_ANIM]   attachedItems=" .. n)
end

Events.OnPlayerUpdate.Add(dump)
print("[GGS_ANIM] anim diagnostic loaded")
