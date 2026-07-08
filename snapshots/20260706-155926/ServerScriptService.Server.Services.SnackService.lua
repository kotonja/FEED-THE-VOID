local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local SnackService = {}

local activeSnacks = {}
local displayedByWorldId = {}
local passiveNotifyAt = {}

local visualAssetByType = {
	Round = "SnackRoundBase",
	Cube = "SnackCubeBase",
	Wrap = "SnackWrapBase",
}

local defaultStageScale = {
	[1] = 0.34,
	[2] = 0.62,
	[3] = 0.92,
}

local defaultGrowthLift = {
	[1] = 0.42,
	[2] = 0.82,
	[3] = 1.18,
}

local defaultRarityMaxSize = {
	Common = 2.2,
	Uncommon = 2.5,
	Rare = 2.9,
	Epic = 3.25,
	Legendary = 3.6,
}

local defaultVisualTypeSizeScale = {
	Round = 1,
	Cube = 0.9,
	Wrap = 1,
}

local PLATE_SURFACE_CLEARANCE = 0.08

local function stageScaleFor(stage)
	local snackConfig = SnackService.Context and SnackService.Context.Config.SnackConfig
	local stageScale = snackConfig and snackConfig.StageScale
	return (stageScale and stageScale[stage or 3]) or defaultStageScale[stage or 3] or 1
end

local function growthLiftFor(stage)
	local snackConfig = SnackService.Context and SnackService.Context.Config.SnackConfig
	local growthLift = snackConfig and snackConfig.GrowthLift
	return (growthLift and growthLift[stage or 3]) or defaultGrowthLift[stage or 3] or 1
end

local function modelBoundingBox(model)
	if typeof(model) ~= "Instance" then
		return CFrame.new(), Vector3.new(2, 2, 2)
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
	return model:GetPivot(), Vector3.new(2, 2, 2)
end

local function modelBounds(model)
	local _, size = modelBoundingBox(model)
	return size
end

local function modelMaxDimension(model)
	local size = modelBounds(model)
	return math.max(size.X, size.Y, size.Z)
end

local function scaleModelPartsFromPivot(model, scale)
	scale = tonumber(scale) or 1
	if typeof(model) ~= "Instance" or math.abs(scale - 1) < 0.001 then
		return
	end
	if model:IsA("BasePart") then
		model.Size *= scale
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

local function forceModelMaxDimension(model, targetMax)
	if typeof(model) ~= "Instance" then
		return targetMax
	end
	local currentMax = modelMaxDimension(model)
	if currentMax > 0.01 then
		SnackService.Context.Services.AssetService.ScaleModelSafely(model, targetMax / currentMax)
	end
	for _ = 1, 3 do
		currentMax = modelMaxDimension(model)
		if currentMax <= 0.01 then
			break
		end
		local ratio = targetMax / currentMax
		if math.abs(1 - ratio) <= 0.025 then
			break
		end
		scaleModelPartsFromPivot(model, ratio)
	end
	return modelMaxDimension(model)
end

local function snackYOffsetFor(model, stage)
	local size = modelBounds(model)
	return math.clamp((size.Y * 0.5) + PLATE_SURFACE_CLEARANCE, 0.5, 3.25)
end

local getSnackConfig
local getMutationConfig

local function targetSnackMaxSize(snackId, mutationId, stage, displayScale)
	local snackConfig = SnackService.Context and SnackService.Context.Config.SnackConfig
	local snack = snackConfig and snackConfig[snackId]
	local raritySizes = (snackConfig and snackConfig.RarityMaxSize) or defaultRarityMaxSize
	local visualSizes = (snackConfig and snackConfig.VisualTypeSizeScale) or defaultVisualTypeSizeScale
	local rarity = snack and snack.Rarity or "Common"
	local visualType = snack and snack.VisualType or "Round"
	local baseMax = (snack and snack.VisualMaxSize) or raritySizes[rarity] or defaultRarityMaxSize.Common
	local visualScale = visualSizes[visualType] or 1
	local mutation = getMutationConfig(mutationId)
	local mutationScale = mutation and mutation.ScaleMultiplier or 1
	local target = baseMax * visualScale * stageScaleFor(stage or 3) * mutationScale * (displayScale or 1)
	local cap = (displayScale or 1) < 1 and 3.85 or 4.05
	return math.clamp(target, 0.85, cap)
end

local function applySnackModelSize(model, snackId, mutationId, stage, displayScale)
	local targetMax = targetSnackMaxSize(snackId, mutationId, stage, displayScale)
	local measuredMax = forceModelMaxDimension(model, targetMax)
	model:SetAttribute("SnackRarity", (getSnackConfig(snackId) and getSnackConfig(snackId).Rarity) or "Common")
	model:SetAttribute("SnackTargetMaxSize", targetMax)
	model:SetAttribute("SnackMeasuredMaxSize", measuredMax)
	model:SetAttribute("SnackStageScale", stageScaleFor(stage or 3))
	return targetMax
end

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function snackFolder()
	return getWorld():WaitForChild("ActiveSnacks")
end

local function limitValue(limitName, fallback)
	local limits = SnackService.Context.Config.GameConfig.Limits or {}
	local anti = SnackService.Context.Config.GameConfig.AntiExploit or {}
	return tonumber(limits[limitName]) or tonumber(anti[limitName]) or fallback
end

local function distanceValue(distanceName, fallback)
	local distances = SnackService.Context.Config.GameConfig.InteractionDistances or {}
	return tonumber(distances[distanceName]) or fallback
end

function getSnackConfig(snackId)
	return SnackService.Context.Config.SnackConfig[snackId]
end

function getMutationConfig(mutationId)
	return SnackService.Context.Config.MutationConfig[mutationId or "Normal"]
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

local function plateTopY(plate)
	if typeof(plate) == "Instance" and plate:IsA("BasePart") then
		return plate.Position.Y + (plate.Size.Y * 0.5)
	end
	local position = targetPosition(plate)
	return position and position.Y or 0
end

local function effectPayload(effectType, target, extra)
	local payload = type(extra) == "table" and table.clone(extra) or {}
	payload.Type = effectType
	if typeof(target) == "Instance" then
		payload.Target = target
	end
	payload.Position = payload.Position or targetPosition(target)
	return payload
end

local function fireEffect(player, effectType, target, extra)
	local context = SnackService.Context
	local vfxService = context and context.Services and context.Services.VFXService
	if player and vfxService then
		local payload = effectPayload(effectType, target, extra)
		vfxService.PlayForPlayer(player, effectType, payload)
	end
end

local function fireEffectAll(effectType, target, extra)
	local context = SnackService.Context
	local vfxService = context and context.Services and context.Services.VFXService
	if vfxService then
		local payload = effectPayload(effectType, target, extra)
		vfxService.PlayForAll(effectType, payload)
	end
end

local rareHarvestMutations = {
	Golden = true,
	Rainbow = true,
	Frozen = true,
	VoidTouched = true,
	Glitched = true,
}

local function playAudioForPlayer(player, key, mode, target, options)
	local audioService = SnackService.Context and SnackService.Context.Services.AudioService
	if audioService then
		audioService.PlayForPlayer(player, key, mode or "World", target, options)
	end
end

local function playAudioForAll(key, mode, target, options)
	local audioService = SnackService.Context and SnackService.Context.Services.AudioService
	if audioService then
		audioService.PlayForAll(key, mode or "World", target, options)
	end
end

local function harvestSoundKey(context, item)
	if not item then
		return "Planting.HarvestNormal"
	end
	if rareHarvestMutations[item.MutationId] then
		return "Planting.HarvestRare"
	end
	local snack = context.Config.SnackConfig[item.SnackId]
	if snack and context.Config.RarityConfig.IsAtLeast(snack.Rarity or "Common", "Rare") then
		return "Planting.HarvestRare"
	end
	return "Planting.HarvestNormal"
end

local function growthEffectPayload(plate, model, snackId, stage, extra)
	local snack = getSnackConfig(snackId)
	local payload = type(extra) == "table" and table.clone(extra) or {}
	payload.Stage = stage or (typeof(model) == "Instance" and model:GetAttribute("GrowthStage")) or 1
	payload.SnackId = snackId
	payload.DisplayName = payload.DisplayName or (snack and snack.DisplayName) or snackId
	payload.Rarity = snack and snack.Rarity or "Common"
	payload.VisualType = snack and snack.VisualType or "Round"
	payload.PlatePosition = typeof(plate) == "Instance" and plate.Position or nil
	payload.PlateTopY = typeof(plate) == "Instance" and plateTopY(plate) or nil
	payload.ModelPosition = targetPosition(model)
	payload.GrowthLift = growthLiftFor(payload.Stage)
	payload.GrowthYOffset = typeof(model) == "Instance" and model:GetAttribute("GrowthYOffset") or snackYOffsetFor(model, payload.Stage)
	payload.SnackBottomClearance = typeof(model) == "Instance" and model:GetAttribute("SnackBottomClearance") or PLATE_SURFACE_CLEARANCE
	payload.TargetMaxSize = typeof(model) == "Instance" and model:GetAttribute("SnackCurrentMaxSize") or nil
	return payload
end

local function positionSnackOnPlate(model, plate, stage)
	local platePosition = targetPosition(plate)
	if not platePosition then
		return snackYOffsetFor(model, stage)
	end
	local topY = plateTopY(plate)
	local boxCFrame, boxSize = modelBoundingBox(model)
	local pivot = model:GetPivot()
	local pivotToBoxCenter = pivot.Position - boxCFrame.Position
	local bottomY = boxCFrame.Position.Y - (boxSize.Y * 0.5)
	local pivotToBottom = pivot.Position.Y - bottomY
	local targetPivotPosition = Vector3.new(
		platePosition.X + pivotToBoxCenter.X,
		topY + PLATE_SURFACE_CLEARANCE + pivotToBottom,
		platePosition.Z + pivotToBoxCenter.Z
	)
	local rotation = pivot - pivot.Position
	SnackService.Context.Services.AssetService.SetModelCFrame(model, CFrame.new(targetPivotPosition) * rotation)

	local settledBoxCFrame, settledSize = modelBoundingBox(model)
	local settledBottomY = settledBoxCFrame.Position.Y - (settledSize.Y * 0.5)
	local correction = (topY + PLATE_SURFACE_CLEARANCE) - settledBottomY
	if math.abs(correction) > 0.01 then
		SnackService.Context.Services.AssetService.SetModelCFrame(model, model:GetPivot() + Vector3.new(0, correction, 0))
		settledBoxCFrame, settledSize = modelBoundingBox(model)
		settledBottomY = settledBoxCFrame.Position.Y - (settledSize.Y * 0.5)
	end

	local yOffset = model:GetPivot().Position.Y - platePosition.Y
	model:SetAttribute("GrowthLift", growthLiftFor(stage))
	model:SetAttribute("GrowthYOffset", yOffset)
	model:SetAttribute("PlateCenter", platePosition)
	model:SetAttribute("PlateTopY", topY)
	model:SetAttribute("SnackBottomY", settledBottomY)
	model:SetAttribute("SnackBottomClearance", settledBottomY - topY)
	return yOffset
end

local function itemDisplayName(snackId, mutationId)
	local snack = getSnackConfig(snackId)
	local mutation = getMutationConfig(mutationId)
	if not snack then
		return snackId
	end
	if not mutation or mutationId == "Normal" then
		return snack.DisplayName
	end
	return mutation.DisplayName .. " " .. snack.DisplayName
end

local function setPlatePrompt(plate, actionText, enabled)
	local prompt = plate and plate:FindFirstChild("PlatePrompt")
	if prompt then
		prompt.ActionText = actionText
		prompt.ObjectText = "Plate"
		prompt.HoldDuration = 0.12
		prompt.MaxActivationDistance = 10.5
		prompt.RequiresLineOfSight = false
		prompt.Enabled = enabled
	end
end

local function promptIsInside(prompt, ancestorName)
	local current = prompt and prompt.Parent
	while current and current ~= workspace do
		if current.Name == ancestorName then
			return true
		end
		current = current.Parent
	end
	return false
end

local function clearPlate(plate)
	if plate then
		plate:SetAttribute("Occupied", false)
		plate:SetAttribute("SnackUid", "")
		plate:SetAttribute("SnackId", "")
		plate:SetAttribute("GrowthStage", 0)
		setPlatePrompt(plate, "Plant Snack", true)
	end
end

local function createSnackModel(name, position, snackId, mutationId, stage, displayScale)
	local context = SnackService.Context
	local snack = getSnackConfig(snackId)
	local mutation = getMutationConfig(mutationId)
	local assetKey = visualAssetByType[(snack and snack.VisualType) or "Round"] or "SnackRoundBase"
	local model = context.Services.AssetService.CloneModel(assetKey)
	model.Name = name
	model.Parent = snackFolder()
	local targetMaxSize = applySnackModelSize(model, snackId, mutationId, stage or 3, displayScale or 1)
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(position))
	context.Services.AssetService.ApplyMutationVisual(model, mutationId, snack and snack.Color)
	model:SetAttribute("SnackCurrentMaxSize", targetMaxSize)
	model:SetAttribute("SnackId", snackId)
	model:SetAttribute("MutationId", mutationId or "Growing")
	return model
end

local function addDisplayLabel(model, text, passiveIncome)
	SnackService.Context.Services.AssetService.AttachBillboard(model, {
		Name = "FTVDisplayLabel",
		Text = text .. "\n+" .. tostring(passiveIncome) .. " coins/tick",
		Size = UDim2.new(0, 160, 0, 44),
		StudsOffset = Vector3.new(0, 2.35, 0),
		MaxDistance = 52,
		BackgroundTransparency = 0.28,
	})
end

local function getPlateNumber(plate)
	local number = tostring(plate.Name):match("Plate(%d+)")
	return tonumber(number) or 1
end

local function getNearestPlate(player, predicate)
	local plot = SnackService.Context.Services.PlotService.GetPlot(player)
	local plates = plot and plot:FindFirstChild("Plates")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plates or not root then
		return nil
	end
	local usablePlates = SnackService.Context.Services.UpgradeService.GetPlateCount(player)
	local bestPlate = nil
	local bestDistance = math.huge
	for _, plate in ipairs(plates:GetChildren()) do
		if plate:IsA("BasePart") and getPlateNumber(plate) <= usablePlates and (not predicate or predicate(plate)) then
			local distance = (root.Position - plate.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestPlate = plate
			end
		end
	end
	if bestPlate and bestDistance <= 18 then
		return bestPlate
	end
	return nil
end

local function allUsablePlatesOccupied(player)
	local plot = SnackService.Context.Services.PlotService.GetPlot(player)
	local plates = plot and plot:FindFirstChild("Plates")
	if not plates then
		return false, 0
	end
	local usablePlates = SnackService.Context.Services.UpgradeService.GetPlateCount(player)
	local usableCount = 0
	local occupiedCount = 0
	local readyCount = 0
	for _, plate in ipairs(plates:GetChildren()) do
		if plate:IsA("BasePart") and getPlateNumber(plate) <= usablePlates then
			usableCount += 1
			if plate:GetAttribute("Occupied") then
				occupiedCount += 1
				if tonumber(plate:GetAttribute("GrowthStage")) == 3 then
					readyCount += 1
				end
			end
		end
	end
	return usableCount > 0 and occupiedCount >= usableCount, readyCount
end

local function countActiveSnacksForPlayer(player)
	local count = 0
	for _, record in pairs(activeSnacks) do
		if record.Player == player and record.Model and record.Model.Parent then
			count += 1
		end
	end
	return count
end

local function countDisplayedForPlayer(player)
	local count = 0
	for _, model in pairs(displayedByWorldId) do
		if model and model.Parent and tonumber(model:GetAttribute("OwnerUserId")) == player.UserId then
			count += 1
		end
	end
	return count
end

local function displaySlotPosition(plot, shelfPart)
	local count = 0
	for _, model in pairs(displayedByWorldId) do
		if model and model.Parent and tonumber(model:GetAttribute("PlotId")) == tonumber(plot:GetAttribute("PlotId")) then
			count += 1
		end
	end
	local x = ((count % 5) - 2) * 3
	local z = math.floor(count / 5) * 2
	return shelfPart.Position + Vector3.new(x, 2.1, z)
end

local function stageForElapsed(elapsed, growTime)
	local progress = math.clamp((tonumber(elapsed) or 0) / math.max(1, tonumber(growTime) or 1), 0, 1)
	if progress >= 1 then
		return 3
	elseif progress >= 0.4 then
		return 2
	end
	return 1
end

local function getPlantedRecords(data)
	data.PlantedSnacks = type(data.PlantedSnacks) == "table" and data.PlantedSnacks or {}
	return data.PlantedSnacks
end

local function findPlantedRecord(data, uid)
	for index, record in ipairs(getPlantedRecords(data)) do
		if record.UniqueId == uid then
			return record, index
		end
	end
	return nil, nil
end

local function removePlantedRecord(data, uid)
	local _, index = findPlantedRecord(data, uid)
	if index then
		table.remove(data.PlantedSnacks, index)
	end
end

local function upsertPlantedRecord(data, record)
	local existing = findPlantedRecord(data, record.UniqueId)
	if existing then
		for key, value in pairs(record) do
			existing[key] = value
		end
		return existing
	end
	table.insert(getPlantedRecords(data), record)
	return record
end

local function plateForRecord(plot, record)
	local plates = plot and plot:FindFirstChild("Plates")
	if not plates then
		return nil
	end
	local plate = record.PlateName and plates:FindFirstChild(record.PlateName)
	if plate then
		return plate
	end
	return plates:FindFirstChild("Plate" .. tostring(record.PlateId or 1))
end

function SnackService.Init(context)
	SnackService.Context = context
end

function SnackService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			SnackService.GrowthTick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SnackService.Context.Config.GameConfig.BaseDisplayIncomeInterval)
			SnackService.PayDisplayIncome()
		end
	end)
	SnackService.BindWorldPrompts()
	task.spawn(function()
		while true do
			task.wait(5)
			SnackService.BindWorldPrompts()
		end
	end)
end

function SnackService.BindWorldPrompts()
	local world = getWorld()
	for _, prompt in ipairs(world:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and not prompt:GetAttribute("FTVBound") then
			prompt:SetAttribute("FTVBound", true)
			if prompt.Name == "PlatePrompt" then
				local plate = prompt.Parent
				if plate and plate:GetAttribute("Occupied") then
					setPlatePrompt(plate, "Growing...", false)
				else
					setPlatePrompt(plate, "Plant Snack", true)
				end
				prompt.Triggered:Connect(function(player)
					local currentPlate = prompt.Parent
					if currentPlate and currentPlate:GetAttribute("Occupied") then
						SnackService.HarvestSnack(player, currentPlate)
					else
						SnackService.PlantSnack(player, currentPlate, "CookieRock")
					end
				end)
			elseif prompt.Name == "SellPrompt" then
				prompt.ActionText = "Open Inventory"
				prompt.ObjectText = "Sell Station"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Select an inventory snack, then tap SELL.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			elseif prompt.Name == "FeedPrompt" then
				prompt.ActionText = "Feed Void"
				prompt.ObjectText = "THE VOID"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Select an inventory snack, then tap FEED VOID.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			elseif prompt.Name == "DisplayPrompt" then
				prompt.ActionText = "Display Snack"
				prompt.ObjectText = "Display Shelf"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Select an inventory snack, then tap DISPLAY.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			elseif prompt.Name == "BuySeedPrompt" then
				prompt.ActionText = "Buy Seeds"
				prompt.ObjectText = "Seed Shop"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Open the shop panel to buy seeds.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			elseif prompt.Name == "RebirthPrompt" or promptIsInside(prompt, "RebirthStation") then
				prompt.Name = "RebirthPrompt"
				prompt.ActionText = "Rebirth"
				prompt.ObjectText = "Rebirth Station"
				prompt.HoldDuration = 0.25
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.RebirthService.TryRebirth(player)
				end)
			elseif prompt.Name == "UpgradePrompt" then
				prompt.ActionText = "Open Upgrades"
				prompt.ObjectText = "Upgrade Terminal"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Open UPGRADES and buy your first lab boost.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			end
		end
	end
end

function SnackService.PlantSnack(player, plate, snackId)
	local context = SnackService.Context
	snackId = snackId or "CookieRock"
	if plate == nil then
		plate = getNearestPlate(player, function(candidate)
			return not candidate:GetAttribute("Occupied")
		end)
	end
	local validPlate = context.Services.ValidationService.ValidateWorldObject(plate, "BasePart")
	if not validPlate then
		local full, readyCount = allUsablePlatesOccupied(player)
		if full then
			context.Services.EconomyService.Notify(player, readyCount > 0 and "All plates are full. Harvest a ready snack." or "All plates are full. Wait for one to finish growing.")
		else
			context.Services.EconomyService.Notify(player, "Stand near an empty plate to plant.")
		end
		return false
	end
	if getPlateNumber(plate) > context.Services.UpgradeService.GetPlateCount(player) then
		context.Services.EconomyService.Notify(player, "Buy Extra Plate to use this plate.")
		return false
	end
	if countActiveSnacksForPlayer(player) >= math.min(context.Services.UpgradeService.GetPlateCount(player), limitValue("MaxActiveSnacksPerPlayer", 10)) then
		context.Services.EconomyService.Notify(player, "Your active plates are full. Harvest one before planting more.")
		return false
	end
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can plant here.")
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, plate, distanceValue("Plate", 12)) then
		context.Services.EconomyService.Notify(player, "Move closer to that plate.")
		return false
	end
	local hasSeed, snack = context.Services.ValidationService.ValidateSeed(player, snackId)
	if not hasSeed then
		context.Services.EconomyService.Notify(player, "You need a " .. (snack and snack.DisplayName or "snack") .. " seed.")
		return false
	end
	if plate:GetAttribute("Occupied") then
		context.Services.EconomyService.Notify(player, "That plate is busy.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		context.Services.EconomyService.Notify(player, "Profile still loading. Try again in a moment.")
		return false
	end
	data.Seeds = type(data.Seeds) == "table" and data.Seeds or {}
	data.Seeds[snackId] -= 1
	local uid = HttpService:GenerateGUID(false)
	local growMultiplier = (context.RuntimeOverrides and tonumber(context.RuntimeOverrides.GrowMultiplier)) or 1
	local growTime = context.Config.GameConfig.DebugFastGrowth and context.Config.GameConfig.FastGrowthTime or (snack.GrowTime / math.max(0.1, context.Services.UpgradeService.GetMultiplier(player, "GrowSpeed") * growMultiplier))
	plate:SetAttribute("Occupied", true)
	plate:SetAttribute("SnackUid", uid)
	plate:SetAttribute("SnackId", snackId)
	plate:SetAttribute("GrowthStage", 1)
	setPlatePrompt(plate, "Growing...", false)

	local model = createSnackModel("Growing_" .. uid, plate.Position + Vector3.new(0, 1.15, 0), snackId, "Normal", 1, 1)
	positionSnackOnPlate(model, plate, 1)
	model:SetAttribute("WorldId", uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("GrowthStage", 1)
	activeSnacks[uid] = {
		Player = player,
		Plate = plate,
		Model = model,
		SnackId = snackId,
		PlantedAt = os.clock(),
		PlantedAtUnix = os.time(),
		GrowTime = growTime,
		Stage = 1,
		VisualMaxSize = model:GetAttribute("SnackCurrentMaxSize") or 0,
		ReadyNotified = false,
	}
	upsertPlantedRecord(data, {
		UniqueId = uid,
		SnackId = snackId,
		PlateName = plate.Name,
		PlateId = getPlateNumber(plate),
		PlantedAt = os.time(),
		GrowTime = growTime,
		CurrentStage = 1,
	})
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.StatsService.Record(player, "SnacksPlanted", 1)
	context.Services.QuestService.Record(player, "Plant", 1)
	context.Services.TutorialService.RecordAction(player, "Plant")
	context.Services.EconomyService.Sync(player)
	fireEffect(player, "Plant", model, growthEffectPayload(plate, model, snackId, 1))
	playAudioForPlayer(player, "Planting.PlantSeed", "World", model)
	context.Services.EconomyService.Notify(player, "You planted " .. snack.DisplayName .. "!")
	context.Services.AnalyticsService.SnackPlanted(player, snackId)
	return true
end

function SnackService.GrowthTick()
	for uid, record in pairs(activeSnacks) do
		if record.Model and record.Model.Parent and record.Plate and record.Plate.Parent then
			local progress = math.clamp((os.clock() - record.PlantedAt) / record.GrowTime, 0, 1)
			local stage = 1
			if progress >= 1 then
				stage = 3
			elseif progress >= 0.4 then
				stage = 2
			end
			if stage ~= record.Stage then
				record.Stage = stage
				record.Plate:SetAttribute("GrowthStage", stage)
				local data = record.Player and SnackService.Context.Services.ProfileServiceWrapper.GetData(record.Player)
				local planted = data and findPlantedRecord(data, uid)
				if planted then
					planted.CurrentStage = stage
					SnackService.Context.Services.ProfileServiceWrapper.MarkDirty(record.Player)
				end
				record.VisualMaxSize = applySnackModelSize(record.Model, record.SnackId, "Normal", stage, 1)
				positionSnackOnPlate(record.Model, record.Plate, stage)
				record.Model:SetAttribute("GrowthStage", stage)
				local snack = getSnackConfig(record.SnackId)
				fireEffect(record.Player, stage >= 3 and "GrowthReady" or "GrowthStage", record.Model, growthEffectPayload(record.Plate, record.Model, record.SnackId, stage))
				playAudioForPlayer(record.Player, stage >= 3 and "Planting.Ready" or "Planting.GrowthStage", "World", record.Model, { MinInterval = 0.3 })
				if stage >= 3 then
					setPlatePrompt(record.Plate, "Harvest", true)
					if not record.ReadyNotified then
						record.ReadyNotified = true
						SnackService.Context.Services.EconomyService.Notify(record.Player, (snack and snack.DisplayName or "Snack") .. " is ready to harvest.")
					end
				end
			end
		else
			activeSnacks[uid] = nil
		end
	end
end

function SnackService.RollMutation()
	local context = SnackService.Context
	local mutations = context.Config.MutationConfig
	local total = 0
	local weighted = {}
	for mutationId, config in pairs(mutations) do
		if type(config) == "table" and config.Weight then
			local weight = config.Weight * context.Services.EventService.GetMutationWeightMultiplier(mutationId)
			total += weight
			table.insert(weighted, { Id = mutationId, Weight = weight })
		end
	end
	local roll = math.random() * total
	local cursor = 0
	for _, entry in ipairs(weighted) do
		cursor += entry.Weight
		if roll <= cursor then
			return entry.Id
		end
	end
	return "Normal"
end

function SnackService.HarvestSnack(player, plate)
	local context = SnackService.Context
	if plate == nil then
		plate = getNearestPlate(player, function(candidate)
			local uid = candidate:GetAttribute("SnackUid")
			local record = uid and activeSnacks[uid]
			return record and record.Stage >= 3
		end)
	end
	local validPlate = context.Services.ValidationService.ValidateWorldObject(plate, "BasePart")
	if not validPlate then
		context.Services.EconomyService.Notify(player, "Stand near a grown snack to harvest.")
		return false
	end
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can harvest here.")
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, plate, distanceValue("Harvest", 12)) then
		context.Services.EconomyService.Notify(player, "Move closer to harvest.")
		return false
	end
	local uid = plate:GetAttribute("SnackUid")
	local record = uid and activeSnacks[uid]
	if not record or record.Stage < 3 then
		context.Services.EconomyService.Notify(player, "This snack is not ready yet.")
		return false
	end
	if not context.Services.InventoryService.CanAddItem(player) then
		context.Services.EconomyService.Notify(player, "Inventory full. Sell, feed, or display a snack before harvesting.")
		return false
	end
	local mutationId = SnackService.RollMutation()
	local mutation = getMutationConfig(mutationId)
	local item = {
		UniqueId = HttpService:GenerateGUID(false),
		SnackId = record.SnackId,
		MutationId = mutationId,
		CreatedAt = os.time(),
		ValueMultiplier = mutation.ValueMultiplier,
		DisplayName = itemDisplayName(record.SnackId, mutationId),
		Locked = false,
	}
	local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
	item.EstimatedSellValue = sellValue
	item.EstimatedVoidValue = voidValue
	item.PassiveIncome = passiveIncome
	local snackConfig = context.Config.SnackConfig[item.SnackId]
	local isRareHarvest = rareHarvestMutations[item.MutationId] == true
		or (snackConfig and context.Config.RarityConfig.IsAtLeast(snackConfig.Rarity or "Common", "Rare"))
	fireEffect(player, isRareHarvest and "Harvest.Rare" or "Harvest.Normal", plate, {
		SnackId = item.SnackId,
		MutationId = item.MutationId,
		DisplayName = item.DisplayName,
		Rarity = snackConfig and snackConfig.Rarity or "Common",
		IsRare = isRareHarvest,
		Text = "+" .. tostring(sellValue) .. " value",
	})
	local addedItem = context.Services.InventoryService.AddItem(player, item)
	if not addedItem then
		context.Services.EconomyService.Notify(player, "Inventory full. Harvest cancelled safely.")
		return false
	end
	playAudioForPlayer(player, harvestSoundKey(context, item), "World", plate)
	context.Services.CollectionService.MarkHarvest(player, item)
	context.Services.StatsService.Record(player, "SnacksHarvested", 1)
	context.Services.StatsService.RecordSnackValue(player, math.max(sellValue, voidValue))
	context.Services.BadgeAwardService.Award(player, "FirstSnackHarvested")
	context.Services.QuestService.Record(player, "Harvest", 1)
	context.Services.TutorialService.RecordAction(player, "Harvest")
	if record.Model then
		record.Model:Destroy()
	end
	clearPlate(plate)
	activeSnacks[uid] = nil
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if data then
		removePlantedRecord(data, uid)
		context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
	context.Services.EconomyService.Notify(player, "You harvested " .. item.DisplayName .. "!")
	if context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.RareHarvest(player, item)
	end
	context.Services.AnalyticsService.SnackHarvested(player, item)
	return true
end

function SnackService.SellSnack(player, itemId)
	local context = SnackService.Context
	local station = context.Services.PlotService.GetStation(player, "SellStation")
	if station and not context.Services.ValidationService.ValidateDistance(player, station, distanceValue("Shop", 18)) then
		context.Services.EconomyService.Notify(player, "Stand near your Sell Station to sell.")
		return false
	end
	local okItem, _, _, itemError = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, itemError == "Locked" and "Unlock this item before using it." or "Select a snack to sell.")
		return false
	end
	local item, removeError = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, removeError == "Locked" and "Unlock this item before using it." or "That item is no longer in your inventory.")
		return false
	end
	local value = select(1, context.Services.EconomyService.ComputeItemValues(player, item))
	context.Services.EconomyService.AddCoins(player, value)
	fireEffect(player, "Sell", station, {
		Text = "+" .. tostring(value) .. " coins",
	})
	playAudioForPlayer(player, "Economy.Sell", "World", station)
	context.Services.StatsService.Record(player, "SnacksSold", 1)
	context.Services.QuestService.Record(player, "Sell", 1)
	context.Services.TutorialService.RecordAction(player, "Sell")
	context.Services.EconomyService.Notify(player, "Sold " .. item.DisplayName .. " for " .. tostring(value) .. " coins.")
	context.Services.AnalyticsService.SnackSold(player, item, value)
	return true
end

function SnackService.FeedVoid(player, itemId)
	local context = SnackService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local feedStation = world and world:FindFirstChild("CentralVoid") and world.CentralVoid:FindFirstChild("FeedStation")
	if feedStation and not context.Services.ValidationService.ValidateDistance(player, feedStation, distanceValue("VoidFeed", 25)) then
		context.Services.EconomyService.Notify(player, "Stand near THE VOID to feed it.")
		return false
	end
	local okItem, _, _, itemError = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, itemError == "Locked" and "Unlock this item before using it." or "Select a snack to feed.")
		return false
	end
	local item, removeError = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, removeError == "Locked" and "Unlock this item before using it." or "That item is no longer in your inventory.")
		return false
	end
	local _, voidValue = context.Services.EconomyService.ComputeItemValues(player, item)
	local golden = context.Services.EventService.GetGoldenHungerSnackId()
	if golden and item.SnackId == golden then
		local config = context.Config.EventConfig.GoldenHunger
		voidValue = math.floor(voidValue * config.VoidValueMultiplier) + config.HungerBonus
		context.Services.EconomyService.AddVoidTokens(player, config.TokenBonus)
		context.Services.EconomyService.Notify(player, "Golden Hunger match! The Void wanted that snack.")
	end
	item.EstimatedVoidValue = voidValue
	local tokenReward = math.max(1, math.floor(voidValue / 10))
	context.Services.EconomyService.AddVoidTokens(player, tokenReward)
	context.Services.VoidService.AddHunger(player, voidValue, item)
	if context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.RareFeed(player, item)
	end
	context.Services.StatsService.Record(player, "SnacksFed", 1)
	if (context.Services.StatsService.Serialize(player).SnacksFed or 0) >= 100 then
		context.Services.BadgeAwardService.Award(player, "HundredSnacksFed")
	end
	context.Services.BadgeAwardService.Award(player, "FirstVoidFeed")
	context.Services.QuestService.Record(player, "FeedVoid", 1)
	context.Services.TutorialService.RecordAction(player, "FeedVoid")
	local voidTarget = feedStation or (world and world:FindFirstChild("CentralVoid") and world.CentralVoid:FindFirstChild("VoidCore"))
	local fedSnackConfig = context.Config.SnackConfig[item.SnackId]
	local isRareFeed = rareHarvestMutations[item.MutationId] == true
		or (fedSnackConfig and context.Config.RarityConfig.IsAtLeast(fedSnackConfig.Rarity or "Common", "Rare"))
	fireEffectAll(isRareFeed and "Void.FeedRare" or "Void.Feed", voidTarget, {
		Player = player,
		SnackId = item.SnackId,
		MutationId = item.MutationId,
		IsRare = isRareFeed,
		VoidValue = voidValue,
		Text = "+" .. tostring(tokenReward) .. " Void Tokens",
	})
	playAudioForAll("Void.Feed", "World", voidTarget, { MinInterval = 0.25 })
	context.Services.EconomyService.Notify(player, "You fed the Void! +" .. tostring(tokenReward) .. " Void Tokens.")
	context.Services.AnalyticsService.SnackFed(player, item, voidValue)
	return true
end

function SnackService.DisplaySnack(player, itemId, shelf)
	local context = SnackService.Context
	local plot = context.Services.PlotService.GetPlot(player)
	local shelfPart = shelf or (plot and plot:FindFirstChild("DisplayShelf"))
	if not shelfPart or not plot then
		context.Services.EconomyService.Notify(player, "Display shelf missing.")
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, shelfPart, distanceValue("Display", 15)) then
		context.Services.EconomyService.Notify(player, "Stand near your Display Shelf to display.")
		return false
	end
	if not context.Services.InventoryService.CanDisplayItem(player) then
		context.Services.EconomyService.Notify(player, "Display shelf full for this private test.")
		return false
	end
	local okItem, _, _, itemError = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, itemError == "Locked" and "Unlock this item before using it." or "Select a snack to display.")
		return false
	end
	local item, removeError = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, removeError == "Locked" and "Unlock this item before using it." or "That item is no longer in your inventory.")
		return false
	end
	local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
	item.EstimatedSellValue = sellValue
	item.EstimatedVoidValue = voidValue
	item.PassiveIncome = passiveIncome
	item.WorldId = item.WorldId or HttpService:GenerateGUID(false)
	local position = displaySlotPosition(plot, shelfPart)
	local model = createSnackModel("Displayed_" .. item.WorldId, position, item.SnackId, item.MutationId, 3, 0.9)
	model:SetAttribute("WorldId", item.WorldId)
	model:SetAttribute("Displayed", true)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("DisplayValue", sellValue)
	model:SetAttribute("PassiveIncome", passiveIncome)
	model:SetAttribute("DisplayName", item.DisplayName)
	addDisplayLabel(model, item.DisplayName, passiveIncome)
	displayedByWorldId[item.WorldId] = model
	fireEffect(player, "Display", model, {
		SnackId = item.SnackId,
		MutationId = item.MutationId,
		DisplayName = item.DisplayName,
		Text = "+" .. tostring(passiveIncome) .. " coins/tick",
	})
	local displayedItem = context.Services.InventoryService.AddDisplayed(player, item)
	if not displayedItem then
		if model then
			model:Destroy()
		end
		displayedByWorldId[item.WorldId] = nil
		context.Services.InventoryService.AddItem(player, item)
		context.Services.EconomyService.Notify(player, "Display cancelled safely.")
		return false
	end
	playAudioForPlayer(player, "Display.Place", "World", model)
	context.Services.QuestService.Record(player, "Display", 1)
	context.Services.TutorialService.RecordAction(player, "Display")
	if context.Services.PhantomSnackService then
		context.Services.PhantomSnackService.TryTriggerFromDisplay(player, item)
	end
	context.Services.EconomyService.Notify(player, "Displayed " .. item.DisplayName .. ". It now earns passive coins.")
	context.Services.AnalyticsService.SnackDisplayed(player, item)
	return true
end

function SnackService.RestorePlanted(player)
	local context = SnackService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local plot = context.Services.PlotService.GetPlot(player)
	if not data or not plot then
		return
	end
	local restoredReady = 0
	local offlineGrowthEnabled = (context.Config.FeatureFlags or {}).OfflineGrowth ~= false
	local offlineCap = tonumber(context.Config.GameConfig.OfflineGrowthMaxSeconds) or 0
	local now = os.time()
	local restoreCap = math.min(context.Services.UpgradeService.GetPlateCount(player), limitValue("MaxActiveSnacksPerPlayer", 10))
	local restoredCount = 0
	for index = #getPlantedRecords(data), 1, -1 do
		local record = data.PlantedSnacks[index]
		local snack = record and context.Config.SnackConfig[record.SnackId]
		local plate = record and plateForRecord(plot, record)
		if not snack or not plate or getPlateNumber(plate) > context.Services.UpgradeService.GetPlateCount(player) or restoredCount >= restoreCap then
			table.remove(data.PlantedSnacks, index)
		elseif not activeSnacks[record.UniqueId] then
			local elapsed = offlineGrowthEnabled and math.max(0, now - (tonumber(record.PlantedAt) or now)) or 0
			if offlineGrowthEnabled and offlineCap > 0 then
				elapsed = math.min(elapsed, offlineCap)
			end
			local growTime = math.max(1, tonumber(record.GrowTime) or snack.GrowTime or 30)
			local stage = stageForElapsed(elapsed, growTime)
			record.CurrentStage = stage
			plate:SetAttribute("Occupied", true)
			plate:SetAttribute("SnackUid", record.UniqueId)
			plate:SetAttribute("SnackId", record.SnackId)
			plate:SetAttribute("GrowthStage", stage)
			setPlatePrompt(plate, stage >= 3 and "Harvest" or "Growing...", stage >= 3)
			local model = createSnackModel("Growing_" .. record.UniqueId, plate.Position + Vector3.new(0, 1.15, 0), record.SnackId, "Normal", stage, 1)
			positionSnackOnPlate(model, plate, stage)
			model:SetAttribute("WorldId", record.UniqueId)
			model:SetAttribute("OwnerUserId", player.UserId)
			model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			model:SetAttribute("GrowthStage", stage)
			activeSnacks[record.UniqueId] = {
				Player = player,
				Plate = plate,
				Model = model,
				SnackId = record.SnackId,
				PlantedAt = os.clock() - math.min(elapsed, growTime),
				PlantedAtUnix = tonumber(record.PlantedAt) or now,
				GrowTime = growTime,
				Stage = stage,
				VisualMaxSize = model:GetAttribute("SnackCurrentMaxSize") or 0,
				ReadyNotified = stage >= 3,
			}
			restoredCount += 1
			if stage >= 3 then
				restoredReady += 1
			end
		end
	end
	if restoredReady > 0 then
		context.Services.EconomyService.Notify(player, tostring(restoredReady) .. " snack grew while you were away.")
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
end

function SnackService.ApplyOfflineDisplayIncome(player)
	local context = SnackService.Context
	if (context.Config.FeatureFlags or {}).OfflineDisplayIncome == false then
		return 0
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return 0
	end
	local logout = tonumber(data.LastLogout) or 0
	if logout <= 0 or #((data.DisplayedSnacks) or {}) <= 0 then
		return 0
	end
	local elapsed = math.max(0, os.time() - logout)
	local cap = tonumber(context.Config.GameConfig.OfflineIncomeMaxSeconds) or 0
	if cap > 0 then
		elapsed = math.min(elapsed, cap)
	end
	local interval = math.max(1, tonumber(context.Config.GameConfig.BaseDisplayIncomeInterval) or 10)
	local ticks = math.floor(elapsed / interval)
	if ticks <= 0 then
		return 0
	end
	local total = 0
	for _, item in ipairs(data.DisplayedSnacks or {}) do
		total += context.Services.EconomyService.GetPassiveIncome(player, item) * ticks
	end
	total = math.floor(total * 0.35)
	if total > 0 then
		data.Coins = (data.Coins or 0) + total
		data.LastOfflineRewards = {
			Coins = total,
			ElapsedSeconds = elapsed,
			Source = "DisplayedSnacks",
		}
		context.Services.StatsService.RecordCoinsEarned(player, total)
		context.Services.ProfileServiceWrapper.MarkDirty(player)
		context.Services.EconomyService.Notify(player, "Your displayed snacks earned +" .. tostring(total) .. " coins while you were away.")
	end
	return total
end

function SnackService.RestoreDisplayed(player)
	local context = SnackService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local plot = context.Services.PlotService.GetPlot(player)
	local shelfPart = plot and plot:FindFirstChild("DisplayShelf")
	if not data or not plot or not shelfPart then
		return
	end
	for _, item in ipairs(data.DisplayedSnacks or {}) do
		if item and item.SnackId and context.Config.SnackConfig[item.SnackId] then
			item.WorldId = item.WorldId or HttpService:GenerateGUID(false)
			if not displayedByWorldId[item.WorldId] then
				local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
				item.EstimatedSellValue = sellValue
				item.EstimatedVoidValue = voidValue
				item.PassiveIncome = passiveIncome
				local model = createSnackModel("Displayed_" .. item.WorldId, displaySlotPosition(plot, shelfPart), item.SnackId, item.MutationId, 3, 0.9)
				model:SetAttribute("WorldId", item.WorldId)
				model:SetAttribute("Displayed", true)
				model:SetAttribute("OwnerUserId", player.UserId)
				model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
				model:SetAttribute("DisplayValue", sellValue)
				model:SetAttribute("PassiveIncome", passiveIncome)
				model:SetAttribute("DisplayName", item.DisplayName)
				addDisplayLabel(model, item.DisplayName, passiveIncome)
				displayedByWorldId[item.WorldId] = model
			end
		else
			warn("[FEED THE VOID] Skipped malformed displayed snack during restore.")
		end
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
end

function SnackService.ClearPlotVisuals(player, clearPlanted)
	for uid, record in pairs(activeSnacks) do
		if record.Player == player then
			if record.Model then
				record.Model:Destroy()
			end
			clearPlate(record.Plate)
			activeSnacks[uid] = nil
		end
	end
	for worldId, model in pairs(displayedByWorldId) do
		if model and tonumber(model:GetAttribute("OwnerUserId")) == player.UserId then
			model:Destroy()
			displayedByWorldId[worldId] = nil
		end
	end
	if clearPlanted then
		local data = SnackService.Context.Services.ProfileServiceWrapper.GetData(player)
		if data then
			data.PlantedSnacks = {}
			SnackService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
		end
	end
end

function SnackService.GetDisplayedModels()
	return displayedByWorldId
end

function SnackService.GetActiveSnackCount(player)
	if player then
		return countActiveSnacksForPlayer(player)
	end
	local count = 0
	for _, record in pairs(activeSnacks) do
		if record.Model and record.Model.Parent then
			count += 1
		end
	end
	return count
end

function SnackService.GetPlantStatus(player)
	local data = player and SnackService.Context.Services.ProfileServiceWrapper.GetData(player)
	return {
		Player = player and player.Name or "server",
		Active = player and countActiveSnacksForPlayer(player) or SnackService.GetActiveSnackCount(),
		DisplayedWorld = player and countDisplayedForPlayer(player) or 0,
		SavedPlanted = data and #(data.PlantedSnacks or {}) or 0,
		SavedDisplayed = data and #(data.DisplayedSnacks or {}) or 0,
		OwnedPlates = player and SnackService.Context.Services.UpgradeService.GetPlateCount(player) or 0,
		ActiveCap = limitValue("MaxActiveSnacksPerPlayer", 10),
		DisplayCap = SnackService.Context.Services.InventoryService.GetDisplayedCap(),
	}
end

function SnackService.PrintPlantStatus(player)
	local status = SnackService.GetPlantStatus(player)
	local line = string.format(
		"[FEED THE VOID][Plants] %s active=%d saved=%d displayedWorld=%d savedDisplayed=%d plates=%d cap=%d displayCap=%d",
		status.Player,
		status.Active,
		status.SavedPlanted,
		status.DisplayedWorld,
		status.SavedDisplayed,
		status.OwnedPlates,
		status.ActiveCap,
		status.DisplayCap
	)
	print(line)
	if player then
		SnackService.Context.Services.EconomyService.Notify(player, "Plants: " .. tostring(status.Active) .. "/" .. tostring(status.OwnedPlates) .. " | Display: " .. tostring(status.SavedDisplayed) .. "/" .. tostring(status.DisplayCap))
	end
	return status
end

function SnackService.PayDisplayIncome()
	local context = SnackService.Context
	for worldId, model in pairs(displayedByWorldId) do
		if not model or not model.Parent then
			displayedByWorldId[worldId] = nil
		else
			local owner = Players:GetPlayerByUserId(tonumber(model:GetAttribute("OwnerUserId")) or 0)
			if owner then
				local income = math.max(1, math.floor(tonumber(model:GetAttribute("PassiveIncome")) or ((tonumber(model:GetAttribute("DisplayValue")) or 10) / 10)))
				context.Services.EconomyService.AddCoins(owner, income)
				local last = passiveNotifyAt[owner] or 0
				if os.clock() - last > 28 then
					passiveNotifyAt[owner] = os.clock()
					context.Services.EconomyService.Notify(owner, "Displayed snacks earned +" .. tostring(income) .. " coins.")
					if context.Services.AudioService then
						context.Services.AudioService.PlayUI(owner, "Economy.PassiveTick", { MinInterval = 25 })
					end
					if context.Services.VFXService then
						context.Services.VFXService.PlayForPlayer(owner, "Economy.PassiveTick", {
							Mode = "UI",
							Text = "Display income +" .. tostring(income),
							MinInterval = 25,
						})
					end
				end
			end
		end
	end
end

return SnackService
