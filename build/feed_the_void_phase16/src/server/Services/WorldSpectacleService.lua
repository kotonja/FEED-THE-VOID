local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local WorldSpectacleService = {}

local lastDiagnostics = nil

local eventMaxDimension = {
	SnackRain = 24,
	MutationSurge = 16,
	VoidInfestation = 10,
	GoldenHunger = 10,
	PhantomSnackChase = 5.5,
}

local eventPositions = {
	SnackRain = Vector3.new(0, 26, 0),
	MutationSurge = Vector3.new(0, 9, 0),
	VoidInfestation = Vector3.new(0, 5.5, 0),
	GoldenHunger = Vector3.new(0, 7, 0),
	PhantomSnackChase = Vector3.new(0, 11, 0),
}

local eventColors = {
	SnackRain = Color3.fromRGB(255, 178, 76),
	MutationSurge = Color3.fromRGB(88, 242, 184),
	VoidInfestation = Color3.fromRGB(156, 84, 230),
	GoldenHunger = Color3.fromRGB(255, 218, 88),
	PhantomSnackChase = Color3.fromRGB(180, 132, 255),
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
	return world, spectacle, events, feeds
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
		return nil, Vector3.new(0, 8, 0)
	end
	local target = central:FindFirstChild("VoidCore") or central:FindFirstChild("FeedStation") or central
	return target, targetPosition(target) or Vector3.new(0, 8, 0)
end

local function rootPosition(player)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 2.4, 0)
	end
	local _, voidPos = centralVoid()
	return voidPos + Vector3.new(0, 4, 20)
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
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanQuery = true
			child.CanTouch = false
			child.Massless = true
			if not textureProtected(child) then
				child.Color = color or child.Color
				child.Material = Enum.Material.Glass
				child.Transparency = math.max(child.Transparency, transparency or 0.1)
			end
		end
	end
	local primary = modelPrimary(model)
	if primary and not primary:FindFirstChild("WorldSpectacleLight") then
		local light = Instance.new("PointLight")
		light.Name = "WorldSpectacleLight"
		light.Color = color or Color3.fromRGB(180, 110, 255)
		light.Brightness = 1.35
		light.Range = 38
		light.Parent = primary
	end
	return primary
end

local function attachBillboard(modelOrPart, text, studsOffset, width, height, color)
	local assetService = WorldSpectacleService.Context and WorldSpectacleService.Context.Services.AssetService
	if assetService and typeof(modelOrPart) == "Instance" then
		return assetService.AttachBillboard(modelOrPart, {
			Name = "WorldSpectacleBillboard",
			Text = text,
			Size = UDim2.new(0, width or 270, 0, height or 74),
			StudsOffset = studsOffset or Vector3.new(0, 5, 0),
			MaxDistance = 150,
			BackgroundTransparency = 0.16,
			BackgroundColor3 = Color3.fromRGB(22, 18, 30),
			TextColor3 = color or Color3.fromRGB(255, 246, 216),
		})
	end
	return nil
end

local function addTrail(part, color, width)
	if not part then
		return nil
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "SpectacleTrailA"
	a0.Position = Vector3.new(0, math.max(0.5, part.Size.Y * 0.3), 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "SpectacleTrailB"
	a1.Position = Vector3.new(0, -math.max(0.5, part.Size.Y * 0.3), 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "SpectacleTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color or Color3.fromRGB(184, 118, 255), Color3.fromRGB(255, 220, 128))
	trail.LightEmission = 0.35
	trail.Lifetime = 0.5
	trail.MinLength = 0.25
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
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
	beam.LightEmission = 0.25
	beam.Segments = 18
	beam.Width0 = width or 0.45
	beam.Width1 = math.max(0.15, (width or 0.45) * 0.35)
	beam.Transparency = NumberSequence.new(0.18)
	beam.Parent = fromPart
	return beam, anchor
end

local function makeShockwave(position, color, radius, lifetime, parent, name)
	local ring = Instance.new("Part")
	ring.Name = name or "SpectacleShockwave"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Glass
	ring.Color = color or Color3.fromRGB(171, 104, 255)
	ring.Transparency = 0.36
	ring.Size = Vector3.new(2, 0.16, 2)
	ring.CFrame = CFrame.new(position)
	ring:SetAttribute("VoidPulse", true)
	ring.Parent = parent or select(2, folders())
	local tween = TweenService:Create(ring, TweenInfo.new(lifetime or 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius or 24, 0.16, radius or 24),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, (lifetime or 0.85) + 0.15)
	return ring
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

local function feedTargetMax(item)
	local context = WorldSpectacleService.Context
	local gameConfig = context.Config.GameConfig
	local sizeConfig = context.Config.SizeConfig
	local cap = tonumber(gameConfig.MaxFeedVisualScale) or 7
	if sizeConfig and sizeConfig.GetFeedVisualScale then
		return sizeConfig.GetFeedVisualScale(item, cap)
	end
	return math.clamp(tonumber(item and item.SizeMultiplier) or 1, 1, cap)
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

function WorldSpectacleService.ClearEventObjects()
	local _, _, events = folders()
	for _, child in ipairs(events:GetChildren()) do
		child:Destroy()
	end
end

function WorldSpectacleService.PlayFeedSequence(player, item, startPosition, target, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, _, feedFolder = folders()
	local snack = context.Config.SnackConfig[item and item.SnackId or "CookieRock"] or context.Config.SnackConfig.CookieRock
	local mutationId = item and item.MutationId or "Normal"
	local targetObject, voidPosition = centralVoid()
	local targetPos = targetPosition(target) or targetPosition(targetObject) or voidPosition
	targetPos += Vector3.new(0, 2.2, 0)
	local fromPos = startPosition or rootPosition(player)
	local assetKey = snackAssetKey(snack)
	local model = context.Services.AssetService.CloneModel(assetKey)
	model.Name = "FeedClone_" .. tostring(item and item.SizeTier or "Regular") .. "_" .. tostring(item and item.SnackId or "Snack")
	model:SetAttribute("FeedClone", true)
	model:SetAttribute("SnackId", item and item.SnackId or "CookieRock")
	model:SetAttribute("MutationId", mutationId)
	model:SetAttribute("SizeTier", item and item.SizeTier or "Regular")
	model:SetAttribute("FeedTargetMaxDimension", feedTargetMax(item))
	model:SetAttribute("SpawnedAt", now())
	model.Parent = options.ParentFolder or feedFolder
	scaleToMax(model, feedTargetMax(item))
	context.Services.AssetService.ApplyMutationVisual(model, mutationId, snack and snack.Color)
	local primary = styleModel(model, (snack and snack.Color) or Color3.fromRGB(210, 188, 128), 0.03)
	pivotModel(model, CFrame.new(fromPos))
	attachBillboard(model, "FEEDING\n" .. sizeLabel(item) .. " " .. tostring(snack and snack.DisplayName or "Snack"), Vector3.new(0, 4.3, 0), 220, 62, Color3.fromRGB(255, 230, 160))
	addTrail(primary, Color3.fromRGB(190, 114, 255), math.clamp(feedTargetMax(item) * 0.32, 0.7, 2.6))
	local beam, anchor = addBeam(primary, targetPos, Color3.fromRGB(175, 102, 255), math.clamp(feedTargetMax(item) * 0.12, 0.35, 1.2), model.Parent)
	Debris:AddItem(model, options.Lifetime or 5.5)
	if anchor then
		Debris:AddItem(anchor, options.Lifetime or 5.5)
	end
	task.spawn(function()
		local steps = 34
		local arcHeight = math.clamp(7 + feedTargetMax(item) * 0.8, 8, 16)
		for step = 1, steps do
			if not model.Parent then
				return
			end
			local alpha = step / steps
			local pos = fromPos:Lerp(targetPos, alpha)
			pos += Vector3.new(0, math.sin(alpha * math.pi) * arcHeight, 0)
			local spin = CFrame.Angles(alpha * math.pi * 3, alpha * math.pi * 5, 0)
			pivotModel(model, CFrame.new(pos) * spin)
			task.wait(0.028)
		end
		if model.Parent then
			if beam then
				beam.Enabled = false
			end
			makeShockwave(targetPos - Vector3.new(0, 1.8, 0), Color3.fromRGB(174, 103, 255), 20 + feedTargetMax(item) * 4, 0.9, feedFolder, "FeedImpactShockwave")
			WorldSpectacleService.PulseVoid(math.clamp((tonumber(options.Percent) or 50), 20, 100), "The Void devours it.", {
				Position = targetPos,
				Reason = "FeedImpact",
			})
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("BasePart") then
					TweenService:Create(child, TweenInfo.new(0.35), { Transparency = 1 }):Play()
				end
			end
			task.wait(0.4)
			if model.Parent then
				model:Destroy()
			end
		end
	end)
	return model
end

function WorldSpectacleService.PulseVoid(percent, text, options)
	options = type(options) == "table" and options or {}
	local _, spectacle = folders()
	local target, voidPos = centralVoid()
	local position = options.Position or voidPos
	local clamped = math.clamp(tonumber(percent) or 50, 0, 100)
	local color = clamped >= 100 and Color3.fromRGB(255, 216, 96) or Color3.fromRGB(172, 96, 255)
	local radius = 18 + (clamped * 0.32)
	local pulse = makeShockwave(position, color, radius, 0.95, spectacle, "VoidReaction_" .. tostring(math.floor(clamped)))
	pulse:SetAttribute("VoidReactionPercent", clamped)
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		local originalSize = target.Size
		local tweenUp = TweenService:Create(target, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = originalSize * 1.06 })
		local tweenDown = TweenService:Create(target, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = originalSize })
		tweenUp:Play()
		tweenUp.Completed:Once(function()
			if target.Parent then
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
	marker.Position = position + Vector3.new(0, 7 + clamped * 0.03, 0)
	marker:SetAttribute("VoidPulse", true)
	marker.Parent = spectacle
	attachBillboard(marker, tostring(text or ("VOID " .. tostring(math.floor(clamped)) .. "%")), Vector3.new(0, 0, 0), 270, 56, color)
	Debris:AddItem(marker, 2.2)
	return pulse
end

function WorldSpectacleService.BeginVoidCharge(duration, eventName)
	local _, spectacle = folders()
	local target, voidPos = centralVoid()
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
	anchor.Position = voidPos + Vector3.new(0, 9, 0)
	anchor.Parent = folder
	attachBillboard(anchor, "THE VOID IS WAKING\n" .. tostring(eventName or "Random Event") .. "\n" .. tostring(math.ceil(seconds)) .. "s", Vector3.new(0, 0, 0), 300, 84, Color3.fromRGB(255, 222, 126))
	for index = 1, 5 do
		local ring = makeShockwave(voidPos + Vector3.new(0, index * 0.18, 0), Color3.fromRGB(174, 99, 255), 16 + index * 8, seconds, folder, "VoidChargeRing_" .. tostring(index))
		ring.Transparency = 0.48
	end
	if target and target:IsA("BasePart") then
		addBeam(anchor, target.Position, Color3.fromRGB(255, 212, 112), 1.25, folder)
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
	local position = options.Position or eventPositions[eventName] or Vector3.new(0, 8, 0)
	local assetKey = options.AssetKey or eventConfig.AssetKey or "EventMutationCrystal"
	local model = context.Services.AssetService.CloneModel(assetKey, { ApplyReferenceTargetSize = true })
	model.Name = "EventSpectacle_" .. tostring(eventName or assetKey)
	model:SetAttribute("EventSpectacle", true)
	model:SetAttribute("EventName", tostring(eventName or assetKey))
	model:SetAttribute("TargetMaxDimension", targetMax)
	model.Parent = parent
	scaleToMax(model, targetMax)
	pivotModel(model, CFrame.new(position))
	styleModel(model, color, 0.08)
	local banner = eventConfig.BannerName or eventConfig.DisplayName or tostring(eventName or "VOID EVENT")
	local objective = eventConfig.ObjectiveText or eventConfig.WorldVisualText or "Join the Void event."
	local duration = options.Duration or eventConfig.DebugDuration or eventConfig.Duration or 45
	attachBillboard(model, banner .. "\n" .. objective .. "\n" .. tostring(duration) .. "s", Vector3.new(0, math.max(5, targetMax * 0.55), 0), 310, 90, Color3.fromRGB(255, 242, 210))
	makeShockwave(Vector3.new(position.X, math.max(1.6, position.Y - targetMax * 0.45), position.Z), color, math.max(16, targetMax * 1.7), 1.3, parent, "EventSpectacleRing_" .. tostring(eventName))
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
	local count = math.max(1, tonumber(total) or 20)
	local angle = ((tonumber(index) or 1) / count) * math.pi * 2
	local radius = 15 + ((tonumber(index) or 1) % 6) * 5
	local finalPosition = options.FinalPosition or Vector3.new(math.cos(angle) * radius, 2.8, math.sin(angle) * radius)
	local startPosition = options.StartPosition or (finalPosition + Vector3.new(0, 24 + ((tonumber(index) or 1) % 5) * 1.6, 0))
	local model = context.Services.AssetService.CloneModel("VoidCrumbPickup", { CanTouch = true })
	model.Name = "SnackRainPickup_" .. tostring(index or 1)
	model:SetAttribute("EventPickup", true)
	model:SetAttribute("PickupKind", "SnackRainCrumb")
	model:SetAttribute("EventToken", token)
	model:SetAttribute("SpectaclePickup", true)
	model.Parent = parent
	scaleToMax(model, 2.4)
	local primary = styleModel(model, Color3.fromRGB(255, 184, 88), 0.04)
	if primary then
		primary.CanTouch = true
	end
	pivotModel(model, CFrame.new(startPosition))
	addTrail(primary, Color3.fromRGB(255, 186, 80), 0.7)
	attachBillboard(model, "Collect", Vector3.new(0, 2.3, 0), 120, 34, Color3.fromRGB(255, 230, 164))
	task.spawn(function()
		local steps = 28
		for step = 1, steps do
			if not model.Parent or model:GetAttribute("Collected") then
				return
			end
			local alpha = step / steps
			local pos = startPosition:Lerp(finalPosition, alpha)
			pos += Vector3.new(0, math.sin(alpha * math.pi) * 2.8, 0)
			pivotModel(model, CFrame.new(pos) * CFrame.Angles(alpha * math.pi * 4, alpha * math.pi * 3, 0))
			task.wait(0.035)
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
	model.Name = "GoldenHungerWantedSnack"
	model:SetAttribute("GoldenHungerWantedSnack", true)
	model:SetAttribute("SnackId", snackId)
	model.Parent = parent
	scaleToMax(model, options.TargetMaxDimension or 5.2)
	context.Services.AssetService.ApplyMutationVisual(model, "Golden", snack.Color)
	styleModel(model, Color3.fromRGB(255, 220, 90), 0.18)
	pivotModel(model, CFrame.new(options.Position or Vector3.new(0, 16, 0)))
	attachBillboard(model, "WANTED\n" .. tostring(snack.DisplayName or snackId), Vector3.new(0, 3.8, 0), 250, 62, Color3.fromRGB(255, 232, 132))
	if options.Lifetime then
		Debris:AddItem(model, options.Lifetime)
	end
	return model
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
					local aura = makeShockwave(plate.Position + Vector3.new(0, plate.Size.Y * 0.5 + 0.14, 0), Color3.fromRGB(92, 244, 182), math.max(6, plate.Size.X + 2), 2.1, parent, "MutationPlateAura")
					aura:SetAttribute("MutationAura", true)
				end
			end
		end
	end
	return made
end

function WorldSpectacleService.SpawnVoidInfestationSwarm(options)
	options = type(options) == "table" and options or {}
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local made = 0
	local count = options.Count or 18
	for index = 1, count do
		local angle = (index / count) * math.pi * 2
		local radius = 11 + (index % 4) * 3
		local mote = Instance.new("Part")
		mote.Name = "VoidInfestationMote"
		mote.Anchored = true
		mote.CanCollide = false
		mote.CanQuery = false
		mote.CanTouch = false
		mote.Shape = Enum.PartType.Ball
		mote.Material = Enum.Material.Glass
		mote.Color = Color3.fromRGB(142, 73, 224)
		mote.Transparency = 0.16
		mote.Size = Vector3.new(1.2, 1.2, 1.2)
		mote.Position = Vector3.new(math.cos(angle) * radius, 5 + (index % 5), math.sin(angle) * radius)
		mote:SetAttribute("VoidInfestationMote", true)
		mote.Parent = parent
		addTrail(mote, Color3.fromRGB(148, 82, 232), 0.35)
		made += 1
		Debris:AddItem(mote, options.Lifetime or 28)
	end
	return made
end

function WorldSpectacleService.StylePhantomModel(model, index)
	local color = Color3.fromRGB(190, 145, 255)
	local primary = styleModel(model, color, 0.22)
	if primary then
		primary.CanTouch = true
		addTrail(primary, color, 0.85)
	end
	model:SetAttribute("PhantomSnack", true)
	attachBillboard(model, index == 1 and "Rare Phantom Snack" or "Phantom Snack", Vector3.new(0, 3.4, 0), 190, 48, Color3.fromRGB(232, 218, 255))
	return primary
end

function WorldSpectacleService.SpawnPhantomPreview(count, options)
	options = type(options) == "table" and options or {}
	local context = WorldSpectacleService.Context
	local _, _, events = folders()
	local parent = options.ParentFolder or events
	local made = 0
	local previewCount = count or 3
	for index = 1, previewCount do
		local model = context.Services.AssetService.CloneModel("PhantomSnack")
		model.Name = "PhantomPreview_" .. tostring(index)
		model:SetAttribute("PhantomPreview", true)
		model.Parent = parent
		scaleToMax(model, options.TargetMaxDimension or 5.2)
		local angle = (index / math.max(1, previewCount)) * math.pi * 2
		local pos = (options.Center or Vector3.new(0, 7, 0)) + Vector3.new(math.cos(angle) * 16, 0, math.sin(angle) * 16)
		pivotModel(model, CFrame.new(pos))
		WorldSpectacleService.StylePhantomModel(model, index)
		Debris:AddItem(model, options.Lifetime or 14)
		made += 1
	end
	return made
end

local function countAttr(root, attrName)
	local count = 0
	if not root then
		return 0
	end
	local function visit(instance)
		if instance:GetAttribute(attrName) then
			count += 1
		end
		for _, child in ipairs(instance:GetChildren()) do
			visit(child)
		end
	end
	visit(root)
	return count
end

function WorldSpectacleService.GetLiveEvidence()
	local _, spectacle, events, feeds = folders()
	return {
		FeedClones = countAttr(feeds, "FeedClone"),
		EventProps = countAttr(events, "EventSpectacle") + countAttr(spectacle, "EventSpectacle"),
		Pickups = countAttr(events, "SpectaclePickup") + countAttr(spectacle, "SpectaclePickup"),
		Phantoms = countAttr(events, "PhantomSnack") + countAttr(spectacle, "PhantomSnack"),
		VoidPulses = countAttr(spectacle, "VoidPulse") + countAttr(feeds, "VoidPulse"),
		VoidChargeObjects = countAttr(spectacle, "VoidCharge"),
		EventObjectsChildren = #events:GetChildren(),
		SpectacleChildren = #spectacle:GetChildren(),
		FeedChildren = #feeds:GetChildren(),
	}
end

function WorldSpectacleService.SpawnSizeVisualCheck(player)
	local context = WorldSpectacleService.Context
	local _, spectacle = folders()
	local old = spectacle:FindFirstChild("SizeVisualCheck")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "SizeVisualCheck"
	folder.Parent = spectacle
	local origin = rootPosition(player) + Vector3.new(-18, 1.5, 0)
	local made = 0
	for index, tierId in ipairs(context.Config.SizeConfig.Order or {}) do
		local item = {
			SnackId = "CookieRock",
			MutationId = "Normal",
			SizeTier = tierId,
			SizeMultiplier = context.Config.SizeConfig.GetScaleMultiplier(tierId),
		}
		local snack = context.Config.SnackConfig.CookieRock
		local model = context.Services.AssetService.CloneModel(snackAssetKey(snack))
		model.Name = "SizePreview_" .. tierId
		model:SetAttribute("SizePreview", true)
		model.Parent = folder
		scaleToMax(model, context.Config.SizeConfig.GetPlateVisualScale(item, context.Config.GameConfig.MaxPlateSnackVisualScale))
		styleModel(model, snack.Color or Color3.fromRGB(210, 188, 128), 0.06)
		pivotModel(model, CFrame.new(origin + Vector3.new((index - 1) * 7, 0, 0)))
		attachBillboard(model, tierId .. "\nplate " .. tostring(context.Config.SizeConfig.GetPlateVisualScale(item)) .. " | feed " .. tostring(context.Config.SizeConfig.GetFeedVisualScale(item)), Vector3.new(0, 4.2, 0), 190, 58, Color3.fromRGB(255, 236, 180))
		made += 1
	end
	Debris:AddItem(folder, 18)
	print("[FEED THE VOID][SizeVisualCheck] previews=" .. tostring(made) .. " folder=" .. folder:GetFullName())
	return made
end

function WorldSpectacleService.RunSpectacleDiagnostics(player)
	local context = WorldSpectacleService.Context
	local _, spectacle = folders()
	local old = spectacle:FindFirstChild("SpectacleDiagnostics")
	if old then
		old:Destroy()
	end
	local diagnostic = Instance.new("Folder")
	diagnostic.Name = "SpectacleDiagnostics"
	diagnostic.Parent = spectacle
	for index, eventName in ipairs(context.Config.EventConfig.Order or {}) do
		local config = context.Config.EventConfig[eventName]
		local x = (index - 3) * 11
		WorldSpectacleService.SpawnEventProp(eventName, config, {
			ParentFolder = diagnostic,
			Position = Vector3.new(x, eventPositions[eventName] and eventPositions[eventName].Y or 8, -36),
			Lifetime = 14,
			Duration = config.DebugDuration or config.Duration or 30,
		})
	end
	for index = 1, 5 do
		WorldSpectacleService.SpawnSnackRainPickup(index, 5, -999, {
			ParentFolder = diagnostic,
			FinalPosition = Vector3.new(-20 + index * 4, 3, -24),
			Lifetime = 14,
		})
	end
	WorldSpectacleService.SpawnGoldenHungerPreview("CookieRock", {
		ParentFolder = diagnostic,
		Position = Vector3.new(0, 12, -24),
		Lifetime = 14,
	})
	WorldSpectacleService.SpawnPhantomPreview(3, {
		ParentFolder = diagnostic,
		Center = Vector3.new(0, 8, -18),
		Lifetime = 14,
	})
	WorldSpectacleService.PulseVoid(75, "Diagnostic Void Pulse")
	WorldSpectacleService.PlayFeedSequence(player, {
		SnackId = "CookieRock",
		MutationId = "VoidTouched",
		DisplayName = "Void Touched Cookie Rock",
		SizeTier = "Voidborn",
		SizeMultiplier = 3.5,
	}, rootPosition(player), nil, {
		ParentFolder = select(4, folders()),
		Lifetime = 8,
		Percent = 75,
	})
	Debris:AddItem(diagnostic, 16)
	task.wait(0.15)
	local evidence = WorldSpectacleService.GetLiveEvidence()
	evidence.DiagnosticChildren = #diagnostic:GetChildren()
	lastDiagnostics = evidence
	print(string.format(
		"[FEED THE VOID][SpectacleEvidence] feedClones=%d eventProps=%d pickups=%d phantoms=%d voidPulses=%d charge=%d diagnosticChildren=%d",
		evidence.FeedClones,
		evidence.EventProps,
		evidence.Pickups,
		evidence.Phantoms,
		evidence.VoidPulses,
		evidence.VoidChargeObjects,
		evidence.DiagnosticChildren
	))
	return evidence
end

function WorldSpectacleService.GetLastDiagnostics()
	return lastDiagnostics
end

return WorldSpectacleService
