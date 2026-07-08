local SettingsService = {}

local allowed = {
	ReduceEffects = true,
	LowDetailMode = true,
	MuteSounds = true,
	HideExtraPopups = true,
	AutoClosePanels = true,
	ShowGuidance = true,
}

local function applyDefaults(config, settings)
	settings = type(settings) == "table" and settings or {}
	for key, value in pairs(config.SettingsDefaults or {}) do
		if settings[key] == nil then
			settings[key] = value
		end
	end
	return settings
end

function SettingsService.Init(context)
	SettingsService.Context = context
end

function SettingsService.Start() end

function SettingsService.Ensure(player)
	local data = SettingsService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return nil
	end
	data.Settings = applyDefaults(SettingsService.Context.Config.GameConfig, data.Settings)
	return data.Settings
end

function SettingsService.Update(player, key, value)
	if not allowed[key] then
		return false
	end
	local settings = SettingsService.Ensure(player)
	if not settings then
		return false
	end
	settings[key] = value == true
	SettingsService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	SettingsService.Context.Services.EconomyService.Sync(player)
	return true
end

function SettingsService.Serialize(player)
	local settings = SettingsService.Ensure(player) or {}
	local result = {}
	for key in pairs(allowed) do
		result[key] = settings[key] == true
	end
	return result
end

return SettingsService
