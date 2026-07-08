local Players = game:GetService("Players")

local VoidmiteService = {}

local nextSpawnCheck = {}
local clearCooldown = {}

local function getFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("ActiveVoidmites")
end

local function ownerPlayerFromUserId(userId)
	userId = tonumber(userId)
	return userId and Players:GetPlayerByUserId(userId) or nil
end

local function countForPlot(plotId)
	local folder = getFolder()
	local count = 0
	if not folder then
		return 0
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("PlotId")) == tonumber(plotId) then
			count += 1
		end
	end
	return count
end

local function spawnVoidmiteForDisplay(displayModel, eventCreated)
	local context = VoidmiteService.Context
	local folder = getFolder()
	if not folder or not displayModel or not displayModel.Parent then
		return
	end
	local ownerUserId = tonumber(displayModel:GetAttribute("OwnerUserId"))
	local plotId = tonumber(displayModel:GetAttribute("PlotId"))
	if not ownerUserId or not plotId then
		return
	end
	if countForPlot(plotId) >= context.Config.GameConfig.MaxVoidmitesPerPlot then
		return
	end
	local reward = math.max(5, math.floor((tonumber(displayModel:GetAttribute("DisplayValue")) or 10) * 0.18))
	if context.Services.EventService.IsActive("VoidInfestation") then
		reward = math.floor(reward * context.Config.EventConfig.VoidInfestation.RewardMultiplier)
	end
	local origin = displayModel:GetPivot().Position
	local model = context.Services.AssetService.CloneModel("Voidmite")
	model.Name = "Voidmite_" .. tostring(os.clock()):gsub("%.", "_")
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("PlotId", plotId)
	model:SetAttribute("RewardValue", reward)
	model:SetAttribute("EventCreated", eventCreated == true)
	model.Parent = folder
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(origin + Vector3.new(math.random(-5, 5), 1.1, math.random(-4, 4))))
	context.Services.AssetService.ApplyMutationVisual(model, "VoidTouched")
	context.Services.AssetService.AddBillboard(model, "Voidmite", Vector3.new(0, 2.1, 0))
	local prompt = context.Services.AssetService.AddProximityPrompt(model, "Voidmite", "Cleanse")
	if prompt then
		prompt.Triggered:Connect(function(player)
			VoidmiteService.ClearVoidmite(player, model)
		end)
	end
	return model
end

function VoidmiteService.Init(context)
	VoidmiteService.Context = context
end

function VoidmiteService.Start()
	task.spawn(function()
		while true do
			task.wait(5)
			VoidmiteService.SpawnTick()
		end
	end)
end

function VoidmiteService.SpawnTick()
	local context = VoidmiteService.Context
	for _, model in pairs(context.Services.SnackService.GetDisplayedModels()) do
		if model and model.Parent then
			local worldId = model:GetAttribute("WorldId")
			local value = tonumber(model:GetAttribute("DisplayValue")) or 10
			local interval = math.max(
				context.Config.GameConfig.MinVoidmiteSpawnInterval,
				context.Config.GameConfig.BaseVoidmiteSpawnInterval - math.clamp(value / 80, 0, 10)
			)
			local due = nextSpawnCheck[worldId] or (os.clock() + (context.Config.GameConfig.FirstVoidmiteSpawnDelay or interval))
			if os.clock() >= due then
				nextSpawnCheck[worldId] = os.clock() + interval + math.random(0, 5)
				spawnVoidmiteForDisplay(model, false)
			else
				nextSpawnCheck[worldId] = due
			end
		end
	end
end

function VoidmiteService.SpawnInfestation(eventCreated)
	local context = VoidmiteService.Context
	for _, model in pairs(context.Services.SnackService.GetDisplayedModels()) do
		spawnVoidmiteForDisplay(model, eventCreated)
	end
end

function VoidmiteService.ClearForPlayer(player)
	local folder = getFolder()
	if not folder then
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("OwnerUserId")) == player.UserId then
			child:Destroy()
		end
	end
end

function VoidmiteService.ClearVoidmite(player, voidmite)
	local context = VoidmiteService.Context
	if typeof(voidmite) ~= "Instance" or not voidmite:IsDescendantOf(workspace) or not voidmite.Name:match("^Voidmite_") then
		context.Services.EconomyService.Notify(player, "That Voidmite is already gone.")
		return false
	end
	local now = os.clock()
	if (clearCooldown[player] or 0) > now then
		return false
	end
	clearCooldown[player] = now + 0.5
	if not context.Services.ValidationService.ValidateDistance(player, voidmite, 14) then
		context.Services.EconomyService.Notify(player, "Move closer to cleanse that Voidmite.")
		return false
	end
	if voidmite:GetAttribute("Cleared") then
		return false
	end
	voidmite:SetAttribute("Cleared", true)
	local reward = tonumber(voidmite:GetAttribute("RewardValue")) or 5
	reward = math.floor(reward * context.Services.UpgradeService.GetMultiplier(player, "VoidmiteReward"))
	local ownerUserId = tonumber(voidmite:GetAttribute("OwnerUserId"))
	local ownerPlayer = ownerPlayerFromUserId(ownerUserId)
	voidmite:Destroy()
	context.Services.EconomyService.AddCoins(player, reward)
	context.Services.EconomyService.AddVoidTokens(player, 1)
	context.Services.StatsService.Record(player, "VoidmitesCleansed", 1)
	context.Services.BadgeAwardService.Award(player, "FirstVoidmiteCleanse")
	context.Services.EventService.MarkParticipation(player, "CleanseVoidmite")
	context.Services.QuestService.Record(player, "CleanseVoidmite", 1)
	context.Services.TutorialService.RecordAction(player, "CleanseVoidmite")
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

function VoidmiteService.CountActive()
	local folder = getFolder()
	return folder and #folder:GetChildren() or 0
end

return VoidmiteService
