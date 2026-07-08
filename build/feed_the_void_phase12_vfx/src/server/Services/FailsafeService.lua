local Players = game:GetService("Players")

local FailsafeService = {}

local hintCooldowns = {}

local function config()
	return FailsafeService.Context.Config.GameConfig.Failsafes or {}
end

local function now()
	return os.time()
end

local function totalSeeds(data)
	local total = 0
	for _, count in pairs(data.Seeds or {}) do
		total += math.max(0, tonumber(count) or 0)
	end
	return total
end

local function inventoryCount(data)
	return #(data.Inventory or {})
end

local function plantedCount(data)
	return #(data.PlantedSnacks or {})
end

local function readySnackCount(data)
	local currentTime = now()
	local ready = 0
	for _, record in ipairs(data.PlantedSnacks or {}) do
		local stage = tonumber(record.CurrentStage) or 1
		local plantedAt = tonumber(record.PlantedAt) or currentTime
		local growTime = math.max(1, tonumber(record.GrowTime) or 1)
		if stage >= 3 or currentTime - plantedAt >= growTime then
			ready += 1
		end
	end
	return ready
end

local function seedCost(context, seedId)
	local snack = context.Config.SnackConfig[seedId]
	return snack and tonumber(snack.SeedCost) or 25
end

local function notifyThrottled(player, key, message, cooldown)
	hintCooldowns[player] = hintCooldowns[player] or {}
	local nextAt = hintCooldowns[player][key] or 0
	if os.clock() < nextAt then
		return
	end
	hintCooldowns[player][key] = os.clock() + (cooldown or 20)
	FailsafeService.Context.Services.EconomyService.Notify(player, message)
end

local function ensureFailsafeState(data)
	data.Failsafes = type(data.Failsafes) == "table" and data.Failsafes or {}
	data.Failsafes.LastEmergencySeedAt = tonumber(data.Failsafes.LastEmergencySeedAt) or 0
	data.Failsafes.LastTeleportToPlotAt = tonumber(data.Failsafes.LastTeleportToPlotAt) or 0
	return data.Failsafes
end

function FailsafeService.Init(context)
	FailsafeService.Context = context
end

function FailsafeService.Start()
	task.spawn(function()
		while true do
			task.wait((FailsafeService.Context.Config.GameConfig.Performance or {}).FailsafeCheckInterval or config().CheckInterval or 10)
			for _, player in ipairs(Players:GetPlayers()) do
				FailsafeService.CheckPlayer(player, "tick")
			end
		end
	end)
end

function FailsafeService.GrantEmergencySeed(player, reason)
	local context = FailsafeService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	local state = ensureFailsafeState(data)
	local seedId = config().EmergencySeedId or "CookieRock"
	local cooldown = config().EmergencySeedCooldown or 120
	if now() - state.LastEmergencySeedAt < cooldown then
		return false
	end
	state.LastEmergencySeedAt = now()
	data.Seeds = type(data.Seeds) == "table" and data.Seeds or {}
	data.Seeds[seedId] = (tonumber(data.Seeds[seedId]) or 0) + (config().EmergencySeedAmount or 1)
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Notify(player, "Rescue seed granted. Plant it on an empty plate.")
	context.Services.EconomyService.Sync(player)
	if context.Services.AnalyticsService then
		context.Services.AnalyticsService.RecordFunnel(player, "EmergencySeed", reason or "unknown")
	end
	return true
end

function FailsafeService.CheckPlayer(player, reason)
	local context = FailsafeService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	if not context.Services.PlotService.GetPlot(player) then
		context.Services.PlotService.AssignPlot(player)
	end

	local state = ensureFailsafeState(data)
	local seedId = config().EmergencySeedId or "CookieRock"
	local starterCost = seedCost(context, seedId)
	local hasNoSeeds = totalSeeds(data) <= 0
	local hasNoItems = inventoryCount(data) <= 0
	local hasNoPlanted = plantedCount(data) <= 0
	if hasNoSeeds and hasNoItems and hasNoPlanted and (tonumber(data.Coins) or 0) < starterCost then
		return FailsafeService.GrantEmergencySeed(player, reason or "stuck")
	end

	local plates = context.Services.UpgradeService.GetPlateCount(player)
	if readySnackCount(data) > 0 then
		notifyThrottled(player, "ReadySnack", "A snack is ready. Harvest it from your plate.", config().ReadySnackHintCooldown or 25)
	elseif plantedCount(data) >= plates and plates > 0 then
		notifyThrottled(player, "FullPlates", "All plates are full. Wait for one to finish growing.", config().FullPlatesHintCooldown or 25)
	end
	state.LastCheckAt = now()
	return false
end

function FailsafeService.TeleportToPlot(player, reason, ignoreCooldown)
	local context = FailsafeService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	local state = ensureFailsafeState(data)
	local cooldown = config().TeleportToPlotCooldown or 15
	if not ignoreCooldown and now() - state.LastTeleportToPlotAt < cooldown then
		local remaining = math.ceil(cooldown - (now() - state.LastTeleportToPlotAt))
		context.Services.EconomyService.Notify(player, "Lab teleport ready in " .. tostring(remaining) .. "s.")
		return false
	end
	if not context.Services.PlotService.GetPlot(player) then
		context.Services.PlotService.AssignPlot(player)
	end
	state.LastTeleportToPlotAt = now()
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.PlotService.TeleportToPlot(player)
	context.Services.EconomyService.Notify(player, reason == "fall" and "Back to solid ground." or "Back to your lab.")
	context.Services.EconomyService.Sync(player)
	return true
end

function FailsafeService.ForgetPlayer(player)
	hintCooldowns[player] = nil
end

return FailsafeService
