local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local NotificationController = {}

local labels = {}
local activeMessages = {}

local function render()
	for index, label in ipairs(labels) do
		local message = activeMessages[index]
		label.Text = message or ""
		label.Visible = message ~= nil
		if message then
			local original = label.Position
			label.TextTransparency = 1
			label.BackgroundTransparency = 1
			label.Position = original + UDim2.new(0, 0, 0, -8)
			TweenService:Create(label, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
				BackgroundTransparency = 0.08,
				Position = original,
			}):Play()
		end
	end
end

function NotificationController.Init(mainUi)
	local feed = mainUi:WaitForChild("Notifications")
	for index = 1, 3 do
		local label = feed:WaitForChild("Message" .. tostring(index))
		labels[index] = label
		label.Visible = false
	end
	local legacy = feed:FindFirstChild("NotificationText")
	if legacy then
		legacy.Visible = false
	end
end

function NotificationController.Show(message)
	table.insert(activeMessages, 1, tostring(message))
	local maxQueued = ((GameConfig.Limits or {}).MaxNotificationsQueued or 5)
	while #activeMessages > math.max(3, maxQueued) do
		table.remove(activeMessages)
	end
	render()
	task.delay(4.5, function()
		for index, queued in ipairs(activeMessages) do
			if queued == message then
				local label = labels[index]
				if label then
					TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						TextTransparency = 1,
						BackgroundTransparency = 1,
					}):Play()
				end
				table.remove(activeMessages, index)
				break
			end
		end
		render()
	end)
end

return NotificationController
