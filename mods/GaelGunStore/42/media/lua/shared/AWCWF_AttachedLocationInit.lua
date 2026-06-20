-- Dynamic locations used by AWCWF/GGS visual weapon-part attachments.
-- These must exist before TempNilItem overlays are attached to players/zombies.

local function registerGaelLocations()
    local group = AttachedLocations and AttachedLocations.getGroup and AttachedLocations.getGroup("Human")
    if not group then
        return
    end

    local partlist = (AWCWF_AdditionalParts and AWCWF_AdditionalParts.partlist) or {
        "Scope",
        "Mount",
        "Canon",
        "Stock",
        "Handguard",
        "Hanguard",
        "Grip",
        "Laser",
        "Light",
        "Stool",
        "R_Scope",
        "L_Scope",
        "Skin",
        "Sling",
        "RecoilPad",
        "Misc",
        "Clip",
        "ClipUI",
        "Hide_Beam",
        "Barrel",
        "Barrel_Shroud",
        "AMMO",
    }

    local bones = {
        "Bip01_Prop1",
        "Bip01_BackPack",
        "Bip01_Back",
        "Bip01_Spine",
        "Bip01_Spine1",
        "Bip01_Pelvis",
    }

    for _, bone in ipairs(bones) do
        for _, part in ipairs(partlist) do
            local locName = bone .. "[]" .. part
            local loc = group:getOrCreateLocation(locName)
            loc:setAttachmentName(locName)
        end
    end
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(registerGaelLocations)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(registerGaelLocations)
end
registerGaelLocations()
