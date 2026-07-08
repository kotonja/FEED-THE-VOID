const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "build", "feed_the_void_phase1");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase1.blueprint.json");
const repairBlueprintPath = path.join(outDir, "feed_the_void_phase1_repair.blueprint.json");

fs.mkdirSync(srcDir, { recursive: true });

const v3 = (x, y, z) => ({ __type: "Vector3", x, y, z });
const v2 = (x, y) => ({ __type: "Vector2", x, y });
const c3 = (r, g, b) => ({ __type: "Color3", mode: "rgb", r, g, b });
const ud2 = (xScale, xOffset, yScale, yOffset) => ({
  __type: "UDim2",
  xScale,
  xOffset,
  yScale,
  yOffset,
});

function step(type, pathName, extra = {}) {
  return { type, path: pathName, ...extra };
}

function writeSource(name, source) {
  const filePath = path.join(srcDir, name);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, source.replace(/\r\n/g, "\n"), "utf8");
  return path.relative(outDir, filePath).replace(/\\/g, "/");
}

const sources = {
  "shared/GameConfig.lua": `local GameConfig = {
	StartingCoins = 100,
	StartingSeeds = {
		CookieRock = 3,
	},
	MaxPlayersPerServerTarget = 8,
	PlateCount = 6,
	BaseDisplayIncomeInterval = 10,
	VoidHungerRequired = 100,
	RemoteCooldown = 0.25,
	VoidmiteBaseInterval = 18,
	RebirthCost = 5000,
}

return GameConfig
`,

  "shared/SnackConfig.lua": `local SnackConfig = {
	CookieRock = {
		DisplayName = "Cookie Rock",
		SeedCost = 10,
		GrowTime = 20,
		BaseSellValue = 25,
		BaseVoidValue = 10,
		Rarity = "Common",
		Color = Color3.fromRGB(185, 164, 132),
	},
	JellyCube = {
		DisplayName = "Jelly Cube",
		SeedCost = 25,
		GrowTime = 35,
		BaseSellValue = 70,
		BaseVoidValue = 22,
		Rarity = "Uncommon",
		Color = Color3.fromRGB(92, 220, 225),
	},
	MeteorMuffin = {
		DisplayName = "Meteor Muffin",
		SeedCost = 100,
		GrowTime = 60,
		BaseSellValue = 250,
		BaseVoidValue = 60,
		Rarity = "Rare",
		Color = Color3.fromRGB(220, 92, 76),
	},
}

return SnackConfig
`,

  "shared/MutationConfig.lua": `local MutationConfig = {
	Normal = {
		Weight = 700,
		ValueMultiplier = 1,
		Color = Color3.fromRGB(235, 235, 225),
		ScaleMultiplier = 1,
	},
	Big = {
		Weight = 120,
		ValueMultiplier = 1.5,
		ScaleMultiplier = 1.35,
	},
	Golden = {
		Weight = 80,
		ValueMultiplier = 3,
		Color = Color3.fromRGB(255, 205, 58),
		ScaleMultiplier = 1.05,
	},
	Rainbow = {
		Weight = 25,
		ValueMultiplier = 8,
		Color = Color3.fromRGB(255, 88, 205),
		ScaleMultiplier = 1.1,
	},
	VoidTouched = {
		Weight = 10,
		ValueMultiplier = 15,
		Color = Color3.fromRGB(70, 24, 110),
		ScaleMultiplier = 1.15,
	},
}

return MutationConfig
`,

  "shared/EventConfig.lua": `local EventConfig = {
	SnackRain = {
		DisplayName = "Snack Rain",
		Duration = 45,
	},
	MutationSurge = {
		DisplayName = "Mutation Surge",
		Duration = 90,
		RareWeightMultiplier = 3,
	},
	VoidInfestation = {
		DisplayName = "Void Infestation",
		Duration = 20,
	},
}

return EventConfig
`,

  "shared/FormatNumbers.lua": `local FormatNumbers = {}

function FormatNumbers.Compact(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	end
	if value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(math.floor(value + 0.5))
end

return FormatNumbers
`,

  "server/Services/AnalyticsService.lua": `local AnalyticsService = {}

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
`,

  "server/Services/ProfileServiceWrapper.lua": `local Players = game:GetService("Players")
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
`,

  "server/Services/EconomyService.lua": `local EconomyService = {}

function EconomyService.Init(context)
	EconomyService.Context = context
end

function EconomyService.Start() end

function EconomyService.GetData(player)
	return EconomyService.Context.Services.ProfileServiceWrapper.GetData(player)
end

function EconomyService.Sync(player)
	local data = EconomyService.GetData(player)
	if not data then
		return
	end
	EconomyService.Context.Remotes.SyncPlayerData:FireClient(player, {
		Coins = data.Coins,
		VoidTokens = data.VoidTokens,
		Rebirths = data.Rebirths,
		Seeds = data.Seeds,
		Inventory = data.Inventory,
		DisplayedSnacks = data.DisplayedSnacks,
		Upgrades = data.Upgrades,
		VoidHunger = EconomyService.Context.Services.VoidService.GetHunger(),
		VoidHungerRequired = EconomyService.Context.Config.GameConfig.VoidHungerRequired,
	})
end

function EconomyService.SyncAll()
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		EconomyService.Sync(player)
	end
end

function EconomyService.Notify(player, message)
	if player then
		EconomyService.Context.Remotes.NotifyClient:FireClient(player, message)
	end
end

function EconomyService.NotifyAll(message)
	EconomyService.Context.Remotes.NotifyClient:FireAllClients(message)
end

function EconomyService.AddCoins(player, amount)
	local data = EconomyService.GetData(player)
	if not data then
		return false
	end
	data.Coins += math.max(0, math.floor(amount))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.SpendCoins(player, amount)
	local data = EconomyService.GetData(player)
	amount = math.max(0, math.floor(amount))
	if not data or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.AddVoidTokens(player, amount)
	local data = EconomyService.GetData(player)
	if not data then
		return false
	end
	data.VoidTokens += math.max(0, math.floor(amount))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

return EconomyService
`,

  "server/Services/InventoryService.lua": `local HttpService = game:GetService("HttpService")

local InventoryService = {}

function InventoryService.Init(context)
	InventoryService.Context = context
end

function InventoryService.Start() end

function InventoryService.GetData(player)
	return InventoryService.Context.Services.ProfileServiceWrapper.GetData(player)
end

function InventoryService.AddItem(player, item)
	local data = InventoryService.GetData(player)
	if not data then
		return nil
	end
	item.UniqueId = item.UniqueId or HttpService:GenerateGUID(false)
	table.insert(data.Inventory, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.FindItem(player, itemId)
	local data = InventoryService.GetData(player)
	if not data then
		return nil, nil
	end
	if itemId == nil or itemId == "" then
		return data.Inventory[1], 1
	end
	for index, item in ipairs(data.Inventory) do
		if item.UniqueId == itemId then
			return item, index
		end
	end
	return nil, nil
end

function InventoryService.RemoveItem(player, itemId)
	local data = InventoryService.GetData(player)
	local item, index = InventoryService.FindItem(player, itemId)
	if not data or not item or not index then
		return nil
	end
	table.remove(data.Inventory, index)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.AddDisplayed(player, item)
	local data = InventoryService.GetData(player)
	if not data then
		return
	end
	table.insert(data.DisplayedSnacks, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
end

function InventoryService.RemoveDisplayedByWorldId(player, worldId)
	local data = InventoryService.GetData(player)
	if not data then
		return
	end
	for index, item in ipairs(data.DisplayedSnacks) do
		if item.WorldId == worldId then
			table.remove(data.DisplayedSnacks, index)
			InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
			InventoryService.Context.Services.EconomyService.Sync(player)
			return item
		end
	end
	return nil
end

return InventoryService
`,

  "server/Services/PlotService.lua": `local Players = game:GetService("Players")

local PlotService = {}

local plots = {}
local playerPlots = {}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function getLabel(plot)
	local sign = plot:FindFirstChild("OwnerSign")
	if not sign then
		return nil
	end
	local gui = sign:FindFirstChild("OwnerBillboard")
	return gui and gui:FindFirstChild("OwnerLabel") or nil
end

function PlotService.Init(context)
	PlotService.Context = context
	local plotsFolder = getWorld():WaitForChild("Plots")
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then
			local plotId = tonumber(plot:GetAttribute("PlotId"))
			if plotId then
				plots[plotId] = plot
				plot:SetAttribute("OwnerUserId", 0)
				local label = getLabel(plot)
				if label then
					label.Text = "EMPTY PLOT"
				end
			end
		end
	end
end

function PlotService.Start() end

function PlotService.AssignPlot(player)
	for plotId, plot in pairs(plots) do
		if not plot:GetAttribute("OwnerUserId") or plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			playerPlots[player] = plot
			local label = getLabel(plot)
			if label then
				label.Text = player.Name .. "'s Lab"
			end
			PlotService.Context.Services.EconomyService.Notify(player, "Your lab plot is ready. Find a plate and plant Cookie Rock.")
			PlotService.TeleportToPlot(player)
			return plot
		end
	end
	PlotService.Context.Services.EconomyService.Notify(player, "No open plots yet. Try again in a moment.")
	return nil
end

function PlotService.TeleportToPlot(player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	local spawnPart = plot:FindFirstChild("PlotSpawn")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if spawnPart and root then
		root.CFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
	end
end

function PlotService.ReleasePlot(player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	plot:SetAttribute("OwnerUserId", 0)
	local label = getLabel(plot)
	if label then
		label.Text = "EMPTY PLOT"
	end
	playerPlots[player] = nil
end

function PlotService.GetPlot(player)
	return playerPlots[player]
end

function PlotService.GetPlotOwner(plot)
	local ownerUserId = plot and tonumber(plot:GetAttribute("OwnerUserId"))
	if not ownerUserId or ownerUserId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(ownerUserId)
end

function PlotService.FindPlotFromInstance(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("PlotId") then
			return current
		end
		current = current.Parent
	end
	return nil
end

function PlotService.PlayerOwnsPlot(player, plot)
	return plot and tonumber(plot:GetAttribute("OwnerUserId")) == player.UserId
end

function PlotService.GetPlots()
	return plots
end

return PlotService
`,

  "server/Services/VoidService.lua": `local VoidService = {}

local hunger = 0

local function updateBillboard(context)
	local world = workspace:FindFirstChild("GameWorld")
	local central = world and world:FindFirstChild("CentralVoid")
	local core = central and central:FindFirstChild("VoidCore")
	local gui = core and core:FindFirstChild("VoidBillboard")
	local label = gui and gui:FindFirstChild("HungerLabel")
	local fill = gui and gui:FindFirstChild("MeterBack") and gui.MeterBack:FindFirstChild("MeterFill")
	local required = context.Config.GameConfig.VoidHungerRequired
	if label then
		label.Text = "THE VOID - " .. tostring(math.floor(hunger)) .. "/" .. tostring(required)
	end
	if fill then
		fill.Size = UDim2.new(math.clamp(hunger / required, 0, 1), 0, 1, 0)
	end
end

function VoidService.Init(context)
	VoidService.Context = context
	updateBillboard(context)
end

function VoidService.Start() end

function VoidService.GetHunger()
	return hunger
end

function VoidService.AddHunger(player, amount)
	local context = VoidService.Context
	local required = context.Config.GameConfig.VoidHungerRequired
	hunger += math.max(0, amount)
	context.Services.EconomyService.NotifyAll(player.Name .. " fed the Void. It rumbles happily.")
	if hunger >= required then
		hunger = 0
		updateBillboard(context)
		context.Services.EconomyService.NotifyAll("THE VOID IS FULL. Something strange begins.")
		context.Services.EventService.StartRandomEvent()
	else
		updateBillboard(context)
	end
	context.Services.EconomyService.SyncAll()
end

return VoidService
`,

  "server/Services/EventService.lua": `local EventService = {}

local activeEvents = {}

local function clearEventObjects()
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end
end

local function spawnSnackRainCrumb(index)
	local context = EventService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if not folder then
		return
	end
	local angle = (index / 18) * math.pi * 2
	local radius = 18 + (index % 5) * 7
	local part = Instance.new("Part")
	part.Name = "SnackRainCrumb_" .. tostring(index)
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 180, 80)
	part.Size = Vector3.new(2.2, 2.2, 2.2)
	part.Position = Vector3.new(math.cos(angle) * radius, 2.8, math.sin(angle) * radius)
	part:SetAttribute("RewardCoins", 12)
	part.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Collect Snack Crumb"
	prompt.ObjectText = "Snack Rain"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part.Parent then
			part:Destroy()
			context.Services.EconomyService.AddCoins(player, 12)
			local data = context.Services.ProfileServiceWrapper.GetData(player)
			if data then
				data.Seeds.CookieRock = (data.Seeds.CookieRock or 0) + 1
				context.Services.ProfileServiceWrapper.MarkDirty(player)
				context.Services.EconomyService.Sync(player)
			end
			context.Services.EconomyService.Notify(player, "Snack crumb collected: +12 coins and +1 Cookie Rock seed.")
		end
	end)
end

function EventService.Init(context)
	EventService.Context = context
end

function EventService.Start() end

function EventService.IsActive(eventName)
	return activeEvents[eventName] == true
end

function EventService.StartEvent(eventName)
	local context = EventService.Context
	if activeEvents[eventName] then
		return
	end
	activeEvents[eventName] = true
	context.Services.AnalyticsService.VoidEventStarted(eventName)
	context.Services.EconomyService.NotifyAll(eventName .. " has started!")

	if eventName == "SnackRain" then
		clearEventObjects()
		for index = 1, 18 do
			spawnSnackRainCrumb(index)
		end
		task.delay(context.Config.EventConfig.SnackRain.Duration, function()
			activeEvents.SnackRain = nil
			clearEventObjects()
			context.Services.EconomyService.NotifyAll("Snack Rain ended.")
		end)
	elseif eventName == "MutationSurge" then
		task.delay(context.Config.EventConfig.MutationSurge.Duration, function()
			activeEvents.MutationSurge = nil
			context.Services.EconomyService.NotifyAll("Mutation Surge faded.")
		end)
	elseif eventName == "VoidInfestation" then
		context.Services.VoidmiteService.SpawnInfestation()
		task.delay(context.Config.EventConfig.VoidInfestation.Duration, function()
			activeEvents.VoidInfestation = nil
		end)
	end
end

function EventService.StartRandomEvent()
	local events = { "SnackRain", "MutationSurge", "VoidInfestation" }
	EventService.StartEvent(events[math.random(1, #events)])
end

return EventService
`,

  "server/Services/VoidmiteService.lua": `local Players = game:GetService("Players")

local VoidmiteService = {}

local nextSpawnCheck = {}

local function getFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("ActiveVoidmites")
end

local function ownerPlayerFromUserId(userId)
	userId = tonumber(userId)
	return userId and Players:GetPlayerByUserId(userId) or nil
end

local function spawnVoidmiteForDisplay(displayModel)
	local context = VoidmiteService.Context
	local folder = getFolder()
	if not folder or not displayModel or not displayModel.Parent then
		return
	end
	local ownerUserId = tonumber(displayModel:GetAttribute("OwnerUserId"))
	local plotId = tonumber(displayModel:GetAttribute("PlotId"))
	local reward = math.max(5, math.floor((tonumber(displayModel:GetAttribute("DisplayValue")) or 10) * 0.18))
	local origin = displayModel:GetPivot().Position

	local part = Instance.new("Part")
	part.Name = "Voidmite_" .. tostring(os.clock()):gsub("%.", "_")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(80, 30, 135)
	part.Size = Vector3.new(1.3, 1.3, 1.3)
	part.Position = origin + Vector3.new(math.random(-5, 5), 1.2, math.random(-4, 4))
	part:SetAttribute("OwnerUserId", ownerUserId)
	part:SetAttribute("PlotId", plotId)
	part:SetAttribute("RewardValue", reward)
	part.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleansePrompt"
	prompt.ActionText = "Cleanse Voidmite"
	prompt.ObjectText = "Voidmite"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		VoidmiteService.ClearVoidmite(player, part)
	end)
end

function VoidmiteService.Init(context)
	VoidmiteService.Context = context
end

function VoidmiteService.Start()
	task.spawn(function()
		while true do
			task.wait(4)
			VoidmiteService.SpawnTick()
		end
	end)
end

function VoidmiteService.SpawnTick()
	local context = VoidmiteService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local snacksFolder = world and world:FindFirstChild("ActiveSnacks")
	if not snacksFolder then
		return
	end
	for _, model in ipairs(snacksFolder:GetChildren()) do
		if model:GetAttribute("Displayed") == true then
			local worldId = model:GetAttribute("WorldId")
			local value = tonumber(model:GetAttribute("DisplayValue")) or 10
			local interval = math.max(8, context.Config.GameConfig.VoidmiteBaseInterval - math.clamp(value / 80, 0, 10))
			local due = nextSpawnCheck[worldId] or (os.clock() + interval)
			if os.clock() >= due then
				nextSpawnCheck[worldId] = os.clock() + interval + math.random(0, 5)
				spawnVoidmiteForDisplay(model)
			end
		end
	end
end

function VoidmiteService.SpawnInfestation()
	local world = workspace:FindFirstChild("GameWorld")
	local snacksFolder = world and world:FindFirstChild("ActiveSnacks")
	if not snacksFolder then
		return
	end
	for _, model in ipairs(snacksFolder:GetChildren()) do
		if model:GetAttribute("Displayed") == true then
			spawnVoidmiteForDisplay(model)
		end
	end
end

function VoidmiteService.ClearVoidmite(player, voidmite)
	local context = VoidmiteService.Context
	if not voidmite or not voidmite:IsDescendantOf(workspace) or voidmite.Name:sub(1, 9) ~= "Voidmite_" then
		context.Services.EconomyService.Notify(player, "That Voidmite is already gone.")
		return false
	end
	local reward = tonumber(voidmite:GetAttribute("RewardValue")) or 5
	local ownerUserId = tonumber(voidmite:GetAttribute("OwnerUserId"))
	local ownerPlayer = ownerPlayerFromUserId(ownerUserId)
	voidmite:Destroy()
	context.Services.EconomyService.AddCoins(player, reward)
	context.Services.EconomyService.AddVoidTokens(player, 1)
	if ownerPlayer and ownerPlayer ~= player then
		local ownerReward = math.max(2, math.floor(reward * 0.5))
		context.Services.EconomyService.AddCoins(ownerPlayer, ownerReward)
		context.Services.EconomyService.Notify(ownerPlayer, player.Name .. " cleansed your Voidmite: +" .. tostring(ownerReward) .. " coins.")
		context.Services.EconomyService.Notify(player, "Co-op cleanse: +" .. tostring(reward) .. " coins and +1 Void Token.")
	else
		context.Services.EconomyService.Notify(player, "Voidmite cleansed: +" .. tostring(reward) .. " coins and +1 Void Token.")
	end
	context.Services.AnalyticsService.VoidmiteCleared(player, ownerPlayer, reward)
	return true
end

return VoidmiteService
`,

  "server/Services/SnackService.lua": `local HttpService = game:GetService("HttpService")

local SnackService = {}

local activeSnacks = {}
local displayedByWorldId = {}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function snackFolder()
	return getWorld():WaitForChild("ActiveSnacks")
end

local function getSnackPart(model)
	return model and model:FindFirstChild("SnackPart")
end

local function setPrompt(plate, actionText)
	local prompt = plate and plate:FindFirstChild("PlatePrompt")
	if prompt then
		prompt.ActionText = actionText
	end
end

local function createSnackVisual(name, position, snackId, mutationId, scale, color)
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "SnackPart"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = Vector3.new(2.5, 2.5, 2.5) * scale
	part.Position = position
	part.Parent = model
	model.PrimaryPart = part
	model:SetAttribute("SnackId", snackId)
	model:SetAttribute("MutationId", mutationId or "Growing")
	model.Parent = snackFolder()
	return model
end

local function getSnackConfig(snackId)
	return SnackService.Context.Config.SnackConfig[snackId]
end

local function getMutationConfig(mutationId)
	return SnackService.Context.Config.MutationConfig[mutationId]
end

local function itemDisplayName(snackId, mutationId)
	local snack = getSnackConfig(snackId)
	if mutationId == "Normal" then
		return snack.DisplayName
	end
	return mutationId .. " " .. snack.DisplayName
end

local function displayValue(item)
	local snack = getSnackConfig(item.SnackId)
	local rarityBonus = ({
		Common = 1,
		Uncommon = 1.4,
		Rare = 2.1,
	})[snack.Rarity] or 1
	return math.floor(snack.BaseSellValue * item.ValueMultiplier * rarityBonus)
end

function SnackService.Init(context)
	SnackService.Context = context
end

function SnackService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			SnackService.GrowthTick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SnackService.Context.Config.GameConfig.BaseDisplayIncomeInterval)
			SnackService.PayDisplayIncome()
		end
	end)
	SnackService.BindWorldPrompts()
end

function SnackService.BindWorldPrompts()
	local world = getWorld()
	for _, prompt in ipairs(world:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			if prompt.Name == "PlatePrompt" then
				prompt.Triggered:Connect(function(player)
					local plate = prompt.Parent
					if plate and plate:GetAttribute("Occupied") then
						SnackService.HarvestSnack(player, plate)
					else
						SnackService.PlantSnack(player, plate, "CookieRock")
					end
				end)
			elseif prompt.Name == "SellPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.SellSnack(player)
				end)
			elseif prompt.Name == "FeedPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.FeedVoid(player)
				end)
			elseif prompt.Name == "DisplayPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.DisplaySnack(player, nil, prompt.Parent)
				end)
			elseif prompt.Name == "BuySeedPrompt" then
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.ShopService.BuySeed(player, "CookieRock")
				end)
			end
		end
	end
end

function SnackService.PlantSnack(player, plate, snackId)
	local context = SnackService.Context
	snackId = snackId or "CookieRock"
	local snack = getSnackConfig(snackId)
	if not snack then
		return false
	end
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can plant here.")
		return false
	end
	if not plate or plate:GetAttribute("Occupied") then
		context.Services.EconomyService.Notify(player, "That plate is busy.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data or (data.Seeds[snackId] or 0) <= 0 then
		context.Services.EconomyService.Notify(player, "You need a " .. snack.DisplayName .. " seed.")
		return false
	end

	data.Seeds[snackId] -= 1
	local uid = HttpService:GenerateGUID(false)
	plate:SetAttribute("Occupied", true)
	plate:SetAttribute("SnackUid", uid)
	plate:SetAttribute("SnackId", snackId)
	plate:SetAttribute("GrowthStage", 1)
	setPrompt(plate, "Growing...")

	local model = createSnackVisual("Growing_" .. uid, plate.Position + Vector3.new(0, 1.2, 0), snackId, "Growing", 0.45, snack.Color)
	model:SetAttribute("WorldId", uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("GrowthStage", 1)
	model:SetAttribute("PlatePath", plate:GetFullName())
	activeSnacks[uid] = {
		Player = player,
		Plate = plate,
		Model = model,
		SnackId = snackId,
		PlantedAt = os.clock(),
		GrowTime = snack.GrowTime / math.max(0.1, data.Upgrades.GrowSpeed or 1),
		Stage = 1,
	}
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Planted " .. snack.DisplayName .. ".")
	context.Services.AnalyticsService.SnackPlanted(player, snackId)
	return true
end

function SnackService.GrowthTick()
	for uid, record in pairs(activeSnacks) do
		if record.Model and record.Model.Parent and record.Plate and record.Plate.Parent then
			local progress = math.clamp((os.clock() - record.PlantedAt) / record.GrowTime, 0, 1)
			local stage = math.clamp(math.floor(progress * 3) + 1, 1, 3)
			if progress >= 1 then
				stage = 3
			end
			if stage ~= record.Stage then
				record.Stage = stage
				record.Plate:SetAttribute("GrowthStage", stage)
				record.Model:SetAttribute("GrowthStage", stage)
				local part = getSnackPart(record.Model)
				if part then
					local size = 1.2 + (stage * 1.1)
					part.Size = Vector3.new(size, size, size)
					part.Position = record.Plate.Position + Vector3.new(0, 0.55 + size / 2, 0)
				end
				if stage >= 3 then
					setPrompt(record.Plate, "Harvest Snack")
				end
			end
		else
			activeSnacks[uid] = nil
		end
	end
end

function SnackService.RollMutation()
	local mutations = SnackService.Context.Config.MutationConfig
	local total = 0
	local weighted = {}
	for mutationId, config in pairs(mutations) do
		local weight = config.Weight
		if SnackService.Context.Services.EventService.IsActive("MutationSurge") and mutationId ~= "Normal" then
			weight *= SnackService.Context.Config.EventConfig.MutationSurge.RareWeightMultiplier
		end
		total += weight
		table.insert(weighted, { Id = mutationId, Weight = weight })
	end
	local roll = math.random() * total
	local cursor = 0
	for _, entry in ipairs(weighted) do
		cursor += entry.Weight
		if roll <= cursor then
			return entry.Id
		end
	end
	return "Normal"
end

function SnackService.HarvestSnack(player, plate)
	local context = SnackService.Context
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can harvest here.")
		return false
	end
	local uid = plate and plate:GetAttribute("SnackUid")
	local record = uid and activeSnacks[uid]
	if not record or record.Stage < 3 then
		context.Services.EconomyService.Notify(player, "This snack is not ready yet.")
		return false
	end
	local mutationId = SnackService.RollMutation()
	local mutation = getMutationConfig(mutationId)
	local item = {
		UniqueId = HttpService:GenerateGUID(false),
		SnackId = record.SnackId,
		MutationId = mutationId,
		CreatedAt = os.time(),
		ValueMultiplier = mutation.ValueMultiplier,
		DisplayName = itemDisplayName(record.SnackId, mutationId),
	}
	context.Services.InventoryService.AddItem(player, item)
	if record.Model then
		record.Model:Destroy()
	end
	plate:SetAttribute("Occupied", false)
	plate:SetAttribute("SnackUid", "")
	plate:SetAttribute("SnackId", "")
	plate:SetAttribute("GrowthStage", 0)
	setPrompt(plate, "Plant Cookie Rock")
	activeSnacks[uid] = nil
	context.Services.EconomyService.Notify(player, "Harvested " .. item.DisplayName .. ".")
	context.Services.AnalyticsService.SnackHarvested(player, item)
	return true
end

function SnackService.SellSnack(player, itemId)
	local context = SnackService.Context
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, "No snack in inventory to sell.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local snack = getSnackConfig(item.SnackId)
	local value = math.floor(snack.BaseSellValue * item.ValueMultiplier * (data.Upgrades.SellMultiplier or 1))
	context.Services.EconomyService.AddCoins(player, value)
	context.Services.EconomyService.Notify(player, "Sold " .. item.DisplayName .. " for " .. tostring(value) .. " coins.")
	context.Services.AnalyticsService.SnackSold(player, item, value)
	return true
end

function SnackService.FeedVoid(player, itemId)
	local context = SnackService.Context
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, "No snack in inventory to feed.")
		return false
	end
	local snack = getSnackConfig(item.SnackId)
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local value = math.floor(snack.BaseVoidValue * item.ValueMultiplier)
	local tokenReward = math.max(1, math.floor(value / 10 * (data.Upgrades.VoidRewardMultiplier or 1)))
	context.Services.EconomyService.AddVoidTokens(player, tokenReward)
	context.Services.VoidService.AddHunger(player, value)
	context.Services.EconomyService.Notify(player, "Fed " .. item.DisplayName .. " to the Void: +" .. tostring(tokenReward) .. " Void Tokens.")
	context.Services.AnalyticsService.SnackFed(player, item, value)
	return true
end

function SnackService.DisplaySnack(player, itemId, shelf)
	local context = SnackService.Context
	local plot = shelf and context.Services.PlotService.FindPlotFromInstance(shelf) or context.Services.PlotService.GetPlot(player)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can display snacks here.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	if not item then
		context.Services.EconomyService.Notify(player, "No snack in inventory to display.")
		return false
	end
	local shelfPart = plot and plot:FindFirstChild("DisplayShelf")
	if not shelfPart then
		context.Services.EconomyService.Notify(player, "Display shelf missing.")
		return false
	end
	local mutation = getMutationConfig(item.MutationId)
	local snack = getSnackConfig(item.SnackId)
	local worldId = HttpService:GenerateGUID(false)
	local count = 0
	for _, model in pairs(displayedByWorldId) do
		if model and model:GetAttribute("PlotId") == plot:GetAttribute("PlotId") then
			count += 1
		end
	end
	local offset = Vector3.new(((count % 4) - 1.5) * 2.8, 2.2 + math.floor(count / 4) * 1.2, 0)
	local color = mutation.Color or snack.Color
	local model = createSnackVisual("Displayed_" .. item.SnackId .. "_" .. worldId, shelfPart.Position + offset, item.SnackId, item.MutationId, mutation.ScaleMultiplier or 1, color)
	local value = displayValue(item)
	model:SetAttribute("WorldId", worldId)
	model:SetAttribute("Displayed", true)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("DisplayValue", value)
	model:SetAttribute("DisplayName", item.DisplayName)
	item.WorldId = worldId
	item.DisplayValue = value
	context.Services.InventoryService.AddDisplayed(player, item)
	displayedByWorldId[worldId] = model
	context.Services.EconomyService.Notify(player, "Displayed " .. item.DisplayName .. ". It will earn passive coins and attract Voidmites.")
	context.Services.AnalyticsService.SnackDisplayed(player, item)
	return true
end

function SnackService.PayDisplayIncome()
	local context = SnackService.Context
	for worldId, model in pairs(displayedByWorldId) do
		if not model or not model.Parent then
			displayedByWorldId[worldId] = nil
		else
			local owner = game:GetService("Players"):GetPlayerByUserId(tonumber(model:GetAttribute("OwnerUserId")) or 0)
			if owner then
				local value = tonumber(model:GetAttribute("DisplayValue")) or 10
				local income = math.max(1, math.floor(value * 0.08))
				context.Services.EconomyService.AddCoins(owner, income)
				context.Services.EconomyService.Notify(owner, "Displayed snack income: +" .. tostring(income) .. " coins.")
			end
		end
	end
end

return SnackService
`,

  "server/Services/ShopService.lua": `local ShopService = {}

function ShopService.Init(context)
	ShopService.Context = context
end

function ShopService.Start() end

function ShopService.BuySeed(player, snackId)
	local context = ShopService.Context
	local snack = context.Config.SnackConfig[snackId]
	if not snack then
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	if not context.Services.EconomyService.SpendCoins(player, snack.SeedCost) then
		context.Services.EconomyService.Notify(player, "Not enough coins for " .. snack.DisplayName .. " seed.")
		return false
	end
	data.Seeds[snackId] = (data.Seeds[snackId] or 0) + 1
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Bought 1 " .. snack.DisplayName .. " seed.")
	return true
end

return ShopService
`,

  "server/Services/RebirthService.lua": `local RebirthService = {}

function RebirthService.Init(context)
	RebirthService.Context = context
end

function RebirthService.Start() end

function RebirthService.TryRebirth(player)
	local context = RebirthService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	local cost = context.Config.GameConfig.RebirthCost
	if data.Coins < cost then
		context.Services.EconomyService.Notify(player, "Rebirth requires " .. tostring(cost) .. " coins.")
		return false
	end
	data.Coins = context.Config.GameConfig.StartingCoins
	data.Inventory = {}
	data.DisplayedSnacks = {}
	data.Rebirths += 1
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Phase 1 rebirth complete. Multipliers come later.")
	return true
end

return RebirthService
`,

  "server/Services/VisitRewardService.lua": `local VisitRewardService = {}

function VisitRewardService.Init(context)
	VisitRewardService.Context = context
end

function VisitRewardService.Start() end

function VisitRewardService.ApplyJoinReward(player)
	VisitRewardService.Context.Services.EconomyService.Notify(player, "Welcome to FEED THE VOID. Grow snacks, feed the Void, and help other labs.")
end

return VisitRewardService
`,

  "server/Main.server.lua": `local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerFolder = script.Parent
local ServicesFolder = ServerFolder:WaitForChild("Services")

local context = {
	Remotes = {
		RequestPlantSnack = Remotes:WaitForChild("RequestPlantSnack"),
		RequestHarvestSnack = Remotes:WaitForChild("RequestHarvestSnack"),
		RequestSellSnack = Remotes:WaitForChild("RequestSellSnack"),
		RequestFeedVoid = Remotes:WaitForChild("RequestFeedVoid"),
		RequestDisplaySnack = Remotes:WaitForChild("RequestDisplaySnack"),
		RequestClearVoidmite = Remotes:WaitForChild("RequestClearVoidmite"),
		RequestBuySeed = Remotes:WaitForChild("RequestBuySeed"),
		RequestRebirth = Remotes:WaitForChild("RequestRebirth"),
		NotifyClient = Remotes:WaitForChild("NotifyClient"),
		SyncPlayerData = Remotes:WaitForChild("SyncPlayerData"),
	},
	Config = {
		GameConfig = require(Shared:WaitForChild("GameConfig")),
		SnackConfig = require(Shared:WaitForChild("SnackConfig")),
		MutationConfig = require(Shared:WaitForChild("MutationConfig")),
		EventConfig = require(Shared:WaitForChild("EventConfig")),
		FormatNumbers = require(Shared:WaitForChild("FormatNumbers")),
	},
	Services = {},
}

local serviceOrder = {
	"ProfileServiceWrapper",
	"AnalyticsService",
	"EconomyService",
	"InventoryService",
	"PlotService",
	"EventService",
	"VoidService",
	"VoidmiteService",
	"ShopService",
	"RebirthService",
	"VisitRewardService",
	"SnackService",
}

for _, serviceName in ipairs(serviceOrder) do
	context.Services[serviceName] = require(ServicesFolder:WaitForChild(serviceName))
end

for _, serviceName in ipairs(serviceOrder) do
	local service = context.Services[serviceName]
	if service.Init then
		service.Init(context)
	end
end

for _, serviceName in ipairs(serviceOrder) do
	local service = context.Services[serviceName]
	if service.Start then
		service.Start()
	end
end

local lastRemoteUse = {}

local function passesCooldown(player, remoteName)
	local now = os.clock()
	lastRemoteUse[player] = lastRemoteUse[player] or {}
	local last = lastRemoteUse[player][remoteName] or 0
	if now - last < context.Config.GameConfig.RemoteCooldown then
		return false
	end
	lastRemoteUse[player][remoteName] = now
	return true
end

local function bindRemote(remoteName, callback)
	context.Remotes[remoteName].OnServerEvent:Connect(function(player, ...)
		if not passesCooldown(player, remoteName) then
			return
		end
		local ok, err = pcall(callback, player, ...)
		if not ok then
			warn("[FEED THE VOID]", remoteName, err)
			context.Services.EconomyService.Notify(player, "That action fizzled. Try again.")
		end
	end)
end

bindRemote("RequestPlantSnack", function(player, plate, snackId)
	context.Services.SnackService.PlantSnack(player, plate, snackId)
end)

bindRemote("RequestHarvestSnack", function(player, plate)
	context.Services.SnackService.HarvestSnack(player, plate)
end)

bindRemote("RequestSellSnack", function(player, itemId)
	context.Services.SnackService.SellSnack(player, itemId)
end)

bindRemote("RequestFeedVoid", function(player, itemId)
	context.Services.SnackService.FeedVoid(player, itemId)
end)

bindRemote("RequestDisplaySnack", function(player, itemId, shelf)
	context.Services.SnackService.DisplaySnack(player, itemId, shelf)
end)

bindRemote("RequestClearVoidmite", function(player, voidmite)
	context.Services.VoidmiteService.ClearVoidmite(player, voidmite)
end)

bindRemote("RequestBuySeed", function(player, snackId)
	context.Services.ShopService.BuySeed(player, snackId)
end)

bindRemote("RequestRebirth", function(player)
	context.Services.RebirthService.TryRebirth(player)
end)

Players.PlayerAdded:Connect(function(player)
	context.Services.ProfileServiceWrapper.LoadPlayer(player)
	context.Services.AnalyticsService.PlayerJoined(player)
	context.Services.PlotService.AssignPlot(player)
	context.Services.VisitRewardService.ApplyJoinReward(player)
	context.Services.EconomyService.Sync(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		context.Services.PlotService.TeleportToPlot(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	context.Services.PlotService.ReleasePlot(player)
	context.Services.ProfileServiceWrapper.ReleasePlayer(player)
	lastRemoteUse[player] = nil
end)

print("[FEED THE VOID] Phase 1 server loaded.")
`,

  "client/Controllers/NotificationController.lua": `local NotificationController = {}

local label

function NotificationController.Init(mainUi)
	local notifications = mainUi:WaitForChild("Notifications")
	label = notifications:WaitForChild("NotificationText")
end

function NotificationController.Show(message)
	if not label then
		return
	end
	label.Text = tostring(message)
	label.Visible = true
	task.delay(3.5, function()
		if label and label.Text == tostring(message) then
			label.Text = ""
		end
	end)
end

return NotificationController
`,

  "client/Controllers/UIController.lua": `local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FormatNumbers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumbers"))

local UIController = {}

local mainUi
local selectedItemId

local function firstInventoryItem(data)
	return data.Inventory and data.Inventory[1] or nil
end

local function seedsText(seeds)
	local parts = {}
	for seedId, count in pairs(seeds or {}) do
		table.insert(parts, seedId .. ": " .. tostring(count))
	end
	table.sort(parts)
	return table.concat(parts, "  ")
end

function UIController.Init(ui, notificationController)
	mainUi = ui
	UIController.NotificationController = notificationController

	local inventoryPanel = mainUi:WaitForChild("InventoryPanel")
	inventoryPanel.SellButton.Activated:Connect(function()
		Remotes.RequestSellSnack:FireServer(selectedItemId)
	end)
	inventoryPanel.FeedButton.Activated:Connect(function()
		Remotes.RequestFeedVoid:FireServer(selectedItemId)
	end)
	inventoryPanel.DisplayButton.Activated:Connect(function()
		Remotes.RequestDisplaySnack:FireServer(selectedItemId)
	end)

	local shop = mainUi:WaitForChild("SeedShopPanel")
	shop.CookieButton.Activated:Connect(function()
		Remotes.RequestBuySeed:FireServer("CookieRock")
	end)
	shop.JellyButton.Activated:Connect(function()
		Remotes.RequestBuySeed:FireServer("JellyCube")
	end)
	shop.MeteorButton.Activated:Connect(function()
		Remotes.RequestBuySeed:FireServer("MeteorMuffin")
	end)
	shop.RebirthButton.Activated:Connect(function()
		Remotes.RequestRebirth:FireServer()
	end)

	Remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		UIController.ApplyData(data)
	end)
	Remotes.NotifyClient.OnClientEvent:Connect(function(message)
		notificationController.Show(message)
	end)
end

function UIController.ApplyData(data)
	local top = mainUi:WaitForChild("TopStats")
	top.CoinsLabel.Text = "Coins: " .. FormatNumbers.Compact(data.Coins or 0)
	top.TokensLabel.Text = "Void Tokens: " .. FormatNumbers.Compact(data.VoidTokens or 0)
	top.HungerLabel.Text = "Void Hunger: " .. tostring(math.floor(data.VoidHunger or 0)) .. "/" .. tostring(data.VoidHungerRequired or 100)
	local fill = top.HungerBarBack.HungerBarFill
	fill.Size = UDim2.new(math.clamp((data.VoidHunger or 0) / (data.VoidHungerRequired or 100), 0, 1), 0, 1, 0)

	local inventoryPanel = mainUi:WaitForChild("InventoryPanel")
	local first = firstInventoryItem(data)
	selectedItemId = first and first.UniqueId or nil
	inventoryPanel.FirstItemLabel.Text = first and ("Selected: " .. first.DisplayName) or "Selected: none"
	inventoryPanel.InventoryList.Text = "Inventory: " .. tostring(#(data.Inventory or {})) .. " snacks"
	inventoryPanel.SeedsLabel.Text = "Seeds: " .. seedsText(data.Seeds)
	inventoryPanel.DisplayedLabel.Text = "Displayed: " .. tostring(#(data.DisplayedSnacks or {}))
end

return UIController
`,

  "client/Controllers/PromptController.lua": `local PromptController = {}

function PromptController.Init()
	-- ProximityPrompts are authored in Workspace and handled by the server.
	-- This controller is intentionally small for Phase 1 so the client stays non-authoritative.
end

return PromptController
`,

  "client/ClientMain.client.lua": `local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mainUi = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local controllers = script.Parent:WaitForChild("Controllers")

local NotificationController = require(controllers:WaitForChild("NotificationController"))
local UIController = require(controllers:WaitForChild("UIController"))
local PromptController = require(controllers:WaitForChild("PromptController"))

NotificationController.Init(mainUi)
UIController.Init(mainUi, NotificationController)
PromptController.Init()

NotificationController.Show("FEED THE VOID Phase 1 loaded.")
`,
};

const steps = [];

function addFolders() {
  [
    "ReplicatedStorage.Remotes",
    "ReplicatedStorage.Shared",
    "ServerScriptService.Server",
    "ServerScriptService.Server.Services",
    "Workspace.GameWorld",
    "Workspace.GameWorld.Plots",
    "Workspace.GameWorld.CentralVoid",
    "Workspace.GameWorld.ActiveSnacks",
    "Workspace.GameWorld.ActiveVoidmites",
    "Workspace.GameWorld.EventObjects",
  ].forEach((p) => steps.push(step("ensureFolder", p)));
  inst("Folder", "StarterPlayer.StarterPlayerScripts.Controllers");
}

function addRemotes() {
  [
    "RequestPlantSnack",
    "RequestHarvestSnack",
    "RequestSellSnack",
    "RequestFeedVoid",
    "RequestDisplaySnack",
    "RequestClearVoidmite",
    "RequestBuySeed",
    "RequestRebirth",
    "NotifyClient",
    "SyncPlayerData",
  ].forEach((name) => steps.push(step("ensureRemoteEvent", `ReplicatedStorage.Remotes.${name}`)));
}

function addSources() {
  const mapping = [
    ["ReplicatedStorage.Shared.GameConfig", "ModuleScript", "shared/GameConfig.lua"],
    ["ReplicatedStorage.Shared.SnackConfig", "ModuleScript", "shared/SnackConfig.lua"],
    ["ReplicatedStorage.Shared.MutationConfig", "ModuleScript", "shared/MutationConfig.lua"],
    ["ReplicatedStorage.Shared.EventConfig", "ModuleScript", "shared/EventConfig.lua"],
    ["ReplicatedStorage.Shared.FormatNumbers", "ModuleScript", "shared/FormatNumbers.lua"],
    ["ServerScriptService.Server.Main", "Script", "server/Main.server.lua"],
    ["ServerScriptService.Server.Services.ProfileServiceWrapper", "ModuleScript", "server/Services/ProfileServiceWrapper.lua"],
    ["ServerScriptService.Server.Services.PlotService", "ModuleScript", "server/Services/PlotService.lua"],
    ["ServerScriptService.Server.Services.SnackService", "ModuleScript", "server/Services/SnackService.lua"],
    ["ServerScriptService.Server.Services.InventoryService", "ModuleScript", "server/Services/InventoryService.lua"],
    ["ServerScriptService.Server.Services.EconomyService", "ModuleScript", "server/Services/EconomyService.lua"],
    ["ServerScriptService.Server.Services.VoidService", "ModuleScript", "server/Services/VoidService.lua"],
    ["ServerScriptService.Server.Services.VoidmiteService", "ModuleScript", "server/Services/VoidmiteService.lua"],
    ["ServerScriptService.Server.Services.EventService", "ModuleScript", "server/Services/EventService.lua"],
    ["ServerScriptService.Server.Services.ShopService", "ModuleScript", "server/Services/ShopService.lua"],
    ["ServerScriptService.Server.Services.RebirthService", "ModuleScript", "server/Services/RebirthService.lua"],
    ["ServerScriptService.Server.Services.VisitRewardService", "ModuleScript", "server/Services/VisitRewardService.lua"],
    ["ServerScriptService.Server.Services.AnalyticsService", "ModuleScript", "server/Services/AnalyticsService.lua"],
    ["StarterPlayer.StarterPlayerScripts.ClientMain", "LocalScript", "client/ClientMain.client.lua"],
    ["StarterPlayer.StarterPlayerScripts.Controllers.UIController", "ModuleScript", "client/Controllers/UIController.lua"],
    ["StarterPlayer.StarterPlayerScripts.Controllers.PromptController", "ModuleScript", "client/Controllers/PromptController.lua"],
    ["StarterPlayer.StarterPlayerScripts.Controllers.NotificationController", "ModuleScript", "client/Controllers/NotificationController.lua"],
  ];

  for (const [studioPath, className, sourceName] of mapping) {
    steps.push(
      step("writeScript", studioPath, {
        className,
        sourceFile: writeSource(sourceName, sources[sourceName]),
      })
    );
  }
}

function part(pathName, properties, attributes) {
  steps.push(step("createPart", pathName, { properties, attributes }));
}

function inst(className, pathName, properties = {}, attributes) {
  steps.push(step("ensureInstance", pathName, { className, properties, attributes }));
}

function addWorld() {
  steps.push(step("setLighting", "Lighting", {
    properties: {
      ClockTime: 17.5,
      Brightness: 2.5,
      Ambient: c3(62, 52, 78),
      OutdoorAmbient: c3(92, 82, 105),
    },
  }));

  part("Workspace.GameWorld.VoidLabFloor", {
    Anchored: true,
    CanCollide: true,
    Size: v3(190, 1, 190),
    Position: v3(0, 0, 0),
    Color: c3(42, 45, 55),
    Material: "Slate",
  });

  part("Workspace.GameWorld.CentralVoid.VoidCore", {
    Anchored: true,
    CanCollide: false,
    Shape: "Ball",
    Size: v3(18, 18, 18),
    Position: v3(0, 11, 0),
    Color: c3(22, 8, 34),
    Material: "Neon",
  });
  part("Workspace.GameWorld.CentralVoid.Mouth", {
    Anchored: true,
    CanCollide: false,
    Size: v3(10, 2, 1),
    Position: v3(0, 7, -8.9),
    Color: c3(5, 2, 8),
    Material: "SmoothPlastic",
  });
  part("Workspace.GameWorld.CentralVoid.LeftEye", {
    Anchored: true,
    CanCollide: false,
    Shape: "Ball",
    Size: v3(2.2, 2.2, 2.2),
    Position: v3(-4, 14, -7),
    Color: c3(190, 65, 255),
    Material: "Neon",
  });
  part("Workspace.GameWorld.CentralVoid.RightEye", {
    Anchored: true,
    CanCollide: false,
    Shape: "Ball",
    Size: v3(2.2, 2.2, 2.2),
    Position: v3(4, 14, -7),
    Color: c3(88, 225, 255),
    Material: "Neon",
  });
  part("Workspace.GameWorld.CentralVoid.FeedStation", {
    Anchored: true,
    CanCollide: true,
    Size: v3(10, 1, 10),
    Position: v3(0, 0.75, -20),
    Color: c3(112, 64, 165),
    Material: "Neon",
  });
  inst("ProximityPrompt", "Workspace.GameWorld.CentralVoid.FeedStation.FeedPrompt", {
    ActionText: "Feed First Snack",
    ObjectText: "THE VOID",
    HoldDuration: 0.25,
    MaxActivationDistance: 12,
  });
  inst("PointLight", "Workspace.GameWorld.CentralVoid.VoidCore.VoidGlow", {
    Brightness: 3,
    Range: 45,
    Color: c3(156, 65, 255),
    Shadows: false,
  });
  inst("BillboardGui", "Workspace.GameWorld.CentralVoid.VoidCore.VoidBillboard", {
    AlwaysOnTop: true,
    Size: ud2(0, 280, 0, 100),
    StudsOffset: v3(0, 14, 0),
  });
  inst("TextLabel", "Workspace.GameWorld.CentralVoid.VoidCore.VoidBillboard.TitleLabel", {
    BackgroundTransparency: 1,
    Size: ud2(1, 0, 0, 42),
    Position: ud2(0, 0, 0, 0),
    Text: "THE VOID",
    TextColor3: c3(244, 232, 255),
    TextScaled: true,
    Font: "GothamBlack",
  });
  inst("Frame", "Workspace.GameWorld.CentralVoid.VoidCore.VoidBillboard.MeterBack", {
    BackgroundColor3: c3(30, 18, 44),
    BorderSizePixel: 0,
    Size: ud2(0.9, 0, 0, 18),
    Position: ud2(0.05, 0, 0, 52),
  });
  inst("Frame", "Workspace.GameWorld.CentralVoid.VoidCore.VoidBillboard.MeterBack.MeterFill", {
    BackgroundColor3: c3(190, 65, 255),
    BorderSizePixel: 0,
    Size: ud2(0, 0, 1, 0),
    Position: ud2(0, 0, 0, 0),
  });
  inst("TextLabel", "Workspace.GameWorld.CentralVoid.VoidCore.VoidBillboard.HungerLabel", {
    BackgroundTransparency: 1,
    Size: ud2(1, 0, 0, 26),
    Position: ud2(0, 0, 0, 72),
    Text: "THE VOID - 0/100",
    TextColor3: c3(230, 230, 255),
    TextScaled: true,
    Font: "GothamBold",
  });

  for (let i = 1; i <= 8; i += 1) {
    const angle = ((i - 1) / 8) * Math.PI * 2;
    const cx = Math.cos(angle) * 58;
    const cz = Math.sin(angle) * 58;
    const plotPath = `Workspace.GameWorld.Plots.Plot${i}`;
    steps.push(step("createModel", plotPath, { attributes: { PlotId: i, OwnerUserId: 0 } }));
    part(`${plotPath}.Platform`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(32, 1, 26),
      Position: v3(cx, 0.7, cz),
      Color: i % 2 === 0 ? c3(48, 68, 75) : c3(62, 50, 74),
      Material: "Concrete",
    }, { PlotId: i });
    part(`${plotPath}.PlotSpawn`, {
      Anchored: true,
      CanCollide: false,
      Size: v3(5, 1, 5),
      Position: v3(cx, 2, cz + 8),
      Transparency: 0.35,
      Color: c3(90, 230, 180),
      Material: "Neon",
    }, { PlotId: i });
    part(`${plotPath}.OwnerSign`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(12, 5, 0.8),
      Position: v3(cx, 4, cz + 14),
      Color: c3(35, 38, 50),
      Material: "SmoothPlastic",
    }, { PlotId: i });
    inst("BillboardGui", `${plotPath}.OwnerSign.OwnerBillboard`, {
      AlwaysOnTop: true,
      Size: ud2(0, 220, 0, 60),
      StudsOffset: v3(0, 4, 0),
    });
    inst("TextLabel", `${plotPath}.OwnerSign.OwnerBillboard.OwnerLabel`, {
      BackgroundTransparency: 1,
      Size: ud2(1, 0, 1, 0),
      Text: "EMPTY PLOT",
      TextColor3: c3(255, 248, 220),
      TextScaled: true,
      Font: "GothamBold",
    });
    part(`${plotPath}.DisplayShelf`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(20, 2, 4),
      Position: v3(cx, 2.1, cz - 10),
      Color: c3(92, 65, 120),
      Material: "WoodPlanks",
    }, { PlotId: i });
    inst("ProximityPrompt", `${plotPath}.DisplayShelf.DisplayPrompt`, {
      ActionText: "Display First Snack",
      ObjectText: "Display Shelf",
      HoldDuration: 0.25,
      MaxActivationDistance: 10,
    });
    part(`${plotPath}.SellStation`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(5, 3, 5),
      Position: v3(cx - 12, 2.4, cz - 9),
      Color: c3(74, 184, 95),
      Material: "Neon",
    }, { PlotId: i });
    inst("ProximityPrompt", `${plotPath}.SellStation.SellPrompt`, {
      ActionText: "Sell First Snack",
      ObjectText: "Sell Station",
      HoldDuration: 0.2,
      MaxActivationDistance: 10,
    });
    part(`${plotPath}.SeedShopStation`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(5, 3, 5),
      Position: v3(cx + 12, 2.4, cz - 9),
      Color: c3(245, 180, 65),
      Material: "Neon",
    }, { PlotId: i });
    inst("ProximityPrompt", `${plotPath}.SeedShopStation.BuySeedPrompt`, {
      ActionText: "Buy Cookie Seed",
      ObjectText: "Seed Shop",
      HoldDuration: 0.2,
      MaxActivationDistance: 10,
    });
    inst("Folder", `${plotPath}.Plates`);
    for (let p = 1; p <= 6; p += 1) {
      const row = p <= 3 ? 0 : 1;
      const col = (p - 1) % 3;
      const px = cx + (col - 1) * 7;
      const pz = cz + (row === 0 ? 2 : -4);
      const platePath = `${plotPath}.Plates.Plate${p}`;
      part(platePath, {
        Anchored: true,
        CanCollide: true,
        Shape: "Cylinder",
        Size: v3(4.5, 0.45, 4.5),
        Position: v3(px, 1.45, pz),
        Orientation: v3(0, 0, 0),
        Color: c3(210, 214, 225),
        Material: "SmoothPlastic",
      }, { PlotId: i, PlateIndex: p, Occupied: false, GrowthStage: 0 });
      inst("ProximityPrompt", `${platePath}.PlatePrompt`, {
        ActionText: "Plant Cookie Rock",
        ObjectText: `Plate ${p}`,
        HoldDuration: 0.15,
        MaxActivationDistance: 9,
      });
    }
  }
}

function addUi() {
  inst("ScreenGui", "StarterGui.MainUI", {
    ResetOnSpawn: false,
    Enabled: true,
    IgnoreGuiInset: false,
    DisplayOrder: 10,
  });
  inst("Frame", "StarterGui.MainUI.TopStats", {
    BackgroundColor3: c3(24, 27, 34),
    BackgroundTransparency: 0.12,
    BorderSizePixel: 0,
    Size: ud2(1, -24, 0, 86),
    Position: ud2(0, 12, 0, 12),
  });
  inst("TextLabel", "StarterGui.MainUI.TopStats.CoinsLabel", {
    BackgroundTransparency: 1,
    Size: ud2(0.24, 0, 0, 32),
    Position: ud2(0, 12, 0, 8),
    Text: "Coins: 100",
    TextColor3: c3(255, 235, 160),
    TextScaled: true,
    Font: "GothamBold",
  });
  inst("TextLabel", "StarterGui.MainUI.TopStats.TokensLabel", {
    BackgroundTransparency: 1,
    Size: ud2(0.25, 0, 0, 32),
    Position: ud2(0.25, 8, 0, 8),
    Text: "Void Tokens: 0",
    TextColor3: c3(192, 165, 255),
    TextScaled: true,
    Font: "GothamBold",
  });
  inst("TextLabel", "StarterGui.MainUI.TopStats.HungerLabel", {
    BackgroundTransparency: 1,
    Size: ud2(0.42, 0, 0, 30),
    Position: ud2(0.52, 0, 0, 8),
    Text: "Void Hunger: 0/100",
    TextColor3: c3(240, 242, 255),
    TextScaled: true,
    Font: "GothamBold",
  });
  inst("Frame", "StarterGui.MainUI.TopStats.HungerBarBack", {
    BackgroundColor3: c3(48, 36, 62),
    BorderSizePixel: 0,
    Size: ud2(1, -24, 0, 20),
    Position: ud2(0, 12, 0, 54),
  });
  inst("Frame", "StarterGui.MainUI.TopStats.HungerBarBack.HungerBarFill", {
    BackgroundColor3: c3(177, 75, 255),
    BorderSizePixel: 0,
    Size: ud2(0, 0, 1, 0),
    Position: ud2(0, 0, 0, 0),
  });

  inst("Frame", "StarterGui.MainUI.Notifications", {
    BackgroundTransparency: 1,
    Size: ud2(0.46, 0, 0, 54),
    Position: ud2(0.27, 0, 0, 104),
  });
  inst("TextLabel", "StarterGui.MainUI.Notifications.NotificationText", {
    BackgroundColor3: c3(28, 32, 42),
    BackgroundTransparency: 0.1,
    BorderSizePixel: 0,
    Size: ud2(1, 0, 1, 0),
    Position: ud2(0, 0, 0, 0),
    Text: "",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });

  inst("Frame", "StarterGui.MainUI.InventoryPanel", {
    BackgroundColor3: c3(28, 31, 39),
    BackgroundTransparency: 0.08,
    BorderSizePixel: 0,
    Size: ud2(0, 320, 0, 220),
    Position: ud2(0, 12, 1, -236),
  });
  [
    ["InventoryTitle", "INVENTORY", 0],
    ["InventoryList", "Inventory: 0 snacks", 34],
    ["FirstItemLabel", "Selected: none", 62],
    ["SeedsLabel", "Seeds: CookieRock: 3", 90],
    ["DisplayedLabel", "Displayed: 0", 118],
  ].forEach(([name, text, y]) => {
    inst("TextLabel", `StarterGui.MainUI.InventoryPanel.${name}`, {
      BackgroundTransparency: 1,
      Size: ud2(1, -20, 0, name === "InventoryTitle" ? 28 : 24),
      Position: ud2(0, 10, 0, y + 6),
      Text: text,
      TextColor3: name === "InventoryTitle" ? c3(255, 235, 160) : c3(230, 235, 245),
      TextScaled: true,
      TextWrapped: true,
      Font: name === "InventoryTitle" ? "GothamBlack" : "Gotham",
    });
  });
  [
    ["SellButton", "SELL", 10],
    ["FeedButton", "FEED", 114],
    ["DisplayButton", "DISPLAY", 218],
  ].forEach(([name, text, x]) => {
    inst("TextButton", `StarterGui.MainUI.InventoryPanel.${name}`, {
      BackgroundColor3: name === "SellButton" ? c3(70, 165, 92) : name === "FeedButton" ? c3(130, 74, 190) : c3(68, 128, 190),
      BorderSizePixel: 0,
      Size: ud2(0, 92, 0, 42),
      Position: ud2(0, x, 1, -52),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      Font: "GothamBold",
    });
  });

  inst("Frame", "StarterGui.MainUI.SeedShopPanel", {
    BackgroundColor3: c3(28, 31, 39),
    BackgroundTransparency: 0.08,
    BorderSizePixel: 0,
    Size: ud2(0, 288, 0, 220),
    Position: ud2(1, -300, 1, -236),
  });
  inst("TextLabel", "StarterGui.MainUI.SeedShopPanel.ShopTitle", {
    BackgroundTransparency: 1,
    Size: ud2(1, -20, 0, 32),
    Position: ud2(0, 10, 0, 8),
    Text: "SEED SHOP",
    TextColor3: c3(255, 213, 105),
    TextScaled: true,
    Font: "GothamBlack",
  });
  [
    ["CookieButton", "Cookie Rock - 10", 48, c3(185, 164, 132)],
    ["JellyButton", "Jelly Cube - 25", 92, c3(92, 200, 225)],
    ["MeteorButton", "Meteor Muffin - 100", 136, c3(220, 92, 76)],
    ["RebirthButton", "REBIRTH - 5000", 180, c3(92, 65, 160)],
  ].forEach(([name, text, y, color]) => {
    inst("TextButton", `StarterGui.MainUI.SeedShopPanel.${name}`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(1, -24, 0, 34),
      Position: ud2(0, 12, 0, y),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      Font: "GothamBold",
    });
  });

  inst("Frame", "StarterGui.MainUI.ActionHints", {
    BackgroundTransparency: 1,
    Size: ud2(0, 430, 0, 62),
    Position: ud2(0.5, -215, 1, -74),
  });
  inst("TextLabel", "StarterGui.MainUI.ActionHints.HintText", {
    BackgroundColor3: c3(24, 27, 34),
    BackgroundTransparency: 0.18,
    BorderSizePixel: 0,
    Size: ud2(1, 0, 1, 0),
    Text: "Use ProximityPrompts on plates, shelves, stations, and Voidmites. Buttons act on your first inventory snack.",
    TextColor3: c3(230, 235, 245),
    TextScaled: true,
    TextWrapped: true,
    Font: "Gotham",
  });
}

function addDocs() {
  const doc = `# FEED THE VOID Phase 1

Created by the local Codex build script and applied to the live Roblox place through the bridge.

## Test Loop

1. Press Play in Roblox Studio.
2. Confirm the server Output prints "[FEED THE VOID] Phase 1 server loaded."
3. Your character should be assigned to a lab plot.
4. Walk to a plate and use "Plant Cookie Rock".
5. Wait about 20 seconds for three growth stages, then harvest.
6. Use UI buttons or world stations to sell, feed, or display your first inventory snack.
7. Displayed snacks pay passive coins and spawn Voidmites over time.
8. Clear Voidmites with their ProximityPrompt.
9. Feed enough snacks to fill the Void meter and trigger a simple server event.

## Studio Setting

DataStore access is optional for this phase. If Studio API access is disabled, the game continues with memory data and warns in Output.

## Phase 2 Candidates

Better art assets, real tutorial flow, richer events, balance tuning, plot upgrades, more snack types, more polished mobile panels, and persistence hardening.
`;
  fs.writeFileSync(path.join(outDir, "PHASE1_TESTING.md"), doc, "utf8");
}

function writeRepairBlueprint() {
  const repairSteps = [
    step("ensureInstance", "StarterPlayer.StarterPlayerScripts.Controllers", {
      className: "Folder",
      properties: {},
    }),
    step("writeScript", "StarterPlayer.StarterPlayerScripts.ClientMain", {
      className: "LocalScript",
      sourceFile: "src/client/ClientMain.client.lua",
      overwrite: true,
    }),
    step("writeScript", "StarterPlayer.StarterPlayerScripts.Controllers.UIController", {
      className: "ModuleScript",
      sourceFile: "src/client/Controllers/UIController.lua",
      overwrite: true,
    }),
    step("writeScript", "StarterPlayer.StarterPlayerScripts.Controllers.PromptController", {
      className: "ModuleScript",
      sourceFile: "src/client/Controllers/PromptController.lua",
      overwrite: true,
    }),
    step("writeScript", "StarterPlayer.StarterPlayerScripts.Controllers.NotificationController", {
      className: "ModuleScript",
      sourceFile: "src/client/Controllers/NotificationController.lua",
      overwrite: true,
    }),
  ];

  for (let plot = 1; plot <= 8; plot += 1) {
    repairSteps.push(step("ensureInstance", `Workspace.GameWorld.Plots.Plot${plot}.Plates`, {
      className: "Folder",
      properties: {},
    }));
    for (let plate = 1; plate <= 6; plate += 1) {
      repairSteps.push(step("setProperties", `Workspace.GameWorld.Plots.Plot${plot}.Plates.Plate${plate}`, {
        properties: {
          Orientation: v3(0, 0, 0),
        },
      }));
    }
  }

  fs.writeFileSync(repairBlueprintPath, JSON.stringify({
    name: "FEED THE VOID Phase 1 Repair Sync",
    mode: "supervised",
    description: "Synchronizes client controller placement and fixes authored plate orientation.",
    steps: repairSteps,
  }, null, 2), "utf8");
}

addFolders();
addRemotes();
addSources();
addWorld();
addUi();
addDocs();

const blueprint = {
  name: "FEED THE VOID Phase 1 Playable Skeleton",
  mode: "supervised",
  description: "Creates Phase 1 real world/UI instances plus modular server/client code for the core playable loop.",
  steps,
};

fs.writeFileSync(blueprintPath, JSON.stringify(blueprint, null, 2), "utf8");
writeRepairBlueprint();
console.log(JSON.stringify({
  ok: true,
  blueprintPath,
  repairBlueprintPath,
  outDir,
  stepCount: steps.length,
  sourceCount: Object.keys(sources).length,
}, null, 2));
