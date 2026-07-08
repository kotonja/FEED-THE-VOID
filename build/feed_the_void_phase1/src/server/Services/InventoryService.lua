local HttpService = game:GetService("HttpService")

local InventoryService = {}

function InventoryService.Init(context)
	InventoryService.Context = context
end

function InventoryService.Start() end

function InventoryService.GetData(player)
	return InventoryService.Context.Services.ProfileServiceWrapper.GetData(player)
end

function InventoryService.AddItem(player, item)
	local data = InventoryService.GetData(player)
	if not data then
		return nil
	end
	item.UniqueId = item.UniqueId or HttpService:GenerateGUID(false)
	table.insert(data.Inventory, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.FindItem(player, itemId)
	local data = InventoryService.GetData(player)
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

function InventoryService.RemoveItem(player, itemId)
	local data = InventoryService.GetData(player)
	local item, index = InventoryService.FindItem(player, itemId)
	if not data or not item or not index then
		return nil
	end
	table.remove(data.Inventory, index)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.AddDisplayed(player, item)
	local data = InventoryService.GetData(player)
	if not data then
		return
	end
	table.insert(data.DisplayedSnacks, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
end

function InventoryService.RemoveDisplayedByWorldId(player, worldId)
	local data = InventoryService.GetData(player)
	if not data then
		return
	end
	for index, item in ipairs(data.DisplayedSnacks) do
		if item.WorldId == worldId then
			table.remove(data.DisplayedSnacks, index)
			InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
			InventoryService.Context.Services.EconomyService.Sync(player)
			return item
		end
	end
	return nil
end

return InventoryService
