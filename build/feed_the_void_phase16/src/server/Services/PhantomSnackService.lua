local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Maid = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Maid"))

local PhantomSnackService = {}

local active = {}
local eventToken = 0

local function enabled()
	return (PhantomSnackService.Context.Config.FeatureFlags or {}).PhantomSnackChase ~= false
end

local function getFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("EventObjects")
end

local function limitValue(limitName, fallback)
	local gameConfig = PhantomSnackService.Context.Config.GameConfig
	local limits = gameConfig.Limits or {}
	local performance = gameConfig.Performance or {}
	return tonumber(limits[limitName]) or tonumber(performance[limitName]) or fallback
end

local function distanceValue(distanceName, fallback)
	local distances = PhantomSnackService.Context.Config.GameConfig.InteractionDistances or {}
	return tonumber(distances[distanceName]) or fallback
end

local function centralWaypoint(index, count, center)
	local angle = (index / math.max(1, count)) * math.pi * 2
	local radius = 20 + ((index % 3) * 8)
	center = center or Vector3.new(0, 5.2, 0)
	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function stylePhantom(model, index)
	if PhantomSnackService.Context.Services.WorldSpectacleService then
		PhantomSnackService.Context.Services.WorldSpectacleService.StylePhantomModel(model, index)
		return
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = math.max(child.Transparency, 0.34)
			local textured = child:IsA("MeshPart") and child.TextureID and child.TextureID ~= ""
			if not textured then
				child.Material = Enum.Material.Glass
				child.Color = Color3.fromRGB(190, 145, 255)
			end
			child.CanCollide = false
			child.CanTouch = true
			local light = Instance.new("PointLight")
			light.Name = "PhantomGlow"
			light.Brightness = 0.6
			light.Range = 12
			light.Color = Color3.fromRGB(180, 110, 255)
			light.Parent = child
		end
	end
end

local function primaryPart(context, model)
	return context.Services.AssetService.EnsurePrimaryPart(model)
end

local function moveLoop(context, model, token, center)
	task.spawn(function()
		local point = 1
		while model.Parent and active[model] and eventToken == token do
			local part = primaryPart(context, model)
			if not part then
				break
			end
			point += 1
			local target = centralWaypoint(point + math.random(1, 5), 9, center)
			local distance = (part.Position - target).Magnitude
			local duration = math.clamp(distance / 13, 1.25, 3.5)
			local startPivot = model:IsA("Model") and model:GetPivot() or part.CFrame
			local steps = math.max(18, math.floor(duration / 0.035))
			for step = 1, steps do
				if not model.Parent or not active[model] or eventToken ~= token then
					return
				end
				local alpha = step / steps
				local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				local pos = startPivot.Position:Lerp(target, eased)
				local bob = math.sin(alpha * math.pi * 2) * 1.15
				context.Services.AssetService.SetModelCFrame(model, CFrame.new(pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, alpha * math.pi * 2, 0))
				task.wait(0.035)
			end
			task.wait(0.2)
		end
	end)
end

local function rewardPlayer(context, player, rare)
	local config = context.Config.EventConfig.PhantomSnackChase
	local coins = math.random(config.BaseCoinReward or 75, config.MaxCoinReward or 250)
	context.Services.EconomyService.AddCoins(player, coins)
	if math.random() < (config.CookieSeedChance or 0.2) then
		context.Services.EconomyService.AddSeeds(player, "CookieRock", 1, false)
	end
	if math.random() < (config.JellySeedChance or 0.1) then
		context.Services.EconomyService.AddSeeds(player, "JellyCube", 1, false)
	end
	if math.random() < (config.MeteorSeedChance or 0.03) then
		context.Services.EconomyService.AddSeeds(player, "MeteorMuffin", 1, false)
	end
	if rare then
		local tokens = math.random(config.VoidTokenMin or 1, config.VoidTokenMax or 3)
		context.Services.EconomyService.AddVoidTokens(player, tokens)
	end
	context.Services.QuestService.Record(player, "CatchPhantomSnacks", 1)
	context.Services.StatsService.Record(player, "PhantomSnacksCaught", 1)
	context.Services.EventService.MarkParticipation(player, "PhantomSnack")
	context.Services.EconomyService.Notify(player, "Caught a Phantom Snack! +" .. tostring(coins) .. " coins.")
	if context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.PhantomCaught(player)
	else
		context.Services.EconomyService.NotifyAll(player.Name .. " caught a Phantom Snack!")
	end
end

function PhantomSnackService.Init(context)
	PhantomSnackService.Context = context
end

function PhantomSnackService.Start() end

function PhantomSnackService.Cleanup()
	for model, maid in pairs(active) do
		if maid then
			maid:DoCleaning()
		elseif model and model.Parent then
			model:Destroy()
		end
	end
	active = {}
end

function PhantomSnackService.SpawnForEvent(duration, options)
	options = type(options) == "table" and options or {}
	local context = PhantomSnackService.Context
	if not enabled() then
		return 0
	end
	local folder = options.ParentFolder or getFolder()
	if not folder then
		return 0
	end
	eventToken += 1
	local token = eventToken
	PhantomSnackService.Cleanup()
	local players = Players:GetPlayers()
	local config = context.Config.EventConfig.PhantomSnackChase
	local maxAllowed = math.max(3, math.min(config.MaxActivePhantoms or 5, limitValue("MaxPhantomSnacks", 5), limitValue("MaxPhantoms", 5)))
	local count = math.clamp(tonumber(options.Count) or math.max(3, math.ceil(#players / 2)), 3, maxAllowed)
	local center = options.Center
	if not center and context.Services.WorldSpectacleService then
		center = context.Services.WorldSpectacleService.GetArenaOrigin() + Vector3.new(0, 7, 0)
	end
	center = center or Vector3.new(0, 7, 0)
	for index = 1, count do
		local maid = Maid.new()
		local assetKey = context.Services.AssetService.HasAsset("PhantomSnack") and "PhantomSnack" or "SnackRoundBase"
		local model = context.Services.AssetService.CloneModel(assetKey)
		model.Name = "PhantomSnack_" .. tostring(index) .. "_" .. tostring(os.clock()):gsub("%.", "_")
		model:SetAttribute("PhantomSnack", true)
		model:SetAttribute("RarePhantom", index == 1)
		model:SetAttribute("ChaseCenter", center)
		model.Parent = folder
		context.Services.AssetService.SetModelCFrame(model, CFrame.new(centralWaypoint(index, count + 2, center)))
		if context.Services.AssetService.ScaleToTargetMaxDimension then
			context.Services.AssetService.ScaleToTargetMaxDimension(model, 5.2)
		else
			context.Services.AssetService.ScaleToTargetSize(model, Vector3.new(5.2, 5.2, 5.2))
		end
		stylePhantom(model, index)
		if not context.Services.WorldSpectacleService then
			context.Services.AssetService.AddBillboard(model, "Phantom Snack", Vector3.new(0, 2.7, 0))
		end
		local prompt = context.Services.AssetService.AddProximityPrompt(model, "Phantom Snack", "Catch")
		if prompt then
			prompt.MaxActivationDistance = distanceValue("Phantom", 14)
			maid:GiveTask(prompt.Triggered:Connect(function(player)
				PhantomSnackService.Catch(player, model)
			end))
		end
		local part = primaryPart(context, model)
		if part then
			maid:GiveTask(part.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					PhantomSnackService.Catch(player, model)
				end
			end))
		end
		maid:GiveTask(model)
		active[model] = maid
		if context.Services.VFXService then
			context.Services.VFXService.PlayForNearbyPlayers("Event.Phantom.Appear", model, 90, {
				Target = model,
				Text = "Phantom Snack!",
				MinInterval = 0.12,
			})
		end
		moveLoop(context, model, token, center)
	end
	task.delay(duration or 45, function()
		if eventToken == token then
			PhantomSnackService.Cleanup()
		end
	end)
	return count
end

function PhantomSnackService.TryTriggerFromDisplay(player, item)
	local context = PhantomSnackService.Context
	if not enabled() then
		return false
	end
	if context.Services.EventService.GetActiveEventName() then
		return false
	end
	local snack = item and context.Config.SnackConfig[item.SnackId]
	if not snack or snack.Rarity ~= "Rare" then
		return false
	end
	if math.random() > 0.08 then
		return false
	end
	return context.Services.EventService.StartEvent("PhantomSnackChase")
end

function PhantomSnackService.Catch(player, model)
	local context = PhantomSnackService.Context
	if not enabled() then
		return false
	end
	if typeof(model) ~= "Instance" or not model:IsDescendantOf(workspace) or not model:GetAttribute("PhantomSnack") then
		return false
	end
	if not active[model] or model:GetAttribute("Caught") then
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, model, distanceValue("Phantom", 14)) then
		context.Services.EconomyService.Notify(player, "Move closer to catch the Phantom Snack.")
		return false
	end
	model:SetAttribute("Caught", true)
	local catchPosition = nil
	local primary = primaryPart(context, model)
	if primary then
		catchPosition = primary.Position
	end
	local maid = active[model]
	active[model] = nil
	local rare = model:GetAttribute("RarePhantom") == true
	if maid then
		maid:DoCleaning()
	elseif model.Parent then
		model:Destroy()
	end
	rewardPlayer(context, player, rare)
	if context.Services.AudioService then
		context.Services.AudioService.PlayForPlayer(player, "Events.PhantomCaught", "World", catchPosition, { MinInterval = 0.12 })
	end
	if context.Services.VFXService then
		context.Services.VFXService.PlayForPlayer(player, "Event.Phantom.Caught", {
			Mode = "World",
			Position = catchPosition,
			Text = rare and "Rare Phantom caught!" or "Phantom caught!",
			MinInterval = 0.12,
		})
	end
	return true
end

function PhantomSnackService.CountActive()
	local count = 0
	for model in pairs(active) do
		if model and model.Parent then
			count += 1
		end
	end
	return count
end

return PhantomSnackService
