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
		return data.Inventory[1], 1
	end
	for index, item in ipairs(data.Inventory) do
		if item.UniqueId == itemId then
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
		InventoryService.Context.Services.EconomyService.Notify(player, "That item is no longer in your inventory.")
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
		return nil
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
	local line = string.format(
		"[FEED THE VOID][Inventory] %s inventory=%d/%d displayed=%d/%d",
		player and player.Name or "server",
		counts.Inventory,
		counts.InventoryCap,
		counts.Displayed,
		counts.DisplayedCap
	)
	print(line)
	if player then
		InventoryService.Context.Services.EconomyService.Notify(player, "Inventory: " .. tostring(counts.Inventory) .. "/" .. tostring(counts.InventoryCap) .. " | Displayed: " .. tostring(counts.Displayed) .. "/" .. tostring(counts.DisplayedCap))
	end
	return counts
end

return InventoryService
