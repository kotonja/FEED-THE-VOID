local ValidationUtil = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("ValidationUtil"))

local ValidationService = {}

function ValidationService.Init(context)
	ValidationService.Context = context
end

function ValidationService.Start() end

function ValidationService.ValidatePlayerProfile(player)
	local data = ValidationService.Context.Services.ProfileServiceWrapper.GetData(player)
	return data ~= nil, data
end

function ValidationService.ValidatePlayerPlot(player)
	local plot = ValidationService.Context.Services.PlotService.GetPlot(player)
	return plot ~= nil, plot
end

function ValidationService.ValidateInventoryItem(player, uniqueId, options)
	local item, index = ValidationService.Context.Services.InventoryService.FindItem(player, uniqueId)
	if not item then
		return false, item, index
	end
	options = type(options) == "table" and options or {}
	if options.AllowLocked ~= true and item.Locked == true then
		return false, item, index, "Locked"
	end
	return true, item, index
end

function ValidationService.ValidateSeed(player, snackId)
	local data = ValidationService.Context.Services.ProfileServiceWrapper.GetData(player)
	local snack = ValidationService.Context.Config.SnackConfig[snackId]
	if not data or not snack then
		return false, snack
	end
	return (data.Seeds[snackId] or 0) > 0, snack
end

function ValidationService.ValidateSnackConfig(snackId)
	local snack = ValidationService.Context.Config.SnackConfig[snackId]
	return snack ~= nil, snack
end

function ValidationService.ValidateWorldObject(instance, expectedType)
	if not ValidationUtil.IsWorkspaceInstance(instance, expectedType) then
		return false, nil
	end
	return true, instance
end

function ValidationService.ValidateDistance(player, target, maxDistance)
	local padding = ValidationService.Context and ValidationService.Context.Config.GameConfig.AntiExploit and ValidationService.Context.Config.GameConfig.AntiExploit.MaxDistancePadding or 0
	return ValidationUtil.IsWithinDistance(player, target, (tonumber(maxDistance) or 0) + padding)
end

return ValidationService
