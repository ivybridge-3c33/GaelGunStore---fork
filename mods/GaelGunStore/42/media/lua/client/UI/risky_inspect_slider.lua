riskyUI_slider = ISCollapsableWindow:derive("riskyUI_slider")

local function formatValue(value)
    return math.floor((value * 4 - 200) / 100 * 10000) / 10000
end

function riskyUI_slider:callback(value, slider)
    -- Read-only isolation mode: do not write model offsets or modData.
    return
end

function riskyUI_slider:render()
    ISCollapsableWindow.render(self)

    local itemname = "None"
    local itemtexture = nil

    if self.itempart then
        local itemseed = ScriptManager.instance:getItem(self.itempart)
        local icon = itemseed:getIcon()
        itemtexture = getTexture("media/textures/Item_" .. icon .. ".png")
        itemname = itemseed:getDisplayName()
    end

    if itemtexture then
        self:drawTextureScaled(itemtexture, self.baselenth * 3, self.baselenth * 3, self.width - self.baselenth * 12,
            self.width - self.baselenth * 12, 1.0, 1.0, 1.0, 1.0)
    end

    self:drawText(itemname, self.baselenth * 4, self.width - self.baselenth * 8, 1, 1, 1, 0.9, UIFont.Large)

    local sliders = {self.slider1, self.slider2, self.slider3}
    local offsets = {self.offsetX, self.offsetY, self.offsetZ}
    local labels = {"X", "Y", "Z"}

    for i, slider in ipairs(sliders) do
        local value = formatValue(slider.currentValue)
        self:drawText(labels[i] .. ": " .. value, self.baselenth * 4, offsets[i], 1, 1, 1, 0.9, UIFont.Large)
    end
end

function riskyUI_slider:createChildren()
    ISCollapsableWindow.createChildren(self)

    local y = self.height / 2
    local x = self.baselenth
    local width = self.width - 2 * self.baselenth
    local height = 1.5 * self.baselenth

    local sliders = {}
    local offsets = {}

    for i = 1, 3 do
        local slider = ISSliderPanel:new(x, y, width, height, self, self.callback)
        slider:initialise()
        slider:instantiate()
        self:addChild(slider)
        sliders[i] = slider
        offsets[i] = y + self.baselenth + height
        y = y + self.baselenth * 3 + height
    end

    self.slider1, self.slider2, self.slider3 = sliders[1], sliders[2], sliders[3]
    self.offsetX, self.offsetY, self.offsetZ = offsets[1], offsets[2], offsets[3]
end

function riskyUI_slider:new(x, y, width, height, parent)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o:setResizable(true)
    o.title = "part"
    o.parenta = parent
    o.parttype = "Wrench"
    o.baselenth = width / 20
    return o
end
