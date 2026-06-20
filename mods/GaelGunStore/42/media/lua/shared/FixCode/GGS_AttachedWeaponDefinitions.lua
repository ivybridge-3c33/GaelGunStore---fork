require "Definitions/AttachedWeaponDefinitions"

if _G.__GGS_ATTACHED_WEAPON_DEFS_DONE then
    return
end

_G.__GGS_ATTACHED_WEAPON_DEFS_DONE = true

local LOG_PREFIX = "[GGS AttachedWeaponDefinitions] "

local function log(message)
    print(LOG_PREFIX .. tostring(message))
end

local function findScriptItem(fullType)
    if not fullType then
        return nil
    end

    if getScriptManager then
        local okManager, manager = pcall(getScriptManager)
        if okManager and manager then
            if manager.FindItem then
                local okItem, item = pcall(manager.FindItem, manager, fullType)
                if okItem and item then
                    return item
                end
            end
            if manager.getItem then
                local okItem, item = pcall(manager.getItem, manager, fullType)
                if okItem and item then
                    return item
                end
            end
        end
    end

    if ScriptManager and ScriptManager.instance then
        local manager = ScriptManager.instance
        if manager.FindItem then
            local okItem, item = pcall(manager.FindItem, manager, fullType)
            if okItem and item then
                return item
            end
        end
        if manager.getItem then
            local okItem, item = pcall(manager.getItem, manager, fullType)
            if okItem and item then
                return item
            end
        end
    end

    return nil
end

local function isItemAvailable(fullType)
    return findScriptItem(fullType) ~= nil
end

local function filteredWeapons(weapons)
    local result = {}

    for i = 1, #weapons do
        local weapon = weapons[i]
        if isItemAvailable(weapon) then
            result[#result + 1] = weapon
        else
            log("Arma omitida en AttachedWeaponDefinitions: " .. tostring(weapon))
        end
    end

    return result
end

local function replaceWeapons(definitionName, weapons)
    if not AttachedWeaponDefinitions then
        return false
    end

    local definition = AttachedWeaponDefinitions[definitionName]
    if not definition then
        log("Definicion no encontrada: " .. tostring(definitionName))
        return false
    end

    local filtered = filteredWeapons(weapons)
    if #filtered == 0 then
        log("Sin armas GGS validas para " .. tostring(definitionName) .. "; se conserva la lista original")
        return false
    end

    definition.weapons = filtered
    return true
end

local policePistols = {
    "Base.Glock23",
    "Base.P228",
    "Base.P220",
    "Base.CZ75",
    "Base.USP45",
    "Base.M9_Samurai",
}

local detectivePistols = {
    "Base.Glock43",
    "Base.CZ75",
    "Base.P228",
    "Base.P220",
    "Base.FNX45",
}

local armyPistols = {
    "Base.M9_Samurai",
    "Base.USP45",
    "Base.HKMK23",
    "Base.FNX45",
    "Base.P220",
}

local swatPistols = {
    "Base.Glock23",
    "Base.FNX45",
    "Base.HKMK23",
    "Base.USP45",
    "Base.CZ75",
}

local policeShotguns = {
    "Base.Remington870",
    "Base.Mossber500",
    "Base.Mossber590",
    "Base.BenelliM4",
    "Base.QBS09",
}

local swatLongGuns = {
    "Base.M4",
    "Base.HK416",
    "Base.DDM4",
    "Base.MP5",
    "Base.MP5SD",
    "Base.BenelliM4",
}

local armyRifles = {
    "Base.M4",
    "Base.M16A2",
    "Base.HK416",
    "Base.DDM4",
    "Base.AR15",
    "Base.AK47",
}

local hunterLongGuns = {
    "Base.HuntingRifle",
    "Base.VarmintRifle",
    "Base.M40",
    "Base.Remington121",
    "Base.RemingtonModel8",
    "Base.Mossber500",
    "Base.Remington870",
    "Base.Remington1100",
}

local crimeLongGuns = {
    "Base.MP5K",
    "Base.MP5",
    "Base.Remington870_Short",
    "Base.Mossber500",
    "Base.ShotgunSawnoff",
    "Base.DoubleBarrelShotgun",
}

local survivalistLongGuns = {
    "Base.AK47",
    "Base.AR15",
    "Base.M4",
    "Base.M16A2",
    "Base.HuntingRifle",
    "Base.VarmintRifle",
    "Base.Mossber590",
    "Base.Remington870",
}

local alreadyApplied = false

local function applyAttachedWeaponDefinitionsPatch()
    if alreadyApplied then
        return
    end

    local patched = 0

    if replaceWeapons("handgunHolster", detectivePistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterShoulder", detectivePistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterPolice", policePistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterAnkle", policePistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterDetective", detectivePistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterArmy", armyPistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterRanger", policePistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterSheriff", policePistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterSWAT", swatPistols) then patched = patched + 1 end
    if replaceWeapons("handgunHolsterGhillie", swatPistols) then patched = patched + 1 end

    if replaceWeapons("shotgunPolice", policeShotguns) then patched = patched + 1 end
    if replaceWeapons("gunOnBackSWAT", swatLongGuns) then patched = patched + 1 end
    if replaceWeapons("assaultRifleOnBack", armyRifles) then patched = patched + 1 end
    if replaceWeapons("assaultRifleArmyOnBack", armyRifles) then patched = patched + 1 end
    if replaceWeapons("gunOnBackHunter", hunterLongGuns) then patched = patched + 1 end
    if replaceWeapons("gunOnBackBagSurvivalist", survivalistLongGuns) then patched = patched + 1 end
    if replaceWeapons("huntingRifleOnBack", hunterLongGuns) then patched = patched + 1 end
    if replaceWeapons("rifleOnBackGhillie", hunterLongGuns) then patched = patched + 1 end
    if replaceWeapons("gunOnBackCrime", crimeLongGuns) then patched = patched + 1 end
    if replaceWeapons("gunOnBackBountyHunter", crimeLongGuns) then patched = patched + 1 end

    if patched > 0 then
        alreadyApplied = true
    end

    log("Definiciones de armas en zombies parcheadas: " .. tostring(patched))
end

applyAttachedWeaponDefinitionsPatch()

if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(applyAttachedWeaponDefinitionsPatch)
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(applyAttachedWeaponDefinitionsPatch)
end
