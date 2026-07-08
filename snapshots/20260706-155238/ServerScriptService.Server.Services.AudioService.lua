local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local AudioService = {}

local warned = {}
local lastPlayed = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[FEED THE VOID][AudioService] " .. tostring(message))
end

local function normalizeId(value)
	if type(value) == "number" then
		return "rbxassetid://" .. tostring(math.floor(value))
	end
	if type(value) ~= "string" then
		return nil
	end
	if string.match(value, "^%d+$") then
		return "rbxassetid://" .. value
	end
	return value
end

local function resolve(pathOrKey)
	if type(pathOrKey) ~= "string" or pathOrKey == "" then
		return nil, nil
	end
	local config = AudioService.Context and AudioService.Context.Config and AudioService.Context.Config.SoundConfig
	if type(config) ~= "table" then
		warnOnce("MissingConfig", "SoundConfig is missing.")
		return nil, pathOrKey
	end
	local node = config
	for part in string.gmatch(pathOrKey, "[^%.]+") do
		node = type(node) == "table" and node[part] or nil
		if node == nil then
			return nil, pathOrKey
		end
	end
	if type(node) ~= "table" then
		return nil, pathOrKey
	end
	return node, pathOrKey
end

local function isZeroId(soundId)
	return soundId == nil or soundId == "" or soundId == "rbxassetid://0" or soundId == "0"
end

local function targetPosition(target)
	if typeof(target) == "Vector3" then
		return target
	end
	if typeof(target) ~= "Instance" then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	end
	if target:IsA("Attachment") then
		return target.WorldPosition
	end
	if target:IsA("Model") then
		local ok, pivot = pcall(function()
			return target:GetPivot()
		end)
		if ok then
			return pivot.Position
		end
	end
	local part = target:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function checkThrottle(player, key, options)
	if options and options.NoThrottle == true then
		return true
	end
	local interval = tonumber(options and options.MinInterval) or 0.18
	local scope = player and tostring(player.UserId) or "ALL"
	local bucketKey = scope .. ":" .. tostring(key)
	local now = os.clock()
	if (lastPlayed[bucketKey] or 0) + interval > now then
		return false
	end
	lastPlayed[bucketKey] = now
	return true
end

local function payloadFor(key, mode, target, options)
	local definition = select(1, resolve(key))
	if not definition then
		warnOnce("Missing_" .. tostring(key), "Missing sound key " .. tostring(key))
		return nil
	end
	local soundId = normalizeId(definition.Id)
	if isZeroId(soundId) then
		return nil
	end
	if type(soundId) ~= "string" or not string.match(soundId, "^rbxassetid://%d+$") then
		warnOnce("Malformed_" .. tostring(key), "Malformed sound id for " .. tostring(key))
		return nil
	end
	local payload = {
		Key = key,
		Mode = mode or "Global",
	}
	if typeof(target) == "Instance" then
		payload.Target = target
	elseif typeof(target) == "Vector3" then
		payload.Position = target
	elseif target ~= nil then
		payload.Position = targetPosition(target)
	end
	if options then
		payload.LoopKey = options.LoopKey
		payload.VolumeScale = options.VolumeScale
		payload.RollOffMaxDistance = options.RollOffMaxDistance
		payload.MinInterval = options.MinInterval
	end
	return payload
end

local function ensureSoundGroups()
	local config = AudioService.Context and AudioService.Context.Config and AudioService.Context.Config.SoundConfig
	local groups = type(config) == "table" and type(config.Groups) == "table" and config.Groups or {}
	for _, name in ipairs({ "Master", "UI", "SFX", "Ambience" }) do
		local group = SoundService:FindFirstChild(name)
		if not group or not group:IsA("SoundGroup") then
			group = Instance.new("SoundGroup")
			group.Name = name
			group.Parent = SoundService
		end
		group.Volume = math.clamp(tonumber(groups[name] and groups[name].Volume) or group.Volume or 1, 0, 1.2)
	end
end

local function traverseSoundEntries(node, prefix, stats)
	for key, value in pairs(node or {}) do
		if key ~= "Groups" and type(value) == "table" then
			local nextPrefix = prefix and (prefix .. "." .. tostring(key)) or tostring(key)
			if value.Id ~= nil then
				local id = normalizeId(value.Id)
				local hasValidShape = type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
				stats.Total += 1
				if isZeroId(id) then
					stats.Disabled += 1
				elseif hasValidShape then
					stats.Valid += 1
				else
					stats.Malformed += 1
					table.insert(stats.MalformedKeys, nextPrefix)
				end
				local volume = tonumber(value.Volume)
				if volume == nil or volume < 0 or volume > 1.2 then
					stats.BadVolume += 1
					table.insert(stats.BadVolumeKeys, nextPrefix)
				end
				if value.Looped ~= true and value.Looped ~= false then
					stats.BadLoopFlag += 1
					table.insert(stats.BadLoopFlagKeys, nextPrefix)
				end
			else
				traverseSoundEntries(value, nextPrefix, stats)
			end
		end
	end
end

function AudioService.Init(context)
	AudioService.Context = context
	ensureSoundGroups()
end

function AudioService.Start() end

function AudioService.ValidateKey(key)
	local definition = select(1, resolve(key))
	if not definition then
		return false, "missing"
	end
	local id = normalizeId(definition.Id)
	if isZeroId(id) then
		return false, "disabled"
	end
	if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then
		return false, "malformed"
	end
	return true, definition
end

function AudioService.PlayForPlayer(player, key, mode, target, options)
	if not player or player.Parent ~= Players then
		return false
	end
	if not checkThrottle(player, key, options) then
		return false
	end
	local remote = AudioService.Context and AudioService.Context.Remotes and AudioService.Context.Remotes.PlaySound
	if not remote then
		warnOnce("MissingRemote", "PlaySound remote is missing.")
		return false
	end
	local payload = payloadFor(key, mode or "Global", target, options)
	if not payload then
		return false
	end
	remote:FireClient(player, payload)
	return true
end

function AudioService.PlayUI(player, key, options)
	return AudioService.PlayForPlayer(player, key, "UI", nil, options)
end

function AudioService.PlayForAll(key, mode, target, options)
	local remote = AudioService.Context and AudioService.Context.Remotes and AudioService.Context.Remotes.PlaySound
	if not remote then
		warnOnce("MissingRemoteAll", "PlaySound remote is missing.")
		return false
	end
	if not checkThrottle(nil, key, options) then
		return false
	end
	local payload = payloadFor(key, mode or "Global", target, options)
	if not payload then
		return false
	end
	remote:FireAllClients(payload)
	return true
end

function AudioService.PlayWorldForNearbyPlayers(key, target, radius, options)
	local position = targetPosition(target)
	if not position then
		return false
	end
	local played = false
	local maxDistance = tonumber(radius) or 70
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= maxDistance then
			played = AudioService.PlayForPlayer(player, key, "World", target, options) or played
		end
	end
	return played
end

function AudioService.StartLoop(player, loopKey, key, target, options)
	options = type(options) == "table" and table.clone(options) or {}
	options.LoopKey = loopKey
	return AudioService.PlayForPlayer(player, key, "LoopStart", target, options)
end

function AudioService.StopLoop(player, loopKey)
	local remote = AudioService.Context and AudioService.Context.Remotes and AudioService.Context.Remotes.PlaySound
	if player and remote then
		remote:FireClient(player, {
			Mode = "LoopStop",
			LoopKey = loopKey,
		})
		return true
	end
	return false
end

function AudioService.StopAllLoops(player)
	local remote = AudioService.Context and AudioService.Context.Remotes and AudioService.Context.Remotes.PlaySound
	if player and remote then
		remote:FireClient(player, {
			Mode = "StopAll",
		})
		return true
	end
	return false
end

function AudioService.GetConfigStats()
	local stats = {
		Total = 0,
		Valid = 0,
		Disabled = 0,
		Malformed = 0,
		BadVolume = 0,
		BadLoopFlag = 0,
		MalformedKeys = {},
		BadVolumeKeys = {},
		BadLoopFlagKeys = {},
	}
	local config = AudioService.Context and AudioService.Context.Config and AudioService.Context.Config.SoundConfig
	if type(config) == "table" then
		traverseSoundEntries(config, nil, stats)
	end
	return stats
end

function AudioService.PrintStatus(player)
	local stats = AudioService.GetConfigStats()
	local line = string.format(
		"[FEED THE VOID][Audio] configured=%d valid=%d disabled=%d malformed=%d badVolume=%d badLoopFlag=%d",
		stats.Total,
		stats.Valid,
		stats.Disabled,
		stats.Malformed,
		stats.BadVolume,
		stats.BadLoopFlag
	)
	print(line)
	if player and AudioService.Context and AudioService.Context.Services.EconomyService then
		AudioService.Context.Services.EconomyService.Notify(player, "Audio: " .. tostring(stats.Valid) .. " valid, " .. tostring(stats.Disabled) .. " disabled, " .. tostring(stats.Malformed) .. " malformed.")
	end
	return stats
end

function AudioService.TestSound(player, key)
	if not player then
		return false
	end
	local ok, reason = AudioService.ValidateKey(key)
	if not ok then
		if AudioService.Context and AudioService.Context.Services.EconomyService then
			AudioService.Context.Services.EconomyService.Notify(player, "Sound unavailable: " .. tostring(key) .. " (" .. tostring(reason) .. ")")
		end
		return false
	end
	return AudioService.PlayForPlayer(player, key, "UI", nil, { NoThrottle = true })
end

function AudioService.TestSequence(player)
	local sequence = {
		"UI.Click",
		"UI.OpenPanel",
		"Planting.PlantSeed",
		"Planting.GrowthStage",
		"Planting.HarvestNormal",
		"Economy.Buy",
		"Economy.Sell",
		"Void.Feed",
		"Void.EventStart",
	}
	for index, key in ipairs(sequence) do
		task.delay((index - 1) * 0.65, function()
			if player.Parent == Players then
				AudioService.PlayForPlayer(player, key, "UI", nil, { NoThrottle = true })
			end
		end)
	end
	return true
end

return AudioService
