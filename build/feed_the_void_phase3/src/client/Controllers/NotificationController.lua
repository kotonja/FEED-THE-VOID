local NotificationController = {}

local labels = {}
local activeMessages = {}

local function render()
	for index, label in ipairs(labels) do
		local message = activeMessages[index]
		label.Text = message or ""
		label.Visible = message ~= nil
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
	while #activeMessages > 3 do
		table.remove(activeMessages)
	end
	render()
	task.delay(4.5, function()
		for index, queued in ipairs(activeMessages) do
			if queued == message then
				table.remove(activeMessages, index)
				break
			end
		end
		render()
	end)
end

return NotificationController
