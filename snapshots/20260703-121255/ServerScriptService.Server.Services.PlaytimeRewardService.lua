local PlaytimeRewardService = {}

local function ensure(data)
	data.PlaytimeRewards = type(data.PlaytimeRewards) == "table" and data.PlaytimeRewards or {}
	if not tonumber(data.PlaytimeRewards.LastSessionStart) then
		data.PlaytimeRewards.LastSessionStart = os.time()
	end
	data.PlaytimeRewards.ClaimedThisSession = type(data.PlaytimeRewards.ClaimedThisSession) == "table" and data.PlaytimeRewards.ClaimedThisSession or {}
	return data.PlaytimeRewards
end

local function rewardKey(reward)
	return tostring(reward.Seconds)
end

local function grantReward(context, player, reward)
	if reward.Coins then
		context.Services.EconomyService.AddCoins(player, reward.Coins)
	end
	if reward.VoidTokens then
		context.Services.EconomyService.AddVoidTokens(player, reward.VoidTokens)
	end
	for seedId, count in pairs(reward.Seeds or {}) do
		context.Services.EconomyService.AddSeeds(player, seedId, count, false)
	end
end

function PlaytimeRewardService.Init(context)
	PlaytimeRewardService.Context = context
end

function PlaytimeRewardService.Start()
	task.spawn(function()
		while true do
			task.wait((PlaytimeRewardService.Context.Config.GameConfig.Performance or {}).PlaytimeCheckInterval or 8)
			PlaytimeRewardService.Context.Services.EconomyService.SyncAll()
		end
	end)
end

function PlaytimeRewardService.Ensure(player)
	local data = PlaytimeRewardService.Context.Services.ProfileServiceWrapper.GetData(player)
	return data and ensure(data) or nil
end

function PlaytimeRewardService.GetElapsed(player)
	local state = PlaytimeRewardService.Ensure(player)
	return state and math.max(0, os.time() - (tonumber(state.LastSessionStart) or os.time())) or 0
end

function PlaytimeRewardService.GetClaimable(player)
	local state = PlaytimeRewardService.Ensure(player)
	if not state then
		return nil
	end
	local elapsed = PlaytimeRewardService.GetElapsed(player)
	for _, reward in ipairs(PlaytimeRewardService.Context.Config.GameConfig.PlaytimeRewards or {}) do
		if elapsed >= reward.Seconds and not state.ClaimedThisSession[rewardKey(reward)] then
			return reward
		end
	end
	return nil
end

function PlaytimeRewardService.Claim(player, requestedSeconds)
	local context = PlaytimeRewardService.Context
	local state = PlaytimeRewardService.Ensure(player)
	if not state then
		return false
	end
	local elapsed = PlaytimeRewardService.GetElapsed(player)
	local selected = nil
	requestedSeconds = tonumber(requestedSeconds)
	for _, reward in ipairs(context.Config.GameConfig.PlaytimeRewards or {}) do
		if (not requestedSeconds or requestedSeconds == reward.Seconds) and elapsed >= reward.Seconds and not state.ClaimedThisSession[rewardKey(reward)] then
			selected = reward
			break
		end
	end
	if not selected then
		context.Services.EconomyService.Notify(player, "No playtime reward is ready yet.")
		return false
	end
	state.ClaimedThisSession[rewardKey(selected)] = true
	grantReward(context, player, selected)
	context.Services.QuestService.Record(player, "ClaimPlaytimeReward", 1)
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Notify(player, "Playtime Reward claimed!")
	context.Services.EconomyService.Sync(player)
	return true
end

function PlaytimeRewardService.Serialize(player)
	local state = PlaytimeRewardService.Ensure(player)
	local elapsed = PlaytimeRewardService.GetElapsed(player)
	local rewards = {}
	for _, reward in ipairs(PlaytimeRewardService.Context.Config.GameConfig.PlaytimeRewards or {}) do
		table.insert(rewards, {
			Seconds = reward.Seconds,
			Label = reward.Label,
			Ready = elapsed >= reward.Seconds,
			Claimed = state and state.ClaimedThisSession[rewardKey(reward)] == true or false,
		})
	end
	return {
		LastSessionStart = state and state.LastSessionStart or os.time(),
		Elapsed = elapsed,
		Rewards = rewards,
	}
end

return PlaytimeRewardService
