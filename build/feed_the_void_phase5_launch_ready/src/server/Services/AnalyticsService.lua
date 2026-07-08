local AnalyticsService = {}

function AnalyticsService.Init(context)
	AnalyticsService.Context = context
end

function AnalyticsService.Start() end

function AnalyticsService.Log(eventName, ...)
	if AnalyticsService.Context and AnalyticsService.Context.Config.GameConfig.DebugMode then
		print("[Analytics]", eventName, ...)
	end
end

function AnalyticsService.PlayerJoined(player) AnalyticsService.Log("PlayerJoined", player.Name) end
function AnalyticsService.SnackPlanted(player, snackId) AnalyticsService.Log("SnackPlanted", player.Name, snackId) end
function AnalyticsService.SnackHarvested(player, item) AnalyticsService.Log("SnackHarvested", player.Name, item and item.DisplayName) end
function AnalyticsService.SnackSold(player, item, coins) AnalyticsService.Log("SnackSold", player.Name, item and item.DisplayName, coins) end
function AnalyticsService.SnackFed(player, item, value) AnalyticsService.Log("SnackFed", player.Name, item and item.DisplayName, value) end
function AnalyticsService.SnackDisplayed(player, item) AnalyticsService.Log("SnackDisplayed", player.Name, item and item.DisplayName) end
function AnalyticsService.VoidmiteCleared(player, owner, reward) AnalyticsService.Log("VoidmiteCleared", player.Name, owner and owner.Name or "offline", reward) end
function AnalyticsService.VoidEventStarted(eventName) AnalyticsService.Log("VoidEventStarted", eventName) end
function AnalyticsService.Rebirth(player, rebirths) AnalyticsService.Log("Rebirth", player.Name, rebirths) end

return AnalyticsService
