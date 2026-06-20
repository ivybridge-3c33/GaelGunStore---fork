-- SELECT ATTACHMENT PANE
require "ISUI/ISPanel"

selectAttachmentPane = ISPanel:derive("selectAttachmentPane")
_G.selectAttachmentPane = selectAttachmentPane
require "AWCWF_AttachmentRules"

local AttachmentRules = AWCWF_AttachmentRules
local paneLogged = false
local debugPotential = false
local brokenItems = {
    ["Base.TestAccessory"] = true,
}
local SLOT_COLUMNS = 5
local SLOT_SIZE = rawget(_G, "AWCWF_ATTACHMENT_SLOT_SIZE") or 60 -- 50% larger tiles for better readability
local SLOT_GAP = 1
local SLOT_MARGIN = 2
local VISIBLE_ROWS = 3
local SLOT_STEP = SLOT_SIZE + SLOT_GAP
local ROW_SCROLL_STEP = SLOT_SIZE + SLOT_MARGIN
local PANEL_HEIGHT = VISIBLE_ROWS * ROW_SCROLL_STEP
local PANEL_WIDTH = SLOT_SIZE * SLOT_COLUMNS + 20
local PANEL_MIN_WIDTH = SLOT_SIZE * SLOT_COLUMNS + 8
-- Default to showing potential attachments if the global flag was never initialized.
if riskyShowPotentialAttachment == nil then
    riskyShowPotentialAttachment = true
end
local function logAttachmentPane(message)
    if debugPotential then
        print("[AWCWF AttachmentPane] " .. tostring(message))
    end
end

local function safeCallBool(owner, fnName)
    if not owner or type(owner[fnName]) ~= "function" then
        return false
    end
    local ok, value = pcall(owner[fnName], owner)
    return ok and value == true
end

local function isDebugModeEnabled()
    if type(isDebugEnabled) == "function" then
        local ok, value = pcall(isDebugEnabled)
        if ok and value == true then
            return true
        end
    end
    if type(getDebug) == "function" then
        local ok, value = pcall(getDebug)
        if ok and value == true then
            return true
        end
    end
    if type(getCore) == "function" then
        local ok, core = pcall(getCore)
        if ok and core then
            if safeCallBool(core, "isDebug")
                    or safeCallBool(core, "isDebugEnabled")
                    or safeCallBool(core, "isInDebug")
                    or safeCallBool(core, "getDebug")
                    or safeCallBool(core, "getOptionDebug") then
                return true
            end
        end
    end
    return false
end

function GGS_isDevAttachmentSpawnerEnabled()
    if SandboxVars and SandboxVars.GGSGS and SandboxVars.GGSGS.DevAttachmentSpawner == true then
        return true
    end
    return isDebugModeEnabled()
end

local function shouldShowPotentialAttachments()
    return riskyShowPotentialAttachment or GGS_isDevAttachmentSpawnerEnabled()
end

local function collectWeaponPartsRecursive(container, out)
    if not container or not out then
        return
    end
    local items = container.getItems and container:getItems()
    if not items then
        return
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if instanceof(item, "WeaponPart") then
                out[#out + 1] = item
            elseif instanceof(item, "InventoryContainer") and item.getInventory then
                collectWeaponPartsRecursive(item:getInventory(), out)
            end
        end
    end
end

local function buildWeaponPartStateToken(weapon)
    if not weapon or not weapon.IsWeapon or not weapon:IsWeapon() then
        return "nil"
    end

    local parts = {}
    local all = weapon.getAllWeaponParts and weapon:getAllWeaponParts() or nil
    if all then
        for i = 0, all:size() - 1 do
            local part = all:get(i)
            if part then
                local pType = part.getPartType and part:getPartType() or "?"
                local full = part.getFullType and part:getFullType() or "?"
                parts[#parts + 1] = tostring(pType) .. "=" .. tostring(full)
            end
        end
    end

    table.sort(parts)
    parts[#parts + 1] = "containsClip=" .. tostring(weapon.isContainsClip and weapon:isContainsClip() or false)
    parts[#parts + 1] = "magType=" .. tostring(weapon.getMagazineType and weapon:getMagazineType() or "nil")
    return table.concat(parts, ";")
end

function selectAttachmentPane:new(x, y, category, ClipType, AttackModeType, SkinType)
    local o = {}
    o = ISPanel:new(x, y, PANEL_WIDTH, PANEL_HEIGHT);
    setmetatable(o, self)
    self.__index = self
    o.ClipType = ClipType
    o.AttackModeType = AttackModeType
    o.SkinType = SkinType
    o.category = category
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 1
    };
    o.borderColor = {
        r = 0.9,
        g = 0.9,
        b = 0.9,
        a = 0.7
    };
    o.currentPrimaryItem = getPlayer():getPrimaryHandItem()
    o.elements = {}
    o.showPotentialAttachment = shouldShowPotentialAttachments()
    o.devAttachmentSpawner = GGS_isDevAttachmentSpawnerEnabled()
    if o.showPotentialAttachment then
        o.potentialAttachment = {}
        local function addCandidate(item)
            if not item then
                return
            end
            local typeString = item.getTypeString and item:getTypeString() or nil
            local typeName = item.getType and item:getType() or nil
            local itemType = item.getItemType and item:getItemType() or nil
            local isScriptItem = (typeString == "WeaponPart") or (tostring(typeName) == "WeaponPart")
            local isItemType = itemType and tostring(itemType):lower():find("weaponpart", 1, true) ~= nil
            if not (isScriptItem or isItemType) then
                return
            end
            local obsolete = type(item.getObsolete) == "function" and item:getObsolete() or false
            local hidden = type(item.isHidden) == "function" and item:isHidden() or false
            if obsolete or hidden then
                return
            end
            local fullName = type(item.getFullName) == "function" and item:getFullName() or nil
            if fullName then
                o.potentialAttachment[fullName] = item
            end
        end

        local items = nil
        if type(getAllItems) == "function" then
            items = getAllItems()
        end
        -- Tolerate environments where getAllItems is missing or returns nil; fall back to ScriptManager
        local function loadList(list)
            if not list then
                return false
            end
            -- Java-style list (size/get)
            if list.size and type(list.size) == "function" and list.get then
                for i = 0, list:size() - 1 do
                    addCandidate(list:get(i))
                end
                return true
            end
            -- Plain Lua table
            if type(list) == "table" then
                for _, entry in pairs(list) do
                    addCandidate(entry)
                end
                return true
            end
            return false
        end
        if not loadList(items) then
            local sm = getScriptManager and getScriptManager()
            if sm and sm.getAllItems then
                loadList(sm:getAllItems())
            end
        end
    end
    if not paneLogged then
        paneLogged = true
        logAttachmentPane("UI loaded (filtered potential list v2)")
    end
    return o
end
function selectAttachmentPane:prerender()
    self:setStencilRect(0, 0, self.width, self.height);
    self:drawRect(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.backgroundColor.a,
        self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
end
function selectAttachmentPane:render()
    self:clearStencilRect();
    self:drawRectBorder(-self:getXScroll(), -self:getYScroll(), self.width, self.height, self.borderColor.a,
        self.borderColor.r, self.borderColor.g, self.borderColor.b);
end
function selectAttachmentPane:createChildren()
    self:addScrollBars(false)
    self:setScrollWithParent(false)
    self:setScrollChildren(true)
end
function selectAttachmentPane:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - (del * ROW_SCROLL_STEP))
    return true;
end
function selectAttachmentPane:update()
    if self and self:getIsVisible() then
        if (self.currentPrimaryItem ~= getPlayer():getPrimaryHandItem() or riskyInspectWindow == nil) then
            self:close()
        end
        local weapon = getPlayer():getPrimaryHandItem()
        local weaponState = buildWeaponPartStateToken(weapon)
        if self.itemCap ~= getPlayer():getInventory():getItems():size() or self.itemWeight ~=
            getPlayer():getInventory():getCapacityWeight() or self.weaponStateToken ~= weaponState then
            self.itemCap = getPlayer():getInventory():getItems():size()
            self.itemWeight = getPlayer():getInventory():getCapacityWeight()
            self.weaponStateToken = weaponState
            if (#self.elements ~= 0) then
                for i = 1, #self.elements do
                    self:removeChild(self.elements[i])
                end
            end
            self.elements = {}
            self:renderInventory()
        end
    end
end
function selectAttachmentPane:renderInventory()
    local weapon = getPlayer():getPrimaryHandItem()
    if getPlayer():getPrimaryHandItem() ~= nil and getPlayer():getPrimaryHandItem():IsWeapon() then
        local visibleSlots = nil
        if AttachmentRules and weapon then
            visibleSlots = AttachmentRules.getVisibleSlots(weapon)
            local slotNameForRules = self.category
            if self.ClipType == "ClipType" then
                slotNameForRules = "Clip"
            elseif self.AttackModeType == "WeaponAttackType" or self.SkinType == "Skin" then
                slotNameForRules = nil
            end
            if slotNameForRules and not AttachmentRules.isSlotVisible(weapon, slotNameForRules, visibleSlots) then
                self:setScrollHeight(0)
                return
            end
        end
        local weaponParts = {}
        collectWeaponPartsRecursive(getPlayer():getInventory(), weaponParts)
        local alreadyDoneList = {};
        local itemNum = 0
        local rowCount = -1
        for i = 1, #weaponParts do
            local part = weaponParts[i];
            local partKey = (part.getFullType and part:getFullType()) or part:getName()
            if part:getMountOn():contains(weapon:getFullType()) and not alreadyDoneList[partKey] then
                if part:getPartType() == self.category then
                    alreadyDoneList[partKey] = true;
                    local canInstall = not AttachmentRules or AttachmentRules.canInstallOnWeapon(weapon, part, visibleSlots)
                    if canInstall then
                        if (math.fmod(itemNum, SLOT_COLUMNS) == 0) then
                            rowCount = rowCount + 1
                        end
                        local x = SLOT_MARGIN + SLOT_STEP * math.fmod(itemNum, SLOT_COLUMNS)
                        local y = SLOT_MARGIN + SLOT_STEP * rowCount
                        if self.showPotentialAttachment then
                            self.potentialAttachment[part:getFullType()] = nil
                        end
                        local item = addAttachmentButton:new(x, y, SLOT_SIZE, SLOT_SIZE, part, weapon, true, "WeaponPart")
                        table.insert(self.elements, item)
                        item:bringToTop()
                        self:addChild(item)
                        itemNum = itemNum + 1
                    end
                end
            end
        end
        if self.ClipType == "ClipType" then
            local weaponMagTypes = _G.AWCWF_WeaponMagazineType
            local mags = weaponMagTypes and weaponMagTypes[weapon:getType()] or nil
            if mags then
                for j = 1, #mags do
                    local TempPart = instanceItem(mags[j]);
                    local tempKey = TempPart and TempPart.getFullType and TempPart:getFullType()
                    if TempPart and not alreadyDoneList[tempKey] then
                        if (math.fmod(itemNum, SLOT_COLUMNS) == 0) then
                            rowCount = rowCount + 1
                        end
                        local x = SLOT_MARGIN + SLOT_STEP * math.fmod(itemNum, SLOT_COLUMNS)
                        local y = SLOT_MARGIN + SLOT_STEP * rowCount
                        local item = addAttachmentButton:new(x, y, SLOT_SIZE, SLOT_SIZE, TempPart, weapon, true, "ClipType")
                        table.insert(self.elements, item)
                        item:bringToTop()
                        self:addChild(item)
                        itemNum = itemNum + 1
                        alreadyDoneList[tempKey] = true
                    end
                end
            end
        end
        if self.SkinType == "Skin" then
            local weaponSkins = _G.CatWeaponSkin
            if weaponSkins and weaponSkins[weapon:getType()] then
                local SkinTableNow = weaponSkins[weapon:getType()]
                for j = 1, #SkinTableNow do
                    if (math.fmod(itemNum, SLOT_COLUMNS) == 0) then
                        rowCount = rowCount + 1
                    end
                    local x = SLOT_MARGIN + SLOT_STEP * math.fmod(itemNum, SLOT_COLUMNS)
                    local y = SLOT_MARGIN + SLOT_STEP * rowCount
                    local SkinItem = instanceItem("Base." .. SkinTableNow[j]);
                    if getPlayer():isRecipeKnown(SkinTableNow[j]) or j == 1 then
                        item = addAttachmentButton:new(x, y, SLOT_SIZE, SLOT_SIZE, SkinItem, weapon, true, "Skin")
                    else
                        item = addAttachmentButton:new(x, y, SLOT_SIZE, SLOT_SIZE, SkinItem, weapon, false, "Skin")
                    end
                    item:bringToTop()
                    self:addChild(item)
                    x = x + SLOT_STEP
                end
            end
        end
        if self.AttackModeType == "WeaponAttackType" then
            local weaponAttackTypes = _G.AWCWF_WeaponAttackType
            if weaponAttackTypes and weaponAttackTypes[weapon:getType()] then
                local AttackTableNow = weaponAttackTypes[weapon:getType()]
                for j = 1, #AttackTableNow do
                    local AttackTypeItem = instanceItem(AttackTableNow[j]);
                    local needflag = false
                    local CreatFlag = true
                    if string.find(weapon:getType(), "Brynhild") then
                        needflag = true
                    end
                    if needflag then
                        if not getPlayer():getInventory():contains(AttackTableNow[j]) then
                            CreatFlag = false
                        end
                    end
                    if (math.fmod(itemNum, SLOT_COLUMNS) == 0) then
                        rowCount = rowCount + 1
                    end
                    local x = SLOT_MARGIN + SLOT_STEP * math.fmod(itemNum, SLOT_COLUMNS)
                    local y = SLOT_MARGIN + SLOT_STEP * rowCount
                    if AttackTypeItem and CreatFlag then
                        local item = addAttachmentButton:new(x, y, SLOT_SIZE, SLOT_SIZE, AttackTypeItem, weapon, true, "WeaponAttackType")
                        table.insert(self.elements, item)
                        item:bringToTop()
                        self:addChild(item)
                        itemNum = itemNum + 1
                    end
                end
            end
        end
        if self.showPotentialAttachment and self.category ~= "Clip" then
            local totalBefore, totalAdded, totalRemoved = 0, 0, 0
            for fullType, scriptItem in pairs(self.potentialAttachment) do
                local scriptPartType = scriptItem and scriptItem.getPartType and scriptItem:getPartType()
                local isClipItem = fullType:find("%.Clip") ~= nil or (scriptPartType == "Clip")
                if not isClipItem then
                    totalBefore = totalBefore + 1
                    local removeEntry = brokenItems[fullType] or false
                    local removeReason = removeEntry and "blocked" or nil

                    local potentialPart
                    if not removeEntry then
                        local ok, created = pcall(instanceItem, fullType)
                        if ok then
                            potentialPart = created
                        end
                        if not potentialPart then
                            removeEntry = true
                            brokenItems[fullType] = true
                            removeReason = "instance failed"
                        end
                    end

                    if not removeEntry and potentialPart then
                        local mountOn = potentialPart.getMountOn and potentialPart:getMountOn()
                        local partType = potentialPart.getPartType and potentialPart:getPartType()
                        if mountOn and partType and mountOn:contains(weapon:getFullType()) and partType == self.category then
                            local canInstall = not AttachmentRules or AttachmentRules.canInstallOnWeapon(weapon, potentialPart, visibleSlots)
                            if canInstall then
                                if (math.fmod(itemNum, SLOT_COLUMNS) == 0) then
                                    rowCount = rowCount + 1
                                end
                                local x = SLOT_MARGIN + SLOT_STEP * math.fmod(itemNum, SLOT_COLUMNS)
                                local y = SLOT_MARGIN + SLOT_STEP * rowCount
                                local item = addAttachmentButton:new(x, y, SLOT_SIZE, SLOT_SIZE, potentialPart, weapon, self.devAttachmentSpawner, "WeaponPart")
                                if self.devAttachmentSpawner then
                                    item.devSpawnMissing = true
                                    item.devSpawnFullType = fullType
                                end
                                table.insert(self.elements, item)
                                item:bringToTop()
                                self:addChild(item)
                                itemNum = itemNum + 1
                                totalAdded = totalAdded + 1
                            end
                        elseif not mountOn or not partType then
                            removeEntry = true
                            brokenItems[fullType] = true
                            removeReason = "missing mount/partType"
                        end
                    end

                    if removeEntry then
                        self.potentialAttachment[fullType] = nil
                        totalRemoved = totalRemoved + 1
                        if debugPotential then
                            logAttachmentPane(("Filtered %s (%s) for %s"):format(tostring(fullType), tostring(self.category), removeReason or "unknown"))
                        end
                    end
                end
            end
            if debugPotential then
                logAttachmentPane(("Category %s: start=%d, added=%d, removed=%d"):format(tostring(self.category), totalBefore, totalAdded, totalRemoved))
            end
        end
        self:setScrollHeight(ROW_SCROLL_STEP * (rowCount + 1))
        if (self:getHeight() >= self:getScrollHeight()) then
            self:setWidth(PANEL_MIN_WIDTH)
        end
    end
end
function selectAttachmentPane:close()
    self:setVisible(false)
end
function selectAttachmentPane:onMouseDownOutside(x, y)
    if self:getIsVisible() and not self.vscroll:isMouseOver() then
        self:close()
    end
end
-- SELECT MAGAZINE PANE

return selectAttachmentPane
