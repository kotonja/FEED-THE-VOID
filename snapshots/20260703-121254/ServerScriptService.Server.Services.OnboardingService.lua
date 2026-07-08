local OnboardingService = {}

local temporaryGoals = {}

function OnboardingService.Init(context)
	OnboardingService.Context = context
end

function OnboardingService.Start() end

local function countInventory(data)
	return #(data.Inventory or {})
end

local function totalSeeds(data)
	local total = 0
	for _, count in pairs(data.Seeds or {}) do
		total += math.max(0, tonumber(count) or 0)
	end
	return total
end

local function hasSeeds(data)
	return totalSeeds(data) > 0
end

local function countPlanted(data)
	return #(data.PlantedSnacks or {})
end

local function plantedReadyCount(data)
	local now = os.time()
	local ready = 0
	for _, record in ipairs(data.PlantedSnacks or {}) do
		local stage = tonumber(record.CurrentStage) or 1
		local plantedAt = tonumber(record.PlantedAt) or now
		local growTime = math.max(1, tonumber(record.GrowTime) or 1)
		if stage >= 3 or now - plantedAt >= growTime then
			ready += 1
		end
	end
	return ready
end

local function plotIdFor(player)
	local plot = OnboardingService.Context.Services.PlotService and OnboardingService.Context.Services.PlotService.GetPlot(player)
	if not plot then
		return 0
	end
	return tonumber(plot:GetAttribute("PlotId")) or 0
end

local function goal(player, id, text, targetType, priority, extra)
	local result = {
		Id = id,
		Text = text,
		TargetType = targetType,
		Kind = targetType,
		TargetPlotId = plotIdFor(player),
		Priority = priority or 100,
	}
	for key, value in pairs(extra or {}) do
		result[key] = value
	end
	return result
end

local function firstReadyPlaytime(context, player)
	return context.Services.PlaytimeRewardService and context.Services.PlaytimeRewardService.GetClaimable(player) ~= nil
end

local function starterSeedCost(context)
	local seedId = context.Config.GameConfig.Failsafes and context.Config.GameConfig.Failsafes.EmergencySeedId or "CookieRock"
	local snack = context.Config.SnackConfig[seedId]
	return snack and tonumber(snack.SeedCost) or 25
end

local function activeVoidmiteForPlayer(player)
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("ActiveVoidmites")
	if not folder then
		return false
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("OwnerUserId")) == player.UserId then
			return true
		end
	end
	return false
end

local function tutorialGoal(context, player, data)
	local step = tonumber(data.TutorialStep) or 1
	local invCount = countInventory(data)
	local readyCount = plantedReadyCount(data)
	local plantedCount = countPlanted(data)
	local plateCount = context.Services.UpgradeService.GetPlateCount(player)
	local coins = tonumber(data.Coins) or 0
	if step <= 2 then
		if hasSeeds(data) and plantedCount < plateCount then
			return goal(player, "TutorialPlant", "Plant a seed on an empty plate", "Plate", 100)
		end
		if coins >= starterSeedCost(context) then
			return goal(player, "TutorialBuySeed", "Buy Cookie Rock seeds", "Shop", 100)
		end
		return goal(player, "TutorialFindLab", "Follow the guide to your lab", "Plot", 100)
	end
	if step == 3 then
		if readyCount > 0 then
			return goal(player, "TutorialHarvest", "Harvest the ready snack", "ReadyPlate", 100)
		end
		if plantedCount > 0 then
			return goal(player, "TutorialWaitGrow", "Stay near your growing snack", "Plate", 100)
		end
		return goal(player, "TutorialPlantAgain", "Plant a seed on an empty plate", "Plate", 100)
	end
	if step == 4 then
		if readyCount > 0 then
			return goal(player, "TutorialHarvest", "Harvest the ready snack", "ReadyPlate", 100)
		end
		return goal(player, "TutorialWaitGrow", "Wait for the snack to finish growing", "Plate", 100)
	end
	if step == 5 then
		if invCount > 0 then
			return goal(player, "TutorialFeedVoid", "Feed a snack to The Void", "FeedVoid", 100)
		end
		return readyCount > 0 and goal(player, "TutorialHarvestFirst", "Harvest a snack first", "ReadyPlate", 100) or goal(player, "TutorialGrowFirst", "Grow a snack first", "Plate", 100)
	end
	if step == 6 then
		if invCount > 0 then
			return goal(player, "TutorialDisplay", "Display a snack on your shelf", "Display", 100)
		end
		return goal(player, "TutorialGetDisplaySnack", "Harvest another snack to display", readyCount > 0 and "ReadyPlate" or "Plate", 100)
	end
	if step == 7 then
		if activeVoidmiteForPlayer(player) then
			return goal(player, "TutorialCleanse", "Cleanse the Voidmite near your shelf", "Voidmite", 100)
		end
		return goal(player, "TutorialKeepDisplay", "Keep snacks displayed for coins", "Display", 90)
	end
	if step == 8 then
		return goal(player, "TutorialUpgrade", "Buy your first lab upgrade", "Upgrade", 100)
	end
	if step == 9 then
		return goal(player, "TutorialObjective", "Complete an objective", "Objectives", 100)
	end
	return goal(player, "TutorialVoidEvents", "Feed The Void to start server events", "FeedVoid", 80)
end

function OnboardingService.SetTemporaryGoal(player, goalData)
	if not player or type(goalData) ~= "table" then
		return
	end
	temporaryGoals[player] = {
		ExpiresAt = os.clock() + 12,
		Goal = goalData,
	}
end

function OnboardingService.ClearTemporaryGoal(player)
	temporaryGoals[player] = nil
end

function OnboardingService.GetNextGoal(player)
	local context = OnboardingService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return { Id = "Loading", Text = "Loading your snack lab...", TargetType = "Plot", Kind = "Plot", Priority = 999 }
	end

	local temporary = temporaryGoals[player]
	if temporary and temporary.ExpiresAt > os.clock() then
		local tempGoal = table.clone(temporary.Goal)
		tempGoal.TargetPlotId = tempGoal.TargetPlotId or plotIdFor(player)
		tempGoal.Kind = tempGoal.Kind or tempGoal.TargetType
		return tempGoal
	end
	if temporary then
		temporaryGoals[player] = nil
	end

	if not context.Services.PlotService.GetPlot(player) then
		return goal(player, "FindLab", "Find your lab", "Plot", 120)
	end

	if not data.TutorialCompleted then
		return tutorialGoal(context, player, data)
	end

	if context.Services.DailyRewardService then
		local canDaily = context.Services.DailyRewardService.CanClaim(player)
		if canDaily then
			return goal(player, "ClaimDaily", "Claim your daily chest", "DailyReward", 90)
		end
	end

	if firstReadyPlaytime(context, player) then
		return goal(player, "ClaimPlaytime", "Claim your playtime reward", "Rewards", 85)
	end

	local activeEventName = context.Services.EventService.GetActiveEventName()
	if activeEventName then
		if activeEventName == "PhantomSnackChase" then
			return goal(player, "CatchPhantoms", "Catch the Phantom Snacks", "Event", 82)
		end
		if activeEventName == "VoidInfestation" then
			return goal(player, "CleanseInfestation", "Cleanse Voidmites during the event", "Voidmite", 82)
		end
		return goal(player, "JoinEvent", "Join the active Void event", "FeedVoid", 82)
	end

	local invCount = countInventory(data)
	local readyCount = plantedReadyCount(data)
	local plantedCount = countPlanted(data)
	local plateCount = context.Services.UpgradeService.GetPlateCount(player)
	local active = data.Quests and data.Quests.Active and data.Quests.Active[1]

	if readyCount > 0 then
		return goal(player, "HarvestReady", "Harvest your ready snack", "ReadyPlate", 78)
	end
	if invCount > 0 and #(data.DisplayedSnacks or {}) == 0 then
		return goal(player, "DisplaySnack", "Display a snack for passive coins", "Display", 74)
	end
	if invCount > 0 then
		return goal(player, "FeedVoid", "Feed The Void", "FeedVoid", 72)
	end
	if not hasSeeds(data) then
		if (data.Coins or 0) >= starterSeedCost(context) then
			return goal(player, "BuySeeds", "Buy Cookie Rock seeds", "Shop", 70)
		end
		return goal(player, "EarnCoins", "Earn coins from displayed snacks or rewards", "Display", 65)
	end
	if plantedCount >= plateCount then
		return goal(player, "PlatesFull", "All plates are growing. Wait or harvest a ready snack", "Plate", 68)
	end
	if active and (active.Progress or 0) < (active.Target or 1) then
		return goal(player, "Objective", "Objective: " .. active.Text, "Objectives", 64)
	end
	local upgradeCost = context.Services.UpgradeService.GetCost(player, "GrowSpeed")
	if (data.Coins or 0) >= upgradeCost then
		return goal(player, "BuyUpgrade", "Buy a lab upgrade", "Upgrade", 62)
	end
	return goal(player, "PlantSnack", "Plant another snack", "Plate", 60)
end

return OnboardingService
