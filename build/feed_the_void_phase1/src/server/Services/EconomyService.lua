local EconomyService = {}

function EconomyService.Init(context)
	EconomyService.Context = context
end

function EconomyService.Start() end

function EconomyService.GetData(player)
	return EconomyService.Context.Services.ProfileServiceWrapper.GetData(player)
end

function EconomyService.Sync(player)
	local data = EconomyService.GetData(player)
	if not data then
		return
	end
	EconomyService.Context.Remotes.SyncPlayerData:FireClient(player, {
		Coins = data.Coins,
		VoidTokens = data.VoidTokens,
		Rebirths = data.Rebirths,
		Seeds = data.Seeds,
		Inventory = data.Inventory,
		DisplayedSnacks = data.DisplayedSnacks,
		Upgrades = data.Upgrades,
		VoidHunger = EconomyService.Context.Services.VoidService.GetHunger(),
		VoidHungerRequired = EconomyService.Context.Config.GameConfig.VoidHungerRequired,
	})
end

function EconomyService.SyncAll()
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		EconomyService.Sync(player)
	end
end

function EconomyService.Notify(player, message)
	if player then
		EconomyService.Context.Remotes.NotifyClient:FireClient(player, message)
	end
end

function EconomyService.NotifyAll(message)
	EconomyService.Context.Remotes.NotifyClient:FireAllClients(message)
end

function EconomyService.AddCoins(player, amount)
	local data = EconomyService.GetData(player)
	if not data then
		return false
	end
	data.Coins += math.max(0, math.floor(amount))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.SpendCoins(player, amount)
	local data = EconomyService.GetData(player)
	amount = math.max(0, math.floor(amount))
	if not data or data.Coins < amount then
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
	data.VoidTokens += math.max(0, math.floor(amount))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

return EconomyService
