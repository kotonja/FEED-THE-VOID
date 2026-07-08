local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuidanceConfig = require(Shared:WaitForChild("GuidanceConfig"))

local GuidanceController = {}

local player = Players.LocalPlayer
local currentData = nil
local currentGoal = nil
local currentInstance = nil
local currentPosition = nil
local currentText = ""
local settings = {}
local visuals = nil
local heartbeatConnection = nil
local pulseTween = nil

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function instancePosition(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Model") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		return ok and pivot.Position or nil
	end
	local part = instance:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function firstBasePart(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function plateNumber(plate)
	return tonumber(tostring(plate and plate.Name or ""):match("(%d+)")) or 1
end

local function world()
	return workspace:FindFirstChild("GameWorld")
end

local function findPlotById(plotId)
	local gameWorld = world()
	local plots = gameWorld and gameWorld:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	plotId = tonumber(plotId) or 0
	if plotId > 0 then
		local named = plots:FindFirstChild("Plot" .. tostring(plotId))
		if named then
			return named
		end
		for _, plot in ipairs(plots:GetChildren()) do
			if tonumber(plot:GetAttribute("PlotId")) == plotId then
				return plot
			end
		end
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if tonumber(plot:GetAttribute("OwnerUserId")) == player.UserId then
			return plot
		end
	end
	return nil
end

local function ownPlot()
	return findPlotById(currentData and currentData.AssignedPlotId)
end

local function sortedPlates(plot)
	local plates = {}
	local folder = plot and plot:FindFirstChild("Plates")
	if not folder then
		return plates
	end
	for _, plate in ipairs(folder:GetChildren()) do
		if plate:IsA("BasePart") then
			table.insert(plates, plate)
		end
	end
	table.sort(plates, function(a, b)
		return plateNumber(a) < plateNumber(b)
	end)
	return plates
end

local function findPlate(kind)
	local plot = ownPlot()
	local usable = currentData and currentData.Upgrades and tonumber(currentData.Upgrades.Plates) or 6
	local fallback = nil
	for _, plate in ipairs(sortedPlates(plot)) do
		if plateNumber(plate) <= usable then
			fallback = fallback or plate
			local occupied = plate:GetAttribute("Occupied") == true
			local ready = occupied and tonumber(plate:GetAttribute("GrowthStage")) == 3
			if kind == "ReadyPlate" and ready then
				return plate
			elseif (kind == "Plate" or kind == "EmptyPlate") and not occupied then
				return plate
			end
		end
	end
	return fallback
end

local function findNearestVoidmite()
	local gameWorld = world()
	local folder = gameWorld and gameWorld:FindFirstChild("ActiveVoidmites")
	if not folder then
		return nil
	end
	local root = getRoot()
	local best = nil
	local bestDistance = math.huge
	for _, voidmite in ipairs(folder:GetChildren()) do
		if tonumber(voidmite:GetAttribute("OwnerUserId")) == player.UserId or not best then
			local pos = instancePosition(voidmite)
			local distance = root and pos and (root.Position - pos).Magnitude or 0
			if distance < bestDistance then
				best = voidmite
				bestDistance = distance
			end
		end
	end
	return best
end

local function findStation(stationName)
	local plot = ownPlot()
	if plot then
		local station = plot:FindFirstChild(stationName)
		if station then
			return station
		end
	end
	local gameWorld = world()
	local stations = gameWorld and gameWorld:FindFirstChild("Stations")
	return stations and stations:FindFirstChild(stationName) or nil
end

local function resolveGoal(goal)
	if type(goal) ~= "table" then
		return nil
	end
	local targetType = goal.TargetType or goal.Kind
	if targetType == "Plot" then
		local plot = ownPlot()
		return plot and (plot:FindFirstChild("PlotSpawn") or firstBasePart(plot)) or nil
	elseif targetType == "ReadyPlate" then
		return findPlate("ReadyPlate")
	elseif targetType == "Plate" or targetType == "EmptyPlate" then
		return findPlate("Plate")
	elseif targetType == "FeedVoid" or targetType == "Void" or targetType == "CentralVoid" then
		local gameWorld = world()
		local central = gameWorld and gameWorld:FindFirstChild("CentralVoid")
		return central and (central:FindFirstChild("FeedStation") or central:FindFirstChild("VoidCore") or firstBasePart(central)) or nil
	elseif targetType == "Shop" or targetType == "SeedShop" then
		return findStation("SeedShopStation")
	elseif targetType == "Upgrade" then
		return findStation("UpgradeStation")
	elseif targetType == "Display" then
		return findStation("DisplayShelf")
	elseif targetType == "Rebirth" then
		return findStation("RebirthStation")
	elseif targetType == "DailyReward" then
		return findStation("DailyRewardChest")
	elseif targetType == "Voidmite" then
		return findNearestVoidmite() or findStation("DisplayShelf")
	elseif targetType == "Event" then
		local gameWorld = world()
		local events = gameWorld and gameWorld:FindFirstChild("EventObjects")
		return events and events:GetChildren()[1] or resolveGoal({ TargetType = "FeedVoid" })
	elseif targetType == "Rewards" or targetType == "Objectives" then
		local plot = ownPlot()
		return plot and (plot:FindFirstChild("PlotSpawn") or firstBasePart(plot)) or nil
	end
	return nil
end

local function ensureVisuals()
	if visuals then
		return visuals
	end
	local targetPart = Instance.new("Part")
	targetPart.Name = "FTVGuidanceTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = GuidanceConfig.TargetPartSize or Vector3.new(1, 1, 1)
	targetPart.Parent = workspace

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TargetAttachment"
	targetAttachment.Parent = targetPart

	local beam = Instance.new("Beam")
	beam.Name = "FTVGuidanceBeam"
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(GuidanceConfig.BeamColor)
	beam.LightEmission = 0.15
	beam.LightInfluence = 0.25
	beam.TextureSpeed = 1.2
	beam.Transparency = NumberSequence.new(0.18, 0.55)
	beam.Width0 = GuidanceConfig.BeamWidth0 or 0.4
	beam.Width1 = GuidanceConfig.BeamWidth1 or 0.18
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Parent = targetPart

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FTVGuidanceBillboard"
	billboard.Adornee = targetPart
	billboard.Size = UDim2.fromOffset(150, 52)
	billboard.StudsOffset = GuidanceConfig.LabelStudsOffset or Vector3.new(0, 2.7, 0)
	billboard.MaxDistance = GuidanceConfig.LabelMaxDistance or 160
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = targetPart

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 0.5)
	arrow.Position = UDim2.fromScale(0, 0)
	arrow.Text = "v"
	arrow.TextColor3 = Color3.fromRGB(244, 225, 255)
	arrow.TextStrokeTransparency = 0.25
	arrow.TextScaled = true
	arrow.Font = Enum.Font.GothamBlack
	arrow.Parent = billboard

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundColor3 = Color3.fromRGB(24, 17, 34)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 0.48)
	label.Position = UDim2.fromScale(0, 0.5)
	label.Text = "HERE"
	label.TextColor3 = Color3.fromRGB(255, 246, 220)
	label.TextStrokeTransparency = 0.75
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	visuals = {
		TargetPart = targetPart,
		TargetAttachment = targetAttachment,
		Beam = beam,
		Billboard = billboard,
		Label = label,
		Arrow = arrow,
		RootAttachment = nil,
	}
	return visuals
end

local function enabled()
	return settings.ShowGuidance ~= false
end

local function setVisible(isVisible)
	local v = ensureVisuals()
	v.Beam.Enabled = isVisible
	v.Billboard.Enabled = isVisible
end

local function setRootAttachment()
	local root = getRoot()
	local v = ensureVisuals()
	if not root then
		v.Beam.Attachment0 = nil
		return false
	end
	if not v.RootAttachment or v.RootAttachment.Parent ~= root then
		if v.RootAttachment then
			v.RootAttachment:Destroy()
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "FTVGuidanceRoot"
		attachment.Position = Vector3.new(0, 1.4, 0)
		attachment.Parent = root
		v.RootAttachment = attachment
		v.Beam.Attachment0 = attachment
	end
	return true
end

local function updateVisualPosition()
	if not enabled() then
		setVisible(false)
		return
	end
	if not setRootAttachment() then
		setVisible(false)
		return
	end
	local position = currentPosition
	if currentInstance and currentInstance.Parent then
		position = instancePosition(currentInstance)
	end
	if not position then
		setVisible(false)
		return
	end
	local root = getRoot()
	if root and (root.Position - position).Magnitude > (GuidanceConfig.MaxDistance or 1400) then
		setVisible(false)
		return
	end
	local v = ensureVisuals()
	v.TargetPart.CFrame = CFrame.new(position + (GuidanceConfig.TargetHeightOffset or Vector3.new(0, 2, 0)))
	v.Label.Text = tostring(currentText ~= "" and currentText or "HERE")
	local lowDetail = settings.LowDetailMode == true
	v.Beam.Color = ColorSequence.new(lowDetail and GuidanceConfig.BeamColorLowDetail or GuidanceConfig.BeamColor)
	v.Beam.Width0 = lowDetail and (GuidanceConfig.LowDetailBeamWidth0 or 0.22) or (GuidanceConfig.BeamWidth0 or 0.45)
	v.Beam.Width1 = lowDetail and (GuidanceConfig.LowDetailBeamWidth1 or 0.1) or (GuidanceConfig.BeamWidth1 or 0.18)
	setVisible(true)
end

local function startLoop()
	if heartbeatConnection then
		return
	end
	heartbeatConnection = RunService.Heartbeat:Connect(updateVisualPosition)
end

local function startPulse()
	local v = ensureVisuals()
	if pulseTween then
		return
	end
	pulseTween = TweenService:Create(v.Arrow, TweenInfo.new(GuidanceConfig.ArrowPulseSeconds or 0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		TextTransparency = 0.28,
	})
	pulseTween:Play()
end

local function applyTarget(targetInstance, targetPosition, labelText)
	currentInstance = targetInstance
	currentPosition = targetPosition
	currentText = tostring(labelText or "HERE")
	ensureVisuals()
	startLoop()
	startPulse()
	updateVisualPosition()
end

function GuidanceController.Init()
	ensureVisuals()
	setVisible(false)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		updateVisualPosition()
	end)
end

function GuidanceController.ShowBeamToInstance(instance, labelText)
	currentGoal = nil
	if typeof(instance) ~= "Instance" then
		GuidanceController.HideGuidance()
		return
	end
	applyTarget(instance, nil, labelText)
end

function GuidanceController.ShowBeamToWorldPosition(position, labelText)
	currentGoal = nil
	if typeof(position) ~= "Vector3" then
		GuidanceController.HideGuidance()
		return
	end
	applyTarget(nil, position, labelText)
end

function GuidanceController.ShowArrowToInstance(instance, labelText)
	GuidanceController.ShowBeamToInstance(instance, labelText)
end

function GuidanceController.HideGuidance()
	setVisible(false)
	currentInstance = nil
	currentPosition = nil
	currentText = ""
end

function GuidanceController.SetGuidanceTarget(goalData)
	currentGoal = type(goalData) == "table" and goalData or nil
	if not currentGoal then
		GuidanceController.HideGuidance()
		return
	end
	local target = resolveGoal(currentGoal)
	if not target then
		GuidanceController.HideGuidance()
		return
	end
	applyTarget(target, nil, currentGoal.Text or "HERE")
end

function GuidanceController.ClearGuidanceTarget()
	currentGoal = nil
	GuidanceController.HideGuidance()
end

function GuidanceController.ApplyData(data)
	currentData = data
	settings = data and data.Settings or settings or {}
	if currentGoal or (data and data.NextGoal) then
		GuidanceController.SetGuidanceTarget(data and data.NextGoal or currentGoal)
	else
		updateVisualPosition()
	end
end

return GuidanceController
