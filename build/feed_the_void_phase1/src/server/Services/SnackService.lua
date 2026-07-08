local HttpService = game:GetService("HttpService")

local SnackService = {}

local activeSnacks = {}
local displayedByWorldId = {}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function snackFolder()
	return getWorld():WaitForChild("ActiveSnacks")
end

local function getSnackPart(model)
	return model and model:FindFirstChild("SnackPart")
end

local function setPrompt(plate, actionText)
	local prompt = plate and plate:FindFirstChild("PlatePrompt")
	if prompt then
		prompt.ActionText = actionText
	end
end

local function createSnackVisual(name, position, snackId, mutationId, scale, color)
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "SnackPart"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = Vector3.new(2.5, 2.5, 2.5) * scale
	part.Position = position
	part.Parent = model
	model.PrimaryPart = part
	model:SetAttribute("SnackId", snackId)
	model:SetAttribute("MutationId", mutationId or "Growing")
	model.Parent = snackFolder()
	return model
end

local function getSnackConfig(snackId)
	return SnackService.Context.Config.SnackConfig[snackId]
end

local function getMutationConfig(mutationId)
	return SnackService.Context.Config.MutationConfig[mutationId]
end

local function itemDisplayName(snackId, mutationId)
	local snack = getSnackConfig(snackId)
	if mutationId == "Normal" then
		return snack.DisplayName
	end
	return mutationId .. " " .. snack.DisplayName
end

local function displayValue(item)
	local snack = getSnackConfig(item.SnackId)
	local rarityBonus = ({
		Common = 1,
		Uncommon = 1.4,
		Rare = 2.1,
	})[snack.Rarity] or 1
	return math.floor(snack.BaseSellValue * item.ValueMultiplier * rarityBonus)
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
end

function SnackService.BindWorldPrompts()
	local world = getWorld()
	for _, prompt in ipairs(world:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			if prompt.Name == "PlatePrompt" then
				prompt.Triggered:Connect(function(player)
					local plate = prompt.Parent
					if plate and plate:GetAttribute("Occupied") then
						SnackService.HarvestSnack(player, plate)
					else
						SnackService.PlantSnack(player, plate, "CookieRock")
					end
				end)
			elseif prompt.Name == "SellPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.SellSnack(player)
				end)
			elseif prompt.Name == "FeedPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.FeedVoid(player)
				end)
			elseif prompt.Name == "DisplayPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.DisplaySnack(player, nil, prompt.Parent)
				end)
			elseif prompt.Name == "BuySeedPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.ShopService.BuySeed(player, "CookieRock")
				end)
			end
		end
	end
end

function SnackService.PlantSnack(player, plate, snackId)
	local context = SnackService.Context
	snackId = snackId or "CookieRock"
	local snack = getSnackConfig(snackId)
	if not snack then
		return false
	end
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can plant here.")
		return false
	end
	if not plate or plate:GetAttribute("Occupied") then
		context.Services.EconomyService.Notify(player, "That plate is busy.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data or (data.Seeds[snackId] or 0) <= 0 then
		context.Services.EconomyService.Notify(player, "You need a " .. snack.DisplayName .. " seed.")
		return false
	end

	data.Seeds[snackId] -= 1
	local uid = HttpService:GenerateGUID(false)
	plate:SetAttribute("Occupied", true)
	plate:SetAttribute("SnackUid", uid)
	plate:SetAttribute("SnackId", snackId)
	plate:SetAttribute("GrowthStage", 1)
	setPrompt(plate, "Growing...")

	local model = createSnackVisual("Growing_" .. uid, plate.Position + Vector3.new(0, 1.2, 0), snackId, "Growing", 0.45, snack.Color)
	model:SetAttribute("WorldId", uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("GrowthStage", 1)
	model:SetAttribute("PlatePath", plate:GetFullName())
	activeSnacks[uid] = {
		Player = player,
		Plate = plate,
		Model = model,
		SnackId = snackId,
		PlantedAt = os.clock(),
		GrowTime = snack.GrowTime / math.max(0.1, data.Upgrades.GrowSpeed or 1),
		Stage = 1,
	}
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Planted " .. snack.DisplayName .. ".")
	context.Services.AnalyticsService.SnackPlanted(player, snackId)
	return true
end

function SnackService.GrowthTick()
	for uid, record in pairs(activeSnacks) do
		if record.Model and record.Model.Parent and record.Plate and record.Plate.Parent then
			local progress = math.clamp((os.clock() - record.PlantedAt) / record.GrowTime, 0, 1)
			local stage = math.clamp(math.floor(progress * 3) + 1, 1, 3)
			if progress >= 1 then
				stage = 3
			end
			if stage ~= record.Stage then
				record.Stage = stage
				record.Plate:SetAttribute("GrowthStage", stage)
				record.Model:SetAttribute("GrowthStage", stage)
				local part = getSnackPart(record.Model)
				if part then
					local size = 1.2 + (stage * 1.1)
					part.Size = Vector3.new(size, size, size)
					part.Position = record.Plate.Position + Vector3.new(0, 0.55 + size / 2, 0)
				end
				if stage >= 3 then
					setPrompt(record.Plate, "Harvest Snack")
				end
			end
		else
			activeSnacks[uid] = nil
		end
	end
end

function SnackService.RollMutation()
	local mutations = SnackService.Context.Config.MutationConfig
	local total = 0
	local weighted = {}
	for mutationId, config in pairs(mutations) do
		local weight = config.Weight
		if SnackService.Context.Services.EventService.IsActive("MutationSurge") and mutationId ~= "Normal" then
			weight *= SnackService.Context.Config.EventConfig.MutationSurge.RareWeightMultiplier
		end
		total += weight
		table.insert(weighted, { Id = mutationId, Weight = weight })
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
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can harvest here.")
		return false
	end
	local uid = plate and plate:GetAttribute("SnackUid")
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
	context.Services.InventoryService.AddItem(player, item)
	if record.Model then
		record.Model:Destroy()
	end
	plate:SetAttribute("Occupied", false)
	plate:SetAttribute("SnackUid", "")
	plate:SetAttribute("SnackId", "")
	plate:SetAttribute("GrowthStage", 0)
	setPrompt(plate, "Plant Cookie Rock")
	activeSnacks[uid] = nil
	context.Services.EconomyService.Notify(player, "Harvested " .. item.DisplayName .. ".")
	context.Services.AnalyticsService.SnackHarvested(player, item)
	return true
end

function SnackService.SellSnack(player, itemId)
	local context = SnackService.Context
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, "No snack in inventory to sell.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local snack = getSnackConfig(item.SnackId)
	local value = math.floor(snack.BaseSellValue * item.ValueMultiplier * (data.Upgrades.SellMultiplier or 1))
	context.Services.EconomyService.AddCoins(player, value)
	context.Services.EconomyService.Notify(player, "Sold " .. item.DisplayName .. " for " .. tostring(value) .. " coins.")
	context.Services.AnalyticsService.SnackSold(player, item, value)
	return true
end

function SnackService.FeedVoid(player, itemId)
	local context = SnackService.Context
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, "No snack in inventory to feed.")
		return false
	end
	local snack = getSnackConfig(item.SnackId)
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local value = math.floor(snack.BaseVoidValue * item.ValueMultiplier)
	local tokenReward = math.max(1, math.floor(value / 10 * (data.Upgrades.VoidRewardMultiplier or 1)))
	context.Services.EconomyService.AddVoidTokens(player, tokenReward)
	context.Services.VoidService.AddHunger(player, value)
	context.Services.EconomyService.Notify(player, "Fed " .. item.DisplayName .. " to the Void: +" .. tostring(tokenReward) .. " Void Tokens.")
	context.Services.AnalyticsService.SnackFed(player, item, value)
	return true
end

function SnackService.DisplaySnack(player, itemId, shelf)
	local context = SnackService.Context
	local plot = shelf and context.Services.PlotService.FindPlotFromInstance(shelf) or context.Services.PlotService.GetPlot(player)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can display snacks here.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, "No snack in inventory to display.")
		return false
	end
	local shelfPart = plot and plot:FindFirstChild("DisplayShelf")
	if not shelfPart then
		context.Services.EconomyService.Notify(player, "Display shelf missing.")
		return false
	end
	local mutation = getMutationConfig(item.MutationId)
	local snack = getSnackConfig(item.SnackId)
	local worldId = HttpService:GenerateGUID(false)
	local count = 0
	for _, model in pairs(displayedByWorldId) do
		if model and model:GetAttribute("PlotId") == plot:GetAttribute("PlotId") then
			count += 1
		end
	end
	local offset = Vector3.new(((count % 4) - 1.5) * 2.8, 2.2 + math.floor(count / 4) * 1.2, 0)
	local color = mutation.Color or snack.Color
	local model = createSnackVisual("Displayed_" .. item.SnackId .. "_" .. worldId, shelfPart.Position + offset, item.SnackId, item.MutationId, mutation.ScaleMultiplier or 1, color)
	local value = displayValue(item)
	model:SetAttribute("WorldId", worldId)
	model:SetAttribute("Displayed", true)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("DisplayValue", value)
	model:SetAttribute("DisplayName", item.DisplayName)
	item.WorldId = worldId
	item.DisplayValue = value
	context.Services.InventoryService.AddDisplayed(player, item)
	displayedByWorldId[worldId] = model
	context.Services.EconomyService.Notify(player, "Displayed " .. item.DisplayName .. ". It will earn passive coins and attract Voidmites.")
	context.Services.AnalyticsService.SnackDisplayed(player, item)
	return true
end

function SnackService.PayDisplayIncome()
	local context = SnackService.Context
	for worldId, model in pairs(displayedByWorldId) do
		if not model or not model.Parent then
			displayedByWorldId[worldId] = nil
		else
			local owner = game:GetService("Players"):GetPlayerByUserId(tonumber(model:GetAttribute("OwnerUserId")) or 0)
			if owner then
				local value = tonumber(model:GetAttribute("DisplayValue")) or 10
				local income = math.max(1, math.floor(value * 0.08))
				context.Services.EconomyService.AddCoins(owner, income)
				context.Services.EconomyService.Notify(owner, "Displayed snack income: +" .. tostring(income) .. " coins.")
			end
		end
	end
end

return SnackService
