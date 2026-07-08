local HttpService = game:GetService("HttpService")

local QuestService = {}

local questDefinitions = {
	{ Type = "Plant", Text = "Plant snacks", Target = 3, Coins = 60 },
	{ Type = "Harvest", Text = "Harvest snacks", Target = 3, Coins = 90 },
	{ Type = "FeedVoid", Text = "Feed the Void", Target = 2, VoidTokens = 2 },
	{ Type = "Sell", Text = "Sell snacks", Target = 2, Coins = 80 },
	{ Type = "Display", Text = "Display a snack", Target = 1, Coins = 75 },
	{ Type = "CleanseVoidmite", Text = "Cleanse Voidmites", Target = 3, Coins = 120, VoidTokens = 1 },
	{ Type = "BuyUpgrade", Text = "Buy an upgrade", Target = 1, Coins = 100 },
	{ Type = "CollectCrumb", Text = "Collect SnackRain crumbs", Target = 5, Coins = 100, Seeds = { CookieRock = 1 } },
	{ Type = "DiscoverMutation", Text = "Discover a mutation", Target = 1, VoidTokens = 2 },
}

local function ensure(data)
	data.Quests = data.Quests or {}
	data.Quests.Active = data.Quests.Active or {}
	data.Quests.CompletedCount = tonumber(data.Quests.CompletedCount) or 0
	return data.Quests
end

local function cloneQuest(definition)
	return {
		Id = HttpService:GenerateGUID(false),
		Type = definition.Type,
		Text = definition.Text,
		Target = definition.Target,
		Progress = 0,
		Coins = definition.Coins or 0,
		VoidTokens = definition.VoidTokens or 0,
		Seeds = definition.Seeds,
	}
end

local function randomQuest(existing)
	local used = {}
	for _, quest in ipairs(existing or {}) do
		used[quest.Type] = true
	end
	local pool = {}
	for _, definition in ipairs(questDefinitions) do
		if not used[definition.Type] then
			table.insert(pool, definition)
		end
	end
	if #pool == 0 then
		pool = questDefinitions
	end
	return cloneQuest(pool[math.random(1, #pool)])
end

function QuestService.Init(context)
	QuestService.Context = context
end

function QuestService.Start() end

function QuestService.Ensure(player)
	local data = QuestService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return nil
	end
	local quests = ensure(data)
	while #quests.Active < 3 do
		table.insert(quests.Active, randomQuest(quests.Active))
	end
	return quests
end

function QuestService.Serialize(player)
	local quests = QuestService.Ensure(player)
	if not quests then
		return { Active = {}, CompletedCount = 0 }
	end
	local active = {}
	for _, quest in ipairs(quests.Active) do
		table.insert(active, {
			Id = quest.Id,
			Type = quest.Type,
			Text = quest.Text,
			Progress = math.min(quest.Progress or 0, quest.Target or 1),
			Target = quest.Target or 1,
		})
	end
	return {
		Active = active,
		CompletedCount = quests.CompletedCount or 0,
	}
end

function QuestService.Record(player, questType, amount)
	local context = QuestService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	local quests = QuestService.Ensure(player)
	local completedAny = false
	for index = #quests.Active, 1, -1 do
		local quest = quests.Active[index]
		if quest.Type == questType then
			quest.Progress = math.min((quest.Progress or 0) + (amount or 1), quest.Target or 1)
			if quest.Progress >= quest.Target then
				if quest.Coins and quest.Coins > 0 then
					context.Services.EconomyService.AddCoins(player, quest.Coins)
				end
				if quest.VoidTokens and quest.VoidTokens > 0 then
					context.Services.EconomyService.AddVoidTokens(player, quest.VoidTokens)
				end
				for seedId, count in pairs(quest.Seeds or {}) do
					context.Services.EconomyService.AddSeeds(player, seedId, count, false)
				end
				context.Services.EconomyService.Notify(player, "Objective complete: " .. quest.Text .. "!")
				table.remove(quests.Active, index)
				quests.CompletedCount = (quests.CompletedCount or 0) + 1
				completedAny = true
			end
		end
	end
	while #quests.Active < 3 do
		table.insert(quests.Active, randomQuest(quests.Active))
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	return completedAny
end

return QuestService
