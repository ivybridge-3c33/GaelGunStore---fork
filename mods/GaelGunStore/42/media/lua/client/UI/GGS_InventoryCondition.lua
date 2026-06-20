local function getWeaponPartMaxCondition(item)
    if not item then
        return 0
    end
    local max = 0
    if item.getConditionMax then
        max = item:getConditionMax() or 0
    end
    if max <= 0 and item.getScriptItem then
        local scriptItem = item:getScriptItem()
        if scriptItem and scriptItem.getConditionMax then
            max = scriptItem:getConditionMax() or 0
            if max > 0 and item.setConditionMax then
                item:setConditionMax(max)
            end
        end
    end
    return max
end

local function ensureWeaponPartConditionState(item)
    if not item or not item.getCondition or not item.setCondition then
        return
    end
    local max = getWeaponPartMaxCondition(item)
    if max <= 0 then
        return
    end
    local current = item:getCondition() or 0
    if current <= 0 then
        item:setCondition(max)
    end
end

local function addWeaponPartConditionToTooltip(item, layout)
    if not item or not layout then
        return
    end
    local max = getWeaponPartMaxCondition(item)
    if max <= 0 then
        return
    end
    ensureWeaponPartConditionState(item)
    local current = max
    if item.getCondition then
        current = item:getCondition() or 0
    end
    if current < 0 then
        current = 0
    elseif current > max then
        current = max
    end
    local line = layout:addItem()
    line:setLabel(getText("IGUI_invpanel_Condition") .. ":", 1, 1, 1, 1)
    line:setValue(tostring(current) .. " / " .. tostring(max), 1, 1, 1, 1)
end

local function stripConditionSuffix(name)
    if type(name) ~= "string" then
        return tostring(name or "")
    end
    local clean = name
    local trimmed = clean:gsub("%s*%(%d+%%%)[%s]*$", "")
    while trimmed ~= clean do
        clean = trimmed
        trimmed = clean:gsub("%s*%(%d+%%%)[%s]*$", "")
    end
    return clean
end

local function getWeaponPartNameWithCondition(item, baseName)
    local cleanBase = stripConditionSuffix(baseName)
    local max = getWeaponPartMaxCondition(item)
    if max <= 0 then
        return cleanBase
    end

    ensureWeaponPartConditionState(item)
    local current = item.getCondition and item:getCondition() or 0
    if current < 0 then
        current = 0
    elseif current > max then
        current = max
    end

    local percent = math.floor((current * 100) / max)
    return string.format("%s (%d%%)", cleanBase, percent)
end

local function shouldSkipWeaponPartInInventoryTooltip()
    return WeaponPart and WeaponPart.__ggs_condition_tooltip
end

local ggsNamePatchState = _G.__ggs_weaponpart_name_patch_state or {}
_G.__ggs_weaponpart_name_patch_state = ggsNamePatchState

local function patchClassMetaMethod(class, methodName, patchKey, createPatch)
    if not (__classmetatables and class and methodName and createPatch) then
        return false
    end
    local metatable = __classmetatables[class]
    if not (metatable and metatable.__index) then
        return false
    end

    local stateKey = tostring(class) .. "::" .. tostring(methodName) .. "::" .. tostring(patchKey)
    if ggsNamePatchState[stateKey] then
        return true
    end

    local originalMethod = metatable.__index[methodName]
    if type(originalMethod) ~= "function" then
        return false
    end

    metatable.__index[methodName] = createPatch(originalMethod)
    ggsNamePatchState[stateKey] = true
    return true
end

local function applyWeaponPartTooltipPatch()
    local ready = true
    if InventoryItem and not InventoryItem.__ggs_weaponpart_condition_tooltip then
        local ggs_original_inventory_dotooltip = InventoryItem.DoTooltip

        function InventoryItem:DoTooltip(tooltip, layout)
            if not tooltip or not tooltip.beginLayout then
                return ggs_original_inventory_dotooltip(self, tooltip, layout)
            end

            if not layout then
                local newLayout = tooltip:beginLayout()
                ggs_original_inventory_dotooltip(self, tooltip, newLayout)
                if instanceof(self, "WeaponPart") and not shouldSkipWeaponPartInInventoryTooltip() then
                    addWeaponPartConditionToTooltip(self, newLayout)
                end
                tooltip:endLayout(newLayout)
                return
            end

            ggs_original_inventory_dotooltip(self, tooltip, layout)
            if instanceof(self, "WeaponPart") and not shouldSkipWeaponPartInInventoryTooltip() then
                addWeaponPartConditionToTooltip(self, layout)
            end
        end

        InventoryItem.__ggs_weaponpart_condition_tooltip = true
    elseif not InventoryItem then
        ready = false
    end

    if WeaponPart and not WeaponPart.__ggs_condition_tooltip then
        local ggs_original_weaponpart_dotooltip = WeaponPart.DoTooltip

        function WeaponPart:DoTooltip(tooltip, layout)
            if not tooltip or not tooltip.beginLayout then
                return ggs_original_weaponpart_dotooltip(self, tooltip, layout)
            end

            if not layout then
                local newLayout = tooltip:beginLayout()
                ggs_original_weaponpart_dotooltip(self, tooltip, newLayout)
                addWeaponPartConditionToTooltip(self, newLayout)
                tooltip:endLayout(newLayout)
                return
            end

            ggs_original_weaponpart_dotooltip(self, tooltip, layout)
            addWeaponPartConditionToTooltip(self, layout)
        end

        WeaponPart.__ggs_condition_tooltip = true
    elseif not WeaponPart then
        ready = false
    end

    if InventoryItem and not InventoryItem.__ggs_weaponpart_condition_name_patch then
        local origInventoryGetName = InventoryItem.getName
        if type(origInventoryGetName) == "function" then
            InventoryItem.getName = function(item, ...)
                local baseName = origInventoryGetName(item, ...)
                if instanceof(item, "WeaponPart") then
                    return getWeaponPartNameWithCondition(item, baseName)
                end
                return baseName
            end
        else
            ready = false
        end

        local origInventoryGetDisplayName = InventoryItem.getDisplayName
        if type(origInventoryGetDisplayName) == "function" then
            InventoryItem.getDisplayName = function(item, ...)
                local baseName = origInventoryGetDisplayName(item, ...)
                if instanceof(item, "WeaponPart") then
                    return getWeaponPartNameWithCondition(item, baseName)
                end
                return baseName
            end
        else
            ready = false
        end

        InventoryItem.__ggs_weaponpart_condition_name_patch = true
    elseif not InventoryItem then
        ready = false
    end

    if WeaponPart and not WeaponPart.__ggs_weaponpart_condition_name_patch then
        local origWeaponPartGetName = WeaponPart.getName
        if type(origWeaponPartGetName) == "function" then
            WeaponPart.getName = function(item, ...)
                local baseName = origWeaponPartGetName(item, ...)
                return getWeaponPartNameWithCondition(item, baseName)
            end
        else
            ready = false
        end

        local origWeaponPartGetDisplayName = WeaponPart.getDisplayName
        if type(origWeaponPartGetDisplayName) == "function" then
            WeaponPart.getDisplayName = function(item, ...)
                local baseName = origWeaponPartGetDisplayName(item, ...)
                return getWeaponPartNameWithCondition(item, baseName)
            end
        else
            ready = false
        end

        WeaponPart.__ggs_weaponpart_condition_name_patch = true
    elseif not WeaponPart then
        ready = false
    end

    if not _G.__ggs_weaponpart_condition_name_patch_meta then
        local patched = false
        if zombie and zombie.inventory and zombie.inventory.InventoryItem and zombie.inventory.InventoryItem.class then
            patched = patchClassMetaMethod(zombie.inventory.InventoryItem.class, "getName", "condition_name",
                function(orig)
                    return function(item, ...)
                        local baseName = orig(item, ...)
                        if instanceof(item, "WeaponPart") then
                            return getWeaponPartNameWithCondition(item, baseName)
                        end
                        return baseName
                    end
                end) or patched

            patched = patchClassMetaMethod(zombie.inventory.InventoryItem.class, "getDisplayName", "condition_display",
                function(orig)
                    return function(item, ...)
                        local baseName = orig(item, ...)
                        if instanceof(item, "WeaponPart") then
                            return getWeaponPartNameWithCondition(item, baseName)
                        end
                        return baseName
                    end
                end) or patched
        end

        if zombie and zombie.inventory and zombie.inventory.types and zombie.inventory.types.WeaponPart and zombie.inventory.types.WeaponPart.class then
            patched = patchClassMetaMethod(zombie.inventory.types.WeaponPart.class, "getName", "condition_name",
                function(orig)
                    return function(item, ...)
                        local baseName = orig(item, ...)
                        return getWeaponPartNameWithCondition(item, baseName)
                    end
                end) or patched

            patched = patchClassMetaMethod(zombie.inventory.types.WeaponPart.class, "getDisplayName", "condition_display",
                function(orig)
                    return function(item, ...)
                        local baseName = orig(item, ...)
                        return getWeaponPartNameWithCondition(item, baseName)
                    end
                end) or patched
        end

        if patched then
            _G.__ggs_weaponpart_condition_name_patch_meta = true
        else
            ready = false
        end
    end

    if not WeaponPart then
        ready = false
    end

    if ready and not _G.__ggs_condition_patch_ready_logged then
        _G.__ggs_condition_patch_ready_logged = true
    end

    return ready
end

local function applyWeaponPartTooltipPatchUntilReady()
    if applyWeaponPartTooltipPatch() then
        Events.OnTick.Remove(applyWeaponPartTooltipPatchUntilReady)
    end
end

local function eachItemRecursive(container, visit)
    if not container or not visit then
        return
    end
    local items = container.getItems and container:getItems() or nil
    if not items then
        return
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            visit(item)
            if instanceof(item, "InventoryContainer") and item.getInventory then
                eachItemRecursive(item:getInventory(), visit)
            end
        end
    end
end

local function getPartBaseName(item)
    if not item then
        return ""
    end
    local scriptItem = item.getScriptItem and item:getScriptItem() or nil
    if scriptItem and scriptItem.getDisplayName then
        local scriptName = scriptItem:getDisplayName()
        if scriptName and scriptName ~= "" then
            return stripConditionSuffix(getText(scriptName))
        end
    end
    local display = item.getDisplayName and item:getDisplayName() or item.getName and item:getName() or ""
    return stripConditionSuffix(display)
end

local function refreshWeaponPartCustomNames(playerObj)
    if not playerObj or playerObj:isDead() then
        return
    end
    local inv = playerObj.getInventory and playerObj:getInventory() or nil
    if not inv then
        return
    end

    eachItemRecursive(inv, function(item)
        if not instanceof(item, "WeaponPart") then
            return
        end
        local baseName = getPartBaseName(item)
        local targetName = getWeaponPartNameWithCondition(item, baseName)
        local currentName = item.getName and item:getName() or ""
        if stripConditionSuffix(currentName) ~= stripConditionSuffix(targetName) or currentName ~= targetName then
            if item.setName then
                item:setName(targetName)
            end
            if item.setCustomName then
                item:setCustomName(true)
            end
        end
    end)
end

local ggsCondTickCounter = 0
local function onConditionNameTick()
    ggsCondTickCounter = ggsCondTickCounter + 1
    if ggsCondTickCounter < 60 then
        return
    end
    ggsCondTickCounter = 0
    local playerObj = getPlayer and getPlayer() or nil
    if playerObj then
        refreshWeaponPartCustomNames(playerObj)
    end
end

if not _G.__ggsConditionTickRegistered then
    _G.__ggsConditionTickRegistered = true
    Events.OnTick.Add(onConditionNameTick)
end

applyWeaponPartTooltipPatch()
Events.OnGameStart.Add(function()
    applyWeaponPartTooltipPatch()
    Events.OnTick.Add(applyWeaponPartTooltipPatchUntilReady)
end)
