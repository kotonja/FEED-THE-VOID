local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemoteEvent(remoteName)
	local remote = Remotes:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = Remotes
	end
	return remote
end
local ServerFolder = script.Parent
local ServicesFolder = ServerFolder:WaitForChild("Services")
local UtilFolder = ServerFolder:WaitForChild("Util")

local CooldownUtil = require(UtilFolder:WaitForChild("CooldownUtil"))
local ValidationUtil = require(UtilFolder:WaitForChild("ValidationUtil"))

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
		NotifyClient = Remotes:WaitForChild("NotifyClient"),
				SyncPlayerData = Remotes:WaitForChild("SyncPlayerData"),
		PlayEffect = getRemoteEvent("PlayEffect"),
	},
	Config = {
		GameConfig = require(Shared:WaitForChild("GameConfig")),
		SnackConfig = require(Shared:WaitForChild("SnackConfig")),
		MutationConfig = require(Shared:WaitForChild("MutationConfig")),
		EventConfig = require(Shared:WaitForChild("EventConfig")),
		FormatNumbers = require(Shared:WaitForChild("FormatNumbers")),
		MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig")),
	},
	Services = {},
}

local serviceOrder = {
	"ProfileServiceWrapper",
	"AnalyticsService",
	"ActivityFeedService",
	"AssetService",
	"MapService",
	"StatsService",
	"BadgeAwardService",
	"SettingsService",
	"EconomyService",
	"InventoryService",
	"PlotService",
	"ValidationService",
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

local function passesCooldown(player, remoteName)
	return remoteLimiter:Check(player, remoteName)
end

local function bindRemote(remoteName, callback)
	context.Remotes[remoteName].OnServerEvent:Connect(function(player, ...)
		if not ValidationUtil.SafeRemotePayload(context.Config.GameConfig.RemotePayloadLimit, ...) then
			warn("[FEED THE VOID]", remoteName, "payload rejected: too many arguments")
			return
		end
		if not passesCooldown(player, remoteName) then
			return
		end
		local ok, err = pcall(callback, player, ...)
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

local function runDebugCommand(player, commandText)
	if not debugAllowed(player) then
		return
	end
	commandText = tostring(commandText or "")
	local command, a, b = commandText:match("^!(%S+)%s*(%S*)%s*(%S*)")
	if not command then
		return
	end
	if command == "coins" and context.Config.GameConfig.DebugGiveCoins then
		context.Services.EconomyService.AddCoins(player, tonumber(a) or 5000)
	elseif command == "seed" then
		context.Services.EconomyService.AddSeeds(player, a ~= "" and a or "CookieRock", tonumber(b) or 5)
	elseif command == "voidfill" then
		context.Services.VoidService.AddHunger(player, context.Services.VoidService.GetRequired(), { DisplayName = "debug snack", MutationId = "Normal" })
	elseif command == "event" and a ~= "" then
		context.Services.EventService.StartEvent(a)
	elseif command == "fastgrowth" then
		context.Config.GameConfig.DebugFastGrowth = (a == "on")
	elseif command == "resetplot" then
		context.Services.SnackService.ClearPlotVisuals(player)
		context.Services.VoidmiteService.ClearForPlayer(player)
		context.Services.PlotService.TeleportToPlot(player)
		context.Services.EconomyService.Notify(player, "Debug: plot visuals reset.")
	elseif command == "health" then
		context.Services.HealthCheckService.Run(player, "debug-command")
	elseif command == "cleardata" and a == "confirm" and dataResetAllowed(player) then
		context.Services.SnackService.ClearPlotVisuals(player)
		context.Services.VoidmiteService.ClearForPlayer(player)
		context.Services.ProfileServiceWrapper.ResetPlayerData(player)
		context.Services.QuestService.Ensure(player)
		context.Services.CollectionService.Ensure(player)
		context.Services.EconomyService.Sync(player)
		context.Services.EconomyService.Notify(player, "Debug: profile reset for this test session.")
	end
end

bindRemote("RequestDebugCommand", runDebugCommand)

local function setupPlayer(player)
	context.Services.ProfileServiceWrapper.LoadPlayer(player)
	context.Services.AnalyticsService.PlayerJoined(player)
	context.Services.PlotService.AssignPlot(player)
	context.Services.MapService.TeleportPlayerSafe(player)
	context.Services.QuestService.Ensure(player)
	context.Services.CollectionService.Ensure(player)
	context.Services.SnackService.RestoreDisplayed(player)
	context.Services.VisitRewardService.ApplyJoinReward(player)
	context.Services.TutorialService.SendStep(player)
	context.Services.EconomyService.Sync(player)
	for _, delaySeconds in ipairs({ 1, 5, 15 }) do
		task.delay(delaySeconds, function()
			if player.Parent == Players then
				context.Services.EconomyService.Sync(player)
			end
		end)
	end
	player.Chatted:Connect(function(message)
		runDebugCommand(player, message)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		context.Services.PlotService.TeleportToPlot(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	context.Services.SnackService.ClearPlotVisuals(player)
	context.Services.VoidmiteService.ClearForPlayer(player)
	context.Services.PlotService.ReleasePlot(player)
	context.Services.ProfileServiceWrapper.ReleasePlayer(player)
	remoteLimiter:Clear(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

print("[FEED THE VOID] Phase 6 premium polish server loaded.")
