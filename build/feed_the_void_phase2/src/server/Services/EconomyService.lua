local Players = game:GetService("Players")

local EconomyService = {}

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
	local mutationMultiplier = item.ValueMultiplier or mutation.ValueMultiplier or 1
	local sellValue = math.max(1, math.floor(snack.BaseSellValue * mutationMultiplier * sellMultiplier))
	local voidValue = math.max(1, math.floor(snack.BaseVoidValue * mutationMultiplier * voidMultiplier))
	local passiveIncome = math.max(1, math.floor((snack.BaseSellValue * mutationMultiplier * displayMultiplier) / 10))
	return sellValue, voidValue, passiveIncome
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
	copy.MutationName = mutation and mutation.DisplayName or item.MutationId or "Normal"
	copy.EstimatedSellValue = sellValue
	copy.EstimatedVoidValue = voidValue
	copy.PassiveIncome = passiveIncome
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
	return {
		Coins = data.Coins or 0,
		VoidTokens = data.VoidTokens or 0,
		Rebirths = data.Rebirths or 0,
		Seeds = copyDictionary(data.Seeds or {}),
		Inventory = inventory,
		DisplayedSnacks = displayed,
		Upgrades = EconomyService.Context.Services.UpgradeService.Serialize(player),
		Collections = EconomyService.Context.Services.CollectionService.Serialize(player),
		Quests = EconomyService.Context.Services.QuestService.Serialize(player),
		TutorialStep = data.TutorialStep or 1,
		VoidHunger = EconomyService.Context.Services.VoidService.GetHunger(),
		VoidHungerRequired = EconomyService.Context.Services.VoidService.GetRequired(),
		ActiveEventName = EconomyService.Context.Services.EventService.GetActiveEventName(),
		ActiveEventEndsAt = EconomyService.Context.Services.EventService.GetActiveEventEndsAt(),
		GoldenHungerSnackId = EconomyService.Context.Services.EventService.GetGoldenHungerSnackId(),
	}
end

function EconomyService.Sync(player)
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
