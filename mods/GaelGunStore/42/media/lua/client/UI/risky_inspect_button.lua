-- @author Risky
-- Custom buttons for UI on windows/panels
require "ISUI/ISButton"
require "ISUI/ISPanel"
require "TimedActions/ISInventoryTransferAction"
pcall(require, "TimedActions/ISUpgradeWeapon")
pcall(require, "TimedActions/ISRemoveWeaponUpgrade")
require "AWCWF_AttachmentRules"
pcall(require, "WeaponAbility/ChangeMagazineType")
local SelectAttachmentPane = require("UI/risky_inspect_selectAttachmentPane")
if SelectAttachmentPane == true then
    SelectAttachmentPane = _G.selectAttachmentPane
end

if not SelectAttachmentPane and _G.selectAttachmentPane then
    SelectAttachmentPane = _G.selectAttachmentPane
end

local function resolveSelectAttachmentPane()
    if SelectAttachmentPane and SelectAttachmentPane.new then
        return SelectAttachmentPane
    end

    if _G.selectAttachmentPane and _G.selectAttachmentPane.new then
        SelectAttachmentPane = _G.selectAttachmentPane
        return SelectAttachmentPane
    end

    local ok, module = pcall(require, "UI/risky_inspect_selectAttachmentPane")
    if ok then
        if module ~= true and module and module.new then
            SelectAttachmentPane = module
            return SelectAttachmentPane
        end

        if _G.selectAttachmentPane and _G.selectAttachmentPane.new then
            SelectAttachmentPane = _G.selectAttachmentPane
            return SelectAttachmentPane
        end
    end

    return nil
end

local ATTACHMENT_SLOT_SIZE = rawget(_G, "AWCWF_ATTACHMENT_SLOT_SIZE") or 60
local ATTACHMENT_PANE_OFFSET_X = ATTACHMENT_SLOT_SIZE + 3

local AttachmentRules = AWCWF_AttachmentRules
local removalLockedTexture = getTexture("media/ui/Dialog_Titlebar_CloseIcon.png")
local READ_ONLY_UI = false
local READ_ONLY_MSG_KEY = "IGUI_GGS_UIReadOnlyMode"
local LIMITED_ACTION_MSG_KEY = "IGUI_GGS_AttachmentChangesOnly"

local function ggsText(key)
    local text = getText(key)
    if text and text ~= key then
        return text
    end
    return key
end

local function sayReadOnly(customKey)
    local player = getPlayer()
    if not player then
        return
    end
    local text = ggsText(customKey or READ_ONLY_MSG_KEY)
    if not text or text == "" then
        return
    end
    player:Say(text)
end

local function refreshHandsModel(character)
    if not character then
        return
    end
    if character.resetEquippedHandsModels then
        character:resetEquippedHandsModels()
    end
    if character.resetModelNextFrame then
        character:resetModelNextFrame()
    end
end

local function safeSetSecondaryHandItem(character, item)
    if not (character and character.setSecondaryHandItem) then
        return false
    end

    local ok, err = pcall(character.setSecondaryHandItem, character, item)
    if not ok then
        print("[GGS VisualSync] setSecondaryHandItem failed: " .. tostring(err))
        return false
    end
    return true
end

local function hasActiveTimedAction(character)
    if not (character and character.getCharacterActions) then
        return false
    end

    local actions = character:getCharacterActions()
    if not actions then
        return false
    end
    if actions.isEmpty then
        return not actions:isEmpty()
    end
    if actions.size then
        return actions:size() > 0
    end
    return false
end

local function syncWeaponHandsAndModel(character, weapon)
    if not character or not weapon then
        return
    end

    if syncHandWeaponFields then
        syncHandWeaponFields(character, weapon)
    end

    local primary = character.getPrimaryHandItem and character:getPrimaryHandItem() or nil
    if primary == weapon then
        local isTwoHand = weapon.isTwoHandWeapon and weapon:isTwoHandWeapon() or false
        local secondary = character.getSecondaryHandItem and character:getSecondaryHandItem() or nil
        if isTwoHand and secondary ~= weapon then
            safeSetSecondaryHandItem(character, weapon)
        elseif (not isTwoHand) and secondary == weapon then
            safeSetSecondaryHandItem(character, nil)
        end
    end

    refreshHandsModel(character)
end

local function installWeaponUpgradeVisualPatches()
    if ISUpgradeWeapon and not ISUpgradeWeapon.__ggsVisualPatch then
        local vanillaComplete = ISUpgradeWeapon.complete
        if vanillaComplete then
            function ISUpgradeWeapon:complete(...)
                local result = vanillaComplete(self, ...)
                syncWeaponHandsAndModel(self.character, self.weapon)
                return result
            end
            ISUpgradeWeapon.__ggsVisualPatch = true
        end
    end

    if ISRemoveWeaponUpgrade and not ISRemoveWeaponUpgrade.__ggsVisualPatch then
        local vanillaComplete = ISRemoveWeaponUpgrade.complete
        if vanillaComplete then
            function ISRemoveWeaponUpgrade:complete(...)
                local result = vanillaComplete(self, ...)
                syncWeaponHandsAndModel(self.character, self.weapon)
                return result
            end
            ISRemoveWeaponUpgrade.__ggsVisualPatch = true
        end
    end
end

installWeaponUpgradeVisualPatches()
if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(installWeaponUpgradeVisualPatches)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(installWeaponUpgradeVisualPatches)
end

local function keepTwoHandPrimarySynced(playerObj)
    if not playerObj then
        return
    end
    if getPlayer and playerObj ~= getPlayer() then
        return
    end
    local weapon = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if not (weapon and weapon.IsWeapon and weapon:IsWeapon()) then
        return
    end
    if not (weapon.isTwoHandWeapon and weapon:isTwoHandWeapon()) then
        return
    end
    if hasActiveTimedAction(playerObj) then
        return
    end
    local secondary = playerObj.getSecondaryHandItem and playerObj:getSecondaryHandItem() or nil
    if secondary ~= weapon and playerObj.setSecondaryHandItem then
        if safeSetSecondaryHandItem(playerObj, weapon) then
            refreshHandsModel(playerObj)
        end
    end
end

-- Do not run this every frame: changing hands during hotbar equip/unequip can
-- trip B42 Java-side null errors. Upgrade completion calls sync explicitly.

local function findItemAndContainerByIdRecursive(container, itemId)
    if not container or not itemId then
        return nil, nil
    end
    local items = container:getItems()
    if not items then
        return nil, nil
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local id = item.getID and item:getID() or nil
            if id == itemId then
                return item, container
            end
            if instanceof(item, "InventoryContainer") then
                local foundItem, foundContainer = findItemAndContainerByIdRecursive(item:getInventory(), itemId)
                if foundItem and foundContainer then
                    return foundItem, foundContainer
                end
            end
        end
    end
    return nil, nil
end

local function stageItemToRootInventory(playerObj, item)
    if not playerObj or not item then
        return item, nil
    end
    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        return item, nil
    end

    local source = item.getContainer and item:getContainer() or nil
    if source then
        return item, source
    end

    local itemId = item.getID and item:getID() or nil
    if itemId then
        local foundItem, foundContainer = findItemAndContainerByIdRecursive(inventory, itemId)
        if foundItem then
            return foundItem, foundContainer
        end
    end
    return item, source
end

local function isDevAttachmentSpawnerEnabled()
    if type(GGS_isDevAttachmentSpawnerEnabled) == "function" then
        local ok, enabled = pcall(GGS_isDevAttachmentSpawnerEnabled)
        if ok and enabled == true then
            return true
        end
    end
    if SandboxVars and SandboxVars.GGSGS and SandboxVars.GGSGS.DevAttachmentSpawner == true then
        return true
    end
    return false
end

local function spawnDevAttachmentIntoInventory(playerObj, fullType)
    if not (playerObj and fullType and fullType ~= "") then
        return nil
    end
    local inventory = playerObj.getInventory and playerObj:getInventory() or nil
    if not inventory then
        return nil
    end

    local ok, item = pcall(inventory.AddItem, inventory, fullType)
    if ok and item and instanceof(item, "WeaponPart") then
        print(string.format("[GGS DevAttach] spawned %s into player inventory", tostring(fullType)))
        return item
    end

    local temp = nil
    if type(instanceItem) == "function" then
        local instanceOk, created = pcall(instanceItem, fullType)
        if instanceOk and created and instanceof(created, "WeaponPart") then
            temp = created
        end
    end

    if temp then
        local addOk, added = pcall(inventory.AddItem, inventory, temp)
        if addOk and added and instanceof(added, "WeaponPart") then
            print(string.format("[GGS DevAttach] spawned %s into player inventory", tostring(fullType)))
            return added
        end
    end

    print(string.format("[GGS DevAttach] failed to spawn %s", tostring(fullType)))
    return nil
end

function predicateNotBroken(item)
    return not item:isBroken()
end

ammoButton = ISButton:derive("ammoButton")

function ammoButton:new(x, y, w, h, slotItem, stackAmount)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.stackAmount = stackAmount

    o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)

    o.borderColor.r = 1
    o.borderColor.g = 1
    o.borderColor.b = 0.0
    o.borderColor.a = 0.5

    o.backgroundColor.r = 0
    o.backgroundColor.g = 0
    o.backgroundColor.b = 0
    o.backgroundColor.a = 0.9

    o.backgroundColorMouseOver.r = 0
    o.backgroundColorMouseOver.g = 0
    o.backgroundColorMouseOver.b = 0
    o.backgroundColorMouseOver.a = 0.3

    if slotItem then
        o.backgroundColorMouseOver.a = 0.8
        o.toolTip = ISToolTipInv:new(slotItem)
        o.toolTip:setOwner(o)
        o.toolTip:setVisible(false)
        o.toolTip:addToUIManager()

        -- Texture related
        o:setImage(slotItem:getTexture())

        local visual = slotItem:getVisual()
        o.tint = nil
        if visual then
            o.tint = visual:getTint(slotItem:getClothingItem())
            o.currentTint = visual:getTint(slotItem:getClothingItem())
        end

        if o.tint ~= nil then
            o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 1.0)
        end

        o.slotItem = slotItem
    end

    o:bringToTop();

    return o
end

function ammoButton:render()
    ISButton.render(self)

    if self.slotItem then
        self:drawText(tostring(self.stackAmount), 4, 0, 1.0, 1.0, 1.0, 1.0)

        -- Texture related
        self:setImage(self.slotItem:getTexture())

        if self.currentTint ~= nil then
            self:setTextureRGBA(self.currentTint:getRedFloat(), self.currentTint:getGreenFloat(),
                self.currentTint:getBlueFloat(), self.currentTint:getAlphaFloat())
        end

        if self.removalBlocked then
            local tex = removalLockedTexture
            if tex then
                local size = math.min(self.width, self.height) * 0.6
                self:drawTextureScaled(tex, (self.width - size) / 2, (self.height - size) / 2, size, size, 0.8, 1, 0,
                    0)
            else
                self:drawTextCentre("X", self.width / 2, self.height / 2 - 8, 1, 0, 0, 0.8, UIFont.Small)
            end
        end

        -- if self:isMouseOver() then
        --     self.toolTip:setVisible(true)
        --     self.toolTip:bringToTop()
        -- else
        --     self.toolTip:setVisible(false)
        -- end
    end
end

function ammoButton:close()
    ISButton.close(self)
    -- self.toolTip:setVisible(false)
    -- self.toolTip:removeFromUIManager()
end

-- Attachment Button

attachmentButton = ISButton:derive("attachmentButton")

function attachmentButton:new(x, y, w, h, slotItem, attachingTo, attachmentType, options)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)

    o.borderColor.r = 0.0
    o.borderColor.g = 1
    o.borderColor.b = 0.0
    o.borderColor.a = 0.5

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.9

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5
    o.backgroundColorMouseOver.a = 0.9

    o.attachingTo = attachingTo
    o.attachmentType = attachmentType
    if attachmentType == "ClipType" then
        o.ClipType = "ClipType"
    elseif attachmentType == "WeaponAttackType" then
        o.AttackModeType = "WeaponAttackType"
    elseif attachmentType == "Skin" then
        o.SkinType = "Skin"
    else
        o.attachmentType = attachmentType
    end

    if slotItem then
        -- o.toolTip = ISToolTip:new();
        -- o.toolTip.description = getText("Tooltip_DoubleClickToRemove")
        -- o.toolTip:setVisible(false)
        -- o.toolTip:addToUIManager()

        -- Texture related
        o:setImage(slotItem:getTexture())

        local visual = slotItem:getVisual()
        o.tint = nil
        if visual then
            o.tint = visual:getTint(slotItem:getClothingItem())
            o.currentTint = visual:getTint(slotItem:getClothingItem())
        end

        if o.tint ~= nil then
            o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 1.0)
        end

        o.slotItem = slotItem
    end

    if options then
        o.removalBlocked = options.removalBlocked or false
        o.blockingParts = options.blockingParts
    else
        o.removalBlocked = false
        o.blockingParts = nil
    end

    o:bringToTop();

    return o
end

function attachmentButton:render()
    -- Fondo negro 90% tanto vacío como con accesorio.
    self.backgroundColor.r = 0.5
    self.backgroundColor.g = 0.5
    self.backgroundColor.b = 0.5
    self.backgroundColor.a = 0.9

    self.backgroundColorMouseOver.r = 0.5
    self.backgroundColorMouseOver.g = 0.5
    self.backgroundColorMouseOver.b = 0.5
    self.backgroundColorMouseOver.a = 0.9

    ISButton.render(self)

    if self.slotItem then
        -- Texture related
        self:setImage(self.slotItem:getTexture())

        if self.currentTint ~= nil then
            self:setTextureRGBA(self.currentTint:getRedFloat(), self.currentTint:getGreenFloat(),
                self.currentTint:getBlueFloat(), self.currentTint:getAlphaFloat())
        end

        -- if self:isMouseOver() then
        --     self.toolTip:setVisible(true)
        --     self.toolTip:bringToTop()
        -- else
        --     self.toolTip:setVisible(false)
        -- end
        self.borderColor.r = 0
        self.borderColor.g = 0.8
        self.borderColor.b = 0
        self.borderColor.a = 0.5
    else
        self.borderColor.r = 0.8
        self.borderColor.g = 0
        self.borderColor.b = 0
        self.borderColor.a = 0.5
    end
end

function attachmentButton:onMouseDoubleClick()
    if READ_ONLY_UI then
        sayReadOnly()
        return
    end
    if self.slotItem and self.ClipType ~= "ClipType" and self.AttackModeType ~= "WeaponAttackType" and self.SkinType ~=
        "Skin" then
        local player = getPlayer()
        if AttachmentRules then
            local canRemove, blocking = AttachmentRules.canRemovePart(self.attachingTo, self.slotItem)
            if not canRemove then
                self.removalBlocked = true
                self.blockingParts = blocking
                local message = nil
                if blocking and #blocking > 0 then
                    local childName = blocking[1].part:getDisplayName()
                    local parentName = self.slotItem:getDisplayName()
                    message = getText("IGUI_AWCWF_RemoveBlocked", childName, parentName)
                else
                    message = getText("IGUI_AWCWF_AttachmentLocked")
                end
                if player and message and message ~= "" then
                    player:Say(message)
                end
                return
            end
        end
        self.removalBlocked = false
        self.blockingParts = nil
        ISTimedActionQueue.add(ISRemoveWeaponUpgrade:new(player, self.attachingTo, self.slotItem:getPartType(), 1))
        if player then
            getSoundManager():PlayWorldSound("WeaponPartInsertSound", player:getSquare(), 0, 0, 0, false);
        end
    end

end

function attachmentButton:onMouseUp()
    if self.slotItem ~= nil and self.ClipType ~= "ClipType" and self.AttackModeType ~= "WeaponAttackType" and
        self.SkinType ~= "Skin" then
        return
    end

    if not riskyInspectWindow then
        return
    end

    local paneClass = resolveSelectAttachmentPane()
    if not paneClass then
        print("AWCWF: selectAttachmentPane class unavailable")
        return
    end

    local pane = paneClass:new(riskyInspectWindow:getX() + self:getX() + ATTACHMENT_PANE_OFFSET_X,
        riskyInspectWindow:getY() + self:getY() - 3, self.attachmentType, self.ClipType, self.AttackModeType,
        self.SkinType)

    if pane then
        pane:addToUIManager()
        pane:bringToTop()
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
function attachmentButton:onMouseDown(x, y)
    ISButton.onMouseDown(self, x, y)

    -- print(self.slotItem:getFullType())

    local extrapanel = self.parent.settingpanel
    if extrapanel and self.slotItem then

        local item = ScriptManager.instance:getItem(self.slotItem:getFullType())
        if item then
            local wTransformFieldNum = getJavaFieldNum(item, "worldStaticModel")
            local worldmodel = getClassFieldVal(item, getClassField(item, wTransformFieldNum))

            local modelscript = "Base." .. getPlayer():getPrimaryHandItem():getWeaponSprite()
            local model = ScriptManager.instance:getModelScript(modelscript)

            -- print(self.slotItem:getPartType())
            -- print(model)
            if model and worldmodel and instanceof(self.slotItem, "WeaponPart") then
                local attachment0 = model:getAttachmentById(self.slotItem:getPartType())

                if not attachment0 then
                    attachment0 = ModelAttachment.new(self.slotItem:getPartType())
                    model:addAttachment(attachment0)
                end

                if attachment0 then
                    local offset = attachment0:getOffset()

                    extrapanel.itempart = self.slotItem:getFullType()

                    -- print(extrapanel.itempart)
                    extrapanel.worldmodel = worldmodel
                    -- local list = offset

                    extrapanel.itempartoffset = offset
                    extrapanel.itempartoffsetment = attachment0
                    extrapanel.modelscript = model
                    extrapanel.modelscriptd = getPlayer():getPrimaryHandItem():getWeaponSprite()
                    local Gun = getPlayer():getPrimaryHandItem()
                    local ModData = Gun:getModData().GunPos
                    if not ModData then
                        ModData = {}
                        Gun:getModData().GunPos = ModData
                    end
                    if not ModData[extrapanel.itempart] then
                        ModData[extrapanel.itempart] = {}
                        ModData[extrapanel.itempart].x = 0
                        ModData[extrapanel.itempart].y = 0
                        ModData[extrapanel.itempart].z = 0
                    end
                    extrapanel.slider1.currentValue = (ModData[extrapanel.itempart].x * 100 + 200) / 4
                    extrapanel.slider2.currentValue = (ModData[extrapanel.itempart].y * 100 + 200) / 4
                    extrapanel.slider3.currentValue = (ModData[extrapanel.itempart].z * 100 + 200) / 4
                    attachment0:getOffset():set(ModData[extrapanel.itempart].x, ModData[extrapanel.itempart].y,
                        ModData[extrapanel.itempart].z)
                    -- local vector = self.scene.javaObject:fromLua4("setObjectPosition", worldmodel,list[1],list[2],list[3])

                end
            end
        end

    end

end

function attachmentButton:close()
    if self.toolTip then
        self.toolTip:setVisible(false)
        self.toolTip:removeFromUIManager()
    end
    ISButton.close(self)
end

-- Add Attachment Button

addAttachmentButton = ISButton:derive("addAttachmentButton")

function addAttachmentButton:new(x, y, w, h, slotItem, attachingTo, enabled, type)
    local o = {}
    o = ISButton:new(x, y, w, h)

    setmetatable(o, self)
    self.__index = self

    o.enabled = enabled
    o.type = type
    o.borderColor.r = 0.0
    o.borderColor.g = 0.0
    o.borderColor.b = 0.0
    o.borderColor.a = 0.9

    o.backgroundColor.r = 0.5
    o.backgroundColor.g = 0.5
    o.backgroundColor.b = 0.5
    o.backgroundColor.a = 0.3

    o.backgroundColorMouseOver.r = 0.5
    o.backgroundColorMouseOver.g = 0.5
    o.backgroundColorMouseOver.b = 0.5

    if enabled then
        o.backgroundColorMouseOver.a = 0.9
        o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 1.0)
    else
        o.backgroundColorMouseOver.a = 0.9
        o.currentTint = ImmutableColor.new(1.0, 1.0, 1.0, 0.3)
    end

    o.attachingTo = attachingTo

    if slotItem then
        o.toolTip = ISToolTipInv:new(slotItem)
        o.toolTip:setOwner(o)
        o.toolTip:setVisible(false)
        o.toolTip:addToUIManager()

        -- Texture related
        o:setImage(slotItem:getTexture())

        local visual = slotItem:getVisual()
        o.tint = nil
        if visual then
            o.tint = visual:getTint(slotItem:getClothingItem())
            o.currentTint = visual:getTint(slotItem:getClothingItem())

            if not enabled then
                o.currentTint.a = 0.3
            end
        end

        if o.tint ~= nil then
            if enabled then
                o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 1.0)
            else
                o:setTextureRGBA(o.tint:getRedFloat(), o.tint:getGreenFloat(), o.tint:getBlueFloat(), 0.3)
            end
        end

        o.slotItem = slotItem
    end

    o:bringToTop();

    return o
end

function addAttachmentButton:render()
    ISButton.render(self)

    if self.slotItem then
        -- Texture related
        self:setImage(self.slotItem:getTexture())

        if self.currentTint ~= nil then
            self:setTextureRGBA(self.currentTint:getRedFloat(), self.currentTint:getGreenFloat(),
                self.currentTint:getBlueFloat(), self.currentTint:getAlphaFloat())
        end

        if self:isMouseOver() then
            self.toolTip:setVisible(true)
            self.toolTip:bringToTop()
        else
            self.toolTip:setVisible(false)
        end

        if self.devSpawnMissing then
            self:drawTextCentre("+", self.width - 8, 1, 0.2, 0.85, 1.0, 0.95, UIFont.Small)
        end
    end
end

function addAttachmentButton:onMouseDown()
    if READ_ONLY_UI then
        sayReadOnly()
        return
    end
    if self.slotItem and self.enabled then
        if self.type ~= "WeaponPart" and self.type ~= "ClipType" then
            sayReadOnly(LIMITED_ACTION_MSG_KEY)
            return
        end

        local didAction = false
        if self.type == "WeaponPart" then
            if AttachmentRules and not AttachmentRules.canInstallOnWeapon(self.attachingTo, self.slotItem) then
                local player = getPlayer()
                local message = getText("IGUI_AWCWF_AttachmentLocked")
                if player and message and message ~= "" then
                    player:Say(message)
                end
                return
            end
            local player = getPlayer()
            if not player then
                return
            end
            if self.devSpawnMissing then
                if not isDevAttachmentSpawnerEnabled() then
                    player:Say(ggsText("IGUI_GGS_DevAttachmentSpawnerDisabled"))
                    return
                end
                local fullType = self.devSpawnFullType or (self.slotItem and self.slotItem.getFullType and self.slotItem:getFullType())
                local spawnedPart = spawnDevAttachmentIntoInventory(player, fullType)
                if not spawnedPart then
                    player:Say(ggsText("IGUI_GGS_CouldNotSpawnAttachment"))
                    return
                end
                self.slotItem = spawnedPart
                self.devSpawnMissing = false
            end
            local inventory = player:getInventory()
            local stagedPart, sourceContainer = stageItemToRootInventory(player, self.slotItem)
            if not stagedPart then
                local itemType = self.slotItem and self.slotItem.getFullType and self.slotItem:getFullType() or
                    tostring(self.slotItem)
                print(string.format("[GGS PartTx] stage failed: missing item reference (%s)", tostring(itemType)))
                return
            end

            self.slotItem = stagedPart

            local containerNow = stagedPart.getContainer and stagedPart:getContainer() or sourceContainer
            if containerNow and containerNow ~= inventory then
                ISTimedActionQueue.add(ISInventoryTransferAction:new(player, stagedPart, containerNow, inventory, 1))
                local partType = stagedPart.getFullType and stagedPart:getFullType() or tostring(stagedPart)
                print(string.format("[GGS PartTx] queued transfer %s to root inventory", tostring(partType)))
            end

            ISTimedActionQueue.add(ISUpgradeWeapon:new(player, self.attachingTo, self.slotItem, 1));
            didAction = true
        elseif self.type == "ClipType" then
            local player = getPlayer()
            if not player then
                return
            end

            local magType = nil
            if self.slotItem.getType then
                magType = self.slotItem:getType()
            elseif self.slotItem.getFullType then
                magType = self.slotItem:getFullType()
            end

            if not magType then
                return
            end

            if ChangeMagazine then
                didAction = ChangeMagazine(player, self.attachingTo, magType, "Inspect", true) ~= false
            end

            if didAction and riskyInspectWindow and riskyInspectWindow.renderInventory then
                riskyInspectWindow:renderInventory()
            end
        end

        if didAction then
            getSoundManager():PlayWorldSound("WeaponPartInsertSound", getPlayer():getSquare(), 0, 0, 0, false);
        end
    end
end

function addAttachmentButton:close()
    ISButton.close(self)
    self.toolTip:setVisible(false)
    self.toolTip:removeFromUIManager()
end
