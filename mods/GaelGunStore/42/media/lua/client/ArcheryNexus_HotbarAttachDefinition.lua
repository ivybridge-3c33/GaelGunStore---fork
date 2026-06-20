require "Hotbar/ISHotbarAttachDefinition"
if not ISHotbarAttachDefinition then
    return
end

local REX5BowBack = {
	type = "REX5BowBack",-- Name shown in the slot icon
	name = "Bow Equip Slot",
	animset = "back", -- Animation name 
	attachments = {
		REX5BowBack = "REX5BowBack",
	},
}
table.insert(ISHotbarAttachDefinition, REX5BowBack);

local REX5 = {
	type = "REX5",-- Name shown in the slot icon
	name = "Quiver Arrow Slot",
	animset = "back", -- Animation name 
	attachments = {
		REX5 = "REX5",
		arrow_wood = "REX5",
		arrow_wood_floor = "REX5",
		arrow_metal = "REX5",
		arrow_metal_floor = "REX5",
		arrow_carbon = "REX5",
		arrow_carbon_floor = "REX5",
		bolt_wood = "REX5",
		bolt_wood_floor = "REX5",
		bolt_metal = "REX5",
		bolt_metal_floor = "REX5",
		bolt_carbon = "REX5",
		bolt_carbon_floor = "REX5",
		WoodShaft_Arrow = "REX5",
	},
}
table.insert(ISHotbarAttachDefinition, REX5);