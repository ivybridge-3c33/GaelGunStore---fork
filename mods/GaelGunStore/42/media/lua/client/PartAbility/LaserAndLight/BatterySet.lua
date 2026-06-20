pcall(require, "ISUI/ISInventoryPaneContextMenu")

local function toPlayerObject(playerRef)
    if not playerRef then
        return getPlayer()
    end
    if type(playerRef) == "number" then
        if getSpecificPlayer then
            local p = getSpecificPlayer(playerRef)
            if p then
                return p
            end
        end
        return getPlayer()
    end
    return playerRef
end

local function RemoveBattery(player, item, PartType)
    player = toPlayerObject(player)
    if not player or not item then
        return
    end
    local md = item:getModData()
    local remain = 0
    if PartType == "Laser" then
        remain = tonumber(md.LaserBatteryReamin) or 0
        md.LaserBatteryReamin = 0
    elseif PartType == "Light" then
        remain = tonumber(md.LightBatteryReamin) or 0
        md.LightBatteryReamin = 0
    end

    remain = math.max(0, math.min(100, remain))
    if remain > 0 then
        local battery = player:getInventory():AddItem("Base.Battery")
        if battery and battery.setCurrentUsesFloat then
            battery:setCurrentUsesFloat(remain / 100.0)
        end
    end

end

local function AddBattery(player, item, PartType, Battery)
    player = toPlayerObject(player)
    if not player or not item or not Battery then
        return
    end

    local power = 0
    if Battery.getCurrentUsesFloat then
        power = tonumber(Battery:getCurrentUsesFloat()) or 0
    end
    power = math.max(0, math.min(1, power))
    local remain = math.floor(power * 100 + 0.5)

    local md = item:getModData()
    if PartType == "Laser" then
        md.LaserBatteryReamin = remain
    elseif PartType == "Light" then
        md.LightBatteryReamin = remain
    end

    local container = Battery.getContainer and Battery:getContainer() or nil
    if container and container.Remove then
        container:Remove(Battery)
    end
    local inventory = player.getInventory and player:getInventory() or nil
    if inventory and inventory.contains and inventory:contains(Battery) then
        inventory:Remove(Battery)
    end

end

local function GetMaxBattery(player)
    if not player then
        return nil
    end
    local inventory = player:getInventory();
    local list = inventory:FindAll("Base.Battery");
    local Max
    for i = 0, list:size() - 1 do
        local TempItem = list:get(i)
        if not Max or TempItem:getCurrentUsesFloat() > Max:getCurrentUsesFloat() then
            Max = TempItem
        end
    end
    return Max
end

local function SendItem(_player, _context, _items)
    _player = toPlayerObject(_player)
    if not _player or not _context or not _items then
        return
    end
    local resItems = {}
    local container
    for i, v in ipairs(_items) do
        if not instanceof(v, "InventoryItem") then
            for _, it in ipairs(v.items) do
                resItems[it] = true
            end
            container = v.items[1]:getContainer()
        else
            resItems[v] = true
            container = v:getContainer()
        end
    end
    for v, _ in pairs(resItems) do
        if instanceof(v, "HandWeapon") and v.IsWeapon and v:IsWeapon() and v.isRanged and v:isRanged() then
            local Laser = v.getLaser and v:getLaser() or nil
            if Laser then
                local Battery = v:getModData().LaserBatteryReamin
                if Battery and Battery > 0 then
                    _context:addOption(getText("ContextMenu_Remove_Battery_To_Laser"), _player, RemoveBattery, v,
                        "Laser")
                end
                if Battery == 0 or Battery == nil then
                    local BatteryItem = GetMaxBattery(_player)
                    if BatteryItem then
                        _context:addOption(getText("ContextMenu_ADD_Battery_To_Laser"), _player, AddBattery, v,
                            "Laser", BatteryItem)
                    end
                end
            end
            local Light = v.getLight and v:getLight() or nil
            if Light then
                local Battery = v:getModData().LightBatteryReamin
                if Battery and Battery > 0 then
                    _context:addOption(getText("ContextMenu_Remove_Battery_To_Light"), _player, RemoveBattery, v,
                        "Light")
                end
                if Battery == 0 or Battery == nil then
                    local BatteryItem = GetMaxBattery(_player)
                    if BatteryItem then
                        _context:addOption(getText("ContextMenu_ADD_Battery_To_Light"), _player, AddBattery, v,
                            "Light", BatteryItem)
                    end
                end
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(SendItem)
