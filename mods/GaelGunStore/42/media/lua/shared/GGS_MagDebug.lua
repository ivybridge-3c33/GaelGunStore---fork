-- Debug-only hook to log magazine info when ejecting. Commented out so it does nothing in-game.

local function fmt(val)
    if val == nil then
        return "nil"
    end
    return tostring(val)
end

local function log(msg)
    print("[GGS MagDebug] " .. msg)
end

local function patchEject()
    if not ISEjectMagazine or ISEjectMagazine.__ggsMagDebug then
        return
    end
    ISEjectMagazine.__ggsMagDebug = true
    local orig = ISEjectMagazine.unloadAmmo
    ISEjectMagazine.unloadAmmo = function(self, ...)
        local gun = self and self.gun
        if gun then
            local contains = gun.isContainsClip and gun:isContainsClip()
            local magType = gun.getMagazineType and gun:getMagazineType()
            local md = gun.getModData and gun:getModData()
            local mdClip = md and md.weaponpart and md.weaponpart["Clip"] or nil
            local ammo = gun.getCurrentAmmoCount and gun:getCurrentAmmoCount() or nil
            log(string.format("eject start contains=%s magType=%s mdClip=%s ammo=%s",
                fmt(contains), fmt(magType), fmt(mdClip), fmt(ammo)))
        else
            log("eject start gun=nil")
        end
        local res = orig(self, ...)
        if gun then
            local containsAfter = gun.isContainsClip and gun:isContainsClip()
            local magTypeAfter = gun.getMagazineType and gun:getMagazineType()
            local md2 = gun.getModData and gun:getModData()
            local mdClipAfter = md2 and md2.weaponpart and md2.weaponpart["Clip"] or nil
            local ammoAfter = gun.getCurrentAmmoCount and gun:getCurrentAmmoCount() or nil
            log(string.format("eject end contains=%s magType=%s mdClip=%s ammo=%s",
                fmt(containsAfter), fmt(magTypeAfter), fmt(mdClipAfter), fmt(ammoAfter)))
        end
        return res
    end
end

-- Disabled to avoid any logging/patching in-game.
-- Events.OnGameBoot.Add(patchEject)
-- Events.OnGameStart.Add(patchEject)
