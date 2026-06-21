--[[
    Sistema de upgrades garantizados para GaelGunStore.
    Permite definir listas reutilizables de piezas y una lÃ³gica por arma que
    determina quÃ© categorÃ­as son obligatorias y cuÃ¡les son opcionales con probabilidad.
]]

local historicMode = GGS_HistoricModeBlacklist
do
    local ok, module = pcall(require, "GGS_HistoricModeBlacklist")
    if ok then
        historicMode = module or GGS_HistoricModeBlacklist
    end
end

GGSWeaponUpgrades = GGSWeaponUpgrades or {}
GGSWeaponUpgrades.Lists = GGSWeaponUpgrades.Lists or {}
GGSWeaponUpgrades.Logic = GGSWeaponUpgrades.Logic or {}
GGSWeaponUpgrades.Pools = GGSWeaponUpgrades.Pools or {}
GGSWeaponUpgrades.WeaponSlots = GGSWeaponUpgrades.WeaponSlots or {}
GGSWeaponUpgrades.Debug = GGSWeaponUpgrades.Debug == true


local prob_barrel_shroud_bipod = SandboxVars.GGSGS.barrel_shroud_bipod * 0.01
local prob_canon_pistol_sup = SandboxVars.GGSGS.canon_pistol_sup * 0.01
local prob_canon_revolver_type = SandboxVars.GGSGS.canon_revolver_type * 0.01
local prob_canon_rifle_sup = SandboxVars.GGSGS.canon_rifle_sup * 0.01
local prob_canon_shotgun_sup = SandboxVars.GGSGS.canon_shotgun_sup * 0.01
local prob_canon_smg_sup = SandboxVars.GGSGS.canon_smg_sup * 0.01
local prob_grip = SandboxVars.GGSGS.grip * 0.01
local prob_grip_grip_normal = SandboxVars.GGSGS.grip_grip_normal * 0.01
local prob_handguard = SandboxVars.GGSGS.handguard * 0.01
local prob_handguard_ak_hg = SandboxVars.GGSGS.handguard_ak_hg * 0.01
local prob_handguard_ar_hg = SandboxVars.GGSGS.handguard_ar_hg * 0.01
local prob_handguard_svd_hg = SandboxVars.GGSGS.handguard_svd_hg * 0.01
local prob_handguard_win_hg = SandboxVars.GGSGS.handguard_win_hg * 0.01
local prob_l_scope_ak_mount_scope = SandboxVars.GGSGS.l_scope_ak_mount_scope * 0.01
local prob_laser_pistol_laser = SandboxVars.GGSGS.laser_pistol_laser * 0.01
local prob_laser_rifle_laser = SandboxVars.GGSGS.laser_rifle_laser * 0.01
local prob_light_pistol_light = SandboxVars.GGSGS.light_pistol_light * 0.01
local prob_light_rifle_light = SandboxVars.GGSGS.light_rifle_light * 0.01
local prob_misc = SandboxVars.GGSGS.misc * 0.01
local prob_mount = SandboxVars.GGSGS.mount * 0.01
local prob_mount_ak_mount = SandboxVars.GGSGS.mount_ak_mount * 0.01
local prob_mount_rifle_mount = SandboxVars.GGSGS.mount_rifle_mount * 0.01
local prob_mount_shotgun_mount = SandboxVars.GGSGS.mount_shotgun_mount * 0.01
local prob_scope_large_scope = SandboxVars.GGSGS.scope_large_scope * 0.01
local prob_scope_medium_scope = SandboxVars.GGSGS.scope_medium_scope * 0.01
local prob_scope_mini_scope = SandboxVars.GGSGS.scope_mini_scope * 0.01
local prob_stock_ak_type = SandboxVars.GGSGS.stock_ak_type * 0.01
local prob_stock_ar_type = SandboxVars.GGSGS.stock_ar_type * 0.01
local prob_stock_mosin_type = SandboxVars.GGSGS.stock_mosin_type * 0.01
local prob_stock_pistol_type = SandboxVars.GGSGS.stock_pistol_type * 0.01
local prob_stock_revolver_type = SandboxVars.GGSGS.stock_revolver_type * 0.01
local prob_stock_scar_type = SandboxVars.GGSGS.stock_scar_type * 0.01
local prob_stock_shotgun_type = SandboxVars.GGSGS.stock_shotgun_type * 0.01
local prob_stock_svd_vss_type = SandboxVars.GGSGS.stock_svd_vss_type * 0.01
local prob_stock_win_type = SandboxVars.GGSGS.stock_win_type * 0.01
local prob_stool_ak_gl = SandboxVars.GGSGS.stool_ak_gl * 0.01
local prob_stool_ar_gl = SandboxVars.GGSGS.stool_ar_gl * 0.01
local prob_stool_scar_gl = SandboxVars.GGSGS.stool_scar_gl * 0.01


local function logDebug(message)
    if GGSWeaponUpgrades.Debug then
        print("[GGS WeaponUpgrades] " .. tostring(message))
    end
end

local DEFAULT_PART_CONDITION_MAX = 100

local function getSandboxBoolean(key, defaultValue)
    local root = SandboxVars or nil
    if not root then
        return defaultValue
    end

    local value = nil
    if root.GGSGS then
        value = root.GGSGS[key]
    end
    if value == nil and root.GGS then
        value = root.GGS[key]
    end
    if value == nil then
        return defaultValue
    end

    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end
    if type(value) == "string" then
        local lower = value:lower()
        return lower == "true" or lower == "1" or lower == "yes"
    end

    return defaultValue
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function isWeaponPartItem(item)
    if not item then
        return false
    end
    if instanceof(item, "WeaponPart") then
        return true
    end
    return false
end

local function setPartConditionPolicy(part, forceMax)
    if not isWeaponPartItem(part) then
        return
    end

    local maxCondition = part.getConditionMax and part:getConditionMax() or 0
    if maxCondition <= 0 and part.setConditionMax then
        maxCondition = DEFAULT_PART_CONDITION_MAX
        part:setConditionMax(maxCondition)
    end
    if maxCondition <= 0 then
        return
    end

    local condition = part.getCondition and part:getCondition() or maxCondition
    if condition <= 0 then
        condition = maxCondition
    end
    condition = clamp(condition, 0, maxCondition)

    if forceMax then
        condition = maxCondition
    end

    if part.setCondition then
        part:setCondition(condition)
    end
end

local function shouldForceMaxPartCondition()
    return getSandboxBoolean("weaponpart_loot_max_condition", true)
end

local function shouldRandomizePartCondition()
    if shouldForceMaxPartCondition() then
        return false
    end
    return getSandboxBoolean("weaponpart_random_condition", false)
end

local function applyRandomPartCondition(part)
    if not isWeaponPartItem(part) then
        return
    end
    if not shouldRandomizePartCondition() then
        return
    end

    local modData = part.getModData and part:getModData() or nil
    if modData and modData.GGS_RandomConditionDone then
        return
    end

    local maxCondition = part.getConditionMax and part:getConditionMax() or 0
    if maxCondition <= 1 then
        if modData then
            modData.GGS_RandomConditionDone = true
        end
        return
    end

    local randomCondition = ZombRand(maxCondition) + 1
    if part.setCondition then
        part:setCondition(randomCondition)
    end
    if modData then
        modData.GGS_RandomConditionDone = true
    end
end

local function applyWeaponPartConditionPolicy(weapon, forceMax)
    if not weapon or not weapon.getAllWeaponParts then
        return
    end
    local parts = weapon:getAllWeaponParts()
    if not parts then
        return
    end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        setPartConditionPolicy(part, forceMax)
    end
end

local function applyRandomWeaponPartCondition(weapon)
    if not weapon or not weapon.getAllWeaponParts then
        return
    end
    if not shouldRandomizePartCondition() then
        return
    end

    local parts = weapon:getAllWeaponParts()
    if not parts then
        return
    end

    for i = 0, parts:size() - 1 do
        applyRandomPartCondition(parts:get(i))
    end
end

local function applyRandomWeaponCondition(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then
        return
    end
    if not weapon.isRanged or not weapon:isRanged() then
        return
    end
    if not getSandboxBoolean("weapon_random_condition", false) then
        return
    end

    local modData = weapon:getModData()
    if modData.GGS_RandomConditionDone then
        return
    end

    local maxCondition = weapon:getConditionMax() or 0
    if maxCondition <= 1 then
        modData.GGS_RandomConditionDone = true
        return
    end

    weapon:setCondition(ZombRand(maxCondition) + 1)
    modData.GGS_RandomConditionDone = true
end

logDebug("Inicializando sistema de upgrades")

local function spawnPartItem(fullType)
    if not fullType then
        return nil
    end

    local item
    if instanceItem then
        local ok, created = pcall(instanceItem, fullType)
        if ok then
            item = created
        end
    end

    if not item and InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, created = pcall(InventoryItemFactory.CreateItem, fullType)
        if ok then
            item = created
        end
    end

    if item and not instanceof(item, "WeaponPart") then
        return nil
    end
    return item
end

local partTypeCache = {}
local listPartTypeCache = {}
local partMountCache = {}

local function isHistoricLootBlocked(fullType)
    return historicMode and historicMode.shouldBlock and historicMode.shouldBlock(fullType)
end

local function resolvePartType(fullType)
    if partTypeCache[fullType] ~= nil then
        return partTypeCache[fullType]
    end

    local item = spawnPartItem(fullType)
    if not item then
        logDebug("No se pudo instanciar la pieza " .. tostring(fullType))
        partTypeCache[fullType] = false
        return false
    end

    local partType = item:getPartType()
    partTypeCache[fullType] = partType or false
    return partTypeCache[fullType]
end

local function mountOnContains(mountOn, weaponType)
    if not mountOn or not weaponType or weaponType == "" then
        return false
    end

    if mountOn.contains then
        local ok, contains = pcall(function()
            return mountOn:contains(weaponType)
        end)
        if ok and contains then
            return true
        end
    end

    if type(mountOn) == "string" then
        for token in mountOn:gmatch("[^;]+") do
            token = token:match("^%s*(.-)%s*$")
            if token == weaponType then
                return true
            end
        end
    end

    return false
end

local function isPartCompatibleWithWeapon(fullType, weapon)
    if not fullType or not weapon then
        return false
    end

    local weaponFullType = weapon.getFullType and weapon:getFullType() or nil
    if not weaponFullType then
        return false
    end

    local cacheKey = fullType .. "|" .. weaponFullType
    if partMountCache[cacheKey] ~= nil then
        return partMountCache[cacheKey]
    end

    local partItem = spawnPartItem(fullType)
    if not partItem or not partItem.getMountOn then
        partMountCache[cacheKey] = false
        return false
    end

    local mountOn = partItem:getMountOn()
    local compatible = mountOnContains(mountOn, weaponFullType)
    if not compatible and weapon.getType then
        compatible = mountOnContains(mountOn, weapon:getType())
    end

    partMountCache[cacheKey] = compatible
    return compatible
end

local function getListEntries(listName)
    local list = GGSWeaponUpgrades.Lists[listName]
    if not list then
        return nil
    end

    if list.items then
        return list.items
    end

    return list
end

local function getListPartTypes(listName)
    if listPartTypeCache[listName] ~= nil then
        return listPartTypeCache[listName]
    end

    local entries = getListEntries(listName)
    if not entries then
        listPartTypeCache[listName] = false
        return nil
    end

    local summary = {}
    for _, fullType in ipairs(entries) do
        if not isHistoricLootBlocked(fullType) then
            local partType = resolvePartType(fullType)
            if partType then
                summary[partType] = true
            end
        end
    end

    listPartTypeCache[listName] = summary
    return summary
end

local function buildCandidates(listName, usedPartTypes, weapon)
    local entries = getListEntries(listName)
    if not entries then
        return nil
    end

    local candidates = {}
    for _, fullType in ipairs(entries) do
        if not isHistoricLootBlocked(fullType) then
            local partType = resolvePartType(fullType)
            if partType and not usedPartTypes[partType] and isPartCompatibleWithWeapon(fullType, weapon) then
                table.insert(candidates, {fullType = fullType, partType = partType})
            end
        end
    end

    return candidates
end

local function pickCandidate(listName, usedPartTypes, weapon)
    local candidates = buildCandidates(listName, usedPartTypes, weapon)
    if not candidates or #candidates == 0 then
        return nil
    end
    local index = ZombRand(#candidates) + 1
    return candidates[index]
end

local function roll(probability)
    if probability == nil then
        return true
    end
    if probability >= 1 then
        return true
    end
    if probability <= 0 then
        return false
    end
    return (ZombRand(100000) / 100000) < probability
end

local MOUNT_LISTS = {
    mount = true,
    mount_ak_mount = true,
    mount_rifle_mount = true,
    mount_shotgun_mount = true,
}

local SCOPE_LISTS = {
    scope_large_scope = true,
    scope_medium_scope = true,
    scope_mini_scope = true,
}

local GRIP_LISTS = {
    grip = true,
    grip_grip_normal = true,
}

local function isHandguardList(listName)
    return type(listName) == "string" and listName:sub(1, 9) == "handguard"
end

local function addUnique(target, listName)
    for _, existing in ipairs(target) do
        if existing == listName then
            return
        end
    end
    table.insert(target, listName)
end

local function getSandboxProbability(listName)
    if not listName or not SandboxVars or not SandboxVars.GGSGS then
        return nil
    end
    local raw = SandboxVars.GGSGS[listName]
    if raw == nil then
        return nil
    end
    return raw * 0.01
end

local function getStepProbability(step)
    if not step then
        return nil
    end
    if step.useStepProbOnly then
        return step.prob
    end
    local sandboxProb = getSandboxProbability(step.list)
    if sandboxProb ~= nil then
        return sandboxProb
    end
    return step.prob
end

local function listHasAnyUsedPartType(listName, usedPartTypes)
    local partTypes = getListPartTypes(listName)
    if not partTypes then
        return false
    end

    for partType in pairs(partTypes) do
        if usedPartTypes[partType] then
            return true
        end
    end
    return false
end

local function buildAutoDependencyContext(logic)
    local context = {
        mountLists = {},
        handguardLists = {},
    }

    for _, step in ipairs(logic) do
        local listName = step.list
        if listName then
            if MOUNT_LISTS[listName] then
                addUnique(context.mountLists, listName)
            end
            if isHandguardList(listName) then
                addUnique(context.handguardLists, listName)
            end
        end
    end

    return context
end

local function dependenciesMet(step, dependencyContext, usedPartTypes)
    local requiresAll = step.requiresAllLists
    local requiresAny = {}

    if step.requiresAnyLists then
        for _, listName in ipairs(step.requiresAnyLists) do
            addUnique(requiresAny, listName)
        end
    end

    if step.autoDependencies ~= false then
        if SCOPE_LISTS[step.list] and #dependencyContext.mountLists > 0 then
            for _, listName in ipairs(dependencyContext.mountLists) do
                addUnique(requiresAny, listName)
            end
        end
        if GRIP_LISTS[step.list] and #dependencyContext.handguardLists > 0 then
            for _, listName in ipairs(dependencyContext.handguardLists) do
                addUnique(requiresAny, listName)
            end
        end
    end

    if requiresAll then
        for _, listName in ipairs(requiresAll) do
            if not listHasAnyUsedPartType(listName, usedPartTypes) then
                return false, "falta '" .. tostring(listName) .. "'"
            end
        end
    end

    if #requiresAny > 0 then
        local anySatisfied = false
        for _, listName in ipairs(requiresAny) do
            if listHasAnyUsedPartType(listName, usedPartTypes) then
                anySatisfied = true
                break
            end
        end
        if not anySatisfied then
            return false, "dependencias no cumplidas"
        end
    end

    return true, nil
end

local function getStepPriority(step)
    if not step or not step.list then
        return 1
    end
    if MOUNT_LISTS[step.list] or isHandguardList(step.list) then
        return 0
    end
    return 1
end

local function buildExecutionPlan(logic)
    local plan = {}
    for index, step in ipairs(logic) do
        table.insert(plan, {
            index = index,
            step = step,
            priority = getStepPriority(step),
        })
    end

    table.sort(plan, function(a, b)
        if a.priority == b.priority then
            return a.index < b.index
        end
        return a.priority < b.priority
    end)

    return plan
end

local function countMissingForRequiredStep(step, usedPartTypes)
    local desired = step.count or 1
    local partTypes = getListPartTypes(step.list)
    if not partTypes then
        return desired
    end

    for partType in pairs(partTypes) do
        if desired <= 0 then
            break
        end
        if usedPartTypes[partType] then
            desired = desired - 1
        end
    end

    if desired < 0 then
        desired = 0
    end
    return desired
end

local function attachPart(weapon, candidate, usedPartTypes)
    if not isPartCompatibleWithWeapon(candidate.fullType, weapon) then
        logDebug(("Pieza incompatible omitida: %s no monta en %s"):format(tostring(candidate.fullType), weapon:getFullType()))
        return false
    end

    local partItem = spawnPartItem(candidate.fullType)
    if not partItem then
        logDebug("No se pudo crear " .. tostring(candidate.fullType) .. " para " .. weapon:getFullType())
        return false
    end

    setPartConditionPolicy(partItem, shouldForceMaxPartCondition())
    applyRandomPartCondition(partItem)
    weapon:attachWeaponPart(nil, partItem)
    usedPartTypes[candidate.partType] = true
    logDebug(("Adjuntado %s a %s (%s)"):format(candidate.fullType, weapon:getFullType(), candidate.partType))
    return true
end

local function getWeaponLogic(weapon)
    local fullType = weapon:getFullType()
    if GGSWeaponUpgrades.Logic[fullType] then
        return GGSWeaponUpgrades.Logic[fullType]
    end
    return GGSWeaponUpgrades.Logic[weapon:getType()]
end

local function gatherUsedPartTypes(weapon)
    local used = {}
    local modData = weapon:getModData()
    if modData and modData.weaponpart then
        for partType in pairs(modData.weaponpart) do
            used[partType] = true
        end
    end
    return used
end

local function getWeaponSlots(weapon)
    local fullType = weapon:getFullType()
    if GGSWeaponUpgrades.WeaponSlots[fullType] then
        return GGSWeaponUpgrades.WeaponSlots[fullType]
    end
    return GGSWeaponUpgrades.WeaponSlots[weapon:getType()]
end

local function tableHasAnyEntry(value)
    if type(value) ~= "table" then
        return false
    end
    for _ in pairs(value) do
        return true
    end
    return false
end

local function hasWeaponUpgradeConfig(weapon)
    local slots = getWeaponSlots(weapon)
    if tableHasAnyEntry(slots) then
        return true
    end
    local logic = getWeaponLogic(weapon)
    return logic and #logic > 0
end

local function getSlotPoolNames(slot)
    if slot.pools then
        return slot.pools
    end
    if slot.pool then
        return {slot.pool}
    end
    if slot.list then
        return {slot.list}
    end
    return nil
end

local function getPoolEntries(poolName)
    local pool = GGSWeaponUpgrades.Pools and GGSWeaponUpgrades.Pools[poolName] or nil
    if not pool then
        return getListEntries(poolName)
    end
    if pool.items then
        return pool.items
    end
    return pool
end

local function normalizePoolEntry(entry)
    if type(entry) == "string" then
        return entry, 1, nil
    end
    if type(entry) ~= "table" then
        return nil, 0, nil
    end

    local fullType = entry.item or entry.fullType or entry[1]
    local weight = tonumber(entry.weight or entry[2]) or 1
    if weight <= 0 then
        weight = 0
    end
    return fullType, weight, entry.partType
end

local function addCandidate(candidates, seen, fullType, partType, weight)
    if not fullType or seen[fullType] then
        return
    end
    seen[fullType] = true
    table.insert(candidates, {
        fullType = fullType,
        partType = partType,
        weight = weight > 0 and weight or 1,
    })
end

local function buildSlotCandidates(slot, usedPartTypes, weapon)
    local poolNames = getSlotPoolNames(slot)
    if not poolNames then
        return nil
    end

    local candidates = {}
    local seen = {}
    for _, poolName in ipairs(poolNames) do
        local entries = getPoolEntries(poolName)
        if entries then
            for _, entry in ipairs(entries) do
                local fullType, weight, entryPartType = normalizePoolEntry(entry)
                if fullType and weight > 0 and not isHistoricLootBlocked(fullType) then
                    local partType = entryPartType or resolvePartType(fullType)
                    if partType
                            and (not slot.partType or partType == slot.partType)
                            and not usedPartTypes[partType]
                            and isPartCompatibleWithWeapon(fullType, weapon) then
                        addCandidate(candidates, seen, fullType, partType, weight)
                    end
                end
            end
        end
    end

    return candidates
end

local function pickWeightedCandidate(candidates)
    if not candidates or #candidates == 0 then
        return nil
    end

    local totalWeight = 0
    for _, candidate in ipairs(candidates) do
        totalWeight = totalWeight + (tonumber(candidate.weight) or 1)
    end
    if totalWeight <= 0 then
        return candidates[ZombRand(#candidates) + 1]
    end

    local target = (ZombRand(100000) / 100000) * totalWeight
    local cursor = 0
    for _, candidate in ipairs(candidates) do
        cursor = cursor + (tonumber(candidate.weight) or 1)
        if target <= cursor then
            return candidate
        end
    end
    return candidates[#candidates]
end

local function hasAnyPartType(partTypes, usedPartTypes)
    if not partTypes then
        return true
    end
    for _, partType in ipairs(partTypes) do
        if usedPartTypes[partType] then
            return true
        end
    end
    return false
end

local function hasAllPartTypes(partTypes, usedPartTypes)
    if not partTypes then
        return true
    end
    for _, partType in ipairs(partTypes) do
        if not usedPartTypes[partType] then
            return false
        end
    end
    return true
end

local function slotDependenciesMet(slot, usedPartTypes, usedConflictGroups)
    if slot.conflictGroup and usedConflictGroups[slot.conflictGroup] then
        return false, "grupo en conflicto usado: " .. tostring(slot.conflictGroup)
    end
    if not hasAllPartTypes(slot.requiresAllPartTypes, usedPartTypes) then
        return false, "faltan PartTypes requeridos"
    end
    if slot.requiresAnyPartType and not hasAnyPartType(slot.requiresAnyPartType, usedPartTypes) then
        return false, "falta un PartType requerido"
    end
    return true, nil
end

local function getSlotProbability(slot)
    if slot.prob ~= nil then
        return slot.prob
    end
    if slot.probKey then
        return getSandboxProbability(slot.probKey)
    end
    if slot.list then
        return getSandboxProbability(slot.list)
    end
    return nil
end

local function mergeSlotStep(slot, step)
    local merged = {}
    for key, value in pairs(slot) do
        if key ~= "variants" and key ~= "steps" then
            merged[key] = value
        end
    end
    for key, value in pairs(step) do
        merged[key] = value
    end
    if not merged.conflictGroup then
        merged.conflictGroup = slot.conflictGroup
    end
    return merged
end

local function applySlotStep(weapon, slot, usedPartTypes)
    local candidates = buildSlotCandidates(slot, usedPartTypes, weapon)
    local candidate = pickWeightedCandidate(candidates)
    if not candidate then
        return false
    end
    return attachPart(weapon, candidate, usedPartTypes)
end

local function getVariantWeight(variant)
    return tonumber(variant.weight) or 1
end

local function pickWeightedVariant(variants)
    if not variants or #variants == 0 then
        return nil
    end

    local totalWeight = 0
    for _, variant in ipairs(variants) do
        local weight = getVariantWeight(variant)
        if weight > 0 then
            totalWeight = totalWeight + weight
        end
    end
    if totalWeight <= 0 then
        return variants[ZombRand(#variants) + 1]
    end

    local target = (ZombRand(100000) / 100000) * totalWeight
    local cursor = 0
    for _, variant in ipairs(variants) do
        local weight = getVariantWeight(variant)
        if weight > 0 then
            cursor = cursor + weight
            if target <= cursor then
                return variant
            end
        end
    end
    return variants[#variants]
end

local function applyVariantSlot(weapon, slot, variant, usedPartTypes)
    if not variant or not variant.steps then
        return false
    end

    local attachedAny = false
    for _, step in ipairs(variant.steps) do
        local stepSlot = mergeSlotStep(slot, step)
        local depsOk, depsReason = slotDependenciesMet(stepSlot, usedPartTypes, {})
        if not depsOk then
            logDebug(("Saltando paso de variante '%s' en %s: %s"):format(tostring(slot.slot or slot.partType), weapon:getFullType(), tostring(depsReason)))
            return attachedAny
        end
        if applySlotStep(weapon, stepSlot, usedPartTypes) then
            attachedAny = true
        elseif step.required ~= false then
            return attachedAny
        end
    end
    return attachedAny
end

local SLOT_PRIORITY = {
    Handguard = 0,
    Stock = 0,
    Mount = 1,
    Canon = 2,
    Barrel_Shroud = 2,
    Grip = 3,
    Laser = 3,
    Light = 3,
    Scope = 4,
    L_Scope = 4,
    Sling = 5,
    Stool = 5,
}

local function getSlotPriority(slot)
    if not slot then
        return 10
    end
    if slot.priority then
        return slot.priority
    end
    if slot.slot == "Optic" then
        return 4
    end
    return SLOT_PRIORITY[slot.partType] or 10
end

local function buildSlotExecutionPlan(slots)
    local plan = {}
    local added = {}

    for index, slot in ipairs(slots) do
        if type(slot) == "table" then
            added[index] = true
            table.insert(plan, {
                index = index,
                slot = slot,
                priority = getSlotPriority(slot),
            })
        end
    end

    for key, slot in pairs(slots) do
        if type(slot) == "table" and not added[key] then
            if type(key) == "string" and not slot.partType and not slot.variants then
                slot.partType = key
            end
            table.insert(plan, {
                index = type(key) == "number" and key or (#plan + 1),
                slot = slot,
                priority = getSlotPriority(slot),
            })
        end
    end
    table.sort(plan, function(a, b)
        if a.priority == b.priority then
            return a.index < b.index
        end
        return a.priority < b.priority
    end)
    return plan
end

local function applyWeaponSlots(weapon, slots, usedPartTypes)
    local usedConflictGroups = {}
    local plan = buildSlotExecutionPlan(slots)
    logDebug(("Procesando %s con %d slots v2"):format(weapon:getFullType(), #plan))

    for _, planned in ipairs(plan) do
        local slot = planned.slot
        local slotName = slot.slot or slot.partType or slot.conflictGroup or "slot"
        local depsOk, depsReason = slotDependenciesMet(slot, usedPartTypes, usedConflictGroups)
        if not depsOk then
            logDebug(("Saltando slot '%s' en %s: %s"):format(tostring(slotName), weapon:getFullType(), tostring(depsReason)))
        elseif roll(getSlotProbability(slot)) then
            local attached = false
            if slot.variants then
                local variant = pickWeightedVariant(slot.variants)
                attached = applyVariantSlot(weapon, slot, variant, usedPartTypes)
            else
                attached = applySlotStep(weapon, slot, usedPartTypes)
            end

            if attached and slot.conflictGroup then
                usedConflictGroups[slot.conflictGroup] = true
            elseif slot.required then
                logDebug("No se pudo completar slot requerido '" .. tostring(slotName) .. "' para " .. weapon:getFullType())
            end
        end
    end
end

function GGSWeaponUpgrades.ApplyToWeapon(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") then
        return
    end
    if isHistoricLootBlocked(weapon:getFullType()) then
        return
    end

    local slots = getWeaponSlots(weapon)
    local logic = getWeaponLogic(weapon)
    if not tableHasAnyEntry(slots) and (not logic or #logic == 0) then
        return
    end

    local modData = weapon:getModData()
    if modData.GGS_WeaponAutoUpgraded then
        logDebug("Ya procesado: " .. weapon:getFullType())
        return
    end

    local usedPartTypes = gatherUsedPartTypes(weapon)
    if tableHasAnyEntry(slots) then
        applyWeaponSlots(weapon, slots, usedPartTypes)
        modData.GGS_WeaponAutoUpgraded = true
        logDebug("Finalizado " .. weapon:getFullType())
        return
    end

    local dependencyContext = buildAutoDependencyContext(logic)
    local executionPlan = buildExecutionPlan(logic)
    logDebug(("Procesando %s con %d pasos"):format(weapon:getFullType(), #logic))

    for _, planned in ipairs(executionPlan) do
        local step = planned.step
        if step.list then
            local skipStep = false
            local needed
            local probability = getStepProbability(step)

            local depsOk, depsReason = dependenciesMet(step, dependencyContext, usedPartTypes)
            if not depsOk then
                skipStep = true
                logDebug(("Saltando '%s' en %s: %s"):format(step.list, weapon:getFullType(), tostring(depsReason)))
            end

            if not skipStep then
                if step.required then
                    if not roll(probability) then
                        skipStep = true
                        logDebug(("Lista obligatoria '%s' no pasÃ³ probabilidad en %s"):format(step.list, weapon:getFullType()))
                    else
                        needed = countMissingForRequiredStep(step, usedPartTypes)
                        skipStep = needed <= 0
                    end
                else
                    if not roll(probability) then
                        skipStep = true
                    else
                        needed = step.count or 1
                    end
                end
            end

            if not skipStep then
                while needed > 0 do
                    local candidate = pickCandidate(step.list, usedPartTypes, weapon)
                    if not candidate then
                        break
                    end
                    if attachPart(weapon, candidate, usedPartTypes) then
                        needed = needed - 1
                    else
                        break
                    end
                end

                if step.required and needed > 0 then
                    logDebug("No se pudo completar la lista obligatoria '" .. tostring(step.list) .. "' para " .. weapon:getFullType())
                end
            end
        end
    end

    modData.GGS_WeaponAutoUpgraded = true
    logDebug("Finalizado " .. weapon:getFullType())
end

local function getInventoryItemsFromEventArgs(...)
    for i = 1, select("#", ...) do
        local candidate = select(i, ...)
        if candidate then
            local ok, items = pcall(function()
                return candidate:getItems()
            end)
            if ok and items then
                local sizeOk = pcall(function()
                    return items:size()
                end)
                if sizeOk then
                    return items, candidate
                end
            end
        end
    end
    return nil, nil
end

local function applyToContainer(roomName, containerType, ...)
    local items = getInventoryItemsFromEventArgs(...)
    if not items then
        return
    end

    local forceMaxParts = shouldForceMaxPartCondition()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and instanceof(item, "HandWeapon") then
            applyRandomWeaponCondition(item)
            if hasWeaponUpgradeConfig(item) then
                logDebug(("Evento OnFillContainer %s/%s contiene %s"):format(tostring(roomName), tostring(containerType), item:getFullType()))
                GGSWeaponUpgrades.ApplyToWeapon(item)
            end
            applyWeaponPartConditionPolicy(item, forceMaxParts)
            applyRandomWeaponPartCondition(item)
        elseif isWeaponPartItem(item) then
            setPartConditionPolicy(item, forceMaxParts)
            applyRandomPartCondition(item)
        end
    end
end

if Events and Events.OnFillContainer then
    Events.OnFillContainer.Add(applyToContainer)
end

--[[
    Ejemplo de configuraciÃ³n inicial. Cada entrada en Lists define las piezas compatibles.
    Cada entrada en Logic define quÃ© listas se aplican a un arma determinada.
]]
GGSWeaponUpgrades = GGSWeaponUpgrades or {}
GGSWeaponUpgrades.Lists = GGSWeaponUpgrades.Lists or {}
GGSWeaponUpgrades.Logic = GGSWeaponUpgrades.Logic or {}
GGSWeaponUpgrades.ProbByList = GGSWeaponUpgrades.ProbByList or {}
GGSWeaponUpgrades.Pools = GGSWeaponUpgrades.Pools or {}
GGSWeaponUpgrades.WeaponSlots = GGSWeaponUpgrades.WeaponSlots or {}
GGSWeaponUpgrades.ProbByList["barrel_shroud_bipod"] = prob_barrel_shroud_bipod
GGSWeaponUpgrades.ProbByList["canon_pistol_sup"] = prob_canon_pistol_sup
GGSWeaponUpgrades.ProbByList["canon_revolver_type"] = prob_canon_revolver_type
GGSWeaponUpgrades.ProbByList["canon_rifle_sup"] = prob_canon_rifle_sup
GGSWeaponUpgrades.ProbByList["canon_shotgun_sup"] = prob_canon_shotgun_sup
GGSWeaponUpgrades.ProbByList["canon_smg_sup"] = prob_canon_smg_sup
GGSWeaponUpgrades.ProbByList["grip"] = prob_grip
GGSWeaponUpgrades.ProbByList["grip_grip_normal"] = prob_grip_grip_normal
GGSWeaponUpgrades.ProbByList["handguard"] = prob_handguard
GGSWeaponUpgrades.ProbByList["handguard_ak_hg"] = prob_handguard_ak_hg
GGSWeaponUpgrades.ProbByList["handguard_ar_hg"] = prob_handguard_ar_hg
GGSWeaponUpgrades.ProbByList["handguard_svd_hg"] = prob_handguard_svd_hg
GGSWeaponUpgrades.ProbByList["handguard_win_hg"] = prob_handguard_win_hg
GGSWeaponUpgrades.ProbByList["l_scope_ak_mount_scope"] = prob_l_scope_ak_mount_scope
GGSWeaponUpgrades.ProbByList["laser_pistol_laser"] = prob_laser_pistol_laser
GGSWeaponUpgrades.ProbByList["laser_rifle_laser"] = prob_laser_rifle_laser
GGSWeaponUpgrades.ProbByList["light_pistol_light"] = prob_light_pistol_light
GGSWeaponUpgrades.ProbByList["light_rifle_light"] = prob_light_rifle_light
GGSWeaponUpgrades.ProbByList["misc"] = prob_misc
GGSWeaponUpgrades.ProbByList["mount"] = prob_mount
GGSWeaponUpgrades.ProbByList["mount_ak_mount"] = prob_mount_ak_mount
GGSWeaponUpgrades.ProbByList["mount_rifle_mount"] = prob_mount_rifle_mount
GGSWeaponUpgrades.ProbByList["mount_shotgun_mount"] = prob_mount_shotgun_mount
GGSWeaponUpgrades.ProbByList["scope_large_scope"] = prob_scope_large_scope
GGSWeaponUpgrades.ProbByList["scope_medium_scope"] = prob_scope_medium_scope
GGSWeaponUpgrades.ProbByList["scope_mini_scope"] = prob_scope_mini_scope
GGSWeaponUpgrades.ProbByList["stock_ak_type"] = prob_stock_ak_type
GGSWeaponUpgrades.ProbByList["stock_ar_type"] = prob_stock_ar_type
GGSWeaponUpgrades.ProbByList["stock_mosin_type"] = prob_stock_mosin_type
GGSWeaponUpgrades.ProbByList["stock_pistol_type"] = prob_stock_pistol_type
GGSWeaponUpgrades.ProbByList["stock_revolver_type"] = prob_stock_revolver_type
GGSWeaponUpgrades.ProbByList["stock_scar_type"] = prob_stock_scar_type
GGSWeaponUpgrades.ProbByList["stock_shotgun_type"] = prob_stock_shotgun_type
GGSWeaponUpgrades.ProbByList["stock_svd_vss_type"] = prob_stock_svd_vss_type
GGSWeaponUpgrades.ProbByList["stock_win_type"] = prob_stock_win_type
GGSWeaponUpgrades.ProbByList["stool_ak_gl"] = prob_stool_ak_gl
GGSWeaponUpgrades.ProbByList["stool_ar_gl"] = prob_stool_ar_gl
GGSWeaponUpgrades.ProbByList["stool_scar_gl"] = prob_stool_scar_gl

GGSWeaponUpgrades.Lists["barrel_shroud_bipod"] = {
    "Base.bipod_harris",
    "Base.scrap_bipod",
}

GGSWeaponUpgrades.Lists["canon_pistol_sup"] = {
    "Base.Cover_Silencer",
    "Base.scrap_pipe_suppressor",
    "Base.Kriss9mm_Silencer",
    "Base.OilFilter_Silencer",
    "Base.Osprey_Silencer",
    "Base.PP93_Silencer",
    "Base.SMG_Silencer",
    "Base.Saiga9_Silencer",
    "Base.Scrap_Silencer",
    "Base.SodaCan_Silencer",
    "Base.SprayCan_Silencer",
    "Base.Suppx_Silencer",
    "Base.TMP_Silencer",
    "Base.WaterBottle_ductaped",
    "Base.sup2",
}

GGSWeaponUpgrades.Lists["canon_revolver_type"] = {
    "Base.A2000_Silencer",
    "Base.aek_Silencer",
    "Base.Cover_Silencer",
    "Base.scrap_pipe_suppressor",
    "Base.OilFilter_Silencer",
    "Base.Scrap_Silencer",
    "Base.SodaCan_Silencer",
    "Base.SprayCan_Silencer",
    "Base.WaterBottle_ductaped",
}

GGSWeaponUpgrades.Lists["canon_rifle_sup"] = {
    "Base.aek_Silencer",
    "Base.Cover2_Silencer",
    "Base.Cover3_Silencer",
    "Base.Dtkp_Hexagon_Silencer",
    "Base.Dtkp_Silencer",
    "Base.scrap_pipe_suppressor",
    "Base.NST_Silencer",
    "Base.OilFilter_Silencer",
    "Base.PBS1_Silencer",
    "Base.PBS4_Silencer",
    "Base.Scrap_Silencer",
    "Base.SodaCan_Silencer",
    "Base.SprayCan_Silencer",
    "Base.TGP_Silencer",
    "Base.WaterBottle_ductaped",
    "Base.sup2",
}

GGSWeaponUpgrades.Lists["canon_shotgun_sup"] = {
    "Base.ChokeTubeFull",
    "Base.ChokeTubeImproved",
    "Base.Cover4_Silencer",
    "Base.Hexagon_12G_Suppressor",
    "Base.Salvo_12G_Suppressor",
}

GGSWeaponUpgrades.Lists["canon_smg_sup"] = {
    "Base.9x39_Silencer",
    "Base.A2000_Silencer",
    "Base.aek_Silencer",
    "Base.Cover_Silencer",
    "Base.Cover2_Silencer",
    "Base.scrap_pipe_suppressor",
    "Base.Kriss9mm_Silencer",
    "Base.OilFilter_Silencer",
    "Base.Osprey_Silencer",
    "Base.PP93_Silencer",
    "Base.SMG_Silencer",
    "Base.Saiga9_Silencer",
    "Base.Scrap_Silencer",
    "Base.SodaCan_Silencer",
    "Base.SprayCan_Silencer",
    "Base.Suppx_Silencer",
    "Base.TMP_Silencer",
    "Base.WaterBottle_ductaped",
    "Base.sup2",
}

GGSWeaponUpgrades.Lists["grip"] = {
    "Base.stark_se",
}

GGSWeaponUpgrades.Lists["grip_grip_normal"] = {
    "Base.aluminum_skeletonized",
    "Base.AngleGrip",
    "Base.ax_base_pad",
    "Base.cobra_tactical",
    "Base.fortis_shift",
    "Base.Grip_Surefire_blk",
    "Base.Grip_Surefire_tan",
    "Base.GripPod",
    "Base.scrap_grip_drill",
    "Base.scrap_grip_screwdriver",
    "Base.hera_arms",
    "Base.hk_sturmgriff",
    "Base.kac_vertical_grip",
    "Base.keymod_sig",
    "Base.keymod_sig_vertical",
    "Base.keymod_vertical",
    "Base.m_lok_magpul",
    "Base.magpul_afg",
    "Base.magpul_rvg",
    "Base.PotatoGrip",
    "Base.rtm_pillau",
    "Base.tango_down",
    "Base.vtac_uvg",
    "Base.zenit_b25u",
    "Base.zenit_rk_1",
    "Base.zenit_rk_5",
    "Base.zenit_rk6",
    "Base.bcm",
}

GGSWeaponUpgrades.Lists["handguard"] = {
    "Base.UniversalMount",
}

GGSWeaponUpgrades.Lists["handguard_ak_hg"] = {
    "Base.AKHGtactical",
    "Base.ak_hg_545_design",
    "Base.ak_hg_cnc",
    "Base.ak_hg_cugir",
    "Base.ak_hg_hexagon",
    "Base.ak_hg_krebs",
    "Base.ak_hg_magpul_moe",
    "Base.ak_hg_magpul_zhukov",
    "Base.ak_hg_quad",
    "Base.ak_hg_rail",
    "Base.ak_hg_std",
    "Base.ak_hg_vltor",
    "Base.AkHGwood",
}

GGSWeaponUpgrades.Lists["handguard_ar_hg"] = {
    "Base.AR_handguard",
    "Base.AR15_handguard",
    "Base.ar10_hg_cmmg_mk3_rml15",
    "Base.ar10_hg_cmmg_mk3_rml9",
    "Base.ar10_hg_kac_urx4_14",
    "Base.ar10_hg_lancer_12",
    "Base.ar10_hg_noveske_quadrail",
    "Base.ar15_hg_adar_wood",
    "Base.ar15_hg_aeroknox_10",
    "Base.ar15_hg_aeroknox_15",
    "Base.ar15_hg_alexander",
    "Base.ar15_hg_geissele_13",
    "Base.ar15_hg_geissele_9",
    "Base.ar15_hg_lone_star_16",
    "Base.ar15_hg_lvoa_c",
    "Base.ar15_hg_lvoa_s",
    "Base.ar15_hg_magpul_carabine",
    "Base.ar15_hg_magpul_moe",
    "Base.ar15_hg_reflex_carbon",
    "Base.ar15_hg_ris_fsp_9",
    "Base.ar15_hg_rsass",
    "Base.ar15_hg_stngr_vypr_10",
    "Base.ar15_wing_and_skull_12",
    "Base.M16_handguard",
    "Base.m16_hg_launcher",
    "Base.M16A2_handguard",
}

GGSWeaponUpgrades.Lists["handguard_svd_hg"] = {
    "Base.svd_handguard_xrs_drg",
    "Base.svd_hg_plastic",
    "Base.svd_hg_wood",
}

GGSWeaponUpgrades.Lists["handguard_win_hg"] = {
    "Base.win_1886_hg_wood",
    "Base.win_archangel_handguard",
    "Base.win_SWM1854_hg_wood",
    "Base.win_swm1894_handguard",
}

GGSWeaponUpgrades.Lists["l_scope_ak_mount_scope"] = {
    "Base.1P78",
    "Base.1PN93_4",
    "Base.EKP_kobra",
    "Base.EKP_kobra_2x",
    "Base.POSP",
    "Base.POSP4x24",
    "Base.Zeiss4x25",
}

GGSWeaponUpgrades.Lists["laser_pistol_laser"] = {
    "Base.BaldrPro",
    "Base.Dbal9021",
    "Base.SurefireX400",
}

GGSWeaponUpgrades.Lists["laser_rifle_laser"] = {
    "Base.ANPEQ_10",
    "Base.ANPEQ_2",
    "Base.DBAL_A2",
    "Base.InsightLA5",
    "Base.Ncstar_laser",
    "Base.PEQ15",
}

GGSWeaponUpgrades.Lists["light_pistol_light"] = {
    "Base.GunLight",
    "Base.SteinerTac2",
    "Base.Zenit2P",
}

GGSWeaponUpgrades.Lists["light_rifle_light"] = {
    "Base.InsightWMX200",
    "Base.M600P",
    "Base.M962LT",
    "Base.Surefire_light",
    "Base.Surefire_M925",
}

GGSWeaponUpgrades.Lists["misc"] = {
    "Base.GunCamo",
}

GGSWeaponUpgrades.Lists["mount"] = {
    "Base.mount_rail",
}

GGSWeaponUpgrades.Lists["mount_ak_mount"] = {
    "Base.ak_mount_kobra",
    "Base.ak_mount_sag",
    "Base.ak_mount_vpo",
    "Base.ak_mount_xd_rgl",
    "Base.AkMount",
    "Base.scrap_mount",
}

GGSWeaponUpgrades.Lists["mount_rifle_mount"] = {
    "Base.Mosin_Mount",
}

GGSWeaponUpgrades.Lists["mount_shotgun_mount"] = {
    "Base.RB7M_Mount",
    "Base.scrap_mount_shotgun",
}

GGSWeaponUpgrades.Lists["scope_large_scope"] = {
    "Base.Accupoint",
    "Base.BallisticScope",
    "Base.Eotech_vudu",
    "Base.Leapers_UTG3",
    "Base.PM_IILP",
    "Base.Springfield_longrange_scope",
    "Base.x8Scope",
}

GGSWeaponUpgrades.Lists["scope_medium_scope"] = {
    "Base.ACOGx4",
    "Base.ATN_Thor",
    "Base.Acog_ecos",
    "Base.Acog_TA648",
    "Base.Bravo4",
    "Base.CP1",
    "Base.Comp_M4",
    "Base.Compact4x",
    "Base.Coyote",
    "Base.Elcan_M145",
    "Base.Eotech",
    "Base.Eotech_XPS3",
    "Base.HAMR",
    "Base.IRNV",
    "Base.Kobra",
    "Base.MicroT1",
    "Base.PKA",
    "Base.PistolScope",
    "Base.RDS",
    "Base.RX01",
    "Base.RedDot",
    "Base.SLDG",
    "Base.SUSAT",
    "Base.Spectre",
    "Base.x2Scope",
    "Base.x4Scope",
}

GGSWeaponUpgrades.Lists["scope_mini_scope"] = {
    "Base.CrimsonRedDot",
    "Base.Deltapoint",
    "Base.MiniRedDot",
    "Base.OKP7",
    "Base.PistolScope",
    "Base.Romeo3",
    "Base.SigSauerRomeo3",
    "Base.TritiumSights",
    "Base.TruBrite",
    "Base.VenomRDS",
    "Base.VortexRedDot",
    "Base.ZaMiniRDS",
}

GGSWeaponUpgrades.Lists["stock_ak_type"] = {
    "Base.AK_Wood_stock",
    "Base.AK12_stock",
    "Base.AK19_stock",
    "Base.AK47_stock",
    "Base.AK74_stock",
    "Base.AK74u_stock",
    "Base.AK9_stock",
    "Base.AMD65_stock",
    "Base.AN94_stock",
    "Base.ak_stock_archangel",
    "Base.ak_stock_fab",
    "Base.ak_stock_fold",
    "Base.ak_stock_hera",
    "Base.ak_stock_hexagon",
    "Base.ak_stock_zenit_magpul",
    "Base.ak74_std_plastic",
    "Base.ak74_stock_plum",
    "Base.ak74m_stock_std",
    "Base.aks74_stock",
    "Base.scrap_stock",
    "Base.Luty_stock",
    "Base.pk_stock_plastic",
    "Base.pk_stock_wood",
    "Base.Type81_stock",
    "Base.VZ58_stock",
    "Base.Wieger940_folding",
    "Base.Wieger940_stock",
    "Base.ak_stock_wrapped",
    "Base.ak_stock_zenit_pt_1",
    "Base.ak_stock_zenit_pt_3",
}

GGSWeaponUpgrades.Lists["stock_ar_type"] = {
    "Base.AR10_stock",
    "Base.AR15_stock",
    "Base.ar15_adar_stock",
    "Base.ar15_armacon_stock",
    "Base.ar15_b5_stock",
    "Base.ar15_doublestar_stock",
    "Base.ar15_f93_stock",
    "Base.ar15_fab_defense_16s_stock",
    "Base.ar15_fab_defense_core_stock",
    "Base.ar15_fab_defense_shock_stock",
    "Base.ar15_high_standart_stock",
    "Base.ar15_lmt_sopmod_stock",
    "Base.ar15_magpul_gen2_fde_stock",
    "Base.ar15_magpul_gen2_stock",
    "Base.ar15_magpul_gen3_stock",
    "Base.ar15_magpul_prs_gen2_fde_stock",
    "Base.ar15_mft_stock",
    "Base.ar15_ripstock_stock",
    "Base.ar15_sba3_stock",
    "Base.ar15_troy_pdw_stock_blk",
    "Base.ar15_troy_pdw_stock_fde",
    "Base.ar15_viper_mod1_stock",
    "Base.ar15_viper_pdw_stock",
    "Base.ar15_vltor_emod_stock",
    "Base.scrap_stock",
    "Base.Luty_stock",
    "Base.M16_stock",
}

GGSWeaponUpgrades.Lists["stock_mosin_type"] = {
    "Base.Mosin_carlo_stock",
    "Base.Mosin_Wood_short_stock",
    "Base.Mosin_Wood_stock",
}

GGSWeaponUpgrades.Lists["stock_pistol_type"] = {
    "Base.OTS_33_pistol_stock",
    "Base.stock_pistol_fab",
    "Base.VP70_pistol_stock",
}

GGSWeaponUpgrades.Lists["stock_revolver_type"] = {
    "Base.OTS_33_pistol_stock",
    "Base.stock_pistol_fab",
}

GGSWeaponUpgrades.Lists["stock_scar_type"] = {
    "Base.Scar_pdw_stock",
    "Base.Scar_ssr_stock",
    "Base.Scar_stock",
}

GGSWeaponUpgrades.Lists["stock_shotgun_type"] = {
    "Base.M1014_stock",
    "Base.MP155_montecarlo_stock",
    "Base.MP18_plastic_stock",
    "Base.Mossberg_grip",
    "Base.R870_magpul_stock",
    "Base.R870_sps_stock",
    "Base.R870_Tactical_Grip",
    "Base.R870_Tactical_Grip_short",
    "Base.R870_Wood_Grip",
    "Base.R870_Wood_stock",
    "Base.R870_grip",
}

GGSWeaponUpgrades.Lists["stock_svd_vss_type"] = {
    "Base.svd_stock_wood",
    "Base.VSS_stock_Tactical",
    "Base.VSS_stock_wood",
}

GGSWeaponUpgrades.Lists["stock_win_type"] = {
    "Base.win_1886_stock_wood",
    "Base.win_1895_stock",
    "Base.win_archangel_stock",
    "Base.win_m1887_grip",
    "Base.win_m1887_stock",
    "Base.win_mts_stock",
    "Base.win_SWM1854_stock_wood",
    "Base.win_sjorgen_stock",
    "Base.win_swm1894_stock",
}

GGSWeaponUpgrades.Lists["stool_ak_gl"] = {
    "Base.GP30_GL",
    "Base.GP30_GL_empty",
    "Base.M320_GL",
    "Base.M320_GL_empty",
}

GGSWeaponUpgrades.Lists["stool_ar_gl"] = {
    "Base.M203_GL",
    "Base.M203_GL_empty",
    "Base.M320_GL",
    "Base.M320_GL_empty",
}

GGSWeaponUpgrades.Lists["stool_scar_gl"] = {
    "Base.Scar_GL",
    "Base.Scar_GL_empty",
}

GGSWeaponUpgrades.ProbByList["barrel_shroud_bipod"] = prob_barrel_shroud_bipod
GGSWeaponUpgrades.ProbByList["canon_pistol_sup"] = prob_canon_pistol_sup
GGSWeaponUpgrades.ProbByList["canon_revolver_type"] = prob_canon_revolver_type
GGSWeaponUpgrades.ProbByList["canon_rifle_sup"] = prob_canon_rifle_sup
GGSWeaponUpgrades.ProbByList["canon_shotgun_sup"] = prob_canon_shotgun_sup
GGSWeaponUpgrades.ProbByList["canon_smg_sup"] = prob_canon_smg_sup
GGSWeaponUpgrades.ProbByList["grip"] = prob_grip
GGSWeaponUpgrades.ProbByList["grip_grip_normal"] = prob_grip_grip_normal
GGSWeaponUpgrades.ProbByList["handguard"] = prob_handguard
GGSWeaponUpgrades.ProbByList["handguard_ak_hg"] = prob_handguard_ak_hg
GGSWeaponUpgrades.ProbByList["handguard_ar_hg"] = prob_handguard_ar_hg
GGSWeaponUpgrades.ProbByList["handguard_svd_hg"] = prob_handguard_svd_hg
GGSWeaponUpgrades.ProbByList["handguard_win_hg"] = prob_handguard_win_hg
GGSWeaponUpgrades.ProbByList["l_scope_ak_mount_scope"] = prob_l_scope_ak_mount_scope
GGSWeaponUpgrades.ProbByList["laser_pistol_laser"] = prob_laser_pistol_laser
GGSWeaponUpgrades.ProbByList["laser_rifle_laser"] = prob_laser_rifle_laser
GGSWeaponUpgrades.ProbByList["light_pistol_light"] = prob_light_pistol_light
GGSWeaponUpgrades.ProbByList["light_rifle_light"] = prob_light_rifle_light
GGSWeaponUpgrades.ProbByList["misc"] = prob_misc
GGSWeaponUpgrades.ProbByList["mount"] = prob_mount
GGSWeaponUpgrades.ProbByList["mount_ak_mount"] = prob_mount_ak_mount
GGSWeaponUpgrades.ProbByList["mount_rifle_mount"] = prob_mount_rifle_mount
GGSWeaponUpgrades.ProbByList["mount_shotgun_mount"] = prob_mount_shotgun_mount
GGSWeaponUpgrades.ProbByList["scope_large_scope"] = prob_scope_large_scope
GGSWeaponUpgrades.ProbByList["scope_medium_scope"] = prob_scope_medium_scope
GGSWeaponUpgrades.ProbByList["scope_mini_scope"] = prob_scope_mini_scope
GGSWeaponUpgrades.ProbByList["stock_ak_type"] = prob_stock_ak_type
GGSWeaponUpgrades.ProbByList["stock_ar_type"] = prob_stock_ar_type
GGSWeaponUpgrades.ProbByList["stock_mosin_type"] = prob_stock_mosin_type
GGSWeaponUpgrades.ProbByList["stock_pistol_type"] = prob_stock_pistol_type
GGSWeaponUpgrades.ProbByList["stock_revolver_type"] = prob_stock_revolver_type
GGSWeaponUpgrades.ProbByList["stock_scar_type"] = prob_stock_scar_type
GGSWeaponUpgrades.ProbByList["stock_shotgun_type"] = prob_stock_shotgun_type
GGSWeaponUpgrades.ProbByList["stock_svd_vss_type"] = prob_stock_svd_vss_type
GGSWeaponUpgrades.ProbByList["stock_win_type"] = prob_stock_win_type
GGSWeaponUpgrades.ProbByList["stool_ak_gl"] = prob_stool_ak_gl
GGSWeaponUpgrades.ProbByList["stool_ar_gl"] = prob_stool_ar_gl
GGSWeaponUpgrades.ProbByList["stool_scar_gl"] = prob_stool_scar_gl

GGSWeaponUpgrades = GGSWeaponUpgrades or {}
GGSWeaponUpgrades.Pools = GGSWeaponUpgrades.Pools or {}
GGSWeaponUpgrades.WeaponSlots = GGSWeaponUpgrades.WeaponSlots or {}

GGSWeaponUpgrades.Pools["barrel_shroud"] = {
    { item = "Base.bipod_old", weight = 1, partType = "Barrel_Shroud" },
    { item = "Base.bipod_simple", weight = 1, partType = "Barrel_Shroud" },
}

GGSWeaponUpgrades.Pools["barrel_shroud_bipod"] = {
    { item = "Base.bipod_harris", weight = 1, partType = "Barrel_Shroud" },
    { item = "Base.scrap_bipod", weight = 1, partType = "Barrel_Shroud" },
}

GGSWeaponUpgrades.Pools["canon_pistol_sup"] = {
    { item = "Base.Cover_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.scrap_pipe_suppressor", weight = 1, partType = "Canon" },
    { item = "Base.Kriss9mm_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.OilFilter_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Osprey_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.PP93_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SMG_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Saiga9_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Scrap_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SodaCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SprayCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Suppx_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.TMP_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.WaterBottle_ductaped", weight = 1, partType = "Canon" },
    { item = "Base.sup2", weight = 1, partType = "Canon" },
}

GGSWeaponUpgrades.Pools["canon_revolver_type"] = {
    { item = "Base.A2000_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.aek_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Cover_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.scrap_pipe_suppressor", weight = 1, partType = "Canon" },
    { item = "Base.OilFilter_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Scrap_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SodaCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SprayCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.WaterBottle_ductaped", weight = 1, partType = "Canon" },
}

GGSWeaponUpgrades.Pools["canon_rifle_sup"] = {
    { item = "Base.aek_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Cover2_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Cover3_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Dtkp_Hexagon_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Dtkp_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.scrap_pipe_suppressor", weight = 1, partType = "Canon" },
    { item = "Base.NST_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.OilFilter_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.PBS1_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.PBS4_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Scrap_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SodaCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SprayCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.TGP_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.WaterBottle_ductaped", weight = 1, partType = "Canon" },
    { item = "Base.sup2", weight = 1, partType = "Canon" },
}

GGSWeaponUpgrades.Pools["canon_shotgun_sup"] = {
    { item = "Base.ChokeTubeFull", weight = 1, partType = "Canon" },
    { item = "Base.ChokeTubeImproved", weight = 1, partType = "Canon" },
    { item = "Base.Cover4_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Hexagon_12G_Suppressor", weight = 1, partType = "Canon" },
    { item = "Base.Salvo_12G_Suppressor", weight = 1, partType = "Canon" },
}

GGSWeaponUpgrades.Pools["canon_smg_sup"] = {
    { item = "Base.9x39_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.A2000_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.aek_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Cover_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Cover2_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.scrap_pipe_suppressor", weight = 1, partType = "Canon" },
    { item = "Base.Kriss9mm_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.OilFilter_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Osprey_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.PP93_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SMG_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Saiga9_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Scrap_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SodaCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.SprayCan_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.Suppx_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.TMP_Silencer", weight = 1, partType = "Canon" },
    { item = "Base.WaterBottle_ductaped", weight = 1, partType = "Canon" },
    { item = "Base.sup2", weight = 1, partType = "Canon" },
}

GGSWeaponUpgrades.Pools["grip"] = {
    { item = "Base.stark_se", weight = 1, partType = "Grip" },
}

GGSWeaponUpgrades.Pools["grip_grip_normal"] = {
    { item = "Base.aluminum_skeletonized", weight = 1, partType = "Grip" },
    { item = "Base.AngleGrip", weight = 1, partType = "Grip" },
    { item = "Base.ax_base_pad", weight = 1, partType = "Grip" },
    { item = "Base.cobra_tactical", weight = 1, partType = "Grip" },
    { item = "Base.fortis_shift", weight = 1, partType = "Grip" },
    { item = "Base.Grip_Surefire_blk", weight = 1, partType = "Grip" },
    { item = "Base.Grip_Surefire_tan", weight = 1, partType = "Grip" },
    { item = "Base.GripPod", weight = 1, partType = "Grip" },
    { item = "Base.scrap_grip_drill", weight = 1, partType = "Grip" },
    { item = "Base.scrap_grip_screwdriver", weight = 1, partType = "Grip" },
    { item = "Base.hera_arms", weight = 1, partType = "Grip" },
    { item = "Base.hk_sturmgriff", weight = 1, partType = "Grip" },
    { item = "Base.kac_vertical_grip", weight = 1, partType = "Grip" },
    { item = "Base.keymod_sig", weight = 1, partType = "Grip" },
    { item = "Base.keymod_sig_vertical", weight = 1, partType = "Grip" },
    { item = "Base.keymod_vertical", weight = 1, partType = "Grip" },
    { item = "Base.m_lok_magpul", weight = 1, partType = "Grip" },
    { item = "Base.magpul_afg", weight = 1, partType = "Grip" },
    { item = "Base.magpul_rvg", weight = 1, partType = "Grip" },
    { item = "Base.PotatoGrip", weight = 1, partType = "Grip" },
    { item = "Base.rtm_pillau", weight = 1, partType = "Grip" },
    { item = "Base.tango_down", weight = 1, partType = "Grip" },
    { item = "Base.vtac_uvg", weight = 1, partType = "Grip" },
    { item = "Base.zenit_b25u", weight = 1, partType = "Grip" },
    { item = "Base.zenit_rk_1", weight = 1, partType = "Grip" },
    { item = "Base.zenit_rk_5", weight = 1, partType = "Grip" },
    { item = "Base.zenit_rk6", weight = 1, partType = "Grip" },
    { item = "Base.bcm", weight = 1, partType = "Grip" },
}

GGSWeaponUpgrades.Pools["handguard"] = {
    { item = "Base.UniversalMount", weight = 1, partType = "Handguard" },
}

GGSWeaponUpgrades.Pools["handguard_ak_hg"] = {
    { item = "Base.AKHGtactical", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_545_design", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_cnc", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_cugir", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_hexagon", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_krebs", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_magpul_moe", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_magpul_zhukov", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_quad", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_rail", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_std", weight = 1, partType = "Handguard" },
    { item = "Base.ak_hg_vltor", weight = 1, partType = "Handguard" },
    { item = "Base.AkHGwood", weight = 1, partType = "Handguard" },
}

GGSWeaponUpgrades.Pools["handguard_ar_hg"] = {
    { item = "Base.AR_handguard", weight = 1, partType = "Handguard" },
    { item = "Base.AR15_handguard", weight = 1, partType = "Handguard" },
    { item = "Base.ar10_hg_cmmg_mk3_rml15", weight = 1, partType = "Handguard" },
    { item = "Base.ar10_hg_cmmg_mk3_rml9", weight = 1, partType = "Handguard" },
    { item = "Base.ar10_hg_kac_urx4_14", weight = 1, partType = "Handguard" },
    { item = "Base.ar10_hg_lancer_12", weight = 1, partType = "Handguard" },
    { item = "Base.ar10_hg_noveske_quadrail", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_adar_wood", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_aeroknox_10", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_aeroknox_15", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_alexander", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_geissele_13", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_geissele_9", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_lone_star_16", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_lvoa_c", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_lvoa_s", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_magpul_carabine", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_magpul_moe", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_reflex_carbon", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_ris_fsp_9", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_rsass", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_hg_stngr_vypr_10", weight = 1, partType = "Handguard" },
    { item = "Base.ar15_wing_and_skull_12", weight = 1, partType = "Handguard" },
    { item = "Base.M16_handguard", weight = 1, partType = "Handguard" },
    { item = "Base.m16_hg_launcher", weight = 1, partType = "Handguard" },
    { item = "Base.M16A2_handguard", weight = 1, partType = "Handguard" },
}

GGSWeaponUpgrades.Pools["handguard_svd_hg"] = {
    { item = "Base.svd_handguard_xrs_drg", weight = 1, partType = "Handguard" },
    { item = "Base.svd_hg_plastic", weight = 1, partType = "Handguard" },
    { item = "Base.svd_hg_wood", weight = 1, partType = "Handguard" },
}

GGSWeaponUpgrades.Pools["handguard_win_hg"] = {
    { item = "Base.win_1886_hg_wood", weight = 1, partType = "Handguard" },
    { item = "Base.win_archangel_handguard", weight = 1, partType = "Handguard" },
    { item = "Base.win_SWM1854_hg_wood", weight = 1, partType = "Handguard" },
    { item = "Base.win_swm1894_handguard", weight = 1, partType = "Handguard" },
}

GGSWeaponUpgrades.Pools["l_scope_ak_mount_scope"] = {
    { item = "Base.1P78", weight = 1, partType = "L_Scope" },
    { item = "Base.1PN93_4", weight = 1, partType = "L_Scope" },
    { item = "Base.EKP_kobra", weight = 1, partType = "L_Scope" },
    { item = "Base.EKP_kobra_2x", weight = 1, partType = "L_Scope" },
    { item = "Base.POSP", weight = 1, partType = "L_Scope" },
    { item = "Base.POSP4x24", weight = 1, partType = "L_Scope" },
    { item = "Base.Zeiss4x25", weight = 1, partType = "L_Scope" },
}

GGSWeaponUpgrades.Pools["laser_pistol_laser"] = {
    { item = "Base.BaldrPro", weight = 1, partType = "Laser" },
    { item = "Base.Dbal9021", weight = 1, partType = "Laser" },
    { item = "Base.SurefireX400", weight = 1, partType = "Laser" },
}

GGSWeaponUpgrades.Pools["laser_rifle_laser"] = {
    { item = "Base.ANPEQ_10", weight = 1, partType = "Laser" },
    { item = "Base.ANPEQ_2", weight = 1, partType = "Laser" },
    { item = "Base.DBAL_A2", weight = 1, partType = "Laser" },
    { item = "Base.InsightLA5", weight = 1, partType = "Laser" },
    { item = "Base.Ncstar_laser", weight = 1, partType = "Laser" },
    { item = "Base.PEQ15", weight = 1, partType = "Laser" },
}

GGSWeaponUpgrades.Pools["light_pistol_light"] = {
    { item = "Base.GunLight", weight = 1, partType = "Light" },
    { item = "Base.SteinerTac2", weight = 1, partType = "Light" },
    { item = "Base.Zenit2P", weight = 1, partType = "Light" },
}

GGSWeaponUpgrades.Pools["light_rifle_light"] = {
    { item = "Base.InsightWMX200", weight = 1, partType = "Light" },
    { item = "Base.M600P", weight = 1, partType = "Light" },
    { item = "Base.M962LT", weight = 1, partType = "Light" },
    { item = "Base.Surefire_light", weight = 1, partType = "Light" },
    { item = "Base.Surefire_M925", weight = 1, partType = "Light" },
}

GGSWeaponUpgrades.Pools["misc"] = {
    { item = "Base.GunCamo", weight = 1, partType = "Misc" },
    { item = "Base.rifle_cloth", weight = 1, partType = "Misc" },
    { item = "Base.rifle_wrap_b", weight = 1, partType = "Misc" },
}

GGSWeaponUpgrades.Pools["mount"] = {
    { item = "Base.mount_rail", weight = 1, partType = "Mount" },
}

GGSWeaponUpgrades.Pools["mount_ak_mount"] = {
    { item = "Base.ak_mount_kobra", weight = 1, partType = "Mount" },
    { item = "Base.ak_mount_sag", weight = 1, partType = "Mount" },
    { item = "Base.ak_mount_vpo", weight = 1, partType = "Mount" },
    { item = "Base.ak_mount_xd_rgl", weight = 1, partType = "Mount" },
    { item = "Base.AkMount", weight = 1, partType = "Mount" },
    { item = "Base.scrap_mount", weight = 1, partType = "Mount" },
}

GGSWeaponUpgrades.Pools["mount_rifle_mount"] = {
    { item = "Base.Mosin_Mount", weight = 1, partType = "Mount" },
}

GGSWeaponUpgrades.Pools["mount_shotgun_mount"] = {
    { item = "Base.RB7M_Mount", weight = 1, partType = "Mount" },
    { item = "Base.scrap_mount_shotgun", weight = 1, partType = "Mount" },
}

GGSWeaponUpgrades.Pools["scope_large_scope"] = {
    { item = "Base.Accupoint", weight = 1, partType = "Scope" },
    { item = "Base.BallisticScope", weight = 1, partType = "Scope" },
    { item = "Base.Eotech_vudu", weight = 1, partType = "Scope" },
    { item = "Base.Leapers_UTG3", weight = 1, partType = "Scope" },
    { item = "Base.PM_IILP", weight = 1, partType = "Scope" },
    { item = "Base.Springfield_longrange_scope", weight = 1, partType = "Scope" },
    { item = "Base.x8Scope", weight = 1, partType = "Scope" },
}

GGSWeaponUpgrades.Pools["scope_medium_scope"] = {
    { item = "Base.ACOGx4", weight = 1, partType = "Scope" },
    { item = "Base.ATN_Thor", weight = 1, partType = "Scope" },
    { item = "Base.Acog_ecos", weight = 1, partType = "Scope" },
    { item = "Base.Acog_TA648", weight = 1, partType = "Scope" },
    { item = "Base.Bravo4", weight = 1, partType = "Scope" },
    { item = "Base.CP1", weight = 1, partType = "Scope" },
    { item = "Base.Comp_M4", weight = 1, partType = "Scope" },
    { item = "Base.Compact4x", weight = 1, partType = "Scope" },
    { item = "Base.Coyote", weight = 1, partType = "Scope" },
    { item = "Base.Elcan_M145", weight = 1, partType = "Scope" },
    { item = "Base.Eotech", weight = 1, partType = "Scope" },
    { item = "Base.Eotech_XPS3", weight = 1, partType = "Scope" },
    { item = "Base.HAMR", weight = 1, partType = "Scope" },
    { item = "Base.IRNV", weight = 1, partType = "Scope" },
    { item = "Base.Kobra", weight = 1, partType = "Scope" },
    { item = "Base.MicroT1", weight = 1, partType = "Scope" },
    { item = "Base.PKA", weight = 1, partType = "Scope" },
    { item = "Base.PistolScope", weight = 1, partType = "Scope" },
    { item = "Base.RDS", weight = 1, partType = "Scope" },
    { item = "Base.RX01", weight = 1, partType = "Scope" },
    { item = "Base.RedDot", weight = 1, partType = "Scope" },
    { item = "Base.SLDG", weight = 1, partType = "Scope" },
    { item = "Base.SUSAT", weight = 1, partType = "Scope" },
    { item = "Base.Spectre", weight = 1, partType = "Scope" },
    { item = "Base.x2Scope", weight = 1, partType = "Scope" },
    { item = "Base.x4Scope", weight = 1, partType = "Scope" },
}

GGSWeaponUpgrades.Pools["scope_mini_scope"] = {
    { item = "Base.CrimsonRedDot", weight = 1, partType = "Scope" },
    { item = "Base.Deltapoint", weight = 1, partType = "Scope" },
    { item = "Base.MiniRedDot", weight = 1, partType = "Scope" },
    { item = "Base.OKP7", weight = 1, partType = "Scope" },
    { item = "Base.PistolScope", weight = 1, partType = "Scope" },
    { item = "Base.Romeo3", weight = 1, partType = "Scope" },
    { item = "Base.SigSauerRomeo3", weight = 1, partType = "Scope" },
    { item = "Base.TritiumSights", weight = 1, partType = "Scope" },
    { item = "Base.TruBrite", weight = 1, partType = "Scope" },
    { item = "Base.VenomRDS", weight = 1, partType = "Scope" },
    { item = "Base.VortexRedDot", weight = 1, partType = "Scope" },
    { item = "Base.ZaMiniRDS", weight = 1, partType = "Scope" },
}

GGSWeaponUpgrades.Pools["sling"] = {
    { item = "Base.Sling", weight = 1, partType = "Sling" },
}

GGSWeaponUpgrades.Pools["stock_ak_type"] = {
    { item = "Base.AK_Wood_stock", weight = 1, partType = "Stock" },
    { item = "Base.AK12_stock", weight = 1, partType = "Stock" },
    { item = "Base.AK19_stock", weight = 1, partType = "Stock" },
    { item = "Base.AK47_stock", weight = 1, partType = "Stock" },
    { item = "Base.AK74_stock", weight = 1, partType = "Stock" },
    { item = "Base.AK74u_stock", weight = 1, partType = "Stock" },
    { item = "Base.AK9_stock", weight = 1, partType = "Stock" },
    { item = "Base.AMD65_stock", weight = 1, partType = "Stock" },
    { item = "Base.AN94_stock", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_archangel", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_fab", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_fold", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_hera", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_hexagon", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_zenit_magpul", weight = 1, partType = "Stock" },
    { item = "Base.ak74_std_plastic", weight = 1, partType = "Stock" },
    { item = "Base.ak74_stock_plum", weight = 1, partType = "Stock" },
    { item = "Base.ak74m_stock_std", weight = 1, partType = "Stock" },
    { item = "Base.aks74_stock", weight = 1, partType = "Stock" },
    { item = "Base.scrap_stock", weight = 1, partType = "Stock" },
    { item = "Base.Luty_stock", weight = 1, partType = "Stock" },
    { item = "Base.pk_stock_plastic", weight = 1, partType = "Stock" },
    { item = "Base.pk_stock_wood", weight = 1, partType = "Stock" },
    { item = "Base.Type81_stock", weight = 1, partType = "Stock" },
    { item = "Base.VZ58_stock", weight = 1, partType = "Stock" },
    { item = "Base.Wieger940_folding", weight = 1, partType = "Stock" },
    { item = "Base.Wieger940_stock", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_wrapped", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_zenit_pt_1", weight = 1, partType = "Stock" },
    { item = "Base.ak_stock_zenit_pt_3", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_ar_type"] = {
    { item = "Base.AR10_stock", weight = 1, partType = "Stock" },
    { item = "Base.AR15_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_adar_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_armacon_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_b5_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_doublestar_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_f93_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_fab_defense_16s_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_fab_defense_core_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_fab_defense_shock_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_high_standart_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_lmt_sopmod_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_magpul_gen2_fde_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_magpul_gen2_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_magpul_gen3_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_magpul_prs_gen2_fde_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_mft_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_ripstock_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_sba3_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_troy_pdw_stock_blk", weight = 1, partType = "Stock" },
    { item = "Base.ar15_troy_pdw_stock_fde", weight = 1, partType = "Stock" },
    { item = "Base.ar15_viper_mod1_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_viper_pdw_stock", weight = 1, partType = "Stock" },
    { item = "Base.ar15_vltor_emod_stock", weight = 1, partType = "Stock" },
    { item = "Base.scrap_stock", weight = 1, partType = "Stock" },
    { item = "Base.Luty_stock", weight = 1, partType = "Stock" },
    { item = "Base.M16_stock", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_mosin_type"] = {
    { item = "Base.Mosin_carlo_stock", weight = 1, partType = "Stock" },
    { item = "Base.Mosin_Wood_short_stock", weight = 1, partType = "Stock" },
    { item = "Base.Mosin_Wood_stock", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_pistol_type"] = {
    { item = "Base.OTS_33_pistol_stock", weight = 1, partType = "Stock" },
    { item = "Base.stock_pistol_fab", weight = 1, partType = "Stock" },
    { item = "Base.VP70_pistol_stock", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_revolver_type"] = {
    { item = "Base.OTS_33_pistol_stock", weight = 1, partType = "Stock" },
    { item = "Base.stock_pistol_fab", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_scar_type"] = {
    { item = "Base.Scar_pdw_stock", weight = 1, partType = "Stock" },
    { item = "Base.Scar_ssr_stock", weight = 1, partType = "Stock" },
    { item = "Base.Scar_stock", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_shotgun_type"] = {
    { item = "Base.M1014_stock", weight = 1, partType = "Stock" },
    { item = "Base.MP155_montecarlo_stock", weight = 1, partType = "Stock" },
    { item = "Base.MP18_plastic_stock", weight = 1, partType = "Stock" },
    { item = "Base.Mossberg_grip", weight = 1, partType = "Stock" },
    { item = "Base.R870_magpul_stock", weight = 1, partType = "Stock" },
    { item = "Base.R870_sps_stock", weight = 1, partType = "Stock" },
    { item = "Base.R870_Tactical_Grip", weight = 1, partType = "Stock" },
    { item = "Base.R870_Tactical_Grip_short", weight = 1, partType = "Stock" },
    { item = "Base.R870_Wood_Grip", weight = 1, partType = "Stock" },
    { item = "Base.R870_Wood_stock", weight = 1, partType = "Stock" },
    { item = "Base.R870_grip", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_svd_vss_type"] = {
    { item = "Base.svd_stock_wood", weight = 1, partType = "Stock" },
    { item = "Base.VSS_stock_Tactical", weight = 1, partType = "Stock" },
    { item = "Base.VSS_stock_wood", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stock_win_type"] = {
    { item = "Base.win_1886_stock_wood", weight = 1, partType = "Stock" },
    { item = "Base.win_1895_stock", weight = 1, partType = "Stock" },
    { item = "Base.win_archangel_stock", weight = 1, partType = "Stock" },
    { item = "Base.win_m1887_grip", weight = 1, partType = "Stock" },
    { item = "Base.win_m1887_stock", weight = 1, partType = "Stock" },
    { item = "Base.win_mts_stock", weight = 1, partType = "Stock" },
    { item = "Base.win_SWM1854_stock_wood", weight = 1, partType = "Stock" },
    { item = "Base.win_sjorgen_stock", weight = 1, partType = "Stock" },
    { item = "Base.win_swm1894_stock", weight = 1, partType = "Stock" },
}

GGSWeaponUpgrades.Pools["stool_ak_gl"] = {
    { item = "Base.GP30_GL", weight = 1, partType = "Stool" },
    { item = "Base.GP30_GL_empty", weight = 1, partType = "Stool" },
    { item = "Base.M320_GL", weight = 1, partType = "Stool" },
    { item = "Base.M320_GL_empty", weight = 1, partType = "Stool" },
}

GGSWeaponUpgrades.Pools["stool_ar_gl"] = {
    { item = "Base.M203_GL", weight = 1, partType = "Stool" },
    { item = "Base.M203_GL_empty", weight = 1, partType = "Stool" },
    { item = "Base.M320_GL", weight = 1, partType = "Stool" },
    { item = "Base.M320_GL_empty", weight = 1, partType = "Stool" },
}

GGSWeaponUpgrades.Pools["stool_scar_gl"] = {
    { item = "Base.Scar_GL", weight = 1, partType = "Stool" },
    { item = "Base.Scar_GL_empty", weight = 1, partType = "Stool" },
}

GGSWeaponUpgrades.WeaponSlots["Base.A2000"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.A91"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
}

GGSWeaponUpgrades.WeaponSlots["Base.AA12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_rifle_sup", "canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.HoneyBadger"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ACE21"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ACE23"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ACE52_CQB"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ACE53"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ADS"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
}

GGSWeaponUpgrades.WeaponSlots["Base.AEK"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AEK919"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK19"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK101"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK103"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK47"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK5C"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK74"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK74u"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK74u_long"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK9"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AKM"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AKU12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AK_minidrako"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AMD65"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount", "mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AN94"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.APC9K"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AR10"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AR15"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AR6951"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ASH_12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AUG_9mm"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AUG_A1"] = {
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AUG_A2"] = {
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AWS"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ACR"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_scar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Anaconda"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Striker"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AssaultRifle"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AssaultRifle2"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Automag357"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Automag44"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Automag50AE"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.BAR"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Becker_Shotgun"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Becker_Shotgun_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.BenelliM4"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Beretta_A400"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Beretta_A400_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.AR160"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl", "stool_scar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Beretta_PX4"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Browning_Auto"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Browning_Auto_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.BrowningHP"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CBJ"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CETME"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CS5"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CZ805"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl", "stool_scar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CZ75"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CZScorpion"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CarcanoCarbine1891"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Carcano"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.CeiRigotti"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.M200"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.CircuitJudgeRifle"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Colt9mm"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ColtNavy1851"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ColtNavyExorcist"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ColtPeacemaker1873"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.DB_Condor"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.DB_Condor_sawn"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Coonan357"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Crossbow"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Crossbow_zhnets"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.K2"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.DDM4"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M16A2"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.DeLisle"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Deagle357_gold"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.DeagleCar14"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Deagle50AE"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.DoubleBarrelShotgun"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.DoubleBarrelShotgunSawnoff"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 10, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type", "stock_pistol_type", "stock_revolver_type", "stock_svd_vss_type", "stock_win_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ar_hg", "handguard_svd_hg"}, required = true },
    { partType = "Grip", pools = {"grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_pistol_laser", "laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ENARM_Pentagun"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Enfield1917"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.FAMAS"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SR338"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.FAL"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.FAL_CQB"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.FN2000"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.FN502_22LR"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.FNX45"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.FarquharHill"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.FedorovAvtomat"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.FedorovAvtomatMaxim"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.FiveSeven"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.G2"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.G36C"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.GOL"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.GSH18"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.G43"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.G17"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.G18"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Glock43"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Glock_tactical"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Grizzly50AE"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Groza"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.HK_121"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.HKMK23"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.HK416"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.HKG28"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.G3A3"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.G27"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Crossbow_hunting"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.HuntingRifle"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.HuotAutomaticRifle"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.IA2"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.IA2_308"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type", "stock_pistol_type", "stock_revolver_type", "stock_svd_vss_type", "stock_win_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Galil"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.JNG90"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Jericho941"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.K7"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.KAC_PDW"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.KS23"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Kark98"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_mosin_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.KSG"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Kimber1911"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Kriss9mm"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.KrissVector45"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.L115A"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.L85"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.L86"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.L96"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.LR300"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.LSAT"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.LVOA"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.LanchesterMK1"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Enfield"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Lewis"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M1"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.M110"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M1887"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M1887_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser", "laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_pistol_light", "light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M1A1"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.M21"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M24"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.M240B"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M249"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M39"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M4"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M40"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M60E4"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M82A3"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M9_Samurai"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M98B"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.M93R"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MAB38A"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MAC10"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MAS36"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MAT49"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 38, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MG131"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MG4"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MG42"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MG710"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MK18"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP18"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 38, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP1911"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP40"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 38, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP5"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP5K"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP5SD"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP7"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP9"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MPX"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MP_R8"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MSST"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MTAR"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_scar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MTS_255"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MTS_255_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MX4"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.MannlicherM1895"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MannlicherM1895_long"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MartiniHenry"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MatebaGrifone"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Mauser98"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MauserSelbstladerM1916"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Micro_UZI"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Mini_14"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Minimi"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 1, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type", "stock_pistol_type", "stock_revolver_type", "stock_svd_vss_type", "stock_win_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_pistol_laser", "laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg", "handguard_svd_hg"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Mondragon"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Mosin"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_mosin_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.MosinNagant1891"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_mosin_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Mossber500"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Mossber590"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Nagant_M1895"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Negev"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.OTS_33"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.P220"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.P220_Elite"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.P228"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.P90"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.P99_Kilin"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.PB6P9"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.PKP"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.PP2000"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.PP93"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.PPSH41"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.PP_Bizon"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Jackhammer"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.PieperM1893"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Pistol"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Pistol2"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Pistol3"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Python357"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.QBA"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_rifle_sup", "canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.QBB95"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 2, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount", "mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type", "stock_pistol_type", "stock_revolver_type", "stock_shotgun_type", "stock_svd_vss_type", "stock_win_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_pistol_laser", "laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg", "handguard_svd_hg"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.QBS09_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.QBS09"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.QBZ951"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.R5"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RMB93"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RPD"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RPK"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RPK12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RPK16"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RSC1917"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.RSH12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Remington1100_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Remington1100"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Remington121"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Remington870"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Remington870_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RemingtonModel8"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Revolver"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Revolver38"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Revolver666"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Revolver_long"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Revolver_short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_shotgun_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Rhino20DS"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RossMK3"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Ruger10_22"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.RugerLC"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Ruger357"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SWMP_12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SWM1854"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard_win_hg"}, required = true },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SWM1894"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard_win_hg"}, required = true },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SA58"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SAR21"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SIG_553"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SIG516"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SKS"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SKS_carbine"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SKS_carbine_short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SPAS12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SPAS15"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg", "handguard_svd_hg"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SR1M"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SR3M"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SR47"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SS2V5"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SV98"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SVD"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard_svd_hg"}, required = true },
    { partType = "Stock", pools = {"stock_svd_vss_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SVD_short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard_svd_hg"}, required = true },
    { partType = "Stock", pools = {"stock_svd_vss_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SVD12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_svd_vss_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SVDK"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard_svd_hg"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SVDK_short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard_svd_hg"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SVU"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SW1905"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SW1917"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SW500"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SWM3"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SWM327"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.SWM629_Deluxe"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.DVB15"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Saiga12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_rifle_sup", "canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Saiga9mm"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Handguard", pools = {"handguard_ak_hg"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Samurai_aw"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Samurai_kendo"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ScarH"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_scar_gl"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_scar_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ScarL"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_scar_gl"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_scar_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Schofield1875"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ScrapRevolver"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Selbstlader1906"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Shorty"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Shotgun"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.ShotgunSawnoff"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Silenced_Sten"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Sjorgen_Short"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Sjorgen"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SW629"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Snub22LR"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.XD"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Springfield1903"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Springfield_sniper"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Sten_MK5"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.M620"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stock", pools = {"stock_shotgun_type"}, required = true },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Scout_elite"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.TEC9"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.TMP"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.TankgewehrM1918"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount", "mount_rifle_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Taurus606"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Taurus_RT85"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Taurus_raging_bull"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Taurus_raging_bull460"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Crossbow_TenPoint"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Crossbow_TenPoint_hunting"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Thompson"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.SVT_40"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount", "mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Type81"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Type88"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.UMP45"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.UMP45_long"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.USAS12"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Glock23"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.USP45"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.UZI"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.VEPR"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.VP70"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.VR80"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Handguard", pools = {"handguard_ar_hg"}, required = true },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.VSK"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.VSS"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_svd_vss_type"}, required = true },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.VSS_Tactical"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_svd_vss_type"}, required = true },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.VSSK"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.VZ58"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.VZ61"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
}

GGSWeaponUpgrades.WeaponSlots["Base.V_M87"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.ValmetM82"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.VarmintRifle"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Veresk"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 38, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.VictorySW22"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.WA2000"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.P99"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Walther_P38"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Webley_MK_snub"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Webley_Revolver"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Wieger940"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "l_scope_direct", weight = 7, steps = {
            { partType = "L_Scope", pools = {"l_scope_ak_mount_scope"}, required = true },
        } },
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_ak_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Stock", pools = {"stock_ak_type", "stock_ar_type"}, required = true },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Stool", pools = {"stool_ak_gl", "stool_ar_gl"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Wildey"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}

GGSWeaponUpgrades.WeaponSlots["Base.Winchester1886"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard_win_hg"}, required = true },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Winchester1895"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Handguard", pools = {"handguard"}, required = true },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.Winchester1897"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "mount_scope", weight = 45, steps = {
            { partType = "Mount", pools = {"mount_shotgun_mount"}, required = true },
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
    { partType = "Stock", pools = {"stock_win_type"}, required = true },
}

GGSWeaponUpgrades.WeaponSlots["Base.X86"] = {
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.XM8"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 45, steps = {
            { partType = "Scope", pools = {"scope_large_scope", "scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Canon", pools = {"canon_pistol_sup", "canon_revolver_type", "canon_rifle_sup", "canon_smg_sup"}, prob = 0.18 },
    { partType = "Grip", pools = {"grip", "grip_grip_normal"}, prob = 0.3, requiresAnyPartType = {"Handguard"} },
    { partType = "Laser", pools = {"laser_rifle_laser"}, prob = 0.15 },
    { partType = "Barrel_Shroud", pools = {"barrel_shroud", "barrel_shroud_bipod"}, prob = 0.25 },
    { partType = "Misc", pools = {"misc"}, prob = 0.175 },
    { partType = "Light", pools = {"light_rifle_light"}, prob = 0.2 },
    { partType = "Stool", pools = {"stool_scar_gl"}, prob = 0.25 },
    { partType = "Sling", pools = {"sling"}, prob = 0.25 },
}

GGSWeaponUpgrades.WeaponSlots["Base.pistol_shotgun"] = {
    { slot = "Optic", prob = 0.12, conflictGroup = "optic", variants = {
        { key = "scope_direct", weight = 13, steps = {
            { partType = "Scope", pools = {"scope_medium_scope", "scope_mini_scope"}, required = true },
        } },
    } },
    { partType = "Laser", pools = {"laser_pistol_laser"}, prob = 0.15 },
    { partType = "Canon", pools = {"canon_shotgun_sup"}, prob = 0.18 },
    { partType = "Light", pools = {"light_pistol_light"}, prob = 0.2 },
}
