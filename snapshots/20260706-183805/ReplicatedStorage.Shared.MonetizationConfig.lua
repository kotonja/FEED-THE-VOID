local MonetizationConfig = {
	Enabled = false,
	Phase = "StubOnly",
	DeveloperProducts = {},
	GamePasses = {},
	Notes = {
		"Phase 5 keeps monetization config-only. No purchase UI, prompts, or paid progression boosts are active.",
		"Add product ids here later, then gate every purchase flow through server validation.",
	},
}

return MonetizationConfig
