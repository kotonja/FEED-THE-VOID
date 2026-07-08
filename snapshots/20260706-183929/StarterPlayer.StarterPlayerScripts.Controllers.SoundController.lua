local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local SoundConfig = require(Shared:WaitForChild("SoundConfig"))

local SoundController = {}

local warned = {}
local muted = false
local initialized = false
local ambienceStarted = false
local lowDetailMode = false
local buttonConnections = setmetatable({}, { __mode = "k" })
local loops = {}
local soundGroups = {}
local groupBaseVolumes = {}
local groupVolumeOverrides = {}
local lastPlayedAt = {}

local legacyEffectKeys = {
	Plant = "Planting.PlantSeed",
	GrowthStage = "Planting.GrowthStage",
	GrowthReady = "Planting.Ready",
	Harvest = "Planting.HarvestNormal",
	Sell = "Economy.Sell",
	FeedVoid = "Void.Feed",
	Display = "Display.Place",
	VoidmiteSpawn = "Voidmite.Spawn",
	VoidmiteCleanse = "Voidmite.Cleanse",
	Rebirth = "Progression.RebirthActivate",
	CollectPhantom = "Events.PhantomCaught",
	PhantomCaught = "Events.PhantomCaught",
	VoidEvent = "Void.EventStart",
	VoidEventStart = "Void.EventStart",
}

local preloadKeys = {
	"UI.Click",
	"UI.OpenPanel",
	"UI.ClosePanel",
	"UI.Error",
	"Planting.PlantSeed",
	"Planting.HarvestNormal",
	"Economy.Buy",
	"Economy.Sell",
	"Void.Feed",
	"Void.EventStart",
}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[FEED THE VOID][SoundController] " .. tostring(message))
end

local function isZeroId(soundId)
	return soundId == nil or soundId == "" or soundId == "rbxassetid://0" or soundId == "0"
end

local function normalizeKey(pathOrKey)
	if type(pathOrKey) ~= "string" or pathOrKey == "" then
		return nil
	end
	return legacyEffectKeys[pathOrKey] or pathOrKey
end

local function resolve(pathOrKey)
	local key = normalizeKey(pathOrKey)
	if not key then
		return nil, nil
	end
	local node = SoundConfig
	for part in string.gmatch(key, "[^%.]+") do
		node = type(node) == "table" and node[part] or nil
		if node == nil then
			return nil, key
		end
	end
	if type(node) ~= "table" then
		return nil, key
	end
	return node, key
end

local function ensureSoundGroup(name)
	if type(name) ~= "string" or name == "" then
		name = "SFX"
	end
	if soundGroups[name] then
		return soundGroups[name]
	end
	local group = SoundService:FindFirstChild(name)
	if not group or not group:IsA("SoundGroup") then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	soundGroups[name] = group
	return group
end

local function applyGroupVolumes()
	for groupName, group in pairs(soundGroups) do
		local baseVolume = groupBaseVolumes[groupName] or 1
		local override = groupVolumeOverrides[groupName]
		local volume = override ~= nil and override or baseVolume
		if muted then
			group.Volume = 0
		elseif lowDetailMode and groupName == "Ambience" then
			group.Volume = math.clamp(volume * 0.45, 0, 1)
		else
			group.Volume = math.clamp(volume, 0, 1.2)
		end
	end
end

local function ensureSoundGroups()
	local groups = type(SoundConfig.Groups) == "table" and SoundConfig.Groups or {}
	for _, groupName in ipairs({ "Master", "UI", "SFX", "Ambience" }) do
		local definition = groups[groupName] or {}
		groupBaseVolumes[groupName] = tonumber(definition.Volume) or groupBaseVolumes[groupName] or 1
		ensureSoundGroup(groupName)
	end
	for groupName, definition in pairs(groups) do
		if type(definition) == "table" then
			groupBaseVolumes[groupName] = tonumber(definition.Volume) or groupBaseVolumes[groupName] or 1
			ensureSoundGroup(groupName)
		end
	end
	applyGroupVolumes()
end

local function canPlay(key, minInterval)
	local now = os.clock()
	local cooldown = tonumber(minInterval) or 0.08
	if (lastPlayedAt[key] or 0) + cooldown > now then
		return false
	end
	lastPlayedAt[key] = now
	return true
end

local function basePartFromInstance(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Attachment") and instance.Parent and instance.Parent:IsA("BasePart") then
		return instance.Parent
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function positionFromTarget(target)
	if typeof(target) == "Vector3" then
		return target
	end
	local part = basePartFromInstance(target)
	return part and part.Position or nil
end

local function soundParentForTarget(target, loopKey)
	local part = basePartFromInstance(target)
	if part then
		return part, nil
	end
	local position = positionFromTarget(target)
	if not position then
		return SoundService, nil
	end
	local emitter = Instance.new("Part")
	emitter.Name = loopKey and ("FTVLoopEmitter_" .. tostring(loopKey)) or "FTVSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.CFrame = CFrame.new(position)
	emitter.Parent = Workspace
	return emitter, emitter
end

local function createSound(pathOrKey, parent, options)
	local definition, resolvedKey = resolve(pathOrKey)
	if not definition then
		warnOnce("Missing_" .. tostring(pathOrKey), "Missing SoundConfig key " .. tostring(pathOrKey))
		return nil, resolvedKey
	end
	if isZeroId(definition.Id) then
		return nil, resolvedKey
	end
	if type(definition.Id) ~= "string" or not string.match(definition.Id, "^rbxassetid://%d+$") then
		warnOnce("Malformed_" .. tostring(resolvedKey), "Malformed sound id for " .. tostring(resolvedKey))
		return nil, resolvedKey
	end

	local sound = Instance.new("Sound")
	sound.Name = "FTV_" .. string.gsub(tostring(resolvedKey), "%.", "_")
	sound.SoundId = definition.Id
	sound.Volume = math.clamp((tonumber(definition.Volume) or 0.5) * (tonumber(options and options.VolumeScale) or 1), 0, 1.2)
	sound.Looped = options and options.Looped ~= nil and options.Looped == true or definition.Looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = tonumber(definition.RollOffMinDistance) or 8
	sound.RollOffMaxDistance = tonumber(options and options.RollOffMaxDistance) or tonumber(definition.RollOffMaxDistance) or 80
	sound.SoundGroup = ensureSoundGroup(definition.Group or "SFX")
	sound.Parent = parent or SoundService
	return sound, resolvedKey
end

local function cleanupLoop(loopKey)
	local entry = loops[loopKey]
	if not entry then
		return
	end
	loops[loopKey] = nil
	if entry.Sound then
		pcall(function()
			entry.Sound:Stop()
		end)
		entry.Sound:Destroy()
	end
	if entry.Emitter then
		entry.Emitter:Destroy()
	end
	if entry.Connection then
		entry.Connection:Disconnect()
	end
end

local function bindButton(button)
	if not button:IsA("GuiButton") or buttonConnections[button] then
		return
	end
	buttonConnections[button] = button.Activated:Connect(function()
		SoundController.PlayUI("UI.Click", { MinInterval = 0.04 })
	end)
end

local function bindUiClicks(root)
	if typeof(root) ~= "Instance" then
		return
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		bindButton(descendant)
	end
	root.DescendantAdded:Connect(bindButton)
end

local function findFirstByNames(root, names)
	if typeof(root) ~= "Instance" then
		return nil
	end
	for _, name in ipairs(names) do
		local found = root:FindFirstChild(name)
		if found then
			return found
		end
		found = root:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function findPlayerPlot()
	local players = game:GetService("Players")
	local player = players.LocalPlayer
	local world = Workspace:FindFirstChild("GameWorld")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if tonumber(plot:GetAttribute("OwnerUserId")) == player.UserId or plot:GetAttribute("OwnerName") == player.Name then
			return plot
		end
	end
	local assigned = player:GetAttribute("AssignedPlotId")
	if assigned then
		return plots:FindFirstChild("Plot" .. tostring(assigned))
	end
	return nil
end

local function startStationLoops()
	local world = Workspace:FindFirstChild("GameWorld")
	if not world then
		return
	end
	local plot = findPlayerPlot()
	local roots = {}
	if plot then
		table.insert(roots, plot)
	end
	local stations = world:FindFirstChild("Stations")
	if stations then
		table.insert(roots, stations)
	end

	local seedIndex = 0
	local upgradeIndex = 0
	for _, root in ipairs(roots) do
		for _, descendant in ipairs(root:GetDescendants()) do
			local name = string.lower(descendant.Name)
			if seedIndex < 4 and string.find(name, "seed") and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
				seedIndex += 1
				SoundController.StartLoop("SeedMachine_" .. tostring(seedIndex), descendant, { Key = "Ambience.SeedMachineLoop" })
			elseif upgradeIndex < 4 and string.find(name, "upgrade") and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
				upgradeIndex += 1
				SoundController.StartLoop("UpgradeStation_" .. tostring(upgradeIndex), descendant, { Key = "Ambience.UpgradeStationLoop" })
			end
			if seedIndex >= 4 and upgradeIndex >= 4 then
				return
			end
		end
	end
end

local function startAmbience()
	if ambienceStarted then
		return
	end
	ambienceStarted = true
	SoundController.StartLoop("MapVoidLoop", SoundService, { Key = "Ambience.MapVoidLoop" })
	local world = Workspace:FindFirstChild("GameWorld")
	local central = world and world:FindFirstChild("CentralVoid")
	local voidTarget = central and findFirstByNames(central, { "VoidCore", "FeedStation", "CentralVoid" })
	if voidTarget then
		SoundController.StartLoop("CentralVoidIdle", voidTarget, { Key = "Void.IdleLoop" })
	end
	local rebirth = world and findFirstByNames(world, { "RebirthPortal", "RebirthStation", "RebirthPad" })
	if rebirth then
		SoundController.StartLoop("RebirthPortal", rebirth, { Key = "Ambience.RebirthPortalHumLoop" })
	end
	startStationLoops()
end

local function preloadHighPriority()
	task.spawn(function()
		local preloadSounds = {}
		for _, key in ipairs(preloadKeys) do
			local definition = resolve(key)
			if definition and not isZeroId(definition.Id) then
				local sound = Instance.new("Sound")
				sound.Name = "FTVPreload_" .. string.gsub(key, "%.", "_")
				sound.SoundId = definition.Id
				sound.Volume = 0
				sound.Parent = SoundService
				table.insert(preloadSounds, sound)
			end
		end
		if #preloadSounds > 0 then
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync(preloadSounds)
			end)
			if not ok then
				warnOnce("PreloadFailed", "Audio preload skipped: " .. tostring(err))
			end
		end
		for _, sound in ipairs(preloadSounds) do
			sound:Destroy()
		end
	end)
end

local function handlePlaySoundPayload(payload)
	if type(payload) ~= "table" then
		return
	end
	local mode = payload.Mode or "Global"
	local key = payload.Key
	if type(key) ~= "string" and mode ~= "LoopStop" and mode ~= "StopAll" then
		return
	end
	if mode == "UI" then
		SoundController.PlayUI(key, payload)
	elseif mode == "World" then
		SoundController.PlayWorld(key, payload.Target or payload.Position, payload)
	elseif mode == "Status" then
		local status = SoundController.GetStatus()
		print("[FEED THE VOID][MixCheck][Client] muted=" .. tostring(status.Muted) .. " lowDetail=" .. tostring(status.LowDetailMode) .. " activeLoops=" .. tostring(status.ActiveLoops) .. " keys=" .. table.concat(status.ActiveLoopKeys, ","))
	elseif mode == "LoopStart" then
		SoundController.StartLoop(payload.LoopKey or key, payload.Target or payload.Position or SoundService, {
			Key = key,
			VolumeScale = payload.VolumeScale,
			RollOffMaxDistance = payload.RollOffMaxDistance,
		})
	elseif mode == "LoopStop" then
		SoundController.StopLoop(payload.LoopKey or key)
	elseif mode == "StopAll" then
		SoundController.StopAllLoops()
	else
		SoundController.Play(key, payload)
	end
end

function SoundController.Init(uiRoot)
	if initialized then
		bindUiClicks(uiRoot)
		return
	end
	initialized = true
	ensureSoundGroups()
	bindUiClicks(uiRoot)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		local settings = type(data) == "table" and data.Settings or {}
		SoundController.SetMuted(settings.MuteSounds == true)
		lowDetailMode = settings.LowDetailMode == true
		applyGroupVolumes()
		startAmbience()
	end)

	local playSound = remotes:FindFirstChild("PlaySound") or remotes:WaitForChild("PlaySound", 10)
	if playSound then
		playSound.OnClientEvent:Connect(handlePlaySoundPayload)
	else
		warnOnce("MissingRemote", "PlaySound remote missing; server-triggered audio disabled.")
	end

	local playEffect = remotes:FindFirstChild("PlayEffect")
	if playEffect then
		playEffect.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			if payload.SoundKey then
				local target = payload.Target or payload.Position
				SoundController.PlayWorld(payload.SoundKey, target, payload)
			elseif payload.Type and legacyEffectKeys[payload.Type] then
				SoundController.PlayWorld(legacyEffectKeys[payload.Type], payload.Target or payload.Position, payload)
			end
		end)
	end

	preloadHighPriority()
	task.delay(4, startAmbience)
end

function SoundController.Play(pathOrKey, options)
	if muted then
		return nil
	end
	local definition, key = resolve(pathOrKey)
	if definition and definition.Group == "Ambience" and lowDetailMode and options and options.SkipInLowDetail then
		return nil
	end
	key = key or normalizeKey(pathOrKey)
	if not key or not canPlay(key, options and options.MinInterval) then
		return nil
	end
	local sound = createSound(key, SoundService, options)
	if not sound then
		return nil
	end
	local ok, err = pcall(function()
		sound:Play()
	end)
	if not ok then
		warnOnce("PlayFailed_" .. tostring(key), "Failed to play " .. tostring(key) .. ": " .. tostring(err))
		sound:Destroy()
		return nil
	end
	Debris:AddItem(sound, math.max(4, (sound.TimeLength > 0 and sound.TimeLength + 1.5 or 8)))
	sound.Ended:Once(function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

function SoundController.PlayUI(pathOrKey, options)
	return SoundController.Play(pathOrKey, options)
end

function SoundController.PlayWorld(pathOrKey, positionOrInstance, options)
	if muted then
		return nil
	end
	local key = normalizeKey(pathOrKey)
	if not key or not canPlay("World_" .. key, options and options.MinInterval) then
		return nil
	end
	local parent, emitter = soundParentForTarget(positionOrInstance)
	local sound = createSound(key, parent, options)
	if not sound then
		if emitter then
			emitter:Destroy()
		end
		return nil
	end
	local ok, err = pcall(function()
		sound:Play()
	end)
	if not ok then
		warnOnce("WorldPlayFailed_" .. tostring(key), "Failed to play world sound " .. tostring(key) .. ": " .. tostring(err))
		sound:Destroy()
		if emitter then
			emitter:Destroy()
		end
		return nil
	end
	local lifetime = math.max(4, (sound.TimeLength > 0 and sound.TimeLength + 1.5 or 9))
	Debris:AddItem(sound, lifetime)
	if emitter then
		Debris:AddItem(emitter, lifetime)
	end
	sound.Ended:Once(function()
		if sound.Parent then
			sound:Destroy()
		end
		if emitter and emitter.Parent then
			emitter:Destroy()
		end
	end)
	return sound
end

function SoundController.StartLoop(loopKey, parentOrPosition, options)
	loopKey = tostring(loopKey or (options and options.Key) or "")
	if loopKey == "" then
		return nil
	end
	if loops[loopKey] then
		return loops[loopKey].Sound
	end
	local soundKey = options and options.Key or loopKey
	local parent, emitter = soundParentForTarget(parentOrPosition, loopKey)
	local sound = createSound(soundKey, parent, {
		Looped = true,
		VolumeScale = options and options.VolumeScale,
		RollOffMaxDistance = options and options.RollOffMaxDistance,
	})
	if not sound then
		if emitter then
			emitter:Destroy()
		end
		return nil
	end
	sound.Looped = true
	loops[loopKey] = {
		Sound = sound,
		Emitter = emitter,
	}
	if typeof(parentOrPosition) == "Instance" then
		loops[loopKey].Connection = parentOrPosition.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				cleanupLoop(loopKey)
			end
		end)
	end
	local ok, err = pcall(function()
		sound:Play()
	end)
	if not ok then
		warnOnce("LoopFailed_" .. loopKey, "Failed to start loop " .. loopKey .. ": " .. tostring(err))
		cleanupLoop(loopKey)
		return nil
	end
	return sound
end

function SoundController.StopLoop(loopKey)
	cleanupLoop(tostring(loopKey or ""))
end

function SoundController.StopAllLoops()
	for loopKey in pairs(loops) do
		cleanupLoop(loopKey)
	end
	ambienceStarted = false
end

function SoundController.SetMuted(isMuted)
	muted = isMuted == true
	applyGroupVolumes()
	if muted then
		for _, entry in pairs(loops) do
			if entry.Sound then
				entry.Sound.Volume = 0
			end
		end
	else
		for _, entry in pairs(loops) do
			if entry.Sound and entry.Sound.Parent then
				local definition = resolve(entry.Sound.Name:gsub("^FTV_", ""):gsub("_", "."))
				entry.Sound.Volume = definition and tonumber(definition.Volume) or entry.Sound.Volume
			end
		end
		if initialized then
			task.delay(0.1, startAmbience)
		end
	end
end

function SoundController.SetGroupVolume(groupName, volume)
	if type(groupName) ~= "string" then
		return
	end
	groupVolumeOverrides[groupName] = math.clamp(tonumber(volume) or 0, 0, 1.2)
	ensureSoundGroup(groupName)
	applyGroupVolumes()
end

function SoundController.TestSound(pathOrKey)
	local definition, key = resolve(pathOrKey)
	if not definition then
		warnOnce("TestMissing_" .. tostring(pathOrKey), "Cannot test missing sound " .. tostring(pathOrKey))
		return false
	end
	if definition.Looped then
		SoundController.StartLoop("Test_" .. tostring(key), SoundService, { Key = key })
		task.delay(2.5, function()
			SoundController.StopLoop("Test_" .. tostring(key))
		end)
	else
		SoundController.Play(key, { MinInterval = 0 })
	end
	return true
end

function SoundController.GetStatus()
	local count = 0
	local keys = {}
	for _ in pairs(loops) do
		count += 1
	end
	for loopKey in pairs(loops) do
		table.insert(keys, tostring(loopKey))
	end
	table.sort(keys)
	return {
		Muted = muted,
		LowDetailMode = lowDetailMode,
		ActiveLoops = count,
		ActiveLoopKeys = keys,
	}
end

return SoundController
