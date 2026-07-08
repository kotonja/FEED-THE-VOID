local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EffectsController = {}

local mainUi
local rewardFrame
local rewardIndex = 1
local rewardLabels = {}
local reduceEffects = false
local lowDetailMode = false
local hideExtraPopups = false
local soundController

local function getPrimaryPart(model)
	if model:IsA("BasePart") then
		return model
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

local function pulseModel(model)
	if reduceEffects or lowDetailMode then
		return
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local original = child.Size
			local grow = TweenService:Create(child, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original * 1.08 })
			local shrink = TweenService:Create(child, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = original })
			grow:Play()
			grow.Completed:Once(function()
				if child.Parent then
					shrink:Play()
				end
			end)
		end
	end
end

local function sparkleAt(model, color)
	if reduceEffects or lowDetailMode then
		return
	end
	local part = getPrimaryPart(model)
	if not part then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "FTVLocalSparkle"
	light.Brightness = 1.1
	light.Range = 10
	light.Color = color or Color3.fromRGB(190, 90, 255)
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	Debris:AddItem(light, 0.4)
end

local function showRewardText(message)
	if hideExtraPopups or not rewardFrame then
		return
	end
	local label = rewardLabels[rewardIndex]
	rewardIndex = (rewardIndex % #rewardLabels) + 1
	if not label then
		return
	end
	local startY = 18 + ((rewardIndex - 1) * 8)
	label.Text = message
	label.Visible = true
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.22
	label.Position = UDim2.new(0.5, -150, 0, startY)
	local tween = TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -150, 0, startY - 34),
		TextTransparency = 1,
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		label.Visible = false
	end)
end

local function watchModel(model)
	pulseModel(model)
	model:GetAttributeChangedSignal("GrowthStage"):Connect(function()
		pulseModel(model)
	end)
end

local function attachWorldWatchers()
	local world = workspace:WaitForChild("GameWorld", 10)
	if not world then
		return
	end
	local snacks = world:WaitForChild("ActiveSnacks", 10)
	if snacks then
		for _, child in ipairs(snacks:GetChildren()) do
			watchModel(child)
		end
		snacks.ChildAdded:Connect(watchModel)
	end
	local voidmites = world:WaitForChild("ActiveVoidmites", 10)
	if voidmites then
		voidmites.ChildAdded:Connect(function(child)
			sparkleAt(child, Color3.fromRGB(170, 80, 255))
		end)
	end
	local events = world:WaitForChild("EventObjects", 10)
	if events then
		events.ChildAdded:Connect(function(child)
			sparkleAt(child, Color3.fromRGB(255, 180, 80))
		end)
	end
end

function EffectsController.Init(ui, sounds)
	mainUi = ui
	soundController = sounds
	rewardFrame = mainUi:FindFirstChild("FloatingRewards")
	if rewardFrame then
		for index = 1, 5 do
			rewardLabels[index] = rewardFrame:FindFirstChild("Reward" .. tostring(index))
		end
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		reduceEffects = data.Settings and data.Settings.ReduceEffects == true or false
		lowDetailMode = data.Settings and data.Settings.LowDetailMode == true or false
		hideExtraPopups = data.Settings and data.Settings.HideExtraPopups == true or false
	end)
	remotes.NotifyClient.OnClientEvent:Connect(function(message)
		message = tostring(message or "")
		if message:find("%+") or message:find("complete") or message:find("harvest") or message:find("fed") or message:find("cleansed") or message:find("caught") or message:find("claimed") then
			showRewardText(message)
		end
		if soundController then
			if message:find("claimed") then
				soundController.Play("RewardClaim")
			elseif message:find("caught") then
				soundController.Play("PhantomCaught")
			end
		end
	end)
	task.spawn(attachWorldWatchers)
end

return EffectsController
