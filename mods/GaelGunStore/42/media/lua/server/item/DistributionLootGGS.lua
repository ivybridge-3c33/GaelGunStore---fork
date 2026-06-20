require 'Items/ProceduralDistributions'
require 'Items/SuburbsDistributions'
require 'Items/ItemPicker'

local historicMode = GGS_HistoricModeBlacklist
do
	local ok, module = pcall(require, "GGS_HistoricModeBlacklist")
	if ok then
		historicMode = module or GGS_HistoricModeBlacklist
	end
end

WeaponUpgrades = {
	VarmintRifle = {},
	HuntingRifle = {},
	Shotgun = {},
	Pistol = {},
	Pistol2 = {},
	Pistol3 = {},
	Revolver = {},
	Revolver_Long = {},
}

-- Avoid double injection if scripts reload.
if _G.__GGS_LOOT_DONE then return end
_G.__GGS_LOOT_DONE = true

local function getSV(key, default)
	local sv = SandboxVars or {}
	if sv.GGSLO and sv.GGSLO[key] ~= nil then return sv.GGSLO[key] end
	if sv[key] ~= nil then return sv[key] end
	return default
end

local function getLootAmount()
	local sv = SandboxVars or {}
	if sv.GGS and sv.GGS.LootAmount then return sv.GGS.LootAmount end
	if sv.GGSGS and sv.GGSGS.LootAmount then return sv.GGSGS.LootAmount end
	if sv.LootAmount then return sv.LootAmount end
	return 4
end

-- GGS injects hundreds of entries into several gun-store lists. Small weights are
-- needed here because the procedural picker sums all entries in a list per roll.
local lootLookup = { 0, 0.0025, 0.01, 0.025, 0.05, 0.1 }
local lootMult = lootLookup[getLootAmount()] or 1

local function isHistoricLootBlocked(item)
	return historicMode and historicMode.shouldBlock and historicMode.shouldBlock(item)
end

local function addProcItem(listName, item, baseWeight, svKey)
	if isHistoricLootBlocked(item) then
		return
	end
	local pd = ProceduralDistributions and ProceduralDistributions.list
	if not (pd and pd[listName]) then return end
	local weight = baseWeight * lootMult
	if svKey then
		weight = weight * (getSV(svKey, 1) or 1)
	end
	table.insert(pd[listName].items, item)
	table.insert(pd[listName].items, weight)
end

local function ensureList(listName)
	local pd = ProceduralDistributions and ProceduralDistributions.list
	if not pd then return end
	if not pd[listName] then
		pd[listName] = {
			rolls = 2,
			items = {},
			junk = { rolls = 1, items = {} },
		}
	end
end

local function classifyAmmo(fullType)
	if type(fullType) ~= "string" then return nil end
	local s = fullType:lower()
	if s:find("box") then return "box" end
	if s:find("bullets") or s:find("bullet") or s:find("ammo") or s:find("shell") or s:find("round") then
		return "bullet"
	end
	if s:find("clip") or s:find("magazine") then
		return "mag"
	end
	-- Heuristic for mags: "mag" but avoid false positives like magpul/magnum.
	if s:find("mag") and not s:find("magpul") and not s:find("magnum") then
		return "mag"
	end
	return nil
end

local lootEntries = require("item/loot")

local injected = false
local function injectLoot()
	if injected then return end
	injected = true
	ensureList("GunStoreAmmunition")
	for _, entry in ipairs(lootEntries) do
		addProcItem(entry.list, entry.item, entry.weight, entry.sv)
		-- Duplicate ammo/mag entries into the dedicated ammo list with priority scaling.
		if entry.list ~= "GunStoreAmmunition" then
			local kind = classifyAmmo(entry.item)
			if kind then
				local factor = (kind == "bullet" and 1.0) or (kind == "box" and 0.5) or (kind == "mag" and 0.1) or 1.0
				addProcItem("GunStoreAmmunition", entry.item, entry.weight * factor, "prob_ammo_mags")
			end
		end
	end
	-- Re-parse distributions so the game picks up new entries.
	if ItemPickerJava and ItemPickerJava.Parse then
		ItemPickerJava.Parse()
	end
end

-- En MP el servidor no dispara OnGameStart; aseguramos inyeccion en eventos de servidor.
Events.OnInitWorld.Add(injectLoot)
Events.OnLoadMapZones.Add(injectLoot)
Events.OnGameStart.Add(injectLoot)
