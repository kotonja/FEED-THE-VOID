local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetReferences = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReferences"))

local AssetService = {}

local warnedMissing = {}

local fallback = {
	Void = { Color = Color3.fromRGB(84, 45, 132), Size = Vector3.new(8, 8, 8), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
	Creature = { Color = Color3.fromRGB(72, 24, 124), Size = Vector3.new(1.4, 1.1, 1.4), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SnackRound = { Color = Color3.fromRGB(185, 164, 132), Size = Vector3.new(2.6, 2.6, 2.6), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SnackCube = { Color = Color3.fromRGB(92, 205, 210), Size = Vector3.new(2.4, 2.4, 2.4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SnackWrap = { Color = Color3.fromRGB(245, 148, 196), Size = Vector3.new(3, 1.4, 1.6), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	PhantomSnack = { Color = Color3.fromRGB(172, 116, 255), Size = Vector3.new(2.2, 2.2, 2.2), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
	GrowPlate = { Color = Color3.fromRGB(80, 92, 110), Size = Vector3.new(5, 0.4, 5), Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal },
	DisplayPedestal = { Color = Color3.fromRGB(70, 64, 90), Size = Vector3.new(4, 1.2, 4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	Station = { Color = Color3.fromRGB(70, 86, 112), Size = Vector3.new(5, 4, 3), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	Portal = { Color = Color3.fromRGB(86, 55, 124), Size = Vector3.new(4, 6, 1), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	Chest = { Color = Color3.fromRGB(122, 78, 48), Size = Vector3.new(5.2, 2.4, 4.2), Shape = Enum.PartType.Block, Material = Enum.Material.WoodPlanks },
	Pickup = { Color = Color3.fromRGB(255, 180, 80), Size = Vector3.new(1.25, 1.25, 1.25), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
}

local fallbackByKey = {
	TheVoid = "Void",
	Voidmite = "Creature",
	VoidlingPet = "Creature",
	SnackRoundBase = "SnackRound",
	SnackCubeBase = "SnackCube",
	SnackWrapBase = "SnackWrap",
	PhantomSnack = "PhantomSnack",
	GrowPlate = "GrowPlate",
	DisplayPedestal = "DisplayPedestal",
	SeedShopMachine = "Station",
	SellStation = "Station",
	UpgradeStation = "Station",
	RebirthPortal = "Portal",
	DailyRewardChest = "Chest",
	VoidCrumbPickup = "Pickup",
	VoidShardPickup = "Pickup",
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

local function anchorParts(model)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
		end
	end
end

local function safeName(text)
	return tostring(text or "Prompt"):gsub("%W+", "")
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

function AssetService.ResolvePath(assetKey)
	local ref = AssetService.GetReference(assetKey)
	return ref and normalizePath(ref.Path) or nil
end

function AssetService.HasAsset(assetKey)
	local pathParts = AssetService.ResolvePath(assetKey)
	return pathParts and findByPath(pathParts) ~= nil or false
end

function AssetService.GetModel(assetKey)
	local pathParts = AssetService.ResolvePath(assetKey)
	return pathParts and findByPath(pathParts) or nil
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
	if not model or scale == 1 then
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
			local hasTexture = child:IsA("MeshPart") and child.TextureID and child.TextureID ~= ""
			if color and not hasTexture then
				child.Color = color
			end
			if mutation and mutation.Material and not hasTexture then
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
	local part = Instance.new("Part")
	part.Name = tostring(assetKey) .. "FallbackPart"
	part.Anchored = true
	part.CanCollide = false
	part.Shape = config.Shape or Enum.PartType.Block
	part.Material = config.Material or Enum.Material.SmoothPlastic
	part.Color = config.Color or Color3.fromRGB(180, 180, 180)
	part.Size = config.Size or Vector3.new(2, 2, 2)
	part.Parent = model
	model.PrimaryPart = part
	if fallbackType == "Station" or fallbackType == "Chest" or fallbackType == "Portal" then
		local accent = Instance.new("Part")
		accent.Name = "FallbackAccent"
		accent.Anchored = true
		accent.CanCollide = false
		accent.Material = Enum.Material.Metal
		accent.Color = Color3.fromRGB(202, 174, 92)
		accent.Size = Vector3.new(math.max(0.8, part.Size.X * 0.38), 0.18, math.max(0.8, part.Size.Z * 0.42))
		accent.CFrame = part.CFrame + Vector3.new(0, part.Size.Y * 0.52, 0)
		accent.Parent = model
	end
	return model
end

function AssetService.CloneModel(assetKey)
	local asset = AssetService.GetModel(assetKey)
	if asset then
		local clone = normalizeClone(asset:Clone(), assetKey)
		clone.Name = assetKey
		anchorParts(clone)
		AssetService.EnsurePrimaryPart(clone)
		return clone, true
	end
	AssetService.WarnMissingOnce(assetKey)
	return AssetService.CreateFallback(assetKey), false
end

return AssetService
