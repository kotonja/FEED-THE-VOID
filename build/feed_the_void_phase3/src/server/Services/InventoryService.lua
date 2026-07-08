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
		return nil
	end
	item.UniqueId = item.UniqueId or HttpService:GenerateGUID(false)
	table.insert(data.DisplayedSnacks, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.ClearInventory(player)
	local data = InventoryService.GetData(player)
	if data then
		data.Inventory = {}
		InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
end

function InventoryService.ClearDisplayed(player)
	local data = InventoryService.GetData(player)
	if data then
		data.DisplayedSnacks = {}
		InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
end

return InventoryService
