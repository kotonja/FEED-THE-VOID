local Players = game:GetService("Players")

local VFXService = {}

local warned = {}
local throttleByPlayer = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[FEED THE VOID][VFXService] " .. tostring(message))
end

local function config()
	return VFXService.Context and VFXService.Context.Config and VFXService.Context.Config.VFXConfig or {}
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
	if target:IsA("Model") then
		return target:GetPivot().Position
	end
	local part = target:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function keySet()
	local set = {}
	for _, key in ipairs(config().EffectKeys or {}) do
		set[key] = true
	end
	return set
end

local function normalizeKey(effectKey)
	effectKey = tostring(effectKey or "")
	local vfxConfig = config()
	local alias = vfxConfig.Aliases and vfxConfig.Aliases[effectKey]
	if alias then
		effectKey = alias
	end
	return effectKey
end

local function throttleKey(player, key)
	if not player then
		return "global:" .. tostring(key)
	end
	return tostring(player.UserId) .. ":" .. tostring(key)
end

local function passesThrottle(player, key, payload)
	payload = type(payload) == "table" and payload or {}
	if payload.NoThrottle == true then
		return true
	end
	local minInterval = tonumber(payload.MinInterval) or 0.08
	if minInterval <= 0 then
		return true
	end
	local now = os.clock()
	local bucketKey = throttleKey(player, key)
	local last = throttleByPlayer[bucketKey]
	if last and now - last < minInterval then
		return false
	end
	throttleByPlayer[bucketKey] = now
	return true
end

local function makePayload(effectKey, payload)
	payload = type(payload) == "table" and table.clone(payload) or {}
	local target = payload.Target or payload.Instance
	local position = payload.Position or targetPosition(target)
	payload.Key = effectKey
	payload.Mode = payload.Mode or (target and "Instance" or "World")
	payload.Target = typeof(target) == "Instance" and target or nil
	payload.Position = position
	payload.Extra = type(payload.Extra) == "table" and payload.Extra or nil
	payload.SentAt = os.clock()
	return payload
end

local function fire(player, payload)
	local remote = VFXService.Context and VFXService.Context.Remotes and VFXService.Context.Remotes.PlayEffect
	if not (remote and player) then
		return false
	end
	local ok, err = pcall(function()
		remote:FireClient(player, payload)
	end)
	if not ok then
		warnOnce("fire:" .. tostring(player), "PlayEffect FireClient failed: " .. tostring(err))
	end
	return ok
end

function VFXService.Init(context)
	VFXService.Context = context
end

function VFXService.Start() end

function VFXService.ValidateEffectKey(effectKey)
	local vfxConfig = config()
	if vfxConfig.Global and vfxConfig.Global.Enabled == false then
		return false, "disabled", normalizeKey(effectKey)
	end
	local normalized = normalizeKey(effectKey)
	if keySet()[normalized] then
		return true, nil, normalized
	end
	return false, "unknown", normalized
end

function VFXService.PlayForPlayer(player, effectKey, payload)
	local ok, reason, normalized = VFXService.ValidateEffectKey(effectKey)
	if not ok then
		warnOnce("key:" .. tostring(effectKey), "Skipped unknown VFX key " .. tostring(effectKey) .. " (" .. tostring(reason) .. ")")
		return false
	end
	if not player or not player:IsDescendantOf(Players) then
		return false
	end
	if not passesThrottle(player, normalized, payload) then
		return false
	end
	return fire(player, makePayload(normalized, payload))
end

function VFXService.PlayForAll(effectKey, payload)
	local played = false
	for _, player in ipairs(Players:GetPlayers()) do
		played = VFXService.PlayForPlayer(player, effectKey, payload) or played
	end
	return played
end

function VFXService.PlayForNearbyPlayers(effectKey, position, radius, payload)
	local center = targetPosition(position) or (type(payload) == "table" and targetPosition(payload.Target)) or (type(payload) == "table" and payload.Position)
	if typeof(center) ~= "Vector3" then
		return false
	end
	local maxDistance = tonumber(radius) or ((config().Global or {}).NearbyRadius or 72)
	local played = false
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - center).Magnitude <= maxDistance then
			local playerPayload = type(payload) == "table" and table.clone(payload) or {}
			playerPayload.Position = playerPayload.Position or center
			played = VFXService.PlayForPlayer(player, effectKey, playerPayload) or played
		end
	end
	return played
end

function VFXService.PlayWorld(effectKey, position, payload)
	local worldPayload = type(payload) == "table" and table.clone(payload) or {}
	worldPayload.Mode = worldPayload.Mode or "World"
	worldPayload.Position = worldPayload.Position or targetPosition(position) or position
	return VFXService.PlayForAll(effectKey, worldPayload)
end

function VFXService.ClearForPlayer(player)
	return VFXService.PlayForPlayer(player, "UI.ClearTemporary", {
		Mode = "Global",
		NoThrottle = true,
	})
end

function VFXService.GetConfigStats()
	local vfxConfig = config()
	local stats = {
		Configured = 0,
		Aliases = 0,
		UnknownAliases = 0,
		MaxTemporaryEffects = (vfxConfig.Global and vfxConfig.Global.MaxTemporaryEffects) or 0,
		MaxParticleCount = 0,
		ParticleGroups = 0,
	}
	local set = keySet()
	for _ in pairs(set) do
		stats.Configured += 1
	end
	for _, key in pairs(vfxConfig.Aliases or {}) do
		stats.Aliases += 1
		if not set[key] then
			stats.UnknownAliases += 1
		end
	end
	for _, particleConfig in pairs(vfxConfig.Particles or {}) do
		stats.ParticleGroups += 1
		stats.MaxParticleCount = math.max(stats.MaxParticleCount, tonumber(particleConfig.Count) or 0)
	end
	return stats
end

function VFXService.PrintStatus(player)
	local stats = VFXService.GetConfigStats()
	print(string.format(
		"[FEED THE VOID][VFX] configured=%d aliases=%d badAliases=%d maxTemporary=%d maxParticleCount=%d",
		stats.Configured,
		stats.Aliases,
		stats.UnknownAliases,
		stats.MaxTemporaryEffects,
		stats.MaxParticleCount
	))
	if player and VFXService.Context and VFXService.Context.Services.EconomyService then
		VFXService.Context.Services.EconomyService.Notify(player, "VFX: " .. tostring(stats.Configured) .. " keys, cap " .. tostring(stats.MaxTemporaryEffects) .. ".")
	end
	return stats
end

function VFXService.TestEffect(player, effectKey)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local position = root and (root.Position + root.CFrame.LookVector * 7 + Vector3.new(0, 2, 0)) or Vector3.new(0, 8, 0)
	local ok, reason, normalized = VFXService.ValidateEffectKey(effectKey)
	if not ok then
		if player and VFXService.Context and VFXService.Context.Services.EconomyService then
			VFXService.Context.Services.EconomyService.Notify(player, "VFX unavailable: " .. tostring(effectKey) .. " (" .. tostring(reason) .. ")")
		end
		return false
	end
	return VFXService.PlayForPlayer(player, normalized, {
		Mode = "World",
		Position = position,
		Text = "VFX: " .. tostring(normalized),
		DebugLabel = tostring(normalized),
		DebugBoost = true,
		DisplayName = "Debug Snack",
		MutationId = normalized == "Harvest.Rare" and "Golden" or "VoidTouched",
		IsRare = normalized == "Harvest.Rare" or normalized == "Void.FeedRare",
		NoThrottle = true,
		MinInterval = 0,
	})
end

function VFXService.TestSequence(player)
	local sequence = config().DebugSequence or {}
	VFXService.PlayForPlayer(player, "UI.RewardPopup", {
		Mode = "UI",
		Text = "VFX test sequence started",
		Type = "Quest",
		NoThrottle = true,
		MinInterval = 0,
	})
	task.spawn(function()
		for _, key in ipairs(sequence) do
			if not (player and player:IsDescendantOf(Players)) then
				break
			end
			VFXService.TestEffect(player, key)
			task.wait(0.7)
		end
	end)
	return true
end

return VFXService
