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

-- A LIVE item of the given fullType anywhere in the inventory tree: one that still has a
-- container. Exists because the MP inventory resync kills old item objects (container and
-- ID both die) while the real item lives on as a new object -- matching by fullType is
-- the only handle that survives the swap.
local function ggsFindLiveItemByFullType(container, fullType, depth)
    if not container or not fullType or depth > 6 then
        return nil
    end
    local items = container.getItems and container:getItems()
    if not items then
        return nil
    end
    for i = 0, items:size() - 1 do
        local candidate = items:get(i)
        if candidate then
            if candidate.getFullType and candidate:getFullType() == fullType and
                candidate.getContainer and candidate:getContainer() ~= nil then
                return candidate
            end
            if instanceof(candidate, "InventoryContainer") and candidate.getInventory then
                local found = ggsFindLiveItemByFullType(candidate:getInventory(), fullType, depth + 1)
                if found then
                    return found
                end
            end
        end
    end
    return nil
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
    -- Entry log: tells us the double-click reached the slot at all, and whether it has a
    -- real part (removable through the normal action) or only a mirrored one (needs the
    -- server). Without it a slot that silently refuses looks identical to a missed click.
    print(string.format("[GGS SlotDBG] doubleClick slot=%s slotItem=%s",
        tostring(self.attachmentType),
        tostring(self.slotItem and self.slotItem.getFullType and self.slotItem:getFullType() or self.slotItem)))
    if READ_ONLY_UI then
        sayReadOnly()
        return
    end
    -- A slot can legitimately show a part that this client has no real InventoryItem for:
    -- the server owns the attachment and only its name reaches us, through the
    -- md.weaponpart mirror that GGS_PartSyncClient writes. slotItem comes from
    -- weapon:getWeaponPart(), which is real-parts-only, so those slots looked populated
    -- and refused to do anything on double-click. There is nothing local to hand to
    -- ISRemoveWeaponUpgrade in that case, so ask the server to detach by slot name and
    -- drop the mirror entry here; the part lands in the inventory server-side and the
    -- next sync confirms the slot is empty.
    if not self.slotItem and self.attachingTo and self.attachmentType then
        local md = self.attachingTo.getModData and self.attachingTo:getModData()
        local mirrored = md and md.weaponpart and md.weaponpart[self.attachmentType]
        if mirrored then
            if isClient and isClient() and sendClientCommand then
                local okId, weaponId = pcall(self.attachingTo.getID, self.attachingTo)
                pcall(sendClientCommand, getPlayer(), "GGS", "detachPart", {
                    slot = tostring(self.attachmentType),
                    weaponId = (okId and weaponId or nil),
                })
                md.weaponpart[self.attachmentType] = nil
                if self.attachingTo.transmitModData then
                    pcall(self.attachingTo.transmitModData, self.attachingTo)
                end
                print("[GGS ClickDBG] server-side detach requested for slot " ..
                          tostring(self.attachmentType))
            else
                sayReadOnly()
            end
            return
        end
    end
    if self.slotItem and self.ClipType ~= "ClipType" and self.AttackModeType ~= "WeaponAttackType" and self.SkinType ~=
        "Skin" then
        local player = getPlayer()
        if AttachmentRules then
            local canRemove, blocking = AttachmentRules.canRemovePart(self.attachingTo, self.slotItem)
            if not canRemove then
                -- The last silent gate on the removal path. [GGS SlotDBG] showed the
                -- double-click arriving with a real part in the slot, yet
                -- ISRemoveWeaponUpgrade never ran -- neither its isValid nor its complete
                -- printed -- so the action was never queued, and this branch only ever
                -- spoke in-game.
                local names = {}
                if blocking then
                    for _, entry in ipairs(blocking) do
                        local p = entry and entry.part
                        names[#names + 1] = tostring(p and p.getFullType and p:getFullType() or "?")
                    end
                end
                print("[GGS SlotDBG] stop: canRemovePart = false, blocked by [" ..
                          table.concat(names, ", ") .. "]")
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
        -- Remove child parts first (deepest first) so removing a parent never
        -- leaves an orphaned child pointing at a gone attachment point, which
        -- previously made parts un-removable / crashed the game to the menu.
        local weapon = self.attachingTo
        local seen = {}
        local function queueRemoval(part)
            if not part then return end
            local pt = part:getPartType()
            if not pt or seen[pt] then return end
            seen[pt] = true
            local kids = nil
            pcall(function()
                if AttachmentRules and AttachmentRules.getBlockingChildren then
                    kids = AttachmentRules.getBlockingChildren(weapon, part)
                end
            end)
            if kids then
                for _, c in ipairs(kids) do
                    if c and c.part then queueRemoval(c.part) end
                end
            end
            ISTimedActionQueue.add(ISRemoveWeaponUpgrade:new(player, weapon, pt, 1))
        end
        queueRemoval(self.slotItem)
        if player then
            getSoundManager():PlayWorldSound("WeaponPartInsertSound", player:getSquare(), 0, 0, 0, false);
        end
    end

end

function attachmentButton:onMouseUp()
    -- This is the step that opens the part list, and it was the last one with no
    -- visibility at all. [GGS ClickDBG] only covers buttons INSIDE the list, so a list
    -- that never opens looks identical to a user who never clicked: zero log lines
    -- either way. Both silent returns below are candidates.
    print(string.format("[GGS PaneDBG] slot onMouseUp type=%s slotItem=%s window=%s",
        tostring(self.attachmentType),
        tostring(self.slotItem and self.slotItem.getFullType and self.slotItem:getFullType() or self.slotItem),
        tostring(riskyInspectWindow ~= nil)))
    if self.slotItem ~= nil and self.ClipType ~= "ClipType" and self.AttackModeType ~= "WeaponAttackType" and
        self.SkinType ~= "Skin" then
        print("[GGS PaneDBG] stop: slot already occupied")
        return
    end

    if not riskyInspectWindow then
        print("[GGS PaneDBG] stop: riskyInspectWindow is nil")
        return
    end

    local paneClass = resolveSelectAttachmentPane()
    if not paneClass then
        print("AWCWF: selectAttachmentPane class unavailable")
        return
    end

    local okPane, pane = pcall(paneClass.new, paneClass,
        riskyInspectWindow:getX() + self:getX() + ATTACHMENT_PANE_OFFSET_X,
        riskyInspectWindow:getY() + self:getY() - 3, self.attachmentType, self.ClipType, self.AttackModeType,
        self.SkinType)
    if not okPane then
        -- Previously an unprotected call: anything thrown in the pane constructor took
        -- the whole click with it and never showed up anywhere.
        print("[GGS PaneDBG] pane constructor ERRORED: " .. tostring(pane))
        return
    end

    if pane then
        pane:addToUIManager()
        pane:bringToTop()
        local count = pane.elements and #pane.elements or -1
        print("[GGS PaneDBG] pane opened, listed parts = " .. tostring(count))
    else
        print("[GGS PaneDBG] stop: pane constructor returned nil")
    end
end
local function getJavaFieldNum(object, fieldName)
    if not object then return nil end
    -- getNumClassFields() is debug-only reflection; outside of -debug it throws
    -- "Not in debug". Guard it so clicking an attachment button degrades gracefully
    -- instead of crashing (same root issue as AWCWF getNumClassFields).
    local ok, count = pcall(getNumClassFields, object)
    if not ok or type(count) ~= "number" then
        return nil
    end
    for i = 0, count - 1 do
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
            -- Prefer the proper API (works without -debug); fall back to reflection.
            local worldmodel = (item.getWorldStaticModel and item:getWorldStaticModel()) or nil
            if not worldmodel then
                local wTransformFieldNum = getJavaFieldNum(item, "worldStaticModel")
                worldmodel = wTransformFieldNum and getClassFieldVal(item, getClassField(item, wTransformFieldNum)) or nil
            end

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
    -- Last unobserved link. Three sessions of logs now agree that on MP nothing is ever
    -- attached: attachWeaponPart is never called, setWeaponPart only ever sees Clip, and
    -- the part-state token never changes -- even with GGSGS.DevAttachmentSpawner = true
    -- confirmed loaded by the server. So the question is no longer which storage the
    -- part lands in, it is whether this click runs at all and which guard it stops on.
    -- Every one of the returns below is silent or only speaks in-game, so the log has
    -- never shown any of this. Prints unconditionally: one line per click is nothing.
    print(string.format(
        "[GGS ClickDBG] onMouseDown type=%s slotItem=%s enabled=%s devSpawnMissing=%s readOnly=%s",
        tostring(self.type),
        tostring(self.slotItem and self.slotItem.getFullType and self.slotItem:getFullType() or self.slotItem),
        tostring(self.enabled), tostring(self.devSpawnMissing), tostring(READ_ONLY_UI)))
    if READ_ONLY_UI then
        print("[GGS ClickDBG] stop: READ_ONLY_UI")
        sayReadOnly()
        return
    end
    -- Say why nothing happens. riskyShowPotentialAttachment is hardcoded true, so the
    -- pane always lists parts the player does not own, but it builds those buttons
    -- with enabled = devAttachmentSpawner (selectAttachmentPane.lua:412). Offline that
    -- is usually on via -debug, so clicking one spawns the part and attaches it and
    -- everything looks fine; on a server with GGSGS.DevAttachmentSpawner = false it is
    -- off, and this used to fall through to a silent return -- part visible in the
    -- list, click does nothing, no message, no log line. That silence is what made
    -- "attachments do not work online" look like a broken attach system.
    if self.slotItem and not self.enabled then
        print("[GGS ClickDBG] stop: button disabled (enabled=false)")
        sayReadOnly("IGUI_GGS_DevAttachmentSpawnerDisabled")
        return
    end
    if not self.slotItem then
        print("[GGS ClickDBG] stop: slotItem is nil")
    end
    if self.slotItem and self.enabled then
        if self.type ~= "WeaponPart" and self.type ~= "ClipType" then
            print("[GGS ClickDBG] stop: type not attachable (" .. tostring(self.type) .. ")")
            sayReadOnly(LIMITED_ACTION_MSG_KEY)
            return
        end

        local didAction = false
        if self.type == "WeaponPart" then
            if AttachmentRules and not AttachmentRules.canInstallOnWeapon(self.attachingTo, self.slotItem) then
                print("[GGS ClickDBG] stop: canInstallOnWeapon = false")
                local player = getPlayer()
                local message = getText("IGUI_AWCWF_AttachmentLocked")
                if player and message and message ~= "" then
                    player:Say(message)
                end
                return
            end
            local player = getPlayer()
            if not player then
                print("[GGS ClickDBG] stop: no player")
                return
            end
            -- Occupied means occupied in EITHER store. After a server-side attach the part
            -- exists as the server's real part plus the pushed mirror entry, while this
            -- client's own real map stays empty -- clicking the pane's entry again then
            -- re-sent the server request forever, one toast per click. Check the mirror
            -- too and say what is actually going on.
            local occSlot = self.slotItem.getPartType and self.slotItem:getPartType()
            local occReal = occSlot and self.attachingTo and self.attachingTo:getWeaponPart(occSlot) or nil
            local occMd = self.attachingTo and self.attachingTo.getModData and self.attachingTo:getModData()
            local occMirror = occSlot and occMd and occMd.weaponpart and occMd.weaponpart[occSlot]
            if occReal or (occMirror and occMirror ~= "") then
                print("[GGS ClickDBG] stop: slot " .. tostring(occSlot) .. " already occupied (real=" ..
                          tostring(occReal and occReal.getFullType and occReal:getFullType() or occReal) ..
                          " mirror=" .. tostring(occMirror) .. ")")
                player:Say(ggsText("IGUI_GGS_SlotOccupied"))
                return
            end
            print("[GGS ClickDBG] passed guards, proceeding to stage+queue")
            if self.devSpawnMissing then
                if not isDevAttachmentSpawnerEnabled() then
                    player:Say(ggsText("IGUI_GGS_DevAttachmentSpawnerDisabled"))
                    return
                end
                local fullType = self.devSpawnFullType or (self.slotItem and self.slotItem.getFullType and self.slotItem:getFullType())
                -- On MP the part has to be created by the server. Spawning it here with
                -- inventory:AddItem produces an item only this client knows about; the
                -- code below then stages that ghost and queues vanilla's ISUpgradeWeapon,
                -- which validates against server state and silently never performs. That
                -- is the whole "attachments do not work online" symptom: click fires,
                -- guards pass, spawn reports success, attachWeaponPart is never reached.
                -- So ask the server (GGS_DevSpawnServer.lua) and stop here -- the item
                -- arrives a moment later, the pane refreshes on the inventory-size
                -- change, and the part is then a real one in the owned list.
                if isClient and isClient() then
                    sendClientCommand(player, "GGS", "devSpawnPart", { fullType = fullType })
                    player:Say(ggsText("IGUI_GGS_DevAttachmentRequested"))
                    return
                end
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

            -- A reference with no container and no world item is a DEAD reference, not a
            -- missing item. Proven from the server save itself: JustNON's player blob
            -- holds the suppressor (customName "SodaCan Silencer", Tooltip_Canon) while
            -- the clicked reference reads container=nil worldItem=false and every lookup
            -- on it fails -- the MP inventory resync replaces item objects wholesale, the
            -- pane's button keeps pointing at the pre-resync object, and even its ID dies
            -- with it. So re-resolve by fullType against the live inventory and continue
            -- with the real object; only give up when no live item of that type exists.
            local stagedContainer = stagedPart.getContainer and stagedPart:getContainer() or nil
            local okWorld, inWorld = pcall(function() return stagedPart:getWorldItem() ~= nil end)
            if not stagedContainer and not (okWorld and inWorld) then
                local wantedFull = stagedPart.getFullType and stagedPart:getFullType() or nil
                local replacement = wantedFull and
                                        ggsFindLiveItemByFullType(player:getInventory(), wantedFull, 0) or nil
                if replacement then
                    print(string.format("[GGS PartTx] re-resolved stale reference %s to live item id=%s",
                        tostring(wantedFull), tostring(replacement.getID and replacement:getID())))
                    stagedPart = replacement
                    sourceContainer = replacement.getContainer and replacement:getContainer() or sourceContainer
                else
                    print(string.format(
                        "[GGS PartTx] refusing stale item reference %s: no container, no world item, no live twin",
                        tostring(wantedFull or "?")))
                    player:Say(ggsText("IGUI_GGS_CouldNotSpawnAttachment"))
                    if riskyInspectWindow and riskyInspectWindow.renderInventory then
                        riskyInspectWindow:renderInventory()
                    end
                    return
                end
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
