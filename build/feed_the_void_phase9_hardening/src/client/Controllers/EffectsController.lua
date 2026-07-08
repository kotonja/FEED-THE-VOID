local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EffectsController = {}

local player = Players.LocalPlayer
local mainUi
local rewardFrame
local rewardIndex = 1
local rewardLabels = {}
local reduceEffects = false
local lowDetailMode = false
local hideExtraPopups = false
local soundController
local activeGrowthVfx = {}

local TEXTURES = {
	Aura = "rbxassetid://7216855914",
	Spark = "rbxassetid://7216849325",
	SwirlA = "rbxassetid://10558425570",
	SwirlB = "rbxassetid://14050094484",
	SoftFog = "rbxassetid://14049993216",
	Bloom = "rbxassetid://14050321697",
	Ring = "rbxassetid://7216847852",
	WideRare = "rbxassetid://14221378803",
}

local COLORS = {
	VoidPurple = Color3.fromRGB(156, 80, 255),
	DeepVoid = Color3.fromRGB(47, 21, 82),
	SoftViolet = Color3.fromRGB(203, 158, 255),
	HarvestGold = Color3.fromRGB(255, 207, 96),
	CleanseCyan = Color3.fromRGB(118, 233, 255),
	PlantGreen = Color3.fromRGB(109, 225, 152),
	GlitchTeal = Color3.fromRGB(84, 255, 205),
	IceBlue = Color3.fromRGB(155, 229, 255),
	Pink = Color3.fromRGB(255, 112, 213),
}

local MUTATION_COLORS = {
	Big = Color3.fromRGB(255, 194, 112),
	Tiny = Color3.fromRGB(191, 160, 255),
	Golden = Color3.fromRGB(255, 210, 82),
	Frozen = Color3.fromRGB(142, 229, 255),
	Rainbow = Color3.fromRGB(255, 107, 207),
	VoidTouched = Color3.fromRGB(137, 68, 255),
	Glitched = Color3.fromRGB(80, 255, 190),
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(119, 230, 161),
	Uncommon = Color3.fromRGB(111, 225, 255),
	Rare = Color3.fromRGB(176, 128, 255),
	Epic = Color3.fromRGB(255, 103, 219),
	Legendary = Color3.fromRGB(255, 211, 94),
}

local function colorSequence(...)
	local colors = { ... }
	if #colors <= 1 then
		return ColorSequence.new(colors[1] or Color3.new(1, 1, 1))
	end
	local keypoints = {}
	for index, color in ipairs(colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local function numberSequence(points)
	if typeof(points) == "NumberSequence" then
		return points
	end
	if type(points) ~= "table" then
		return NumberSequence.new(points or 1)
	end
	local keypoints = {}
	for _, point in ipairs(points) do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keypoints)
end

local function detailScale()
	if lowDetailMode then
		return 0.45
	end
	if reduceEffects then
		return 0.65
	end
	return 1
end

local function scaledCount(count)
	return math.max(2, math.floor((count or 12) * detailScale()))
end

local function getPrimaryPart(model)
	if typeof(model) ~= "Instance" then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getPosition(target, payload)
	if payload and typeof(payload.Position) == "Vector3" then
		return payload.Position
	end
	if typeof(target) == "Vector3" then
		return target
	end
	if typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			return target.Position
		end
		if target:IsA("Model") then
			return target:GetPivot().Position
		end
		local part = getPrimaryPart(target)
		return part and part.Position or nil
	end
	return nil
end

local function createAnchor(position, lifetime)
	local anchor = Instance.new("Part")
	anchor.Name = "FTVLocalVFXAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace
	Debris:AddItem(anchor, lifetime or 3)
	return anchor
end

local function makeEmitter(parent, config)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = config.Name or "FTVParticle"
	emitter.Enabled = false
	emitter.Texture = config.Texture or TEXTURES.Aura
	emitter.Color = config.Color or colorSequence(COLORS.VoidPurple)
	emitter.LightEmission = config.LightEmission or 0.75
	emitter.LightInfluence = config.LightInfluence or 0
	emitter.Brightness = config.Brightness or 1
	emitter.Lifetime = config.Lifetime or NumberRange.new(0.45, 0.85)
	emitter.Speed = config.Speed or NumberRange.new(3, 6)
	emitter.Drag = config.Drag or 1.5
	emitter.Acceleration = config.Acceleration or Vector3.new(0, 1.5, 0)
	emitter.RotSpeed = config.RotSpeed or NumberRange.new(-180, 180)
	emitter.Rotation = config.Rotation or NumberRange.new(-180, 180)
	emitter.SpreadAngle = config.SpreadAngle or Vector2.new(360, 360)
	emitter.Size = numberSequence(config.Size or {
		{ 0, 1.2 },
		{ 0.45, 2.3 },
		{ 1, 0 },
	})
	emitter.Transparency = numberSequence(config.Transparency or {
		{ 0, 1 },
		{ 0.12, 0.08 },
		{ 0.72, 0.18 },
		{ 1, 1 },
	})
	emitter.Parent = parent
	return emitter
end

local function emitBurst(position, config)
	if not position then
		return
	end
	config = config or {}
	local anchor = createAnchor(position + (config.Offset or Vector3.zero), config.Duration or 3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "FTVEmitterAttachment"
	attachment.Parent = anchor
	local emitter = makeEmitter(attachment, config)
	emitter:Emit(scaledCount(config.Count or 14))
	return anchor, emitter
end

local function pointLightAt(target, color, brightness, range, duration)
	if lowDetailMode then
		return
	end
	local part = getPrimaryPart(target)
	local anchor
	if not part then
		local position = getPosition(target)
		if not position then
			return
		end
		anchor = createAnchor(position, duration or 1)
		part = anchor
	end
	local light = Instance.new("PointLight")
	light.Name = "FTVLocalLight"
	light.Color = color or COLORS.VoidPurple
	light.Brightness = brightness or 1
	light.Range = range or 10
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(light, duration or 0.6)
end

local function flashHighlight(target, color, duration)
	if reduceEffects or lowDetailMode or typeof(target) ~= "Instance" then
		return
	end
	local adornment = target:IsA("Model") and target or getPrimaryPart(target)
	if not adornment then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "FTVLocalHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0.25
	highlight.OutlineColor = color or COLORS.VoidPurple
	highlight.Parent = adornment
	TweenService:Create(highlight, TweenInfo.new(duration or 0.5), { OutlineTransparency = 1 }):Play()
	Debris:AddItem(highlight, duration or 0.65)
end

local function pulseModel(model, strength)
	if reduceEffects or lowDetailMode or typeof(model) ~= "Instance" then
		return
	end
	strength = strength or 1.08
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local original = child.Size
			local grow = TweenService:Create(child, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original * strength })
			local shrink = TweenService:Create(child, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = original })
			grow:Play()
			grow.Completed:Once(function()
				if child.Parent then
					shrink:Play()
				end
			end)
		end
	end
end

local function showRewardText(message)
	if hideExtraPopups or not rewardFrame or #rewardLabels == 0 then
		return
	end
	local label = rewardLabels[rewardIndex]
	rewardIndex = (rewardIndex % #rewardLabels) + 1
	if not label then
		return
	end
	local startY = 18 + ((rewardIndex - 1) * 8)
	label.Text = tostring(message or "")
	label.Visible = true
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.2
	label.Position = UDim2.new(0.5, -150, 0, startY)
	local tween = TweenService:Create(label, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -150, 0, startY - 36),
		TextTransparency = 1,
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		label.Visible = false
	end)
end

local function addPersistentEmitter(attachment, config)
	if lowDetailMode then
		return
	end
	local emitter = makeEmitter(attachment, config)
	emitter.Enabled = true
	emitter.Rate = math.max(1, math.floor((config.Rate or 5) * detailScale()))
	return emitter
end

local function rarityColor(payload, target)
	local rarity = payload and payload.Rarity
	if not rarity and typeof(target) == "Instance" then
		rarity = target:GetAttribute("SnackRarity")
	end
	return RARITY_COLORS[rarity] or COLORS.PlantGreen
end

local function payloadStage(payload, target)
	local stage = payload and tonumber(payload.Stage)
	if not stage and typeof(target) == "Instance" then
		stage = tonumber(target:GetAttribute("GrowthStage"))
	end
	return stage or 1
end

local function targetSizeHint(target, payload)
	local size = payload and tonumber(payload.TargetMaxSize)
	if not size and typeof(target) == "Instance" then
		size = tonumber(target:GetAttribute("SnackCurrentMaxSize")) or tonumber(target:GetAttribute("SnackTargetMaxSize"))
	end
	return math.clamp(size or 2.2, 1.2, 4.2)
end

local function platePositionFromPayload(payload)
	local target = payload and payload.Target
	local function withSurfaceY(position)
		local surfaceY = payload and tonumber(payload.PlateTopY)
		if not surfaceY and typeof(target) == "Instance" then
			surfaceY = tonumber(target:GetAttribute("PlateTopY"))
		end
		if surfaceY then
			return Vector3.new(position.X, surfaceY, position.Z)
		end
		return position
	end
	if payload and typeof(payload.PlatePosition) == "Vector3" then
		return withSurfaceY(payload.PlatePosition)
	end
	if payload and typeof(payload.Plate) == "Instance" then
		local platePosition = getPosition(payload.Plate)
		return platePosition and withSurfaceY(platePosition) or nil
	end
	if typeof(target) == "Instance" then
		local plateCenter = target:GetAttribute("PlateCenter")
		if typeof(plateCenter) == "Vector3" then
			return withSurfaceY(plateCenter)
		end
	end
	local position = payload and getPosition(target, payload)
	if position then
		local yOffset = tonumber(payload.GrowthYOffset) or tonumber(payload.GrowthLift) or 1.4
		return position - Vector3.new(0, math.clamp(yOffset, 0.9, 3.5), 0)
	end
	return nil
end

local function emitPlatePulse(position, color, sizeHint, stage)
	if not position then
		return
	end
	local radius = math.clamp((sizeHint or 2.2) * (stage >= 3 and 1.15 or 1), 1.7, 5.1)
	emitBurst(position + Vector3.new(0, 0.22, 0), {
		Name = "GrowthPlatePulse",
		Texture = TEXTURES.Ring,
		Color = colorSequence(color, COLORS.SoftViolet),
		LightEmission = 0.28,
		Brightness = 0.85,
		Count = lowDetailMode and 2 or 4,
		Lifetime = NumberRange.new(0.85, 1.1),
		Speed = NumberRange.new(0.05, 0.2),
		Drag = 8,
		Size = { { 0, radius * 0.55 }, { 0.45, radius * 1.65 }, { 1, radius * 2.05 } },
		Transparency = { { 0, 0.65 }, { 0.18, 0.16 }, { 0.72, 0.38 }, { 1, 1 } },
	})
end

local function emitLiftMotes(basePosition, topPosition, color, sizeHint, stage)
	if not basePosition then
		return
	end
	local height = topPosition and math.clamp((topPosition.Y - basePosition.Y) * 0.35, 0.45, 1.6) or 0.8
	emitBurst(basePosition + Vector3.new(0, 0.3 + height, 0), {
		Name = "GrowthLiftMotes",
		Texture = stage >= 3 and TEXTURES.Spark or TEXTURES.SwirlA,
		Color = colorSequence(color, COLORS.SoftViolet, COLORS.PlantGreen),
		LightEmission = 0.32,
		Brightness = 0.95,
		Count = stage >= 3 and 24 or 16,
		Lifetime = NumberRange.new(0.65, 1.15),
		Speed = NumberRange.new(1.2, 3.8),
		Drag = 1.1,
		Acceleration = Vector3.new(0, 3.2, 0),
		Size = { { 0, 0.55 }, { 0.35, math.clamp((sizeHint or 2) * 0.7, 1.25, 2.75) }, { 1, 0 } },
		Transparency = { { 0, 0.95 }, { 0.18, 0.08 }, { 0.78, 0.22 }, { 1, 1 } },
	})
end

local function growthLiftBeam(basePosition, topPosition, color, sizeHint, duration)
	if lowDetailMode or not basePosition or not topPosition then
		return
	end
	local lifetime = duration or 0.65
	local startAnchor = createAnchor(basePosition + Vector3.new(0, 0.28, 0), lifetime + 0.15)
	local endAnchor = createAnchor(topPosition + Vector3.new(0, 0.16, 0), lifetime + 0.15)
	local a0 = Instance.new("Attachment")
	a0.Parent = startAnchor
	local a1 = Instance.new("Attachment")
	a1.Parent = endAnchor
	local beam = Instance.new("Beam")
	beam.Name = "FTVGrowthLiftBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = TEXTURES.SwirlB
	beam.TextureLength = 1.3
	beam.TextureSpeed = 2.8
	beam.Width0 = math.clamp((sizeHint or 2) * 0.25, 0.45, 1.15)
	beam.Width1 = math.clamp((sizeHint or 2) * 0.12, 0.16, 0.55)
	beam.LightEmission = 0.25
	beam.Color = colorSequence(color, COLORS.SoftViolet)
	beam.Transparency = numberSequence({ { 0, 0.42 }, { 0.55, 0.2 }, { 1, 1 } })
	beam.FaceCamera = true
	beam.Parent = startAnchor
	TweenService:Create(beam, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Width0 = 0, Width1 = 0 }):Play()
end

local function cleanupGrowthVfx(target)
	local record = activeGrowthVfx[target]
	if not record then
		return
	end
	record.Alive = false
	for _, connection in ipairs(record.Connections) do
		connection:Disconnect()
	end
	for _, instance in ipairs(record.Instances) do
		if instance and instance.Parent then
			instance:Destroy()
		end
	end
	activeGrowthVfx[target] = nil
end

local function startGrowthVfx(target, payload)
	if typeof(target) ~= "Instance" or target:GetAttribute("Displayed") then
		return
	end
	if payloadStage(payload, target) >= 3 then
		cleanupGrowthVfx(target)
		return
	end
	local part = getPrimaryPart(target)
	if not part then
		return
	end
	cleanupGrowthVfx(target)
	local color = rarityColor(payload, target)
	local sizeHint = targetSizeHint(target, payload)
	local attachment = Instance.new("Attachment")
	attachment.Name = "FTVGrowthVFX"
	attachment.Parent = part
	local light = Instance.new("PointLight")
	light.Name = "FTVGrowthLight"
	light.Color = color
	light.Brightness = reduceEffects and 0.12 or 0.24
	light.Range = math.clamp(sizeHint * 2.15, 4.5, 8.5)
	light.Parent = part
	local record = {
		Alive = true,
		Connections = {},
		Instances = { attachment, light },
	}
	activeGrowthVfx[target] = record

	addPersistentEmitter(attachment, {
		Name = "GrowthSoftAura",
		Texture = TEXTURES.Aura,
		Color = colorSequence(COLORS.DeepVoid, color, COLORS.SoftViolet),
		LightEmission = 0.24,
		Brightness = 0.82,
		Rate = 4,
		Lifetime = NumberRange.new(1.05, 1.65),
		Speed = NumberRange.new(0.15, 0.8),
		Drag = 2,
		Acceleration = Vector3.new(0, 0.8, 0),
		RotSpeed = NumberRange.new(-80, 80),
		Size = { { 0, sizeHint * 0.35 }, { 0.55, sizeHint * 0.95 }, { 1, 0 } },
		Transparency = { { 0, 0.9 }, { 0.22, 0.34 }, { 0.82, 0.62 }, { 1, 1 } },
	})
	addPersistentEmitter(attachment, {
		Name = "GrowthSpiral",
		Texture = TEXTURES.SwirlA,
		Color = colorSequence(color, COLORS.SoftViolet),
		LightEmission = 0.32,
		Brightness = 0.92,
		Rate = 5,
		Lifetime = NumberRange.new(0.85, 1.25),
		Speed = NumberRange.new(0.5, 1.45),
		Drag = 1.5,
		Acceleration = Vector3.new(0, 2.1, 0),
		RotSpeed = NumberRange.new(120, 260),
		Size = { { 0, sizeHint * 0.22 }, { 0.35, sizeHint * 0.72 }, { 1, 0 } },
		Transparency = { { 0, 0.85 }, { 0.2, 0.18 }, { 0.72, 0.38 }, { 1, 1 } },
	})
	addPersistentEmitter(attachment, {
		Name = "GrowthSparklets",
		Texture = TEXTURES.Spark,
		Color = colorSequence(COLORS.PlantGreen, color, COLORS.SoftViolet),
		LightEmission = 0.38,
		Brightness = 1,
		Rate = 9,
		Lifetime = NumberRange.new(0.45, 0.85),
		Speed = NumberRange.new(0.8, 2.4),
		Drag = 1.25,
		Acceleration = Vector3.new(0, 2.8, 0),
		Size = { { 0, 0.35 }, { 0.35, 0.95 }, { 1, 0 } },
	})

	table.insert(record.Connections, target.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanupGrowthVfx(target)
		end
	end))
	table.insert(record.Connections, target:GetAttributeChangedSignal("GrowthStage"):Connect(function()
		if payloadStage(nil, target) >= 3 then
			cleanupGrowthVfx(target)
		end
	end))

	task.spawn(function()
		while record.Alive and target.Parent and payloadStage(nil, target) < 3 do
			local position = getPosition(target, { Target = target })
			local basePosition = platePositionFromPayload(payload)
			if not basePosition and position then
				local yOffset = tonumber(target:GetAttribute("GrowthYOffset")) or tonumber(target:GetAttribute("GrowthLift")) or 1.35
				basePosition = position - Vector3.new(0, math.clamp(yOffset, 0.9, 3.5), 0)
			end
			local stage = payloadStage(nil, target)
			if basePosition then
				emitPlatePulse(basePosition, color, sizeHint, stage)
				emitLiftMotes(basePosition, position, color, sizeHint, stage)
			end
			task.wait(lowDetailMode and 2.2 or (reduceEffects and 1.65 or 1.15))
		end
		cleanupGrowthVfx(target)
	end)
end

local function playGrowthMoment(payload, ready)
	local target = payload.Target
	local position = getPosition(target, payload)
	local basePosition = platePositionFromPayload(payload)
	local stage = payloadStage(payload, target)
	local sizeHint = targetSizeHint(target, payload)
	local color = ready and COLORS.HarvestGold or rarityColor(payload, target)
	emitPlatePulse(basePosition or position, color, sizeHint, stage)
	if position then
		emitLiftMotes(basePosition or position, position, color, sizeHint, stage)
		growthLiftBeam(basePosition or (position - Vector3.new(0, 1.2, 0)), position, color, sizeHint, ready and 0.85 or 0.65)
	end
	flashHighlight(target, color, ready and 0.75 or 0.5)
	pointLightAt(target or position, color, ready and 1.1 or 0.65, ready and 10 or 7, ready and 0.65 or 0.42)
	pulseModel(target, ready and 1.045 or 1.03)
end

local function mutationColor(mutationId)
	return MUTATION_COLORS[mutationId or "Normal"] or COLORS.VoidPurple
end

local function attachMutationVfx(model)
	if typeof(model) ~= "Instance" or reduceEffects then
		return
	end
	local mutationId = model:GetAttribute("MutationId")
	if not mutationId or mutationId == "Normal" or mutationId == "Growing" then
		return
	end
	local part = getPrimaryPart(model)
	if not part then
		return
	end
	local oldAttachment = part:FindFirstChild("FTVMutationVFX")
	if oldAttachment and oldAttachment:GetAttribute("MutationId") == mutationId then
		return
	end
	if oldAttachment then
		oldAttachment:Destroy()
	end
	local oldLight = part:FindFirstChild("FTVMutationLight")
	if oldLight then
		oldLight:Destroy()
	end
	local color = mutationColor(mutationId)
	local attachment = Instance.new("Attachment")
	attachment.Name = "FTVMutationVFX"
	attachment:SetAttribute("MutationId", mutationId)
	attachment.Parent = part
	local light = Instance.new("PointLight")
	light.Name = "FTVMutationLight"
	light.Color = color
	light.Brightness = mutationId == "VoidTouched" and 0.8 or 0.55
	light.Range = mutationId == "VoidTouched" and 9 or 7
	light.Parent = part

	if mutationId == "Golden" then
		addPersistentEmitter(attachment, {
			Name = "GoldenAura",
			Texture = TEXTURES.Aura,
			Color = colorSequence(COLORS.HarvestGold, Color3.fromRGB(255, 245, 170)),
			Rate = 7,
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(0.4, 1.1),
			Size = { { 0, 0.9 }, { 0.45, 1.9 }, { 1, 0 } },
		})
	elseif mutationId == "Frozen" then
		addPersistentEmitter(attachment, {
			Name = "FrozenMist",
			Texture = TEXTURES.SoftFog,
			Color = colorSequence(COLORS.IceBlue, Color3.fromRGB(235, 255, 255)),
			Rate = 5,
			Lifetime = NumberRange.new(1.4, 2.1),
			Speed = NumberRange.new(0.15, 0.8),
			Size = { { 0, 0.7 }, { 0.55, 2.4 }, { 1, 0 } },
		})
	elseif mutationId == "Rainbow" then
		addPersistentEmitter(attachment, {
			Name = "RainbowStars",
			Texture = TEXTURES.Spark,
			Color = colorSequence(Color3.fromRGB(255, 78, 134), Color3.fromRGB(255, 220, 83), Color3.fromRGB(89, 255, 178), Color3.fromRGB(112, 153, 255), COLORS.Pink),
			Rate = 7,
			Lifetime = NumberRange.new(0.9, 1.4),
			Speed = NumberRange.new(0.8, 1.6),
			Size = { { 0, 0.55 }, { 0.25, 1.1 }, { 1, 0 } },
		})
	elseif mutationId == "VoidTouched" then
		addPersistentEmitter(attachment, {
			Name = "VoidAura",
			Texture = TEXTURES.Aura,
			Color = colorSequence(COLORS.DeepVoid, COLORS.VoidPurple, COLORS.SoftViolet),
			Rate = 8,
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(0.4, 1.3),
			Size = { { 0, 1.1 }, { 0.5, 2.8 }, { 1, 0 } },
		})
		addPersistentEmitter(attachment, {
			Name = "VoidBloom",
			Texture = TEXTURES.Bloom,
			Color = colorSequence(COLORS.DeepVoid, COLORS.VoidPurple),
			Rate = 3,
			Lifetime = NumberRange.new(1.6, 2.4),
			Speed = NumberRange.new(0.05, 0.4),
			Size = { { 0, 0.4 }, { 1, 3.4 } },
			Transparency = { { 0, 0.7 }, { 1, 1 } },
		})
	elseif mutationId == "Glitched" then
		addPersistentEmitter(attachment, {
			Name = "GlitchSparks",
			Texture = TEXTURES.Spark,
			Color = colorSequence(COLORS.GlitchTeal, COLORS.VoidPurple, Color3.fromRGB(255, 84, 225)),
			Rate = 10,
			Lifetime = NumberRange.new(0.45, 0.95),
			Speed = NumberRange.new(1.2, 2.8),
			Size = { { 0, 0.7 }, { 0.2, 1.35 }, { 1, 0 } },
		})
		task.spawn(function()
			for _ = 1, 12 do
				if not light.Parent then
					break
				end
				light.Enabled = not light.Enabled
				task.wait(0.055 + math.random() * 0.08)
			end
			if light.Parent then
				light.Enabled = true
			end
		end)
	else
		addPersistentEmitter(attachment, {
			Name = "MutationSparkle",
			Texture = TEXTURES.Spark,
			Color = colorSequence(color, COLORS.SoftViolet),
			Rate = mutationId == "Tiny" and 4 or 5,
			Lifetime = NumberRange.new(0.65, 1.15),
			Speed = NumberRange.new(0.6, 1.5),
			Size = { { 0, 0.55 }, { 0.3, mutationId == "Tiny" and 1.25 or 1.6 }, { 1, 0 } },
		})
	end
end

local function localPlayerBeam(targetPosition, color)
	if reduceEffects or lowDetailMode or not targetPosition then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local startAnchor = createAnchor(root.Position + Vector3.new(0, 1.2, 0), 0.55)
	local endAnchor = createAnchor(targetPosition, 0.55)
	local a0 = Instance.new("Attachment")
	a0.Parent = startAnchor
	local a1 = Instance.new("Attachment")
	a1.Parent = endAnchor
	local beam = Instance.new("Beam")
	beam.Name = "FTVFeedBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = TEXTURES.SwirlA
	beam.TextureLength = 1.6
	beam.TextureSpeed = 3.5
	beam.Width0 = 0.75
	beam.Width1 = 1.45
	beam.LightEmission = 0.8
	beam.Color = colorSequence(color or COLORS.VoidPurple, COLORS.SoftViolet)
	beam.Transparency = numberSequence({ { 0, 0.15 }, { 0.7, 0.08 }, { 1, 1 } })
	beam.FaceCamera = true
	beam.Parent = startAnchor
	TweenService:Create(beam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Width0 = 0, Width1 = 0 }):Play()
end

local function subtleCameraPulse()
	if reduceEffects or lowDetailMode then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local original = camera.FieldOfView
	local up = TweenService:Create(camera, TweenInfo.new(0.08), { FieldOfView = original + 1.2 })
	local down = TweenService:Create(camera, TweenInfo.new(0.18), { FieldOfView = original })
	up:Play()
	up.Completed:Once(function()
		if camera then
			down:Play()
		end
	end)
end

local handlers = {}

function handlers.Plant(payload)
	local target = payload.Target
	local position = getPosition(target, payload)
	local basePosition = platePositionFromPayload(payload)
	local color = rarityColor(payload, target)
	local sizeHint = targetSizeHint(target, payload)
	startGrowthVfx(target, payload)
	playGrowthMoment(payload, false)
	emitBurst(position, {
		Texture = TEXTURES.Bloom,
		Color = colorSequence(COLORS.DeepVoid, color, COLORS.PlantGreen),
		Count = 22,
		Lifetime = NumberRange.new(0.65, 1.1),
		Speed = NumberRange.new(1.6, 4.2),
		Acceleration = Vector3.new(0, 2.4, 0),
		Size = { { 0, sizeHint * 0.38 }, { 0.45, sizeHint * 1.35 }, { 1, 0 } },
	})
	emitBurst(position, {
		Texture = TEXTURES.Spark,
		Color = colorSequence(COLORS.PlantGreen, color, COLORS.SoftViolet),
		Count = 16,
		Lifetime = NumberRange.new(0.45, 0.85),
		Speed = NumberRange.new(2.5, 5.8),
		Acceleration = Vector3.new(0, 3.4, 0),
		Size = { { 0, 0.55 }, { 0.3, 1.15 }, { 1, 0 } },
	})
	growthLiftBeam(basePosition or (position and position - Vector3.new(0, 1, 0)), position, color, sizeHint, 0.75)
end

function handlers.GrowthStage(payload)
	local position = getPosition(payload.Target, payload)
	local color = rarityColor(payload, payload.Target)
	local sizeHint = targetSizeHint(payload.Target, payload)
	startGrowthVfx(payload.Target, payload)
	playGrowthMoment(payload, false)
	emitBurst(position, {
		Texture = TEXTURES.SwirlB,
		Color = colorSequence(COLORS.VoidPurple, color, COLORS.PlantGreen),
		Count = 22,
		Lifetime = NumberRange.new(0.75, 1.25),
		Speed = NumberRange.new(1.2, 3.8),
		Acceleration = Vector3.new(0, 3.8, 0),
		Size = { { 0, sizeHint * 0.32 }, { 0.5, sizeHint * 1.05 }, { 1, 0 } },
	})
end

function handlers.GrowthReady(payload)
	local position = getPosition(payload.Target, payload)
	local basePosition = platePositionFromPayload(payload)
	local sizeHint = targetSizeHint(payload.Target, payload)
	cleanupGrowthVfx(payload.Target)
	playGrowthMoment(payload, true)
	emitBurst(position, {
		Texture = TEXTURES.Ring,
		Color = colorSequence(COLORS.HarvestGold, COLORS.SoftViolet),
		Count = 24,
		Lifetime = NumberRange.new(0.75, 1.1),
		Speed = NumberRange.new(0.25, 1.15),
		Drag = 6,
		Size = { { 0, sizeHint * 0.6 }, { 0.4, sizeHint * 1.7 }, { 1, 0 } },
		Transparency = { { 0, 0.72 }, { 0.18, 0.08 }, { 0.68, 0.22 }, { 1, 1 } },
	})
	emitBurst(position, {
		Texture = TEXTURES.Spark,
		Color = colorSequence(COLORS.HarvestGold, Color3.fromRGB(255, 255, 220)),
		Count = 34,
		Lifetime = NumberRange.new(0.65, 1.2),
		Speed = NumberRange.new(3.2, 7.2),
		Acceleration = Vector3.new(0, 2.5, 0),
		Size = { { 0, 0.65 }, { 0.25, 1.65 }, { 1, 0 } },
	})
	emitLiftMotes(basePosition or position, position, COLORS.HarvestGold, sizeHint, 3)
	showRewardText((payload.DisplayName or "Snack") .. " ready")
end

function handlers.Harvest(payload)
	local position = getPosition(payload.Target, payload)
	local color = mutationColor(payload.MutationId)
	emitBurst(position, {
		Texture = TEXTURES.Aura,
		Color = colorSequence(color, COLORS.HarvestGold),
		Count = payload.MutationId and payload.MutationId ~= "Normal" and 30 or 22,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(3.8, 7.8),
		Size = { { 0, 0.9 }, { 0.35, 2.7 }, { 1, 0 } },
	})
	emitBurst(position, {
		Texture = TEXTURES.Spark,
		Color = colorSequence(COLORS.HarvestGold, color),
		Count = payload.MutationId and payload.MutationId ~= "Normal" and 26 or 16,
		Lifetime = NumberRange.new(0.6, 1.05),
		Speed = NumberRange.new(3.2, 7),
		Size = { { 0, 0.65 }, { 0.2, 1.45 }, { 1, 0 } },
	})
	if payload.MutationId and payload.MutationId ~= "Normal" then
		emitBurst(position, {
			Texture = TEXTURES.WideRare,
			Color = colorSequence(color, COLORS.SoftViolet),
			Count = 8,
			Lifetime = NumberRange.new(0.9, 1.4),
			Speed = NumberRange.new(0.15, 0.6),
			Size = { { 0, 1.4 }, { 1, 4.4 } },
			Transparency = { { 0, 0.62 }, { 1, 1 } },
		})
		showRewardText(payload.DisplayName or "Rare mutation!")
	elseif payload.Text then
		showRewardText(payload.Text)
	end
	pointLightAt(payload.Target or position, color, 1.2, 11, 0.5)
end

function handlers.Sell(payload)
	local position = getPosition(payload.Target, payload)
	emitBurst(position, {
		Texture = TEXTURES.Spark,
		Color = colorSequence(COLORS.HarvestGold, Color3.fromRGB(255, 245, 180)),
		Count = 12,
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(2, 4.5),
		Size = { { 0, 0.5 }, { 0.25, 1.1 }, { 1, 0 } },
	})
	if payload.Text then
		showRewardText(payload.Text)
	end
end

function handlers.Display(payload)
	local position = getPosition(payload.Target, payload)
	attachMutationVfx(payload.Target)
	emitBurst(position, {
		Texture = TEXTURES.SwirlA,
		Color = colorSequence(mutationColor(payload.MutationId), COLORS.SoftViolet),
		Count = 14,
		Lifetime = NumberRange.new(0.65, 1.1),
		Speed = NumberRange.new(1.1, 3),
		Size = { { 0, 0.8 }, { 0.4, 2.4 }, { 1, 0 } },
	})
	flashHighlight(payload.Target, mutationColor(payload.MutationId), 0.55)
	if payload.Text then
		showRewardText(payload.Text)
	end
end

function handlers.FeedVoid(payload)
	local position = getPosition(payload.Target, payload)
	local color = mutationColor(payload.MutationId)
	localPlayerBeam(position, color)
	emitBurst(position, {
		Texture = TEXTURES.Aura,
		Color = colorSequence(COLORS.DeepVoid, COLORS.VoidPurple, color),
		Count = 34,
		Lifetime = NumberRange.new(0.65, 1.25),
		Speed = NumberRange.new(3.5, 8.5),
		Size = { { 0, 1.6 }, { 0.45, 4.2 }, { 1, 0 } },
	})
	emitBurst(position, {
		Texture = TEXTURES.Bloom,
		Color = colorSequence(COLORS.DeepVoid, COLORS.VoidPurple),
		Count = 12,
		Lifetime = NumberRange.new(0.9, 1.5),
		Speed = NumberRange.new(0.3, 1.1),
		Size = { { 0, 1 }, { 1, 5.2 } },
		Transparency = { { 0, 0.55 }, { 1, 1 } },
	})
	pointLightAt(payload.Target or position, COLORS.VoidPurple, 1.35, 16, 0.7)
	subtleCameraPulse()
	if payload.Text then
		showRewardText(payload.Text)
	end
end

function handlers.VoidmiteSpawn(payload)
	local position = getPosition(payload.Target, payload)
	emitBurst(position, {
		Texture = TEXTURES.SoftFog,
		Color = colorSequence(COLORS.DeepVoid, COLORS.VoidPurple),
		Count = 20,
		Lifetime = NumberRange.new(0.75, 1.25),
		Speed = NumberRange.new(1.2, 3.2),
		Size = { { 0, 1 }, { 0.55, 3.1 }, { 1, 0 } },
	})
	emitBurst(position, {
		Texture = TEXTURES.Spark,
		Color = colorSequence(COLORS.VoidPurple, COLORS.SoftViolet),
		Count = 10,
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(2.2, 4.4),
		Size = { { 0, 0.5 }, { 0.35, 1.2 }, { 1, 0 } },
	})
	pointLightAt(payload.Target or position, COLORS.VoidPurple, 0.9, 9, 0.5)
	attachMutationVfx(payload.Target)
end

function handlers.VoidmiteCleanse(payload)
	local position = getPosition(payload.Target, payload)
	emitBurst(position, {
		Texture = TEXTURES.Ring,
		Color = colorSequence(COLORS.CleanseCyan, COLORS.SoftViolet),
		Count = 22,
		Lifetime = NumberRange.new(0.55, 0.95),
		Speed = NumberRange.new(2, 5.2),
		Size = { { 0, 1.2 }, { 0.35, 3.2 }, { 1, 0 } },
	})
	emitBurst(position, {
		Texture = TEXTURES.Spark,
		Color = colorSequence(COLORS.CleanseCyan, Color3.fromRGB(255, 255, 255)),
		Count = 24,
		Lifetime = NumberRange.new(0.55, 1.05),
		Speed = NumberRange.new(3.2, 7.5),
		Size = { { 0, 0.7 }, { 0.2, 1.5 }, { 1, 0 } },
	})
	pointLightAt(payload.Target or position, COLORS.CleanseCyan, 1.25, 12, 0.55)
	if payload.Text then
		showRewardText(payload.Text)
	end
end

local function handleEffect(payload)
	if type(payload) ~= "table" then
		return
	end
	local handler = handlers[payload.Type]
	if handler then
		handler(payload)
	end
end

local function isGrowingSnack(model)
	if typeof(model) ~= "Instance" or model:GetAttribute("Displayed") then
		return false
	end
	if not model:GetAttribute("SnackId") then
		return false
	end
	local stage = tonumber(model:GetAttribute("GrowthStage"))
	return stage ~= nil and stage < 3
end

local function watchModel(model)
	attachMutationVfx(model)
	if isGrowingSnack(model) then
		startGrowthVfx(model, {
			Target = model,
			Stage = model:GetAttribute("GrowthStage"),
			Rarity = model:GetAttribute("SnackRarity"),
			TargetMaxSize = model:GetAttribute("SnackCurrentMaxSize") or model:GetAttribute("SnackTargetMaxSize"),
		})
	end
	model:GetAttributeChangedSignal("GrowthStage"):Connect(function()
		local stage = tonumber(model:GetAttribute("GrowthStage"))
		if model:GetAttribute("SnackId") then
			if stage and stage < 3 then
				startGrowthVfx(model, {
					Target = model,
					Stage = stage,
					Rarity = model:GetAttribute("SnackRarity"),
					TargetMaxSize = model:GetAttribute("SnackCurrentMaxSize") or model:GetAttribute("SnackTargetMaxSize"),
				})
				pulseModel(model, 1.025)
			else
				cleanupGrowthVfx(model)
				pulseModel(model, 1.04)
			end
		else
			pulseModel(model)
		end
	end)
	model:GetAttributeChangedSignal("SnackId"):Connect(function()
		if isGrowingSnack(model) then
			startGrowthVfx(model, {
				Target = model,
				Stage = model:GetAttribute("GrowthStage"),
				Rarity = model:GetAttribute("SnackRarity"),
				TargetMaxSize = model:GetAttribute("SnackCurrentMaxSize") or model:GetAttribute("SnackTargetMaxSize"),
			})
		end
	end)
	model:GetAttributeChangedSignal("MutationId"):Connect(function()
		attachMutationVfx(model)
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
		for _, child in ipairs(voidmites:GetChildren()) do
			watchModel(child)
		end
		voidmites.ChildAdded:Connect(function(child)
			watchModel(child)
			if not reduceEffects then
				handlers.VoidmiteSpawn({ Target = child })
			end
		end)
	end
	local events = world:WaitForChild("EventObjects", 10)
	if events then
		events.ChildAdded:Connect(function(child)
			emitBurst(getPosition(child), {
				Texture = TEXTURES.Spark,
				Color = colorSequence(COLORS.HarvestGold, COLORS.VoidPurple),
				Count = 10,
				Lifetime = NumberRange.new(0.55, 0.9),
				Speed = NumberRange.new(1.8, 4.2),
				Size = { { 0, 0.6 }, { 0.35, 1.2 }, { 1, 0 } },
			})
		end)
	end
end

function EffectsController.Init(ui, sounds)
	mainUi = ui
	soundController = sounds
	rewardFrame = mainUi:FindFirstChild("FloatingRewards")
	if rewardFrame then
		for index = 1, 5 do
			local label = rewardFrame:FindFirstChild("Reward" .. tostring(index))
			if label then
				table.insert(rewardLabels, label)
			end
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
		local lower = string.lower(message)
		if message:find("%+") or lower:find("complete") or lower:find("harvest") or lower:find("fed") or lower:find("cleansed") or lower:find("caught") or lower:find("claimed") or lower:find("ready") then
			showRewardText(message)
		end
		if soundController then
			if lower:find("claimed") then
				soundController.Play("RewardClaim")
			elseif lower:find("caught") then
				soundController.Play("PhantomCaught")
			end
		end
	end)
	local playEffect = remotes:WaitForChild("PlayEffect", 10)
	if playEffect then
		playEffect.OnClientEvent:Connect(handleEffect)
	end
	task.spawn(attachWorldWatchers)
end

return EffectsController
