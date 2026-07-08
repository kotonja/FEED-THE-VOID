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


local function spawnEventVortex(labelText, color, assetKey)
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if not folder then
		return
	end
	local assetService = EventService.Context and EventService.Context.Services.AssetService
	if assetKey and assetService then
		local model = assetService.CloneModel(assetKey, { ApplyReferenceTargetSize = true })
		model.Name = "EventVortex_" .. tostring(assetKey)
		model.Parent = folder
		assetService.ScaleToTargetSize(model, Vector3.new(12, 8, 12))
		assetService.SetModelCFrame(model, CFrame.new(0, 21, 0))
		local primary = assetService.EnsurePrimaryPart(model)
		if primary then
			local light = Instance.new("PointLight")
			light.Name = "EventVortexLight"
			light.Color = color or Color3.fromRGB(170, 70, 255)
			light.Brightness = 0.85
			light.Range = 48
			light.Parent = primary
		end
		assetService.AttachBillboard(model, {
			Name = "EventVortexBillboard",
			Text = labelText or "VOID EVENT",
			Size = UDim2.new(0, 260, 0, 62),
			StudsOffset = Vector3.new(0, 5.2, 0),
			MaxDistance = 120,
			BackgroundColor3 = Color3.fromRGB(25, 18, 34),
			TextColor3 = Color3.fromRGB(255, 246, 210),
		})
		return
	end
	local vortex = Instance.new("Part")
	vortex.Name = "EventVortex"
	vortex.Anchored = true
	vortex.CanCollide = false
	vortex.Shape = Enum.PartType.Ball
	vortex.Material = Enum.Material.Glass
	vortex.Color = color or Color3.fromRGB(170, 70, 255)
	vortex.Transparency = 0.42
	vortex.Size = Vector3.new(18, 5, 18)
	vortex.Position = Vector3.new(0, 22, 0)
	vortex.Parent = folder
	local light = Instance.new("PointLight")
	light.Name = "EventVortexLight"
	light.Color = vortex.Color
	light.Brightness = 0.8
	light.Range = 45
	light.Parent = vortex
	local gui = Instance.new("BillboardGui")
	gui.Name = "EventVortexBillboard"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 260, 0, 62)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.Parent = vortex
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(25, 18, 34)
	label.TextColor3 = Color3.fromRGB(255, 246, 210)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBlack
	label.Text = labelText or "VOID EVENT"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Parent = gui
end

local function eventObjectsFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("EventObjects")
end

local function snackAssetKey(snack)
	if snack and snack.AssetKey then
		return snack.AssetKey
	end
	local visualType = snack and snack.VisualType or "Round"
	if visualType == "Cube" then
		return "SnackCubeBase"
	elseif visualType == "Wrap" then
		return "SnackWrapBase"
	end
	return "SnackRoundBase"
end

local function spawnWantedSnackPreview(snackId)
	local context = EventService.Context
	local folder = eventObjectsFolder()
	local snack = context.Config.SnackConfig[snackId]
	if not folder or not snack then
		return
	end
	local assetService = context.Services.AssetService
	local model = assetService.CloneModel(snackAssetKey(snack))
	model.Name = "EventGoldenHungerWantedSnack"
	model.Parent = folder
	assetService.ScaleToTargetSize(model, Vector3.new(4.2, 4.2, 4.2))
	assetService.ApplyMutationVisual(model, "Golden", snack.Color)
	assetService.SetModelCFrame(model, CFrame.new(0, 16, 0))
	assetService.AttachBillboard(model, {
		Name = "WantedSnackBillboard",
		Text = "WANTED: " .. tostring(snack.DisplayName or snackId),
		Size = UDim2.new(0, 260, 0, 54),
		StudsOffset = Vector3.new(0, 3.6, 0),
		MaxDistance = 130,
		BackgroundColor3 = Color3.fromRGB(34, 26, 18),
		TextColor3 = Color3.fromRGB(255, 231, 130),
	})
	eventMaid:GiveTask(model)
end

local function spawnMutationPlateAuras()
	local world = workspace:FindFirstChild("GameWorld")
	local folder = eventObjectsFolder()
	local plots = world and world:FindFirstChild("Plots")
	if not folder or not plots then
		return
	end
	local count = 0
	for _, plot in ipairs(plots:GetChildren()) do
		local plates = plot:FindFirstChild("Plates")
		if plates then
			for _, plate in ipairs(plates:GetChildren()) do
				if plate:IsA("BasePart") and count < 48 then
					count += 1
					local aura = Instance.new("Part")
					aura.Name = "EventMutationPlateAura"
					aura.Anchored = true
					aura.CanCollide = false
					aura.CanQuery = false
					aura.CanTouch = false
					aura.Shape = Enum.PartType.Cylinder
					aura.Material = Enum.Material.Glass
					aura.Color = Color3.fromRGB(90, 255, 190)
					aura.Transparency = 0.58
					aura.Size = Vector3.new(math.max(4.8, plate.Size.X + 1.2), 0.12, math.max(4.8, plate.Size.Z + 1.2))
					aura.CFrame = CFrame.new(plate.Position + Vector3.new(0, (plate.Size.Y * 0.5) + 0.12, 0))
					aura.Parent = folder
					eventMaid:GiveTask(aura)
				end
			end
		end
	end
end

local function spawnVoidInfestationSwarm()
	local folder = eventObjectsFolder()
	if not folder then
		return
	end
	for index = 1, 14 do
		local angle = (index / 14) * math.pi * 2
		local radius = 10 + (index % 3) * 2
		local mote = Instance.new("Part")
		mote.Name = "EventVoidSwarmMote"
		mote.Anchored = true
		mote.CanCollide = false
		mote.CanQuery = false
		mote.CanTouch = false
		mote.Shape = Enum.PartType.Ball
		mote.Material = Enum.Material.Glass
		mote.Color = Color3.fromRGB(110, 48, 190)
		mote.Transparency = 0.28
		mote.Size = Vector3.new(0.8, 0.8, 0.8)
		mote.Position = Vector3.new(math.cos(angle) * radius, 6 + (index % 4), math.sin(angle) * radius)
		mote.Parent = folder
		eventMaid:GiveTask(mote)
	end
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

local function spawnSnackRainCrumb(index)
	local context = EventService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if not folder then
		return
	end
	local angle = (index / context.Config.EventConfig.SnackRain.CrumbCount) * math.pi * 2
	local radius = 16 + (index % 5) * 6
	local finalPosition = Vector3.new(math.cos(angle) * radius, 2.8, math.sin(angle) * radius)
	local model = context.Services.AssetService.CloneModel("VoidCrumbPickup")
	model.Name = "SnackRainCrumb_" .. tostring(index)
	model:SetAttribute("EventPickup", true)
	model:SetAttribute("PickupKind", "SnackRainCrumb")
	model:SetAttribute("EventToken", activeToken)
	model.Parent = folder
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(finalPosition + Vector3.new(0, 18 + (index % 5), 0)))
	task.spawn(function()
		for step = 1, 16 do
			if not model.Parent or model:GetAttribute("Collected") then
				return
			end
			local alpha = step / 16
			local arcY = (1 - alpha) * (18 + (index % 5))
			context.Services.AssetService.SetModelCFrame(model, CFrame.new(finalPosition + Vector3.new(0, arcY, 0)))
			task.wait(0.045)
		end
	end)
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
	return config and (config.DisplayName or activeEventName) or nil
end

function EventService.GetActiveEventObjective()
	local config = activeEventName and EventService.Context.Config.EventConfig[activeEventName]
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
	local endedParticipants = participants
	activeEventName = nil
	activeEventEndsAt = 0
	goldenHungerSnackId = nil
	participants = {}
	clearEventObjects()
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

function EventService.StartEvent(eventName)
	local context = EventService.Context
	local config = context.Config.EventConfig[eventName]
	if not config or activeEventName then
		return false
	end
	if not EventService.IsEventEnabled(eventName) then
		warn("[FEED THE VOID] Event disabled or unavailable", eventName)
		return false
	end
	activeToken += 1
	local token = activeToken
	local duration = eventDuration(config)
	activeEventName = eventName
	activeEventEndsAt = os.time() + duration
	lastEventStartedAt = os.time()
	participants = {}
	goldenHungerSnackId = nil
	context.Services.AnalyticsService.VoidEventStarted(eventName)
	local displayName = config.DisplayName or eventName
	local objectiveText = config.ObjectiveText or "Join the active Void event."
	context.Services.EconomyService.NotifyAll(displayName .. " has started! " .. objectiveText)
	if context.Services.AudioService then
		local target = centralAudioTarget()
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
		local target = centralAudioTarget()
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

	local ok, err = pcall(function()
	if eventName == "SnackRain" then
		spawnEventVortex(config.WorldVisualText or "SNACK RAIN", Color3.fromRGB(255, 180, 80), "EventSnackRainCloud")
		for index = 1, math.min(config.CrumbCount or 0, config.MaxActivePickups or math.huge, limitValue("MaxEventPickups", 60), limitValue("MaxSnackRainPickups", 60)) do
			spawnSnackRainCrumb(index)
		end
	elseif eventName == "VoidInfestation" then
		spawnEventVortex(config.WorldVisualText or "VOIDMITES SWARM", Color3.fromRGB(175, 75, 255), "EventVoidmiteNest")
		spawnVoidInfestationSwarm()
		context.Services.EconomyService.NotifyAll(objectiveText)
		for _ = 1, config.ExtraSpawnPasses or 1 do
			context.Services.VoidmiteService.SpawnInfestation(true)
		end
	elseif eventName == "GoldenHunger" then
		spawnEventVortex(config.WorldVisualText or "GOLDEN HUNGER", Color3.fromRGB(255, 215, 80), "EventGoldenHungerIdol")
		local order = context.Config.SnackConfig.Order
		goldenHungerSnackId = order[math.random(1, math.min(#order, 6))]
		spawnWantedSnackPreview(goldenHungerSnackId)
		context.Services.EconomyService.NotifyAll("The Void wants " .. context.Config.SnackConfig[goldenHungerSnackId].DisplayName .. "!")
	elseif eventName == "MutationSurge" then
		spawnEventVortex(config.WorldVisualText or "MUTATION SURGE", Color3.fromRGB(90, 255, 190), "EventMutationCrystal")
		spawnMutationPlateAuras()
		context.Services.EconomyService.NotifyAll(objectiveText)
	elseif eventName == "PhantomSnackChase" then
		spawnEventVortex(config.WorldVisualText or "PHANTOM CHASE", Color3.fromRGB(172, 116, 255), "PhantomSnack")
		context.Services.EconomyService.NotifyAll(objectiveText)
		context.Services.PhantomSnackService.SpawnForEvent(duration)
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
	local available = {}
	for _, eventName in ipairs(EventService.Context.Config.EventConfig.Order or {}) do
		if EventService.IsEventEnabled(eventName) then
			table.insert(available, eventName)
		end
	end
	if #available == 0 then
		warn("[FEED THE VOID] No enabled events available.")
		return false
	end
	return EventService.StartEvent(available[math.random(1, #available)])
end

function EventService.PlayEventVisual(eventName)
	if not EventService.Context.Config.EventConfig[eventName] then
		return false
	end
	if activeEventName then
		EventService.Context.Services.EconomyService.NotifyAll("Event visual requested, but " .. tostring(activeEventName) .. " is already active.")
		return false
	end
	return EventService.StartEvent(eventName)
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
