local SnackConfig = {
	CookieRock = {
		DisplayName = "Cookie Rock",
		SeedCost = 10,
		GrowTime = 14,
		BaseSellValue = 25,
		BaseVoidValue = 16,
		Rarity = "Common",
		VisualType = "Round",
		Color = Color3.fromRGB(185, 164, 132),
	},
	JellyCube = {
		DisplayName = "Jelly Cube",
		SeedCost = 25,
		GrowTime = 28,
		BaseSellValue = 70,
		BaseVoidValue = 34,
		Rarity = "Uncommon",
		VisualType = "Cube",
		Color = Color3.fromRGB(92, 220, 225),
	},
	MeteorMuffin = {
		DisplayName = "Meteor Muffin",
		SeedCost = 100,
		GrowTime = 52,
		BaseSellValue = 250,
		BaseVoidValue = 75,
		Rarity = "Rare",
		VisualType = "Round",
		Color = Color3.fromRGB(220, 92, 76),
	},
	MoonMarshmallow = {
		DisplayName = "Moon Marshmallow",
		SeedCost = 15,
		GrowTime = 20,
		BaseSellValue = 40,
		BaseVoidValue = 22,
		Rarity = "Common",
		VisualType = "Round",
		Color = Color3.fromRGB(220, 224, 255),
	},
	BubbleBread = {
		DisplayName = "Bubble Bread",
		SeedCost = 40,
		GrowTime = 34,
		BaseSellValue = 110,
		BaseVoidValue = 42,
		Rarity = "Uncommon",
		VisualType = "Wrap",
		Color = Color3.fromRGB(255, 158, 204),
	},
	CrystalDonut = {
		DisplayName = "Crystal Donut",
		SeedCost = 180,
		GrowTime = 75,
		BaseSellValue = 450,
		BaseVoidValue = 90,
		Rarity = "Rare",
		VisualType = "Round",
		Color = Color3.fromRGB(119, 218, 255),
	},
	LavaNoodleWrap = {
		DisplayName = "Lava Noodle Wrap",
		SeedCost = 500,
		GrowTime = 120,
		BaseSellValue = 1400,
		BaseVoidValue = 220,
		Rarity = "Epic",
		VisualType = "Wrap",
		Color = Color3.fromRGB(255, 97, 48),
	},
	BlackHoleBurrito = {
		DisplayName = "Black Hole Burrito",
		SeedCost = 2500,
		GrowTime = 240,
		BaseSellValue = 9000,
		BaseVoidValue = 900,
		Rarity = "Legendary",
		VisualType = "Wrap",
		Color = Color3.fromRGB(48, 31, 70),
	},
}

local order = {
	"CookieRock",
	"MoonMarshmallow",
	"JellyCube",
	"BubbleBread",
	"MeteorMuffin",
	"CrystalDonut",
	"LavaNoodleWrap",
	"BlackHoleBurrito",
}

SnackConfig.Order = order

SnackConfig.StageScale = {
	[1] = 0.42,
	[2] = 0.7,
	[3] = 1,
}

SnackConfig.RarityMaxSize = {
	Common = 2.35,
	Uncommon = 2.65,
	Rare = 3.05,
	Epic = 3.45,
	Legendary = 3.85,
}

SnackConfig.VisualTypeSizeScale = {
	Round = 1,
	Cube = 0.92,
	Wrap = 1.05,
}

return SnackConfig
