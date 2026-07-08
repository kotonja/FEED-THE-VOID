local EventService = {}

local activeEvents = {}

local function clearEventObjects()
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end
end

local function spawnSnackRainCrumb(index)
	local context = EventService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if not folder then
		return
	end
	local angle = (index / 18) * math.pi * 2
	local radius = 18 + (index % 5) * 7
	local part = Instance.new("Part")
	part.Name = "SnackRainCrumb_" .. tostring(index)
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 180, 80)
	part.Size = Vector3.new(2.2, 2.2, 2.2)
	part.Position = Vector3.new(math.cos(angle) * radius, 2.8, math.sin(angle) * radius)
	part:SetAttribute("RewardCoins", 12)
	part.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Collect Snack Crumb"
	prompt.ObjectText = "Snack Rain"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part.Parent then
			part:Destroy()
			context.Services.EconomyService.AddCoins(player, 12)
			local data = context.Services.ProfileServiceWrapper.GetData(player)
			if data then
				data.Seeds.CookieRock = (data.Seeds.CookieRock or 0) + 1
				context.Services.ProfileServiceWrapper.MarkDirty(player)
				context.Services.EconomyService.Sync(player)
			end
			context.Services.EconomyService.Notify(player, "Snack crumb collected: +12 coins and +1 Cookie Rock seed.")
		end
	end)
end

function EventService.Init(context)
	EventService.Context = context
end

function EventService.Start() end

function EventService.IsActive(eventName)
	return activeEvents[eventName] == true
end

function EventService.StartEvent(eventName)
	local context = EventService.Context
	if activeEvents[eventName] then
		return
	end
	activeEvents[eventName] = true
	context.Services.AnalyticsService.VoidEventStarted(eventName)
	context.Services.EconomyService.NotifyAll(eventName .. " has started!")

	if eventName == "SnackRain" then
		clearEventObjects()
		for index = 1, 18 do
			spawnSnackRainCrumb(index)
		end
		task.delay(context.Config.EventConfig.SnackRain.Duration, function()
			activeEvents.SnackRain = nil
			clearEventObjects()
			context.Services.EconomyService.NotifyAll("Snack Rain ended.")
		end)
	elseif eventName == "MutationSurge" then
		task.delay(context.Config.EventConfig.MutationSurge.Duration, function()
			activeEvents.MutationSurge = nil
			context.Services.EconomyService.NotifyAll("Mutation Surge faded.")
		end)
	elseif eventName == "VoidInfestation" then
		context.Services.VoidmiteService.SpawnInfestation()
		task.delay(context.Config.EventConfig.VoidInfestation.Duration, function()
			activeEvents.VoidInfestation = nil
		end)
	end
end

function EventService.StartRandomEvent()
	local events = { "SnackRain", "MutationSurge", "VoidInfestation" }
	EventService.StartEvent(events[math.random(1, #events)])
end

return EventService
