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

function ValidationService.ValidateInventoryItem(player, uniqueId)
	local item, index = ValidationService.Context.Services.InventoryService.FindItem(player, uniqueId)
	return item ~= nil, item, index
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
	if typeof(instance) ~= "Instance" then
		return false, nil
	end
	if not instance:IsDescendantOf(workspace) then
		return false, nil
	end
	if expectedType and not instance:IsA(expectedType) then
		return false, nil
	end
	return true, instance
end

function ValidationService.ValidateDistance(player, target, maxDistance)
	if typeof(target) ~= "Instance" then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local position
	if target:IsA("Model") then
		position = target:GetPivot().Position
	elseif target:IsA("BasePart") then
		position = target.Position
	elseif target.Parent and target.Parent:IsA("BasePart") then
		position = target.Parent.Position
	end
	if not position then
		return false
	end
	return (root.Position - position).Magnitude <= maxDistance
end

return ValidationService
