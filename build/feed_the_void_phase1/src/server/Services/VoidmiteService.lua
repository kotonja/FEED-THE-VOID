local Players = game:GetService("Players")

local VoidmiteService = {}

local nextSpawnCheck = {}

local function getFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("ActiveVoidmites")
end

local function ownerPlayerFromUserId(userId)
	userId = tonumber(userId)
	return userId and Players:GetPlayerByUserId(userId) or nil
end

local function spawnVoidmiteForDisplay(displayModel)
	local context = VoidmiteService.Context
	local folder = getFolder()
	if not folder or not displayModel or not displayModel.Parent then
		return
	end
	local ownerUserId = tonumber(displayModel:GetAttribute("OwnerUserId"))
	local plotId = tonumber(displayModel:GetAttribute("PlotId"))
	local reward = math.max(5, math.floor((tonumber(displayModel:GetAttribute("DisplayValue")) or 10) * 0.18))
	local origin = displayModel:GetPivot().Position

	local part = Instance.new("Part")
	part.Name = "Voidmite_" .. tostring(os.clock()):gsub("%.", "_")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(80, 30, 135)
	part.Size = Vector3.new(1.3, 1.3, 1.3)
	part.Position = origin + Vector3.new(math.random(-5, 5), 1.2, math.random(-4, 4))
	part:SetAttribute("OwnerUserId", ownerUserId)
	part:SetAttribute("PlotId", plotId)
	part:SetAttribute("RewardValue", reward)
	part.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleansePrompt"
	prompt.ActionText = "Cleanse Voidmite"
	prompt.ObjectText = "Voidmite"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		VoidmiteService.ClearVoidmite(player, part)
	end)
end

function VoidmiteService.Init(context)
	VoidmiteService.Context = context
end

function VoidmiteService.Start()
	task.spawn(function()
		while true do
			task.wait(4)
			VoidmiteService.SpawnTick()
		end
	end)
end

function VoidmiteService.SpawnTick()
	local context = VoidmiteService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local snacksFolder = world and world:FindFirstChild("ActiveSnacks")
	if not snacksFolder then
		return
	end
	for _, model in ipairs(snacksFolder:GetChildren()) do
		if model:GetAttribute("Displayed") == true then
			local worldId = model:GetAttribute("WorldId")
			local value = tonumber(model:GetAttribute("DisplayValue")) or 10
			local interval = math.max(8, context.Config.GameConfig.VoidmiteBaseInterval - math.clamp(value / 80, 0, 10))
			local due = nextSpawnCheck[worldId] or (os.clock() + interval)
			if os.clock() >= due then
				nextSpawnCheck[worldId] = os.clock() + interval + math.random(0, 5)
				spawnVoidmiteForDisplay(model)
			end
		end
	end
end

function VoidmiteService.SpawnInfestation()
	local world = workspace:FindFirstChild("GameWorld")
	local snacksFolder = world and world:FindFirstChild("ActiveSnacks")
	if not snacksFolder then
		return
	end
	for _, model in ipairs(snacksFolder:GetChildren()) do
		if model:GetAttribute("Displayed") == true then
			spawnVoidmiteForDisplay(model)
		end
	end
end

function VoidmiteService.ClearVoidmite(player, voidmite)
	local context = VoidmiteService.Context
	if not voidmite or not voidmite:IsDescendantOf(workspace) or voidmite.Name:sub(1, 9) ~= "Voidmite_" then
		context.Services.EconomyService.Notify(player, "That Voidmite is already gone.")
		return false
	end
	local reward = tonumber(voidmite:GetAttribute("RewardValue")) or 5
	local ownerUserId = tonumber(voidmite:GetAttribute("OwnerUserId"))
	local ownerPlayer = ownerPlayerFromUserId(ownerUserId)
	voidmite:Destroy()
	context.Services.EconomyService.AddCoins(player, reward)
	context.Services.EconomyService.AddVoidTokens(player, 1)
	if ownerPlayer and ownerPlayer ~= player then
		local ownerReward = math.max(2, math.floor(reward * 0.5))
		context.Services.EconomyService.AddCoins(ownerPlayer, ownerReward)
		context.Services.EconomyService.Notify(ownerPlayer, player.Name .. " cleansed your Voidmite: +" .. tostring(ownerReward) .. " coins.")
		context.Services.EconomyService.Notify(player, "Co-op cleanse: +" .. tostring(reward) .. " coins and +1 Void Token.")
	else
		context.Services.EconomyService.Notify(player, "Voidmite cleansed: +" .. tostring(reward) .. " coins and +1 Void Token.")
	end
	context.Services.AnalyticsService.VoidmiteCleared(player, ownerPlayer, reward)
	return true
end

return VoidmiteService
