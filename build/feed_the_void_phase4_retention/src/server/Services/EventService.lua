local Players = game:GetService("Players")

local EventService = {}

local activeEventName = nil
local activeEventEndsAt = 0
local activeToken = 0
local goldenHungerSnackId = nil
local participants = {}

local function eventDuration(config)
	if EventService.Context.Config.GameConfig.DebugShortEvents and config.DebugDuration then
		return config.DebugDuration
	end
	return config.Duration
end

local function clearEventObjects()
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end
end


local function spawnEventVortex(labelText, color)
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if not folder then
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

local function collectCrumb(model, player)
	if not model.Parent then
		return
	end
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
	local model = context.Services.AssetService.CloneModel("VoidCrumbPickup")
	model.Name = "SnackRainCrumb_" .. tostring(index)
	model.Parent = folder
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(math.cos(angle) * radius, 2.8, math.sin(angle) * radius))
	local prompt = context.Services.AssetService.AddProximityPrompt(model, "Snack Rain", "Collect Crumb")
	local collected = false
	local function tryCollect(player)
		if collected then
			return
		end
		collected = true
		collectCrumb(model, player)
	end
	if prompt then
		prompt.Triggered:Connect(tryCollect)
	end
	local primary = context.Services.AssetService.EnsurePrimaryPart(model)
	if primary then
		primary.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				tryCollect(player)
			end
		end)
	end
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

function EventService.GetGoldenHungerSnackId()
	return goldenHungerSnackId
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
				EventService.Context.Services.EconomyService.AddCoins(player, 50)
				EventService.Context.Services.EconomyService.AddVoidTokens(player, 1)
				EventService.Context.Services.StatsService.Record(player, "VoidEventsParticipated", 1)
				EventService.Context.Services.BadgeAwardService.Award(player, "FirstVoidEvent")
				EventService.Context.Services.EconomyService.Notify(player, "Event participation bonus: +50 coins and +1 Void Token.")
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
	activeToken += 1
	local token = activeToken
	local duration = eventDuration(config)
	activeEventName = eventName
	activeEventEndsAt = os.time() + duration
	participants = {}
	goldenHungerSnackId = nil
	context.Services.AnalyticsService.VoidEventStarted(eventName)
	context.Services.EconomyService.NotifyAll((config.DisplayName or eventName) .. " has started!")
	clearEventObjects()

	if eventName == "SnackRain" then
		spawnEventVortex("SNACK RAIN", Color3.fromRGB(255, 180, 80))
		for index = 1, math.min(config.CrumbCount, config.MaxActivePickups) do
			spawnSnackRainCrumb(index)
		end
	elseif eventName == "VoidInfestation" then
		spawnEventVortex("VOIDMITES SWARM", Color3.fromRGB(175, 75, 255))
		context.Services.EconomyService.NotifyAll("Voidmites are swarming the labs!")
		for _ = 1, config.ExtraSpawnPasses or 1 do
			context.Services.VoidmiteService.SpawnInfestation(true)
		end
	elseif eventName == "GoldenHunger" then
		spawnEventVortex("GOLDEN HUNGER", Color3.fromRGB(255, 215, 80))
		local order = context.Config.SnackConfig.Order
		goldenHungerSnackId = order[math.random(1, math.min(#order, 6))]
		context.Services.EconomyService.NotifyAll("The Void wants " .. context.Config.SnackConfig[goldenHungerSnackId].DisplayName .. "!")
	elseif eventName == "MutationSurge" then
		spawnEventVortex("MUTATION SURGE", Color3.fromRGB(90, 255, 190))
		context.Services.EconomyService.NotifyAll("Rare mutations are stirring, but they are still rare.")
	elseif eventName == "PhantomSnackChase" then
		spawnEventVortex("PHANTOM CHASE", Color3.fromRGB(172, 116, 255))
		context.Services.EconomyService.NotifyAll("Phantom Snacks are loose!")
		context.Services.PhantomSnackService.SpawnForEvent(duration)
	end

	context.Services.EconomyService.SyncAll()
	task.delay(duration, function()
		EventService.EndEvent(token)
	end)
	return true
end

function EventService.StartRandomEvent()
	local events = EventService.Context.Config.EventConfig.Order
	return EventService.StartEvent(events[math.random(1, #events)])
end

return EventService
