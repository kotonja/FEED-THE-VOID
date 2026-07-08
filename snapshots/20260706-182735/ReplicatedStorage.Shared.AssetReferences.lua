local AssetReferences = {
	TheVoid = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Void", "FTW_TheVoid" },
		FallbackType = "Void",
		DefaultScale = 1,
		Description = "Central hunger creature model.",
	},
	Voidmite = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Creatures", "FTW_Voidmite" },
		FallbackType = "Creature",
		DefaultScale = 1,
		Description = "Small enemy/cleanse creature.",
	},
	VoidlingPet = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Creatures", "FTW_VoidlingPet" },
		FallbackType = "Creature",
		DefaultScale = 1,
		Description = "Future pet/companion model. Safe if not imported yet.",
	},
	SnackRoundBase = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Snacks", "FTW_Snack_RoundBase" },
		FallbackType = "SnackRound",
		DefaultScale = 1,
		Description = "Round snack base mesh.",
	},
	SnackCubeBase = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Snacks", "FTW_Snack_CubeBase" },
		FallbackType = "SnackCube",
		DefaultScale = 1,
		Description = "Cube snack base mesh.",
	},
	SnackWrapBase = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Snacks", "FTW_Snack_WrapBase" },
		FallbackType = "SnackWrap",
		DefaultScale = 1,
		Description = "Wrap snack base mesh.",
	},
	PhantomSnack = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Snacks", "FTW_PhantomSnack" },
		FallbackType = "PhantomSnack",
		DefaultScale = 1,
		Description = "Phantom Snack Chase collectible.",
	},
	GrowPlate = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Plot", "FTW_GrowPlate" },
		FallbackType = "GrowPlate",
		DefaultScale = 1,
		Description = "Grow plate visual mesh.",
	},
	DisplayPedestal = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Plot", "FTW_DisplayPedestal" },
		FallbackType = "DisplayPedestal",
		DefaultScale = 1,
		Description = "Displayed snack pedestal mesh.",
	},
	SeedShopMachine = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Stations", "FTW_SeedShopMachine" },
		FallbackType = "Station",
		DefaultScale = 1,
		Description = "Seed shop station visual.",
	},
	SellStation = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Stations", "FTW_SellStation" },
		FallbackType = "Station",
		DefaultScale = 1,
		Description = "Sell station visual.",
	},
	UpgradeStation = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Stations", "FTW_UpgradeStation" },
		FallbackType = "Station",
		DefaultScale = 1,
		Description = "Upgrade station visual.",
	},
	RebirthPortal = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Stations", "FTW_RebirthPortal" },
		FallbackType = "Portal",
		DefaultScale = 1,
		Description = "Rebirth portal visual.",
	},
	DailyRewardChest = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Stations", "FTW_DailyRewardChest" },
		FallbackType = "Chest",
		DefaultScale = 1,
		Description = "Daily chest station visual.",
	},
	VoidCrumbPickup = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Pickups", "FTW_VoidCrumbPickup" },
		FallbackType = "Pickup",
		DefaultScale = 1,
		Description = "Snack Rain pickup.",
	},
	VoidShardPickup = {
		Path = { "ReplicatedStorage", "Assets", "Models", "Pickups", "FTW_VoidShardPickup" },
		FallbackType = "Pickup",
		DefaultScale = 1,
		Description = "Rare shard pickup.",
	},
}

AssetReferences.RequiredAssetKeys = {
	"TheVoid",
	"Voidmite",
	"VoidlingPet",
	"SnackRoundBase",
	"SnackCubeBase",
	"SnackWrapBase",
	"PhantomSnack",
	"GrowPlate",
	"DisplayPedestal",
	"SeedShopMachine",
	"SellStation",
	"UpgradeStation",
	"RebirthPortal",
	"DailyRewardChest",
	"VoidCrumbPickup",
	"VoidShardPickup",
}

return AssetReferences
