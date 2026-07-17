-- Safety net: keep a ranged weapon's effective RecoilDelay from dropping so low
-- (stacked negative RecoilDelayModifier parts, or a bad script value) that the
-- fire-rate gate breaks. When RecoilDelay hits ~0/negative the "Single" fire mode
-- stops gating one-shot-per-click and fires full-auto, and it out-paces the Auto
-- mode (Auto is throttled by CyclicRateMultiplier, Single is not).
-- Root cases already patched in data: grip magpul_afg (-85) and the RecoilDelay=3
-- rifles (XM8/SR47/VZ58/Wieger940); this clamp covers any future/stacked combo.
--
-- PZ bakes weapon-part stat modifiers into the live equipped item, so
-- weapon:getRecoilDelay() returns the already-modified (effective) value.
-- Guarded so it is a safe no-op if the API is absent on this build.

local RECOIL_DELAY_FLOOR = 5

local function clampRecoilDelay(playerObj)
    if not playerObj then
        return
    end
    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if not (weapon and instanceof(weapon, "HandWeapon")) then
        return
    end
    if not (weapon.isRanged and weapon:isRanged()) then
        return
    end
    if not (weapon.getRecoilDelay and weapon.setRecoilDelay) then
        return
    end
    local rd = weapon:getRecoilDelay()
    if rd and rd < RECOIL_DELAY_FLOOR then
        pcall(weapon.setRecoilDelay, weapon, RECOIL_DELAY_FLOOR)
    end
end

Events.OnPlayerUpdate.Add(clampRecoilDelay)
