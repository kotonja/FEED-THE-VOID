local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

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

local function defaultData(context)
	local gameConfig = context.Config.GameConfig
	return {
		Coins = gameConfig.StartingCoins,
		VoidTokens = 0,
		Rebirths = 0,
		Seeds = deepCopy(gameConfig.StartingSeeds),
		Inventory = {},
		DisplayedSnacks = {},
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
		},
		Quests = {
			Active = {},
			CompletedCount = 0,
		},
		TutorialStep = 1,
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
	data.Quests = data.Quests or { Active = {}, CompletedCount = 0 }
	data.Quests.Active = type(data.Quests.Active) == "table" and data.Quests.Active or {}
	data.Quests.CompletedCount = tonumber(data.Quests.CompletedCount) or 0
	data.Inventory = type(data.Inventory) == "table" and data.Inventory or {}
	data.DisplayedSnacks = type(data.DisplayedSnacks) == "table" and data.DisplayedSnacks or {}
	data.Seeds = type(data.Seeds) == "table" and data.Seeds or deepCopy(gameConfig.StartingSeeds)
	data.TutorialStep = tonumber(data.TutorialStep) or 1
	data.LastLogout = tonumber(data.LastLogout) or 0
	return data
end

local function profileKey(player)
	return "player_" .. tostring(player.UserId)
end

function ProfileServiceWrapper.Init(context)
	ProfileServiceWrapper.Context = context
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore("FeedTheVoid_Phase15_v1")
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
	data.LastLogout = os.time()
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
	ProfileServiceWrapper.SavePlayer(player)
	profiles[player] = nil
	dirty[player] = nil
end

return ProfileServiceWrapper
