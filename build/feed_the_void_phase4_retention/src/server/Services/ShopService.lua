local ShopService = {}

local stock = {}
local restockEndsAt = 0

function ShopService.Init(context)
	ShopService.Context = context
end

local function contains(list, value)
	for _, item in ipairs(list or {}) do
		if item == value then
			return true
		end
	end
	return false
end

local function restock()
	local context = ShopService.Context
	local always = context.Config.GameConfig.ShopAlwaysAvailableSeeds or { "CookieRock" }
	local rotating = context.Config.GameConfig.ShopRotatingSeeds or {}
	stock = {}
	for _, seedId in ipairs(always) do
		if context.Config.SnackConfig[seedId] then
			stock[seedId] = true
		end
	end
	if #rotating > 0 then
		local start = math.random(1, #rotating)
		for offset = 0, math.min(2, #rotating - 1) do
			local seedId = rotating[((start + offset - 1) % #rotating) + 1]
			if context.Config.SnackConfig[seedId] then
				stock[seedId] = true
			end
		end
	end
	restockEndsAt = os.time() + (context.Config.GameConfig.ShopRestockInterval or 300)
end

local function ensureStock()
	if os.time() >= restockEndsAt or next(stock) == nil then
		restock()
	end
end

local function discoveries(data)
	local count = 0
	for _, unlocked in pairs(data.Collections and data.Collections.Snacks or {}) do
		if unlocked then
			count += 1
		end
	end
	return count
end

function ShopService.Start()
	restock()
	task.spawn(function()
		while true do
			task.wait(5)
			if os.time() >= restockEndsAt then
				restock()
				ShopService.Context.Services.EconomyService.SyncAll()
			end
		end
	end)
end

function ShopService.IsUnlocked(player, snackId)
	local context = ShopService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local snack = context.Config.SnackConfig[snackId]
	if not data or not snack then
		return false, "Unavailable"
	end
	if contains(context.Config.GameConfig.ShopAlwaysAvailableSeeds, snackId) then
		return true
	end
	if snack.Rarity == "Common" then
		return true
	end
	local stats = data.Stats or {}
	if snack.Rarity == "Uncommon" then
		return (stats.SnacksHarvested or 0) >= 3 or ((data.Quests and data.Quests.CompletedCount) or 0) >= 1
	end
	if snack.Rarity == "Rare" then
		return (data.Rebirths or 0) >= 1 or discoveries(data) >= 10 or (data.Coins or 0) >= snack.SeedCost * 2
	end
	return false, "Unlock later"
end

function ShopService.Serialize(player)
	ensureStock()
	local result = {}
	for _, seedId in ipairs(ShopService.Context.Config.SnackConfig.Order) do
		local unlocked, reason = ShopService.IsUnlocked(player, seedId)
		table.insert(result, {
			Id = seedId,
			InStock = stock[seedId] == true,
			Unlocked = unlocked == true,
			LockedReason = reason,
		})
	end
	return {
		Stock = result,
		RestockEndsAt = restockEndsAt,
	}
end

function ShopService.BuySeed(player, snackId)
	local context = ShopService.Context
	ensureStock()
	local okProfile, data = context.Services.ValidationService.ValidatePlayerProfile(player)
	local snack = context.Config.SnackConfig[snackId]
	if not okProfile or not snack then
		context.Services.EconomyService.Notify(player, "That seed is not available.")
		return false
	end
	local unlocked = ShopService.IsUnlocked(player, snackId)
	if not stock[snackId] or not unlocked then
		context.Services.EconomyService.Notify(player, "That seed is locked until a later restock or milestone.")
		return false
	end
	local station = context.Services.PlotService.GetStation(player, "SeedShopStation")
	if station and not context.Services.ValidationService.ValidateDistance(player, station, 34) then
		context.Services.EconomyService.Notify(player, "Stand near your Seed Shop to buy seeds.")
		return false
	end
	if not context.Services.EconomyService.SpendCoins(player, snack.SeedCost) then
		context.Services.EconomyService.Notify(player, "Not enough coins for " .. snack.DisplayName .. ".")
		return false
	end
	data.Seeds[snackId] = (data.Seeds[snackId] or 0) + 1
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.QuestService.Record(player, "BuySeed", 1)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Bought 1 " .. snack.DisplayName .. " seed.")
	return true
end

return ShopService
