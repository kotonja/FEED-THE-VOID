local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ProfileServiceWrapper = {}

local profiles = {}
local dirty = {}
local dataStore = nil
local warnedMemoryFallback = false

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function mergeDefaults(data, defaults)
	data = type(data) == "table" and data or {}
	for key, value in pairs(defaults) do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" then
			data[key] = mergeDefaults(data[key], value)
		end
	end
	return data
end

local function migrateUpgradeLevel(value, perLevel)
	value = tonumber(value) or 0
	if value <= 0 then
		return 0
	end
	if value > 0 and value <= 1 then
		return 0
	end
	if value > 1 and value < 4 then
		return math.clamp(math.floor(((value - 1) / perLevel) + 0.5), 0, 10)
	end
	return math.clamp(math.floor(value), 0, 10)
end

local function itemDisplayName(context, snackId, mutationId)
	local snack = context.Config.SnackConfig[snackId]
	local mutation = context.Config.MutationConfig[mutationId or "Normal"]
	if not snack then
		return tostring(snackId)
	end
	if not mutation or mutationId == "Normal" then
		return snack.DisplayName or snackId
	end
	return tostring(mutation.DisplayName or mutationId) .. " " .. tostring(snack.DisplayName or snackId)
end

local function sanitizeItemList(context, items, maxCount)
	local result = {}
	if type(items) ~= "table" then
		return result
	end
	for _, item in ipairs(items) do
		if type(item) == "table" and type(item.SnackId) == "string" and context.Config.SnackConfig[item.SnackId] then
			local mutationId = type(item.MutationId) == "string" and item.MutationId or "Normal"
			if not context.Config.MutationConfig[mutationId] then
				mutationId = "Normal"
			end
			local mutation = context.Config.MutationConfig[mutationId] or context.Config.MutationConfig.Normal
			item.MutationId = mutationId
			item.UniqueId = tostring(item.UniqueId or HttpService:GenerateGUID(false))
			item.CreatedAt = tonumber(item.CreatedAt) or os.time()
			item.ValueMultiplier = tonumber(item.ValueMultiplier) or (mutation and mutation.ValueMultiplier) or 1
			item.DisplayName = itemDisplayName(context, item.SnackId, mutationId)
			item.Locked = item.Locked == true
			table.insert(result, item)
			if #result >= maxCount then
				break
			end
		end
	end
	return result
end

local function sanitizePlantedSnacks(context, planted, maxCount)
	local result = {}
	if type(planted) ~= "table" then
		return result
	end
	for _, record in ipairs(planted) do
		if type(record) == "table" and type(record.SnackId) == "string" and context.Config.SnackConfig[record.SnackId] then
			local plateName = type(record.PlateName) == "string" and record.PlateName or ("Plate" .. tostring(tonumber(record.PlateId) or 1))
			table.insert(result, {
				UniqueId = tostring(record.UniqueId or HttpService:GenerateGUID(false)),
				SnackId = record.SnackId,
				PlateName = plateName,
				PlateId = tonumber(record.PlateId) or tonumber(plateName:match("(%d+)")) or 1,
				PlantedAt = tonumber(record.PlantedAt) or os.time(),
				GrowTime = math.max(1, tonumber(record.GrowTime) or context.Config.SnackConfig[record.SnackId].GrowTime or 30),
				CurrentStage = math.clamp(math.floor(tonumber(record.CurrentStage) or 1), 1, 3),
			})
			if #result >= maxCount then
				break
			end
		elseif context.Config.GameConfig.DebugMode then
			warn("[FEED THE VOID] Skipped malformed planted snack during migration.")
		end
	end
	return result
end

local function defaultData(context)
	local gameConfig = context.Config.GameConfig
	return {
		DataVersion = gameConfig.DataVersion or 1,
		Coins = gameConfig.StartingCoins,
		VoidTokens = 0,
		Rebirths = 0,
		Seeds = deepCopy(gameConfig.StartingSeeds),
		Inventory = {},
		DisplayedSnacks = {},
		PlantedSnacks = {},
		Upgrades = {
			Plates = gameConfig.PlateCount,
			GrowSpeed = 0,
			SellMultiplier = 0,
			VoidRewardMultiplier = 0,
			DisplayIncome = 0,
			VoidmiteReward = 0,
		},
		Collections = {
			Snacks = {},
			Mutations = {},
			Combos = {},
			RewardClaims = {},
			ClaimedMilestones = {},
		},
		Quests = {
			Active = {},
			CompletedCount = 0,
		},
		TutorialStep = 1,
		TutorialCompleted = false,
		AssignedPlotId = 0,
		Failsafes = {
			LastEmergencySeedAt = 0,
			LastTeleportToPlotAt = 0,
		},
		Stats = {
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
		},
		DailyReward = {
			LastClaimTime = 0,
			Streak = 0,
		},
		PlaytimeRewards = {
			LastSessionStart = os.time(),
			ClaimedThisSession = {},
		},
		BadgesAwarded = {},
		Settings = deepCopy(gameConfig.SettingsDefaults or {}),
		Shop = {},
		LastOfflineRewards = nil,
		LastLogin = 0,
		LastLogout = 0,
	}
end

local function migrateData(context, data)
	data = mergeDefaults(data, defaultData(context))
	local gameConfig = context.Config.GameConfig
	local old = type(data.Upgrades) == "table" and data.Upgrades or {}
	data.Upgrades = {
		Plates = math.clamp(tonumber(old.Plates) or gameConfig.PlateCount, gameConfig.PlateCount, gameConfig.MaxPlateCount),
		GrowSpeed = migrateUpgradeLevel(old.GrowSpeed, 0.05),
		SellMultiplier = migrateUpgradeLevel(old.SellMultiplier, 0.10),
		VoidRewardMultiplier = migrateUpgradeLevel(old.VoidRewardMultiplier, 0.10),
		DisplayIncome = migrateUpgradeLevel(old.DisplayIncome, 0.10),
		VoidmiteReward = migrateUpgradeLevel(old.VoidmiteReward, 0.10),
	}
	data.Collections = data.Collections or {}
	data.Collections.Snacks = data.Collections.Snacks or {}
	data.Collections.Mutations = data.Collections.Mutations or {}
	data.Collections.Combos = data.Collections.Combos or {}
	data.Collections.RewardClaims = data.Collections.RewardClaims or {}
	data.Collections.ClaimedMilestones = data.Collections.ClaimedMilestones or data.Collections.RewardClaims or {}
	data.Collections.RewardClaims = data.Collections.ClaimedMilestones
	data.Quests = data.Quests or { Active = {}, CompletedCount = 0 }
	data.Quests.Active = type(data.Quests.Active) == "table" and data.Quests.Active or {}
	data.Quests.CompletedCount = tonumber(data.Quests.CompletedCount) or 0
	local anti = gameConfig.AntiExploit or {}
	data.Inventory = sanitizeItemList(context, data.Inventory, anti.MaxInventoryItems or 120)
	data.DisplayedSnacks = sanitizeItemList(context, data.DisplayedSnacks, anti.MaxDisplayedSnacks or 40)
	data.PlantedSnacks = sanitizePlantedSnacks(context, data.PlantedSnacks, anti.MaxPlantedSnacks or gameConfig.MaxPlateCount or 10)
	data.Seeds = type(data.Seeds) == "table" and data.Seeds or deepCopy(gameConfig.StartingSeeds)
	for seedId, count in pairs(gameConfig.StartingSeeds or {}) do
		data.Seeds[seedId] = tonumber(data.Seeds[seedId]) or count
	end
	for seedId, count in pairs(data.Seeds) do
		if not gameConfig.StartingSeeds[seedId] and not context.Config.SnackConfig[seedId] then
			data.Seeds[seedId] = nil
		else
			data.Seeds[seedId] = math.clamp(math.floor(tonumber(count) or 0), 0, anti.MaxSeedsPerType or 999)
		end
	end
	data.TutorialStep = tonumber(data.TutorialStep) or 1
	data.TutorialCompleted = data.TutorialCompleted == true
	if data.TutorialStep > #(gameConfig.TutorialMessages or {}) then
		data.TutorialCompleted = true
	end
	data.AssignedPlotId = math.max(0, math.floor(tonumber(data.AssignedPlotId) or 0))
	data.Failsafes = type(data.Failsafes) == "table" and data.Failsafes or {}
	data.Failsafes.LastEmergencySeedAt = tonumber(data.Failsafes.LastEmergencySeedAt) or 0
	data.Failsafes.LastTeleportToPlotAt = tonumber(data.Failsafes.LastTeleportToPlotAt) or 0
	data.Stats = type(data.Stats) == "table" and data.Stats or {}
	for key, value in pairs(defaultData(context).Stats) do
		data.Stats[key] = tonumber(data.Stats[key]) or value
	end
	data.DailyReward = type(data.DailyReward) == "table" and data.DailyReward or {}
	data.DailyReward.LastClaimTime = tonumber(data.DailyReward.LastClaimTime) or 0
	data.DailyReward.Streak = tonumber(data.DailyReward.Streak) or 0
	data.PlaytimeRewards = {
		LastSessionStart = os.time(),
		ClaimedThisSession = {},
	}
	data.BadgesAwarded = type(data.BadgesAwarded) == "table" and data.BadgesAwarded or {}
	data.Shop = type(data.Shop) == "table" and data.Shop or {}
	data.LastOfflineRewards = nil
	data.Settings = type(data.Settings) == "table" and data.Settings or {}
	for key, value in pairs(gameConfig.SettingsDefaults or {}) do
		if data.Settings[key] == nil then
			data.Settings[key] = value
		else
			data.Settings[key] = data.Settings[key] == true
		end
	end
	data.DataVersion = gameConfig.DataVersion or data.DataVersion or 1
	data.LastLogin = tonumber(data.LastLogin) or 0
	data.LastLogout = tonumber(data.LastLogout) or 0
	return data
end

local function profileKey(player)
	return "player_" .. tostring(player.UserId)
end

function ProfileServiceWrapper.Init(context)
	ProfileServiceWrapper.Context = context
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore(context.Config.GameConfig.ProfileStoreName or "FeedTheVoid_Phase5_v2")
	end)
	if ok then
		dataStore = storeOrError
	else
		warn("[FEED THE VOID] DataStore unavailable; using memory profiles. " .. tostring(storeOrError))
	end
end

function ProfileServiceWrapper.Start()
	task.spawn(function()
		while true do
			task.wait(60)
			ProfileServiceWrapper.SaveAll()
		end
	end)
	game:BindToClose(function()
		ProfileServiceWrapper.SaveAll()
	end)
end

function ProfileServiceWrapper.LoadPlayer(player)
	local data = nil
	if dataStore then
		local ok, result = pcall(function()
			return dataStore:GetAsync(profileKey(player))
		end)
		if ok then
			data = result
		else
			if not warnedMemoryFallback then
				print("[FEED THE VOID] DataStore load failed; continuing with memory data. Enable Studio API access to test persistence.", result)
				warnedMemoryFallback = true
			end
		end
	end
	data = migrateData(ProfileServiceWrapper.Context, data)
	data.LastLogin = os.time()
	data.PlaytimeRewards.LastSessionStart = os.time()
	data.PlaytimeRewards.ClaimedThisSession = {}
	profiles[player] = {
		Data = data,
		LoadedAt = os.time(),
	}
	dirty[player] = false
	return profiles[player]
end

function ProfileServiceWrapper.GetProfile(player)
	return profiles[player]
end

function ProfileServiceWrapper.GetData(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function ProfileServiceWrapper.MarkDirty(player)
	if profiles[player] then
		dirty[player] = true
	end
end

function ProfileServiceWrapper.SavePlayer(player)
	local profile = profiles[player]
	if not profile then
		return true
	end
	profile.Data.LastLogout = os.time()
	if not dataStore then
		dirty[player] = false
		return true
	end
	if not dirty[player] then
		return true
	end
	local ok, err = pcall(function()
		dataStore:SetAsync(profileKey(player), profile.Data)
	end)
	if ok then
		dirty[player] = false
		return true
	end
	print("[FEED THE VOID] DataStore save failed; session data remains in memory.", err)
	return false
end

function ProfileServiceWrapper.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		ProfileServiceWrapper.SavePlayer(player)
	end
end

function ProfileServiceWrapper.ReleasePlayer(player)
	if ProfileServiceWrapper.Context.Services.StatsService then
		ProfileServiceWrapper.Context.Services.StatsService.UpdatePlaytime(player)
	end
	ProfileServiceWrapper.SavePlayer(player)
	profiles[player] = nil
	dirty[player] = nil
end

function ProfileServiceWrapper.ResetPlayerData(player)
	local data = migrateData(ProfileServiceWrapper.Context, nil)
	profiles[player] = {
		Data = data,
		LoadedAt = os.time(),
	}
	dirty[player] = true
	return data
end

return ProfileServiceWrapper
