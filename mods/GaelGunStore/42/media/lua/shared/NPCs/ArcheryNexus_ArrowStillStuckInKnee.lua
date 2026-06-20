-- Adds attachment positions on Items
--[[
local group = BodyLocations.getGroup("Human")
group:getOrCreateLocation(ItemBodyLocation.REX5)
group:getOrCreateLocation(ItemBodyLocation.RX5ArrowSlot)

group:getOrCreateLocation(ItemBodyLocation.RX5QuiverSlot)
group:getOrCreateLocation(ItemBodyLocation.REX5BowBack)
--[[
local group = BodyLocations.getGroup("Human")
group:getOrCreateLocation("REX5")
group:getOrCreateLocation("RX5ArrowSlot")
group:getOrCreateLocation("RX5QuiverSlot")
group:getOrCreateLocation("REX5BowBack")
--]]