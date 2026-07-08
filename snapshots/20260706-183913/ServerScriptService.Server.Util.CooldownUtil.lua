local CooldownUtil = {}

function CooldownUtil.Create(defaultCooldown, cooldowns)
	local limiter = {
		DefaultCooldown = tonumber(defaultCooldown) or 0.25,
		Cooldowns = cooldowns or {},
		LastUse = {},
	}

	function limiter:GetCooldown(key)
		return tonumber(self.Cooldowns[key]) or self.DefaultCooldown
	end

	function limiter:Check(player, key)
		local now = os.clock()
		self.LastUse[player] = self.LastUse[player] or {}
		local last = self.LastUse[player][key] or 0
		local cooldown = self:GetCooldown(key)
		if now - last < cooldown then
			return false, cooldown - (now - last)
		end
		self.LastUse[player][key] = now
		return true, 0
	end

	function limiter:Clear(player)
		self.LastUse[player] = nil
	end

	return limiter
end

return CooldownUtil
