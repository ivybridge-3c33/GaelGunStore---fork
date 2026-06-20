local script =
"inputs {}"

local recipe = getScriptManager():getCraftRecipe("OpenBoxOfBullets20")
recipe:getInputs():clear()
recipe:Load("OpenBoxOfBullets20",script)

local recipe = getScriptManager():getCraftRecipe("OpenBoxOfBullets50")
recipe:getInputs():clear()
recipe:Load("OpenBoxOfBullets50",script)

local recipe = getScriptManager():getCraftRecipe("place_ammo_in_box")
recipe:getInputs():clear()
recipe:Load("PlaceAmmoInBox",script)

local box3030 = getScriptManager():getItem("Base.3030Box")
if box3030 and box3030.DoParam then
    box3030:DoParam("DoubleClickRecipe = OpenBoxof3030Bullets")
end
