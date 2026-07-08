local StatsService = {}

local defaults = {
	SnacksPlanted = 0,
	SnacksHarvested = 0,
	SnacksSold = 0,
	SnacksFed = 0,
	VoidmitesCleansed = 0,
	PhantomSnacksCaught = 0,
	VoidEventsParticipated = 0,
	TotalCoinsEarned = 0,
	TotalVoidTokensEarned = 0,
	TotalPlaytimeSeconds = 0,
	HighestSnackValue = 0,
	Discoveries = 0,
}

local function copyDefaults()
	local result = {}
	for key, value in pairs(defaults) do
		result[key] = value
	end
	return result
end

function StatsService.Defaults()
	return copyDefaults()
end

function StatsService.Init(context)
	StatsService.Context = context
end

function StatsService.Start() end

function StatsService.Ensure(player)
	local data = StatsService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return nil
	end
	data.Stats = type(data.Stats) == "table" and data.Stats or copyDefaults()
	for key, value in pairs(defaults) do
		data.Stats[key] = tonumber(data.Stats[key]) or value
	end
	return data.Stats
end

function StatsService.Record(player, statName, amount)
	local stats = StatsService.Ensure(player)
	if not stats or defaults[statName] == nil then
		return 0
	end
	amount = tonumber(amount) or 1
	stats[statName] = math.max(0, math.floor((stats[statName] or 0) + amount))
	StatsService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	return stats[statName]
end

function StatsService.RecordCoinsEarned(player, amount)
	if (tonumber(amount) or 0) > 0 then
		StatsService.Record(player, "TotalCoinsEarned", amount)
	end
end

function StatsService.RecordVoidTokensEarned(player, amount)
	if (tonumber(amount) or 0) > 0 then
		StatsService.Record(player, "TotalVoidTokensEarned", amount)
	end
end

function StatsService.RecordSnackValue(player, value)
	value = math.floor(tonumber(value) or 0)
	local stats = StatsService.Ensure(player)
	if stats and value > (stats.HighestSnackValue or 0) then
		stats.HighestSnackValue = value
		StatsService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
end

function StatsService.UpdatePlaytime(player)
	local data = StatsService.Context.Services.ProfileServiceWrapper.GetData(player)
	local stats = StatsService.Ensure(player)
	if not data or not stats then
		return
	end
	local rewards = data.PlaytimeRewards
	local sessionStart = rewards and tonumber(rewards.LastSessionStart) or nil
	if sessionStart and sessionStart > 0 then
		local elapsed = math.max(0, os.time() - sessionStart)
		if elapsed > 0 then
			stats.TotalPlaytimeSeconds = math.max(0, math.floor((stats.TotalPlaytimeSeconds or 0) + elapsed))
			rewards.LastSessionStart = os.time()
			StatsService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
		end
	end
end

function StatsService.Serialize(player)
	local stats = StatsService.Ensure(player) or copyDefaults()
	local result = {}
	for key, value in pairs(defaults) do
		result[key] = tonumber(stats[key]) or value
	end
	return result
end

return StatsService
