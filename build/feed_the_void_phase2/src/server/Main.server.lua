local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerFolder = script.Parent
local ServicesFolder = ServerFolder:WaitForChild("Services")

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
		NotifyClient = Remotes:WaitForChild("NotifyClient"),
		SyncPlayerData = Remotes:WaitForChild("SyncPlayerData"),
	},
	Config = {
		GameConfig = require(Shared:WaitForChild("GameConfig")),
		SnackConfig = require(Shared:WaitForChild("SnackConfig")),
		MutationConfig = require(Shared:WaitForChild("MutationConfig")),
		EventConfig = require(Shared:WaitForChild("EventConfig")),
		FormatNumbers = require(Shared:WaitForChild("FormatNumbers")),
	},
	Services = {},
}

local serviceOrder = {
	"ProfileServiceWrapper",
	"AnalyticsService",
	"AssetService",
	"EconomyService",
	"InventoryService",
	"PlotService",
	"ValidationService",
	"CollectionService",
	"QuestService",
	"UpgradeService",
	"TutorialService",
	"EventService",
	"VoidService",
	"VoidmiteService",
	"ShopService",
	"RebirthService",
	"VisitRewardService",
	"SnackService",
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

local lastRemoteUse = {}

local function passesCooldown(player, remoteName)
	local now = os.clock()
	lastRemoteUse[player] = lastRemoteUse[player] or {}
	local last = lastRemoteUse[player][remoteName] or 0
	local cooldown = context.Config.GameConfig.RemoteCooldowns[remoteName] or context.Config.GameConfig.RemoteCooldown
	if now - last < cooldown then
		return false
	end
	lastRemoteUse[player][remoteName] = now
	return true
end

local function bindRemote(remoteName, callback)
	context.Remotes[remoteName].OnServerEvent:Connect(function(player, ...)
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

local function runDebugCommand(player, commandText)
	if not context.Config.GameConfig.DebugMode then
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
	end
end

bindRemote("RequestDebugCommand", runDebugCommand)

local function setupPlayer(player)
	context.Services.ProfileServiceWrapper.LoadPlayer(player)
	context.Services.AnalyticsService.PlayerJoined(player)
	context.Services.PlotService.AssignPlot(player)
	context.Services.QuestService.Ensure(player)
	context.Services.CollectionService.Ensure(player)
	context.Services.SnackService.RestoreDisplayed(player)
	context.Services.VisitRewardService.ApplyJoinReward(player)
	context.Services.TutorialService.SendStep(player)
	context.Services.EconomyService.Sync(player)
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
	lastRemoteUse[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

print("[FEED THE VOID] Phase 2 server loaded.")
