require "ISUI/ISPanel"
require "ISUI/ISButton"

riskyUI_infoPanel = ISPanel:derive("riskyUI_infoPanel")
riskyUI_infoPanel.instance = nil

local NAV_WIDTH = 150
local PADDING = 10
local TAB_HEIGHT = 28

local TAB_CONTENT = {
    {
        title = "Keyboard shortcout",
        lines = {
            "* Hold R for open radial menu and Swap Mags",
            "* Press F for switch Flashlight and laser mod.",
            "* Press G with a GrenadeLauncher to shoot, u need ammo"
            
        }
    },
    {
        title = "Bullet Crafts",
        lines = {
            "* You can disassemble any bullet; you just need pliers.",
            "* "
        }
    },
    {
        title = "Crafts",
        lines = {
            "Contenido de prueba - Info 3.",
            "Listo para agregar mas informacion."
        }
    },
    {
        title = "Fixing Guns",
        lines = {
            "Contenido de prueba - Info 3.",
            "Listo para agregar mas informacion."
        }
    }
}

local function closeInstance(instance)
    if not instance then
        return
    end
    instance:setVisible(false)
    instance:removeFromUIManager()
    if riskyUI_infoPanel.instance == instance then
        riskyUI_infoPanel.instance = nil
    end
end

function riskyUI_infoPanel:onOptionMouseDown(button)
    if not button then
        return
    end

    if button.internal == "close" then
        self:close()
        return
    end

    if button.internal == "tab" then
        self.selectedTab = button.infoTabIndex or 1
    end
end

function riskyUI_infoPanel:close()
    closeInstance(self)
end

function riskyUI_infoPanel:update()
    if self.parentWindow and (not self.parentWindow:getIsVisible()) then
        self:close()
    end
end

function riskyUI_infoPanel:createChildren()
    ISPanel.createChildren(self)

    self.tabButtons = {}
    local y = 44
    for i = 1, #TAB_CONTENT do
        local tab = TAB_CONTENT[i]
        local button = ISButton:new(PADDING, y, NAV_WIDTH - (PADDING * 2), TAB_HEIGHT, tab.title, self,
            self.onOptionMouseDown)
        button.internal = "tab"
        button.infoTabIndex = i
        button:initialise()
        button:instantiate()
        button.borderColor.a = 0.3
        button.backgroundColor.a = 0.2
        button.backgroundColorMouseOver.a = 0.4
        self:addChild(button)
        self.tabButtons[i] = button
        y = y + TAB_HEIGHT + 6
    end

    self.closeButton = ISButton:new(self.width - 28, 8, 20, 20, "X", self, self.onOptionMouseDown)
    self.closeButton.internal = "close"
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton.borderColor.a = 0
    self.closeButton.backgroundColor.a = 0.2
    self.closeButton.backgroundColorMouseOver.a = 0.5
    self:addChild(self.closeButton)
end

function riskyUI_infoPanel:prerender()
    ISPanel.prerender(self)

    self:drawRect(0, 0, self.width, self.height, 0.86, 0.06, 0.06, 0.06)
    self:drawRectBorder(0, 0, self.width, self.height, 0.9, 0.3, 0.3, 0.3)
    self:drawRect(NAV_WIDTH, 0, 1, self.height, 0.7, 0.25, 0.25, 0.25)

    self:drawText("Info", PADDING, 12, 1, 1, 1, 1, UIFont.Medium)

    local activeButton = self.tabButtons and self.tabButtons[self.selectedTab]
    if activeButton then
        self:drawRect(activeButton:getX() - 2, activeButton:getY() - 1, activeButton:getWidth() + 4,
            activeButton:getHeight() + 2, 0.35, 0.15, 0.5, 0.75)
    end
end

function riskyUI_infoPanel:render()
    local tab = TAB_CONTENT[self.selectedTab] or TAB_CONTENT[1]
    local textX = NAV_WIDTH + 16
    local y = 14

    self:drawText(tab.title, textX, y, 1, 1, 1, 1, UIFont.Medium)
    y = y + 28

    for i = 1, #tab.lines do
        self:drawText(tab.lines[i], textX, y, 0.92, 0.92, 0.92, 1, UIFont.Small)
        y = y + 20
    end
end

function riskyUI_infoPanel:new(x, y, width, height, parentWindow)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.parentWindow = parentWindow
    o.selectedTab = 1
    o.background = false
    o.moveWithMouse = true
    o.anchorLeft = false
    o.anchorRight = false
    o.anchorTop = false
    o.anchorBottom = false
    return o
end

return riskyUI_infoPanel
