local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetReferences = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReferences"))

local AssetService = {}

local warnedMissing = {}

local fallback = {
	TheVoid = { Color = Color3.fromRGB(95, 45, 160), Size = Vector3.new(8, 8, 8), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
	Voidmite = { Color = Color3.fromRGB(72, 24, 124), Size = Vector3.new(1.4, 1.1, 1.4), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SnackRoundBase = { Color = Color3.fromRGB(185, 164, 132), Size = Vector3.new(2.6, 2.6, 2.6), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SnackCubeBase = { Color = Color3.fromRGB(92, 220, 225), Size = Vector3.new(2.4, 2.4, 2.4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SnackWrapBase = { Color = Color3.fromRGB(255, 158, 204), Size = Vector3.new(3, 1.4, 1.6), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	GrowPlate = { Color = Color3.fromRGB(80, 92, 110), Size = Vector3.new(5, 0.4, 5), Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal },
	DisplayPedestal = { Color = Color3.fromRGB(70, 64, 90), Size = Vector3.new(4, 1.2, 4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SeedShopMachine = { Color = Color3.fromRGB(56, 128, 84), Size = Vector3.new(5, 5, 3), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SellStation = { Color = Color3.fromRGB(64, 118, 170), Size = Vector3.new(5, 4, 3), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	VoidCrumbPickup = { Color = Color3.fromRGB(255, 180, 80), Size = Vector3.new(1.3, 1.3, 1.3), Shape = Enum.PartType.Ball, Material = Enum.Material.Glass },
	VoidShardPickup = { Color = Color3.fromRGB(155, 105, 255), Size = Vector3.new(1.1, 1.6, 1.1), Shape = Enum.PartType.Block, Material = Enum.Material.Glass },
}

local function findByPath(pathParts)
	local current = game
	for _, partName in ipairs(pathParts or {}) do
		current = current:FindFirstChild(partName)
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

function AssetService.Init(context)
	AssetService.Context = context
end

function AssetService.Start()
	AssetService.MountImportedAsset("TheVoid", "Workspace.GameWorld.CentralVoid.VoidCore", 1)
end

function AssetService.HasAsset(assetKey)
	local ref = AssetReferences[assetKey]
	return ref and findByPath(ref) ~= nil or false
end

function AssetService.GetModel(assetKey)
	local ref = AssetReferences[assetKey]
	return ref and findByPath(ref) or nil
end

function AssetService.EnsurePrimaryPart(model)
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

function AssetService.SetModelCFrame(model, cframe)
	if not model then
		return
	end
	if model:IsA("BasePart") then
		model.CFrame = cframe
		return
	end
	AssetService.EnsurePrimaryPart(model)
	model:PivotTo(cframe)
end

function AssetService.ScaleModelSafely(model, scale)
	scale = tonumber(scale) or 1
	if not model then
		return
	end
	if model:IsA("BasePart") then
		model.Size *= scale
		return
	end
	local ok = pcall(function()
		model:ScaleTo(scale)
	end)
	if not ok then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Size *= scale
			end
		end
	end
end

function AssetService.ApplyMutationVisual(model, mutationId, snackColor)
	local mutation = AssetService.Context and AssetService.Context.Config.MutationConfig[mutationId or "Normal"] or nil
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Color = (mutation and mutation.Color) or snackColor or child.Color
			child.Material = (mutation and mutation.Material) or child.Material
			if mutationId == "VoidTouched" then
				local light = Instance.new("PointLight")
				light.Name = "VoidSnackGlow"
				light.Brightness = 1
				light.Range = 10
				light.Color = Color3.fromRGB(170, 80, 255)
				light.Parent = child
			elseif mutationId == "Glitched" then
				local light = Instance.new("PointLight")
				light.Name = "GlitchGlow"
				light.Brightness = 0.7
				light.Range = 7
				light.Color = Color3.fromRGB(80, 255, 190)
				light.Parent = child
			elseif mutationId == "Rainbow" then
				child.Color = Color3.fromRGB(255, 90, 205)
			end
		end
	end
end

function AssetService.AddBillboard(model, text, studsOffset)
	local part = AssetService.EnsurePrimaryPart(model)
	if not part then
		return nil
	end
	local old = part:FindFirstChild("FTVBillboard")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "FTVBillboard"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 190, 0, 58)
	gui.StudsOffset = studsOffset or Vector3.new(0, 2.8, 0)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 0.18
	label.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.TextColor3 = Color3.fromRGB(255, 246, 210)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return gui
end

function AssetService.AddProximityPrompt(modelOrPart, promptText, actionText)
	local part = modelOrPart:IsA("BasePart") and modelOrPart or AssetService.EnsurePrimaryPart(modelOrPart)
	if not part then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = actionText:gsub("%s+", "") .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = promptText
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	return prompt
end

function AssetService.CreateFallback(assetKey)
	local config = fallback[assetKey] or fallback.SnackRoundBase
	local part = Instance.new("Part")
	part.Name = assetKey .. "FallbackPart"
	part.Anchored = true
	part.CanCollide = false
	part.Shape = config.Shape or Enum.PartType.Block
	part.Material = config.Material or Enum.Material.SmoothPlastic
	part.Color = config.Color or Color3.fromRGB(180, 180, 180)
	part.Size = config.Size or Vector3.new(2, 2, 2)
	return wrapBasePart(part, assetKey .. "Fallback")
end

function AssetService.CloneModel(assetKey)
	local asset = AssetService.GetModel(assetKey)
	if asset then
		local clone = asset:Clone()
		if clone:IsA("BasePart") then
			clone.Anchored = true
			clone.CanCollide = false
			clone = wrapBasePart(clone, assetKey)
		end
		for _, child in ipairs(clone:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Anchored = true
				child.CanCollide = false
			end
		end
		AssetService.EnsurePrimaryPart(clone)
		return clone, true
	end
	if not warnedMissing[assetKey] then
		warnedMissing[assetKey] = true
		warn("[FEED THE VOID] Missing imported asset " .. tostring(assetKey) .. "; using fallback.")
	end
	return AssetService.CreateFallback(assetKey), false
end

function AssetService.MountImportedAsset(assetKey, anchorPath, scale)
	if not AssetService.HasAsset(assetKey) then
		return nil
	end
	local anchor = findByPath(string.split(anchorPath, "."))
	if not anchor then
		return nil
	end
	local parent = anchor.Parent
	local model = AssetService.CloneModel(assetKey)
	model.Name = assetKey .. "_Imported"
	model.Parent = parent
	AssetService.SetModelCFrame(model, anchor:IsA("BasePart") and anchor.CFrame or anchor:GetPivot())
	AssetService.ScaleModelSafely(model, scale or 1)
	if anchor:IsA("BasePart") then
		anchor.Transparency = 1
		anchor.CanCollide = false
	end
	return model
end

return AssetService
