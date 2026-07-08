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
	data.Collections.ClaimedMilestones = data.Collections.ClaimedMilestones or data.Collections.RewardClaims or {}
	data.Collections.RewardClaims = data.Collections.ClaimedMilestones
	return data.Collections
end

local function countSnacksByRarity(context, collections, rarity)
	local discovered = 0
	local total = 0
	for _, snackId in ipairs(context.Config.SnackConfig.Order or {}) do
		local snack = context.Config.SnackConfig[snackId]
		if snack and snack.Rarity == rarity then
			total += 1
			if collections.Snacks[snackId] then
				discovered += 1
			end
		end
	end
	return discovered, total
end

local function milestoneProgress(context, collections, milestone)
	if milestone.Kind == "SnackTypes" then
		return countKeys(collections.Snacks), milestone.Target
	end
	if milestone.Kind == "Mutations" then
		return countKeys(collections.Mutations), milestone.Target
	end
	if milestone.Kind == "Combos" then
		return countKeys(collections.Combos), milestone.Target
	end
	if milestone.Kind == "Mutation" then
		return collections.Mutations[milestone.MutationId] and 1 or 0, 1
	end
	if milestone.Kind == "AllRarity" then
		return countSnacksByRarity(context, collections, milestone.Rarity)
	end
	return 0, 1
end

local function milestoneReady(context, collections, milestone)
	local progress, target = milestoneProgress(context, collections, milestone)
	return target > 0 and progress >= target, progress, target
end

local function rewardText(reward)
	local parts = {}
	if reward.Coins and reward.Coins > 0 then
		table.insert(parts, tostring(reward.Coins) .. " coins")
	end
	if reward.VoidTokens and reward.VoidTokens > 0 then
		table.insert(parts, tostring(reward.VoidTokens) .. " Void Tokens")
	end
	for seedId, count in pairs(reward.Seeds or {}) do
		table.insert(parts, tostring(count) .. " " .. tostring(seedId) .. " seed")
	end
	return #parts > 0 and table.concat(parts, " + ") or "Reward"
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
	local collections = data and ensure(data) or { Snacks = {}, Mutations = {}, Combos = {}, ClaimedMilestones = {} }
	local snackList = {}
	for _, snackId in ipairs(context.Config.SnackConfig.Order) do
		local snack = context.Config.SnackConfig[snackId]
		table.insert(snackList, {
			Id = snackId,
			Name = collections.Snacks[snackId] and snack.DisplayName or "???",
			Unlocked = collections.Snacks[snackId] == true,
			Rarity = snack.Rarity,
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
	local milestones = {}
	for _, milestone in ipairs(context.Config.GameConfig.CollectionMilestones or {}) do
		local ready, progress, target = milestoneReady(context, collections, milestone)
		local claimed = collections.ClaimedMilestones[milestone.Id] == true
		table.insert(milestones, {
			Id = milestone.Id,
			Text = milestone.Text,
			Progress = progress,
			Target = target,
			Ready = ready and not claimed,
			Claimed = claimed,
			RewardText = rewardText(milestone),
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
		Milestones = milestones,
		ClaimedMilestones = collections.ClaimedMilestones,
	}
end

function CollectionService.ClaimMilestone(player, milestoneId)
	local context = CollectionService.Context
	if (context.Config.FeatureFlags or {}).CollectionMilestones == false then
		context.Services.EconomyService.Notify(player, "Collection rewards are disabled for this test.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data or type(milestoneId) ~= "string" then
		return false
	end
	local collections = ensure(data)
	local found = nil
	for _, milestone in ipairs(context.Config.GameConfig.CollectionMilestones or {}) do
		if milestone.Id == milestoneId then
			found = milestone
			break
		end
	end
	if not found then
		context.Services.EconomyService.Notify(player, "That collection reward does not exist.")
		return false
	end
	if collections.ClaimedMilestones[found.Id] then
		context.Services.EconomyService.Notify(player, "Collection reward already claimed.")
		return false
	end
	local ready = milestoneReady(context, collections, found)
	if not ready then
		context.Services.EconomyService.Notify(player, "That collection reward is not ready yet.")
		return false
	end
	collections.ClaimedMilestones[found.Id] = true
	if found.Coins then
		context.Services.EconomyService.AddCoins(player, found.Coins)
	end
	if found.VoidTokens then
		context.Services.EconomyService.AddVoidTokens(player, found.VoidTokens)
	end
	for seedId, count in pairs(found.Seeds or {}) do
		context.Services.EconomyService.AddSeeds(player, seedId, count, false)
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Notify(player, "Collection reward claimed: " .. rewardText(found) .. ".")
	if context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.CollectionMilestone(player, found.Text)
	end
	context.Services.EconomyService.Sync(player)
	return true
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
		context.Services.QuestService.Record(player, "DiscoverSnack", 1)
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
	local snack = context.Config.SnackConfig[snackId]
	if snack and context.Config.RarityConfig.IsAtLeast(snack.Rarity, "Rare") then
		context.Services.QuestService.Record(player, "HarvestRarePlus", 1)
	end
	if firstDiscovery then
		context.Services.StatsService.Record(player, "Discoveries", 1)
		context.Services.EconomyService.AddCoins(player, 20)
		if rareMutations[mutationId] then
			context.Services.EconomyService.AddVoidTokens(player, 1)
		end
		context.Services.EconomyService.Notify(player, "New discovery: " .. tostring(item.DisplayName) .. "!")
	end
	if mutationId == "VoidTouched" then
		context.Services.BadgeAwardService.Award(player, "FirstVoidTouched")
		if context.Services.ActivityFeedService then
			context.Services.ActivityFeedService.Announce("first_voidtouched_" .. tostring(player.UserId), player.DisplayName .. " discovered " .. tostring(item.DisplayName) .. "!", 8)
		end
	end
	if mutationId == "Glitched" and context.Services.ActivityFeedService then
		context.Services.ActivityFeedService.Announce("first_glitched_" .. tostring(player.UserId), player.DisplayName .. " discovered " .. tostring(item.DisplayName) .. "!", 8)
	end
	if countKeys(collections.Snacks) + countKeys(collections.Mutations) >= 10 then
		context.Services.BadgeAwardService.Award(player, "TenDiscoveries")
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
end

return CollectionService
