local SizeConfig = {}

SizeConfig.DefaultTier = "Regular"
SizeConfig.MaxValueMultiplier = 2.8

SizeConfig.Order = {
	"Regular",
	"Chunky",
	"Huge",
	"Massive",
	"Colossal",
	"Voidborn",
}

SizeConfig.Tiers = {
	Regular = {
		DisplayName = "Regular",
		Order = 1,
		Weight = 720,
		Scale = 1,
		WeightMultiplier = 1,
		MinWeightMultiplier = 0.92,
		MaxWeightMultiplier = 1.12,
	},
	Chunky = {
		DisplayName = "Chunky",
		Order = 2,
		Weight = 190,
		Scale = 1.22,
		WeightMultiplier = 1.35,
		MinWeightMultiplier = 1.18,
		MaxWeightMultiplier = 1.58,
	},
	Huge = {
		DisplayName = "Huge",
		Order = 3,
		Weight = 65,
		Scale = 1.55,
		WeightMultiplier = 2.05,
		MinWeightMultiplier = 1.78,
		MaxWeightMultiplier = 2.42,
	},
	Massive = {
		DisplayName = "Massive",
		Order = 4,
		Weight = 20,
		Scale = 2.05,
		WeightMultiplier = 3.4,
		MinWeightMultiplier = 2.85,
		MaxWeightMultiplier = 4.15,
	},
	Colossal = {
		DisplayName = "Colossal",
		Order = 5,
		Weight = 4,
		Scale = 2.85,
		WeightMultiplier = 6.25,
		MinWeightMultiplier = 5.15,
		MaxWeightMultiplier = 7.8,
		Announce = true,
	},
	Voidborn = {
		DisplayName = "Voidborn",
		Order = 6,
		Weight = 1,
		Scale = 3.35,
		WeightMultiplier = 9.5,
		MinWeightMultiplier = 8.1,
		MaxWeightMultiplier = 12,
		Announce = true,
	},
}

function SizeConfig.NormalizeTier(tierId)
	tierId = tostring(tierId or "")
	if SizeConfig.Tiers[tierId] then
		return tierId
	end
	return SizeConfig.DefaultTier
end

function SizeConfig.GetTier(tierId)
	return SizeConfig.Tiers[SizeConfig.NormalizeTier(tierId)]
end

function SizeConfig.GetOrder(tierId)
	local tier = SizeConfig.GetTier(tierId)
	return tier and tier.Order or 1
end

function SizeConfig.RollTier(forcedTier)
	if forcedTier and forcedTier ~= "" then
		return SizeConfig.NormalizeTier(forcedTier)
	end
	local total = 0
	for _, tierId in ipairs(SizeConfig.Order) do
		total += tonumber(SizeConfig.Tiers[tierId].Weight) or 0
	end
	local roll = math.random() * math.max(1, total)
	local cursor = 0
	for _, tierId in ipairs(SizeConfig.Order) do
		cursor += tonumber(SizeConfig.Tiers[tierId].Weight) or 0
		if roll <= cursor then
			return tierId
		end
	end
	return SizeConfig.DefaultTier
end

function SizeConfig.BaseWeight(snack)
	if type(snack) ~= "table" then
		return 1
	end
	local explicit = tonumber(snack.BaseWeight)
	if explicit then
		return explicit
	end
	local value = tonumber(snack.BaseSellValue) or 25
	return math.max(0.5, math.floor((value / 28) * 10 + 0.5) / 10)
end

function SizeConfig.WeightForSnack(snack, tierId)
	local tier = SizeConfig.GetTier(tierId)
	local minMultiplier = tonumber(tier.MinWeightMultiplier) or tier.WeightMultiplier or 1
	local maxMultiplier = tonumber(tier.MaxWeightMultiplier) or tier.WeightMultiplier or minMultiplier
	local randomMultiplier = minMultiplier + ((maxMultiplier - minMultiplier) * math.random())
	local weight = SizeConfig.BaseWeight(snack) * randomMultiplier
	return math.max(0.1, math.floor(weight * 10 + 0.5) / 10)
end

function SizeConfig.GetSizeMultiplier(itemOrTier)
	if type(itemOrTier) == "table" then
		local explicit = tonumber(itemOrTier.SizeMultiplier)
		if explicit then
			return explicit
		end
		return SizeConfig.GetTier(itemOrTier.SizeTier).Scale
	end
	return SizeConfig.GetTier(itemOrTier).Scale
end

function SizeConfig.GetVisualScale(itemOrTier, cap)
	local scale = SizeConfig.GetSizeMultiplier(itemOrTier)
	if cap then
		return math.clamp(scale, 0.75, tonumber(cap) or scale)
	end
	return math.max(0.75, scale)
end

function SizeConfig.GetValueMultiplier(itemOrTier)
	local scale = SizeConfig.GetSizeMultiplier(itemOrTier)
	local valueMultiplier = 1 + ((scale - 1) * 0.6)
	return math.clamp(valueMultiplier, 0.7, SizeConfig.MaxValueMultiplier)
end

function SizeConfig.ApplyToItem(item, snack, defaultTier)
	if type(item) ~= "table" then
		return item
	end
	local tierId = item.SizeTier
	if not tierId or tierId == "" then
		tierId = defaultTier or SizeConfig.DefaultTier
	end
	tierId = SizeConfig.NormalizeTier(tierId)
	item.SizeTier = tierId
	item.SizeMultiplier = tonumber(item.SizeMultiplier) or SizeConfig.GetTier(tierId).Scale
	item.Weight = tonumber(item.Weight) or SizeConfig.WeightForSnack(snack, tierId)
	item.SizeValueMultiplier = SizeConfig.GetValueMultiplier(item)
	return item
end

function SizeConfig.ApplyToPlantedRecord(record, snack, defaultTier)
	if type(record) ~= "table" then
		return record
	end
	local tierId = record.SizeTier
	if not tierId or tierId == "" then
		tierId = defaultTier or SizeConfig.DefaultTier
	end
	tierId = SizeConfig.NormalizeTier(tierId)
	record.SizeTier = tierId
	record.SizeMultiplier = tonumber(record.SizeMultiplier) or SizeConfig.GetTier(tierId).Scale
	record.Weight = tonumber(record.Weight) or SizeConfig.WeightForSnack(snack, tierId)
	record.SizeValueMultiplier = SizeConfig.GetValueMultiplier(record)
	return record
end

function SizeConfig.SizeLabel(item)
	local tierId = type(item) == "table" and item.SizeTier or item
	local tier = SizeConfig.GetTier(tierId)
	if tier.DisplayName == "Regular" then
		return ""
	end
	return tier.DisplayName .. " "
end

function SizeConfig.IsAnnounceTier(tierId)
	local tier = SizeConfig.GetTier(tierId)
	return tier.Announce == true
end

function SizeConfig.ShouldAnnounce(item, snack, rarityConfig)
	if type(item) ~= "table" then
		return false
	end
	if item.SizeTier == "Voidborn" then
		return true
	end
	if item.SizeTier ~= "Colossal" then
		return false
	end
	if not snack or not rarityConfig or not rarityConfig.IsAtLeast then
		return true
	end
	return rarityConfig.IsAtLeast(snack.Rarity or "Common", "Rare")
end

function SizeConfig.FeedEffectKey(item, snack, rarityConfig)
	if type(item) ~= "table" then
		return "Void.FeedNormal"
	end
	if item.SizeTier == "Colossal" or item.SizeTier == "Voidborn" or SizeConfig.GetSizeMultiplier(item) >= 2.7 then
		return "Void.FeedColossal"
	end
	if item.MutationId == "Golden" or item.MutationId == "Rainbow" or item.MutationId == "VoidTouched" or item.MutationId == "Glitched" then
		return "Void.FeedRare"
	end
	if snack and rarityConfig and rarityConfig.IsAtLeast and rarityConfig.IsAtLeast(snack.Rarity or "Common", "Rare") then
		return "Void.FeedRare"
	end
	if (tonumber(item.EstimatedVoidValue) or 0) <= 20 then
		return "Void.FeedSmall"
	end
	return "Void.FeedNormal"
end

return SizeConfig
