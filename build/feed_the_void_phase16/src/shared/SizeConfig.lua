local SizeConfig = {}

SizeConfig.DefaultTier = "Regular"
SizeConfig.MaxValueMultiplier = 7.6

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
		Weight = 650,
		ScaleMultiplier = 1,
		ValueMultiplier = 1,
		ServerAnnounce = false,
	},
	Chunky = {
		DisplayName = "Chunky",
		Order = 2,
		Weight = 180,
		ScaleMultiplier = 1.25,
		ValueMultiplier = 1.3,
		ServerAnnounce = false,
	},
	Huge = {
		DisplayName = "Huge",
		Order = 3,
		Weight = 90,
		ScaleMultiplier = 1.6,
		ValueMultiplier = 1.9,
		ServerAnnounce = false,
	},
	Massive = {
		DisplayName = "Massive",
		Order = 4,
		Weight = 45,
		ScaleMultiplier = 2.1,
		ValueMultiplier = 2.8,
		ServerAnnounce = false,
	},
	Colossal = {
		DisplayName = "Colossal",
		Order = 5,
		Weight = 18,
		ScaleMultiplier = 2.8,
		ValueMultiplier = 4.6,
		ServerAnnounce = true,
	},
	Voidborn = {
		DisplayName = "Voidborn",
		Order = 6,
		Weight = 3,
		ScaleMultiplier = 3.5,
		ValueMultiplier = 7.6,
		ServerAnnounce = true,
	},
}

for tierId, tier in pairs(SizeConfig.Tiers) do
	tier.Scale = tier.ScaleMultiplier
	tier.WeightMultiplier = tier.ScaleMultiplier
	tier.Announce = tier.ServerAnnounce
	tier.Id = tierId
end

local function roundTenth(value)
	return math.max(0.1, math.floor((tonumber(value) or 0) * 10 + 0.5) / 10)
end

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
	return SizeConfig.GetTier(tierId).Order or 1
end

function SizeConfig.RollSizeTier(forcedTier)
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

function SizeConfig.RollTier(forcedTier)
	return SizeConfig.RollSizeTier(forcedTier)
end

function SizeConfig.GetScaleMultiplier(itemOrTier)
	if type(itemOrTier) == "table" then
		local explicit = tonumber(itemOrTier.SizeMultiplier)
		if explicit then
			return explicit
		end
		return SizeConfig.GetTier(itemOrTier.SizeTier).ScaleMultiplier
	end
	return SizeConfig.GetTier(itemOrTier).ScaleMultiplier
end

function SizeConfig.GetSizeMultiplier(itemOrTier)
	return SizeConfig.GetScaleMultiplier(itemOrTier)
end

function SizeConfig.GetVisualScale(itemOrTier, cap)
	local scale = SizeConfig.GetScaleMultiplier(itemOrTier)
	if cap then
		return math.clamp(scale, 0.75, tonumber(cap) or scale)
	end
	return math.max(0.75, scale)
end

function SizeConfig.GetValueMultiplier(itemOrTier)
	if type(itemOrTier) == "table" then
		local explicit = tonumber(itemOrTier.SizeValueMultiplier)
		if explicit then
			return explicit
		end
		return SizeConfig.GetTier(itemOrTier.SizeTier).ValueMultiplier
	end
	return SizeConfig.GetTier(itemOrTier).ValueMultiplier
end

function SizeConfig.FormatWeight(weight)
	weight = roundTenth(weight or 1)
	if math.abs(weight - math.floor(weight)) < 0.05 then
		return tostring(math.floor(weight)) .. " lb"
	end
	return string.format("%.1f lb", weight)
end

function SizeConfig.BaseWeight(snack)
	if type(snack) ~= "table" then
		return 1
	end
	return tonumber(snack.BaseWeight) or 1
end

function SizeConfig.WeightForSnack(snack, tierId, variation)
	local tier = SizeConfig.GetTier(tierId)
	variation = tonumber(variation)
	if not variation then
		variation = 0.9 + (math.random() * 0.25)
	end
	return roundTenth(SizeConfig.BaseWeight(snack) * (tier.ScaleMultiplier or 1) * variation)
end

local function applySizeFields(target, snack, defaultTier)
	if type(target) ~= "table" then
		return target
	end
	local tierId = SizeConfig.NormalizeTier(target.SizeTier or defaultTier or SizeConfig.DefaultTier)
	local tier = SizeConfig.GetTier(tierId)
	target.SizeTier = tierId
	target.SizeMultiplier = tier.ScaleMultiplier
	target.SizeValueMultiplier = tier.ValueMultiplier
	target.WeightRoll = tonumber(target.WeightRoll) or (0.9 + (math.random() * 0.25))
	target.Weight = tonumber(target.Weight) or SizeConfig.WeightForSnack(snack, tierId, target.WeightRoll)
	target.Weight = roundTenth(target.Weight)
	return target
end

function SizeConfig.ApplyToItem(item, snack, defaultTier)
	return applySizeFields(item, snack, defaultTier)
end

function SizeConfig.ApplyToPlantedRecord(record, snack, defaultTier)
	return applySizeFields(record, snack, defaultTier)
end

function SizeConfig.SizeLabel(itemOrTier)
	local tierId = type(itemOrTier) == "table" and itemOrTier.SizeTier or itemOrTier
	local tier = SizeConfig.GetTier(tierId)
	if tier.DisplayName == "Regular" then
		return ""
	end
	return tier.DisplayName .. " "
end

function SizeConfig.IsAnnounceTier(tierId)
	return SizeConfig.GetTier(tierId).ServerAnnounce == true
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
		return "Void.Feed"
	end
	if item.SizeTier == "Voidborn" then
		return "Void.FeedVoidborn"
	end
	if item.SizeTier == "Colossal" or SizeConfig.GetScaleMultiplier(item) >= 2.7 then
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
	return "Void.Feed"
end

return SizeConfig
