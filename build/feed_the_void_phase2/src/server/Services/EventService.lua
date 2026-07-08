local Players = game:GetService("Players")

local EventService = {}

local activeEventName = nil
local activeEventEndsAt = 0
local activeToken = 0
local goldenHungerSnackId = nil

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

local function collectCrumb(model, player)
	if not model.Parent then
		return
	end
	model:Destroy()
	local context = EventService.Context
	local config = context.Config.EventConfig.SnackRain
	context.Services.EconomyService.AddCoins(player, config.CoinReward)
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

function EventService.EndEvent(token)
	if token and token ~= activeToken then
		return
	end
	local endedName = activeEventName
	activeEventName = nil
	activeEventEndsAt = 0
	goldenHungerSnackId = nil
	clearEventObjects()
	if endedName then
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
	goldenHungerSnackId = nil
	context.Services.AnalyticsService.VoidEventStarted(eventName)
	context.Services.EconomyService.NotifyAll((config.DisplayName or eventName) .. " has started!")
	clearEventObjects()

	if eventName == "SnackRain" then
		for index = 1, math.min(config.CrumbCount, config.MaxActivePickups) do
			spawnSnackRainCrumb(index)
		end
	elseif eventName == "VoidInfestation" then
		context.Services.EconomyService.NotifyAll("The Voidmites are swarming the labs!")
		for _ = 1, config.ExtraSpawnPasses or 1 do
			context.Services.VoidmiteService.SpawnInfestation(true)
		end
	elseif eventName == "GoldenHunger" then
		local order = context.Config.SnackConfig.Order
		goldenHungerSnackId = order[math.random(1, math.min(#order, 6))]
		context.Services.EconomyService.NotifyAll("The Void wants " .. context.Config.SnackConfig[goldenHungerSnackId].DisplayName .. "!")
	elseif eventName == "MutationSurge" then
		context.Services.EconomyService.NotifyAll("Rare mutations are stirring, but they are still rare.")
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
