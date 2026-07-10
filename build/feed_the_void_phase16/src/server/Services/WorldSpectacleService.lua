local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local WorldSpectacleService = {}

local lastDiagnostics = nil
local lastBannerEvidence = nil

local feedMaxDimensionByTier = {
	Regular = 3.5,
	Chunky = 4.8,
	Huge = 6.4,
	Massive = 7.8,
	Colossal = 9.5,
	Voidborn = 13,
}

local sizePreviewMaxDimensionByTier = {
	Regular = 3.2,
	Huge = 7,
	Colossal = 13.8,
	Voidborn = 17.6,
}

local eventMaxDimension = {
	SnackRain = 25,
	MutationSurge = 16,
	VoidInfestation = 10,
	GoldenHunger = 10,
	PhantomSnackChase = 5.5,
}

local eventHorizontalOffset = {
	SnackRain = Vector3.new(0, 0, 0),
	MutationSurge = Vector3.new(-22, 0, 0),
	VoidInfestation = Vector3.new(22, 0, 0),
	GoldenHunger = Vector3.new(0, 0, 18),
	PhantomSnackChase = Vector3.new(0, 0, 0),
}

local eventColors = {
	SnackRain = Color3.fromRGB(255, 178, 76),
	MutationSurge = Color3.fromRGB(88, 242, 184),
	VoidInfestation = Color3.fromRGB(156, 84, 230),
	GoldenHunger = Color3.fromRGB(255, 218, 88),
	PhantomSnackChase = Color3.fromRGB(180, 132, 255),
}

local eventObjectName = {
	SnackRain = "SnackRainCloud",
	MutationSurge = "MutationCrystal",
	VoidInfestation = "VoidmiteNest",
	GoldenHunger = "GoldenHungerIdol",
	PhantomSnackChase = "PhantomChaseMarker",
}

local eventEvidenceAttribute = {
	SnackRain = "SnackRainCloud",
	MutationSurge = "MutationCrystal",
	VoidInfestation = "VoidmiteNest",
	GoldenHunger = "GoldenHungerIdol",
	PhantomSnackChase = "PhantomChaseMarker",
}

local snackAssetByType = {
	Round = "SnackRoundBase",
	Cube = "SnackCubeBase",
	Wrap = "SnackWrapBase",
}

local function now()
	return os.clock()
end

local function getWorld()
	return workspace:FindFirstChild("GameWorld") or workspace
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function folders()
	local world = getWorld()
	local spectacle = ensureFolder(world, "SpectacleObjects")
	local events = ensureFolder(world, "EventObjects")
	local feeds = ensureFolder(world, "FeedEffects")
	local visualTests = ensureFolder(world, "VisualTestObjects")
	return world, spectacle, events, feeds, visualTests
end

local function targetPosition(target)
	if typeof(target) == "Vector3" then
		return target
	end
	if typeof(target) ~= "Instance" then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	end
	if target:IsA("Model") then
		return target:GetPivot().Position
	end
	local part = target:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function centralVoid()
	local world = getWorld()
	local central = world:FindFirstChild("CentralVoid")
	if not central then
		return nil, Vector3.new(0, 8, 0), nil, nil
	end
	local core = central:FindFirstChild("VoidCore")
	local feedStation = central:FindFirstChild("FeedStation")
	local visuals = central:FindFirstChild("Visuals")
	local voidVisual = visuals and (visuals:FindFirstChild("TheVoidVisual") or visuals:FindFirstChildWhichIsA("Model")) or nil
	local target = core or feedStation or voidVisual or central
	return target, targetPosition(target) or Vector3.new(0, 8, 0), voidVisual, feedStation
end

local function arenaGroundPosition()
	local world = getWorld()
	local _, voidPosition, _, feedStation = centralVoid()
	if feedStation and feedStation:IsA("BasePart") then
		return Vector3.new(feedStation.Position.X, feedStation.Position.Y - (feedStation.Size.Y * 0.5), feedStation.Position.Z)
	end
	local spawnPoints = world:FindFirstChild("SpawnPoints")
	local centralSpawn = spawnPoints and spawnPoints:FindFirstChild("CentralSpawn")
	if centralSpawn and centralSpawn:IsA("BasePart") then
		return Vector3.new(centralSpawn.Position.X, centralSpawn.Position.Y, centralSpawn.Position.Z)
	end
	return voidPosition + Vector3.new(0, -40, 48)
end

local function rootPart(player)
	return player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") or nil
end

local function rootPosition(player)
	local root = rootPart(player)
	if root then
		return root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 2.6, 0)
	end
	local _, voidPosition = centralVoid()
	return voidPosition + Vector3.new(0, -24, 44)
end

local function horizontalUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.01 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function forEachBasePart(instance, callback)
	if instance:IsA("BasePart") then
		callback(instance)
	end
	for _, child in ipairs(instance:GetDescendants()) do
		if child:IsA("BasePart") then
			callback(child)
		end
	end
end

local function modelPrimary(model)
	local assetService = WorldSpectacleService.Context and WorldSpectacleService.Context.Services.AssetService
	if assetService then
		return assetService.EnsurePrimaryPart(model)
	end
	if model:IsA("BasePart") then
		return model
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function modelPivot(model)
	if model:IsA("BasePart") then
		return model.CFrame
	end
	return model:GetPivot()
end

local function boundingBox(model)
	local assetService = WorldSpectacleService.Context and WorldSpectacleService.Context.Services.AssetService
	if assetService and assetService.GetBoundingBox then
		return assetService.GetBoundingBox(model)
	end
	if model:IsA("BasePart") then
		return model.CFrame, model.Size
	end
	return model:GetBoundingBox()
end

local function scaleToMax(model, targetMax)
	local assetService = WorldSpectacleService.Context and WorldSpectacleService.Context.Services.AssetService
	if not assetService or not model or not targetMax then
		return nil
	end
	if assetService.ScaleToTargetMaxDimension then
		return assetService.ScaleToTargetMaxDimension(model, targetMax)
	end
	return assetService.ScaleToTargetSize(model, Vector3.new(targetMax, targetMax, targetMax))
end

local function pivotModel(model, cframe)
	local assetService = WorldSpectacleService.Context and WorldSpectacleService.Context.Services.AssetService
	if assetService then
		assetService.SetModelCFrame(model, cframe)
	elseif model:IsA("BasePart") then
		model.CFrame = cframe
	else
		model:PivotTo(cframe)
	end
end

local function placeModelBottomAt(model, groundPosition, yaw)
	pivotModel(model, CFrame.new(groundPosition) * CFrame.Angles(0, yaw or 0, 0))
	local boxCFrame, size = boundingBox(model)
	local bottomY = boxCFrame.Position.Y - (size.Y * 0.5)
	local deltaY = groundPosition.Y - bottomY
	pivotModel(model, modelPivot(model) + Vector3.new(0, deltaY, 0))
	return size
end

local function textureProtected(part)
	if part:IsA("MeshPart") and part.TextureID and part.TextureID ~= "" then
		return true
	end
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("SurfaceAppearance") or child:IsA("Texture") or child:IsA("Decal") then
			return true
		end
	end
	return false
end

local function styleModel(model, color, transparency)
	forEachBasePart(model, function(part)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = true
		part.CanTouch = false
		part.Massless = true
		if not textureProtected(part) then
			part.Color = color or part.Color
			part.Material = Enum.Material.Glass
			part.Transparency = math.max(part.Transparency, transparency or 0.08)
		end
	end)
	local primary = modelPrimary(model)
	if primary and not primary:FindFirstChild("WorldSpectacleLight") then
		local light = Instance.new("PointLight")
		light.Name = "WorldSpectacleLight"
		light.Color = color or Color3.fromRGB(180, 110, 255)
		light.Brightness = 1.55
		light.Range = 42
		light.Parent = primary
	end
	return primary
end

local function addHighlight(adornee, color, parent, lifetime)
	if not adornee then
		return nil
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "WorldSpectacleHighlight"
	highlight.Adornee = adornee
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
	highlight.OutlineTransparency = 0.12
	highlight.Parent = parent or adornee
	if lifetime then
		Debris:AddItem(highlight, lifetime)
	end
	return highlight
end

local function attachBillboard(modelOrPart, text, studsOffset, width, height, color, maxDistance)
	local assetService = WorldSpectacleService.Context and WorldSpectacleService.Context.Services.AssetService
	if assetService and typeof(modelOrPart) == "Instance" then
		return assetService.AttachBillboard(modelOrPart, {
			Name = "WorldSpectacleBillboard",
			Text = text,
			Size = UDim2.new(0, width or 270, 0, height or 74),
			StudsOffset = studsOffset or Vector3.new(0, 5, 0),
			MaxDistance = maxDistance or 110,
			BackgroundTransparency = 0.14,
			BackgroundColor3 = Color3.fromRGB(22, 18, 30),
			TextColor3 = color or Color3.fromRGB(255, 246, 216),
		})
	end
	return nil
end

local function addTrail(part, color, width, lifetime)
	if not part then
		return nil
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "SpectacleTrailA"
	a0.Position = Vector3.new(0, math.max(0.5, part.Size.Y * 0.32), 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "SpectacleTrailB"
	a1.Position = Vector3.new(0, -math.max(0.5, part.Size.Y * 0.32), 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "SpectacleTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color or Color3.fromRGB(184, 118, 255), Color3.fromRGB(255, 220, 128))
	trail.LightEmission = 0.35
	trail.Lifetime = lifetime or 0.72
	trail.MinLength = 0.2
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(width or 1.2)
	trail.Parent = part
	return trail
end

local function addBeam(fromPart, toPosition, color, width, parent)
	if not fromPart then
		return nil
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SpectacleBeamAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.35, 0.35, 0.35)
	anchor.Position = toPosition
	anchor.Parent = parent or fromPart.Parent
	local a0 = Instance.new("Attachment")
	a0.Name = "SpectacleBeamA"
	a0.Parent = fromPart
	local a1 = Instance.new("Attachment")
	a1.Name = "SpectacleBeamB"
	a1.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Name = "SpectacleBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color or Color3.fromRGB(171, 104, 255), Color3.fromRGB(255, 223, 120))
	beam.LightEmission = 0.35
	beam.Segments = 24
	beam.Width0 = width or 0.55
	beam.Width1 = math.max(0.18, (width or 0.55) * 0.42)
	beam.Transparency = NumberSequence.new(0.12)
	beam.Parent = fromPart
	return beam, anchor
end

local function makeShockwave(position, color, diameter, lifetime, parent, name)
	local ring = Instance.new("Part")
	ring.Name = name or "SpectacleShockwave"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Glass
	ring.Color = color or Color3.fromRGB(171, 104, 255)
	ring.Transparency = 0.34
	ring.Size = Vector3.new(0.16, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring:SetAttribute("SpectacleShockwave", true)
	ring.Parent = parent or select(2, folders())
	local tween = TweenService:Create(ring, TweenInfo.new(lifetime or 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.16, diameter or 24, diameter or 24),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, (lifetime or 0.9) + 0.2)
	return ring
end

local function makeImpactBurst(position, color, scale, parent)
	local folder = Instance.new("Folder")
	folder.Name = "FeedImpactBurst"
	folder:SetAttribute("FeedImpactBurst", true)
	folder.Parent = parent
	local count = 14
	for index = 1, count do
		local angle = (index / count) * math.pi * 2
		local vertical = ((index % 5) - 2) * 0.24
		local direction = Vector3.new(math.cos(angle), vertical + 0.28, math.sin(angle)).Unit
		local orb = Instance.new("Part")
		orb.Name = "ImpactShard"
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.Shape = Enum.PartType.Ball
		orb.Material = Enum.Material.Glass
		orb.Color = color
		orb.Transparency = 0.08
		orb.Size = Vector3.new(0.7, 0.7, 0.7) * math.clamp(scale * 0.15, 0.8, 2.1)
		orb.Position = position
		orb.Parent = folder
		TweenService:Create(orb, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = position + direction * (10 + scale * 1.4),
			Transparency = 1,
			Size = orb.Size * 0.35,
		}):Play()
	end
	Debris:AddItem(folder, 1)
	return folder
end

local function makeRewardPopup(position, text, color, parent)
	local anchor = Instance.new("Part")
	anchor.Name = "FeedRewardPopup"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position + Vector3.new(0, 7, 0)
	anchor:SetAttribute("FeedRewardPopup", true)
	anchor.Parent = parent
	attachBillboard(anchor, text or "+ VOID REWARD", Vector3.new(0, 0, 0), 250, 60, color, 140)
	TweenService:Create(anchor, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, 7, 0),
	}):Play()
	Debris:AddItem(anchor, 1.8)
	return anchor
end

local function animateModel(model, duration, bobHeight, rotationSpeed)
	local startPivot = modelPivot(model)
	local started = now()
	task.spawn(function()
		while model.Parent and now() - started < (duration or 30) do
			local elapsed = now() - started
			local bob = math.sin(elapsed * 2.4) * (bobHeight or 0.25)
			local yaw = elapsed * (rotationSpeed or 0.08)
			pivotModel(model, (startPivot + Vector3.new(0, bob, 0)) * CFrame.Angles(0, yaw, 0))
			task.wait(0.05)
		end
	end)
end

local function snackAssetKey(snack)
	if snack and snack.AssetKey then
		return snack.AssetKey
	end
	return snackAssetByType[(snack and snack.VisualType) or "Round"] or "SnackRoundBase"
end

local function sizeLabel(item)
	local sizeConfig = WorldSpectacleService.Context and WorldSpectacleService.Context.Config.SizeConfig
	if not sizeConfig then
		return tostring(item and item.SizeTier or "Regular")
	end
	local tier = sizeConfig.GetTier(item and item.SizeTier)
	return tier and tier.DisplayName or tostring(item and item.SizeTier or "Regular")
end

local function feedTargetMax(item, options)
	if type(options) == "table" and tonumber(options.TargetMaxDimension) then
		return math.clamp(tonumber(options.TargetMaxDimension), 3, 14)
	end
	local context = WorldSpectacleService.Context
	local tierId = context.Config.SizeConfig.NormalizeTier(item and item.SizeTier)
	return feedMaxDimensionByTier[tierId] or feedMaxDimensionByTier.Regular
end

local function fixedFeedStart(targetPositionValue)
	local _, _, _, feedStation = centralVoid()
	if feedStation and feedStation:IsA("BasePart") then
		return feedStation.Position + Vector3.new(0, 7, 0)
	end
	return targetPositionValue + Vector3.new(0, -24, 48)
end

function WorldSpectacleService.Init(context)
	WorldSpectacleService.Context = context
end

function WorldSpectacleService.Start()
	WorldSpectacleService.EnsureFolders()
end

function WorldSpectacleService.EnsureFolders()
	return folders()
end

function WorldSpectacleService.GetArenaOrigin()
	return arenaGroundPosition()
end

function WorldSpectacleService.GetEventOrigin(player, visualTest)
	local arenaOrigin = arenaGroundPosition()
	local root = rootPart(player)
	if not visualTest or not root then
		return arenaOrigin
	end
	local horizontalDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(arenaOrigin.X, 0, arenaOrigin.Z)).Magnitude
	if horizontalDistance <= 95 then
		return arenaOrigin
	end
	local forward = horizontalUnit(root.CFrame.LookVector)
	return Vector3.new(root.Position.X, root.Position.Y - 3.1, root.Position.Z) + forward * 28
end

function WorldSpectacleService.GetVisualTestFolder()
	return select(5, folders())
end

function WorldSpectacleService.ClearVisualTests()
	local visualTests = select(5, folders())
	for _, child in ipairs(visualTests:GetChildren()) do
		child:Destroy()
	end
	visualTests:SetAttribute("LastBannerEvent", nil)
	visualTests:SetAttribute("LastBannerObjective", nil)
	return true
end

function WorldSpectacleService.ClearEventObjects()
	local _, _, events = folders()
	for _, child in ipairs(events:GetChildren()) do
		child:Destroy()
	end
end

function WorldSpectacleService.NoteEventBanner(eventName, objectiveText)
	local visualTests = select(5, folders())
	lastBannerEvidence = {
		EventName = tostring(eventName or ""),
		ObjectiveText = tostring(objectiveText or ""),
		RecordedAt = now(),
	}
	visualTests:SetAttribute("LastBannerEvent", lastBannerEvidence.EventName)
	visualTests:SetAttribute("LastBannerObjective", lastBannerEvidence.ObjectiveText)
	return lastBannerEvidence
end

function WorldSpectacleService.GetLastBannerEvidence()
	return lastBannerEvidence
end

function WorldSpectacleService.PlayFeedSequence(player, item, startPosition, target, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, _, feedFolder = folders()
	local snack = context.Config.SnackConfig[item and item.SnackId or "CookieRock"] or context.Config.SnackConfig.CookieRock
	local mutationId = item and item.MutationId or "Normal"
	local targetObject, voidPosition = centralVoid()
	local targetPos = targetPosition(targetObject) or targetPosition(target) or voidPosition
	local requestedStart = startPosition or rootPosition(player)
	local fromPos = requestedStart
	if options.DebugVisual and (requestedStart - targetPos).Magnitude > 135 then
		fromPos = fixedFeedStart(targetPos)
	end
	local targetMax = feedTargetMax(item, options)
	local parent = options.ParentFolder or feedFolder
	local model = context.Services.AssetService.CloneModel(snackAssetKey(snack))
	model.Name = "FeedClone_" .. tostring(item and item.SizeTier or "Regular") .. "_" .. tostring(item and item.SnackId or "Snack")
	model:SetAttribute("FeedClone", true)
	model:SetAttribute("SnackId", item and item.SnackId or "CookieRock")
	model:SetAttribute("MutationId", mutationId)
	model:SetAttribute("SizeTier", item and item.SizeTier or "Regular")
	model:SetAttribute("FeedTargetMaxDimension", targetMax)
	model:SetAttribute("SpawnedAt", now())
	model.Parent = parent
	scaleToMax(model, targetMax)
	context.Services.AssetService.ApplyMutationVisual(model, mutationId, snack and snack.Color)
	local primary = styleModel(model, (snack and snack.Color) or Color3.fromRGB(210, 188, 128), 0.02)
	addHighlight(model, Color3.fromRGB(205, 145, 255), model)
	pivotModel(model, CFrame.new(fromPos))
	attachBillboard(model, "FEEDING\n" .. sizeLabel(item) .. " " .. tostring(snack and snack.DisplayName or "Snack"), Vector3.new(0, targetMax * 0.5 + 2.2, 0), 240, 68, Color3.fromRGB(255, 230, 160), 150)
	addTrail(primary, Color3.fromRGB(190, 114, 255), math.clamp(targetMax * 0.38, 1.15, 4.6), 0.9)
	local beam, beamAnchor = addBeam(primary, targetPos, Color3.fromRGB(175, 102, 255), math.clamp(targetMax * 0.17, 0.65, 2.4), parent)
	local distance = (fromPos - targetPos).Magnitude
	local travelDuration = math.clamp(distance / 72, 1.65, 2.9)
	local steps = 72
	local arcHeight = math.clamp((distance * 0.18) + (targetMax * 0.75), 16, 48)
	local cleanupLifetime = math.max(options.Lifetime or 0, travelDuration + 3.2)
	Debris:AddItem(model, cleanupLifetime)
	if beamAnchor then
		Debris:AddItem(beamAnchor, cleanupLifetime)
	end
	task.spawn(function()
		for step = 1, steps do
			if not model.Parent then
				return
			end
			local alpha = step / steps
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			local position = fromPos:Lerp(targetPos, eased)
			position += Vector3.new(0, math.sin(alpha * math.pi) * arcHeight, 0)
			local spin = CFrame.Angles(alpha * math.pi * 5, alpha * math.pi * 8, alpha * math.pi * 2)
			pivotModel(model, CFrame.new(position) * spin)
			task.wait(travelDuration / steps)
		end
		if not model.Parent then
			return
		end
		if beam then
			beam.Enabled = false
		end
		local shockwave = makeShockwave(targetPos - Vector3.new(0, 3.2, 0), Color3.fromRGB(174, 103, 255), 28 + targetMax * 4.2, 1.05, parent, "FeedImpactShockwave")
		shockwave:SetAttribute("FeedImpactShockwave", true)
		makeImpactBurst(targetPos, Color3.fromRGB(206, 128, 255), targetMax, parent)
		makeRewardPopup(targetPos, options.RewardText or "+ VOID REWARD", Color3.fromRGB(255, 226, 128), parent)
		WorldSpectacleService.PulseVoid(math.clamp(tonumber(options.Percent) or 50, 20, 100), "THE VOID DEVOURED IT", {
			Position = targetPos,
			ParentFolder = parent,
			Reason = "FeedImpact",
		})
		forEachBasePart(model, function(part)
			TweenService:Create(part, TweenInfo.new(0.36), { Transparency = 1 }):Play()
		end)
		task.wait(0.42)
		if model.Parent then
			model:Destroy()
		end
	end)
	return model
end

function WorldSpectacleService.PulseVoid(percent, text, options)
	options = type(options) == "table" and options or {}
	local _, spectacle = folders()
	local target, voidPosition, voidVisual = centralVoid()
	local position = options.Position or voidPosition
	local parent = options.ParentFolder or spectacle
	local clamped = math.clamp(tonumber(percent) or 50, 0, 100)
	local color = clamped >= 100 and Color3.fromRGB(255, 216, 96) or Color3.fromRGB(172, 96, 255)
	local diameter = 24 + (clamped * 0.42)
	local pulse = makeShockwave(position - Vector3.new(0, 3, 0), color, diameter, 1.05, parent, "VoidReaction_" .. tostring(math.floor(clamped)))
	pulse:SetAttribute("VoidPulse", true)
	pulse:SetAttribute("VoidReactionPercent", clamped)
	local adornee = voidVisual or target
	local highlight = addHighlight(adornee, color, parent, 0.75)
	if highlight then
		TweenService:Create(highlight, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			FillTransparency = 0.42,
			OutlineTransparency = 0,
		}):Play()
	end
	local visualPart = adornee and (adornee:IsA("BasePart") and adornee or adornee:FindFirstChildWhichIsA("BasePart", true)) or nil
	if visualPart then
		local originalSize = visualPart.Size
		local tweenUp = TweenService:Create(visualPart, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = originalSize * 1.035 })
		local tweenDown = TweenService:Create(visualPart, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = originalSize })
		tweenUp:Play()
		tweenUp.Completed:Once(function()
			if visualPart.Parent then
				tweenDown:Play()
			end
		end)
	end
	local marker = Instance.new("Part")
	marker.Name = "VoidReactionBillboardAnchor"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.Position = position + Vector3.new(0, 10, 0)
	marker:SetAttribute("VoidPulse", true)
	marker.Parent = parent
	attachBillboard(marker, tostring(text or ("VOID " .. tostring(math.floor(clamped)) .. "%")), Vector3.new(0, 0, 0), 300, 62, color, 170)
	Debris:AddItem(marker, 2.4)
	return pulse
end

function WorldSpectacleService.BeginVoidCharge(duration, eventName)
	local _, spectacle = folders()
	local target, voidPosition = centralVoid()
	local old = spectacle:FindFirstChild("VoidChargeSpectacle")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "VoidChargeSpectacle"
	folder:SetAttribute("VoidCharge", true)
	folder:SetAttribute("QueuedEventName", tostring(eventName or "Random Event"))
	folder.Parent = spectacle
	local seconds = math.max(1, tonumber(duration) or 4)
	local anchor = Instance.new("Part")
	anchor.Name = "VoidChargeAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = voidPosition + Vector3.new(0, 12, 0)
	anchor.Parent = folder
	attachBillboard(anchor, "THE VOID IS WAKING\n" .. tostring(eventName or "Random Event") .. "\n" .. tostring(math.ceil(seconds)) .. "s", Vector3.new(0, 0, 0), 320, 90, Color3.fromRGB(255, 222, 126), 180)
	for index = 1, 5 do
		local ring = makeShockwave(voidPosition - Vector3.new(0, 4 - index * 0.2, 0), Color3.fromRGB(174, 99, 255), 20 + index * 12, seconds, folder, "VoidChargeRing_" .. tostring(index))
		ring.Transparency = 0.48
	end
	if target and target:IsA("BasePart") then
		addBeam(anchor, target.Position, Color3.fromRGB(255, 212, 112), 1.4, folder)
	end
	Debris:AddItem(folder, seconds + 1.3)
	return folder
end

function WorldSpectacleService.SpawnEventProp(eventName, config, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local eventConfig = config or context.Config.EventConfig[eventName] or {}
	local color = options.Color or eventConfig.EventColor or eventColors[eventName] or Color3.fromRGB(174, 99, 255)
	local targetMax = options.TargetMaxDimension or eventMaxDimension[eventName] or 10
	local origin = options.Origin or arenaGroundPosition()
	local groundPosition = options.GroundPosition or (origin + (eventHorizontalOffset[eventName] or Vector3.zero))
	local assetKey = options.AssetKey or eventConfig.AssetKey or "EventMutationCrystal"
	local model = context.Services.AssetService.CloneModel(assetKey, { ApplyReferenceTargetSize = true })
	model.Name = eventObjectName[eventName] or ("EventSpectacle_" .. tostring(eventName or assetKey))
	model:SetAttribute("EventSpectacle", true)
	model:SetAttribute("EventName", tostring(eventName or assetKey))
	model:SetAttribute("TargetMaxDimension", targetMax)
	model:SetAttribute(eventEvidenceAttribute[eventName] or "EventProp", true)
	model.Parent = parent
	scaleToMax(model, targetMax)
	if eventName == "SnackRain" then
		pivotModel(model, CFrame.new(groundPosition + Vector3.new(0, options.CloudHeight or 30, 0)))
	else
		placeModelBottomAt(model, groundPosition + Vector3.new(0, 0.25, 0), options.Yaw or 0)
	end
	local primary = styleModel(model, color, 0.05)
	addHighlight(model, color, model)
	local banner = eventConfig.BannerName or eventConfig.DisplayName or tostring(eventName or "VOID EVENT")
	local objective = eventConfig.ObjectiveText or eventConfig.WorldVisualText or "Join the Void event."
	local duration = options.Duration or eventConfig.DebugDuration or eventConfig.Duration or 45
	model:SetAttribute("BannerName", banner)
	model:SetAttribute("ObjectiveText", objective)
	model:SetAttribute("DurationSeconds", duration)
	attachBillboard(model, banner .. "\n" .. objective .. "\n" .. tostring(math.ceil(duration)) .. "s", Vector3.new(0, math.max(5, targetMax * 0.55), 0), 330, 94, Color3.fromRGB(255, 242, 210), 145)
	local ringPosition = eventName == "SnackRain" and groundPosition + Vector3.new(0, 0.2, 0) or Vector3.new(modelPivot(model).Position.X, groundPosition.Y + 0.2, modelPivot(model).Position.Z)
	makeShockwave(ringPosition, color, math.max(18, targetMax * 1.9), 1.35, parent, "EventSpectacleRing_" .. tostring(eventName))
	if primary then
		local light = primary:FindFirstChild("WorldSpectacleLight")
		if light then
			light.Range = math.max(42, targetMax * 3)
			light.Brightness = eventName == "SnackRain" and 2.1 or 1.75
			TweenService:Create(light, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Brightness = light.Brightness * 0.45,
			}):Play()
		end
	end
	if eventName == "MutationSurge" then
		animateModel(model, duration, 0.65, 0.24)
	elseif eventName == "GoldenHunger" then
		animateModel(model, duration, 0.32, 0.1)
	elseif eventName == "SnackRain" then
		animateModel(model, duration, 0.8, 0.035)
	end
	if options.Lifetime then
		Debris:AddItem(model, options.Lifetime)
	end
	return model
end

function WorldSpectacleService.SpawnSnackRainPickup(index, total, token, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local center = options.Center or arenaGroundPosition()
	local count = math.max(1, tonumber(total) or 20)
	local itemIndex = tonumber(index) or 1
	local angle = (itemIndex / count) * math.pi * 2
	local radius = 8 + (itemIndex % 5) * 4
	local finalPosition = options.FinalPosition or (center + Vector3.new(math.cos(angle) * radius, 2.4, math.sin(angle) * radius))
	local cloudPosition = options.CloudPosition or (center + Vector3.new(0, 30, 0))
	local startPosition = options.StartPosition or (cloudPosition + Vector3.new(math.cos(angle) * radius * 0.45, (itemIndex % 4) * 1.4, math.sin(angle) * radius * 0.45))
	local model = context.Services.AssetService.CloneModel("VoidCrumbPickup", { CanTouch = true })
	model.Name = "SnackRainPickup_" .. tostring(itemIndex)
	model:SetAttribute("EventPickup", true)
	model:SetAttribute("PickupKind", "SnackRainCrumb")
	model:SetAttribute("EventToken", token)
	model:SetAttribute("SpectaclePickup", true)
	model:SetAttribute("SnackRainFallingPickup", true)
	model:SetAttribute("Landed", false)
	model.Parent = parent
	scaleToMax(model, options.TargetMaxDimension or 2.8)
	local primary = styleModel(model, Color3.fromRGB(255, 184, 88), 0.02)
	if primary then
		primary.CanTouch = true
	end
	addHighlight(model, Color3.fromRGB(255, 202, 102), model)
	pivotModel(model, CFrame.new(startPosition))
	addTrail(primary, Color3.fromRGB(255, 186, 80), 0.95, 0.65)
	attachBillboard(model, "COLLECT", Vector3.new(0, 2.5, 0), 118, 36, Color3.fromRGB(255, 230, 164), 75)
	task.spawn(function()
		local steps = 42
		local fallDuration = 1.35 + (itemIndex % 4) * 0.12
		for step = 1, steps do
			if not model.Parent or model:GetAttribute("Collected") then
				return
			end
			local alpha = step / steps
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local position = startPosition:Lerp(finalPosition, eased)
			position += Vector3.new(0, math.sin(alpha * math.pi) * 2.2, 0)
			pivotModel(model, CFrame.new(position) * CFrame.Angles(alpha * math.pi * 5, alpha * math.pi * 4, 0))
			task.wait(fallDuration / steps)
		end
		if model.Parent then
			model:SetAttribute("Landed", true)
			makeShockwave(finalPosition - Vector3.new(0, 1.9, 0), Color3.fromRGB(255, 190, 82), 6, 0.4, parent, "SnackRainLanding")
		end
	end)
	if options.Lifetime then
		Debris:AddItem(model, options.Lifetime)
	end
	return model
end

function WorldSpectacleService.SpawnGoldenHungerPreview(snackId, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local snack = context.Config.SnackConfig[snackId]
	if not snack then
		return nil
	end
	local model = context.Services.AssetService.CloneModel(snackAssetKey(snack))
	model.Name = "GoldenHungerWantedSnackHologram"
	model:SetAttribute("GoldenHungerWantedSnack", true)
	model:SetAttribute("GoldenHungerWantedSnackHologram", true)
	model:SetAttribute("SnackId", snackId)
	model.Parent = parent
	local targetMax = options.TargetMaxDimension or 6
	scaleToMax(model, targetMax)
	context.Services.AssetService.ApplyMutationVisual(model, "Golden", snack.Color)
	styleModel(model, Color3.fromRGB(255, 220, 90), 0.14)
	addHighlight(model, Color3.fromRGB(255, 220, 90), model)
	pivotModel(model, CFrame.new(options.Position or (arenaGroundPosition() + Vector3.new(0, 18, 0))))
	attachBillboard(model, "WANTED\n" .. tostring(snack.DisplayName or snackId), Vector3.new(0, targetMax * 0.5 + 2.3, 0), 270, 68, Color3.fromRGB(255, 232, 132), 145)
	animateModel(model, options.Lifetime or 35, 0.85, 0.55)
	if options.Lifetime then
		Debris:AddItem(model, options.Lifetime)
	end
	return model
end

function WorldSpectacleService.LinkGoldenHunger(idol, preview, parent)
	if not idol or not preview then
		return false
	end
	local idolPrimary = modelPrimary(idol)
	local previewPosition = targetPosition(preview)
	if not idolPrimary or not previewPosition then
		return false
	end
	local beam, anchor = addBeam(idolPrimary, previewPosition, Color3.fromRGB(255, 218, 88), 1.35, parent or idol.Parent)
	if beam then
		beam.Name = "GoldenWantedSnackBeam"
		beam:SetAttribute("GoldenHungerBeam", true)
	end
	if anchor then
		anchor:SetAttribute("GoldenHungerBeam", true)
	end
	return true
end

function WorldSpectacleService.SpawnMutationPlateAuras(options)
	options = type(options) == "table" and options or {}
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local world = getWorld()
	local plots = world:FindFirstChild("Plots")
	local made = 0
	if not plots then
		return 0
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local plates = plot:FindFirstChild("Plates")
		if plates then
			for _, plate in ipairs(plates:GetChildren()) do
				if plate:IsA("BasePart") and made < (options.MaxAuras or 64) then
					made += 1
					local diameter = math.max(7, math.max(plate.Size.X, plate.Size.Y, plate.Size.Z) + 3)
					local aura = Instance.new("Part")
					aura.Name = "MutationPlateAura"
					aura.Anchored = true
					aura.CanCollide = false
					aura.CanQuery = false
					aura.CanTouch = false
					aura.Shape = Enum.PartType.Cylinder
					aura.Material = Enum.Material.Glass
					aura.Color = Color3.fromRGB(92, 244, 182)
					aura.Transparency = 0.4
					aura.Size = Vector3.new(0.14, diameter, diameter)
					aura.CFrame = CFrame.new(plate.Position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
					aura:SetAttribute("MutationAura", true)
					aura.Parent = parent
					TweenService:Create(aura, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
						Transparency = 0.72,
						Size = Vector3.new(0.14, diameter * 1.12, diameter * 1.12),
					}):Play()
					if options.Lifetime then
						Debris:AddItem(aura, options.Lifetime)
					end
				end
			end
		end
	end
	return made
end

function WorldSpectacleService.SpawnVoidInfestationSwarm(options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local center = options.Center or (arenaGroundPosition() + eventHorizontalOffset.VoidInfestation)
	local lifetime = options.Lifetime or 30
	local voidmiteCount = options.VoidmiteCount or 6
	local mistCount = options.MistCount or 14
	for index = 1, mistCount do
		local angle = (index / mistCount) * math.pi * 2
		local radius = 4 + (index % 5) * 2.6
		local puff = Instance.new("Part")
		puff.Name = "VoidInfestationMist"
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.Shape = Enum.PartType.Ball
		puff.Material = Enum.Material.Glass
		puff.Color = Color3.fromRGB(142, 73, 224)
		puff.Transparency = 0.34
		puff.Size = Vector3.new(1.6, 1.6, 1.6) * (0.8 + (index % 3) * 0.25)
		puff.Position = center + Vector3.new(math.cos(angle) * radius, 2.2 + (index % 5) * 1.25, math.sin(angle) * radius)
		puff:SetAttribute("VoidInfestationMist", true)
		puff.Parent = parent
		TweenService:Create(puff, TweenInfo.new(1.4 + (index % 4) * 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.78,
			Position = puff.Position + Vector3.new(0, 3.5, 0),
			Size = puff.Size * 1.6,
		}):Play()
		Debris:AddItem(puff, lifetime)
	end
	for index = 1, voidmiteCount do
		local angle = (index / voidmiteCount) * math.pi * 2
		local radius = 8 + (index % 3) * 3
		local model = context.Services.AssetService.CloneModel("Voidmite")
		model.Name = "InfestationVoidmite_" .. tostring(index)
		model:SetAttribute("InfestationSwarmVoidmite", true)
		model.Parent = parent
		scaleToMax(model, 3.8)
		local primary = styleModel(model, Color3.fromRGB(164, 92, 232), 0.1)
		addHighlight(model, Color3.fromRGB(176, 102, 242), model)
		if primary then
			addTrail(primary, Color3.fromRGB(164, 92, 232), 0.55, 0.55)
		end
		local start = center + Vector3.new(math.cos(angle) * radius, 3.4 + (index % 2), math.sin(angle) * radius)
		pivotModel(model, CFrame.new(start))
		if index == 1 then
			attachBillboard(model, "VOIDMITE SWARM", Vector3.new(0, 3.2, 0), 210, 46, Color3.fromRGB(226, 196, 255), 110)
		end
		task.spawn(function()
			local started = now()
			while model.Parent and now() - started < lifetime do
				local elapsed = now() - started
				local orbitAngle = angle + elapsed * (0.45 + index * 0.035)
				local position = center + Vector3.new(math.cos(orbitAngle) * radius, 3.5 + math.sin(elapsed * 2.2 + index) * 1.2, math.sin(orbitAngle) * radius)
				pivotModel(model, CFrame.new(position) * CFrame.Angles(0, -orbitAngle, 0))
				task.wait(0.05)
			end
		end)
		Debris:AddItem(model, lifetime)
	end
	return voidmiteCount, mistCount
end

function WorldSpectacleService.StylePhantomModel(model, index)
	local color = Color3.fromRGB(190, 145, 255)
	local primary = styleModel(model, color, 0.16)
	if primary then
		primary.CanTouch = true
		addTrail(primary, color, 1.15, 0.75)
	end
	addHighlight(model, color, model)
	model:SetAttribute("PhantomSnack", true)
	attachBillboard(model, index == 1 and "RARE PHANTOM - CATCH!" or "PHANTOM - CATCH!", Vector3.new(0, 3.8, 0), 220, 50, Color3.fromRGB(232, 218, 255), 115)
	return primary
end

function WorldSpectacleService.SpawnPhantomPreview(count, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local center = options.Center or (arenaGroundPosition() + Vector3.new(0, 6, 0))
	local made = 0
	local previewCount = count or 3
	local lifetime = options.Lifetime or 20
	for index = 1, previewCount do
		local model = context.Services.AssetService.CloneModel("PhantomSnack")
		model.Name = "PhantomPreview_" .. tostring(index)
		model:SetAttribute("PhantomPreview", true)
		model.Parent = parent
		scaleToMax(model, options.TargetMaxDimension or 5.5)
		local angle = (index / math.max(1, previewCount)) * math.pi * 2
		local radius = 11 + index * 2
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		pivotModel(model, CFrame.new(position))
		WorldSpectacleService.StylePhantomModel(model, index)
		task.spawn(function()
			local started = now()
			while model.Parent and now() - started < lifetime do
				local elapsed = now() - started
				local movingAngle = angle + elapsed * (0.55 + index * 0.08)
				local movingPosition = center + Vector3.new(math.cos(movingAngle) * radius, math.sin(elapsed * 2.8 + index) * 1.5, math.sin(movingAngle) * radius)
				pivotModel(model, CFrame.new(movingPosition) * CFrame.Angles(0, -movingAngle, 0))
				task.wait(0.05)
			end
		end)
		Debris:AddItem(model, lifetime)
		made += 1
	end
	return made
end

local function countAttr(root, attributeName)
	local count = 0
	if not root then
		return 0
	end
	if root:GetAttribute(attributeName) then
		count += 1
	end
	for _, child in ipairs(root:GetDescendants()) do
		if child:GetAttribute(attributeName) then
			count += 1
		end
	end
	return count
end

local function countPhantomPrompts(root)
	local count = 0
	if not root then
		return count
	end
	for _, instance in ipairs(root:GetDescendants()) do
		if instance:IsA("ProximityPrompt") then
			local ancestor = instance.Parent
			while ancestor and ancestor ~= root do
				if ancestor:GetAttribute("PhantomSnack") then
					count += 1
					break
				end
				ancestor = ancestor.Parent
			end
		end
	end
	return count
end

local function feedDimensionEvidence(...)
	local evidence = {
		Regular = 0,
		Colossal = 0,
		Voidborn = 0,
	}
	for _, root in ipairs({ ... }) do
		if root then
			for _, instance in ipairs(root:GetDescendants()) do
				if instance:GetAttribute("FeedClone") then
					local tierId = tostring(instance:GetAttribute("SizeTier") or "Regular")
					local targetMax = tonumber(instance:GetAttribute("FeedTargetMaxDimension")) or 0
					if evidence[tierId] ~= nil then
						evidence[tierId] = math.max(evidence[tierId], targetMax)
					end
				end
			end
		end
	end
	return evidence
end

local function sizeDimensionEvidence(root)
	local evidence = {}
	if not root then
		return evidence
	end
	for _, instance in ipairs(root:GetDescendants()) do
		if instance:GetAttribute("SizePreview") then
			local tierId = tostring(instance:GetAttribute("SizeTier") or "")
			evidence[tierId] = tonumber(instance:GetAttribute("PreviewTargetMaxDimension")) or 0
		end
	end
	return evidence
end

function WorldSpectacleService.GetLiveEvidence()
	local _, spectacle, events, feeds, visualTests = folders()
	local dimensions = feedDimensionEvidence(feeds, visualTests)
	local sizeDimensions = sizeDimensionEvidence(visualTests)
	return {
		FeedClones = countAttr(feeds, "FeedClone") + countAttr(visualTests, "FeedClone"),
		FeedRegularMaxDimension = dimensions.Regular,
		FeedColossalMaxDimension = dimensions.Colossal,
		FeedVoidbornMaxDimension = dimensions.Voidborn,
		SizeRegularMaxDimension = sizeDimensions.Regular or 0,
		SizeHugeMaxDimension = sizeDimensions.Huge or 0,
		SizeColossalMaxDimension = sizeDimensions.Colossal or 0,
		SizeVoidbornMaxDimension = sizeDimensions.Voidborn or 0,
		SnackRainClouds = countAttr(events, "SnackRainCloud") + countAttr(visualTests, "SnackRainCloud"),
		SnackRainFallingPickups = countAttr(events, "SnackRainFallingPickup") + countAttr(visualTests, "SnackRainFallingPickup"),
		MutationCrystals = countAttr(events, "MutationCrystal") + countAttr(visualTests, "MutationCrystal"),
		MutationPlateAuras = countAttr(events, "MutationAura") + countAttr(visualTests, "MutationAura"),
		VoidmiteNests = countAttr(events, "VoidmiteNest") + countAttr(visualTests, "VoidmiteNest"),
		InfestationVoidmites = countAttr(events, "InfestationSwarmVoidmite") + countAttr(visualTests, "InfestationSwarmVoidmite"),
		InfestationMist = countAttr(events, "VoidInfestationMist") + countAttr(visualTests, "VoidInfestationMist"),
		GoldenHungerIdols = countAttr(events, "GoldenHungerIdol") + countAttr(visualTests, "GoldenHungerIdol"),
		GoldenHungerHolograms = countAttr(events, "GoldenHungerWantedSnackHologram") + countAttr(visualTests, "GoldenHungerWantedSnackHologram"),
		GoldenHungerBeams = countAttr(events, "GoldenHungerBeam") + countAttr(visualTests, "GoldenHungerBeam"),
		Phantoms = countAttr(events, "PhantomSnack") + countAttr(visualTests, "PhantomSnack"),
		PhantomCatchPrompts = countPhantomPrompts(events) + countPhantomPrompts(visualTests),
		VoidPulses = countAttr(spectacle, "VoidPulse") + countAttr(feeds, "VoidPulse") + countAttr(visualTests, "VoidPulse"),
		VoidChargeObjects = countAttr(spectacle, "VoidCharge"),
		EventObjectsChildren = #events:GetChildren(),
		SpectacleChildren = #spectacle:GetChildren(),
		FeedChildren = #feeds:GetChildren(),
		VisualTestChildren = #visualTests:GetChildren(),
	}
end

function WorldSpectacleService.SpawnSizeVisualCheck(player, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local visualTests = select(5, folders())
	if not options.SkipClear then
		WorldSpectacleService.ClearVisualTests()
	end
	local parent = options.ParentFolder or visualTests
	local old = parent:FindFirstChild("SizeVisualCheck")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "SizeVisualCheck"
	folder:SetAttribute("VisualTest", true)
	folder.Parent = parent
	local root = rootPart(player)
	local forward = root and horizontalUnit(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local right = forward:Cross(Vector3.new(0, 1, 0))
	local groundCenter
	if root then
		groundCenter = Vector3.new(root.Position.X, root.Position.Y - 3.1, root.Position.Z) + forward * 38
	else
		groundCenter = arenaGroundPosition() + Vector3.new(0, 0, 34)
	end
	local tiers = { "Regular", "Huge", "Colossal", "Voidborn" }
	local lateralOffsets = { -27, -19, -6, 14 }
	local made = 0
	for index, tierId in ipairs(tiers) do
		local targetMax = sizePreviewMaxDimensionByTier[tierId]
		local snack = context.Config.SnackConfig.CookieRock
		local model = context.Services.AssetService.CloneModel(snackAssetKey(snack))
		model.Name = "SizePreview_" .. tierId
		model:SetAttribute("SizePreview", true)
		model:SetAttribute("SizeTier", tierId)
		model:SetAttribute("PreviewTargetMaxDimension", targetMax)
		model.Parent = folder
		scaleToMax(model, targetMax)
		styleModel(model, snack.Color or Color3.fromRGB(210, 188, 128), 0.02)
		addHighlight(model, Color3.fromRGB(255, 214, 146), model)
		local groundPosition = groundCenter + right * lateralOffsets[index]
		local finalSize = placeModelBottomAt(model, groundPosition, math.rad(12 * index))
		attachBillboard(model, string.upper(tierId) .. " COOKIE ROCK\n" .. string.format("%.1f STUDS", targetMax), Vector3.new(0, finalSize.Y * 0.55 + 2.1, 0), 230, 60, Color3.fromRGB(255, 236, 180), 95)
		made += 1
	end
	Debris:AddItem(folder, options.Lifetime or 55)
	print("[FEED THE VOID][SizeVisualCheck] previews=" .. tostring(made) .. " regular=3.2 huge=7.0 colossal=13.8 voidborn=17.6 folder=" .. folder:GetFullName())
	return made
end

function WorldSpectacleService.RunSpectacleDiagnostics(player, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local visualTests = select(5, folders())
	if not options.PreserveExisting then
		WorldSpectacleService.ClearVisualTests()
	end
	local old = visualTests:FindFirstChild("SpectacleDiagnostics")
	if old then
		old:Destroy()
	end
	local diagnostic = Instance.new("Folder")
	diagnostic.Name = "SpectacleDiagnostics"
	diagnostic:SetAttribute("VisualTest", true)
	diagnostic.Parent = visualTests
	local root = rootPart(player)
	local baseStart = root and (root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 3, 0)) or fixedFeedStart(select(2, centralVoid()))
	for index, tierId in ipairs({ "Regular", "Colossal", "Voidborn" }) do
		WorldSpectacleService.PlayFeedSequence(player, {
			SnackId = "CookieRock",
			MutationId = tierId == "Voidborn" and "VoidTouched" or "Normal",
			DisplayName = tierId .. " Cookie Rock",
			SizeTier = tierId,
		}, baseStart + Vector3.new((index - 2) * 5, index * 1.3, 0), nil, {
			ParentFolder = diagnostic,
			DebugVisual = true,
			Lifetime = 9,
			Percent = 75,
			RewardText = "+ TEST VOID REWARD",
		})
	end
	WorldSpectacleService.SpawnSizeVisualCheck(player, {
		ParentFolder = diagnostic,
		SkipClear = true,
		Lifetime = 50,
	})
	local origin = WorldSpectacleService.GetEventOrigin(player, true)
	local cloudOrigin = origin + Vector3.new(-38, 0, -12)
	WorldSpectacleService.SpawnEventProp("SnackRain", context.Config.EventConfig.SnackRain, {
		ParentFolder = diagnostic,
		Origin = cloudOrigin,
		Lifetime = 50,
		Duration = 45,
	})
	for index = 1, 10 do
		WorldSpectacleService.SpawnSnackRainPickup(index, 10, -1700, {
			ParentFolder = diagnostic,
			Center = cloudOrigin,
			Lifetime = 50,
		})
	end
	local mutationOrigin = origin + Vector3.new(34, 0, -10)
	WorldSpectacleService.SpawnEventProp("MutationSurge", context.Config.EventConfig.MutationSurge, {
		ParentFolder = diagnostic,
		Origin = mutationOrigin,
		Lifetime = 50,
		Duration = 45,
	})
	WorldSpectacleService.SpawnMutationPlateAuras({
		ParentFolder = diagnostic,
		MaxAuras = 16,
		Lifetime = 50,
	})
	local nestOrigin = origin + Vector3.new(30, 0, 24)
	WorldSpectacleService.SpawnEventProp("VoidInfestation", context.Config.EventConfig.VoidInfestation, {
		ParentFolder = diagnostic,
		Origin = nestOrigin,
		Lifetime = 50,
		Duration = 45,
	})
	WorldSpectacleService.SpawnVoidInfestationSwarm({
		ParentFolder = diagnostic,
		Center = nestOrigin + eventHorizontalOffset.VoidInfestation,
		Lifetime = 50,
		VoidmiteCount = 6,
		MistCount = 14,
	})
	local goldenOrigin = origin + Vector3.new(-28, 0, 25)
	local idol = WorldSpectacleService.SpawnEventProp("GoldenHunger", context.Config.EventConfig.GoldenHunger, {
		ParentFolder = diagnostic,
		Origin = goldenOrigin,
		Lifetime = 50,
		Duration = 45,
	})
	local idolPosition = targetPosition(idol) or goldenOrigin
	local wanted = WorldSpectacleService.SpawnGoldenHungerPreview("CookieRock", {
		ParentFolder = diagnostic,
		Position = idolPosition + Vector3.new(0, 12, 0),
		Lifetime = 50,
	})
	WorldSpectacleService.LinkGoldenHunger(idol, wanted, diagnostic)
	if context.Services.PhantomSnackService and context.Services.PhantomSnackService.SpawnForEvent then
		context.Services.PhantomSnackService.SpawnForEvent(50, {
			ParentFolder = diagnostic,
			Center = origin + Vector3.new(0, 7, 38),
			Count = 3,
		})
	else
		WorldSpectacleService.SpawnPhantomPreview(3, {
			ParentFolder = diagnostic,
			Center = origin + Vector3.new(0, 7, 38),
			Lifetime = 50,
			TargetMaxDimension = 5.5,
		})
	end
	task.wait(0.2)
	local evidence = WorldSpectacleService.GetLiveEvidence()
	evidence.DiagnosticChildren = #diagnostic:GetChildren()
	evidence.SizeVisualRatio = evidence.SizeRegularMaxDimension > 0 and (evidence.SizeVoidbornMaxDimension / evidence.SizeRegularMaxDimension) or 0
	evidence.EventBannerObjectiveText = lastBannerEvidence and lastBannerEvidence.ObjectiveText or ""
	lastDiagnostics = evidence
	print(string.format(
		"[FEED THE VOID][SpectacleEvidence] feedRegular=%.1f feedColossal=%.1f feedVoidborn=%.1f sizeRatio=%.2f cloud=%d pickups=%d crystal=%d nest=%d swarm=%d idol=%d hologram=%d phantoms=%d bannerObjective=%s diagnosticChildren=%d",
		evidence.FeedRegularMaxDimension or 0,
		evidence.FeedColossalMaxDimension or 0,
		evidence.FeedVoidbornMaxDimension or 0,
		evidence.SizeVisualRatio or 0,
		evidence.SnackRainClouds or 0,
		evidence.SnackRainFallingPickups or 0,
		evidence.MutationCrystals or 0,
		evidence.VoidmiteNests or 0,
		evidence.InfestationVoidmites or 0,
		evidence.GoldenHungerIdols or 0,
		evidence.GoldenHungerHolograms or 0,
		evidence.Phantoms or 0,
		tostring(evidence.EventBannerObjectiveText or ""),
		evidence.DiagnosticChildren or 0
	))
	Debris:AddItem(diagnostic, 55)
	return evidence
end

function WorldSpectacleService.GetLastDiagnostics()
	return lastDiagnostics
end

return WorldSpectacleService
