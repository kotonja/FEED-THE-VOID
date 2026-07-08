local ShopService = {}

function ShopService.Init(context)
	ShopService.Context = context
end

function ShopService.Start() end

function ShopService.BuySeed(player, snackId)
	local context = ShopService.Context
	local okProfile, data = context.Services.ValidationService.ValidatePlayerProfile(player)
	local snack = context.Config.SnackConfig[snackId]
	if not okProfile or not snack then
		context.Services.EconomyService.Notify(player, "That seed is not available.")
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
