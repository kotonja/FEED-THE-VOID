local DailyRewardService = {}

local rewards = {
	{ Coins = 100, Label = "Day 1: 100 Coins" },
	{ Coins = 200, Label = "Day 2: 200 Coins" },
	{ Seeds = { MeteorMuffin = 1 }, Label = "Day 3: Meteor Muffin seed" },
	{ VoidTokens = 5, Label = "Day 4: 5 Void Tokens" },
	{ Coins = 500, Label = "Day 5: 500 Coins" },
	{ RandomSeeds = 2, Label = "Day 6: 2 bonus seeds" },
	{ Coins = 1000, VoidTokens = 10, Label = "Day 7: 1000 Coins + 10 Void Tokens" },
}

local randomSeedPool = { "JellyCube", "BubbleBread", "MeteorMuffin", "CrystalDonut" }

local function ensure(data)
	data.DailyReward = type(data.DailyReward) == "table" and data.DailyReward or {}
	data.DailyReward.LastClaimTime = tonumber(data.DailyReward.LastClaimTime) or 0
	data.DailyReward.Streak = tonumber(data.DailyReward.Streak) or 0
	return data.DailyReward
end

local function rewardForDay(day)
	return rewards[math.clamp(day, 1, #rewards)] or rewards[#rewards]
end

local function grant(context, player, reward)
	if reward.Coins then
		context.Services.EconomyService.AddCoins(player, reward.Coins)
	end
	if reward.VoidTokens then
		context.Services.EconomyService.AddVoidTokens(player, reward.VoidTokens)
	end
	for seedId, count in pairs(reward.Seeds or {}) do
		context.Services.EconomyService.AddSeeds(player, seedId, count, false)
	end
	for _ = 1, reward.RandomSeeds or 0 do
		local seedId = randomSeedPool[math.random(1, #randomSeedPool)]
		context.Services.EconomyService.AddSeeds(player, seedId, 1, false)
	end
end

local function bindPrompt(context)
	local world = workspace:FindFirstChild("GameWorld")
	local station = world and world:FindFirstChild("Stations") and world.Stations:FindFirstChild("DailyRewardChest")
	local prompt = station and station:FindFirstChild("DailyRewardPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") and not prompt:GetAttribute("FTVBound") then
		prompt:SetAttribute("FTVBound", true)
		prompt.Triggered:Connect(function(player)
			DailyRewardService.Claim(player)
		end)
	end
end

function DailyRewardService.Init(context)
	DailyRewardService.Context = context
end

function DailyRewardService.Start()
	task.spawn(function()
		while true do
			bindPrompt(DailyRewardService.Context)
			task.wait(5)
		end
	end)
end

function DailyRewardService.Ensure(player)
	local data = DailyRewardService.Context.Services.ProfileServiceWrapper.GetData(player)
	return data and ensure(data) or nil
end

function DailyRewardService.CanClaim(player)
	local state = DailyRewardService.Ensure(player)
	if not state then
		return false, 0
	end
	local cooldown = DailyRewardService.Context.Config.GameConfig.DailyRewardCooldownSeconds
	local remaining = math.max(0, (state.LastClaimTime + cooldown) - os.time())
	return remaining <= 0, remaining
end

function DailyRewardService.Claim(player)
	local context = DailyRewardService.Context
	local state = DailyRewardService.Ensure(player)
	if not state then
		return false
	end
	local canClaim, remaining = DailyRewardService.CanClaim(player)
	if not canClaim then
		context.Services.EconomyService.Notify(player, "Daily reward ready in " .. tostring(math.ceil(remaining / 60)) .. " min.")
		return false
	end
	local grace = context.Config.GameConfig.DailyRewardStreakGraceSeconds
	local nextStreak = 1
	if state.LastClaimTime > 0 and os.time() - state.LastClaimTime <= grace then
		nextStreak = math.min(7, (state.Streak or 0) + 1)
	end
	state.Streak = nextStreak
	state.LastClaimTime = os.time()
	local reward = rewardForDay(nextStreak)
	grant(context, player, reward)
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Notify(player, "Daily Reward claimed! " .. reward.Label)
	context.Services.EconomyService.Sync(player)
	return true
end

function DailyRewardService.Serialize(player)
	local state = DailyRewardService.Ensure(player)
	local canClaim, remaining = DailyRewardService.CanClaim(player)
	local nextDay = state and math.clamp((state.Streak or 0) + 1, 1, 7) or 1
	return {
		LastClaimTime = state and state.LastClaimTime or 0,
		Streak = state and state.Streak or 0,
		CanClaim = canClaim,
		RemainingSeconds = remaining,
		NextReward = rewardForDay(nextDay).Label,
	}
end

return DailyRewardService
