local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ProfileServiceWrapper = {}

local DEFAULT_DATA = {
	Coins = 100,
	VoidTokens = 0,
	Rebirths = 0,
	Seeds = {
		CookieRock = 3,
	},
	Inventory = {},
	DisplayedSnacks = {},
	Upgrades = {
		Plates = 6,
		GrowSpeed = 1,
		SellMultiplier = 1,
		VoidRewardMultiplier = 1,
	},
	TutorialStep = 1,
	LastLogout = 0,
}

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

local function profileKey(player)
	return "player_" .. tostring(player.UserId)
end

function ProfileServiceWrapper.Init(context)
	ProfileServiceWrapper.Context = context
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore("FeedTheVoid_Phase1_v1")
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
				warn("[FEED THE VOID] DataStore load failed; continuing with memory data. Enable Studio API access to test persistence.")
				warn(result)
				warnedMemoryFallback = true
			end
		end
	end

	data = mergeDefaults(data, DEFAULT_DATA)
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
	local data = profile.Data
	local ok, err = pcall(function()
		dataStore:SetAsync(profileKey(player), data)
	end)
	if ok then
		dirty[player] = false
		return true
	end
	warn("[FEED THE VOID] DataStore save failed; session data remains in memory.", err)
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
