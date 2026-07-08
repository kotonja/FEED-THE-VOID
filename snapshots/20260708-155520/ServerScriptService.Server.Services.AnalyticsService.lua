local AnalyticsService = {}

local sessionFunnel = {}
local lastActions = {}

local function compactDetail(detail)
	if detail == nil then
		return nil
	end
	if type(detail) == "table" then
		local parts = {}
		for key, value in pairs(detail) do
			table.insert(parts, tostring(key) .. "=" .. tostring(value))
		end
		table.sort(parts)
		return table.concat(parts, ",")
	end
	return tostring(detail)
end

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

function AnalyticsService.RecordAction(player, action, detail)
	if not player or not action then
		return
	end
	lastActions[player] = lastActions[player] or {}
	local entry = {
		Time = os.time(),
		Clock = os.clock(),
		Action = tostring(action),
		Detail = compactDetail(detail),
	}
	table.insert(lastActions[player], 1, entry)
	while #lastActions[player] > 10 do
		table.remove(lastActions[player])
	end
end

function AnalyticsService.GetLastActions(player, limit)
	local result = {}
	local entries = lastActions[player] or {}
	for index = 1, math.min(tonumber(limit) or 10, #entries) do
		result[index] = entries[index]
	end
	return result
end

function AnalyticsService.PlayerJoined(player)
	sessionFunnel[player] = {}
	lastActions[player] = {}
	AnalyticsService.Log("PlayerJoined", player.Name)
	AnalyticsService.RecordFunnel(player, "Joined")
	AnalyticsService.RecordAction(player, "Joined")
end

function AnalyticsService.SnackPlanted(player, snackId)
	AnalyticsService.Log("SnackPlanted", player.Name, snackId)
	AnalyticsService.RecordFunnel(player, "FirstPlant", snackId)
	AnalyticsService.RecordAction(player, "Planted " .. tostring(snackId))
end

function AnalyticsService.SnackHarvested(player, item)
	AnalyticsService.Log("SnackHarvested", player.Name, item and item.DisplayName)
	AnalyticsService.RecordFunnel(player, "FirstHarvest", item and item.SnackId)
	AnalyticsService.RecordAction(player, "Harvested " .. tostring(item and item.DisplayName or "snack"))
end

function AnalyticsService.SnackSold(player, item, coins)
	AnalyticsService.Log("SnackSold", player.Name, item and item.DisplayName, coins)
	AnalyticsService.RecordFunnel(player, "FirstSell", coins)
	AnalyticsService.RecordAction(player, "Sold item", { Item = item and item.DisplayName or "snack", Coins = coins })
end

function AnalyticsService.SnackFed(player, item, value)
	AnalyticsService.Log("SnackFed", player.Name, item and item.DisplayName, value)
	AnalyticsService.RecordFunnel(player, "FirstVoidFeed", value)
	AnalyticsService.RecordAction(player, "Fed Void", { Item = item and item.DisplayName or "snack", Value = value })
end

function AnalyticsService.SnackDisplayed(player, item)
	AnalyticsService.Log("SnackDisplayed", player.Name, item and item.DisplayName)
	AnalyticsService.RecordFunnel(player, "FirstDisplay", item and item.SnackId)
	AnalyticsService.RecordAction(player, "Displayed snack", item and item.DisplayName)
end

function AnalyticsService.VoidmiteCleared(player, owner, reward)
	AnalyticsService.Log("VoidmiteCleared", player.Name, owner and owner.Name or "offline", reward)
	AnalyticsService.RecordFunnel(player, "FirstVoidmiteCleanse", reward)
	AnalyticsService.RecordAction(player, "Cleansed Voidmite", { Owner = owner and owner.Name or "self", Reward = reward })
end

function AnalyticsService.VoidEventStarted(eventName)
	AnalyticsService.Log("VoidEventStarted", eventName)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		AnalyticsService.RecordAction(player, "Event started", eventName)
	end
end

function AnalyticsService.Rebirth(player, rebirths)
	AnalyticsService.Log("Rebirth", player.Name, rebirths)
	AnalyticsService.RecordAction(player, "Rebirth", rebirths)
end

function AnalyticsService.PlayerRemoving(player)
	sessionFunnel[player] = nil
	lastActions[player] = nil
end

return AnalyticsService
