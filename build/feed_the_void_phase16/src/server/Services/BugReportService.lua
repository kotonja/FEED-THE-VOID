local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local BugReportService = {}

local DEFAULT_LOOK_TARGETS = {
	ScreenshotSpot_Event = Vector3.new(-280, 60, -184),
	ScreenshotSpot_FeedVoid = Vector3.new(-280, 58, -184),
	ScreenshotSpot_Lab = Vector3.new(-258, 61, -176),
	ScreenshotSpot_Overview = Vector3.new(-280, 58, -185),
	ScreenshotSpot_Rebirth = Vector3.new(-258, 61, -174),
}

local function countTable(value)
	return type(value) == "table" and #value or 0
end

local function boolText(value)
	return value and "true" or "false"
end

local function vecText(value)
	if typeof(value) == "Vector3" then
		return string.format("%.1f, %.1f, %.1f", value.X, value.Y, value.Z)
	end
	return "unknown"
end

local function playerPosition(player)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function findPlayer(name)
	name = tostring(name or "")
	if name == "" then
		return nil
	end
	local needle = string.lower(name)
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == needle or string.lower(player.DisplayName) == needle then
			return player
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(player.Name), needle, 1, true) or string.find(string.lower(player.DisplayName), needle, 1, true) then
			return player
		end
	end
	return nil
end

local function seedSummary(seeds)
	if type(seeds) ~= "table" then
		return "none"
	end
	local parts = {}
	for seedId, count in pairs(seeds) do
		if tonumber(count) and tonumber(count) > 0 then
			table.insert(parts, tostring(seedId) .. "=" .. tostring(count))
		end
	end
	table.sort(parts)
	return #parts > 0 and table.concat(parts, ",") or "none"
end

local function questSummary(quests)
	local active = quests and quests.Active or {}
	local parts = {}
	for index, quest in ipairs(active) do
		if index > 3 then
			break
		end
		table.insert(parts, tostring(quest.Text or quest.Id or "?") .. " " .. tostring(quest.Progress or 0) .. "/" .. tostring(quest.Target or 1))
	end
	return #parts > 0 and table.concat(parts, " | ") or "none"
end

local function lastActionsText(actions)
	local parts = {}
	for index, action in ipairs(actions or {}) do
		if index > 5 then
			break
		end
		local detail = action.Detail and (" (" .. tostring(action.Detail) .. ")") or ""
		table.insert(parts, tostring(action.Action) .. detail)
	end
	return #parts > 0 and table.concat(parts, " <- ") or "none"
end

local function countPlotVoidmites(context, player, data)
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("ActiveVoidmites")
	local plotId = data and tonumber(data.AssignedPlotId) or nil
	local count = 0
	if not folder then
		return 0
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("OwnerUserId")) == player.UserId or (plotId and tonumber(child:GetAttribute("PlotId")) == plotId) then
			count += 1
		end
	end
	return count
end

local function mainUiForPlayer(player)
	local playerGui = player and player:FindFirstChild("PlayerGui")
	return (playerGui and playerGui:FindFirstChild("MainUI")) or StarterGui:FindFirstChild("MainUI")
end

local function collectDisallowedUiText(player)
	local hits = {}
	local disallowed = { "steal", "trade", "kill", "gamble", "lootbox", "paid reward", "like for reward", "coming soon" }
	local main = mainUiForPlayer(player)
	if not main then
		return hits
	end
	for _, object in ipairs(main:GetDescendants()) do
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			local text = string.lower(tostring(object.Text or object.PlaceholderText or ""))
			for _, word in ipairs(disallowed) do
				if string.find(text, word, 1, true) then
					table.insert(hits, object:GetFullName() .. "=" .. word)
				end
			end
		end
	end
	return hits
end

local function collectMobileUiWarnings(player)
	local warnings = {}
	local main = mainUiForPlayer(player)
	if not main then
		return { "MainUI missing" }
	end
	local nextGoal = main:FindFirstChild("NextGoalPanel")
	if not nextGoal then
		table.insert(warnings, "NextGoalPanel missing")
	elseif nextGoal.Size.Y.Offset > 64 then
		table.insert(warnings, "NextGoalPanel height is large")
	end
	local eventBanner = main:FindFirstChild("EventBanner")
	if eventBanner and (eventBanner.Size.Y.Scale > 0.16 or eventBanner.Size.Y.Offset > 110) then
		table.insert(warnings, "EventBanner height is large")
	end
	local feedbackButton = main:FindFirstChild("FeedbackButton")
	if feedbackButton and (feedbackButton.Size.X.Offset > 116 or feedbackButton.Size.Y.Offset > 40) then
		table.insert(warnings, "FeedbackButton is large")
	end
	local notifications = main:FindFirstChild("Notifications")
	if notifications and #notifications:GetChildren() > 3 then
		table.insert(warnings, "More than 3 notification UI objects")
	end
	local nav = main:FindFirstChild("BottomNav")
	if not nav then
		table.insert(warnings, "BottomNav missing")
	else
		local mobileAction = nav:FindFirstChild("MobileActionButton")
		if not mobileAction then
			table.insert(warnings, "Contextual action button missing")
		elseif mobileAction.Size.Y.Offset > 64 then
			table.insert(warnings, "Contextual action button is large")
		end
	end
	return warnings
end

local function summaryState(summary)
	if not summary then
		return "not run"
	end
	local failed = tonumber(summary.Failed) or 0
	local warnings = tonumber(summary.Warnings) or 0
	if failed > 0 then
		return "FAIL " .. tostring(failed)
	end
	if warnings > 0 then
		return "WARN " .. tostring(warnings)
	end
	return "OK"
end

local function spotsFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("ScreenshotSpots") or nil
end

local function lookAtForSpot(spot)
	local value = spot and spot:GetAttribute("LookAt") or nil
	if typeof(value) == "Vector3" then
		return value
	end
	return spot and DEFAULT_LOOK_TARGETS[spot.Name] or nil
end

function BugReportService.Init(context)
	BugReportService.Context = context
end

function BugReportService.Start() end

function BugReportService.BuildSnapshot(player)
	local context = BugReportService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local eventStatus = context.Services.EventService and context.Services.EventService.GetStatus() or {}
	local goal = context.Services.OnboardingService and context.Services.OnboardingService.GetNextGoal(player) or nil
	local settings = data and data.Settings or {}
	local actions = context.Services.AnalyticsService and context.Services.AnalyticsService.GetLastActions(player, 5) or {}
	return {
		BuildVersion = context.Config.GameConfig.BuildVersion or context.Config.GameConfig.Phase,
		LaunchMode = context.Config.GameConfig.LaunchMode,
		UserId = player.UserId,
		PlayerName = player.Name,
		ProfileLoaded = data ~= nil,
		AssignedPlotId = (context.Services.PlotService and context.Services.PlotService.GetPlotId(player)) or (data and data.AssignedPlotId) or 0,
		Position = playerPosition(player),
		Coins = data and data.Coins or 0,
		VoidTokens = data and data.VoidTokens or 0,
		Rebirths = data and data.Rebirths or 0,
		Seeds = seedSummary(data and data.Seeds),
		InventoryCount = countTable(data and data.Inventory),
		DisplayedCount = countTable(data and data.DisplayedSnacks),
		PlantedCount = countTable(data and data.PlantedSnacks),
		ActiveQuests = questSummary(data and data.Quests),
		TutorialStep = data and data.TutorialStep or "?",
		NextGoalId = goal and goal.Id or "none",
		NextGoalText = goal and goal.Text or "none",
		ActiveEventName = eventStatus.ActiveEventName or "none",
		ActiveVoidmitesOnPlot = data and countPlotVoidmites(context, player, data) or 0,
		MuteSounds = settings.MuteSounds == true,
		ReduceEffects = settings.ReduceEffects == true,
		LowDetailMode = settings.LowDetailMode == true,
		LastActions = actions,
	}
end

function BugReportService.PrintSnapshot(requestingPlayer, targetName)
	local target = targetName and targetName ~= "" and findPlayer(targetName) or requestingPlayer
	if not target then
		BugReportService.Context.Services.EconomyService.Notify(requestingPlayer, "Snapshot target not found.")
		return nil
	end
	local snapshot = BugReportService.BuildSnapshot(target)
	print("[FEED THE VOID][Snapshot] build=" .. tostring(snapshot.BuildVersion) .. " launch=" .. tostring(snapshot.LaunchMode) .. " player=" .. tostring(snapshot.PlayerName) .. " userId=" .. tostring(snapshot.UserId))
	print("[FEED THE VOID][Snapshot] profileLoaded=" .. boolText(snapshot.ProfileLoaded) .. " plot=" .. tostring(snapshot.AssignedPlotId) .. " position=" .. vecText(snapshot.Position))
	print("[FEED THE VOID][Snapshot] coins=" .. tostring(snapshot.Coins) .. " voidTokens=" .. tostring(snapshot.VoidTokens) .. " rebirths=" .. tostring(snapshot.Rebirths))
	print("[FEED THE VOID][Snapshot] seeds={" .. tostring(snapshot.Seeds) .. "} inventory=" .. tostring(snapshot.InventoryCount) .. " displayed=" .. tostring(snapshot.DisplayedCount) .. " planted=" .. tostring(snapshot.PlantedCount))
	print("[FEED THE VOID][Snapshot] quests=" .. tostring(snapshot.ActiveQuests) .. " tutorialStep=" .. tostring(snapshot.TutorialStep) .. " nextGoal=" .. tostring(snapshot.NextGoalId) .. " | " .. tostring(snapshot.NextGoalText))
	print("[FEED THE VOID][Snapshot] event=" .. tostring(snapshot.ActiveEventName) .. " voidmitesOnPlot=" .. tostring(snapshot.ActiveVoidmitesOnPlot) .. " mute=" .. boolText(snapshot.MuteSounds) .. " reduceEffects=" .. boolText(snapshot.ReduceEffects) .. " lowDetail=" .. boolText(snapshot.LowDetailMode))
	print("[FEED THE VOID][Snapshot] lastActions=" .. lastActionsText(snapshot.LastActions))
	BugReportService.Context.Services.EconomyService.Notify(requestingPlayer, "Snapshot printed for " .. target.Name .. ".")
	return snapshot
end

function BugReportService.PrintScreenshotSpots(player)
	local folder = spotsFolder()
	if not folder then
		print("[FEED THE VOID][ScreenshotSpots] folder missing")
		BugReportService.Context.Services.EconomyService.Notify(player, "Screenshot spots are missing.")
		return {}
	end
	local spots = folder:GetChildren()
	table.sort(spots, function(a, b)
		return a.Name < b.Name
	end)
	print("[FEED THE VOID][ScreenshotSpots] count=" .. tostring(#spots))
	for _, spot in ipairs(spots) do
		local position = spot:IsA("BasePart") and spot.Position or spot:GetAttribute("Position")
		print("[FEED THE VOID][ScreenshotSpots] " .. spot.Name .. " position=" .. vecText(position) .. " lookAt=" .. vecText(lookAtForSpot(spot)))
	end
	if player then
		BugReportService.Context.Services.EconomyService.Notify(player, "Screenshot spots printed to Output: " .. tostring(#spots))
	end
	return spots
end

function BugReportService.MoveCamera(player, spotName)
	local folder = spotsFolder()
	local spot = folder and folder:FindFirstChild(tostring(spotName or ""))
	if not (player and spot and spot:IsA("BasePart")) then
		BugReportService.Context.Services.EconomyService.Notify(player, "Camera spot not found.")
		return false
	end
	BugReportService.Context.Services.VFXService.PlayForPlayer(player, "UI.CameraSpot", {
		Mode = "UI",
		Position = spot.Position,
		LookAt = lookAtForSpot(spot),
		NoThrottle = true,
	})
	BugReportService.Context.Services.EconomyService.Notify(player, "Camera moved to " .. spot.Name .. ".")
	return true
end

function BugReportService.PrivateTestCheck(player)
	local context = BugReportService.Context
	local gameConfig = context.Config.GameConfig
	local flags = context.Config.FeatureFlags or {}
	local critical = {}
	local warnings = {}
	local recommended = {
		"Run !health after joining.",
		"Run !smoketest after profile sync.",
		"Test plant, harvest, feed, display, cleanse, upgrade.",
		"Use a phone-sized viewport once before inviting testers.",
	}

	local health = context.Services.HealthCheckService.GetLastSummary()
	local smoke = context.Services.SmokeTestService.GetLastSummary()
	local first10 = context.Services.SmokeTestService.GetLastFirst10Summary and context.Services.SmokeTestService.GetLastFirst10Summary() or nil
	local spectacle = context.Services.SmokeTestService.GetLastSpectacleSummary and context.Services.SmokeTestService.GetLastSpectacleSummary() or nil
	local audio = context.Services.AudioService.GetConfigStats()
	local vfx = context.Services.VFXService.GetConfigStats()
	local assetReport = context.Services.AssetService.GetLastAssetReport and context.Services.AssetService.GetLastAssetReport() or nil
	if not assetReport and context.Services.AssetService.GetAssetReport then
		assetReport = context.Services.AssetService.GetAssetReport()
	end
	local world = workspace:FindFirstChild("GameWorld")
	local plots = world and world:FindFirstChild("Plots")
	local mainUi = mainUiForPlayer(player)
	local loading = mainUi and mainUi:FindFirstChild("LoadingPanel")
	local textHits = collectDisallowedUiText(player)
	local mobileWarnings = collectMobileUiWarnings(player)
	local firstUpgradeCost = context.Services.UpgradeService.GetCostForLevel and context.Services.UpgradeService.GetCostForLevel("GrowSpeed", 0) or math.huge
	if spectacle and context.Services.WorldSpectacleService then
		context.Services.WorldSpectacleService.RunSpectacleDiagnostics(player)
	end
	local liveSpectacle = context.Services.WorldSpectacleService and context.Services.WorldSpectacleService.GetLiveEvidence() or nil

	if gameConfig.LaunchMode ~= "PrivateTest" then table.insert(critical, "LaunchMode is " .. tostring(gameConfig.LaunchMode)) end
	if gameConfig.BuildVersion ~= "0.1.0-private" then table.insert(critical, "BuildVersion is " .. tostring(gameConfig.BuildVersion)) end
	if gameConfig.FeatureFreeze ~= true then table.insert(critical, "FeatureFreeze is not true") end
	if flags.Monetization ~= false then table.insert(critical, "Monetization flag is not false") end
	if flags.Stealing ~= false or flags.Trading ~= false or flags.Pets ~= false then table.insert(critical, "Disabled feature flags are not all false") end
	if not loading then table.insert(critical, "LoadingPanel missing") end
	if not context.Services.FeedbackService.IsEnabled() then table.insert(warnings, "Feedback is not enabled") end
	if not plots or #plots:GetChildren() < 8 then table.insert(critical, "Map plots fewer than 8") end
	if not spotsFolder() or #spotsFolder():GetChildren() < 5 then table.insert(warnings, "Screenshot spots incomplete") end
	if not health then table.insert(warnings, "HealthCheck has not run yet") elseif (health.Failed or 0) > 0 then table.insert(critical, "HealthCheck has failures: " .. tostring(health.Failed)) end
	if not smoke then table.insert(warnings, "SmokeTest has not run yet") elseif (smoke.Failed or 0) > 0 then table.insert(critical, "SmokeTest has failures: " .. tostring(smoke.Failed)) end
	if not first10 then table.insert(critical, "First10Check has not run yet") elseif (first10.Failed or 0) > 0 then table.insert(critical, "First10Check has failures: " .. tostring(first10.Failed)) end
	if not spectacle then table.insert(critical, "SpectacleCheck has not run yet") elseif (spectacle.Failed or 0) > 0 then table.insert(critical, "SpectacleCheck has failures: " .. tostring(spectacle.Failed)) end
	if firstUpgradeCost > 250 then table.insert(critical, "First upgrade cost is too high: " .. tostring(firstUpgradeCost)) end
	if spectacle and not liveSpectacle then
		table.insert(critical, "Live spectacle evidence is missing")
	elseif spectacle and liveSpectacle then
		if (liveSpectacle.SnackRainClouds or 0) < 1 then table.insert(critical, "SnackRain cloud is not visibly spawned") end
		if (liveSpectacle.SnackRainFallingPickups or 0) < 10 then table.insert(critical, "SnackRain has fewer than 10 visible falling pickups") end
		if (liveSpectacle.MutationCrystals or 0) < 1 then table.insert(critical, "MutationCrystal is not visibly spawned") end
		if (liveSpectacle.VoidmiteNests or 0) < 1 or (liveSpectacle.InfestationVoidmites or 0) < 3 then table.insert(critical, "VoidInfestation nest or visible swarm is missing") end
		if (liveSpectacle.GoldenHungerIdols or 0) < 1 or (liveSpectacle.GoldenHungerHolograms or 0) < 1 then table.insert(critical, "GoldenHunger idol or wanted snack hologram is missing") end
		if (liveSpectacle.Phantoms or 0) < 1 then table.insert(critical, "PhantomSnackChase has no visible targets") end
	end
	if audio.Valid <= 0 or audio.Malformed > 0 or audio.BadVolume > 0 then table.insert(critical, "Audio config has invalid mix data") end
	if vfx.Configured < 20 or vfx.UnknownAliases > 0 then table.insert(critical, "VFX config has invalid keys or aliases") end
	if not assetReport then
		table.insert(warnings, "Asset report missing")
	else
		if (assetReport.Total or 0) < 30 then table.insert(critical, "Asset reference count is low: " .. tostring(assetReport.Total)) end
		if (assetReport.Missing or 0) > 0 then table.insert(warnings, "Missing imported assets: " .. tostring(assetReport.Missing)) end
		if (assetReport.Loose or 0) > 0 then table.insert(warnings, "Loose Workspace assets still present: " .. tostring(assetReport.Loose)) end
	end
	if #textHits > 0 then table.insert(warnings, "Player UI disallowed text hits: " .. table.concat(textHits, " | ")) end
	if #mobileWarnings > 0 then table.insert(warnings, "Mobile UI warnings: " .. table.concat(mobileWarnings, " | ")) end

	local ready = #critical == 0 and (#warnings == 0 and "YES" or "WARNINGS") or "NO"
	print("[PRIVATE TEST CHECK]")
	print("Ready: " .. ready)
	print("HealthCheck status: " .. summaryState(health))
	print("SmokeTest status: " .. summaryState(smoke))
	print("First10Check status: " .. summaryState(first10))
	print("SpectacleCheck status: " .. summaryState(spectacle))
	print("First upgrade cost: " .. tostring(firstUpgradeCost))
	print("Live spectacle: cloud=" .. tostring(liveSpectacle and liveSpectacle.SnackRainClouds or 0) .. " pickups=" .. tostring(liveSpectacle and liveSpectacle.SnackRainFallingPickups or 0) .. " crystal=" .. tostring(liveSpectacle and liveSpectacle.MutationCrystals or 0) .. " nest=" .. tostring(liveSpectacle and liveSpectacle.VoidmiteNests or 0) .. " swarm=" .. tostring(liveSpectacle and liveSpectacle.InfestationVoidmites or 0) .. " idol=" .. tostring(liveSpectacle and liveSpectacle.GoldenHungerIdols or 0) .. " hologram=" .. tostring(liveSpectacle and liveSpectacle.GoldenHungerHolograms or 0) .. " phantoms=" .. tostring(liveSpectacle and liveSpectacle.Phantoms or 0))
	print("Private test blocker count: " .. tostring(#critical))
	print("Audio valid? " .. tostring(audio.Valid) .. " valid, " .. tostring(audio.Disabled) .. " disabled, " .. tostring(audio.Malformed) .. " malformed")
	print("VFX valid? keys=" .. tostring(vfx.Configured) .. " cap=" .. tostring(vfx.MaxTemporaryEffects) .. " badAliases=" .. tostring(vfx.UnknownAliases))
	print("Asset status: organized=" .. tostring(assetReport and assetReport.Organized or "?") .. " loose=" .. tostring(assetReport and assetReport.Loose or "?") .. " missing=" .. tostring(assetReport and assetReport.Missing or "?") .. " total=" .. tostring(assetReport and assetReport.Total or "?"))
	print("Map plots 8/8? " .. tostring(plots and #plots:GetChildren() or 0))
	print("Loading screen working? " .. boolText(loading ~= nil))
	print("Feedback enabled? " .. boolText(context.Services.FeedbackService.IsEnabled()))
	print("FeatureFreeze true? " .. boolText(gameConfig.FeatureFreeze == true))
	print("Monetization disabled? " .. boolText(flags.Monetization == false))
	print("Trading disabled? " .. boolText(flags.Trading == false))
	print("Stealing disabled? " .. boolText(flags.Stealing == false))
	print("Pets disabled? " .. boolText(flags.Pets == false))
	print("Mobile UI warnings? " .. (#mobileWarnings > 0 and table.concat(mobileWarnings, " | ") or "none"))
	print("Player UI clean? " .. boolText(#textHits == 0))
	print("LaunchMode? " .. tostring(gameConfig.LaunchMode))
	print("BuildVersion? " .. tostring(gameConfig.BuildVersion))
	print("Critical issues: " .. (#critical > 0 and table.concat(critical, " | ") or "none"))
	print("Warnings: " .. (#warnings > 0 and table.concat(warnings, " | ") or "none"))
	print("Recommended tests: " .. table.concat(recommended, " | "))
	if player then
		context.Services.EconomyService.Notify(player, "Private test check: " .. ready .. ". See Output.")
	end
	return {
		Ready = ready,
		Critical = critical,
		Warnings = warnings,
		Health = health,
		Smoke = smoke,
		First10 = first10,
		Spectacle = spectacle,
		FirstUpgradeCost = firstUpgradeCost,
		LiveSpectacle = liveSpectacle,
		AssetReport = assetReport,
		MobileWarnings = mobileWarnings,
	}
end

return BugReportService
