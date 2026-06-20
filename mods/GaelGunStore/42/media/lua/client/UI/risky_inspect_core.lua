-- Core file, contains all the event listeners and windows handler
-- Orginal auther : risky 
-- Have access to rebuild
require "ISUI/ISPanel"
require "TimedActions/ISEquipWeaponAction"
require "AWCWF_AttachmentRules"
local okInfoPanel, riskyInfoPanelModule = pcall(require, "UI/risky_inspect_info_panel")
riskyInspectWindow = nil
riskyShowPotentialAttachment = true
AWCWF_WeaponAttackType = AWCWF_WeaponAttackType or {}
riskyUI = ISPanel:derive("riskyUI")
local riskyInfoPanelClass = nil
if okInfoPanel and riskyInfoPanelModule then
    riskyInfoPanelClass = riskyInfoPanelModule
elseif rawget(_G, "riskyUI_infoPanel") then
    riskyInfoPanelClass = rawget(_G, "riskyUI_infoPanel")
end
local ATTACHMENT_SLOT_SIZE = rawget(_G, "AWCWF_ATTACHMENT_SLOT_SIZE") or 60
local ATTACHMENT_SLOT_BASE = rawget(_G, "AWCWF_ATTACHMENT_SLOT_BASE") or 40
local ATTACHMENT_SLOT_OFFSET = rawget(_G, "AWCWF_ATTACHMENT_SLOT_OFFSET")
if not ATTACHMENT_SLOT_OFFSET then
    ATTACHMENT_SLOT_OFFSET = (ATTACHMENT_SLOT_SIZE - ATTACHMENT_SLOT_BASE) / 2
end
local STAT_BAR_BASE_WIDTH = 100
local STAT_BAR_SCALE = rawget(_G, "AWCWF_STAT_BAR_SCALE") or 0.50
local STAT_BAR_MAX_WIDTH = STAT_BAR_BASE_WIDTH * STAT_BAR_SCALE
local GUNATTPART_BUTTON_SIZE = math.floor(64 * 0.75)
local function getTextSafe(primaryKey, fallbackKey)
    local text = getText(primaryKey)
    if text == primaryKey and fallbackKey then
        local fallback = getText(fallbackKey)
        if fallback ~= fallbackKey then
            return fallback
        end
    end
    return text
end
local function createAttachmentSlot(x, y, slotItem, weapon, slotType, options)
    return attachmentButton:new(x - ATTACHMENT_SLOT_OFFSET, y - ATTACHMENT_SLOT_OFFSET, ATTACHMENT_SLOT_SIZE,
        ATTACHMENT_SLOT_SIZE, slotItem, weapon, slotType, options)
end
local function getScaledStatWidth(valuePerc)
    return STAT_BAR_MAX_WIDTH * valuePerc
end
local btnView = getText("IGUI_RISKY_VIEW")
local btnViewWid = getTextManager():MeasureStringX(UIFont.NewSmall, btnView) + 10
local btnViewHgt = getTextManager():MeasureStringY(UIFont.NewSmall, btnView) + 10

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

function riskyUI:onOptionMouseDown(button)
    if button.internal == "close" then
        self:close()
    end
    if button.internal == "Rotate" then
        self.scene.startRotate = not self.scene.startRotate
    end
    if button.internal == "Info" then
        self:toggleInfoPanel()
    end
end
function riskyUI:close()
    self:setVisible(false)
    -- AWCWF_Attach.Apply_Effect(getPlayer(), self.currentPrimaryItem)
    getPlayer():clearVariable("IsInspectOneHandedRanged")
    getPlayer():clearVariable("IsInspectTwoHandedRanged")
    if riskyInfoPanelClass and riskyInfoPanelClass.instance then
        riskyInfoPanelClass.instance:close()
        riskyInfoPanelClass.instance = nil
    end
    if ItemPreviewUI and ItemPreviewUI.instance then
        ItemPreviewUI.instance:destroy()
        ItemPreviewUI.instance = nil
    end
end

function riskyUI:toggleInfoPanel()
    if not riskyInfoPanelClass then
        return
    end

    if riskyInfoPanelClass.instance and riskyInfoPanelClass.instance:getIsVisible() then
        riskyInfoPanelClass.instance:close()
        riskyInfoPanelClass.instance = nil
        return
    end

    local width = math.max(380, math.floor(self:getWidth() * 0.40))
    local height = math.max(260, math.floor(self:getHeight() * 0.60))
    local x = self:getX() + self:getWidth() + 12
    local y = self:getY()
    if x + width > getCore():getScreenWidth() then
        x = math.max(10, self:getX() - width - 12)
    end

    local panel = riskyInfoPanelClass:new(x, y, width, height, self)
    panel:initialise()
    panel:addToUIManager()
    riskyInfoPanelClass.instance = panel
end

function riskyUI:new(x, y, width, height)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.panelWidth = 0
    o.background = true
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0.70
    }
    o.borderColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0
    }
    o.panelHeight = 0
    o.currentPrimaryItem = getPlayer():getPrimaryHandItem()
    o.itemWeight = getPlayer():getInventory():getCapacityWeight()
    o.itemCap = getPlayer():getInventory():getItems():size()
    o.weaponCondition = (getPlayer():getPrimaryHandItem():getCondition() * 100) /
                            getPlayer():getPrimaryHandItem():getConditionMax()
    o.weaponStateToken = buildWeaponPartStateToken(getPlayer():getPrimaryHandItem())
    o.moveWithMouse = true
    local weapon = getPlayer():getPrimaryHandItem()
    if (weapon:IsWeapon() and weapon:isRanged()) then
        if (weapon:isTwoHandWeapon()) then
            getPlayer():setVariable("IsInspectTwoHandedRanged", "true")
        else
            getPlayer():setVariable("IsInspectOneHandedRanged", "true")
        end
    end
    return o
end
function riskyUI:update()
    if self and self:getIsVisible() then
        if (self.currentPrimaryItem ~= getPlayer():getPrimaryHandItem()) then
            self:close()
        end
        local currentWeapon = getPlayer():getPrimaryHandItem()
        if not currentWeapon then
            self:close()
            return
        end
        local currentWeaponCondition = (currentWeapon:getCondition() * 100) / currentWeapon:getConditionMax()
        local weaponState = buildWeaponPartStateToken(currentWeapon)
        if self.itemCap ~= getPlayer():getInventory():getItems():size() or self.itemWeight ~=
            getPlayer():getInventory():getCapacityWeight() or self.weaponCondition ~= currentWeaponCondition or
            self.weaponStateToken ~= weaponState then
            self.itemCap = getPlayer():getInventory():getItems():size()
            self.itemWeight = getPlayer():getInventory():getCapacityWeight()
            self.weaponCondition = currentWeaponCondition
            self.weaponStateToken = weaponState
            self:renderInventory()
        end
    end
end

local AttachmentRules = AWCWF_AttachmentRules

local function stripConditionSuffixes(name)
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

local function getDisplayNameWithCondition(item, defaultName)
    local name = stripConditionSuffixes(defaultName or getText('IGUI_NONE'))
    if not item then
        return name
    end

    local maxCondition = item.getConditionMax and item:getConditionMax() or 0
    local currentCondition = item.getCondition and item:getCondition() or 0
    if currentCondition < 0 then
        currentCondition = 0
    end

    -- Some weapon parts arrive with condition set but maxCondition missing (0) in B42.
    -- Use a safe fallback so the percent stays visible in the inspect UI.
    if maxCondition <= 0 then
        if currentCondition <= 0 then
            return name
        end
        if currentCondition > 100 then
            maxCondition = currentCondition
        else
            maxCondition = 100
        end
    elseif currentCondition > maxCondition then
        currentCondition = maxCondition
    end

    local percent = math.floor((currentCondition * 100) / maxCondition)
    return string.format("%s (%d%%)", name, percent)
end

local function drawAttachment(self, weapon, type, x, y, visibleSet)
    if AttachmentRules and not AttachmentRules.isSlotVisible(weapon, type, visibleSet) then
        return
    end
    local attachment = weapon:getWeaponPart(type)
    if AttachmentRules then
        local resolved = AttachmentRules.getAttachment and AttachmentRules.getAttachment(weapon, type)
        if resolved then
            attachment = resolved
        end
    end
    local displayName = getText('IGUI_NONE')
    if attachment ~= nil then
        displayName = getDisplayNameWithCondition(attachment, attachment:getDisplayName());
    end
    self:drawText(displayName, x, y, 1, 1, 1, 1, UIFont.Small);
    self:drawText(getText('IGUI_' .. type), x, y + 20, 1, 1, 1, 1, UIFont.Small);
end

local partlist = (AWCWF_AdditionalParts and AWCWF_AdditionalParts.partlist) or {}
local function getAmmoItemKey(ammoType)
    if not ammoType or ammoType == "" then
        return nil
    end
    if type(ammoType) == "string" then
        return ammoType
    end
    if ammoType.getItemKey then
        return ammoType:getItemKey()
    end
    return tostring(ammoType)
end

local function countGunAttParts(container)
    if not container then
        return 0
    end
    local total = container:getItemCount("Base.GunAttParts")
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local inner = items:get(i)
        if instanceof(inner, "InventoryContainer") then
            total = total + countGunAttParts(inner:getInventory())
        end
    end
    return total
end

local function getAttacheMentCount(weapon)
    local ReturnList = {
        WeightModifier = 0,
        SpreadModifier = 0,
        Angle = 0,
        Damage = 0,
        ReloadTime = 0,
        LowLightBonus = 0,
        HitChance = 0,
        MinRangeRanged = 0,
        AimingTime = 0,
        MinSightRange = 0,
        MaxRange = 0,
        RecoilDelay = 0,
        MaxSightRange = 0,
        SoundModifier = 0
    }
    for i, v in ipairs(partlist) do
        if weapon:getWeaponPart(v) and v ~= "Clip" then
            local item = weapon:getWeaponPart(v)
            if item then
                if item:getWeightModifier() then
                    ReturnList["WeightModifier"] = ReturnList["WeightModifier"] + item:getWeightModifier()
                end
                if item:getSpreadModifier() then
                    ReturnList["SpreadModifier"] = ReturnList["SpreadModifier"] + item:getSpreadModifier()
                end
                if item:getAngle() then
                    ReturnList["Angle"] = ReturnList["Angle"] + item:getAngle()
                end
                if item:getDamage() then
                    ReturnList["Damage"] = ReturnList["Damage"] + item:getDamage()
                end
                if item:getReloadTime() then
                    ReturnList["ReloadTime"] = ReturnList["ReloadTime"] + item:getReloadTime()
                end
                if item:getLowLightBonus() then
                    ReturnList["LowLightBonus"] = ReturnList["LowLightBonus"] + item:getLowLightBonus()
                end
                if item:getHitChance() then
                    ReturnList["HitChance"] = ReturnList["HitChance"] + item:getHitChance()
                end
                if item:getMinRangeRanged() then
                    ReturnList["MinRangeRanged"] = ReturnList["MinRangeRanged"] + item:getMinRangeRanged()
                end
                if item:getAimingTime() then
                    ReturnList["AimingTime"] = ReturnList["AimingTime"] + item:getAimingTime()
                end
                if item:getMinSightRange() then
                    ReturnList["MinSightRange"] = ReturnList["MinSightRange"] + item:getMinSightRange()
                end
                if item:getMaxRange() then
                    ReturnList["MaxRange"] = ReturnList["MaxRange"] + item:getMaxRange()
                end
                if item:getRecoilDelay() then
                    ReturnList["RecoilDelay"] = ReturnList["RecoilDelay"] + item:getRecoilDelay()
                end
                if item:getMaxSightRange() then
                    ReturnList["MaxSightRange"] = ReturnList["MaxSightRange"] + item:getMaxSightRange()
                end
            end
            if item:getPartType() == "Canon" then
                if (string.find(item:getDisplayName(), getTextSafe("IGUI_Slience", "IGUI_Silence")) or
                    string.find(item:getType(), "Silencer") or string.find(item:getType(), "silencer")) then
                    ReturnList["SoundModifier"] = ReturnList["SoundModifier"] - 40
                end
            end
        end
    end
    return ReturnList
end

function riskyUI:prerender()
    ISPanel.prerender(self)
    local BackGroundPanelTexture = getTexture("media/textures/UI/AWCWF_BackGround.png")
    self:drawTextureScaled(BackGroundPanelTexture, 0, 0, self.width, self.height, 1, 0.5, 0.5, 0.5)
    if getPlayer():getPrimaryHandItem() ~= nil and getPlayer():getPrimaryHandItem():IsWeapon() then
        local weapon = getPlayer():getPrimaryHandItem()
        local conditionPerc = (weapon:getCondition() * 100) / weapon:getConditionMax()
        self:drawTextureScaled(weapon:getTexture(), 10, 35, 64, 64, 1, 1, 1, 1)
        local weaponrate = weapon:getCondition() / weapon:getConditionMax()
        local dely = (1 - weaponrate) * 64
        local adely = weaponrate * 64
        local colorr = 1 - weaponrate
        local colorg = weaponrate
        self:drawRectStatic(10, 35 + dely, 64, adely, 0.1, colorr, colorg, 0);
        self:drawRectBorder(10, 35, 64, 64, 0.3, 1, 1, 1)
        local conditionText = tostring(math.floor(conditionPerc)) .. "%"

        self:drawText(conditionText, 65 + 32, 55, 1, 1, 1, 1, UIFont.Small)
        local repairText = ""
        if weapon:getHaveBeenRepaired() == 1 then
            repairText = getText('IGUI_RISKY_REPAIR_HEAVILY')
        elseif weapon:getHaveBeenRepaired() > 1 and weapon:getHaveBeenRepaired() < 4 then
            repairText = getText('IGUI_RISKY_REPAIR_SLIGHTLY')
        else
            repairText = getText('IGUI_RISKY_REPAIR_NONE')
        end
        self:drawText(weapon:getDisplayName(), 65 + 32, 35, 1, 1, 1, 1, UIFont.Medium)
        self:drawText(repairText, 65 + 32, 70, 1, 1, 1, 1, UIFont.Small)
        if weapon:isRanged() then
            local OriginItem = instanceItem(weapon:getFullType())
            local WeaponDataList = {{
                Name = "IGUI_WeaponUI_DamegeMax",
                Value = OriginItem:getMaxDamage(),
                BonusType = "Damage",
                BounsAdd = true,
                MaxValue = 5,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_DamegeMin",
                Value = OriginItem:getMinDamage(),
                MaxValue = 5,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_RangeMax",
                Value = OriginItem:getMaxRange(),
                BonusType = "MaxRange",
                BounsAdd = true,
                MaxValue = 60,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_AngleMax",
                Value = OriginItem:getMaxAngle(),
                BonusType = "Angle",
                BounsAdd = true,
                MaxValue = 1,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_AngleMin",
                Value = OriginItem:getMinAngle(),
                BonusType = "Angle",
                BounsAdd = true,
                MaxValue = 1,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_CriticalChance",
                Value = OriginItem:getCriticalChance(),
                -- BonusType = "Critical",
                MaxValue = 100,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_AimingTime",
                Value = OriginItem:getAimingTime(),
                BonusType = "AimingTime",
                BounsAdd = false,
                MaxValue = 30,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_ReloadTime",
                Value = OriginItem:getReloadTime(),
                BounsAdd = false,
                BonusType = "ReloadTime",
                MaxValue = 60,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_FireRate",
                Value = OriginItem:getRecoilDelay(),
                BounsAdd = false,
                BonusType = "RecoilDelay",
                MaxValue = 30,
                MinValue = 0,
                IsReversed = true -- 反过来显示 越小越长
            }, {
                Name = "IGUI_WeaponUI_MaxHitCount",
                Value = OriginItem:getMaxHitCount(),
                MaxValue = 10,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_Sound",
                Value = OriginItem:getSoundRadius(),
                BounsAdd = false,
                BonusType = "SoundModifier",
                MaxValue = 200,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_Weight",
                Value = OriginItem:getWeight(),
                BounsAdd = false,
                BonusType = "WeightModifier",
                MaxValue = 5,
                MinValue = 0
            }, {
                Name = "IGUI_WeaponUI_ClipNow",
                Value = OriginItem:getMaxAmmo(),
                MaxValue = 100,
                MinValue = 0
            }}
            local indeX = 1000
            local indexY = 85
            self:drawText(getText("IGUI_WeaponUI_Data"), indeX + 20, indexY, 1, 1, 1, 1, UIFont.Medium)
            local lineHeight = getTextManager():MeasureStringY(UIFont.Medium, getText('IGUI_RISKY_ATTACHMENTS'))
            self:drawRectStatic(indeX + 5, indexY, 200 + 25, lineHeight * 2, 0.2, 0.8, 0.8, 0.8, 1);
            indexY = indexY + lineHeight
            -- 获得配件加成
            local AttachMentCount = getAttacheMentCount(weapon)

            for k, v in pairs(WeaponDataList) do
                local text = getText(v.Name)

                lineHeight = getTextManager():MeasureStringY(UIFont.Medium, getText('IGUI_RISKY_ATTACHMENTS'))
                if k % 2 == 1 then
                    self:drawRectStatic(indeX + 5, indexY + (k * lineHeight), 200 + 25, lineHeight, 0.2, 1, 1, 1, 1);
                else
                    self:drawRectStatic(indeX + 5, indexY + (k * lineHeight), 200 + 25, lineHeight, 0.2, 0.8, 0.8, 0.8,
                        1);
                end
                self:drawText(text, indeX + 20, indexY + (k * lineHeight), 1, 1, 1, 1, UIFont.Small)

                local value = v.Value
                local maxValue = v.MaxValue
                local minValue = v.MinValue
                local valuePerc = (value - minValue) / (maxValue - minValue)
                if v.IsReversed then
                    valuePerc = 1 - valuePerc
                end
                local LastWidth = getScaledStatWidth(valuePerc)
                self:drawRectStatic(indeX + 20 + 100, indexY + (k * lineHeight) + lineHeight / 2 - 2, LastWidth, 3, 0.5,
                    1, 1, 1, 1);

                if v.BonusType and AttachMentCount[v.BonusType] then
                    local bouns = AttachMentCount[v.BonusType]
                    valuePerc = (bouns - minValue) / (maxValue - minValue)
                    if v.BounsAdd then
                        -- 大于0显示绿色，小于0显示红色
                        if bouns > 0 then

                            self:drawRectStatic(indeX + 20 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 2, getScaledStatWidth(valuePerc), 3, 0.8, 0, 1,
                                0, 1);
                        else
                            self:drawRectStatic(indeX + 20 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 2, getScaledStatWidth(valuePerc), 3, 0.8, 1, 0,
                                0, 1);
                        end
                    else
                        if bouns > 0 then
                            self:drawRectStatic(indeX + 20 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 2, getScaledStatWidth(valuePerc), 3, 0.8, 1, 0,
                                0, 1);
                        else

                            self:drawRectStatic(indeX + 20 + 100 + LastWidth,
                                indexY + (k * lineHeight) + lineHeight / 2 - 2, getScaledStatWidth(valuePerc), 3, 0.8, 0, 1,
                                0, 1);
                        end
                    end
                end
            end
            self:drawText(getText('IGUI_RISKY_ATTACHMENTS'), 20, 100, 1, 1, 1, 1, UIFont.Medium)

            local visibleSlots = nil
            if AttachmentRules then
                visibleSlots = AttachmentRules.getVisibleSlots(weapon)
            end
            local showMagazineText = true
            if AttachmentRules then
                showMagazineText = AttachmentRules.isSlotVisible(weapon, "Clip", visibleSlots)
            end
            if weapon:getMagazineType() ~= nil and showMagazineText then
                local MagazineItem = instanceItem(weapon:getMagazineType());
                if MagazineItem ~= nil then
                    local clip = MagazineItem:getDisplayName()
                    self:drawText(clip, 916, 551, 1, 1, 1, 1, UIFont.Small)
                    self:drawText(getTextSafe('IGUI_CLIP', 'IGUI_Clip'), 916, 571, 1, 1, 1, 1, UIFont.Small)
                end
            end
            if AWCWF_WeaponAttackType[weapon:getType()] then
                local AttackType = getWeaponAttackType(weapon, AWCWF_WeaponAttackType[weapon:getType()])
                local AttackTypeItem = instanceItem(AttackType);
                if AttackTypeItem then
                    AttackType = AttackTypeItem:getDisplayName()
                    self:drawText(AttackType, 608, 100, 1, 1, 1, 1, UIFont.Small)
                    self:drawText(getText('IGUI_WeaponAttackType'), 608, 120, 1, 1, 1, 1, UIFont.Small)
                end
            end
            for _, info in ipairs(attachmentInfo) do
                drawAttachment(self, weapon, info.type, info.x, info.y, visibleSlots);
            end

        end
    else
        self:close()
    end
    if self.scene then
        self.scene:setY(self.height / 12)
        self.scene:setX(0)
        self.scene:setWidth(self.width)
        self.scene:setHeight(self.height * 10 / 12)
        self.settingbutton:setX(64)
        self.settingbutton:setY(self.height * 13 / 16)
        self.settingbutton:setWidth(GUNATTPART_BUTTON_SIZE)
        self.settingbutton:setHeight(GUNATTPART_BUTTON_SIZE)
    end
end
local function getJavaFieldNum(object, fieldName)
    for i = 0, getNumClassFields(object) - 1 do
        local javaField = getClassField(object, i)
        if luautils.stringEnds(tostring(javaField), '.' .. fieldName) then
            return i
        end
    end
end

local ATTACHMENT_MODEL_OVERRIDES = {
    ["x2Scope"] = "Base.x2Scope",
    ["x4Scope"] = "Base.x4Scope",
    ["x8Scope"] = "Base.x8Scope",
    ["Base.x2Scope"] = "Base.x2Scope",
    ["Base.x4Scope"] = "Base.x4Scope",
    ["Base.x8Scope"] = "Base.x8Scope",
}

local function resolvePartScriptItem(part)
    if not part then
        return nil, nil
    end

    local fullType = part.getFullType and tostring(part:getFullType()) or nil
    if not fullType or fullType == "" then
        return nil, nil
    end

    local scriptItem = ScriptManager.instance:getItem(fullType)
    if not scriptItem and not fullType:find("%.") then
        local normalized = "Base." .. fullType
        scriptItem = ScriptManager.instance:getItem(normalized)
        if scriptItem then
            fullType = normalized
        end
    end

    return scriptItem, fullType
end

local function resolveModelName(item, fullTypeOverride)
    if not item then return nil end
    local overrideKey = fullTypeOverride or (item.getFullName and item:getFullName()) or nil
    if overrideKey then
        local overrideModel = ATTACHMENT_MODEL_OVERRIDES[overrideKey]
        if overrideModel and overrideModel ~= "" then
            return overrideModel
        end
    end

    local function readStaticModel(scriptItem)
        local model = (scriptItem.getStaticModel and scriptItem:getStaticModel()) or nil
        if not model then
            local sNum = getJavaFieldNum(scriptItem, "StaticModel")
            if sNum then
                model = getClassFieldVal(scriptItem, getClassField(scriptItem, sNum))
            end
        end
        return model
    end

    local function readWorldModel(scriptItem)
        local model = (scriptItem.getWorldStaticModel and scriptItem:getWorldStaticModel()) or nil
        if not model then
            local wNum = getJavaFieldNum(scriptItem, "WorldStaticModel")
            if wNum then
                model = getClassFieldVal(scriptItem, getClassField(scriptItem, wNum))
            end
        end
        return model
    end

    local isWeaponPart = item.getType and tostring(item:getType()) == "WeaponPart"
    local model = nil

    if isWeaponPart then
        -- 3DUI: para accesorios priorizamos el mesh world para que coincida con el render en arma.
        model = readWorldModel(item) or readStaticModel(item)
    else
        model = readStaticModel(item) or readWorldModel(item)
    end

    if not model then return nil end
    local sm = tostring(model)
    -- skip bogus placeholders that would create a Base.null scene object
    if sm == "" or sm == "null" or sm:find("nil") then return nil end
    if not sm:find("%.") then
        local mod = item.getModuleName and item:getModuleName() or "Base"
        sm = mod .. "." .. sm
    end
    return sm
end

local function getpartmodel(weapon, scene)
    for i, v in pairs(partlist) do
        if weapon:getWeaponPart(v) then
            local part = weapon:getWeaponPart(v)
            local item, partFullType = resolvePartScriptItem(part)
            if item then
                local modelName = resolveModelName(item, partFullType)
                if modelName and not string.find(modelName, "nil") and not string.find(modelName, "null") then
                    scene.javaObject:fromLua2("createModel", modelName, modelName)
                    scene.partlist = scene.partlist or {}
                    scene.partlist[modelName] = true
                end
            end
        end
    end
end
local function getpartmodeldel(weapon, scene)
    local partlistnow = {}
    for i, v in pairs(partlist) do
        if weapon:getWeaponPart(v) then
            local part = weapon:getWeaponPart(v)
            local item, partFullType = resolvePartScriptItem(part)
            if item then
                local modelName = resolveModelName(item, partFullType)
                if modelName and (not string.find(modelName, "nil") and not string.find(modelName, "null")) and
                    modelName ~= "Base.Gun_Magazine_Ground" then
                    if not scene.partlist[modelName] then
                        scene.javaObject:fromLua2("createModel", modelName, modelName)
                        scene.partlist[modelName] = true
                    end
                    partlistnow[modelName] = true
                end
            end
        end
    end
    scene.partlist = scene.partlist or {}
    for i, v in pairs(scene.partlist) do
        if not partlistnow[i] then
            scene.partlist[i] = nil
            scene.javaObject:fromLua1("removeModel", i)
        end
    end
end
function riskyUI:settingbutton()
    if riskyUI_slider and riskyUI_slider.instance then
        riskyUI_slider.instance:close()
        riskyUI_slider.instance = nil
    end
    local width = self.width / 3
    self.settingpanel = riskyUI_slider:new(self.x - width, self.y, width, self.height, self)
    self.settingpanel:initialise()
    self.settingpanel:addToUIManager()
end
function riskyUI:settingbuttona()
    if riskyUI_slider and riskyUI_slider.instance then
        riskyUI_slider.instance:close()
        riskyUI_slider.instance = nil
    end
    local width = self.width / 3
    self.settingpanel = riskyUI_slider:new(self.x - width, self.y, width, self.height, self)
    self.settingpanel:initialise()
    self.settingpanel:addToUIManager()
end
function riskyUI:createChildren()
    ISPanel.createChildren(self)
    self.scene = Carshopscenetk:new(self.width / 10, self.height / 8, self.width * 8 / 10, self.height * 6 / 8)
    self.scene:initialise()
    self.scene:instantiate()
    self.scene:setAnchorRight(true)
    self.scene:setAnchorBottom(true)
    self:addChild(self.scene)

    self.scene.javaObject:fromLua1("setDrawGrid", false)
    self.scene.javaObject:fromLua1("setDrawGridAxes", false)

    self.scene.javaObject:fromLua1("setMaxZoom", 100)
    self.scene.javaObject:fromLua1("setZoom", 15)
    self.scene.javaObject:fromLua2("dragView", -30, 30)
    -- self.scene:java7("createDepthTexture", "depthTexture", getTexture("media/white.png"), 0, 0, 64, 128, 0.0)
    -- self.scene:java2("setObjectVisible", "depthTexture", false)
    self.scene:setView("UserDefined")
    local weapon = getPlayer():getPrimaryHandItem()
    local sprite = weapon:getWeaponSprite()
    if sprite and sprite ~= "nil" and not string.find(sprite, "_0") then
        local model = ScriptManager.instance:getItem(weapon:getFullType()):getModuleName() .. "." .. sprite
        self.scene.javaObject:fromLua2("createModel", "Gunmodel", model)
    end
    getpartmodel(weapon, self.scene)
    local gunAttPartsItem = instanceItem("Base.GunAttParts")
    local gunAttPartsCount = countGunAttParts(getPlayer():getInventory())
    self.settingbutton =
        ammoButton:new(64, self.height * 15 / 16, GUNATTPART_BUTTON_SIZE, GUNATTPART_BUTTON_SIZE, gunAttPartsItem,
            gunAttPartsCount);
    self.settingbutton.target = nil
    self.settingbutton.onclick = function()
    end
    self.settingbutton.anchorTop = false
    self.settingbutton.anchorBottom = false
    self.settingbutton:initialise();
    self.settingbutton:instantiate();
    self.settingbutton.borderColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 0
    };
    self:addChild(self.settingbutton);
    if gunAttPartsItem then
        local icon = gunAttPartsItem:getIcon()
        if icon then
            local texture = icon
            if type(icon) == "string" then
                texture = getTexture("media/textures/Item_" .. icon .. ".png") or getTexture(icon)
            elseif icon.getName then
                texture = icon
            end
            if texture then
                self.settingbutton:setImage(texture)
            end
        end
    end
    local image = getTexture("media/textures/UI/AWCWF_Close.png")
    if image then
        self.closeButton = ISButton:new(698 + 300 + 300 - 60 - image:getWidth(), 10 + image:getHeight(),
            image:getWidth(), image:getHeight(), "", self, self.onOptionMouseDown);
        self.closeButton.internal = "close";
        self.closeButton:initialise();
        self.closeButton:instantiate();
        self.closeButton.borderColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 0
        }
        self:addChild(self.closeButton);
        self.closeButton:setImage(getTexture("media/textures/UI/AWCWF_Close.png"))

        self.rotateButton = ISButton:new(698 + 300 + 300 - 60 - image:getWidth() - 10 - image:getWidth(),
            10 + image:getHeight(), image:getWidth(), image:getHeight(), "", self, self.onOptionMouseDown);
        self.rotateButton.internal = "Rotate";
        self.rotateButton:initialise();
        self.rotateButton:instantiate();
        self.rotateButton.borderColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 0
        }
        self:addChild(self.rotateButton);
        self.rotateButton:setImage(getTexture("media/textures/UI/AWCWF_Rotate.png"))

        self.infoButton = ISButton:new(698 + 300 + 300 - 60 - image:getWidth() - 10 - image:getWidth() - 10 -
            image:getWidth(), 10 + image:getHeight(), image:getWidth(), image:getHeight(), "", self,
            self.onOptionMouseDown);
        self.infoButton.internal = "Info";
        self.infoButton:initialise();
        self.infoButton:instantiate();
        self.infoButton.borderColor = {
            r = 1,
            g = 1,
            b = 1,
            a = 0
        }
        self:addChild(self.infoButton);
        self.infoButton:setImage(getTexture("media/textures/UI/GGS_Info.png"))

    end
end

function riskyUI:renderInventory()

    self:clearChildren()
    if self.settingpanel then
        self.settingpanel:close()
        self.settingpanel = nil
        self:settingbuttona()
    end
    -----------------------------------------------------------
    -- self.scene = nil
    local weapon = getPlayer():getPrimaryHandItem()
    if not self.scene then
        self:createChildren()
    else
        self:addChild(self.scene)
        getpartmodeldel(weapon, self.scene)
        self:addChild(self.settingbutton)
        self:addChild(self.closeButton)
        self:addChild(self.rotateButton)
        if self.infoButton then
            self:addChild(self.infoButton)
        end
    end
    if self.settingbutton then
        self.settingbutton.stackAmount = countGunAttParts(getPlayer():getInventory())
    end
    local function rotateGunModelIfNeeded()
        if not self.scene or not weapon or weapon:getSwingAnim() ~= "Handgun" then
            return
        end
        local rotation = self.scene.javaObject:fromLua1("getObjectRotation", "Gunmodel")
        if rotation then
            rotation:set(rotation:x(), 180, rotation:z())
        end
    end
    self.scene.baseRotations = self.scene.baseRotations or {}
    -- (3DUI). Format 1 1: {x, y, z}
    local PART_ROTATION = {
        ["Base.A2000"] = {
            Clip = {27.9358, 0.0, 0.0},
        },
        ["Base.APC9K"] = {
            Clip = {18.2440, 0.0, 0.0},
        },
        ["Base.AR6951"] = {
            Clip = {16.6546, 0.0, 0.0},
        },
        ["Base.AUG_9mm"] = {
            Clip = {20.9014, 0.0, 0.0},
        },
        ["Base.Colt9mm"] = {
            Clip = {18.5497, 0.0, 0.0},
        },
        ["Base.CZScorpion"] = {
            Clip = {20.9969, 0.0, 0.0},
        },
        ["Base.K7"] = {
            Clip = {20.6172, 0.0, 0.0},
        },
        ["Base.LanchesterMK1"] = {
            Clip = {0.0, 0.0, 25.8261},
        },
        ["Base.MAB38A"] = {
            Clip = {24.3610, 90.0, -0.0013},
        },
        ["Base.MAT49"] = {
            Clip = {-155.8267, 90.0, 0.0},
        },
        ["Base.MP5"] = {
            Clip = {32.5464, 0.0, 0.0},
        },
        ["Base.MP5SD"] = {
            Clip = {32.7717, 0.0, 0.0},
        },
        ["Base.MP5K"] = {
            Clip = {32.5464, 0.0, 0.0},
        },
        ["Base.MP40"] = {
            Clip = {-155.6669, 89.1853, 179.9996},
        },
        ["Base.MPX"] = {
            Clip = {27.4584, 0.0, 0.0},
        },
        ["Base.MX4"] = {
            Clip = {7.5560, 0.0, 0.0},
        },
        ["Base.PPSH41"] = {
            Clip = {-6.1744, 0.0, 0.0},
        },
        ["Base.Saiga9mm"] = {
            Clip = {18.6580, 0.0, 0.0},
        },
        ["Base.Silenced_Sten"] = {
            Clip = {0.0000, 0.0000, 24.0833},
        },
        ["Base.Sten_MK5"] = {
            Clip = {0.0, 0.0, 24.2347},
        },
        ["Base.UMP45"] = {
            Clip = {33.1296, 0.0, 0.0},
        },
        ["Base.UMP45_long"] = {
            Clip = {33.1296, 0.0, 0.0},
        },
        ["Base.X86"] = {
            Clip = {29.2659, 0.0, 0.0},
        },
        ["Base.AEK919"] = {
            Clip = {5.8713, 0.0, 0.0},
        },
        ["Base.CBJ"] = {
            Clip = {17.5545, 0.0, 0.0},
        },
        ["Base.MAC10"] = {
            Clip = {16.7226, 0.0, 0.0},
        },
        ["Base.Micro_UZI"] = {
            Clip = {16.7226, 0.0, 0.0},
        },
        ["Base.MP7"] = {
            Clip = {16.7226, 0.0, 0.0},
        },
        ["Base.MP9"] = {
            Clip = {11.9668, 0.0, 0.0},
        },
        ["Base.MSST"] = {
            Clip = {30.0000, 0.0, 0.0},
        },
        ["Base.P99_Kilin"] = {
            Clip = {16.1000, 0.0, 0.0},
        },
        ["Base.PP2000"] = {
            Clip = {14.3500, 0.0, 0.0},
        },
        ["Base.PP93"] = {
            Clip = {8.0022, 0.0, -0.0},
        },
        ["Base.TEC9"] = {
            Clip = {15.5000, 0.0, 0.0},
        },
        ["Base.TMP"] = {
            Clip = {13.0, 0.0, 0.0},
        },
        ["Base.UZI"] = {
            Clip = {17.0000, 0.0, 0.0},
        },
        ["Base.Veresk"] = {
            Clip = {15.2935, 0.0, 0.0},
        },
        ["Base.VZ61"] = {
            Clip = {38.0298, 0.0, 0.0},
        },
    }
    for uy, ur in pairs(partlist) do
        if weapon:getWeaponPart(ur) then
            local item = ScriptManager.instance:getItem(weapon:getWeaponPart(ur):getFullType())
            if item then
                local worldmodel = resolveModelName(item)
                local modelscript = "Base." .. weapon:getWeaponSprite()
                local model = ScriptManager.instance:getModelScript(modelscript)
                if model and worldmodel then
                    local attachment0 = model:getAttachmentById(ur)
                    if attachment0 and not string.find(worldmodel, "nil") and not string.find(worldmodel, "null") and
                        worldmodel ~= "Base.Gun_Magazine_Ground" then
                        local offset = attachment0:getOffset()
                        local list = {offset:x(), offset:y(), offset:z()}
                        if weapon:getSwingAnim() == "Handgun" then
                            list[1] = -list[1]
                            list[3] = -list[3]
                        end
                        self.scene.javaObject:fromLua4("setObjectPosition", worldmodel, list[1], list[2], list[3])
                        if weapon:getSwingAnim() == "Handgun" then
                            local rotation = self.scene.javaObject:fromLua1("getObjectRotation", worldmodel)
                            if rotation then
                                local base = self.scene.baseRotations[worldmodel]
                                if not base then
                                    base = {
                                        x = rotation:x() or 0,
                                        y = rotation:y() or 0,
                                        z = rotation:z() or 0
                                    }
                                    self.scene.baseRotations[worldmodel] = base
                                end
                                rotation:set(base.x, base.y, base.z )
                            end
                        end
                        -- Aplicar rotación específica si existe para arma+parte.
                        local overWpn = PART_ROTATION[weapon:getFullType()]
                        local overRot = overWpn and overWpn[ur] or nil
                        if overRot then
                            local rotObj = self.scene.javaObject:fromLua1("getObjectRotation", worldmodel)
                            if rotObj then
                                rotObj:set(overRot[1] or 0, overRot[2] or 0, overRot[3] or 0)
                            end
                        end
                    end
                end
            end
        end
    end
    rotateGunModelIfNeeded()
    -- Close button
    local closeButton = ISButton:new(3, 0, 15, 15, "", self, self.onOptionMouseDown)
    closeButton.internal = "close";
    closeButton:initialise();
    closeButton.borderColor.a = 0.0;
    closeButton.backgroundColor.a = 0;
    closeButton.backgroundColorMouseOver.a = 0;
    closeButton:setImage(getTexture("media/ui/Dialog_Titlebar_CloseIcon.png"));
    self:addChild(closeButton);
    if getPlayer():getPrimaryHandItem() ~= nil and getPlayer():getPrimaryHandItem():IsWeapon() then

        if (weapon:isRanged()) then
            -- Width/Height
            self.panelHeight = 110
            self:setHeight(self.panelHeight)
            local itemList = getPlayer():getInventory():getItems()
            local containerCount = 1
            local allContainers = {}
            local visibleSlots = nil
            if AttachmentRules then
                visibleSlots = AttachmentRules.getVisibleSlots(weapon)
            end
            -- Probe containers
            for i = 0, itemList:size() - 1, 1 do
                if instanceof(itemList:get(i), 'InventoryContainer') and (itemList:get(i):isEquipped()) then
                    table.insert(allContainers, itemList:get(i))
                    containerCount = containerCount + 1
                end
            end
            -- Not an ideal way to get the object loose ammo and box ammo object, but for the time being...
            local ammoItemKey = getAmmoItemKey(weapon:getAmmoType())
            local rawAmmoBox = weapon.getAmmoBox and weapon:getAmmoBox() or nil
            local ammoBoxKey = getAmmoItemKey(rawAmmoBox)

            local looseAmmo = ammoItemKey and instanceItem(ammoItemKey) or nil
            local boxAmmo = ammoBoxKey and instanceItem(ammoBoxKey) or nil

            local looseAmmoCount = ammoItemKey and getPlayer():getInventory():getItemCount(ammoItemKey) or 0
            local boxAmmoCount = ammoBoxKey and getPlayer():getInventory():getItemCount(ammoBoxKey) or 0
            if (containerCount > 1) then
                for i = 1, containerCount - 1 do
                    if ammoItemKey then
                        looseAmmoCount = looseAmmoCount + allContainers[i]:getInventory():getItemCount(ammoItemKey)
                    end
                    if ammoBoxKey then
                        boxAmmoCount = boxAmmoCount + allContainers[i]:getInventory():getItemCount(ammoBoxKey)
                    end
                end
            end
            if looseAmmo then
                local item = ammoButton:new(200 + 10, 40, 50, 50, looseAmmo, looseAmmoCount)
                item:bringToTop()
                self:addChild(item)
            end
            if boxAmmo then
                local item = ammoButton:new(200 + 65, 40, 50, 50, boxAmmo, boxAmmoCount)
                item:bringToTop()
                self:addChild(item)
            end
            self.panelWidth = self.panelWidth + 130
            self.panelHeight = self.panelHeight + 180

            local showMagazineSlot = true
            if AttachmentRules then
                showMagazineSlot = AttachmentRules.isSlotVisible(weapon, "Clip", visibleSlots)
            end
            if weapon:getMagazineType() ~= nil and showMagazineSlot then
                local MagazineItem = instanceItem(weapon:getMagazineType());
                if MagazineItem then
                    item = createAttachmentSlot(858, 542, MagazineItem, weapon, "ClipType", {
                        removalBlocked = false
                    })
                    item:bringToTop()
                    self:addChild(item)
                end
            end
            if AWCWF_WeaponAttackType[weapon:getType()] then
                local AttackType = getWeaponAttackType(weapon, AWCWF_WeaponAttackType[weapon:getType()])
                local AttackTypeItem = instanceItem(AttackType);
                if AttackTypeItem then
                    item = createAttachmentSlot(558, 100, AttackTypeItem, weapon, "WeaponAttackType", {
                        removalBlocked = false
                    })
                    item:bringToTop()
                    self:addChild(item)
                end
            end

            for _, info in ipairs(attachmentButtonsInfo) do
                local slotVisible = true
                if AttachmentRules then
                    slotVisible = AttachmentRules.isSlotVisible(weapon, info.type, visibleSlots)
                end
                if slotVisible then
                    local attachmentItem = weapon:getWeaponPart(info.type)
                    if AttachmentRules and AttachmentRules.getAttachment then
                        local resolved = AttachmentRules.getAttachment(weapon, info.type)
                        if resolved then
                            attachmentItem = resolved
                        end
                    end
                    local removalBlocked = false
                    local blockingParts = nil
                    if attachmentItem and AttachmentRules then
                        local canRemove, blocking = AttachmentRules.canRemovePart(weapon, attachmentItem)
                        removalBlocked = not canRemove
                        blockingParts = blocking
                    end
                    local item = createAttachmentSlot(info.x, info.y, attachmentItem, weapon, info.type, {
                        removalBlocked = removalBlocked,
                        blockingParts = blockingParts
                    });
                    item:bringToTop();
                    self:addChild(item);
                end
            end
        end
    end
    self:setWidth(698 + 300 + 300)
    self:setHeight(516 + 200)
end
