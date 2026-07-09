local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetReferences = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReferences"))

local AssetService = {}

local warnedMissing = {}
local lastAssetReport = nil

local fallback = {
	Void = { Color = Color3.fromRGB(84, 45, 132), Size = Vector3.new(8, 8, 8), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
	Creature = { Color = Color3.fromRGB(72, 24, 124), Size = Vector3.new(1.4, 1.1, 1.4), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SeedCapsule = { Color = Color3.fromRGB(120, 210, 190), Size = Vector3.new(1.2, 1.8, 1.2), Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic },
	GrowthSprout = { Color = Color3.fromRGB(126, 220, 136), Size = Vector3.new(1.2, 1.4, 1.2), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	GrowthBud = { Color = Color3.fromRGB(174, 148, 255), Size = Vector3.new(1.8, 2, 1.8), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SnackRound = { Color = Color3.fromRGB(185, 164, 132), Size = Vector3.new(2.6, 2.6, 2.6), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SnackCube = { Color = Color3.fromRGB(92, 205, 210), Size = Vector3.new(2.4, 2.4, 2.4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SnackWrap = { Color = Color3.fromRGB(245, 148, 196), Size = Vector3.new(3, 1.4, 1.6), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	PhantomSnack = { Color = Color3.fromRGB(172, 116, 255), Size = Vector3.new(2.2, 2.2, 2.2), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
	GrowPlate = { Color = Color3.fromRGB(80, 92, 110), Size = Vector3.new(5, 0.4, 5), Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal },
	DisplayPedestal = { Color = Color3.fromRGB(70, 64, 90), Size = Vector3.new(4, 1.2, 4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	Station = { Color = Color3.fromRGB(70, 86, 112), Size = Vector3.new(5, 4, 3), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	Portal = { Color = Color3.fromRGB(86, 55, 124), Size = Vector3.new(4, 6, 1), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	EventProp = { Color = Color3.fromRGB(126, 80, 180), Size = Vector3.new(5, 4, 5), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
	Chest = { Color = Color3.fromRGB(122, 78, 48), Size = Vector3.new(5.2, 2.4, 4.2), Shape = Enum.PartType.Block, Material = Enum.Material.WoodPlanks },
	Clock = { Color = Color3.fromRGB(72, 116, 170), Size = Vector3.new(3.2, 4, 0.6), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	Book = { Color = Color3.fromRGB(82, 64, 118), Size = Vector3.new(3.6, 3, 0.7), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	Pickup = { Color = Color3.fromRGB(255, 180, 80), Size = Vector3.new(1.25, 1.25, 1.25), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
}

local fallbackByKey = {
	TheVoid = "Void",
	Voidmite = "Creature",
	SeedCapsuleGeneric = "SeedCapsule",
	SnackSproutGeneric = "GrowthSprout",
	SnackBudGeneric = "GrowthBud",
	SnackRoundBase = "SnackRound",
	SnackCubeBase = "SnackCube",
	SnackWrapBase = "SnackWrap",
	SnackCrystalDonut = "SnackRound",
	SnackMeteorMuffin = "SnackRound",
	SnackGoblinSandwich = "SnackWrap",
	SnackStarPancake = "SnackRound",
	SnackLavaNoodleWrap = "SnackWrap",
	SnackVoidWaffle = "SnackCube",
	SnackBlackHoleBurrito = "SnackWrap",
	SnackGoldenFridgeSnack = "SnackCube",
	SnackLivingSandwich = "SnackWrap",
	PhantomSnack = "PhantomSnack",
	GrowPlate = "GrowPlate",
	DisplayPedestal = "DisplayPedestal",
	SeedShopMachine = "Station",
	SellStation = "Station",
	UpgradeStation = "Station",
	RebirthPortal = "Portal",
	EventSnackRainCloud = "EventProp",
	EventMutationCrystal = "EventProp",
	EventVoidmiteNest = "EventProp",
	EventGoldenHungerIdol = "EventProp",
	VoidCrumbPickup = "Pickup",
	VoidShardPickup = "Pickup",
	DailyRewardChest = "Chest",
	PlaytimeRewardClock = "Clock",
	CollectionBook = "Book",
}

local function normalizePath(pathValue)
	if type(pathValue) == "string" then
		local parts = {}
		for part in string.gmatch(pathValue, "[^%.]+") do
			table.insert(parts, part)
		end
		return parts
	end
	return pathValue
end

local function findByPath(pathParts)
	pathParts = normalizePath(pathParts)
	if type(pathParts) ~= "table" then
		return nil
	end
	local current = nil
	for index, partName in ipairs(pathParts) do
		if index == 1 then
			local ok, service = pcall(function()
				return game:GetService(partName)
			end)
			current = ok and service or game:FindFirstChild(partName)
		else
			current = current and current:FindFirstChild(partName)
		end
		if not current then
			return nil
		end
	end
	return current
end

local function largestBasePart(model)
	local best = nil
	local bestVolume = -1
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local volume = child.Size.X * child.Size.Y * child.Size.Z
			if volume > bestVolume then
				best = child
				bestVolume = volume
			end
		end
	end
	return best
end

local function wrapBasePart(part, modelName)
	local model = Instance.new("Model")
	model.Name = modelName or part.Name
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function normalizeClone(clone, modelName)
	if clone:IsA("Model") then
		return clone
	end
	if clone:IsA("BasePart") then
		return wrapBasePart(clone, modelName)
	end
	if clone:IsA("Folder") then
		local model = Instance.new("Model")
		model.Name = modelName or clone.Name
		for _, child in ipairs(clone:GetChildren()) do
			child.Parent = model
		end
		clone:Destroy()
		return model
	end
	local model = Instance.new("Model")
	model.Name = modelName or clone.Name
	clone.Parent = model
	return model
end

local function safeName(text)
	return tostring(text or "Prompt"):gsub("%W+", "")
end

local function hasTexturePayload(part)
	if part:IsA("MeshPart") and part.TextureID and part.TextureID ~= "" then
		return true
	end
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Texture") or descendant:IsA("Decal") then
			return true
		end
	end
	return false
end

local function targetRatioFor(size, targetSize)
	if typeof(size) ~= "Vector3" or typeof(targetSize) ~= "Vector3" then
		return nil
	end
	local ratios = {}
	if size.X > 0.01 and targetSize.X > 0 then
		table.insert(ratios, targetSize.X / size.X)
	end
	if size.Y > 0.01 and targetSize.Y > 0 then
		table.insert(ratios, targetSize.Y / size.Y)
	end
	if size.Z > 0.01 and targetSize.Z > 0 then
		table.insert(ratios, targetSize.Z / size.Z)
	end
	if #ratios == 0 then
		return nil
	end
	local ratio = ratios[1]
	for _, value in ipairs(ratios) do
		ratio = math.min(ratio, value)
	end
	return ratio
end

local function addFallbackAccent(model, part, fallbackType)
	if fallbackType ~= "Station" and fallbackType ~= "Chest" and fallbackType ~= "Portal" and fallbackType ~= "Clock" and fallbackType ~= "Book" then
		return
	end
	local accent = Instance.new("Part")
	accent.Name = "FallbackAccent"
	accent.Anchored = true
	accent.CanCollide = false
	accent.CanQuery = false
	accent.CanTouch = false
	accent.Material = Enum.Material.Metal
	accent.Color = Color3.fromRGB(202, 174, 92)
	accent.Size = Vector3.new(math.max(0.8, part.Size.X * 0.38), 0.18, math.max(0.8, part.Size.Z * 0.42))
	accent.CFrame = part.CFrame + Vector3.new(0, part.Size.Y * 0.52, 0)
	accent.Parent = model
end

function AssetService.Init(context)
	AssetService.Context = context
end

function AssetService.Start() end

function AssetService.GetReference(assetKey)
	local ref = AssetReferences[assetKey]
	if type(ref) ~= "table" then
		return nil
	end
	if ref.Path then
		return ref
	end
	if ref[1] then
		return { Path = ref, FallbackType = fallbackByKey[assetKey] }
	end
	return ref
end

function AssetService.GetAllReferences()
	local refs = {}
	for assetKey, ref in pairs(AssetReferences) do
		if type(ref) == "table" and ref.Path then
			refs[assetKey] = ref
		end
	end
	return refs
end

function AssetService.ResolvePath(assetKey)
	local ref = AssetService.GetReference(assetKey)
	return ref and normalizePath(ref.Path) or nil
end

function AssetService.ResolveAsset(assetKey)
	local ref = AssetService.GetReference(assetKey)
	if not ref then
		return nil, "missing-reference", nil
	end
	local primary = findByPath(ref.Path)
	if primary then
		return primary, "organized", ref
	end
	for _, fallbackPath in ipairs(ref.FallbackPaths or {}) do
		local loose = findByPath(fallbackPath)
		if loose then
			return loose, "loose", ref
		end
	end
	return nil, "missing", ref
end

function AssetService.HasAsset(assetKey)
	local asset = AssetService.ResolveAsset(assetKey)
	return asset ~= nil
end

function AssetService.HasOrganizedAsset(assetKey)
	local asset, status = AssetService.ResolveAsset(assetKey)
	return asset ~= nil and status == "organized"
end

function AssetService.GetModel(assetKey)
	local asset = AssetService.ResolveAsset(assetKey)
	return asset
end

function AssetService.WarnMissingOnce(assetKey)
	if not warnedMissing[assetKey] then
		warnedMissing[assetKey] = true
		warn("[FEED THE VOID] Missing imported asset " .. tostring(assetKey) .. "; using fallback.")
	end
end

function AssetService.EnsurePrimaryPart(model)
	if not model then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best = largestBasePart(model)
	if best then
		model.PrimaryPart = best
	end
	return best
end

function AssetService.GetBoundingBox(model)
	if typeof(model) ~= "Instance" then
		return CFrame.new(), Vector3.new(0, 0, 0)
	end
	if model:IsA("BasePart") then
		return model.CFrame, model.Size
	end
	local ok, boxCFrame, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if ok then
		return boxCFrame, size
	end
	return model:GetPivot(), Vector3.new(0, 0, 0)
end

function AssetService.PivotModel(model, cframe)
	if not model or typeof(cframe) ~= "CFrame" then
		return false
	end
	if model:IsA("BasePart") then
		model.CFrame = cframe
		return true
	end
	AssetService.EnsurePrimaryPart(model)
	model:PivotTo(cframe)
	return true
end

function AssetService.SetModelCFrame(model, cframe)
	return AssetService.PivotModel(model, cframe)
end

function AssetService.ScaleModel(model, scale)
	scale = tonumber(scale) or 1
	if not model or math.abs(scale - 1) < 0.001 then
		return
	end
	if model:IsA("BasePart") then
		model.Size *= scale
		return
	end
	local ok = pcall(function()
		model:ScaleTo(scale)
	end)
	if ok then
		return
	end
	local pivot = model:GetPivot()
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(child.CFrame)
			child.Size *= scale
			child.CFrame = pivot * CFrame.new(relative.Position * scale) * (relative - relative.Position)
		end
	end
end

function AssetService.ScaleModelSafely(model, scale)
	return AssetService.ScaleModel(model, scale)
end

function AssetService.ScaleToTargetSize(model, targetSize)
	if typeof(targetSize) ~= "Vector3" then
		return nil
	end
	local _, size = AssetService.GetBoundingBox(model)
	local ratio = targetRatioFor(size, targetSize)
	if ratio then
		AssetService.ScaleModel(model, ratio)
	end
	local _, finalSize = AssetService.GetBoundingBox(model)
	return finalSize
end

function AssetService.ApplySafeModelSetup(model, options)
	options = type(options) == "table" and options or {}
	local category = options.Category
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Anchored = options.Anchored ~= false
			child.CanCollide = options.CanCollide == true
			child.CanQuery = options.CanQuery == true
			child.CanTouch = options.CanTouch == true or category == "Pickups"
			child.Massless = true
		end
	end
	AssetService.EnsurePrimaryPart(model)
	return model
end

function AssetService.ApplyMutationVisual(model, mutationId, snackColor)
	if not model then
		return
	end
	mutationId = mutationId or "Normal"
	local mutation = AssetService.Context and AssetService.Context.Config.MutationConfig[mutationId] or nil
	local color = (mutation and mutation.Color) or snackColor
	local shouldHighlight = mutationId ~= "Normal" and mutationId ~= "Growing"
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local textured = hasTexturePayload(child)
			if color and not textured then
				child.Color = color
			end
			if mutation and mutation.Material and not textured then
				child.Material = mutation.Material
			end
			if shouldHighlight and not child:FindFirstChild("FTVMutationGlow") then
				local light = Instance.new("PointLight")
				light.Name = "FTVMutationGlow"
				light.Brightness = mutationId == "VoidTouched" and 0.75 or 0.45
				light.Range = mutationId == "VoidTouched" and 10 or 7
				light.Color = color or Color3.fromRGB(170, 80, 255)
				light.Parent = child
			end
		end
	end
	if shouldHighlight and model:IsA("Model") and not model:FindFirstChild("FTVMutationHighlight") then
		local highlight = Instance.new("Highlight")
		highlight.Name = "FTVMutationHighlight"
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0.45
		highlight.OutlineColor = color or Color3.fromRGB(170, 80, 255)
		highlight.Parent = model
	end
	model:SetAttribute("MutationVisualApplied", mutationId)
end

function AssetService.ApplyReadyHighlight(model)
	if not model or not model:IsA("Model") or model:FindFirstChild("FTVReadyHighlight") then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "FTVReadyHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0.22
	highlight.OutlineColor = Color3.fromRGB(255, 221, 112)
	highlight.Parent = model
end

function AssetService.AttachBillboard(model, config)
	local part = AssetService.EnsurePrimaryPart(model)
	if not part then
		return nil
	end
	config = type(config) == "table" and config or { Text = tostring(config or "") }
	local old = part:FindFirstChild(config.Name or "FTVBillboard")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = config.Name or "FTVBillboard"
	gui.AlwaysOnTop = config.AlwaysOnTop ~= false
	gui.Size = config.Size or UDim2.new(0, 190, 0, 58)
	gui.StudsOffset = config.StudsOffset or Vector3.new(0, 2.8, 0)
	gui.MaxDistance = config.MaxDistance or 80
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = config.BackgroundTransparency or 0.18
	label.BackgroundColor3 = config.BackgroundColor3 or Color3.fromRGB(24, 27, 34)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.TextColor3 = config.TextColor3 or Color3.fromRGB(255, 246, 210)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = config.Font or Enum.Font.GothamBold
	label.Text = config.Text or ""
	label.Parent = gui
	return gui
end

function AssetService.AddBillboard(model, text, studsOffset)
	return AssetService.AttachBillboard(model, {
		Text = text,
		StudsOffset = studsOffset,
	})
end

function AssetService.AttachPrompt(modelOrPart, config)
	local part = modelOrPart and (modelOrPart:IsA("BasePart") and modelOrPart or AssetService.EnsurePrimaryPart(modelOrPart))
	if not part then
		return nil
	end
	config = type(config) == "table" and config or {}
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = config.Name or (safeName(config.ActionText or "Use") .. "Prompt")
	prompt.ActionText = config.ActionText or "Use"
	prompt.ObjectText = config.ObjectText or ""
	prompt.HoldDuration = config.HoldDuration or 0.2
	prompt.MaxActivationDistance = config.MaxActivationDistance or 10
	prompt.RequiresLineOfSight = config.RequiresLineOfSight == true
	prompt.Parent = part
	return prompt
end

function AssetService.AddProximityPrompt(modelOrPart, promptText, actionText)
	return AssetService.AttachPrompt(modelOrPart, {
		ObjectText = promptText,
		ActionText = actionText,
		Name = safeName(actionText) .. "Prompt",
	})
end

function AssetService.CreateFallback(assetKey)
	local ref = AssetService.GetReference(assetKey)
	local fallbackType = (ref and ref.FallbackType) or fallbackByKey[assetKey] or "SnackRound"
	local config = fallback[fallbackType] or fallback.SnackRound
	local model = Instance.new("Model")
	model.Name = "Fallback_" .. tostring(assetKey)
	model:SetAttribute("FallbackAssetKey", assetKey)
	model:SetAttribute("AssetKey", assetKey)
	model:SetAttribute("AssetSourceStatus", "fallback")
	local part = Instance.new("Part")
	part.Name = tostring(assetKey) .. "FallbackPart"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = fallbackType == "Pickup"
	part.Shape = config.Shape or Enum.PartType.Block
	part.Material = config.Material or Enum.Material.SmoothPlastic
	part.Color = config.Color or Color3.fromRGB(180, 180, 180)
	part.Size = config.Size or Vector3.new(2, 2, 2)
	part.Parent = model
	model.PrimaryPart = part
	addFallbackAccent(model, part, fallbackType)
	return model
end

function AssetService.CloneModel(assetKey, options)
	options = type(options) == "table" and options or {}
	local asset, status, ref = AssetService.ResolveAsset(assetKey)
	if asset then
		local clone = normalizeClone(asset:Clone(), assetKey)
		clone.Name = options.Name or tostring(assetKey)
		clone:SetAttribute("AssetKey", assetKey)
		clone:SetAttribute("AssetSourceStatus", status)
		AssetService.ApplySafeModelSetup(clone, {
			Category = ref and ref.Category,
			CanTouch = options.CanTouch,
			CanCollide = options.CanCollide,
			CanQuery = options.CanQuery,
			Anchored = options.Anchored,
		})
		if ref and ref.DefaultScale and math.abs((tonumber(ref.DefaultScale) or 1) - 1) > 0.001 then
			AssetService.ScaleModel(clone, ref.DefaultScale)
		end
		if options.ApplyReferenceTargetSize and ref and typeof(ref.TargetSize) == "Vector3" then
			AssetService.ScaleToTargetSize(clone, ref.TargetSize)
		end
		return clone, status == "organized"
	end
	AssetService.WarnMissingOnce(assetKey)
	local fallbackModel = AssetService.CreateFallback(assetKey)
	AssetService.ApplySafeModelSetup(fallbackModel, {
		Category = ref and ref.Category,
		CanTouch = options.CanTouch,
		CanCollide = options.CanCollide,
		CanQuery = options.CanQuery,
		Anchored = options.Anchored,
	})
	return fallbackModel, false
end

function AssetService.GetAssetReport()
	local report = {
		Total = 0,
		Organized = 0,
		Loose = 0,
		Missing = 0,
		ByCategory = {},
		Assets = {},
	}
	for _, assetKey in ipairs(AssetReferences.RequiredAssetKeys or {}) do
		local asset, status, ref = AssetService.ResolveAsset(assetKey)
		local category = (ref and ref.Category) or "Uncategorized"
		local className = asset and asset.ClassName or "missing"
		local hasPrimaryPart = false
		local boundingSize = Vector3.new(0, 0, 0)
		if asset then
			if asset:IsA("BasePart") then
				hasPrimaryPart = true
				boundingSize = asset.Size
			elseif asset:IsA("Model") then
				hasPrimaryPart = AssetService.EnsurePrimaryPart(asset) ~= nil
				local _, size = AssetService.GetBoundingBox(asset)
				boundingSize = size
			elseif asset:IsA("Folder") then
				local firstPart = asset:FindFirstChildWhichIsA("BasePart", true)
				hasPrimaryPart = firstPart ~= nil
				if firstPart then
					boundingSize = firstPart.Size
				end
			end
		end
		local fallbackStatus = "not-needed"
		if not asset then
			fallbackStatus = fallbackByKey[assetKey] and "available" or "missing"
		elseif status ~= "organized" then
			fallbackStatus = "loose-source"
		end
		report.Total += 1
		report.ByCategory[category] = report.ByCategory[category] or { Organized = 0, Loose = 0, Missing = 0, Total = 0 }
		report.ByCategory[category].Total += 1
		if asset and status == "organized" then
			report.Organized += 1
			report.ByCategory[category].Organized += 1
		elseif asset then
			report.Loose += 1
			report.ByCategory[category].Loose += 1
		else
			report.Missing += 1
			report.ByCategory[category].Missing += 1
		end
		table.insert(report.Assets, {
			Key = assetKey,
			Status = asset and status or "missing",
			Category = category,
			Path = ref and table.concat(normalizePath(ref.Path), ".") or "?",
			ClassName = className,
			BoundingBox = boundingSize,
			HasPrimaryPart = hasPrimaryPart,
			FallbackStatus = fallbackStatus,
		})
	end
	lastAssetReport = report
	return report
end

function AssetService.PrintAssetCheck(player)
	local report = AssetService.GetAssetReport()
	print(string.format(
		"[FEED THE VOID][Assets] total=%d organized=%d loose=%d missing=%d",
		report.Total,
		report.Organized,
		report.Loose,
		report.Missing
	))
	for _, item in ipairs(report.Assets) do
		local bounds = item.BoundingBox
		local boundsText = typeof(bounds) == "Vector3" and string.format("%.1f x %.1f x %.1f", bounds.X, bounds.Y, bounds.Z) or "?"
		local line = string.format(
			"[FEED THE VOID][Assets] key=%s status=%s path=%s class=%s bounds=%s primary=%s fallback=%s",
			tostring(item.Key),
			tostring(item.Status),
			tostring(item.Path),
			tostring(item.ClassName),
			boundsText,
			tostring(item.HasPrimaryPart == true),
			tostring(item.FallbackStatus)
		)
		if item.Status ~= "organized" then
			warn(line)
		else
			print(line)
		end
	end
	if player and AssetService.Context and AssetService.Context.Services.EconomyService then
		AssetService.Context.Services.EconomyService.Notify(player, "Assets: " .. tostring(report.Organized) .. " organized, " .. tostring(report.Loose) .. " loose, " .. tostring(report.Missing) .. " missing.")
	end
	return report
end

function AssetService.ClearShowcase()
	local world = workspace:FindFirstChild("GameWorld") or workspace
	local old = world:FindFirstChild("AssetShowcase")
	if old then
		old:Destroy()
	end
	return true
end

function AssetService.SpawnShowcase(player)
	AssetService.ClearShowcase()
	local world = workspace:FindFirstChild("GameWorld") or workspace
	local folder = Instance.new("Folder")
	folder.Name = "AssetShowcase"
	folder.Parent = world

	local origin = Vector3.new(0, 8, -95)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		origin = root.Position + root.CFrame.LookVector * 24 + Vector3.new(0, 4, 0)
	end

	local columns = 6
	local spacing = 9
	local count = 0
	for _, assetKey in ipairs(AssetReferences.RequiredAssetKeys or {}) do
		count += 1
		local ref = AssetService.GetReference(assetKey)
		local model = AssetService.CloneModel(assetKey, { ApplyReferenceTargetSize = true })
		model.Name = "Showcase_" .. assetKey
		model.Parent = folder
		local row = math.floor((count - 1) / columns)
		local column = (count - 1) % columns
		local position = origin + Vector3.new((column - (columns - 1) * 0.5) * spacing, 0, row * spacing)
		local maxSize = ref and ref.Category == "Void" and Vector3.new(7, 7, 7) or Vector3.new(4.4, 4.4, 4.4)
		AssetService.ScaleToTargetSize(model, maxSize)
		AssetService.PivotModel(model, CFrame.new(position))
		local _, status = AssetService.ResolveAsset(assetKey)
		AssetService.AttachBillboard(model, {
			Name = "AssetShowcaseLabel",
			Text = assetKey .. "\n" .. tostring(status),
			Size = UDim2.new(0, 150, 0, 44),
			StudsOffset = Vector3.new(0, 3.6, 0),
			MaxDistance = 70,
			BackgroundTransparency = 0.24,
		})
	end
	if player and AssetService.Context and AssetService.Context.Services.EconomyService then
		AssetService.Context.Services.EconomyService.Notify(player, "Asset showcase spawned nearby.")
	end
	return folder
end

function AssetService.GetLastAssetReport()
	return lastAssetReport
end

return AssetService
