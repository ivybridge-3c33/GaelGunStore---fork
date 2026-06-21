-- GGS render diagnostic. Temporary: logs why an attached Clip part may not
-- render on the held weapon. Remove this file once diagnosed.
-- Output appears in console.txt / DebugLog prefixed with [GGS_DBG].

local tick = 0

local function dump()
    tick = tick + 1
    if tick % 120 ~= 0 then return end -- ~ every few seconds, avoid spam

    local p = getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
    if not p then return end
    local w = p:getPrimaryHandItem()
    if not w or not instanceof(w, "HandWeapon") then return end

    local sprite = tostring(w:getWeaponSprite())
    print(string.format("[GGS_DBG] weapon=%s sprite=%s", tostring(w:getFullType()), sprite))

    -- 1) weapon model resolvable? (used by GetWeaponModelInstance gate)
    local wms = ScriptManager.instance:getModelScript("Base." .. sprite)
    print("[GGS_DBG]   weaponModelScript(Base." .. sprite .. ")=" .. tostring(wms))

    -- 2) the render gate
    local gmi = nil
    if AWCWF_AdditionalParts and AWCWF_AdditionalParts.GetWeaponModelInstance then
        local ok, res = pcall(AWCWF_AdditionalParts.GetWeaponModelInstance, p, w)
        gmi = ok and res or ("ERR:" .. tostring(res))
    else
        gmi = "GetWeaponModelInstance MISSING"
    end
    print("[GGS_DBG]   GetWeaponModelInstance=" .. tostring(gmi) .. "  <-- nil/false => NOTHING renders")

    -- 3) modData parts the renderer iterates
    local md = w:getModData().weaponpart
    if not md then
        print("[GGS_DBG]   modData.weaponpart = nil (renderer has no parts to draw)")
        return
    end
    for slot, partId in pairs(md) do
        local pm = ScriptManager.instance:getModelScript(tostring(partId))
        print(string.format("[GGS_DBG]   part[%s]=%s  partModelScript=%s %s",
            tostring(slot), tostring(partId), tostring(pm),
            pm and "" or "<-- partmodel nil => this part skipped"))
    end
end

Events.OnPlayerUpdate.Add(dump)
print("[GGS_DBG] render diagnostic loaded")
