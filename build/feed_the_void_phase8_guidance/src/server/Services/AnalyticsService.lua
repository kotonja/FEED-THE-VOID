local AnalyticsService = {}

local sessionFunnel = {}

function AnalyticsService.Init(context)
	AnalyticsService.Context = context
end

function AnalyticsService.Start() end

function AnalyticsService.Log(eventName, ...)
	if AnalyticsService.Context and AnalyticsService.Context.Config.GameConfig.DebugMode then
		print("[Analytics]", eventName, ...)
	end
end

function AnalyticsService.RecordFunnel(player, milestone, detail)
	if not player or not milestone then
		return
	end
	sessionFunnel[player] = sessionFunnel[player] or {}
	if sessionFunnel[player][milestone] then
		return
	end
	sessionFunnel[player][milestone] = os.clock()
	AnalyticsService.Log("Funnel", player.Name, milestone, detail or "")
end

function AnalyticsService.GetSessionFunnel(player)
	return sessionFunnel[player] or {}
end

function AnalyticsService.PlayerJoined(player)
	sessionFunnel[player] = {}
	AnalyticsService.Log("PlayerJoined", player.Name)
	AnalyticsService.RecordFunnel(player, "Joined")
end

function AnalyticsService.SnackPlanted(player, snackId)
	AnalyticsService.Log("SnackPlanted", player.Name, snackId)
	AnalyticsService.RecordFunnel(player, "FirstPlant", snackId)
end

function AnalyticsService.SnackHarvested(player, item)
	AnalyticsService.Log("SnackHarvested", player.Name, item and item.DisplayName)
	AnalyticsService.RecordFunnel(player, "FirstHarvest", item and item.SnackId)
end

function AnalyticsService.SnackSold(player, item, coins)
	AnalyticsService.Log("SnackSold", player.Name, item and item.DisplayName, coins)
	AnalyticsService.RecordFunnel(player, "FirstSell", coins)
end

function AnalyticsService.SnackFed(player, item, value)
	AnalyticsService.Log("SnackFed", player.Name, item and item.DisplayName, value)
	AnalyticsService.RecordFunnel(player, "FirstVoidFeed", value)
end

function AnalyticsService.SnackDisplayed(player, item)
	AnalyticsService.Log("SnackDisplayed", player.Name, item and item.DisplayName)
	AnalyticsService.RecordFunnel(player, "FirstDisplay", item and item.SnackId)
end

function AnalyticsService.VoidmiteCleared(player, owner, reward)
	AnalyticsService.Log("VoidmiteCleared", player.Name, owner and owner.Name or "offline", reward)
	AnalyticsService.RecordFunnel(player, "FirstVoidmiteCleanse", reward)
end

function AnalyticsService.VoidEventStarted(eventName) AnalyticsService.Log("VoidEventStarted", eventName) end
function AnalyticsService.Rebirth(player, rebirths) AnalyticsService.Log("Rebirth", player.Name, rebirths) end

return AnalyticsService
