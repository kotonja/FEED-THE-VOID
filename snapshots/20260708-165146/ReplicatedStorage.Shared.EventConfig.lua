local EventConfig = {
	SnackRain = {
		DisplayName = "Snack Rain",
		ObjectiveText = "Collect falling snack crumbs before they vanish.",
		WorldVisualText = "FALLING SNACK CRUMBS",
		Duration = 45,
		DebugDuration = 20,
		CrumbCount = 20,
		MaxActivePickups = 24,
		CoinReward = 12,
		SeedChance = 0.25,
	},
	MutationSurge = {
		DisplayName = "Mutation Surge",
		ObjectiveText = "Plant and harvest while mutation energy is surging.",
		WorldVisualText = "MUTATION PLATES ACTIVE",
		Duration = 90,
		DebugDuration = 25,
		RareWeightMultiplier = 2.25,
	},
	VoidInfestation = {
		DisplayName = "Void Infestation",
		ObjectiveText = "Cleanse the Voidmites swarming the labs.",
		WorldVisualText = "VOIDMITE NEST OPEN",
		Duration = 45,
		DebugDuration = 20,
		RewardMultiplier = 1.35,
		ExtraSpawnPasses = 2,
	},
	GoldenHunger = {
		DisplayName = "Golden Hunger",
		ObjectiveText = "Feed the wanted snack for bonus hunger and Void Tokens.",
		WorldVisualText = "THE VOID WANTS A SNACK",
		Duration = 120,
		DebugDuration = 30,
		VoidValueMultiplier = 1.75,
		TokenBonus = 3,
		HungerBonus = 18,
	},
	PhantomSnackChase = {
		DisplayName = "Phantom Snack Chase",
		ObjectiveText = "Catch the visible Phantom Snacks before they escape.",
		WorldVisualText = "PHANTOMS LOOSE",
		Duration = 45,
		DebugDuration = 20,
		MaxActivePhantoms = 5,
		BaseCoinReward = 75,
		MaxCoinReward = 250,
		CookieSeedChance = 0.20,
		JellySeedChance = 0.10,
		MeteorSeedChance = 0.03,
		VoidTokenMin = 1,
		VoidTokenMax = 3,
	},
}

EventConfig.Order = { "SnackRain", "MutationSurge", "VoidInfestation", "GoldenHunger", "PhantomSnackChase" }

return EventConfig
