local RebirthService = {}

function RebirthService.Init(context)
	RebirthService.Context = context
end

function RebirthService.Start() end

function RebirthService.TryRebirth(player)
	local context = RebirthService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	local cost = context.Config.GameConfig.RebirthCost
	if data.Coins < cost then
		context.Services.EconomyService.Notify(player, "Rebirth requires " .. tostring(cost) .. " coins.")
		return false
	end
	data.Coins = context.Config.GameConfig.StartingCoins
	data.Inventory = {}
	data.DisplayedSnacks = {}
	data.Rebirths += 1
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Phase 1 rebirth complete. Multipliers come later.")
	return true
end

return RebirthService
