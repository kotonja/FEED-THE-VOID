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

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function snackFolder()
	return getWorld():WaitForChild("ActiveSnacks")
end

local function getSnackConfig(snackId)
	return SnackService.Context.Config.SnackConfig[snackId]
end

local function getMutationConfig(mutationId)
	return SnackService.Context.Config.MutationConfig[mutationId or "Normal"]
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
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 9
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
	local stageScale = ({ 0.45, 0.75, 1 })[stage or 3] or 1
	local mutationScale = mutation and mutation.ScaleMultiplier or 1
	context.Services.AssetService.ScaleModelSafely(model, stageScale * mutationScale * (displayScale or 1))
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(position))
	context.Services.AssetService.ApplyMutationVisual(model, mutationId, snack and snack.Color)
	model:SetAttribute("SnackId", snackId)
	model:SetAttribute("MutationId", mutationId or "Growing")
	return model
end

local function addDisplayLabel(model, text, passiveIncome)
	SnackService.Context.Services.AssetService.AddBillboard(model, text .. "\n+" .. tostring(passiveIncome) .. " coins/tick", Vector3.new(0, 2.8, 0))
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
		context.Services.EconomyService.Notify(player, "Stand near an empty plate to plant.")
		return false
	end
	if getPlateNumber(plate) > context.Services.UpgradeService.GetPlateCount(player) then
		context.Services.EconomyService.Notify(player, "Buy Extra Plate to use this plate.")
		return false
	end
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can plant here.")
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, plate, 18) then
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
	data.Seeds[snackId] -= 1
	local uid = HttpService:GenerateGUID(false)
	plate:SetAttribute("Occupied", true)
	plate:SetAttribute("SnackUid", uid)
	plate:SetAttribute("SnackId", snackId)
	plate:SetAttribute("GrowthStage", 1)
	setPlatePrompt(plate, "Growing...", false)

	local model = createSnackModel("Growing_" .. uid, plate.Position + Vector3.new(0, 1.5, 0), snackId, "Normal", 1, 1)
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
		GrowTime = context.Config.GameConfig.DebugFastGrowth and context.Config.GameConfig.FastGrowthTime or (snack.GrowTime / math.max(0.1, context.Services.UpgradeService.GetMultiplier(player, "GrowSpeed"))),
		Stage = 1,
	}
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.StatsService.Record(player, "SnacksPlanted", 1)
	context.Services.QuestService.Record(player, "Plant", 1)
	context.Services.TutorialService.RecordAction(player, "Plant")
	context.Services.EconomyService.Sync(player)
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
			elseif progress >= 0.5 then
				stage = 2
			end
			if stage ~= record.Stage then
				record.Stage = stage
				record.Plate:SetAttribute("GrowthStage", stage)
				record.Model:SetAttribute("GrowthStage", stage)
				SnackService.Context.Services.AssetService.SetModelCFrame(record.Model, CFrame.new(record.Plate.Position + Vector3.new(0, 1.5 + stage * 0.25, 0)))
				if stage >= 3 then
					setPlatePrompt(record.Plate, "Harvest", true)
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
	if not context.Services.ValidationService.ValidateDistance(player, plate, 18) then
		context.Services.EconomyService.Notify(player, "Move closer to harvest.")
		return false
	end
	local uid = plate:GetAttribute("SnackUid")
	local record = uid and activeSnacks[uid]
	if not record or record.Stage < 3 then
		context.Services.EconomyService.Notify(player, "This snack is not ready yet.")
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
	}
	local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
	item.EstimatedSellValue = sellValue
	item.EstimatedVoidValue = voidValue
	item.PassiveIncome = passiveIncome
	context.Services.InventoryService.AddItem(player, item)
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
	if station and not context.Services.ValidationService.ValidateDistance(player, station, 24) then
		context.Services.EconomyService.Notify(player, "Stand near your Sell Station to sell.")
		return false
	end
	local okItem = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, "Select a snack to sell.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	local value = select(1, context.Services.EconomyService.ComputeItemValues(player, item))
	context.Services.EconomyService.AddCoins(player, value)
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
	if feedStation and not context.Services.ValidationService.ValidateDistance(player, feedStation, 28) then
		context.Services.EconomyService.Notify(player, "Stand near THE VOID to feed it.")
		return false
	end
	local okItem = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, "Select a snack to feed.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
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
	context.Services.StatsService.Record(player, "SnacksFed", 1)
	if (context.Services.StatsService.Serialize(player).SnacksFed or 0) >= 100 then
		context.Services.BadgeAwardService.Award(player, "HundredSnacksFed")
	end
	context.Services.BadgeAwardService.Award(player, "FirstVoidFeed")
	context.Services.QuestService.Record(player, "FeedVoid", 1)
	context.Services.TutorialService.RecordAction(player, "FeedVoid")
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
	if not context.Services.ValidationService.ValidateDistance(player, shelfPart, 24) then
		context.Services.EconomyService.Notify(player, "Stand near your Display Shelf to display.")
		return false
	end
	local okItem = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, "Select a snack to display.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
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
	model:SetAttribute("DisplayName", item.DisplayName)
	addDisplayLabel(model, item.DisplayName, passiveIncome)
	displayedByWorldId[item.WorldId] = model
	context.Services.InventoryService.AddDisplayed(player, item)
	context.Services.QuestService.Record(player, "Display", 1)
	context.Services.TutorialService.RecordAction(player, "Display")
	if context.Services.PhantomSnackService then
		context.Services.PhantomSnackService.TryTriggerFromDisplay(player, item)
	end
	context.Services.EconomyService.Notify(player, "Displayed " .. item.DisplayName .. ". It now earns passive coins.")
	context.Services.AnalyticsService.SnackDisplayed(player, item)
	return true
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

function SnackService.ClearPlotVisuals(player)
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
end

function SnackService.GetDisplayedModels()
	return displayedByWorldId
end

function SnackService.PayDisplayIncome()
	local context = SnackService.Context
	for worldId, model in pairs(displayedByWorldId) do
		if not model or not model.Parent then
			displayedByWorldId[worldId] = nil
		else
			local owner = Players:GetPlayerByUserId(tonumber(model:GetAttribute("OwnerUserId")) or 0)
			if owner then
				local income = math.max(1, math.floor((tonumber(model:GetAttribute("DisplayValue")) or 10) / 10))
				context.Services.EconomyService.AddCoins(owner, income)
				local last = passiveNotifyAt[owner] or 0
				if os.clock() - last > 28 then
					passiveNotifyAt[owner] = os.clock()
					context.Services.EconomyService.Notify(owner, "Displayed snacks earned +" .. tostring(income) .. " coins.")
				end
			end
		end
	end
end

return SnackService
