local AssetImportGuide = {
	Summary = "Place imported FTW models under ReplicatedStorage.Assets.Models using these exact names. Missing models are safe: AssetService warns once and uses non-neon placeholders.",
	LibraryRoot = "ReplicatedStorage.Assets.Models",
	RequiredPaths = {
		"The Void: ReplicatedStorage.Assets.Models.Void.FTW_TheVoid",
		"Voidmite: ReplicatedStorage.Assets.Models.Creatures.FTW_Voidmite",
		"Voidling pet: ReplicatedStorage.Assets.Models.Creatures.FTW_VoidlingPet",
		"Round snack: ReplicatedStorage.Assets.Models.Snacks.FTW_Snack_RoundBase",
		"Cube snack: ReplicatedStorage.Assets.Models.Snacks.FTW_Snack_CubeBase",
		"Wrap snack: ReplicatedStorage.Assets.Models.Snacks.FTW_Snack_WrapBase",
		"Phantom snack: ReplicatedStorage.Assets.Models.Snacks.FTW_PhantomSnack",
		"Grow plate: ReplicatedStorage.Assets.Models.Plot.FTW_GrowPlate",
		"Display pedestal: ReplicatedStorage.Assets.Models.Plot.FTW_DisplayPedestal",
		"Seed machine: ReplicatedStorage.Assets.Models.Stations.FTW_SeedShopMachine",
		"Sell station: ReplicatedStorage.Assets.Models.Stations.FTW_SellStation",
		"Upgrade station: ReplicatedStorage.Assets.Models.Stations.FTW_UpgradeStation",
		"Rebirth portal: ReplicatedStorage.Assets.Models.Stations.FTW_RebirthPortal",
		"Daily chest: ReplicatedStorage.Assets.Models.Stations.FTW_DailyRewardChest",
		"Void crumb: ReplicatedStorage.Assets.Models.Pickups.FTW_VoidCrumbPickup",
		"Void shard: ReplicatedStorage.Assets.Models.Pickups.FTW_VoidShardPickup",
	},
	Notes = {
		"Keep gameplay anchors and prompts in Workspace; imported models are visuals and can be swapped without changing remote names.",
		"MeshPart.TextureID and model materials are preserved by AssetService. Mutation styling adds highlights/lights instead of repainting textured meshes.",
		"Do not move artist source models into ServerStorage. Runtime clones are created from ReplicatedStorage.Assets.Models.",
	},
}

return AssetImportGuide
