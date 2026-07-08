local ShopService = {}

local stock = {}
local restockEndsAt = 0
local unlockedAllForSession = {}

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

local function snackTypesDiscovered(data)
	local count = 0
	for _, unlocked in pairs(data.Collections and data.Collections.Snacks or {}) do
		if unlocked then
			count += 1
		end
	end
	return count
end

local function buyableSeedIds()
	local context = ShopService.Context
	local result = {}
	for _, seedId in ipairs(context.Config.SnackConfig.Order or {}) do
		local snack = context.Config.SnackConfig[seedId]
		if snack and snack.Buyable ~= false and snack.SeedCost ~= nil then
			table.insert(result, seedId)
		end
	end
	return result
end

local function restock()
	local context = ShopService.Context
	local always = context.Config.GameConfig.ShopAlwaysAvailableSeeds or { "CookieRock" }
	local rotating = context.Config.GameConfig.ShopRotatingSeeds or buyableSeedIds()
	stock = {}
	for _, seedId in ipairs(always) do
		local snack = context.Config.SnackConfig[seedId]
		if snack and snack.Buyable ~= false then
			stock[seedId] = true
		end
	end
	if #rotating > 0 then
		local start = math.random(1, #rotating)
		for offset = 0, math.min(4, #rotating - 1) do
			local seedId = rotating[((start + offset - 1) % #rotating) + 1]
			local snack = context.Config.SnackConfig[seedId]
			if snack and snack.Buyable ~= false and snack.SeedCost ~= nil then
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

function ShopService.Start()
	restock()
	task.spawn(function()
		while true do
			task.wait((ShopService.Context.Config.GameConfig.Performance or {}).ShopRestockPollInterval or 10)
			if os.time() >= restockEndsAt then
				restock()
				ShopService.Context.Services.EconomyService.SyncAll()
			end
		end
	end)
end

function ShopService.UnlockAllForSession(player)
	if not player then
		return false
	end
	unlockedAllForSession[player.UserId] = true
	ShopService.Context.Services.EconomyService.Sync(player)
	ShopService.Context.Services.EconomyService.Notify(player, "Debug: shop tiers unlocked for this session.")
	return true
end

function ShopService.IsUnlocked(player, snackId)
	local context = ShopService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local snack = context.Config.SnackConfig[snackId]
	if not data or not snack then
		return false, "Unavailable"
	end
	if snack.Buyable == false or snack.SeedCost == nil then
		return false, snack.UnlockRequirement or "Secret reward only"
	end
	if unlockedAllForSession[player.UserId] then
		return true
	end
	if contains(context.Config.GameConfig.ShopAlwaysAvailableSeeds, snackId) or snack.Rarity == "Common" then
		return true
	end
	local stats = data.Stats or {}
	local completedQuests = (data.Quests and data.Quests.CompletedCount) or 0
	local snacksFound = snackTypesDiscovered(data)
	local discoveries = (stats.Discoveries or 0)
	if snack.Rarity == "Uncommon" then
		return (stats.SnacksHarvested or 0) >= 3 or completedQuests >= 1, "Harvest 3 snacks or complete 1 quest"
	end
	if snack.Rarity == "Rare" then
		return (stats.SnacksHarvested or 0) >= 10 or snacksFound >= 5 or (data.Rebirths or 0) >= 1, "Harvest 10 snacks, discover 5 snacks, or reach Rebirth 1"
	end
	if snack.Rarity == "Epic" then
		return (data.Rebirths or 0) >= 1 or discoveries >= 25, "Reach Rebirth 1 or make 25 discoveries"
	end
	if snack.Rarity == "Legendary" then
		return (data.Rebirths or 0) >= 2 or discoveries >= 50, "Reach Rebirth 2 or make 50 discoveries"
	end
	return false, snack.UnlockRequirement or "Locked"
end

function ShopService.Serialize(player)
	ensureStock()
	local result = {}
	local unlocks = {}
	for _, seedId in ipairs(ShopService.Context.Config.SnackConfig.Order) do
		local snack = ShopService.Context.Config.SnackConfig[seedId]
		local unlocked, reason = ShopService.IsUnlocked(player, seedId)
		if snack then
			unlocks[seedId] = unlocked == true
			table.insert(result, {
				Id = seedId,
				InStock = stock[seedId] == true,
				Unlocked = unlocked == true,
				LockedReason = unlocked and "" or (reason or snack.UnlockRequirement or "Locked"),
				Buyable = snack.Buyable ~= false and snack.SeedCost ~= nil,
				Rarity = snack.Rarity,
				SeedCost = snack.SeedCost,
			})
		end
	end
	return {
		Stock = result,
		Unlocks = unlocks,
		RestockEndsAt = restockEndsAt,
	}
end

function ShopService.BuySeed(player, snackId)
	local context = ShopService.Context
	ensureStock()
	local okProfile, data = context.Services.ValidationService.ValidatePlayerProfile(player)
	local snack = context.Config.SnackConfig[snackId]
	if not okProfile or not snack or snack.Buyable == false or snack.SeedCost == nil then
		context.Services.EconomyService.Notify(player, "That seed is not available.")
		return false
	end
	local unlocked, reason = ShopService.IsUnlocked(player, snackId)
	if not stock[snackId] or not unlocked then
		context.Services.EconomyService.Notify(player, reason or "That seed is locked until a later restock or milestone.")
		return false
	end
	local station = context.Services.PlotService.GetStation(player, "SeedShopStation")
	if station and not context.Services.ValidationService.ValidateDistance(player, station, (context.Config.GameConfig.InteractionDistances or {}).Shop or 18) then
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
	if context.Services.AudioService then
		context.Services.AudioService.PlayUI(player, "Economy.Buy")
	end
	if context.Services.VFXService then
		context.Services.VFXService.PlayForPlayer(player, "Economy.Buy", {
			Mode = "UI",
			Text = "Seed bought!",
			SnackId = snackId,
		})
	end
	context.Services.EconomyService.Notify(player, "Bought 1 " .. snack.DisplayName .. " seed.")
	return true
end

return ShopService
