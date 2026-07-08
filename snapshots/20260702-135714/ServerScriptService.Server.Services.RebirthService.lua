local RebirthService = {}

function RebirthService.Init(context)
	RebirthService.Context = context
end

function RebirthService.Start() end

local function copyStartingSeeds(context)
	local seeds = {}
	for seedId, count in pairs(context.Config.GameConfig.StartingSeeds) do
		seeds[seedId] = count
	end
	return seeds
end

local function isNearRebirthStation(context, player)
	local station = context.Services.PlotService.GetStation(player, "RebirthStation")
	if not station then
		return true
	end
	if not context.Services.ValidationService.ValidateDistance(player, station, 30) then
		context.Services.EconomyService.Notify(player, "Stand near your Rebirth Station to rebirth.")
		return false
	end
	return true
end

function RebirthService.TryRebirth(player)
	local context = RebirthService.Context
	local okProfile, data = context.Services.ValidationService.ValidatePlayerProfile(player)
	if not okProfile then
		return false
	end
	local cost = context.Config.GameConfig.RebirthRequirement or context.Config.GameConfig.RebirthCost
	if (data.Coins or 0) < cost then
		context.Services.EconomyService.Notify(player, "Rebirth requires " .. tostring(cost) .. " coins.")
		return false
	end
	if not isNearRebirthStation(context, player) then
		return false
	end
	context.Services.SnackService.ClearPlotVisuals(player)
	context.Services.VoidmiteService.ClearForPlayer(player)
	data.Rebirths = (data.Rebirths or 0) + 1
	data.Coins = context.Config.GameConfig.StartingCoins
	data.Seeds = copyStartingSeeds(context)
	data.Inventory = {}
	data.DisplayedSnacks = {}
	data.Upgrades = {
		Plates = context.Config.GameConfig.PlateCount,
		GrowSpeed = 0,
		SellMultiplier = 0,
		VoidRewardMultiplier = 0,
		DisplayIncome = 0,
		VoidmiteReward = 0,
	}
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.BadgeAwardService.Award(player, "FirstRebirth")
	context.Services.EconomyService.Notify(player, "Rebirth complete. Permanent boost is now +" .. tostring(math.floor(data.Rebirths * context.Config.GameConfig.RebirthBoostPerRebirth * 100)) .. "%.")
	if context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.Rebirth(player, data.Rebirths)
	end
	context.Services.AnalyticsService.Rebirth(player, data.Rebirths)
	context.Services.EconomyService.Sync(player)
	return true
end

return RebirthService
