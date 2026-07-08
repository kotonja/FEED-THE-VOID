local CollectionService = {}

local rareMutations = {
	Golden = true,
	Rainbow = true,
	VoidTouched = true,
	Glitched = true,
}

local function countKeys(map)
	local count = 0
	for _, unlocked in pairs(map or {}) do
		if unlocked then
			count += 1
		end
	end
	return count
end

local function ensure(data)
	data.Collections = data.Collections or {}
	data.Collections.Snacks = data.Collections.Snacks or {}
	data.Collections.Mutations = data.Collections.Mutations or {}
	data.Collections.Combos = data.Collections.Combos or {}
	data.Collections.RewardClaims = data.Collections.RewardClaims or {}
	return data.Collections
end

function CollectionService.Init(context)
	CollectionService.Context = context
end

function CollectionService.Start() end

function CollectionService.Ensure(player)
	local data = CollectionService.Context.Services.ProfileServiceWrapper.GetData(player)
	return data and ensure(data) or nil
end

function CollectionService.Serialize(player)
	local context = CollectionService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local collections = data and ensure(data) or { Snacks = {}, Mutations = {}, Combos = {} }
	local snackList = {}
	for _, snackId in ipairs(context.Config.SnackConfig.Order) do
		local snack = context.Config.SnackConfig[snackId]
		table.insert(snackList, {
			Id = snackId,
			Name = collections.Snacks[snackId] and snack.DisplayName or "???",
			Unlocked = collections.Snacks[snackId] == true,
		})
	end
	local mutationList = {}
	for _, mutationId in ipairs(context.Config.MutationConfig.Order) do
		local mutation = context.Config.MutationConfig[mutationId]
		table.insert(mutationList, {
			Id = mutationId,
			Name = collections.Mutations[mutationId] and mutation.DisplayName or "???",
			Unlocked = collections.Mutations[mutationId] == true,
		})
	end
	return {
		SnacksDiscovered = countKeys(collections.Snacks),
		SnacksTotal = #context.Config.SnackConfig.Order,
		MutationsDiscovered = countKeys(collections.Mutations),
		MutationsTotal = #context.Config.MutationConfig.Order,
		CombosDiscovered = countKeys(collections.Combos),
		CombosTotal = #context.Config.SnackConfig.Order * #context.Config.MutationConfig.Order,
		SnackList = snackList,
		MutationList = mutationList,
	}
end

local function claimMilestone(context, player, collections, key, condition, reward)
	if collections.RewardClaims[key] or not condition then
		return
	end
	collections.RewardClaims[key] = true
	if reward.Coins then
		context.Services.EconomyService.AddCoins(player, reward.Coins)
	end
	if reward.VoidTokens then
		context.Services.EconomyService.AddVoidTokens(player, reward.VoidTokens)
	end
	context.Services.EconomyService.Notify(player, reward.Message)
end

function CollectionService.MarkHarvest(player, item)
	local context = CollectionService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data or not item then
		return
	end
	local collections = ensure(data)
	local snackId = item.SnackId
	local mutationId = item.MutationId or "Normal"
	local comboId = snackId .. "_" .. mutationId
	local firstDiscovery = false
	if not collections.Snacks[snackId] then
		collections.Snacks[snackId] = true
		firstDiscovery = true
	end
	if not collections.Mutations[mutationId] then
		collections.Mutations[mutationId] = true
		firstDiscovery = true
		context.Services.QuestService.Record(player, "DiscoverMutation", 1)
	end
	if not collections.Combos[comboId] then
		collections.Combos[comboId] = true
		firstDiscovery = true
	end
	if firstDiscovery then
		context.Services.EconomyService.AddCoins(player, 20)
		if rareMutations[mutationId] then
			context.Services.EconomyService.AddVoidTokens(player, 1)
		end
		context.Services.EconomyService.Notify(player, "New discovery: " .. tostring(item.DisplayName) .. "!")
	end
	claimMilestone(context, player, collections, "Snacks3", countKeys(collections.Snacks) >= 3, { Coins = 100, Message = "Collection reward: 3 snack types discovered! +100 coins." })
	claimMilestone(context, player, collections, "Mutations5", countKeys(collections.Mutations) >= 5, { Coins = 250, Message = "Collection reward: 5 mutations discovered! +250 coins." })
	claimMilestone(context, player, collections, "Combos10", countKeys(collections.Combos) >= 10, { VoidTokens = 5, Message = "Collection reward: 10 combos discovered! +5 Void Tokens." })
	if mutationId == "VoidTouched" then
		context.Services.EconomyService.NotifyAll(player.Name .. " discovered a Void Touched snack!")
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
end

return CollectionService
