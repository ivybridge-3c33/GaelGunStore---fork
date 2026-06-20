-- Filters invalid script items so the vanilla Admin -> Items list doesn't crash
local function patchISItemsListTable()
	if not ISItemsListTable or not ISItemsListTable.initList or ISItemsListTable.__gaelSafeInit then
		return
	end

	ISItemsListTable.__gaelSafeInit = true
	local vanillaInit = ISItemsListTable.initList

	function ISItemsListTable:initList(module)
		if type(module) == "table" then
			local safeList = {}
			for _, v in ipairs(module) do
				local itemType = v and v.getItemType and v:getItemType()
				if itemType then
					safeList[#safeList + 1] = v
				else
					print("[GaelGunStore] Skipping item without itemType in ISItemsListTable: " ..
						tostring(v and v.getFullName and v:getFullName() or v))
				end
			end
			module = safeList
		end

		return vanillaInit(self, module)
	end
end

Events.OnGameBoot.Add(patchISItemsListTable)
patchISItemsListTable()
