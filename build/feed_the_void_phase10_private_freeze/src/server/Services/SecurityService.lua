local Players = game:GetService("Players")

local SecurityService = {}

local invalidByPlayer = {}
local ignoredUntil = {}
local recentLog = {}

local function config()
	return SecurityService.Context.Config.GameConfig.Security or {}
end

local function keyFor(player, remoteName)
	return tostring(player.UserId) .. ":" .. tostring(remoteName or "*")
end

local function pushLog(entry)
	table.insert(recentLog, 1, entry)
	while #recentLog > 40 do
		table.remove(recentLog)
	end
end

function SecurityService.Init(context)
	SecurityService.Context = context
end

function SecurityService.Start() end

function SecurityService.CanProcess(player, remoteName)
	if not player then
		return false
	end
	local untilTime = ignoredUntil[keyFor(player, remoteName)] or ignoredUntil[keyFor(player, "*")]
	if untilTime and os.clock() < untilTime then
		return false
	end
	return true
end

function SecurityService.RecordInvalid(player, remoteName, reason)
	if not player then
		return
	end
	local nowClock = os.clock()
	local window = config().InvalidRemoteWindowSeconds or 10
	local threshold = config().InvalidRemoteWarnThreshold or 5
	local key = keyFor(player, remoteName)
	local bucket = invalidByPlayer[key]
	if not bucket or nowClock - bucket.StartedAt > window then
		bucket = {
			StartedAt = nowClock,
			Count = 0,
		}
		invalidByPlayer[key] = bucket
	end
	bucket.Count += 1
	local entry = {
		PlayerName = player.Name,
		UserId = player.UserId,
		RemoteName = tostring(remoteName or "?"),
		Reason = tostring(reason or "invalid"),
		At = os.time(),
		Count = bucket.Count,
	}
	pushLog(entry)
	if bucket.Count >= threshold then
		local ignoreSeconds = config().TemporaryIgnoreSeconds or 5
		ignoredUntil[key] = nowClock + ignoreSeconds
		warn("[FEED THE VOID][Security] temporarily ignoring", player.Name, remoteName, "reason=", reason, "count=", bucket.Count)
	else
		warn("[FEED THE VOID][Security] invalid remote", player.Name, player.UserId, remoteName, reason)
	end
end

function SecurityService.GetSummary()
	local totalInvalid = 0
	for _, bucket in pairs(invalidByPlayer) do
		totalInvalid += bucket.Count
	end
	local ignored = 0
	for _, untilTime in pairs(ignoredUntil) do
		if os.clock() < untilTime then
			ignored += 1
		end
	end
	return {
		TotalInvalid = totalInvalid,
		ActiveIgnores = ignored,
		Recent = recentLog,
		PlayerCount = #Players:GetPlayers(),
	}
end

function SecurityService.PlayerRemoving(player)
	if not player then
		return
	end
	local prefix = tostring(player.UserId) .. ":"
	for key in pairs(invalidByPlayer) do
		if string.sub(key, 1, #prefix) == prefix then
			invalidByPlayer[key] = nil
		end
	end
	for key in pairs(ignoredUntil) do
		if string.sub(key, 1, #prefix) == prefix then
			ignoredUntil[key] = nil
		end
	end
end

return SecurityService
