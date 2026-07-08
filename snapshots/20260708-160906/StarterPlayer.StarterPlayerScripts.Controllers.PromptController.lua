local PromptController = {}

local function tunePrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = math.min(prompt.HoldDuration, 0.25)
	prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 10)
end

function PromptController.Init()
	local world = workspace:WaitForChild("GameWorld", 10)
	if not world then
		return
	end
	for _, descendant in ipairs(world:GetDescendants()) do
		tunePrompt(descendant)
	end
	world.DescendantAdded:Connect(tunePrompt)
end

return PromptController
