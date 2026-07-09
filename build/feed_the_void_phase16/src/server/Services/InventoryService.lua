local HttpService = game:GetService("HttpService")

local InventoryService = {}

function InventoryService.Init(context)
	InventoryService.Context = context
end

function InventoryService.Start() end

function InventoryService.GetData(player)
	return InventoryService.Context.Services.ProfileServiceWrapper.GetData(player)
end

local function limitValue(limitName, fallback)
	local limits = InventoryService.Context.Config.GameConfig.Limits or {}
	local anti = InventoryService.Context.Config.GameConfig.AntiExploit or {}
	return tonumber(limits[limitName]) or tonumber(anti[limitName]) or fallback
end

local function ensureLists(data)
	if not data then
		return nil
	end
	data.Inventory = type(data.Inventory) == "table" and data.Inventory or {}
	data.DisplayedSnacks = type(data.DisplayedSnacks) == "table" and data.DisplayedSnacks or {}
	return data
end

local function sanitizeItem(item)
	if type(item) ~= "table" then
		return nil
	end
	item.UniqueId = tostring(item.UniqueId or HttpService:GenerateGUID(false))
	item.SnackId = tostring(item.SnackId or "")
	item.MutationId = tostring(item.MutationId or "Normal")
	item.CreatedAt = tonumber(item.CreatedAt) or os.time()
	item.ValueMultiplier = tonumber(item.ValueMultiplier) or 1
	item.DisplayName = tostring(item.DisplayName or item.SnackId)
	item.Locked = item.Locked == true
	local context = InventoryService.Context
	local snack = context and context.Config.SnackConfig[item.SnackId]
	local sizeConfig = context and context.Config.SizeConfig
	if sizeConfig and snack then
		sizeConfig.ApplyToItem(item, snack, "Regular")
	else
		item.SizeTier = tostring(item.SizeTier or "Regular")
		item.SizeMultiplier = tonumber(item.SizeMultiplier) or 1
		item.Weight = tonumber(item.Weight) or 1
		item.SizeValueMultiplier = tonumber(item.SizeValueMultiplier) or 1
	end
	return item
end

function InventoryService.GetInventoryCap()
	return limitValue("MaxInventoryItems", 250)
end

function InventoryService.GetDisplayedCap()
	return limitValue("MaxDisplayedSnacksPerPlayer", 10)
end

function InventoryService.CanAddItem(player)
	local data = ensureLists(InventoryService.GetData(player))
	return data ~= nil and #data.Inventory < InventoryService.GetInventoryCap()
end

function InventoryService.CanDisplayItem(player)
	local data = ensureLists(InventoryService.GetData(player))
	return data ~= nil and #data.DisplayedSnacks < InventoryService.GetDisplayedCap()
end

function InventoryService.AddItem(player, item)
	local data = ensureLists(InventoryService.GetData(player))
	if not data then
		return nil
	end
	if #data.Inventory >= InventoryService.GetInventoryCap() then
		InventoryService.Context.Services.EconomyService.Notify(player, "Inventory full. Sell, feed, or display a snack first.")
		return nil, "Full"
	end
	item = sanitizeItem(item)
	if not item or item.SnackId == "" then
		return nil, "InvalidItem"
	end
	table.insert(data.Inventory, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.FindItem(player, itemId)
	local data = ensureLists(InventoryService.GetData(player))
	if not data then
		return nil, nil
	end
	if itemId == nil or itemId == "" then
		return nil, nil
	end
	itemId = tostring(itemId)
	for index, item in ipairs(data.Inventory) do
		if tostring(item.UniqueId) == itemId then
			return item, index
		end
	end
	return nil, nil
end

function InventoryService.IsLocked(item)
	return type(item) == "table" and item.Locked == true
end

function InventoryService.ToggleItemLock(player, itemId)
	local item = InventoryService.FindItem(player, itemId)
	if not item then
		local missingId = itemId == nil or itemId == ""
		InventoryService.Context.Services.EconomyService.Notify(player, missingId and "Select a snack first." or "That item is no longer in your inventory.")
		return false
	end
	item.Locked = not (item.Locked == true)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	InventoryService.Context.Services.EconomyService.Notify(player, item.Locked and "Item locked." or "Item unlocked.")
	return true, item.Locked
end

function InventoryService.RemoveItem(player, itemId, allowLocked)
	local data = ensureLists(InventoryService.GetData(player))
	local item, index = InventoryService.FindItem(player, itemId)
	if not data or not item or not index then
		local missingId = itemId == nil or itemId == ""
		return nil, missingId and "MissingItemId" or "Missing"
	end
	if item.Locked and allowLocked ~= true then
		return nil, "Locked"
	end
	table.remove(data.Inventory, index)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.AddDisplayed(player, item)
	local data = ensureLists(InventoryService.GetData(player))
	if not data then
		return nil
	end
	if #data.DisplayedSnacks >= InventoryService.GetDisplayedCap() then
		InventoryService.Context.Services.EconomyService.Notify(player, "Display shelf full. Feed or sell a displayed snack later.")
		return nil, "DisplayFull"
	end
	item = sanitizeItem(item)
	if not item or item.SnackId == "" then
		return nil, "InvalidItem"
	end
	table.insert(data.DisplayedSnacks, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.ClearInventory(player)
	local data = ensureLists(InventoryService.GetData(player))
	if data then
		data.Inventory = {}
		InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
end

function InventoryService.ClearDisplayed(player)
	local data = ensureLists(InventoryService.GetData(player))
	if data then
		data.DisplayedSnacks = {}
		InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
end

function InventoryService.GetCounts(player)
	local data = ensureLists(InventoryService.GetData(player))
	return {
		Inventory = data and #data.Inventory or 0,
		InventoryCap = InventoryService.GetInventoryCap(),
		Displayed = data and #data.DisplayedSnacks or 0,
		DisplayedCap = InventoryService.GetDisplayedCap(),
	}
end

function InventoryService.PrintInventoryCheck(player)
	local counts = InventoryService.GetCounts(player)
	local data = ensureLists(InventoryService.GetData(player))
	local locked = 0
	local malformed = 0
	local missingSize = 0
	local duplicates = 0
	local seen = {}
	for _, item in ipairs(data and data.Inventory or {}) do
		local uniqueId = item and tostring(item.UniqueId or "") or ""
		if type(item) ~= "table" or uniqueId == "" or item.SnackId == nil then
			malformed += 1
		end
		if item and item.Locked == true then
			locked += 1
		end
		if item and (item.SizeTier == nil or item.SizeMultiplier == nil or item.SizeValueMultiplier == nil or item.Weight == nil) then
			missingSize += 1
		end
		if uniqueId ~= "" then
			if seen[uniqueId] then
				duplicates += 1
			end
			seen[uniqueId] = true
		end
	end
	local line = string.format(
		"[FEED THE VOID][Inventory] %s inventory=%d/%d displayed=%d/%d locked=%d malformed=%d duplicateUniqueId=%d missingSizeFields=%d MissingItemFallbackDisabled=true",
		player and player.Name or "server",
		counts.Inventory,
		counts.InventoryCap,
		counts.Displayed,
		counts.DisplayedCap,
		locked,
		malformed,
		duplicates,
		missingSize
	)
	print(line)
	if player then
		InventoryService.Context.Services.EconomyService.Notify(player, "Inventory: " .. tostring(counts.Inventory) .. "/" .. tostring(counts.InventoryCap) .. " | locked " .. tostring(locked) .. " | malformed " .. tostring(malformed) .. " | exact-id only")
	end
	counts.Locked = locked
	counts.Malformed = malformed
	counts.DuplicateUniqueIds = duplicates
	counts.MissingSizeFields = missingSize
	counts.MissingItemFallbackDisabled = true
	return counts
end

return InventoryService
