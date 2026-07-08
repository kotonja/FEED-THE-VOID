local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local AssetReferences = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReferences"))

local HealthCheckService = {}

local lastSummary = nil

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

local function expectedUtils()
	return {
		"CooldownUtil",
		"ValidationUtil",
		"Maid",
		"SafeCall",
	}
end

local function findPlotById(plotsFolder, plotId)
	if not plotsFolder then
		return nil
	end
	local named = plotsFolder:FindFirstChild("Plot" .. tostring(plotId))
	if named then
		return named
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if tonumber(plot:GetAttribute("PlotId")) == plotId then
			return plot
		end
	end
	return nil
end

function HealthCheckService.Init(context)
	HealthCheckService.Context = context
end

function HealthCheckService.Start()
	if HealthCheckService.Context.Config.GameConfig.SoftLaunch and HealthCheckService.Context.Config.GameConfig.SoftLaunch.HealthCheckOnServerStart == false then
		return
	end
	task.defer(function()
		HealthCheckService.Run(nil, "server-start")
	end)
end

function HealthCheckService.Run(player, reason)
	local context = HealthCheckService.Context
	local gameConfig = context.Config.GameConfig
	local summary = {
		Reason = reason or "manual",
		StartedAt = os.time(),
		BuildVersion = gameConfig.BuildVersion or gameConfig.Phase,
		BuildName = gameConfig.BuildName or "FEED THE VOID",
		LaunchMode = gameConfig.LaunchMode,
		Passed = 0,
		Warnings = 0,
		Failed = 0,
		Checks = {},
	}

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	record(summary, remotesFolder ~= nil, "ReplicatedStorage.Remotes", remotesFolder and "present" or "missing")
	for _, remoteName in ipairs(expectedRemotes()) do
		local remote = remotesFolder and remotesFolder:FindFirstChild(remoteName)
		record(summary, remote ~= nil, "Remote " .. remoteName, remote and remote.ClassName or "missing")
	end
	local seenRemotes = {}
	local duplicates = {}
	if remotesFolder then
		for _, child in ipairs(remotesFolder:GetChildren()) do
			if child:IsA("RemoteEvent") then
				if seenRemotes[child.Name] then
					table.insert(duplicates, child.Name)
				end
				seenRemotes[child.Name] = true
			end
		end
	end
	record(summary, #duplicates == 0, "Duplicate remotes", #duplicates == 0 and "none" or table.concat(duplicates, ", "))

	for _, serviceName in ipairs(expectedServices()) do
		record(summary, context.Services[serviceName] ~= nil, "Service " .. serviceName, context.Services[serviceName] and "loaded" or "missing")
	end
	local utilFolder = script.Parent.Parent:FindFirstChild("Util")
	record(summary, utilFolder ~= nil, "Server.Util", utilFolder and "present" or "missing")
	for _, utilName in ipairs(expectedUtils()) do
		local util = utilFolder and utilFolder:FindFirstChild(utilName)
		record(summary, util ~= nil, "Util " .. utilName, util and "loaded" or "missing")
	end

	local world = workspace:FindFirstChild("GameWorld")
	local plots = world and world:FindFirstChild("Plots")
	local central = world and world:FindFirstChild("CentralVoid")
	record(summary, world ~= nil, "Workspace.GameWorld", world and "present" or "missing")
	record(summary, childCount(plots) >= 8, "GameWorld.Plots", tostring(childCount(plots)) .. " plots")
	record(summary, childCount(world and world:FindFirstChild("ScreenshotSpots")) >= 5, "GameWorld.ScreenshotSpots", tostring(childCount(world and world:FindFirstChild("ScreenshotSpots"))) .. " spots")
	record(summary, central ~= nil, "GameWorld.CentralVoid", central and "present" or "missing")
	record(summary, central and (central:FindFirstChild("FeedStation") or central:FindFirstChild("VoidCore")) ~= nil, "CentralVoid feed target", central and "checked" or "missing")
	for _, folderName in ipairs({ "ActiveSnacks", "ActiveVoidmites", "EventObjects", "Stations", "SpawnPoints", "Plots" }) do
		record(summary, world and world:FindFirstChild(folderName) ~= nil, "GameWorld." .. folderName, world and (world:FindFirstChild(folderName) and "present" or "missing") or "missing")
	end

	for plotId = 1, 8 do
		local plot = findPlotById(plots, plotId)
		record(summary, plot ~= nil, "Plot" .. tostring(plotId), plot and "present" or "missing")
		if plot then
			record(summary, plot:FindFirstChild("PlotSpawn") ~= nil, "Plot" .. tostring(plotId) .. ".PlotSpawn", plot:FindFirstChild("PlotSpawn") and "present" or "missing")
			local plateFolder = plot:FindFirstChild("Plates")
			record(summary, childCount(plateFolder) >= (gameConfig.PlateCount or 6), "Plot" .. tostring(plotId) .. ".Plates", tostring(childCount(plateFolder)) .. " plates")
			record(summary, plot:FindFirstChild("OwnerSign") ~= nil, "Plot" .. tostring(plotId) .. ".OwnerSign", plot:FindFirstChild("OwnerSign") and "present" or "missing", true)
			for _, stationName in ipairs({ "SeedShopStation", "SellStation", "UpgradeStation", "DisplayShelf", "RebirthStation" }) do
				record(summary, plot:FindFirstChild(stationName) ~= nil, "Plot" .. tostring(plotId) .. "." .. stationName, plot:FindFirstChild(stationName) and "present" or "missing", true)
			end
		end
	end

	for _, assetKey in ipairs(AssetReferences.RequiredAssetKeys or {}) do
		local hasAsset = context.Services.AssetService and context.Services.AssetService.HasAsset(assetKey)
		record(summary, hasAsset, "Asset " .. assetKey, hasAsset and "imported" or "fallback active", true)
	end
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local modelsFolder = assetsFolder and assetsFolder:FindFirstChild("Models")
	record(summary, assetsFolder ~= nil, "ReplicatedStorage.Assets", assetsFolder and "present" or "missing")
	record(summary, modelsFolder ~= nil, "Assets.Models", modelsFolder and "present" or "missing")
	for _, folderName in ipairs(AssetReferences.ModelFolders or {}) do
		record(summary, modelsFolder and modelsFolder:FindFirstChild(folderName) ~= nil, "Assets.Models." .. folderName, modelsFolder and (modelsFolder:FindFirstChild(folderName) and "present" or "missing") or "missing")
	end
	record(summary, assetsFolder and assetsFolder:FindFirstChild("Duplicates") ~= nil, "Assets.Duplicates", assetsFolder and (assetsFolder:FindFirstChild("Duplicates") and "present" or "missing") or "missing", true)
	if context.Services.AssetService then
		local assetReport = context.Services.AssetService.GetAssetReport()
		summary.AssetReport = assetReport
		record(summary, assetReport.Total >= 30, "Asset reference count", tostring(assetReport.Total))
		record(summary, assetReport.Loose == 0, "Loose Workspace assets", tostring(assetReport.Loose), true)
		record(summary, assetReport.Missing <= 5, "Missing asset fallbacks", tostring(assetReport.Missing), true)
	end

	record(summary, type(context.Config.SnackConfig.Order) == "table" and #context.Config.SnackConfig.Order >= 1, "SnackConfig.Order", tostring(#(context.Config.SnackConfig.Order or {})) .. " snacks")
	record(summary, type(context.Config.SizeConfig) == "table", "SizeConfig", context.Config.SizeConfig and "loaded" or "missing")
	if context.Config.SizeConfig then
		record(summary, type(context.Config.SizeConfig.Tiers) == "table" and context.Config.SizeConfig.Tiers.Regular ~= nil and context.Config.SizeConfig.Tiers.Voidborn ~= nil, "SizeConfig tiers", "Regular to Voidborn")
	end
	record(summary, type(context.Config.MutationConfig.Normal) == "table", "MutationConfig.Normal", context.Config.MutationConfig.Normal and "present" or "missing")
	record(summary, type(context.Config.RarityConfig.Common) == "table", "RarityConfig.Common", context.Config.RarityConfig.Common and "present" or "missing")
	record(summary, type(context.Config.EventConfig.Order) == "table" and #context.Config.EventConfig.Order >= 1, "EventConfig.Order", tostring(#(context.Config.EventConfig.Order or {})) .. " events")
	record(summary, type(context.Config.FeatureFlags) == "table", "FeatureFlags", context.Config.FeatureFlags and "present" or "missing")
	if context.Config.FeatureFlags then
		record(summary, context.Config.FeatureFlags.Monetization == false, "FeatureFlags.Monetization", tostring(context.Config.FeatureFlags.Monetization))
		record(summary, context.Config.FeatureFlags.Trading == false, "FeatureFlags.Trading", tostring(context.Config.FeatureFlags.Trading))
		record(summary, context.Config.FeatureFlags.Stealing == false, "FeatureFlags.Stealing", tostring(context.Config.FeatureFlags.Stealing))
		record(summary, context.Config.FeatureFlags.PrivateTestFeedback ~= false, "FeatureFlags.PrivateTestFeedback", tostring(context.Config.FeatureFlags.PrivateTestFeedback))
	end
	record(summary, type(gameConfig.UpgradeConfig) == "table", "UpgradeConfig", gameConfig.UpgradeConfig and "present" or "missing")
	record(summary, gameConfig.BuildVersion == "0.1.0-private", "BuildVersion", tostring(gameConfig.BuildVersion))
	record(summary, gameConfig.FeatureFreeze == true, "FeatureFreeze", tostring(gameConfig.FeatureFreeze))
	record(summary, type(gameConfig.SettingsDefaults) == "table" and gameConfig.SettingsDefaults.ShowGuidance ~= nil, "Settings.ShowGuidance", "configured")
	record(summary, type(gameConfig.Failsafes) == "table" and gameConfig.Failsafes.TeleportToPlotCooldown ~= nil, "Failsafe config", "configured")
	record(summary, gameConfig.LaunchMode == "PrivateTest" or gameConfig.LaunchMode == "Development" or gameConfig.LaunchMode == "SoftLaunch" or gameConfig.LaunchMode == "Production", "LaunchMode", tostring(gameConfig.LaunchMode))
	record(summary, type(gameConfig.Performance) == "table" and gameConfig.Performance.MaxVoidmitesGlobal ~= nil, "Performance config", "configured")
	record(summary, type(gameConfig.Limits) == "table" and gameConfig.Limits.MaxInventoryItems ~= nil, "Limits config", "configured")
	record(summary, type(gameConfig.Security) == "table" and gameConfig.Security.InvalidRemoteWarnThreshold ~= nil, "Security config", "configured")
	record(summary, type(gameConfig.PrivateTest) == "table" and gameConfig.PrivateTest.MaxPlayers ~= nil, "PrivateTest config", "configured")
	record(summary, type(gameConfig.InteractionDistances) == "table" and gameConfig.InteractionDistances.Plate ~= nil, "Interaction distance config", "configured")
	record(summary, tonumber(gameConfig.VoidEventChargeDuration) ~= nil, "VoidEventChargeDuration", tostring(gameConfig.VoidEventChargeDuration))
	record(summary, tonumber(gameConfig.MaxPlateSnackVisualScale) == 3.5, "MaxPlateSnackVisualScale", tostring(gameConfig.MaxPlateSnackVisualScale))
	record(summary, tonumber(gameConfig.MaxDisplaySnackVisualScale) == 2.8, "MaxDisplaySnackVisualScale", tostring(gameConfig.MaxDisplaySnackVisualScale))
	record(summary, tonumber(gameConfig.MaxSingleFeedHungerPercent) ~= nil, "MaxSingleFeedHungerPercent", tostring(gameConfig.MaxSingleFeedHungerPercent))
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local launchPageConfigModule = shared and shared:FindFirstChild("LaunchPageConfig")
	record(summary, launchPageConfigModule and launchPageConfigModule:IsA("ModuleScript"), "Shared.LaunchPageConfig", launchPageConfigModule and launchPageConfigModule.ClassName or "missing")
	local soundConfigModule = shared and shared:FindFirstChild("SoundConfig")
	record(summary, soundConfigModule and soundConfigModule:IsA("ModuleScript"), "Shared.SoundConfig", soundConfigModule and soundConfigModule.ClassName or "missing")
	record(summary, type(context.Config.SoundConfig) == "table", "SoundConfig loaded", context.Config.SoundConfig and "loaded" or "missing")
	local vfxConfigModule = shared and shared:FindFirstChild("VFXConfig")
	record(summary, vfxConfigModule and vfxConfigModule:IsA("ModuleScript"), "Shared.VFXConfig", vfxConfigModule and vfxConfigModule.ClassName or "missing")
	record(summary, type(context.Config.VFXConfig) == "table", "VFXConfig loaded", context.Config.VFXConfig and "loaded" or "missing")
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local controllers = starterScripts and starterScripts:FindFirstChild("Controllers")
	local controller = controllers and controllers:FindFirstChild("SoundController")
	record(summary, controller and controller:IsA("ModuleScript"), "Client SoundController", controller and controller.ClassName or "missing")
	local effectsController = controllers and controllers:FindFirstChild("EffectsController")
	record(summary, effectsController and effectsController:IsA("ModuleScript"), "Client EffectsController", effectsController and effectsController.ClassName or "missing")
	local oldVfxController = controllers and controllers:FindFirstChild("VFXController")
	record(summary, oldVfxController == nil, "Legacy VFXController removed", oldVfxController and oldVfxController.ClassName or "absent")
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
	record(summary, context.Services.ProfileServiceWrapper.GetDataStoreMode ~= nil, "DataStore mode", context.Services.ProfileServiceWrapper.GetDataStoreMode and context.Services.ProfileServiceWrapper.GetDataStoreMode() or "unknown", true)
	record(summary, gameConfig.DebugMode ~= true or gameConfig.LaunchMode ~= "Production", "DebugMode", "LaunchMode=" .. tostring(gameConfig.LaunchMode), true)

	if player then
		local data = context.Services.ProfileServiceWrapper.GetData(player)
		record(summary, data ~= nil, "Player data", data and "loaded" or "missing")
		if data then
			record(summary, data.AssignedPlotId ~= nil, "Data.AssignedPlotId", tostring(data.AssignedPlotId))
			record(summary, data.TutorialCompleted ~= nil, "Data.TutorialCompleted", tostring(data.TutorialCompleted))
			record(summary, type(data.Settings) == "table" and data.Settings.ShowGuidance ~= nil, "Data.Settings.ShowGuidance", tostring(data.Settings and data.Settings.ShowGuidance))
			record(summary, type(data.Failsafes) == "table", "Data.Failsafes", data.Failsafes and "present" or "missing")
			record(summary, player:GetAttribute("ProfileReady") == true, "Player.ProfileReady", tostring(player:GetAttribute("ProfileReady")))
			record(summary, player:GetAttribute("PlotAssigned") == true, "Player.PlotAssigned", tostring(player:GetAttribute("PlotAssigned")))
			record(summary, player:GetAttribute("InitialSyncSent") == true, "Player.InitialSyncSent", tostring(player:GetAttribute("InitialSyncSent")))
		end
	end

	lastSummary = summary
	HealthCheckService.PrintSummary(summary)
	if player and context.Services.EconomyService then
		context.Services.EconomyService.Notify(player, "Health: " .. tostring(summary.Passed) .. " pass, " .. tostring(summary.Warnings) .. " warn, " .. tostring(summary.Failed) .. " fail.")
	end
	return summary
end

function HealthCheckService.PrintSummary(summary)
	summary = summary or lastSummary
	if not summary then
		return
	end
	local prefix = "[FEED THE VOID][Health]"
	print("[FEED THE VOID HEALTH CHECK]")
	print(prefix .. " build=" .. tostring(summary.BuildVersion or "?") .. " launch=" .. tostring(summary.LaunchMode or "?") .. " reason=" .. tostring(summary.Reason) .. ": " .. tostring(summary.Passed) .. " pass, " .. tostring(summary.Warnings) .. " warn, " .. tostring(summary.Failed) .. " fail.")
	if summary.Audio then
		print(prefix .. " Audio: " .. tostring(summary.Audio.Valid) .. " valid, " .. tostring(summary.Audio.Disabled) .. " disabled, " .. tostring(summary.Audio.Malformed) .. " malformed.")
	end
	if summary.VFX then
		print(prefix .. " VFX: OK | keys=" .. tostring(summary.VFX.Configured) .. " cap=" .. tostring(summary.VFX.MaxTemporaryEffects) .. " maxParticles=" .. tostring(summary.VFX.MaxParticleCount))
	end
	if summary.AssetReport then
		print(prefix .. " Assets: organized=" .. tostring(summary.AssetReport.Organized) .. " loose=" .. tostring(summary.AssetReport.Loose) .. " missing=" .. tostring(summary.AssetReport.Missing))
	end
	for _, entry in ipairs(summary.Checks) do
		if not entry.Ok then
			local line = prefix .. " " .. (entry.WarnOnly and "WARN " or "FAIL ") .. entry.Label .. " - " .. tostring(entry.Detail)
			warn(line)
		end
	end
end

function HealthCheckService.GetLastSummary()
	return lastSummary
end

return HealthCheckService
