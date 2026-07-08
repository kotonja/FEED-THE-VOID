local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		"NotifyClient",
		"SyncPlayerData",
	}
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
	local summary = {
		Reason = reason or "manual",
		StartedAt = os.time(),
		Passed = 0,
		Warnings = 0,
		Failed = 0,
		Checks = {},
	}

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	for _, remoteName in ipairs(expectedRemotes()) do
		local remote = remotesFolder and remotesFolder:FindFirstChild(remoteName)
		record(summary, remote ~= nil, "Remote " .. remoteName, remote and remote.ClassName or "missing")
	end

	for _, serviceName in ipairs({
		"ProfileServiceWrapper",
		"AssetService",
		"ValidationService",
		"HealthCheckService",
		"ActivityFeedService",
		"SettingsService",
		"EventService",
		"PhantomSnackService",
		"DailyRewardService",
		"PlaytimeRewardService",
	}) do
		record(summary, context.Services[serviceName] ~= nil, "Service " .. serviceName, context.Services[serviceName] and "loaded" or "missing")
	end

	local world = workspace:FindFirstChild("GameWorld")
	local plots = world and world:FindFirstChild("Plots")
	local central = world and world:FindFirstChild("CentralVoid")
	record(summary, world ~= nil, "Workspace.GameWorld", world and "present" or "missing")
	record(summary, childCount(plots) >= 1, "GameWorld.Plots", tostring(childCount(plots)) .. " plots")
	record(summary, central ~= nil, "GameWorld.CentralVoid", central and "present" or "missing")
	for _, folderName in ipairs({ "ActiveSnacks", "ActiveVoidmites", "EventObjects", "Stations", "SpawnPoints" }) do
		record(summary, world and world:FindFirstChild(folderName) ~= nil, "GameWorld." .. folderName, world and (world:FindFirstChild(folderName) and "present" or "missing") or "missing")
	end

	for _, assetKey in ipairs(AssetReferences.RequiredAssetKeys or {}) do
		local hasAsset = context.Services.AssetService.HasAsset(assetKey)
		record(summary, hasAsset, "Asset " .. assetKey, hasAsset and "imported" or "fallback active", true)
	end

	record(summary, type(context.Config.SnackConfig.Order) == "table" and #context.Config.SnackConfig.Order >= 1, "SnackConfig.Order", tostring(#(context.Config.SnackConfig.Order or {})) .. " snacks")
	record(summary, type(context.Config.MutationConfig.Normal) == "table", "MutationConfig.Normal", context.Config.MutationConfig.Normal and "present" or "missing")
	record(summary, type(context.Config.EventConfig.Order) == "table" and #context.Config.EventConfig.Order >= 1, "EventConfig.Order", tostring(#(context.Config.EventConfig.Order or {})) .. " events")
	record(summary, type(context.Config.GameConfig.UpgradeConfig) == "table", "UpgradeConfig", context.Config.GameConfig.UpgradeConfig and "present" or "missing")
	record(summary, type(context.Config.GameConfig.SettingsDefaults) == "table" and context.Config.GameConfig.SettingsDefaults.LowDetailMode ~= nil, "Settings.LowDetailMode", "configured")
	record(summary, context.Config.GameConfig.DebugMode ~= true or context.Config.GameConfig.LaunchMode ~= "Production", "DebugMode", "LaunchMode=" .. tostring(context.Config.GameConfig.LaunchMode), true)

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
	print(prefix .. " " .. tostring(summary.Reason) .. ": " .. tostring(summary.Passed) .. " pass, " .. tostring(summary.Warnings) .. " warn, " .. tostring(summary.Failed) .. " fail.")
	for _, entry in ipairs(summary.Checks) do
		if not entry.Ok then
			local line = prefix .. " " .. (entry.WarnOnly and "WARN " or "FAIL ") .. entry.Label .. " - " .. tostring(entry.Detail)
			if entry.WarnOnly then
				warn(line)
			else
				warn(line)
			end
		end
	end
end

function HealthCheckService.GetLastSummary()
	return lastSummary
end

return HealthCheckService
