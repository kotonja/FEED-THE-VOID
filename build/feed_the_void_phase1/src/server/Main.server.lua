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
		RequestRebirth = Remotes:WaitForChild("RequestRebirth"),
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
	"EconomyService",
	"InventoryService",
	"PlotService",
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
	if now - last < context.Config.GameConfig.RemoteCooldown then
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

bindRemote("RequestDisplaySnack", function(player, itemId, shelf)
	context.Services.SnackService.DisplaySnack(player, itemId, shelf)
end)

bindRemote("RequestClearVoidmite", function(player, voidmite)
	context.Services.VoidmiteService.ClearVoidmite(player, voidmite)
end)

bindRemote("RequestBuySeed", function(player, snackId)
	context.Services.ShopService.BuySeed(player, snackId)
end)

bindRemote("RequestRebirth", function(player)
	context.Services.RebirthService.TryRebirth(player)
end)

Players.PlayerAdded:Connect(function(player)
	context.Services.ProfileServiceWrapper.LoadPlayer(player)
	context.Services.AnalyticsService.PlayerJoined(player)
	context.Services.PlotService.AssignPlot(player)
	context.Services.VisitRewardService.ApplyJoinReward(player)
	context.Services.EconomyService.Sync(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		context.Services.PlotService.TeleportToPlot(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	context.Services.PlotService.ReleasePlot(player)
	context.Services.ProfileServiceWrapper.ReleasePlayer(player)
	lastRemoteUse[player] = nil
end)

print("[FEED THE VOID] Phase 1 server loaded.")
