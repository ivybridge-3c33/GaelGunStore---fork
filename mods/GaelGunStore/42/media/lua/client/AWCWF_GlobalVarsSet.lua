-- MagazineSet
AWCWF_MagazineTypeToPart = AWCWF_MagazineTypeToPart or {}
-- WeaponMagazineType
AWCWF_WeaponMagazineType = AWCWF_WeaponMagazineType or {}
-- WeaponAttackType
AWCWF_WeaponAttackType = AWCWF_WeaponAttackType or {}
-- Attachment visibility configuration
AWCWF_GunAllowAttachments = AWCWF_GunAllowAttachments or {}
AWCWF_AttAllowAttachments = AWCWF_AttAllowAttachments or {}
AWCWF_AttSlotExclusions = AWCWF_AttSlotExclusions or {}
-- Example:
-- AWCWF_AttSlotExclusions["Base.AR15_handguard"] = {
--     {"Grip", "Stool"}
-- }
local defaultSlotConflictRules = {
    {"Grip", "Stool"}
}

AWCWF_SlotConflictRules = AWCWF_SlotConflictRules or defaultSlotConflictRules

local function ensureSlotConflictPair(slotA, slotB)
    AWCWF_SlotConflictRules = AWCWF_SlotConflictRules or {}
    for _, pair in ipairs(AWCWF_SlotConflictRules) do
        if type(pair) == "table" then
            local a, b = pair[1], pair[2]
            if (a == slotA and b == slotB) or (a == slotB and b == slotA) then
                return
            end
        end
    end
    table.insert(AWCWF_SlotConflictRules, {slotA, slotB})
end

-- Prevent using a Mount together with an L_Scope on any weapon
ensureSlotConflictPair("Mount", "L_Scope")
-- AllowModDataTable
AWCWF_AllowModDataTable = AWCWF_AllowModDataTable or {}
AWCWF_AllowModDataTable["ItemAffix"] = true
AWCWF_AllowModDataTable["ItemAffixIdentify"] = true
AWCWF_AllowModDataTable["UpgradeLevel"] = true
AWCWF_AllowModDataTable["weaponpart"] = true
AWCWF_AllowModDataTable["NowLightSet"] = true
-- Weapon with anim
AWCWF_WeaponWithBoltAnim = AWCWF_WeaponWithBoltAnim or {}
-- BayonetSet

AWCWF_WeaponMustPartList = AWCWF_WeaponMustPartList or {}
-- AWCWF_WeaponMustPartList["HK416_cat"] = {
--     Laser = {
--         MustInstall = true,
--         HW_SH = {
--             SpawnPart = true,
--             FullType = "Base.HW_SH",
--             Chance = 70
--         }
--     }
-- }

AWCWF_BayonetSet = AWCWF_BayonetSet or {}

AWCWF_BayonetSet.Parts = AWCWF_BayonetSet.Parts or {}
AWCWF_BayonetSet.Parts.Stool = AWCWF_BayonetSet.Parts.Stool or {}
AWCWF_BayonetSet.Parts.Stool["bayonet_cat"] = true

AWCWF_SilencerSet = AWCWF_SilencerSet or {}
AWCWF_SilencerSet.Canon = AWCWF_SilencerSet.Canon or {}
-- AWCWF_SilencerSet.Canon["silencer_cat"] = {
--     SoundVolumeModifier = 0.3,
--     SoundRadiusModifier = 0.3,
--     SilenceSound = "Silencer_Silence"
-- }

-- LaserSet
AWCWF_LaserAndGunLightSet = AWCWF_LaserAndGunLightSet or {}

AWCWF_LaserAndGunLightSwitchSet = {"nil", "Laser", "GunLight", "LaserAndGunLight"} -- do not Edit this

-- Skin
AWCWF_WeaponSkin = AWCWF_WeaponSkin or {}

-- Stool_Grenadelauncher 

AWCWF_Stool_Grenadelauncher = AWCWF_Stool_Grenadelauncher or {}
-- AWCWF_Stool_Grenadelauncher["M203_cat"] = {
--     EmptyType = "Base.M203_cat_empty",
--     LaunchSound = "LauncherFire",
--     ExplosionDamage = 1,
--     ExplosionRange = 4,
--     ExplosionSound = "PipeBombExplode"

-- }
-- AWCWF_Stool_Grenadelauncher["M203_cat_empty"] = {
--     AmmoType = "GrenadeAmmo",
--     LoadSound = "LauncherReload",
--     LoadType = "Base.M203_cat"
-- }
