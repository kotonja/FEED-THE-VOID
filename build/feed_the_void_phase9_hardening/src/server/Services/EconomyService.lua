local Players = game:GetService("Players")

local EconomyService = {}

local function ensureLeaderstats(player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	for _, statName in ipairs({ "Rebirths", "Coins", "VoidTokens" }) do
		if not folder:FindFirstChild(statName) then
			local value = Instance.new("IntValue")
			value.Name = statName
			value.Parent = folder
		end
	end
	return folder
end

local function updateLeaderstats(player, data)
	if not player or not data then
		return
	end
	local folder = ensureLeaderstats(player)
	folder.Rebirths.Value = math.floor(tonumber(data.Rebirths) or 0)
	folder.Coins.Value = math.floor(tonumber(data.Coins) or 0)
	folder.VoidTokens.Value = math.floor(tonumber(data.VoidTokens) or 0)
end

local function copyDictionary(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

function EconomyService.Init(context)
	EconomyService.Context = context
end

function EconomyService.Start() end

function EconomyService.GetData(player)
	return EconomyService.Context.Services.ProfileServiceWrapper.GetData(player)
end

function EconomyService.ComputeItemValues(player, item)
	if not item then
		return 0, 0, 0
	end
	local context = EconomyService.Context
	local snack = context.Config.SnackConfig[item.SnackId]
	local mutation = context.Config.MutationConfig[item.MutationId or "Normal"] or context.Config.MutationConfig.Normal
	if not snack or not mutation then
		return 0, 0, 0
	end
	local sellMultiplier = player and context.Services.UpgradeService.GetMultiplier(player, "SellMultiplier") or 1
	local voidMultiplier = player and context.Services.UpgradeService.GetMultiplier(player, "VoidRewardMultiplier") or 1
	local displayMultiplier = player and context.Services.UpgradeService.GetMultiplier(player, "DisplayIncome") or 1
	local rarity = context.Config.RarityConfig and context.Config.RarityConfig[snack.Rarity]
	local passiveRarityMultiplier = rarity and rarity.PassiveIncomeMultiplier or 1
	local mutationMultiplier = item.ValueMultiplier or mutation.ValueMultiplier or 1
	local sellValue = math.max(1, math.floor(snack.BaseSellValue * mutationMultiplier * sellMultiplier))
	local voidValue = math.max(1, math.floor(snack.BaseVoidValue * mutationMultiplier * voidMultiplier))
	local passiveIncome = math.max(1, math.floor((snack.BaseSellValue * mutationMultiplier * displayMultiplier * passiveRarityMultiplier) / 10))
	return sellValue, voidValue, passiveIncome
end

function EconomyService.GetSellValue(player, item)
	return select(1, EconomyService.ComputeItemValues(player, item))
end

function EconomyService.GetVoidValue(player, item)
	return select(2, EconomyService.ComputeItemValues(player, item))
end

function EconomyService.GetPassiveIncome(player, displayedItem)
	return select(3, EconomyService.ComputeItemValues(player, displayedItem))
end

function EconomyService.GetUpgradeCost(player, upgradeId)
	return EconomyService.Context.Services.UpgradeService.GetCost(player, upgradeId)
end

function EconomyService.GetRebirthRequirement(player)
	local config = EconomyService.Context.Config.GameConfig
	local base = tonumber(config.RebirthRequirement or config.RebirthCost) or 5000
	local data = player and EconomyService.GetData(player)
	local rebirths = data and tonumber(data.Rebirths) or 0
	return math.floor(base * (1 + (rebirths * 0.35)))
end

function EconomyService.SerializeItem(player, item)
	if not item then
		return nil
	end
	local sellValue, voidValue, passiveIncome = EconomyService.ComputeItemValues(player, item)
	local snack = EconomyService.Context.Config.SnackConfig[item.SnackId]
	local mutation = EconomyService.Context.Config.MutationConfig[item.MutationId or "Normal"]
	local copy = copyDictionary(item)
	copy.DisplayName = item.DisplayName or ((mutation and mutation.DisplayName ~= "Normal" and mutation.DisplayName .. " " or "") .. (snack and snack.DisplayName or item.SnackId))
	copy.SnackName = snack and snack.DisplayName or item.SnackId
	copy.Rarity = snack and snack.Rarity or "Common"
	copy.RaritySortOrder = EconomyService.Context.Config.RarityConfig and EconomyService.Context.Config.RarityConfig.GetSortOrder(copy.Rarity) or 999
	copy.MutationName = mutation and mutation.DisplayName or item.MutationId or "Normal"
	copy.EstimatedSellValue = sellValue
	copy.EstimatedVoidValue = voidValue
	copy.PassiveIncome = passiveIncome
	copy.Locked = item.Locked == true
	return copy
end

function EconomyService.BuildSnapshot(player)
	local data = EconomyService.GetData(player)
	if not data then
		return nil
	end
	local inventory = {}
	for _, item in ipairs(data.Inventory or {}) do
		table.insert(inventory, EconomyService.SerializeItem(player, item))
	end
	local displayed = {}
	for _, item in ipairs(data.DisplayedSnacks or {}) do
		table.insert(displayed, EconomyService.SerializeItem(player, item))
	end
	local shopSnapshot = EconomyService.Context.Services.ShopService and EconomyService.Context.Services.ShopService.Serialize(player) or {}
	return {
		DataVersion = data.DataVersion or 1,
		Coins = data.Coins or 0,
		VoidTokens = data.VoidTokens or 0,
		Rebirths = data.Rebirths or 0,
		AssignedPlotId = (EconomyService.Context.Services.PlotService and EconomyService.Context.Services.PlotService.GetPlotId(player)) or data.AssignedPlotId or 0,
		Seeds = copyDictionary(data.Seeds or {}),
		Inventory = inventory,
		DisplayedSnacks = displayed,
		PlantedSnacks = data.PlantedSnacks or {},
		Upgrades = EconomyService.Context.Services.UpgradeService.Serialize(player),
		RebirthRequirement = EconomyService.GetRebirthRequirement(player),
		Collections = EconomyService.Context.Services.CollectionService.Serialize(player),
		Quests = EconomyService.Context.Services.QuestService.Serialize(player),
		TutorialStep = data.TutorialStep or 1,
		TutorialCompleted = data.TutorialCompleted == true,
		Stats = EconomyService.Context.Services.StatsService and EconomyService.Context.Services.StatsService.Serialize(player) or data.Stats,
		DailyReward = EconomyService.Context.Services.DailyRewardService and EconomyService.Context.Services.DailyRewardService.Serialize(player) or data.DailyReward,
		PlaytimeRewards = EconomyService.Context.Services.PlaytimeRewardService and EconomyService.Context.Services.PlaytimeRewardService.Serialize(player) or data.PlaytimeRewards,
		BadgesAwarded = EconomyService.Context.Services.BadgeAwardService and EconomyService.Context.Services.BadgeAwardService.Serialize(player) or data.BadgesAwarded,
		Settings = EconomyService.Context.Services.SettingsService and EconomyService.Context.Services.SettingsService.Serialize(player) or data.Settings,
		ShopStock = shopSnapshot.Stock or {},
		ShopRestockEndsAt = shopSnapshot.RestockEndsAt or 0,
		ShopUnlocks = shopSnapshot.Unlocks or {},
		VoidHunger = EconomyService.Context.Services.VoidService.GetHunger(),
		VoidHungerRequired = EconomyService.Context.Services.VoidService.GetRequired(),
		ActiveEventName = EconomyService.Context.Services.EventService.GetActiveEventName(),
		ActiveEventEndsAt = EconomyService.Context.Services.EventService.GetActiveEventEndsAt(),
		GoldenHungerSnackId = EconomyService.Context.Services.EventService.GetGoldenHungerSnackId(),
		NextGoal = EconomyService.Context.Services.OnboardingService and EconomyService.Context.Services.OnboardingService.GetNextGoal(player) or nil,
		LastOfflineRewards = data.LastOfflineRewards,
	}
end

function EconomyService.Sync(player)
	local data = EconomyService.GetData(player)
	updateLeaderstats(player, data)
	local snapshot = EconomyService.BuildSnapshot(player)
	if snapshot then
		EconomyService.Context.Remotes.SyncPlayerData:FireClient(player, snapshot)
	end
end

function EconomyService.SyncAll()
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.Sync(player)
	end
end

function EconomyService.Notify(player, message)
	if player and message then
		EconomyService.Context.Remotes.NotifyClient:FireClient(player, tostring(message))
	end
end

function EconomyService.NotifyAll(message)
	if message then
		EconomyService.Context.Remotes.NotifyClient:FireAllClients(tostring(message))
	end
end

function EconomyService.AddCoins(player, amount)
	local data = EconomyService.GetData(player)
	if not data then
		return false
	end
	data.Coins += math.max(0, math.floor(amount or 0))
	if EconomyService.Context.Services.StatsService then
		EconomyService.Context.Services.StatsService.RecordCoinsEarned(player, amount)
	end
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.SpendCoins(player, amount)
	local data = EconomyService.GetData(player)
	amount = math.max(0, math.floor(amount or 0))
	if not data or (data.Coins or 0) < amount then
		return false
	end
	data.Coins -= amount
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.AddVoidTokens(player, amount)
	local data = EconomyService.GetData(player)
	if not data then
		return false
	end
	data.VoidTokens += math.max(0, math.floor(amount or 0))
	if EconomyService.Context.Services.StatsService then
		EconomyService.Context.Services.StatsService.RecordVoidTokensEarned(player, amount)
	end
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.AddSeeds(player, snackId, amount, notify)
	local data = EconomyService.GetData(player)
	local snack = EconomyService.Context.Config.SnackConfig[snackId]
	if not data or not snack then
		return false
	end
	data.Seeds[snackId] = (data.Seeds[snackId] or 0) + math.max(0, math.floor(amount or 0))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	if notify ~= false then
		EconomyService.Notify(player, "+" .. tostring(amount) .. " " .. snack.DisplayName .. " seed.")
	end
	EconomyService.Sync(player)
	return true
end

return EconomyService
