windows = nil
lastX = 100
lastY = 100

AWCWF_ATTACHMENT_SLOT_BASE = 40
AWCWF_ATTACHMENT_SLOT_SIZE = 60
AWCWF_ATTACHMENT_SLOT_OFFSET = (AWCWF_ATTACHMENT_SLOT_SIZE - AWCWF_ATTACHMENT_SLOT_BASE) / 2

attachmentInfo = {{
    type = "Canon",
    x = 214,
    y = 280
}, {
    type = "Barrel",
    x = 90,
    y = (180 + 337) / 2
}, {
    type = "Laser",
    x = 634,
    y = 529
}, {
    type = "Light",
    x = 267,
    y = 529
}, {
    type = "Stool",
    x = 379,
    y = 598
}, {
    type = "Handguard",
    x = 442,
    y = 526
}, {
    type = "Grip",
    x = 506,
    y = 600
}, {
    type = "Skin",
    x = 472,
    y = 466
}, {
    type = "Misc",
    x = 342,
    y = 466
}, {
    type = "Scope",
    x = 442,
    y = 133
}, {
    type = "Mount",
    x = 442,
    y = 202
}, {
    type = "R_Scope",
    x = 472,
    y = 100
}, {
    type = "L_Scope",
    x = 633,
    y = 205
}, {
    type = "Sling",
    x = 608,
    y = 180
}, {
    type = "Stock",
    x = 913,
    y = 330
}, {
    type = "RecoilPad",
    x = 608,
    y = 280
}, {
    type = "Barrel_Shroud",
    x = 265,
    y = 420
}};
attachmentButtonsInfo = {{
    type = "Canon",
    x = 160,
    y = 280
}, {
    type = "Barrel",
    x = 40,
    y = (180 + 337) / 2
}, {
    x = 579,
    y = 525,
    method = "getLaser",
    type = "Laser"
}, {
    x = 326,
    y = 595,
    method = "getStool",
    type = "Stool"
}, {
    x = 212,
    y = 525,
    method = "getLight",
    type = "Light"
}, {
    x = 392,
    y = 525,
    method = "getHandguard",
    type = "Handguard"
}, {
    x = 453,
    y = 594,
    method = "getGrip",
    type = "Grip"
}, {
    x = 422,
    y = 466,
    method = "getSkin",
    type = "Skin"
}, {
    x = 292,
    y = 466,
    method = "getMisc",
    type = "Misc"
}, {
    x = 400,
    y = 120,
    method = "getScope",
    type = "Scope"
}, {
    x = 400,
    y = 195,
    method = "getMount",
    type = "Mount"
}, {
    x = 422,
    y = 100,
    method = "getR_Scope",
    type = "R_Scope"
}, {
    x = 576,
    y = 196,
    method = "getL_Scope",
    type = "L_Scope"
}, {
    x = 558,
    y = 180,
    method = "getSling",
    type = "Sling"
}, {
    x = 858,
    y = 330,
    method = "getStock",
    type = "Stock"
}, {
    x = 558,
    y = 280,
    method = "getRecoilPad",
    type = "RecoilPad"
}, {
    x = 210,
    y = 413,
    method = "getBarrel_Shroud",
    type = "Barrel_Shroud"
}};

function getWeaponAttackType(MainGun, table)
    if MainGun:getModData()["AttackType"] == nil then
        MainGun:getModData()["AttackType"] = table[1]
    end
    return MainGun:getModData()["AttackType"]
end

function SetWeaponAttackType(MainGun, selectType)
    -- Read-only isolation mode.
    return
end

function HasWeaponAttackType(MainGun)
    if MainGun:getModData()["AttackType"] == nil then
        return false
    end
    return MainGun:getModData()["AttackType"]
end

