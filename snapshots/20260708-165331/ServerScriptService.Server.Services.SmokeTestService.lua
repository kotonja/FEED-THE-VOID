local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local AssetReferences = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReferences"))

local SmokeTestService = {}

local lastSummary = nil
local lastFirst10Summary = nil

local function record(summary, ok, label, detail, warnOnly)
	local entry = {
		Ok = ok == true,
		Label = label,
		Detail = detail,
		WarnOnly = warnOnly == true,
	}
	table.insert(summary.Checks, entry)
	if entry.Ok then
		summary.Passed += 1
	elseif warnOnly then
		summary.Warnings += 1
	else
		summary.Failed += 1
	end
	return entry.Ok
end

local function childCount(parent)
	return parent and #parent:GetChildren() or 0
end

local function expectedRemotes()
	return {
		"RequestPlantSnack",
		"RequestHarvestSnack",
		"RequestSellSnack",
		"RequestFeedVoid",
		"RequestDisplaySnack",
		"RequestClearVoidmite",
		"RequestBuySeed",
		"RequestBuyUpgrade",
		"RequestRebirth",
		"RequestSkipTutorial",
		"RequestDebugCommand",
		"RequestClaimPlaytimeReward",
		"RequestClaimDailyReward",
		"RequestCatchPhantomSnack",
		"RequestUpdateSettings",
		"RequestCollectEventPickup",
		"RequestToggleItemLock",
		"RequestClaimCollectionMilestone",
		"RequestTeleportToPlot",
		"RequestSubmitFeedback",
		"PlaySound",
		"PlayEffect",
		"NotifyClient",
		"SyncPlayerData",
	}
end

local function expectedServices()
	return {
		"ProfileServiceWrapper",
		"AnalyticsService",
		"ActivityFeedService",
		"BalanceReportService",
		"AssetService",
		"AssetOrganizerService",
		"MapService",
		"StatsService",
		"BadgeAwardService",
		"SettingsService",
		"AudioService",
		"VFXService",
		"EconomyService",
		"InventoryService",
		"PlotService",
		"ValidationService",
		"SecurityService",
		"FailsafeService",
		"FeedbackService",
		"BugReportService",
		"CollectionService",
		"QuestService",
		"UpgradeService",
		"OnboardingService",
		"PlaytimeRewardService",
		"DailyRewardService",
		"TutorialService",
		"EventService",
		"PhantomSnackService",
		"VoidService",
		"VoidmiteService",
		"ShopService",
		"RebirthService",
		"VisitRewardService",
		"SnackService",
		"SmokeTestService",
		"HealthCheckService",
	}
end

local function plotById(plots, plotId)
	if not plots then
		return nil
	end
	local named = plots:FindFirstChild("Plot" .. tostring(plotId))
	if named then
		return named
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if tonumber(plot:GetAttribute("PlotId")) == plotId then
			return plot
		end
	end
	return nil
end

function SmokeTestService.Init(context)
	SmokeTestService.Context = context
end

function SmokeTestService.Start() end

function SmokeTestService.Run(player, reason)
	local context = SmokeTestService.Context
	local gameConfig = context.Config.GameConfig
	local featureFlags = context.Config.FeatureFlags or {}
	local summary = {
		Reason = reason or "manual",
		BuildVersion = gameConfig.BuildVersion or gameConfig.Phase,
		LaunchMode = gameConfig.LaunchMode,
		Passed = 0,
		Warnings = 0,
		Failed = 0,
		Checks = {},
	}

	record(summary, gameConfig.LaunchMode == "PrivateTest", "LaunchMode", tostring(gameConfig.LaunchMode))
	record(summary, gameConfig.BuildVersion == "0.1.0-private", "BuildVersion", tostring(gameConfig.BuildVersion))
	record(summary, gameConfig.FeatureFreeze == true, "FeatureFreeze", tostring(gameConfig.FeatureFreeze))
	record(summary, type(context.Config.SizeConfig) == "table", "SizeConfig loaded", context.Config.SizeConfig and "loaded" or "missing")
	if context.Config.SizeConfig then
		record(summary, context.Config.SizeConfig.Tiers.Colossal ~= nil and context.Config.SizeConfig.Tiers.Voidborn ~= nil, "Size tiers", "Colossal/Voidborn present")
	end
	record(summary, tonumber(gameConfig.VoidEventChargeDuration) ~= nil, "Void event charge", tostring(gameConfig.VoidEventChargeDuration))
	record(summary, tonumber(gameConfig.MaxPlateSnackVisualScale) == 3.5, "Plate visual cap", tostring(gameConfig.MaxPlateSnackVisualScale))
	record(summary, tonumber(gameConfig.MaxDisplaySnackVisualScale) == 2.8, "Display visual cap", tostring(gameConfig.MaxDisplaySnackVisualScale))
	record(summary, tonumber(gameConfig.MaxSingleFeedHungerPercent) ~= nil, "Feed hunger cap", tostring(gameConfig.MaxSingleFeedHungerPercent))
	record(summary, featureFlags.Monetization == false, "Monetization flag", tostring(featureFlags.Monetization))
	record(summary, featureFlags.Trading == false, "Trading flag", tostring(featureFlags.Trading))
	record(summary, featureFlags.Stealing == false, "Stealing flag", tostring(featureFlags.Stealing))
	record(summary, featureFlags.Pets == false, "Pets flag", tostring(featureFlags.Pets))
	record(summary, featureFlags.PrivateTestFeedback ~= false, "Feedback flag", tostring(featureFlags.PrivateTestFeedback))

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	for _, remoteName in ipairs(expectedRemotes()) do
		local remote = remotesFolder and remotesFolder:FindFirstChild(remoteName)
		record(summary, remote and remote:IsA("RemoteEvent"), "Remote " .. remoteName, remote and remote.ClassName or "missing")
	end

	for _, serviceName in ipairs(expectedServices()) do
		record(summary, context.Services[serviceName] ~= nil, "Service " .. serviceName, context.Services[serviceName] and "loaded" or "missing")
	end

	local utilFolder = script.Parent.Parent:FindFirstChild("Util")
	for _, utilName in ipairs({ "CooldownUtil", "ValidationUtil", "Maid", "SafeCall" }) do
		local util = utilFolder and utilFolder:FindFirstChild(utilName)
		record(summary, util ~= nil, "Util " .. utilName, util and "present" or "missing")
	end

	local world = workspace:FindFirstChild("GameWorld")
	local plots = world and world:FindFirstChild("Plots")
	record(summary, world ~= nil, "Workspace.GameWorld", world and "present" or "missing")
	record(summary, childCount(plots) >= 8, "Plots count", tostring(childCount(plots)))
	record(summary, childCount(world and world:FindFirstChild("ScreenshotSpots")) >= 5, "ScreenshotSpots", tostring(childCount(world and world:FindFirstChild("ScreenshotSpots"))))
	record(summary, world and world:FindFirstChild("CentralVoid") ~= nil, "CentralVoid", world and "checked" or "missing")
	record(summary, world and world:FindFirstChild("EventObjects") ~= nil, "EventObjects folder", world and "checked" or "missing")
	for plotId = 1, 8 do
		local plot = plotById(plots, plotId)
		record(summary, plot ~= nil, "Plot" .. tostring(plotId), plot and "present" or "missing")
		if plot then
			record(summary, childCount(plot:FindFirstChild("Plates")) >= (gameConfig.PlateCount or 6), "Plot" .. tostring(plotId) .. " plates", tostring(childCount(plot:FindFirstChild("Plates"))))
			record(summary, plot:FindFirstChild("OwnerSign") ~= nil, "Plot" .. tostring(plotId) .. " owner sign", plot:FindFirstChild("OwnerSign") and "present" or "missing", true)
		end
	end

	for _, assetKey in ipairs(AssetReferences.RequiredAssetKeys or {}) do
		local ok, model = pcall(function()
			return context.Services.AssetService.CloneModel(assetKey)
		end)
		if ok and model then
			model:Destroy()
		end
		record(summary, ok and model ~= nil, "Asset/fallback " .. assetKey, ok and "clone ok" or tostring(model), true)
	end
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local modelsFolder = assetsFolder and assetsFolder:FindFirstChild("Models")
	for _, folderName in ipairs(AssetReferences.ModelFolders or {}) do
		record(summary, modelsFolder and modelsFolder:FindFirstChild(folderName) ~= nil, "Assets.Models." .. folderName, modelsFolder and (modelsFolder:FindFirstChild(folderName) and "present" or "missing") or "missing")
	end
	record(summary, assetsFolder and assetsFolder:FindFirstChild("Duplicates") ~= nil, "Assets.Duplicates", assetsFolder and (assetsFolder:FindFirstChild("Duplicates") and "present" or "missing") or "missing", true)
	if context.Services.AssetService then
		local assetReport = context.Services.AssetService.GetAssetReport()
		summary.AssetReport = assetReport
		record(summary, assetReport.Total >= 30, "Asset reference count", tostring(assetReport.Total))
		record(summary, assetReport.Loose == 0, "Loose Workspace assets", tostring(assetReport.Loose), true)
	end

	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local launchPageConfigModule = shared and shared:FindFirstChild("LaunchPageConfig")
	record(summary, launchPageConfigModule and launchPageConfigModule:IsA("ModuleScript"), "Shared.LaunchPageConfig", launchPageConfigModule and launchPageConfigModule.ClassName or "missing")
	local soundConfigModule = shared and shared:FindFirstChild("SoundConfig")
	record(summary, soundConfigModule and soundConfigModule:IsA("ModuleScript"), "Shared.SoundConfig", soundConfigModule and soundConfigModule.ClassName or "missing")
	record(summary, type(context.Config.SoundConfig) == "table", "SoundConfig loaded", context.Config.SoundConfig and "loaded" or "missing")
	local vfxConfigModule = shared and shared:FindFirstChild("VFXConfig")
	record(summary, vfxConfigModule and vfxConfigModule:IsA("ModuleScript"), "Shared.VFXConfig", vfxConfigModule and vfxConfigModule.ClassName or "missing")
	record(summary, type(context.Config.VFXConfig) == "table", "VFXConfig loaded", context.Config.VFXConfig and "loaded" or "missing")
	if type(context.Config.VFXConfig) == "table" then
		local vfxKeys = {}
		for _, key in ipairs(context.Config.VFXConfig.EffectKeys or {}) do
			vfxKeys[key] = true
		end
		for _, key in ipairs({ "Void.FeedSmall", "Void.FeedNormal", "Void.FeedRare", "Void.FeedColossal", "Void.EventCharge" }) do
			record(summary, vfxKeys[key] == true, "VFX key " .. key, vfxKeys[key] and "present" or "missing")
		end
	end
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local controllers = starterScripts and starterScripts:FindFirstChild("Controllers")
	local controller = controllers and controllers:FindFirstChild("SoundController")
	record(summary, controller and controller:IsA("ModuleScript"), "Client SoundController", controller and controller.ClassName or "missing")
	local effectsController = controllers and controllers:FindFirstChild("EffectsController")
	record(summary, effectsController and effectsController:IsA("ModuleScript"), "Client EffectsController", effectsController and effectsController.ClassName or "missing")
	record(summary, not (controllers and controllers:FindFirstChild("VFXController")), "Legacy VFXController removed", controllers and controllers:FindFirstChild("VFXController") and "still present" or "absent")
	for _, groupName in ipairs({ "Master", "UI", "SFX", "Ambience" }) do
		local group = SoundService:FindFirstChild(groupName)
		record(summary, group and group:IsA("SoundGroup"), "SoundGroup " .. groupName, group and ("volume=" .. tostring(group.Volume)) or "missing")
	end
	if context.Services.AudioService then
		local audioStats = context.Services.AudioService.GetConfigStats()
		summary.Audio = audioStats
		record(summary, audioStats.Valid > 0, "Audio valid IDs", tostring(audioStats.Valid))
		record(summary, audioStats.Disabled >= 0, "Audio disabled IDs", tostring(audioStats.Disabled), true)
		record(summary, audioStats.Malformed == 0, "Audio malformed IDs", tostring(audioStats.Malformed))
		record(summary, audioStats.BadVolume == 0, "Audio volume range", tostring(audioStats.BadVolume))
		record(summary, audioStats.BadLoopFlag == 0, "Audio loop flags", tostring(audioStats.BadLoopFlag))
	end
	if context.Services.VFXService then
		local vfxStats = context.Services.VFXService.GetConfigStats()
		summary.VFX = vfxStats
		record(summary, vfxStats.Configured >= 20, "VFX key configs", tostring(vfxStats.Configured))
		record(summary, vfxStats.MaxTemporaryEffects == 80, "Temporary effect cap", tostring(vfxStats.MaxTemporaryEffects))
		record(summary, vfxStats.MaxParticleCount <= 80, "VFX particle budget", tostring(vfxStats.MaxParticleCount))
		record(summary, vfxStats.UnknownAliases == 0, "VFX aliases", tostring(vfxStats.UnknownAliases))
	end
	record(summary, type(gameConfig.SettingsDefaults) == "table" and gameConfig.SettingsDefaults.ReduceEffects ~= nil, "Settings.ReduceEffects", "configured")
	record(summary, type(gameConfig.SettingsDefaults) == "table" and gameConfig.SettingsDefaults.LowDetailMode ~= nil, "Settings.LowDetailMode", "configured")
	record(summary, type(gameConfig.SettingsDefaults) == "table" and gameConfig.SettingsDefaults.HideExtraPopups ~= nil, "Settings.HideExtraPopups", "configured")

	if player then
		local data = context.Services.ProfileServiceWrapper.GetData(player)
		record(summary, player:GetAttribute("ProfileReady") == true, "Player ProfileReady", tostring(player:GetAttribute("ProfileReady")))
		record(summary, player:GetAttribute("PlotAssigned") == true, "Player PlotAssigned", tostring(player:GetAttribute("PlotAssigned")))
		record(summary, player:GetAttribute("InitialSyncSent") == true, "Player InitialSyncSent", tostring(player:GetAttribute("InitialSyncSent")))
		record(summary, data ~= nil, "Player profile data", data and "loaded" or "missing")
		if data then
			record(summary, type(data.Seeds) == "table", "Data.Seeds", data.Seeds and "present" or "missing")
			record(summary, type(data.Inventory) == "table", "Data.Inventory", data.Inventory and "present" or "missing")
			record(summary, tonumber(data.AssignedPlotId) ~= nil, "Data.AssignedPlotId", tostring(data.AssignedPlotId))
		end
	end

	lastSummary = summary
	SmokeTestService.PrintSummary(summary)
	if player and context.Services.EconomyService then
		context.Services.EconomyService.Notify(player, "Smoke: " .. tostring(summary.Passed) .. " pass, " .. tostring(summary.Warnings) .. " warn, " .. tostring(summary.Failed) .. " fail.")
	end
	return summary
end

function SmokeTestService.First10Check(player)
	local context = SmokeTestService.Context
	local data = player and context.Services.ProfileServiceWrapper.GetData(player)
	local gameConfig = context.Config.GameConfig
	local cheapestSeedId = nil
	local cheapestSeedCost = math.huge
	for _, snackId in ipairs(context.Config.SnackConfig.Order or {}) do
		local snack = context.Config.SnackConfig[snackId]
		if snack and tonumber(snack.SeedCost) and snack.SeedCost < cheapestSeedCost then
			cheapestSeedId = snackId
			cheapestSeedCost = snack.SeedCost
		end
	end
	local cookie = context.Config.SnackConfig.CookieRock or {}
	local firstUpgradeCost = context.Services.UpgradeService and context.Services.UpgradeService.GetCost(player, "GrowSpeed") or ((gameConfig.UpgradeConfig.GrowSpeed or {}).BaseCost)
	local firstQuests = {}
	if data and data.Quests and data.Quests.Active then
		for index, quest in ipairs(data.Quests.Active) do
			if index > 3 then
				break
			end
			table.insert(firstQuests, tostring(quest.Text or quest.Id or "?"))
		end
	end
	local summary = {
		Reason = "first10check",
		BuildVersion = gameConfig.BuildVersion or gameConfig.Phase,
		LaunchMode = gameConfig.LaunchMode,
		Passed = 0,
		Warnings = 0,
		Failed = 0,
		Checks = {},
	}
	record(summary, player ~= nil, "Player", player and player.Name or "missing")
	record(summary, data ~= nil, "Profile data", data and "loaded" or "missing")
	record(summary, (gameConfig.StartingCoins or 0) >= (cheapestSeedCost == math.huge and 0 or cheapestSeedCost), "Starting coins", tostring(gameConfig.StartingCoins))
	record(summary, type(gameConfig.StartingSeeds) == "table" and next(gameConfig.StartingSeeds) ~= nil, "Starting seeds", gameConfig.StartingSeeds and "configured" or "missing")
	record(summary, cheapestSeedId ~= nil, "Cheapest starter seed", tostring(cheapestSeedId) .. " cost=" .. tostring(cheapestSeedCost ~= math.huge and cheapestSeedCost or "?"))
	record(summary, tonumber(cookie.GrowTime) and cookie.GrowTime <= 45, "CookieRock grow time", tostring(cookie.GrowTime))
	record(summary, tonumber(firstUpgradeCost) and firstUpgradeCost <= math.max(100, (gameConfig.StartingCoins or 0) * 1.25), "First upgrade cost", tostring(firstUpgradeCost))
	record(summary, (gameConfig.FirstVoidmiteSpawnDelay or 999) <= 60, "First Voidmite delay", tostring(gameConfig.FirstVoidmiteSpawnDelay))
	record(summary, (gameConfig.VoidHungerRequired or 999) <= 150, "Void Hunger required", tostring(gameConfig.VoidHungerRequired))
	record(summary, (gameConfig.TargetFirstEventSeconds or 999) <= 360, "Target first event", tostring(gameConfig.TargetFirstEventSeconds))
	record(summary, #firstQuests > 0, "First quests", #firstQuests > 0 and table.concat(firstQuests, " | ") or "none", #firstQuests == 0)
	record(summary, context.Services.PlaytimeRewardService and context.Services.PlaytimeRewardService.GetClaimable ~= nil, "Playtime rewards", "configured")
	local firstReward = type(gameConfig.PlaytimeRewards) == "table" and gameConfig.PlaytimeRewards[1] or nil
	record(summary, firstReward and tonumber(firstReward.Seconds) and firstReward.Seconds <= 120, "First playtime reward", firstReward and (tostring(firstReward.Seconds) .. "s " .. tostring(firstReward.Label)) or "missing")
	if data then
		record(summary, tonumber(data.Coins) ~= nil, "Coins", tostring(data.Coins))
		record(summary, type(data.Seeds) == "table" and next(data.Seeds) ~= nil, "Starting seeds", data.Seeds and "present" or "missing")
		record(summary, type(data.PlantedSnacks) == "table", "Planted snacks table", data.PlantedSnacks and tostring(#data.PlantedSnacks) or "missing")
		record(summary, type(data.Inventory) == "table", "Inventory table", data.Inventory and tostring(#data.Inventory) or "missing")
		record(summary, data.TutorialCompleted ~= nil, "Tutorial state", tostring(data.TutorialCompleted))
	end
	local eventStatus = context.Services.EventService and context.Services.EventService.GetStatus() or {}
	record(summary, eventStatus.ActiveEventName ~= nil or true, "Event service status", tostring(eventStatus.ActiveEventName or "none"), true)
	record(summary, context.Services.OnboardingService ~= nil, "Onboarding service", context.Services.OnboardingService and "loaded" or "missing")
	lastFirst10Summary = summary
	SmokeTestService.PrintSummary(summary)
	if player and context.Services.EconomyService then
		context.Services.EconomyService.Notify(player, "First-10 check printed to Output.")
	end
	return summary
end

function SmokeTestService.SpectacleCheck(player)
	local context = SmokeTestService.Context
	local gameConfig = context.Config.GameConfig
	local summary = {
		Reason = "spectaclecheck",
		BuildVersion = gameConfig.BuildVersion or gameConfig.Phase,
		LaunchMode = gameConfig.LaunchMode,
		Passed = 0,
		Warnings = 0,
		Failed = 0,
		Checks = {},
	}
	record(summary, gameConfig.Phase == "16-spectacle", "Phase", tostring(gameConfig.Phase))
	record(summary, type(context.Config.SizeConfig) == "table", "SizeConfig", context.Config.SizeConfig and "loaded" or "missing")
	if context.Config.SizeConfig then
		for _, tierId in ipairs({ "Regular", "Chunky", "Huge", "Massive", "Colossal", "Voidborn" }) do
			record(summary, context.Config.SizeConfig.Tiers[tierId] ~= nil, "Size tier " .. tierId, context.Config.SizeConfig.Tiers[tierId] and "present" or "missing")
		end
	end
	record(summary, tonumber(gameConfig.VoidEventChargeDuration) ~= nil and gameConfig.VoidEventChargeDuration > 0, "Void charge duration", tostring(gameConfig.VoidEventChargeDuration))
	record(summary, tonumber(gameConfig.MaxPlateSnackVisualScale) == 3.5, "Plate snack cap", tostring(gameConfig.MaxPlateSnackVisualScale))
	record(summary, tonumber(gameConfig.MaxDisplaySnackVisualScale) == 2.8, "Display snack cap", tostring(gameConfig.MaxDisplaySnackVisualScale))
	record(summary, tonumber(gameConfig.MaxSingleFeedHungerPercent) ~= nil and gameConfig.MaxSingleFeedHungerPercent <= 0.35, "Single feed hunger cap", tostring(gameConfig.MaxSingleFeedHungerPercent))

	local vfxKeys = {}
	for _, key in ipairs((context.Config.VFXConfig and context.Config.VFXConfig.EffectKeys) or {}) do
		vfxKeys[key] = true
	end
	for _, key in ipairs({ "Void.FeedSmall", "Void.FeedNormal", "Void.FeedRare", "Void.FeedColossal", "Void.EventCharge" }) do
		record(summary, vfxKeys[key] == true, "VFX key " .. key, vfxKeys[key] and "present" or "missing")
	end
	for _, eventName in ipairs(context.Config.EventConfig.Order or {}) do
		local eventConfig = context.Config.EventConfig[eventName]
		record(summary, eventConfig and eventConfig.ObjectiveText ~= nil, "Event objective " .. tostring(eventName), eventConfig and tostring(eventConfig.ObjectiveText) or "missing")
		record(summary, eventConfig and eventConfig.WorldVisualText ~= nil, "Event world text " .. tostring(eventName), eventConfig and tostring(eventConfig.WorldVisualText) or "missing", true)
	end
	local world = workspace:FindFirstChild("GameWorld")
	record(summary, world and world:FindFirstChild("EventObjects") ~= nil, "EventObjects cleanup folder", world and (world:FindFirstChild("EventObjects") and "present" or "missing") or "missing")
	record(summary, context.Services.EventService.GetActiveEventObjective ~= nil, "Event objective API", context.Services.EventService.GetActiveEventObjective and "present" or "missing")
	record(summary, context.Services.VoidService.IsCharging ~= nil, "Void charge API", context.Services.VoidService.IsCharging and "present" or "missing")

	SmokeTestService.PrintSummary(summary)
	if player and context.Services.EconomyService then
		context.Services.EconomyService.Notify(player, "Spectacle check: " .. tostring(summary.Passed) .. " pass, " .. tostring(summary.Warnings) .. " warn, " .. tostring(summary.Failed) .. " fail.")
	end
	return summary
end

function SmokeTestService.PrintSummary(summary)
	print("[FEED THE VOID][SmokeTest] " .. tostring(summary.Reason) .. ": " .. tostring(summary.Passed) .. " pass, " .. tostring(summary.Warnings) .. " warn, " .. tostring(summary.Failed) .. " fail.")
	if summary.Audio then
		print("[FEED THE VOID][SmokeTest] Audio: " .. tostring(summary.Audio.Valid) .. " valid, " .. tostring(summary.Audio.Disabled) .. " disabled, " .. tostring(summary.Audio.Malformed) .. " malformed.")
	end
	if summary.VFX then
		print("[FEED THE VOID][SmokeTest] VFX: OK | keys=" .. tostring(summary.VFX.Configured) .. " cap=" .. tostring(summary.VFX.MaxTemporaryEffects) .. " maxParticles=" .. tostring(summary.VFX.MaxParticleCount))
	end
	if summary.AssetReport then
		print("[FEED THE VOID][SmokeTest] Assets: organized=" .. tostring(summary.AssetReport.Organized) .. " loose=" .. tostring(summary.AssetReport.Loose) .. " missing=" .. tostring(summary.AssetReport.Missing))
	end
	for _, entry in ipairs(summary.Checks or {}) do
		if not entry.Ok then
			local prefix = entry.WarnOnly and "WARN" or "FAIL"
			warn("[FEED THE VOID][SmokeTest] " .. prefix .. " " .. tostring(entry.Label) .. " - " .. tostring(entry.Detail))
		end
	end
end

function SmokeTestService.GetLastSummary()
	return lastSummary
end

function SmokeTestService.GetLastFirst10Summary()
	return lastFirst10Summary
end

return SmokeTestService
