local AnalyticsService = {}

local function log(eventName, ...)
	print("[Analytics]", eventName, ...)
end

function AnalyticsService.Init(context)
	AnalyticsService.Context = context
end

function AnalyticsService.Start() end

function AnalyticsService.PlayerJoined(player) log("PlayerJoined", player.Name) end
function AnalyticsService.SnackPlanted(player, snackId) log("SnackPlanted", player.Name, snackId) end
function AnalyticsService.SnackHarvested(player, item) log("SnackHarvested", player.Name, item and item.DisplayName) end
function AnalyticsService.SnackSold(player, item, coins) log("SnackSold", player.Name, item and item.DisplayName, coins) end
function AnalyticsService.SnackFed(player, item, value) log("SnackFed", player.Name, item and item.DisplayName, value) end
function AnalyticsService.SnackDisplayed(player, item) log("SnackDisplayed", player.Name, item and item.DisplayName) end
function AnalyticsService.VoidmiteCleared(player, owner, reward) log("VoidmiteCleared", player.Name, owner and owner.Name or "offline", reward) end
function AnalyticsService.VoidEventStarted(eventName) log("VoidEventStarted", eventName) end

return AnalyticsService
