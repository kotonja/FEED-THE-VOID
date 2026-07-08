local EventConfig = {
	SnackRain = {
		DisplayName = "Snack Rain",
		Duration = 45,
		DebugDuration = 20,
		CrumbCount = 20,
		MaxActivePickups = 24,
		CoinReward = 12,
		SeedChance = 0.25,
	},
	MutationSurge = {
		DisplayName = "Mutation Surge",
		Duration = 90,
		DebugDuration = 25,
		RareWeightMultiplier = 2.25,
	},
	VoidInfestation = {
		DisplayName = "Void Infestation",
		Duration = 45,
		DebugDuration = 20,
		RewardMultiplier = 1.35,
		ExtraSpawnPasses = 2,
	},
	GoldenHunger = {
		DisplayName = "Golden Hunger",
		Duration = 120,
		DebugDuration = 30,
		VoidValueMultiplier = 1.75,
		TokenBonus = 3,
		HungerBonus = 18,
	},
}

EventConfig.Order = { "SnackRain", "MutationSurge", "VoidInfestation", "GoldenHunger" }

return EventConfig
