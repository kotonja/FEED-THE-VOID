local UpgradeService = {}

local upgradeKeys = {
	ExtraPlate = "Plates",
	GrowSpeed = "GrowSpeed",
	SellMultiplier = "SellMultiplier",
	VoidRewardMultiplier = "VoidRewardMultiplier",
	DisplayIncome = "DisplayIncome",
	VoidmiteReward = "VoidmiteReward",
}

function UpgradeService.Init(context)
	UpgradeService.Context = context
end

function UpgradeService.Start() end

local function rawUpgradeData(player)
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return nil, {}
	end
	data.Upgrades = data.Upgrades or {}
	return data, data.Upgrades
end

function UpgradeService.GetDefinition(upgradeId)
	return UpgradeService.Context.Config.GameConfig.UpgradeConfig[upgradeId]
end

function UpgradeService.GetLevel(player, upgradeId)
	local data, upgrades = rawUpgradeData(player)
	if not data then
		return 0
	end
	if upgradeId == "ExtraPlate" then
		return math.max(0, (tonumber(upgrades.Plates) or UpgradeService.Context.Config.GameConfig.PlateCount) - UpgradeService.Context.Config.GameConfig.PlateCount)
	end
	return math.max(0, tonumber(upgrades[upgradeKeys[upgradeId] or upgradeId]) or 0)
end

function UpgradeService.GetPlateCount(player)
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	local count = data and data.Upgrades and tonumber(data.Upgrades.Plates) or UpgradeService.Context.Config.GameConfig.PlateCount
	return math.clamp(count, UpgradeService.Context.Config.GameConfig.PlateCount, UpgradeService.Context.Config.GameConfig.MaxPlateCount)
end

function UpgradeService.GetMultiplier(player, upgradeId)
	local definition = UpgradeService.GetDefinition(upgradeId)
	local level = UpgradeService.GetLevel(player, upgradeId)
	local rebirthBoost = 1
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	if upgradeId == "SellMultiplier" or upgradeId == "VoidRewardMultiplier" or upgradeId == "DisplayIncome" then
		rebirthBoost = 1 + ((data and tonumber(data.Rebirths) or 0) * UpgradeService.Context.Config.GameConfig.RebirthBoostPerRebirth)
	end
	if not definition then
		return rebirthBoost
	end
	return rebirthBoost * (1 + (level * (definition.PerLevel or 0)))
end

function UpgradeService.GetCost(player, upgradeId)
	local definition = UpgradeService.GetDefinition(upgradeId)
	if not definition then
		return 0
	end
	local level = UpgradeService.GetLevel(player, upgradeId)
	return math.floor(definition.BaseCost * ((level + 1) ^ 2))
end

function UpgradeService.Serialize(player)
	local config = UpgradeService.Context.Config.GameConfig
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	local upgrades = data and data.Upgrades or {}
	local result = {
		Plates = UpgradeService.GetPlateCount(player),
		GrowSpeed = tonumber(upgrades.GrowSpeed) or 0,
		SellMultiplier = tonumber(upgrades.SellMultiplier) or 0,
		VoidRewardMultiplier = tonumber(upgrades.VoidRewardMultiplier) or 0,
		DisplayIncome = tonumber(upgrades.DisplayIncome) or 0,
		VoidmiteReward = tonumber(upgrades.VoidmiteReward) or 0,
		Items = {},
	}
	for _, upgradeId in ipairs(config.UpgradeOrder) do
		local definition = config.UpgradeConfig[upgradeId]
		local level = UpgradeService.GetLevel(player, upgradeId)
		table.insert(result.Items, {
			Id = upgradeId,
			DisplayName = definition.DisplayName,
			Description = definition.Description,
			Level = level,
			MaxLevel = definition.MaxLevel,
			Cost = UpgradeService.GetCost(player, upgradeId),
			Multiplier = UpgradeService.GetMultiplier(player, upgradeId),
		})
	end
	return result
end

function UpgradeService.BuyUpgrade(player, upgradeId)
	local context = UpgradeService.Context
	local definition = UpgradeService.GetDefinition(upgradeId)
	if not definition then
		context.Services.EconomyService.Notify(player, "That upgrade is not available.")
		return false
	end
	local data, upgrades = rawUpgradeData(player)
	if not data then
		return false
	end
	local level = UpgradeService.GetLevel(player, upgradeId)
	if level >= definition.MaxLevel then
		context.Services.EconomyService.Notify(player, definition.DisplayName .. " is max level.")
		return false
	end
	local cost = UpgradeService.GetCost(player, upgradeId)
	if not context.Services.EconomyService.SpendCoins(player, cost) then
		context.Services.EconomyService.Notify(player, "Not enough coins for " .. definition.DisplayName .. ".")
		return false
	end
	if upgradeId == "ExtraPlate" then
		upgrades.Plates = math.min(context.Config.GameConfig.MaxPlateCount, UpgradeService.GetPlateCount(player) + 1)
	else
		upgrades[upgradeKeys[upgradeId] or upgradeId] = level + 1
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.QuestService.Record(player, "BuyUpgrade", 1)
	context.Services.EconomyService.Notify(player, "Upgrade bought: " .. definition.DisplayName .. "!")
	context.Services.EconomyService.Sync(player)
	return true
end

return UpgradeService
