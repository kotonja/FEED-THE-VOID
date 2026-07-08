local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VFXController = {}

local mainUi
local rewardFrame
local rewardIndex = 1
local rewardLabels = {}

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
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local original = child.Size
			local grow = TweenService:Create(child, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original * 1.12 })
			local shrink = TweenService:Create(child, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = original })
			grow:Play()
			grow.Completed:Once(function()
				if child.Parent then
					shrink:Play()
				end
			end)
		end
	end
end

local function popIn(model)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local original = child.Size
			child.Size = original * 0.35
			TweenService:Create(child, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original }):Play()
		end
	end
end

local function sparkleAt(model, color)
	local part = getPrimaryPart(model)
	if not part then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "FTVLocalSparkle"
	light.Brightness = 1.6
	light.Range = 12
	light.Color = color or Color3.fromRGB(190, 90, 255)
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	Debris:AddItem(light, 0.45)
end

local function showRewardText(message)
	if not rewardFrame then
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
	popIn(model)
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
			popIn(child)
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

function VFXController.Init(ui)
	mainUi = ui
	rewardFrame = mainUi:FindFirstChild("FloatingRewards")
	if rewardFrame then
		for index = 1, 5 do
			rewardLabels[index] = rewardFrame:FindFirstChild("Reward" .. tostring(index))
		end
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.NotifyClient.OnClientEvent:Connect(function(message)
		message = tostring(message or "")
		if message:find("%+") or message:find("complete") or message:find("harvest") or message:find("fed") or message:find("cleansed") then
			showRewardText(message)
		end
	end)
	task.spawn(attachWorldWatchers)
end

return VFXController
