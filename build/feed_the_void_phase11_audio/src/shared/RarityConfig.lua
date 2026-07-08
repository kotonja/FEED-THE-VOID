local RarityConfig = {
	Common = {
		DisplayColor = Color3.fromRGB(225, 232, 245),
		SortOrder = 1,
		ServerAnnounce = false,
		PassiveIncomeMultiplier = 1,
		VoidmiteAttractionMultiplier = 1,
		CollectionReward = { Coins = 25 },
		ShopWeight = 100,
	},
	Uncommon = {
		DisplayColor = Color3.fromRGB(116, 225, 154),
		SortOrder = 2,
		ServerAnnounce = false,
		PassiveIncomeMultiplier = 1.25,
		VoidmiteAttractionMultiplier = 1.2,
		CollectionReward = { Coins = 50 },
		ShopWeight = 70,
	},
	Rare = {
		DisplayColor = Color3.fromRGB(92, 178, 255),
		SortOrder = 3,
		ServerAnnounce = false,
		PassiveIncomeMultiplier = 1.75,
		VoidmiteAttractionMultiplier = 1.75,
		CollectionReward = { Coins = 125 },
		ShopWeight = 35,
	},
	Epic = {
		DisplayColor = Color3.fromRGB(190, 116, 255),
		SortOrder = 4,
		ServerAnnounce = true,
		PassiveIncomeMultiplier = 2.75,
		VoidmiteAttractionMultiplier = 2.5,
		CollectionReward = { VoidTokens = 2 },
		ShopWeight = 14,
	},
	Legendary = {
		DisplayColor = Color3.fromRGB(255, 205, 58),
		SortOrder = 5,
		ServerAnnounce = true,
		PassiveIncomeMultiplier = 5,
		VoidmiteAttractionMultiplier = 4,
		CollectionReward = { VoidTokens = 5 },
		ShopWeight = 5,
	},
	Secret = {
		DisplayColor = Color3.fromRGB(80, 255, 190),
		SortOrder = 6,
		ServerAnnounce = true,
		PassiveIncomeMultiplier = 10,
		VoidmiteAttractionMultiplier = 6,
		CollectionReward = { VoidTokens = 10 },
		ShopWeight = 0,
	},
}

RarityConfig.Order = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Secret",
}

function RarityConfig.GetSortOrder(rarity)
	local config = RarityConfig[rarity]
	return config and config.SortOrder or 999
end

function RarityConfig.IsAtLeast(rarity, minimum)
	return RarityConfig.GetSortOrder(rarity) >= RarityConfig.GetSortOrder(minimum)
end

return RarityConfig
