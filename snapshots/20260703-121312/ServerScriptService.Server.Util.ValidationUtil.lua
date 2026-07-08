local ValidationUtil = {}

local function getPosition(target)
	if typeof(target) ~= "Instance" then
		return nil
	end
	if target:IsA("Model") then
		return target:GetPivot().Position
	end
	if target:IsA("BasePart") then
		return target.Position
	end
	if target.Parent and target.Parent:IsA("BasePart") then
		return target.Parent.Position
	end
	return nil
end

function ValidationUtil.GetRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function ValidationUtil.IsWorkspaceInstance(instance, expectedType)
	if typeof(instance) ~= "Instance" then
		return false
	end
	if not instance:IsDescendantOf(workspace) then
		return false
	end
	if expectedType and not instance:IsA(expectedType) then
		return false
	end
	return true
end

function ValidationUtil.IsWithinDistance(player, target, maxDistance)
	local root = ValidationUtil.GetRoot(player)
	local position = getPosition(target)
	if not root or not position then
		return false
	end
	return (root.Position - position).Magnitude <= (tonumber(maxDistance) or 0)
end

function ValidationUtil.IsKnownId(value, configTable)
	if type(value) ~= "string" or value == "" then
		return false
	end
	return type(configTable) == "table" and type(configTable[value]) == "table"
end

function ValidationUtil.Boolean(value)
	return value == true
end

function ValidationUtil.CountArray(array)
	if type(array) ~= "table" then
		return 0
	end
	local count = 0
	for _ in ipairs(array) do
		count += 1
	end
	return count
end

function ValidationUtil.SafeRemotePayload(maxArgs, ...)
	if select("#", ...) > (tonumber(maxArgs) or 8) then
		return false
	end
	return true
end

return ValidationUtil
