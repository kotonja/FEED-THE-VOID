local ShopService = {}

function ShopService.Init(context)
	ShopService.Context = context
end

function ShopService.Start() end

function ShopService.BuySeed(player, snackId)
	local context = ShopService.Context
	local snack = context.Config.SnackConfig[snackId]
	if not snack then
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	if not context.Services.EconomyService.SpendCoins(player, snack.SeedCost) then
		context.Services.EconomyService.Notify(player, "Not enough coins for " .. snack.DisplayName .. " seed.")
		return false
	end
	data.Seeds[snackId] = (data.Seeds[snackId] or 0) + 1
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Bought 1 " .. snack.DisplayName .. " seed.")
	return true
end

return ShopService
