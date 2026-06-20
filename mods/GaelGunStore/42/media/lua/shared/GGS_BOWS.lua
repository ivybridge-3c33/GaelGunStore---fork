GGS_BOWS = GGS_BOWS or {}

local function normalizeFullType(fullType)
    if not fullType then
        return nil
    end
    fullType = tostring(fullType)
    if fullType:sub(1, 10) == "Base.Base." then
        fullType = "Base." .. fullType:sub(11)
    end
    local colonPos = fullType:find(":", 1, true)
    if colonPos then
        local moduleName = fullType:sub(1, colonPos - 1)
        local itemName = fullType:sub(colonPos + 1)
        if moduleName ~= "" and itemName ~= "" then
            if moduleName:lower() == "base" then
                moduleName = "Base"
            end
            fullType = moduleName .. "." .. itemName
        end
    end
    if not fullType:find(".", 1, true) then
        fullType = "Base." .. fullType
    end
    return fullType
end

local weaponProfiles = {
    ["Base.Primitive_Bow"] = {
        id = "primitive_bow",
        class = "bow",
        requiresCock = false,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.arrow_wood",
            "Base.arrow_wood_floor",
            "Base.arrow_metal",
            "Base.arrow_metal_floor",
            "Base.arrow_carbon",
            "Base.arrow_carbon_floor",
            "Base.WoodShaft_Arrow"
        },
        defaultAmmoType = "Base.arrow_wood",
        defaultFlightVisualItem = "Base.arrow_wood_fly",
        defaultFloorItemType = "Base.arrow_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.22,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = 0.90,
        damageScale = 1.75,
        dropStartRange = 14.0,
        dropPerTile = 0.065,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "BowMuzzle",
        fallbackMuzzleModelScript = "Primitive_Bow",
        reloadDuration = 42
    },
    ["Base.Bow_hunting"] = {
        id = "Bow_hunting",
        class = "bow",
        requiresCock = false,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.arrow_wood",
            "Base.arrow_wood_floor",
            "Base.arrow_metal",
            "Base.arrow_metal_floor",
            "Base.arrow_carbon",
            "Base.arrow_carbon_floor",
            "Base.WoodShaft_Arrow"
        },
        defaultAmmoType = "Base.arrow_wood",
        defaultFlightVisualItem = "Base.arrow_wood_fly",
        defaultFloorItemType = "Base.arrow_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.22,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = 0.90,
        damageScale = 1.85,
        dropStartRange = 14.0,
        dropPerTile = 0.065,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "BowMuzzle",
        fallbackMuzzleModelScript = "Primitive_Bow",
        reloadDuration = 42
    },
    ["Base.Bow_crafted"] = {
        id = "Bow_crafted",
        class = "bow",
        requiresCock = false,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.arrow_wood",
            "Base.arrow_wood_floor",
            "Base.arrow_metal",
            "Base.arrow_metal_floor",
            "Base.arrow_carbon",
            "Base.arrow_carbon_floor",
            "Base.WoodShaft_Arrow"
        },
        defaultAmmoType = "Base.arrow_wood",
        defaultFlightVisualItem = "Base.arrow_wood_fly",
        defaultFloorItemType = "Base.arrow_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.22,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = 0.90,
        damageScale = 1.85,
        dropStartRange = 14.0,
        dropPerTile = 0.065,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "BowMuzzle",
        fallbackMuzzleModelScript = "Primitive_Bow",
        reloadDuration = 42
    },
    ["Base.Bow_compbound"] = {
        id = "Bow_compbound",
        class = "bow",
        requiresCock = false,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.arrow_wood",
            "Base.arrow_wood_floor",
            "Base.arrow_metal",
            "Base.arrow_metal_floor",
            "Base.arrow_carbon",
            "Base.arrow_carbon_floor",
            "Base.WoodShaft_Arrow"
        },
        defaultAmmoType = "Base.arrow_wood",
        defaultFlightVisualItem = "Base.arrow_wood_fly",
        defaultFloorItemType = "Base.arrow_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.22,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = 0.90,
        damageScale = 2.10,
        dropStartRange = 14.0,
        dropPerTile = 0.065,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "BowMuzzle",
        fallbackMuzzleModelScript = "Primitive_Bow",
        reloadDuration = 42
    },
    ["Base.Bow_compbound2"] = {
        id = "Bow_compbound2",
        class = "bow",
        requiresCock = false,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.arrow_wood",
            "Base.arrow_wood_floor",
            "Base.arrow_metal",
            "Base.arrow_metal_floor",
            "Base.arrow_carbon",
            "Base.arrow_carbon_floor",
            "Base.WoodShaft_Arrow"
        },
        defaultAmmoType = "Base.arrow_wood",
        defaultFlightVisualItem = "Base.arrow_wood_fly",
        defaultFloorItemType = "Base.arrow_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.22,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = 0.90,
        damageScale = 2.25,
        dropStartRange = 14.0,
        dropPerTile = 0.065,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "BowMuzzle",
        fallbackMuzzleModelScript = "Primitive_Bow",
        reloadDuration = 42
    },
    ["Base.Bow_medieval"] = {
        id = "Bow_medieval",
        class = "bow",
        requiresCock = false,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.arrow_wood",
            "Base.arrow_wood_floor",
            "Base.arrow_metal",
            "Base.arrow_metal_floor",
            "Base.arrow_carbon",
            "Base.arrow_carbon_floor",
            "Base.WoodShaft_Arrow"
        },
        defaultAmmoType = "Base.arrow_wood",
        defaultFlightVisualItem = "Base.arrow_wood_fly",
        defaultFloorItemType = "Base.arrow_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.22,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = 0.90,
        damageScale = 2.00,
        dropStartRange = 14.0,
        dropPerTile = 0.065,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "BowMuzzle",
        fallbackMuzzleModelScript = "Primitive_Bow",
        reloadDuration = 42
    },
    ["Base.Crossbow"] = {
        id = "crossbow",
        class = "crossbow",
        requiresCock = true,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.bolt_wood",
            "Base.bolt_wood_floor",
            "Base.bolt_metal",
            "Base.bolt_metal_floor",
            "Base.bolt_carbon",
            "Base.bolt_carbon_floor"
        },
        defaultAmmoType = "Base.bolt_wood",
        defaultFlightVisualItem = "Base.bolt_wood_fly",
        defaultFloorItemType = "Base.bolt_wood",
        speedTilesPerSec = 15.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.18,
        worldOzMax = 0.95,
        maxTargetDistance = 55.0,
        impactDamageRadius = 0.90,
        damageScale = 2.35,
        dropStartRange = 18.0,
        dropPerTile = 0.05,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "muzzle",
        fallbackMuzzleModelScript = "Crossbow",
        baseWeaponSprite = "Crossbow",
        readyWeaponSprite = "Crossbow_ready",
        cockDuration = 34,
        loadDuration = 32
    },
    ["Base.Crossbow_hunting"] = {
        id = "crossbow_hunting",
        class = "crossbow",
        requiresCock = true,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.bolt_wood",
            "Base.bolt_wood_floor",
            "Base.bolt_metal",
            "Base.bolt_metal_floor",
            "Base.bolt_carbon",
            "Base.bolt_carbon_floor"
        },
        defaultAmmoType = "Base.bolt_wood",
        defaultFlightVisualItem = "Base.bolt_wood_fly",
        defaultFloorItemType = "Base.bolt_wood",
        speedTilesPerSec = 15.5,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.18,
        worldOzMax = 0.95,
        maxTargetDistance = 58.0,
        impactDamageRadius = 0.90,
        damageScale = 2.45,
        dropStartRange = 18.0,
        dropPerTile = 0.05,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "muzzle",
        fallbackMuzzleModelScript = "Crossbow_hunting",
        baseWeaponSprite = "Crossbow_hunting",
        readyWeaponSprite = "Crossbow_hunting_ready",
        tensionPower = 9.0,
        cockDuration = 35,
        loadDuration = 33
    },
    ["Base.Crossbow_medieval"] = {
        id = "crossbow_medieval",
        class = "crossbow",
        requiresCock = true,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.bolt_wood",
            "Base.bolt_wood_floor",
            "Base.bolt_metal",
            "Base.bolt_metal_floor",
            "Base.bolt_carbon",
            "Base.bolt_carbon_floor"
        },
        defaultAmmoType = "Base.bolt_wood",
        defaultFlightVisualItem = "Base.bolt_wood_fly",
        defaultFloorItemType = "Base.bolt_wood",
        speedTilesPerSec = 15.5,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.18,
        worldOzMax = 0.95,
        maxTargetDistance = 60.0,
        impactDamageRadius = 0.95,
        damageScale = 2.50,
        dropStartRange = 19.0,
        dropPerTile = 0.05,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "muzzle",
        fallbackMuzzleModelScript = "Crossbow_medieval",
        baseWeaponSprite = "Crossbow_medieval",
        readyWeaponSprite = "Crossbow_medieval_ready",
        tensionPower = 10.0,
        cockDuration = 38,
        loadDuration = 35
    },
    ["Base.Crossbow_TenPoint"] = {
        id = "crossbow_tenpoint",
        class = "crossbow",
        requiresCock = true,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.bolt_wood",
            "Base.bolt_wood_floor",
            "Base.bolt_metal",
            "Base.bolt_metal_floor",
            "Base.bolt_carbon",
            "Base.bolt_carbon_floor"
        },
        defaultAmmoType = "Base.bolt_wood",
        defaultFlightVisualItem = "Base.bolt_wood_fly",
        defaultFloorItemType = "Base.bolt_wood",
        speedTilesPerSec = 17.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.16,
        worldOzMax = 0.95,
        maxTargetDistance = 68.0,
        impactDamageRadius = 0.95,
        damageScale = 2.85,
        dropStartRange = 22.0,
        dropPerTile = 0.04,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "muzzle",
        fallbackMuzzleModelScript = "Crossbow_TenPoint",
        baseWeaponSprite = "Crossbow_TenPoint",
        readyWeaponSprite = "Crossbow_TenPoint_ready",
        tensionPower = 12.0,
        cockDuration = 40,
        loadDuration = 34
    },
    ["Base.Crossbow_TenPoint_hunting"] = {
        id = "crossbow_tenpoint_hunting",
        class = "crossbow",
        requiresCock = true,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.bolt_wood",
            "Base.bolt_wood_floor",
            "Base.bolt_metal",
            "Base.bolt_metal_floor",
            "Base.bolt_carbon",
            "Base.bolt_carbon_floor"
        },
        defaultAmmoType = "Base.bolt_wood",
        defaultFlightVisualItem = "Base.bolt_wood_fly",
        defaultFloorItemType = "Base.bolt_wood",
        speedTilesPerSec = 16.5,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.16,
        worldOzMax = 0.95,
        maxTargetDistance = 65.0,
        impactDamageRadius = 0.95,
        damageScale = 2.70,
        dropStartRange = 21.0,
        dropPerTile = 0.042,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "muzzle",
        fallbackMuzzleModelScript = "Crossbow_TenPoint_hunting",
        baseWeaponSprite = "Crossbow_TenPoint_hunting",
        readyWeaponSprite = "Crossbow_TenPoint_hunting_ready",
        tensionPower = 11.0,
        cockDuration = 38,
        loadDuration = 33
    },
    ["Base.Crossbow_zhnets"] = {
        id = "crossbow_zhnets",
        class = "crossbow",
        requiresCock = true,
        visualPartSlot = "AMMO",
        ammoPriority = {
            "Base.bolt_wood",
            "Base.bolt_wood_floor",
            "Base.bolt_metal",
            "Base.bolt_metal_floor",
            "Base.bolt_carbon",
            "Base.bolt_carbon_floor"
        },
        defaultAmmoType = "Base.bolt_wood",
        defaultFlightVisualItem = "Base.bolt_wood_fly",
        defaultFloorItemType = "Base.bolt_wood",
        speedTilesPerSec = 16.0,
        minFlight = 0.18,
        maxFlight = 1.40,
        startZBias = 0.72,
        arcZ = 0.17,
        worldOzMax = 0.95,
        maxTargetDistance = 62.0,
        impactDamageRadius = 0.95,
        damageScale = 2.60,
        dropStartRange = 20.0,
        dropPerTile = 0.045,
        groundImpactEpsilon = 0.04,
        muzzleAttachment = "muzzle",
        fallbackMuzzleModelScript = "Crossbow_zhnets",
        baseWeaponSprite = "Crossbow_zhnets",
        readyWeaponSprite = "Crossbow_zhnets_ready",
        tensionPower = 11.0,
        cockDuration = 36,
        loadDuration = 34
    }
}

local ammoProfiles = {
    ["Base.arrow_wood"] = {
        ammoClass = "arrow",
        sharpness = 0.90,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.08,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.arrow_wood_fly",
        floorItemType = "Base.arrow_wood",
        weaponPart = "Base.AMMO_arrow_wood_part"
    },
    ["Base.arrow_metal"] = {
        ammoClass = "arrow",
        sharpness = 1.10,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.10,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.arrow_metal_fly",
        floorItemType = "Base.arrow_metal",
        weaponPart = "Base.AMMO_arrow_metal_part"
    },
    ["Base.arrow_metal_floor"] = {
        ammoClass = "arrow",
        sharpness = 1.10,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.10,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.arrow_metal_fly",
        floorItemType = "Base.arrow_metal",
        weaponPart = "Base.AMMO_arrow_metal_part"
    },
    ["Base.arrow_carbon"] = {
        ammoClass = "arrow",
        sharpness = 1.25,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.06,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.arrow_carbon_fly",
        floorItemType = "Base.arrow_carbon",
        weaponPart = "Base.AMMO_arrow_carbon_part"
    },
    ["Base.arrow_carbon_floor"] = {
        ammoClass = "arrow",
        sharpness = 1.25,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.06,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.arrow_carbon_fly",
        floorItemType = "Base.arrow_carbon",
        weaponPart = "Base.AMMO_arrow_carbon_part"
    },
    ["Base.bolt_wood"] = {
        ammoClass = "bolt",
        sharpness = 1.00,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.09,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.bolt_wood_fly",
        floorItemType = "Base.bolt_wood",
        weaponPart = "Base.AMMO_bolt_wood_part"
    },
    ["Base.bolt_wood_floor"] = {
        ammoClass = "bolt",
        sharpness = 1.00,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.09,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.bolt_wood_fly",
        floorItemType = "Base.bolt_wood",
        weaponPart = "Base.AMMO_bolt_wood_part"
    },
    ["Base.bolt_metal"] = {
        ammoClass = "bolt",
        sharpness = 1.20,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.11,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.bolt_metal_fly",
        floorItemType = "Base.bolt_metal",
        weaponPart = "Base.AMMO_bolt_metal_part"
    },
    ["Base.bolt_metal_floor"] = {
        ammoClass = "bolt",
        sharpness = 1.20,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.11,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.bolt_metal_fly",
        floorItemType = "Base.bolt_metal",
        weaponPart = "Base.AMMO_bolt_metal_part"
    },
    ["Base.bolt_carbon"] = {
        ammoClass = "bolt",
        sharpness = 1.35,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.07,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.bolt_carbon_fly",
        floorItemType = "Base.bolt_carbon",
        weaponPart = "Base.AMMO_bolt_carbon_part"
    },
    ["Base.bolt_carbon_floor"] = {
        ammoClass = "bolt",
        sharpness = 1.35,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.07,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.bolt_carbon_fly",
        floorItemType = "Base.bolt_carbon",
        weaponPart = "Base.AMMO_bolt_carbon_part"
    },
    ["Base.arrow_wood_floor"] = {
        ammoClass = "arrow",
        sharpness = 0.90,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.08,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.arrow_wood_fly",
        floorItemType = "Base.arrow_wood",
        weaponPart = "Base.AMMO_arrow_wood_part"
    },
    ["Base.WoodShaft_Arrow"] = {
        ammoClass = "arrow",
        sharpness = 0.90,
        impactImpulse = 0.01,
        hitReaction = "arrow_light",
        mass = 0.08,
        flightYawOffset = 0.0,
        flightVisualZOffset = 0.0,
        flightVisualItemType = "Base.Arrow_fly",
        floorItemType = "Base.WoodShaft_Arrow",
        weaponPart = "Base.AMMO_arrow_wood_part"
    }
}

for fullType, profile in pairs(weaponProfiles) do
    local normalized = normalizeFullType(fullType)
    if normalized ~= fullType then
        weaponProfiles[normalized] = profile
    end
    if profile and profile.ammoPriority then
        for i = 1, #profile.ammoPriority do
            profile.ammoPriority[i] = normalizeFullType(profile.ammoPriority[i])
        end
    end
    if profile and profile.defaultAmmoType then
        profile.defaultAmmoType = normalizeFullType(profile.defaultAmmoType)
    end
    if profile and profile.defaultFlightVisualItem then
        profile.defaultFlightVisualItem = normalizeFullType(profile.defaultFlightVisualItem)
    end
    if profile and profile.defaultFloorItemType then
        profile.defaultFloorItemType = normalizeFullType(profile.defaultFloorItemType)
    end
end

for fullType, profile in pairs(ammoProfiles) do
    local normalized = normalizeFullType(fullType)
    if normalized ~= fullType then
        ammoProfiles[normalized] = profile
    end
    if profile and profile.flightVisualItemType then
        profile.flightVisualItemType = normalizeFullType(profile.flightVisualItemType)
    end
    if profile and profile.floorItemType then
        profile.floorItemType = normalizeFullType(profile.floorItemType)
    end
    if profile and profile.weaponPart then
        profile.weaponPart = normalizeFullType(profile.weaponPart)
    end
end

GGS_BOWS.Weapons = weaponProfiles
GGS_BOWS.Ammo = ammoProfiles

function GGS_BOWS.normalizeFullType(fullType)
    return normalizeFullType(fullType)
end

function GGS_BOWS.getWeaponProfile(fullType)
    return weaponProfiles[normalizeFullType(fullType)]
end

function GGS_BOWS.getAmmoProfile(fullType)
    return ammoProfiles[normalizeFullType(fullType)]
end
