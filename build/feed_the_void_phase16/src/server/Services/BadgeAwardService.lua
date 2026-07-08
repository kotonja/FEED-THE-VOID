local BadgeService = game:GetService("BadgeService")
local RunService = game:GetService("RunService")

local BadgeAwardService = {}

function BadgeAwardService.Init(context)
	BadgeAwardService.Context = context
end

function BadgeAwardService.Start() end

local function ensureData(data)
	data.BadgesAwarded = type(data.BadgesAwarded) == "table" and data.BadgesAwarded or {}
	return data.BadgesAwarded
end

function BadgeAwardService.Award(player, badgeKey)
	local context = BadgeAwardService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return false
	end
	local awarded = ensureData(data)
	if awarded[badgeKey] then
		return false
	end
	awarded[badgeKey] = true
	context.Services.ProfileServiceWrapper.MarkDirty(player)

	local badgeId = context.Config.GameConfig.BadgeConfig and context.Config.GameConfig.BadgeConfig[badgeKey]
	if not badgeId or badgeId == 0 then
		if context.Config.GameConfig.DebugMode then
			print("[FEED THE VOID] Badge " .. tostring(badgeKey) .. " would be awarded, but no badge ID configured.")
		end
		return true
	end

	task.spawn(function()
		local ok, err = pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				BadgeService:AwardBadge(player.UserId, badgeId)
			end
		end)
		if not ok and (context.Config.GameConfig.DebugMode or RunService:IsStudio()) then
			warn("[FEED THE VOID] Badge award failed", badgeKey, err)
		end
	end)
	return true
end

function BadgeAwardService.Serialize(player)
	local data = BadgeAwardService.Context.Services.ProfileServiceWrapper.GetData(player)
	local awarded = data and ensureData(data) or {}
	local result = {}
	for key, value in pairs(awarded) do
		result[key] = value == true
	end
	return result
end

return BadgeAwardService
