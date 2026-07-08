local OnboardingService = {}

function OnboardingService.Init(context)
	OnboardingService.Context = context
end

function OnboardingService.Start() end

local function countInventory(data)
	return #(data.Inventory or {})
end

local function hasSeeds(data)
	for _, count in pairs(data.Seeds or {}) do
		if (tonumber(count) or 0) > 0 then
			return true
		end
	end
	return false
end

local function firstReadyPlaytime(context, player)
	return context.Services.PlaytimeRewardService and context.Services.PlaytimeRewardService.GetClaimable(player) ~= nil
end

function OnboardingService.GetNextGoal(player)
	local context = OnboardingService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return { Text = "Loading your snack lab...", Kind = "Loading" }
	end
	if context.Services.DailyRewardService then
		local canDaily = context.Services.DailyRewardService.CanClaim(player)
		if canDaily then
			return { Text = "Claim your daily chest", Kind = "DailyReward" }
		end
	end
	if firstReadyPlaytime(context, player) then
		return { Text = "Claim your playtime reward", Kind = "PlaytimeReward" }
	end
	if context.Services.EventService.GetActiveEventName() then
		if context.Services.EventService.GetActiveEventName() == "PhantomSnackChase" then
			return { Text = "Catch the Phantom Snacks", Kind = "Event" }
		end
		return { Text = "Join the active Void event", Kind = "Event" }
	end
	if not hasSeeds(data) then
		return { Text = "Buy Cookie Rock seeds", Kind = "Shop" }
	end
	local active = data.Quests and data.Quests.Active and data.Quests.Active[1]
	if active and (active.Progress or 0) < (active.Target or 1) then
		return { Text = "Objective: " .. active.Text, Kind = "Quest" }
	end
	if countInventory(data) > 0 and #(data.DisplayedSnacks or {}) == 0 then
		return { Text = "Display a snack for passive coins", Kind = "Display" }
	end
	if countInventory(data) > 0 then
		return { Text = "Feed The Void", Kind = "FeedVoid" }
	end
	local stats = data.Stats or {}
	if (stats.SnacksHarvested or 0) == 0 then
		return { Text = "Plant a Cookie Rock", Kind = "Plant" }
	end
	local upgradeCost = context.Services.UpgradeService.GetCost(player, "GrowSpeed")
	if (data.Coins or 0) >= upgradeCost then
		return { Text = "Buy your first upgrade", Kind = "Upgrade" }
	end
	return { Text = "Grow another snack", Kind = "Plant" }
end

return OnboardingService
