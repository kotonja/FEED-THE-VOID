local Players = game:GetService("Players")

local Maid = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Maid"))

local EventService = {}

local activeEventName = nil
local activeEventEndsAt = 0
local activeToken = 0
local goldenHungerSnackId = nil
local participants = {}
local lastEventStartedAt = os.time()
local eventMaid = Maid.new()
local disabledThisServer = {}
local eventErrorCounts = {}
local isCharging = false
local queuedEventName = nil
local chargeEndsAt = 0
local activeEventIsVisualTest = false
local activeEventStageOrigin = nil

local eventFeatureFlag = {
	SnackRain = "SnackRain",
	MutationSurge = "MutationSurge",
	VoidInfestation = "VoidInfestation",
	GoldenHunger = "GoldenHunger",
	PhantomSnackChase = "PhantomSnackChase",
}

local eventStartSoundKey = {
	SnackRain = "Events.SnackRainStart",
	MutationSurge = "Events.MutationSurgeStart",
	VoidInfestation = "Events.VoidInfestationStart",
	GoldenHunger = "Events.GoldenHungerStart",
	PhantomSnackChase = "Events.PhantomAppear",
}

local eventStartVfxKey = {
	SnackRain = "Event.SnackRain.Start",
	MutationSurge = "Event.MutationSurge.Start",
	VoidInfestation = "Event.VoidInfestation.Start",
	GoldenHunger = "Event.GoldenHunger.Start",
	PhantomSnackChase = "Event.Phantom.Appear",
}

local function centralAudioTarget()
	local world = workspace:FindFirstChild("GameWorld")
	local central = world and world:FindFirstChild("CentralVoid")
	return central and (central:FindFirstChild("VoidCore") or central:FindFirstChild("FeedStation") or central) or Vector3.new(0, 8, 0)
end

local function limitValue(limitName, fallback)
	local gameConfig = EventService.Context.Config.GameConfig
	local limits = gameConfig.Limits or {}
	local performance = gameConfig.Performance or {}
	return tonumber(limits[limitName]) or tonumber(performance[limitName]) or fallback
end

local function distanceValue(distanceName, fallback)
	local distances = EventService.Context.Config.GameConfig.InteractionDistances or {}
	return tonumber(distances[distanceName]) or fallback
end

local function eventDuration(config)
	if EventService.Context.Config.GameConfig.DebugShortEvents and config.DebugDuration then
		return config.DebugDuration
	end
	return config.Duration
end

local function featureEnabled(eventName)
	local context = EventService.Context
	local flagName = eventFeatureFlag[eventName]
	if not flagName then
		return true
	end
	local flags = context.Config.FeatureFlags or {}
	return flags[flagName] ~= false
end

local function disabledList()
	local list = {}
	for eventName, disabled in pairs(disabledThisServer) do
		if disabled then
			table.insert(list, eventName)
		end
	end
	table.sort(list)
	return list
end

local function clearEventObjects()
	eventMaid:DoCleaning()
	eventMaid = Maid.new()
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end
end


local function spawnEventProp(eventName, labelText, color, assetKey, targetSize, stage)
	local context = EventService.Context
	local config = table.clone(context.Config.EventConfig[eventName] or {})
	config.WorldVisualText = config.WorldVisualText or labelText
	config.ObjectiveText = config.ObjectiveText or labelText
	config.BannerName = config.BannerName or labelText
	config.AssetKey = assetKey or config.AssetKey
	config.EventColor = color or config.EventColor
	local targetMax = targetSize and math.max(targetSize.X, targetSize.Y, targetSize.Z) or nil
	local model = context.Services.WorldSpectacleService.SpawnEventProp(eventName, config, {
		ParentFolder = stage.ParentFolder,
		Origin = stage.Origin,
		TargetMaxDimension = targetMax,
		Duration = stage.Duration,
	})
	if model then
		eventMaid:GiveTask(model)
	end
	return model
end

local function spawnWantedSnackPreview(snackId, stage, idol)
	local context = EventService.Context
	local idolPosition = idol and idol:GetPivot().Position or stage.Origin
	local model = context.Services.WorldSpectacleService.SpawnGoldenHungerPreview(snackId, {
		ParentFolder = stage.ParentFolder,
		Position = idolPosition + Vector3.new(0, 12, 0),
	})
	if model then
		eventMaid:GiveTask(model)
		context.Services.WorldSpectacleService.LinkGoldenHunger(idol, model, stage.ParentFolder)
	end
	return model
end

local function spawnMutationPlateAuras(stage)
	return EventService.Context.Services.WorldSpectacleService.SpawnMutationPlateAuras({
		ParentFolder = stage.ParentFolder,
		Lifetime = stage.Duration + 1,
	})
end

local function spawnVoidInfestationSwarm(stage)
	return EventService.Context.Services.WorldSpectacleService.SpawnVoidInfestationSwarm({
		ParentFolder = stage.ParentFolder,
		Center = stage.Origin + Vector3.new(22, 0, 0),
		Lifetime = stage.Duration + 1,
		VoidmiteCount = 6,
		MistCount = 14,
	})
end

local function collectCrumb(model, player)
	if not model.Parent or model:GetAttribute("Collected") then
		return
	end
	local pickupPosition = nil
	local primary = model:IsA("Model") and model.PrimaryPart or nil
	if primary then
		pickupPosition = primary.Position
	elseif model:IsA("Model") then
		local ok, pivot = pcall(function()
			return model:GetPivot()
		end)
		if ok then
			pickupPosition = pivot.Position
		end
	elseif model:IsA("BasePart") then
		pickupPosition = model.Position
	end
	model:SetAttribute("Collected", true)
	model:Destroy()
	local context = EventService.Context
	local config = context.Config.EventConfig.SnackRain
	context.Services.EconomyService.AddCoins(player, config.CoinReward)
	context.Services.EventService.MarkParticipation(player, "CollectCrumb")
	context.Services.QuestService.Record(player, "CollectCrumb", 1)
	if math.random() < config.SeedChance then
		local seedId = math.random() < 0.7 and "CookieRock" or "JellyCube"
		context.Services.EconomyService.AddSeeds(player, seedId, 1, false)
		context.Services.EconomyService.Notify(player, "Snack crumb: +" .. tostring(config.CoinReward) .. " coins and +1 " .. context.Config.SnackConfig[seedId].DisplayName .. " seed.")
	else
		context.Services.EconomyService.Notify(player, "Snack crumb collected: +" .. tostring(config.CoinReward) .. " coins.")
	end
	if context.Services.AudioService then
		context.Services.AudioService.PlayForPlayer(player, "Events.SnackRainPickup", "World", pickupPosition, { MinInterval = 0.08 })
	end
	if context.Services.VFXService then
		context.Services.VFXService.PlayForPlayer(player, "Event.SnackRain.Pickup", {
			Mode = "World",
			Position = pickupPosition,
			Text = "+" .. tostring(config.CoinReward) .. " coins",
			MinInterval = 0.08,
		})
	end
	context.Services.EconomyService.Sync(player)
end

local function spawnSnackRainCrumb(index, stage)
	local context = EventService.Context
	local model = context.Services.WorldSpectacleService.SpawnSnackRainPickup(index, context.Config.EventConfig.SnackRain.CrumbCount, activeToken, {
		ParentFolder = stage.ParentFolder,
		Center = stage.Origin,
		Lifetime = stage.Duration + 1,
	})
	if not model then
		return
	end
	local prompt = context.Services.AssetService.AddProximityPrompt(model, "Snack Rain", "Collect Crumb")
	local collected = false
	local function tryCollect(player)
		if collected then
			return
		end
		collected = true
		collectCrumb(model, player)
	end
	local primary = context.Services.AssetService.EnsurePrimaryPart(model)
	if primary then
		eventMaid:GiveTask(primary.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				tryCollect(player)
			end
		end))
	end
	if prompt then
		eventMaid:GiveTask(prompt.Triggered:Connect(tryCollect))
	end
	eventMaid:GiveTask(model)
end

function EventService.Init(context)
	EventService.Context = context
end

function EventService.Start() end

function EventService.GetActiveEventName()
	return activeEventName
end

function EventService.GetActiveEventEndsAt()
	return activeEventEndsAt
end

function EventService.GetActiveEventDisplayName()
	local config = activeEventName and EventService.Context.Config.EventConfig[activeEventName]
	return config and (config.BannerName or config.DisplayName or activeEventName) or nil
end

function EventService.GetActiveEventObjective()
	local config = activeEventName and EventService.Context.Config.EventConfig[activeEventName]
	if activeEventName == "GoldenHunger" and goldenHungerSnackId then
		local snack = EventService.Context.Config.SnackConfig[goldenHungerSnackId]
		return snack and ("The Void wants: " .. tostring(snack.DisplayName or goldenHungerSnackId)) or config.ObjectiveText
	end
	return config and config.ObjectiveText or nil
end

function EventService.GetGoldenHungerSnackId()
	return goldenHungerSnackId
end

function EventService.GetPityMultiplier()
	local context = EventService.Context
	if not context or activeEventName then
		return 1
	end
	local target = tonumber(context.Config.GameConfig.TargetFirstEventSeconds) or 300
	if os.time() - lastEventStartedAt >= target then
		return 0.75
	end
	return 1
end

function EventService.SetChargeState(active, nextEventName, endsAt)
	isCharging = active == true
	queuedEventName = isCharging and nextEventName or nil
	chargeEndsAt = isCharging and (tonumber(endsAt) or 0) or 0
end

function EventService.IsCharging()
	return isCharging == true
end

function EventService.GetChargeStatus()
	return {
		IsCharging = isCharging == true,
		QueuedEventName = queuedEventName,
		ChargeEndsAt = chargeEndsAt,
	}
end

function EventService.GetMutationWeightMultiplier(mutationId)
	if activeEventName ~= "MutationSurge" or mutationId == "Normal" then
		return 1
	end
	local mutation = EventService.Context.Config.MutationConfig[mutationId]
	if not mutation or (mutation.ValueMultiplier or 1) < 2 then
		return 1.2
	end
	return EventService.Context.Config.EventConfig.MutationSurge.RareWeightMultiplier
end

function EventService.IsActive(eventName)
	return activeEventName == eventName
end

function EventService.IsEventEnabled(eventName)
	return EventService.Context.Config.EventConfig[eventName] ~= nil
		and disabledThisServer[eventName] ~= true
		and featureEnabled(eventName)
end

function EventService.MarkParticipation(player, reason)
	if not activeEventName or not player then
		return false
	end
	participants[player.UserId] = {
		Player = player,
		Reason = reason or "Action",
	}
	return true
end

function EventService.CollectEventPickup(player, pickup)
	local context = EventService.Context
	if typeof(pickup) ~= "Instance" then
		return false
	end
	local model = pickup:IsA("Model") and pickup or pickup:FindFirstAncestorOfClass("Model")
	if not model or not model:IsDescendantOf(workspace) or model:GetAttribute("EventPickup") ~= true then
		return false
	end
	if model:GetAttribute("Collected") then
		return false
	end
	if model:GetAttribute("EventToken") ~= activeToken then
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, model, distanceValue("Pickup", 10)) then
		context.Services.EconomyService.Notify(player, "Move closer to collect that pickup.")
		return false
	end
	local kind = model:GetAttribute("PickupKind")
	if activeEventName == "SnackRain" and kind == "SnackRainCrumb" then
		collectCrumb(model, player)
		return true
	end
	return false
end

function EventService.EndEvent(token)
	if token and token ~= activeToken then
		return
	end
	local endedName = activeEventName
	local endedWasVisualTest = activeEventIsVisualTest
	local endedParticipants = participants
	activeEventName = nil
	activeEventEndsAt = 0
	goldenHungerSnackId = nil
	activeEventIsVisualTest = false
	activeEventStageOrigin = nil
	participants = {}
	clearEventObjects()
	if endedWasVisualTest and EventService.Context.Services.WorldSpectacleService then
		EventService.Context.Services.WorldSpectacleService.ClearVisualTests()
	end
	if EventService.Context.Services.PhantomSnackService then
		EventService.Context.Services.PhantomSnackService.Cleanup()
	end
	if endedName then
		for _, entry in pairs(endedParticipants) do
			local player = entry.Player
			if player and player.Parent then
				local ok, err = pcall(function()
					EventService.Context.Services.EconomyService.AddCoins(player, 50)
					EventService.Context.Services.EconomyService.AddVoidTokens(player, 1)
					EventService.Context.Services.StatsService.Record(player, "VoidEventsParticipated", 1)
					EventService.Context.Services.BadgeAwardService.Award(player, "FirstVoidEvent")
					EventService.Context.Services.EconomyService.Notify(player, "Event participation bonus: +50 coins and +1 Void Token.")
				end)
				if not ok then
					warn("[FEED THE VOID] Event bonus failed", endedName, player.Name, err)
				end
			end
		end
		EventService.Context.Services.EconomyService.NotifyAll((EventService.Context.Config.EventConfig[endedName].DisplayName or endedName) .. " ended.")
		EventService.Context.Services.EconomyService.SyncAll()
	end
end

function EventService.StartEvent(eventName, options)
	options = type(options) == "table" and options or {}
	local context = EventService.Context
	local config = context.Config.EventConfig[eventName]
	if not config or activeEventName then
		return false
	end
	if isCharging then
		warn("[FEED THE VOID] Event start rejected while The Void is charging", eventName)
		return false
	end
	if not EventService.IsEventEnabled(eventName) then
		warn("[FEED THE VOID] Event disabled or unavailable", eventName)
		return false
	end
	activeToken += 1
	local token = activeToken
	local visualTest = options.VisualTest == true
	local duration = tonumber(options.Duration) or (visualTest and config.DebugDuration) or eventDuration(config)
	activeEventName = eventName
	activeEventEndsAt = os.time() + duration
	activeEventIsVisualTest = visualTest
	lastEventStartedAt = os.time()
	participants = {}
	goldenHungerSnackId = nil
	activeEventStageOrigin = context.Services.WorldSpectacleService.GetEventOrigin(options.Player, visualTest)
	context.Services.AnalyticsService.VoidEventStarted(eventName)
	local displayName = config.BannerName or config.DisplayName or eventName
	local objectiveText = config.ObjectiveText or "Join the active Void event."
	context.Services.EconomyService.NotifyAll(displayName .. " has started! " .. objectiveText)
	if context.Services.AudioService then
		local target = visualTest and (activeEventStageOrigin + Vector3.new(0, 6, 0)) or centralAudioTarget()
		context.Services.AudioService.PlayForAll("Void.EventStart", "World", target, { NoThrottle = true })
		if eventStartSoundKey[eventName] then
			task.delay(0.35, function()
				if activeEventName == eventName then
					context.Services.AudioService.PlayForAll(eventStartSoundKey[eventName], "World", target, { NoThrottle = true })
				end
			end)
		end
	end
	if context.Services.VFXService then
		local target = visualTest and (activeEventStageOrigin + Vector3.new(0, 6, 0)) or centralAudioTarget()
		context.Services.VFXService.PlayForAll("Void.EventStart", {
			Mode = "World",
			Target = typeof(target) == "Instance" and target or nil,
			Position = typeof(target) == "Vector3" and target or nil,
			Text = displayName,
			ObjectiveText = objectiveText,
			NoThrottle = true,
		})
		if eventStartVfxKey[eventName] then
			task.delay(0.2, function()
				if activeEventName == eventName then
					context.Services.VFXService.PlayForAll(eventStartVfxKey[eventName], {
						Mode = "World",
						Target = typeof(target) == "Instance" and target or nil,
						Position = typeof(target) == "Vector3" and target or nil,
						Text = displayName,
						ObjectiveText = objectiveText,
						NoThrottle = true,
					})
				end
			end)
		end
	end
	if context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.EventStarted(eventName)
	end
	clearEventObjects()
	local stageParent
	if visualTest then
		context.Services.WorldSpectacleService.ClearVisualTests()
		stageParent = context.Services.WorldSpectacleService.GetVisualTestFolder()
	else
		context.Services.WorldSpectacleService.ClearEventObjects()
		local world = workspace:FindFirstChild("GameWorld")
		stageParent = world and world:FindFirstChild("EventObjects")
	end
	local stage = {
		ParentFolder = stageParent,
		Origin = activeEventStageOrigin,
		Duration = duration,
		VisualTest = visualTest,
	}

	local ok, err = pcall(function()
		if eventName == "SnackRain" then
			spawnEventProp(eventName, config.WorldVisualText or config.BannerName or "SNACK RAIN", config.EventColor, config.AssetKey or "EventSnackRainCloud", Vector3.new(25, 25, 25), stage)
			for index = 1, math.min(config.CrumbCount or 0, config.MaxActivePickups or math.huge, limitValue("MaxEventPickups", 60), limitValue("MaxSnackRainPickups", 60)) do
				spawnSnackRainCrumb(index, stage)
			end
		elseif eventName == "VoidInfestation" then
			spawnEventProp(eventName, config.WorldVisualText or config.BannerName or "VOIDMITES SWARM", config.EventColor, config.AssetKey or "EventVoidmiteNest", Vector3.new(10, 10, 10), stage)
			spawnVoidInfestationSwarm(stage)
			context.Services.EconomyService.NotifyAll(objectiveText)
			for _ = 1, config.ExtraSpawnPasses or 1 do
				context.Services.VoidmiteService.SpawnInfestation(true)
			end
		elseif eventName == "GoldenHunger" then
			local idol = spawnEventProp(eventName, config.WorldVisualText or config.BannerName or "GOLDEN HUNGER", config.EventColor, config.AssetKey or "EventGoldenHungerIdol", Vector3.new(10, 10, 10), stage)
			local order = context.Config.SnackConfig.Order
			goldenHungerSnackId = order[math.random(1, math.min(#order, 6))]
			spawnWantedSnackPreview(goldenHungerSnackId, stage, idol)
			context.Services.EconomyService.NotifyAll("The Void wants " .. context.Config.SnackConfig[goldenHungerSnackId].DisplayName .. "!")
		elseif eventName == "MutationSurge" then
			spawnEventProp(eventName, config.WorldVisualText or config.BannerName or "MUTATION SURGE", config.EventColor, config.AssetKey or "EventMutationCrystal", Vector3.new(16, 16, 16), stage)
			spawnMutationPlateAuras(stage)
			context.Services.EconomyService.NotifyAll(objectiveText)
		elseif eventName == "PhantomSnackChase" then
			context.Services.EconomyService.NotifyAll(objectiveText)
			context.Services.PhantomSnackService.SpawnForEvent(duration, {
				ParentFolder = stage.ParentFolder,
				Center = stage.Origin + Vector3.new(0, 7, 0),
				Count = 3,
			})
		end
	end)
	if not ok then
		warn("[FEED THE VOID] Event start failed", eventName, err)
		eventErrorCounts[eventName] = (eventErrorCounts[eventName] or 0) + 1
		if eventErrorCounts[eventName] >= 2 then
			disabledThisServer[eventName] = true
			warn("[FEED THE VOID] Event disabled for this server after repeated failures", eventName)
		end
		EventService.EndEvent(token)
		return false
	end

	local activeObjective = EventService.GetActiveEventObjective() or objectiveText
	context.Services.WorldSpectacleService.NoteEventBanner(eventName, activeObjective)
	context.Services.EconomyService.SyncAll()
	task.delay(duration, function()
		EventService.EndEvent(token)
	end)
	return true
end

function EventService.GetStatus()
	local objectCount = 0
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if folder then
		objectCount = #folder:GetChildren()
	end
	local participantCount = 0
	for _ in pairs(participants) do
		participantCount += 1
	end
	local spectacle = EventService.Context.Services.WorldSpectacleService and EventService.Context.Services.WorldSpectacleService.GetLiveEvidence() or nil
	return {
		ActiveEventName = activeEventName,
		ActiveEventDisplayName = EventService.GetActiveEventDisplayName(),
		ActiveEventObjective = EventService.GetActiveEventObjective(),
		EndsAt = activeEventEndsAt,
		SecondsRemaining = math.max(0, activeEventEndsAt - os.time()),
		Participants = participantCount,
		EventObjects = objectCount,
		Token = activeToken,
		DisabledThisServer = disabledList(),
		ErrorCounts = eventErrorCounts,
		IsCharging = isCharging == true,
		QueuedEventName = queuedEventName,
		ChargeEndsAt = chargeEndsAt,
		Spectacle = spectacle,
		IsVisualTest = activeEventIsVisualTest,
		StageOrigin = activeEventStageOrigin,
	}
end

function EventService.PrintStatus(player)
	local status = EventService.GetStatus()
	local line = string.format(
		"[FEED THE VOID][Event] active=%s remaining=%ds participants=%d objects=%d token=%d disabled=%s",
		tostring(status.ActiveEventName or "none"),
		status.SecondsRemaining,
		status.Participants,
		status.EventObjects,
		status.Token,
		table.concat(status.DisabledThisServer or {}, ",")
	)
	print(line)
	if player then
		EventService.Context.Services.EconomyService.Notify(player, "Event: " .. tostring(status.ActiveEventName or "none") .. " | objects " .. tostring(status.EventObjects) .. " | remaining " .. tostring(status.SecondsRemaining) .. "s")
	end
	return status
end

function EventService.StartRandomEvent()
	local eventName = EventService.GetRandomEventName()
	if not eventName then
		warn("[FEED THE VOID] No enabled events available.")
		return false
	end
	return EventService.StartEvent(eventName)
end

function EventService.GetRandomEventName()
	local available = {}
	for _, eventName in ipairs(EventService.Context.Config.EventConfig.Order or {}) do
		if EventService.IsEventEnabled(eventName) then
			table.insert(available, eventName)
		end
	end
	if #available == 0 then
		return nil
	end
	return available[math.random(1, #available)]
end

function EventService.PlayEventVisual(eventName, player, options)
	if not EventService.Context.Config.EventConfig[eventName] then
		return false
	end
	if activeEventName then
		EventService.EndEvent()
	end
	options = type(options) == "table" and table.clone(options) or {}
	options.VisualTest = true
	options.Player = player
	return EventService.StartEvent(eventName, options)
end

function EventService.ClearVisualTests()
	if activeEventIsVisualTest then
		EventService.EndEvent()
	else
		EventService.Context.Services.WorldSpectacleService.ClearVisualTests()
	end
	return true
end

function EventService.DisableEvent(eventName, reason)
	if EventService.Context.Config.EventConfig[eventName] then
		disabledThisServer[eventName] = true
		if activeEventName == eventName then
			EventService.EndEvent()
		end
		print("[FEED THE VOID][Event] disabled " .. tostring(eventName) .. " reason=" .. tostring(reason or "manual"))
		return true
	end
	return false
end

function EventService.EnableEvent(eventName)
	if EventService.Context.Config.EventConfig[eventName] then
		disabledThisServer[eventName] = nil
		eventErrorCounts[eventName] = nil
		print("[FEED THE VOID][Event] enabled " .. tostring(eventName))
		return true
	end
	return false
end

return EventService
