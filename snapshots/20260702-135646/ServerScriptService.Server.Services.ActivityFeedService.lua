local ActivityFeedService = {}

local lastByKey = {}

local function isEnabled()
	local config = ActivityFeedService.Context and ActivityFeedService.Context.Config.GameConfig
	if not config then
		return false
	end
	local feed = config.ActivityFeed or {}
	local soft = config.SoftLaunch or {}
	return feed.Enabled ~= false and soft.ActivityFeedEnabled ~= false
end

local function displayName(player)
	if not player then
		return "Someone"
	end
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

function ActivityFeedService.Init(context)
	ActivityFeedService.Context = context
end

function ActivityFeedService.Start() end

function ActivityFeedService.Announce(key, message, minSeconds)
	if not isEnabled() or not message or message == "" then
		return false
	end
	local now = os.clock()
	local feed = ActivityFeedService.Context.Config.GameConfig.ActivityFeed or {}
	local cooldown = tonumber(minSeconds) or tonumber(feed.MinSecondsBetweenMessages) or 4
	if lastByKey[key] and now - lastByKey[key] < cooldown then
		return false
	end
	lastByKey[key] = now
	ActivityFeedService.Context.Services.EconomyService.NotifyAll("[VOID FEED] " .. tostring(message))
	return true
end

function ActivityFeedService.RareHarvest(player, item)
	local mutationId = item and item.MutationId
	if not mutationId or mutationId == "Normal" then
		return false
	end
	local mutation = ActivityFeedService.Context.Config.MutationConfig[mutationId]
	local threshold = ActivityFeedService.Context.Config.GameConfig.ActivityFeed.RareMutationMinimumValueMultiplier or 2
	if not mutation or (mutation.ValueMultiplier or 1) < threshold then
		return false
	end
	return ActivityFeedService.Announce("rare_" .. tostring(player.UserId), displayName(player) .. " harvested " .. tostring(item.DisplayName) .. "!", 8)
end

function ActivityFeedService.EventStarted(eventName)
	local eventConfig = ActivityFeedService.Context.Config.EventConfig[eventName]
	local name = eventConfig and eventConfig.DisplayName or eventName
	return ActivityFeedService.Announce("event_started", tostring(name) .. " is active!", 5)
end

function ActivityFeedService.PhantomCaught(player)
	return ActivityFeedService.Announce("phantom_caught", displayName(player) .. " caught a Phantom Snack!", 6)
end

function ActivityFeedService.Rebirth(player, rebirths)
	return ActivityFeedService.Announce("rebirth_" .. tostring(player.UserId), displayName(player) .. " reached Rebirth " .. tostring(rebirths or 1) .. "!", 10)
end

return ActivityFeedService
