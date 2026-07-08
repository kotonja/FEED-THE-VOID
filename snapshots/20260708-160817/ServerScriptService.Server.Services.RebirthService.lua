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

function RebirthService.TryRebirth(player)
	local context = RebirthService.Context
	if (context.Config.FeatureFlags or {}).Rebirth == false then
		context.Services.EconomyService.Notify(player, "Rebirth is disabled for this test.")
		return false
	end
	local okProfile, data = context.Services.ValidationService.ValidatePlayerProfile(player)
	if not okProfile then
		return false
	end
	local cost = context.Services.EconomyService.GetRebirthRequirement(player)
	if (data.Coins or 0) < cost then
		context.Services.EconomyService.Notify(player, "Rebirth requires " .. tostring(cost) .. " coins.")
		return false
	end
	local keepCollections = context.Config.GameConfig.RebirthKeepsCollections ~= false
	local keepStats = context.Config.GameConfig.RebirthKeepsStats ~= false
	local collections = keepCollections and data.Collections or nil
	local stats = keepStats and data.Stats or nil
	local badges = data.BadgesAwarded
	context.Services.SnackService.ClearPlotVisuals(player, true)
	context.Services.VoidmiteService.ClearForPlayer(player)
	data.Rebirths = (data.Rebirths or 0) + 1
	data.Coins = context.Config.GameConfig.StartingCoins
	data.Seeds = copyStartingSeeds(context)
	data.Inventory = {}
	data.DisplayedSnacks = {}
	data.PlantedSnacks = {}
	data.Upgrades = {
		Plates = context.Config.GameConfig.PlateCount,
		GrowSpeed = 0,
		SellMultiplier = 0,
		VoidRewardMultiplier = 0,
		DisplayIncome = 0,
		VoidmiteReward = 0,
	}
	if collections then
		data.Collections = collections
	end
	if stats then
		data.Stats = stats
	end
	data.BadgesAwarded = badges or data.BadgesAwarded
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.BadgeAwardService.Award(player, "FirstRebirth")
	if context.Services.AudioService then
		context.Services.AudioService.PlayForAll("Progression.RebirthActivate", "World", context.Services.PlotService.GetStation(player, "RebirthStation") or context.Services.PlotService.GetPlot(player), { MinInterval = 0.6 })
	end
	if context.Services.VFXService then
		context.Services.VFXService.PlayForAll("Rebirth.Activate", {
			Mode = "World",
			Target = context.Services.PlotService.GetStation(player, "RebirthStation") or context.Services.PlotService.GetPlot(player),
			Text = "Rebirth +" .. tostring(data.Rebirths),
			MinInterval = 0.6,
		})
	end
	context.Services.EconomyService.Notify(player, "Rebirth complete. Permanent boost is now +" .. tostring(math.floor(data.Rebirths * context.Config.GameConfig.RebirthBoostPerRebirth * 100)) .. "%.")
	if context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.Rebirth(player, data.Rebirths)
	end
	context.Services.AnalyticsService.Rebirth(player, data.Rebirths)
	context.Services.EconomyService.Sync(player)
	return true
end

return RebirthService
