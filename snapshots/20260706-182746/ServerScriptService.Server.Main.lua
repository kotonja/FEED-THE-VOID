local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerFolder = script.Parent
local ServicesFolder = ServerFolder:WaitForChild("Services")
local UtilFolder = ServerFolder:WaitForChild("Util")

local CooldownUtil = require(UtilFolder:WaitForChild("CooldownUtil"))
local ValidationUtil = require(UtilFolder:WaitForChild("ValidationUtil"))
local Maid = require(UtilFolder:WaitForChild("Maid"))
local SafeCall = require(UtilFolder:WaitForChild("SafeCall"))

local context = {
	Remotes = {
		RequestPlantSnack = Remotes:WaitForChild("RequestPlantSnack"),
		RequestHarvestSnack = Remotes:WaitForChild("RequestHarvestSnack"),
		RequestSellSnack = Remotes:WaitForChild("RequestSellSnack"),
		RequestFeedVoid = Remotes:WaitForChild("RequestFeedVoid"),
		RequestDisplaySnack = Remotes:WaitForChild("RequestDisplaySnack"),
		RequestClearVoidmite = Remotes:WaitForChild("RequestClearVoidmite"),
		RequestBuySeed = Remotes:WaitForChild("RequestBuySeed"),
		RequestBuyUpgrade = Remotes:WaitForChild("RequestBuyUpgrade"),
		RequestRebirth = Remotes:WaitForChild("RequestRebirth"),
		RequestSkipTutorial = Remotes:WaitForChild("RequestSkipTutorial"),
		RequestDebugCommand = Remotes:WaitForChild("RequestDebugCommand"),
		RequestClaimPlaytimeReward = Remotes:WaitForChild("RequestClaimPlaytimeReward"),
		RequestClaimDailyReward = Remotes:WaitForChild("RequestClaimDailyReward"),
		RequestCatchPhantomSnack = Remotes:WaitForChild("RequestCatchPhantomSnack"),
		RequestUpdateSettings = Remotes:WaitForChild("RequestUpdateSettings"),
		RequestCollectEventPickup = Remotes:WaitForChild("RequestCollectEventPickup"),
		RequestToggleItemLock = Remotes:WaitForChild("RequestToggleItemLock"),
		RequestClaimCollectionMilestone = Remotes:WaitForChild("RequestClaimCollectionMilestone"),
		RequestTeleportToPlot = Remotes:WaitForChild("RequestTeleportToPlot"),
		RequestSubmitFeedback = Remotes:WaitForChild("RequestSubmitFeedback"),
		PlaySound = Remotes:WaitForChild("PlaySound"),
		PlayEffect = Remotes:WaitForChild("PlayEffect"),
		NotifyClient = Remotes:WaitForChild("NotifyClient"),
		SyncPlayerData = Remotes:WaitForChild("SyncPlayerData"),
	},
	Config = {
		GameConfig = require(Shared:WaitForChild("GameConfig")),
		SnackConfig = require(Shared:WaitForChild("SnackConfig")),
		MutationConfig = require(Shared:WaitForChild("MutationConfig")),
		RarityConfig = require(Shared:WaitForChild("RarityConfig")),
		EventConfig = require(Shared:WaitForChild("EventConfig")),
		FormatNumbers = require(Shared:WaitForChild("FormatNumbers")),
		MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig")),
		GuidanceConfig = require(Shared:WaitForChild("GuidanceConfig")),
		SoundConfig = require(Shared:WaitForChild("SoundConfig")),
		VFXConfig = require(Shared:WaitForChild("VFXConfig")),
		FeatureFlags = require(Shared:WaitForChild("FeatureFlags")),
		LaunchPageConfig = require(Shared:WaitForChild("LaunchPageConfig")),
	},
	Services = {},
	Util = {
		SafeCall = SafeCall,
	},
	RuntimeOverrides = {
		HungerRequired = nil,
		GrowMultiplier = 1,
		VoidmiteSpeedMultiplier = 1,
	},
}

local serviceOrder = {
	"ProfileServiceWrapper",
	"AnalyticsService",
	"ActivityFeedService",
	"BalanceReportService",
	"AssetService",
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

for _, serviceName in ipairs(serviceOrder) do
	context.Services[serviceName] = require(ServicesFolder:WaitForChild(serviceName))
end

for _, serviceName in ipairs(serviceOrder) do
	local service = context.Services[serviceName]
	if service.Init then
		service.Init(context)
	end
end

for _, serviceName in ipairs(serviceOrder) do
	local service = context.Services[serviceName]
	if service.Start then
		service.Start()
	end
end

local remoteLimiter = CooldownUtil.Create(context.Config.GameConfig.RemoteCooldown, context.Config.GameConfig.RemoteCooldowns)
local playerMaids = {}
local profileRequiredRemotes = {
	RequestPlantSnack = true,
	RequestHarvestSnack = true,
	RequestSellSnack = true,
	RequestFeedVoid = true,
	RequestDisplaySnack = true,
	RequestClearVoidmite = true,
	RequestBuySeed = true,
	RequestBuyUpgrade = true,
	RequestRebirth = true,
	RequestSkipTutorial = true,
	RequestClaimPlaytimeReward = true,
	RequestClaimDailyReward = true,
	RequestCatchPhantomSnack = true,
	RequestUpdateSettings = true,
	RequestCollectEventPickup = true,
	RequestToggleItemLock = true,
	RequestClaimCollectionMilestone = true,
	RequestTeleportToPlot = true,
}

local plotRequiredRemotes = {
	RequestPlantSnack = true,
	RequestHarvestSnack = true,
	RequestSellSnack = true,
	RequestFeedVoid = true,
	RequestDisplaySnack = true,
	RequestClearVoidmite = true,
	RequestBuySeed = true,
	RequestBuyUpgrade = true,
	RequestRebirth = true,
	RequestCollectEventPickup = true,
	RequestTeleportToPlot = true,
}

local function featureEnabled(name)
	local flags = context.Config.FeatureFlags or {}
	return flags[name] ~= false
end

local function setLoadState(player, stateName)
	player:SetAttribute("ProfileLoading", stateName == "ProfileLoading")
	player:SetAttribute("ProfileReady", stateName == "ProfileReady" or stateName == "PlotAssigned" or stateName == "InitialSyncSent")
	player:SetAttribute("PlotAssigned", stateName == "PlotAssigned" or stateName == "InitialSyncSent")
	player:SetAttribute("InitialSyncSent", stateName == "InitialSyncSent")
end

local function passesCooldown(player, remoteName)
	return remoteLimiter:Check(player, remoteName)
end

local function bindRemote(remoteName, callback)
	context.Remotes[remoteName].OnServerEvent:Connect(function(player, ...)
		local security = context.Services.SecurityService
		if security and not security.CanProcess(player, remoteName) then
			return
		end
		if not ValidationUtil.SafeRemotePayload(context.Config.GameConfig.RemotePayloadLimit, ...) then
			if security then
				security.RecordInvalid(player, remoteName, "Too many arguments")
			end
			if context.Services.AnalyticsService then
				context.Services.AnalyticsService.RecordAction(player, "Remote rejected reason", remoteName .. ": too many arguments")
			end
			warn("[FEED THE VOID]", remoteName, "payload rejected: too many arguments")
			return
		end
		local data = context.Services.ProfileServiceWrapper.GetData(player)
		if profileRequiredRemotes[remoteName] and (player:GetAttribute("ProfileReady") ~= true or not data) then
			if security then
				security.RecordInvalid(player, remoteName, "Profile not loaded")
			end
			if context.Services.AnalyticsService then
				context.Services.AnalyticsService.RecordAction(player, "Remote rejected reason", remoteName .. ": profile not loaded")
			end
			context.Services.EconomyService.Notify(player, "Your lab is still loading.")
			return
		end
		if plotRequiredRemotes[remoteName] and player:GetAttribute("PlotAssigned") ~= true then
			if security then
				security.RecordInvalid(player, remoteName, "Plot not assigned")
			end
			if context.Services.AnalyticsService then
				context.Services.AnalyticsService.RecordAction(player, "Remote rejected reason", remoteName .. ": plot not assigned")
			end
			context.Services.EconomyService.Notify(player, "Your lab is still loading.")
			return
		end
		if not passesCooldown(player, remoteName) then
			if context.Services.AnalyticsService then
				context.Services.AnalyticsService.RecordAction(player, "Remote rejected reason", remoteName .. ": cooldown")
			end
			return
		end
		local ok, err = SafeCall.Call("Remote " .. tostring(remoteName), callback, player, ...)
		if not ok then
			warn("[FEED THE VOID]", remoteName, err)
			context.Services.EconomyService.Notify(player, "That action fizzled. Try again.")
		end
	end)
end

bindRemote("RequestPlantSnack", function(player, plate, snackId)
	context.Services.SnackService.PlantSnack(player, plate, snackId)
end)

bindRemote("RequestHarvestSnack", function(player, plate)
	context.Services.SnackService.HarvestSnack(player, plate)
end)

bindRemote("RequestSellSnack", function(player, itemId)
	context.Services.SnackService.SellSnack(player, itemId)
end)

bindRemote("RequestFeedVoid", function(player, itemId)
	context.Services.SnackService.FeedVoid(player, itemId)
end)

bindRemote("RequestDisplaySnack", function(player, itemId)
	context.Services.SnackService.DisplaySnack(player, itemId)
end)

bindRemote("RequestClearVoidmite", function(player, voidmite)
	context.Services.VoidmiteService.ClearVoidmite(player, voidmite)
end)

bindRemote("RequestBuySeed", function(player, snackId)
	context.Services.ShopService.BuySeed(player, snackId)
end)

bindRemote("RequestBuyUpgrade", function(player, upgradeId)
	context.Services.UpgradeService.BuyUpgrade(player, upgradeId)
end)

bindRemote("RequestRebirth", function(player)
	context.Services.RebirthService.TryRebirth(player)
end)

bindRemote("RequestSkipTutorial", function(player)
	context.Services.TutorialService.Skip(player)
end)

bindRemote("RequestClaimPlaytimeReward", function(player, seconds)
	context.Services.PlaytimeRewardService.Claim(player, seconds)
end)

bindRemote("RequestClaimDailyReward", function(player)
	context.Services.DailyRewardService.Claim(player)
end)

bindRemote("RequestCatchPhantomSnack", function(player, phantom)
	context.Services.PhantomSnackService.Catch(player, phantom)
end)

bindRemote("RequestUpdateSettings", function(player, key, value)
	context.Services.SettingsService.Update(player, key, value)
end)

bindRemote("RequestCollectEventPickup", function(player, pickup)
	context.Services.EventService.CollectEventPickup(player, pickup)
end)

bindRemote("RequestToggleItemLock", function(player, itemId)
	context.Services.InventoryService.ToggleItemLock(player, itemId)
end)

bindRemote("RequestClaimCollectionMilestone", function(player, milestoneId)
	context.Services.CollectionService.ClaimMilestone(player, milestoneId)
end)

bindRemote("RequestTeleportToPlot", function(player)
	context.Services.FailsafeService.TeleportToPlot(player, "request", false)
end)

bindRemote("RequestSubmitFeedback", function(player, payload)
	context.Services.FeedbackService.Submit(player, payload)
end)

local function isOwner(player)
	local owners = context.Config.GameConfig.DebugOwnerUserIds or {}
	for _, userId in ipairs(owners) do
		if tonumber(userId) == player.UserId then
			return true
		end
	end
	return false
end

local function debugAllowed(player)
	if not featureEnabled("DebugCommands") then
		return false
	end
	if not context.Config.GameConfig.DebugMode then
		return false
	end
	if isOwner(player) then
		return true
	end
	local soft = context.Config.GameConfig.SoftLaunch or {}
	if RunService:IsStudio() and soft.AllowDebugInStudio ~= false then
		return true
	end
	return context.Config.GameConfig.LaunchMode ~= "Production" and soft.RequireOwnerForDebugOutsideStudio ~= true
end

local function dataResetAllowed(player)
	local soft = context.Config.GameConfig.SoftLaunch or {}
	return isOwner(player) or (RunService:IsStudio() and soft.AllowDataResetInStudio ~= false)
end

local function idInList(list, userId)
	for _, value in ipairs(list or {}) do
		if tonumber(value) == userId then
			return true
		end
	end
	return false
end

local function privateTestAllowed(player)
	local gameConfig = context.Config.GameConfig
	local private = gameConfig.PrivateTest or {}
	if gameConfig.LaunchMode ~= "PrivateTest" or RunService:IsStudio() then
		return true
	end
	if isOwner(player) or idInList(gameConfig.PrivateTestUserIds, player.UserId) then
		return true
	end
	if tonumber(gameConfig.PrivateTestGroupId) and tonumber(gameConfig.PrivateTestGroupId) > 0 then
		local ok, inGroup = pcall(function()
			return player:IsInGroup(tonumber(gameConfig.PrivateTestGroupId))
		end)
		if ok and inGroup then
			return true
		end
	end
	if private.KickUnlistedPlayers ~= true then
		return true
	end
	return false
end

local function normalizeDebugCommandText(value)
	if type(value) == "table" then
		value = value.Command
			or value.command
			or value.Text
			or value.text
			or value.Message
			or value.message
			or value[1]
			or value.payload
			or value.remotePayload
	end
	return tostring(value or "")
end

local function runDebugCommand(player, commandText)
	if not debugAllowed(player) then
		return
	end
	commandText = normalizeDebugCommandText(commandText)
	local command, a, b = commandText:match("^!(%S+)%s*(%S*)%s*(%S*)")
	if not command then
		return
	end
	if command == "coins" and context.Config.GameConfig.DebugGiveCoins then
		context.Services.EconomyService.AddCoins(player, tonumber(a) or 5000)
	elseif command == "seed" then
		context.Services.EconomyService.AddSeeds(player, a ~= "" and a or "CookieRock", tonumber(b) or 5)
	elseif command == "giveitem" then
		local snackId = a ~= "" and a or "CookieRock"
		local mutationId = b ~= "" and b or "Normal"
		local snack = context.Config.SnackConfig[snackId]
		local mutation = context.Config.MutationConfig[mutationId]
		if snack and mutation then
			local item = {
				UniqueId = game:GetService("HttpService"):GenerateGUID(false),
				SnackId = snackId,
				MutationId = mutationId,
				CreatedAt = os.time(),
				ValueMultiplier = mutation.ValueMultiplier or 1,
				DisplayName = ((mutationId ~= "Normal" and mutation.DisplayName .. " " or "") .. snack.DisplayName),
				Locked = false,
			}
			local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
			item.EstimatedSellValue = sellValue
			item.EstimatedVoidValue = voidValue
			item.PassiveIncome = passiveIncome
			context.Services.InventoryService.AddItem(player, item)
			context.Services.EconomyService.Notify(player, "Debug item granted: " .. item.DisplayName)
		else
			context.Services.EconomyService.Notify(player, "Debug item failed: invalid snack or mutation.")
		end
	elseif command == "voidfill" then
		context.Services.VoidService.AddHunger(player, context.Services.VoidService.GetRequired(), { DisplayName = "debug snack", MutationId = "Normal" })
	elseif command == "event" and a ~= "" then
		context.Services.EventService.StartEvent(a)
	elseif command == "eventstatus" then
		context.Services.EventService.PrintStatus(player)
	elseif command == "endevent" then
		context.Services.EventService.EndEvent()
		context.Services.EconomyService.Notify(player, "Debug: event ended.")
	elseif command == "voidmites" then
		context.Services.VoidmiteService.PrintStatus(player)
	elseif command == "plants" then
		context.Services.SnackService.PrintPlantStatus(player)
	elseif command == "inventorycheck" then
		context.Services.InventoryService.PrintInventoryCheck(player)
	elseif command == "playerprogress" then
		local data = context.Services.ProfileServiceWrapper.GetData(player)
		local stats = context.Services.StatsService.Serialize(player)
		local collections = context.Services.CollectionService.Serialize(player)
		local quests = context.Services.QuestService.Serialize(player)
		if data then
			local line = string.format(
				"[FEED THE VOID][Progress] %s coins=%d vt=%d rebirths=%d planted=%d inventory=%d displayed=%d harvested=%d questsDone=%d discoveries=%d",
				player.Name,
				tonumber(data.Coins) or 0,
				tonumber(data.VoidTokens) or 0,
				tonumber(data.Rebirths) or 0,
				#(data.PlantedSnacks or {}),
				#(data.Inventory or {}),
				#(data.DisplayedSnacks or {}),
				tonumber(stats.SnacksHarvested) or 0,
				tonumber(quests.CompletedCount) or 0,
				tonumber(collections.SnacksDiscovered) or 0
			)
			print(line)
			context.Services.EconomyService.Notify(player, "Progress: " .. tostring(stats.SnacksHarvested or 0) .. " harvested | " .. tostring(quests.CompletedCount or 0) .. " quests | " .. tostring(collections.SnacksDiscovered or 0) .. " snacks found")
		end
	elseif command == "fastgrowth" then
		context.Config.GameConfig.DebugFastGrowth = (a == "on")
		context.Services.EconomyService.Notify(player, "Debug fast growth: " .. tostring(context.Config.GameConfig.DebugFastGrowth and "on" or "off"))
	elseif command == "resetplot" then
		context.Services.SnackService.ClearPlotVisuals(player, true)
		context.Services.VoidmiteService.ClearForPlayer(player)
		context.Services.PlotService.TeleportToPlot(player)
		context.Services.EconomyService.Notify(player, "Debug: plot visuals reset.")
	elseif command == "health" then
		context.Services.HealthCheckService.Run(player, "debug-command")
	elseif command == "smoketest" then
		context.Services.SmokeTestService.Run(player, "debug-command")
	elseif command == "first10check" then
		context.Services.SmokeTestService.First10Check(player)
	elseif command == "snapshot" then
		context.Services.BugReportService.PrintSnapshot(player, a)
	elseif command == "screenshotspots" then
		context.Services.BugReportService.PrintScreenshotSpots(player)
	elseif command == "camera" and a ~= "" then
		context.Services.BugReportService.MoveCamera(player, a)
	elseif command == "privatetestcheck" then
		context.Services.BugReportService.PrivateTestCheck(player)
	elseif command == "feedback" then
		context.Services.FeedbackService.PrintRecent(player)
	elseif command == "clearfeedback" then
		context.Services.FeedbackService.Clear(player)
	elseif command == "soundtest" and a ~= "" then
		context.Services.AudioService.TestSound(player, a)
	elseif command == "soundtestall" then
		context.Services.AudioService.TestSequence(player)
		context.Services.EconomyService.Notify(player, "Debug audio test sequence started.")
	elseif command == "stopsounds" then
		context.Services.AudioService.StopAllLoops(player)
		context.Services.EconomyService.Notify(player, "Debug: client audio loops stopped.")
	elseif command == "soundstatus" then
		context.Services.AudioService.PrintStatus(player)
	elseif command == "mixcheck" then
		context.Services.AudioService.PrintMixCheck(player)
	elseif command == "vfx" and a ~= "" then
		context.Services.VFXService.TestEffect(player, a)
	elseif command == "vfxall" then
		context.Services.VFXService.TestSequence(player)
		context.Services.EconomyService.Notify(player, "Debug VFX test sequence started.")
	elseif command == "clearvfx" then
		context.Services.VFXService.ClearForPlayer(player)
		context.Services.EconomyService.Notify(player, "Debug: temporary client VFX cleared.")
	elseif command == "vfxstatus" then
		context.Services.VFXService.PrintStatus(player)
	elseif command == "disableevent" and a ~= "" then
		context.Services.EventService.DisableEvent(a, "debug command")
		context.Services.EconomyService.Notify(player, "Debug: disabled event " .. tostring(a) .. " for this server.")
	elseif command == "enableevent" and a ~= "" then
		context.Services.EventService.EnableEvent(a)
		context.Services.EconomyService.Notify(player, "Debug: enabled event " .. tostring(a) .. " for this server.")
	elseif command == "sethungerrequired" then
		local value = tonumber(a)
		context.RuntimeOverrides.HungerRequired = value and math.max(1, math.floor(value)) or nil
		context.Services.EconomyService.SyncAll()
		context.Services.EconomyService.Notify(player, "Void hunger required override: " .. tostring(context.RuntimeOverrides.HungerRequired or "default"))
	elseif command == "setgrowmultiplier" then
		local value = tonumber(a)
		context.RuntimeOverrides.GrowMultiplier = value and math.clamp(value, 0.05, 25) or 1
		context.Services.EconomyService.Notify(player, "Grow multiplier override: " .. tostring(context.RuntimeOverrides.GrowMultiplier))
	elseif command == "setvoidmitespeed" then
		local value = tonumber(a)
		context.RuntimeOverrides.VoidmiteSpeedMultiplier = value and math.clamp(value, 0.05, 25) or 1
		context.Services.EconomyService.Notify(player, "Voidmite speed override: " .. tostring(context.RuntimeOverrides.VoidmiteSpeedMultiplier))
	elseif command == "resetserverbalances" then
		context.RuntimeOverrides.HungerRequired = nil
		context.RuntimeOverrides.GrowMultiplier = 1
		context.RuntimeOverrides.VoidmiteSpeedMultiplier = 1
		context.Config.GameConfig.DebugFastGrowth = false
		context.Config.GameConfig.DebugFastVoid = false
		context.Services.EconomyService.SyncAll()
		context.Services.EconomyService.Notify(player, "Debug balance overrides reset.")
	elseif command == "serverstatus" then
		local eventStatus = context.Services.EventService.GetStatus()
		local securityStatus = context.Services.SecurityService.GetSummary()
		local healthStatus = context.Services.HealthCheckService.GetLastSummary()
		local line = string.format(
			"[FEED THE VOID][ServerStatus] build=%s launch=%s players=%d datastore=%s event=%s objects=%d voidmites=%d phantoms=%d invalidRemotes=%d health=%s/%s/%s overrides={hunger=%s,grow=%s,voidmites=%s}",
			tostring(context.Config.GameConfig.BuildVersion or context.Config.GameConfig.Phase),
			tostring(context.Config.GameConfig.LaunchMode),
			#Players:GetPlayers(),
			tostring(context.Services.ProfileServiceWrapper.GetDataStoreMode()),
			tostring(eventStatus.ActiveEventName or "none"),
			tonumber(eventStatus.EventObjects) or 0,
			tonumber(context.Services.VoidmiteService.CountActive()) or 0,
			tonumber(context.Services.PhantomSnackService.CountActive()) or 0,
			tonumber(securityStatus.TotalInvalid) or 0,
			healthStatus and tostring(healthStatus.Passed) or "?",
			healthStatus and tostring(healthStatus.Warnings) or "?",
			healthStatus and tostring(healthStatus.Failed) or "?",
			tostring(context.RuntimeOverrides.HungerRequired or "default"),
			tostring(context.RuntimeOverrides.GrowMultiplier or 1),
			tostring(context.RuntimeOverrides.VoidmiteSpeedMultiplier or 1)
		)
		print(line)
		context.Services.EconomyService.Notify(player, "Server: " .. tostring(context.Config.GameConfig.LaunchMode) .. " | players " .. tostring(#Players:GetPlayers()) .. " | event " .. tostring(eventStatus.ActiveEventName or "none") .. " | voidmites " .. tostring(context.Services.VoidmiteService.CountActive()))
	elseif command == "balancereport" then
		context.Services.BalanceReportService.Run(player)
	elseif command == "unlockshop" then
		context.Services.ShopService.UnlockAllForSession(player)
	elseif command == "tutorialreset" then
		context.Services.TutorialService.Reset(player)
	elseif command == "guidetest" then
		context.Services.OnboardingService.SetTemporaryGoal(player, {
			Id = "DebugGuideToLab",
			Text = "Guidance test: follow the beam to your lab",
			TargetType = "Plot",
			Priority = 999,
		})
		context.Services.EconomyService.Sync(player)
		context.Services.EconomyService.Notify(player, "Debug guidance target sent.")
	elseif command == "simulatefirstsession" then
		local data = context.Services.ProfileServiceWrapper.GetData(player)
		if data then
			data.TutorialStep = 1
			data.TutorialCompleted = false
			data.Inventory = {}
			data.DisplayedSnacks = {}
			data.PlantedSnacks = {}
			data.Seeds = table.clone(context.Config.GameConfig.StartingSeeds)
			context.Services.SnackService.ClearPlotVisuals(player, true)
			context.Services.ProfileServiceWrapper.MarkDirty(player)
			context.Services.TutorialService.SendStep(player)
			context.Services.EconomyService.Sync(player)
			context.Services.EconomyService.Notify(player, "Debug: first session simulated.")
		end
	elseif command == "resetcurrentrun" then
		local data = context.Services.ProfileServiceWrapper.GetData(player)
		if data then
			data.Coins = context.Config.GameConfig.StartingCoins
			data.VoidTokens = 0
			data.Seeds = table.clone(context.Config.GameConfig.StartingSeeds)
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
			data.LastOfflineRewards = nil
			context.Services.SnackService.ClearPlotVisuals(player, true)
			context.Services.VoidmiteService.ClearForPlayer(player)
			context.Services.ProfileServiceWrapper.MarkDirty(player)
			context.Services.EconomyService.Sync(player)
			context.Services.EconomyService.Notify(player, "Debug: current test run reset.")
		end
	elseif command == "cleardata" and a == "confirm" and dataResetAllowed(player) then
		context.Services.SnackService.ClearPlotVisuals(player, true)
		context.Services.VoidmiteService.ClearForPlayer(player)
		context.Services.ProfileServiceWrapper.ResetPlayerData(player)
		context.Services.QuestService.Ensure(player)
		context.Services.CollectionService.Ensure(player)
		context.Services.EconomyService.Sync(player)
		context.Services.EconomyService.Notify(player, "Debug: profile reset for this test session.")
	end
end

bindRemote("RequestDebugCommand", runDebugCommand)

local function callServiceHook(hookName, player)
	for _, serviceName in ipairs(serviceOrder) do
		local service = context.Services[serviceName]
		local hook = service and service[hookName]
		if hook then
			local ok, err = SafeCall.Call(serviceName .. "." .. hookName, hook, player)
			if not ok then
				warn("[FEED THE VOID]", serviceName .. "." .. hookName, err)
			end
		end
	end
end

local function setupPlayer(player)
	if not privateTestAllowed(player) then
		player:Kick((context.Config.GameConfig.PrivateTest or {}).KickMessage or "FEED THE VOID is in private testing right now.")
		return
	end
	if playerMaids[player] then
		playerMaids[player]:DoCleaning()
	end
	local maid = Maid.new()
	playerMaids[player] = maid
	setLoadState(player, "ProfileLoading")
	context.Services.ProfileServiceWrapper.LoadPlayer(player)
	if not context.Services.ProfileServiceWrapper.GetData(player) then
		context.Services.EconomyService.Notify(player, "Your lab is still loading.")
		return
	end
	setLoadState(player, "ProfileReady")
	context.Services.AnalyticsService.PlayerJoined(player)
	context.Services.AnalyticsService.RecordAction(player, "ProfileLoaded")
	context.Services.PlotService.AssignPlot(player)
	setLoadState(player, "PlotAssigned")
	context.Services.AnalyticsService.RecordAction(player, "PlotAssigned", context.Services.PlotService.GetPlotId(player))
	context.Services.MapService.TeleportPlayerSafe(player)
	context.Services.QuestService.Ensure(player)
	context.Services.CollectionService.Ensure(player)
	context.Services.SnackService.RestorePlanted(player)
	context.Services.SnackService.RestoreDisplayed(player)
	context.Services.SnackService.ApplyOfflineDisplayIncome(player)
	context.Services.VisitRewardService.ApplyJoinReward(player)
	context.Services.TutorialService.SendStep(player)
	context.Services.EconomyService.Sync(player)
	setLoadState(player, "InitialSyncSent")
	for _, delaySeconds in ipairs({ 1, 5, 15 }) do
		task.delay(delaySeconds, function()
			if player.Parent == Players then
				context.Services.EconomyService.Sync(player)
			end
		end)
	end
	maid:GiveTask(player.Chatted:Connect(function(message)
		runDebugCommand(player, message)
	end))
	maid:GiveTask(player.CharacterAdded:Connect(function()
		task.wait(0.25)
		if player.Parent == Players then
			context.Services.PlotService.TeleportToPlot(player)
		end
	end))
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	if playerMaids[player] then
		playerMaids[player]:DoCleaning()
		playerMaids[player] = nil
	end
	callServiceHook("PlayerRemoving", player)
	context.Services.SnackService.ClearPlotVisuals(player)
	context.Services.VoidmiteService.ClearForPlayer(player)
	context.Services.PlotService.ReleasePlot(player)
	context.Services.FailsafeService.ForgetPlayer(player)
	context.Services.ProfileServiceWrapper.ReleasePlayer(player)
	remoteLimiter:Clear(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

print("[FEED THE VOID] Phase 13 private test server loaded.")
