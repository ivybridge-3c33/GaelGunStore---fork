require "ISUI/ISFirearmRadialMenu"
pcall(require, "UI/GGS_MagSwapRadial")

local BIPOD_SLOT = "Barrel_Shroud"
local BIPOD_TOGGLE = {
    ["Base.bipod_harris"] = "Base.bipod_harris_open",
    ["Base.bipod_harris_open"] = "Base.bipod_harris",
    ["Base.bipod_old"] = "Base.bipod_old_open",
    ["Base.bipod_old_open"] = "Base.bipod_old",
    ["Base.bipod_simple"] = "Base.bipod_simple_open",
    ["Base.bipod_simple_open"] = "Base.bipod_simple",
    ["Base.scrap_bipod"] = "Base.scrap_bipod_open",
    ["Base.scrap_bipod_open"] = "Base.scrap_bipod",
}

local function ggsText(key)
    local text = getText(key)
    if text and text ~= key then
        return text
    end
    return key
end

local function addMagSwapSlice(self)
    local api = _G.GGS_MagSwapRadial
    if not (api and api.open and api.hasCandidates) then
        return
    end

    local playerObj = self and self.character or nil
    local weapon = self and self.getWeapon and self:getWeapon() or nil
    if not (playerObj and weapon) then
        return
    end
    if not api.hasCandidates(playerObj, weapon) then
        return
    end

    local menu = getPlayerRadialMenu(self.playerNum or playerObj:getPlayerNum())
    if not menu then
        return
    end

    local text = ggsText("IGUI_GGS_ChangeMagazine")
    local icon = getTexture and getTexture("media/textures/mag_swapper.png") or nil

    menu:addSlice(text, icon, function()
        api.open(playerObj, weapon, true)
    end)
end

local function isOpenBipod(fullType)
    return fullType and fullType:find("_open", 1, true) ~= nil
end

local function getInstalledBipod(weapon)
    if not (weapon and weapon.getWeaponPart) then
        return nil, nil
    end

    local ok, part = pcall(weapon.getWeaponPart, weapon, BIPOD_SLOT)
    if not ok then
        part = nil
    end
    if not part then
        ok, part = pcall(weapon.getWeaponPart, weapon, BIPOD_SLOT, false)
        if not ok then
            part = nil
        end
    end
    local fullType = part and part.getFullType and part:getFullType() or nil
    if fullType and BIPOD_TOGGLE[fullType] then
        return part, fullType
    end

    return nil, nil
end

local function copyPartState(sourcePart, targetPart)
    if not (sourcePart and targetPart) then
        return
    end

    if sourcePart.getCondition and targetPart.setCondition then
        pcall(targetPart.setCondition, targetPart, sourcePart:getCondition())
    end

    if sourcePart.getModData and targetPart.getModData then
        local sourceModData = sourcePart:getModData()
        local targetModData = targetPart:getModData()
        for key, value in pairs(sourceModData) do
            targetModData[key] = value
        end
    end

    if targetPart.transmitModData then
        pcall(targetPart.transmitModData, targetPart)
    end
end

local function syncBipodToggle(playerObj, weapon)
    if weapon and weapon.transmitModData then
        pcall(weapon.transmitModData, weapon)
    end
    if playerObj and weapon and syncHandWeaponFields then
        pcall(syncHandWeaponFields, playerObj, weapon)
    end
    if playerObj and playerObj.resetEquippedHandsModels then
        pcall(playerObj.resetEquippedHandsModels, playerObj)
    end
    if playerObj and playerObj.resetModelNextFrame then
        pcall(playerObj.resetModelNextFrame, playerObj)
    end
end

local function toggleBipod(playerObj, weapon)
    local currentPart, currentFullType = getInstalledBipod(weapon)
    local targetFullType = currentFullType and BIPOD_TOGGLE[currentFullType] or nil
    if not (currentPart and targetFullType and instanceItem and weapon and weapon.setWeaponPart) then
        return
    end

    local targetPart = instanceItem(targetFullType)
    if not targetPart then
        return
    end

    copyPartState(currentPart, targetPart)
    local ok = pcall(weapon.setWeaponPart, weapon, BIPOD_SLOT, targetPart)
    if ok then
        syncBipodToggle(playerObj, weapon)
    end
end

local function addBipodSlice(self)
    local playerObj = self and self.character or nil
    local weapon = self and self.getWeapon and self:getWeapon() or nil
    if not (playerObj and weapon) then
        return
    end

    local part, fullType = getInstalledBipod(weapon)
    if not (part and fullType) then
        return
    end

    local menu = getPlayerRadialMenu(self.playerNum or playerObj:getPlayerNum())
    if not menu then
        return
    end

    local targetFullType = BIPOD_TOGGLE[fullType]
    local iconItem = targetFullType and instanceItem and instanceItem(targetFullType) or part
    local icon = iconItem and iconItem.getTexture and iconItem:getTexture() or nil
    local text = isOpenBipod(fullType) and ggsText("IGUI_GGS_RetractBipod") or ggsText("IGUI_GGS_DeployBipod")

    menu:addSlice(text, icon, function()
        toggleBipod(playerObj, weapon)
    end)
end

local function patchFirearmRadialFill()
    if _G.__ggsReloadRadialMagSwapPatched then
        return
    end
    if not (ISFirearmRadialMenu and ISFirearmRadialMenu.fillMenu) then
        return
    end

    local vanillaFillMenu = ISFirearmRadialMenu.fillMenu
    ISFirearmRadialMenu.fillMenu = function(self, ...)
        local result = vanillaFillMenu(self, ...)
        addMagSwapSlice(self)
        addBipodSlice(self)
        return result
    end

    _G.__ggsReloadRadialMagSwapPatched = true
end

patchFirearmRadialFill()
if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(patchFirearmRadialFill)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(patchFirearmRadialFill)
end

-- GGS: direct hotkey (default B) to fold/deploy the installed bipod, so it can
-- be toggled without opening the firearm radial menu.
local function onToggleBipodKey(key)
    if not (getCore and getSpecificPlayer) then return end
    local ok, bound = pcall(function() return getCore():getKey("ToggleBipod") end)
    if not ok or not bound or key ~= bound then return end
    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end
    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    local part = getInstalledBipod(weapon)
    if part then
        toggleBipod(playerObj, weapon)
    end
end
if Events and Events.OnKeyPressed and Events.OnKeyPressed.Add then
    Events.OnKeyPressed.Add(onToggleBipodKey)
end
