local NotificationController = {}

local label

function NotificationController.Init(mainUi)
	local notifications = mainUi:WaitForChild("Notifications")
	label = notifications:WaitForChild("NotificationText")
end

function NotificationController.Show(message)
	if not label then
		return
	end
	label.Text = tostring(message)
	label.Visible = true
	task.delay(3.5, function()
		if label and label.Text == tostring(message) then
			label.Text = ""
		end
	end)
end

return NotificationController
