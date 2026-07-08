local HttpService = game:GetService("HttpService")

local FeedbackService = {}

local recentEntries = {}
local lastSubmitAt = {}
local maxRecentEntries = 50
local categories = {
	Bug = true,
	Confusing = true,
	TooSlow = true,
	TooHard = true,
	UIIssue = true,
	MobileIssue = true,
	Fun = true,
	Other = true,
}

local function featureEnabled(context)
	local flags = context.Config.FeatureFlags or {}
	local private = context.Config.GameConfig.PrivateTest or {}
	return flags.PrivateTestFeedback ~= false
		and private.EnableFeedbackButton ~= false
		and context.Config.GameConfig.LaunchMode ~= "Production"
end

local function cleanText(value, maxLength)
	value = tostring(value or "")
	value = value:gsub("[%c]", " ")
	value = value:match("^%s*(.-)%s*$") or ""
	if #value > maxLength then
		value = value:sub(1, maxLength)
	end
	return value
end

local function compactTable(value)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	return ok and encoded or tostring(value)
end

function FeedbackService.Init(context)
	FeedbackService.Context = context
end

function FeedbackService.Start() end

function FeedbackService.IsEnabled()
	return featureEnabled(FeedbackService.Context)
end

function FeedbackService.Submit(player, payload)
	local context = FeedbackService.Context
	if not player or not featureEnabled(context) then
		return false
	end
	if type(payload) ~= "table" then
		context.Services.EconomyService.Notify(player, "Feedback did not send.")
		return false
	end
	local now = os.clock()
	if lastSubmitAt[player.UserId] and now - lastSubmitAt[player.UserId] < 30 then
		context.Services.EconomyService.Notify(player, "Feedback cooldown active.")
		return false
	end
	local category = cleanText(payload.Category, 24)
	if not categories[category] then
		category = "Other"
	end
	local message = cleanText(payload.Message, 200)
	if #message < 3 then
		context.Services.EconomyService.Notify(player, "Type a little more feedback first.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local eventStatus = context.Services.EventService and context.Services.EventService.GetStatus() or {}
	local entry = {
		Id = HttpService:GenerateGUID(false),
		CreatedAt = os.time(),
		PlayerName = player.Name,
		UserId = player.UserId,
		Category = category,
		Message = message,
		DeviceType = cleanText(payload.DeviceType, 32),
		CurrentPanel = cleanText(payload.CurrentPanel, 48),
		BuildVersion = context.Config.GameConfig.BuildVersion or context.Config.GameConfig.Phase,
		LaunchMode = context.Config.GameConfig.LaunchMode,
		ProfileReady = player:GetAttribute("ProfileReady") == true,
		PlotAssigned = player:GetAttribute("PlotAssigned") == true,
		AssignedPlotId = data and data.AssignedPlotId or nil,
		TutorialStep = data and data.TutorialStep or nil,
		ActiveEventName = eventStatus.ActiveEventName,
		NextGoal = payload.NextGoal,
	}
	table.insert(recentEntries, 1, entry)
	while #recentEntries > maxRecentEntries do
		table.remove(recentEntries)
	end
	lastSubmitAt[player.UserId] = now
	print("[FEED THE VOID][Feedback] " .. compactTable(entry))
	context.Services.EconomyService.Notify(player, "Feedback sent. Thank you.")
	return true
end

function FeedbackService.PrintRecent(player)
	print("[FEED THE VOID][Feedback] Recent entries: " .. tostring(#recentEntries))
	for index, entry in ipairs(recentEntries) do
		if index > 10 then
			break
		end
		print(string.format(
			"[FEED THE VOID][Feedback] #%d %s/%s user=%s panel=%s msg=%s",
			index,
			tostring(entry.Category),
			tostring(entry.BuildVersion),
			tostring(entry.UserId),
			tostring(entry.CurrentPanel),
			tostring(entry.Message)
		))
	end
	if player and FeedbackService.Context.Services.EconomyService then
		FeedbackService.Context.Services.EconomyService.Notify(player, "Feedback entries printed to Output: " .. tostring(math.min(#recentEntries, 10)))
	end
end

function FeedbackService.Clear(player)
	table.clear(recentEntries)
	table.clear(lastSubmitAt)
	if player and FeedbackService.Context.Services.EconomyService then
		FeedbackService.Context.Services.EconomyService.Notify(player, "Feedback log cleared for this server.")
	end
end

function FeedbackService.GetSummary()
	return {
		Enabled = FeedbackService.IsEnabled(),
		RecentCount = #recentEntries,
	}
end

return FeedbackService
