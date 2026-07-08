local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ownedPlateCount = 6
local trackedPlots = {}

local function getPlotsFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("Plots") or nil
end

local function getLockIndex(billboard)
	local lock = billboard:FindFirstAncestor("PremiumPlateLock")
	if not lock then
		return 0
	end

	local index = tonumber(lock:GetAttribute("PlateVisualIndex"))
	if index then
		return index
	end

	local visual = lock.Parent
	return visual and tonumber(tostring(visual.Name):match("^GrowPlateVisual(%d+)$")) or 0
end

local function isPremiumBillboard(instance)
	return instance:IsA("BillboardGui") and instance.Name == "PremiumPlateBillboard"
end

local function updateBillboard(plot, billboard)
	local ownerUserId = tonumber(plot:GetAttribute("OwnerUserId")) or 0
	local lockIndex = getLockIndex(billboard)
	billboard.Enabled = ownerUserId == player.UserId and lockIndex > ownedPlateCount
end

local function refreshPlot(plot)
	if not plot or not plot.Parent then
		return
	end

	for _, descendant in ipairs(plot:GetDescendants()) do
		if isPremiumBillboard(descendant) then
			updateBillboard(plot, descendant)
		end
	end
end

local function refreshAll()
	local plots = getPlotsFolder()
	if not plots then
		return
	end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") then
			refreshPlot(plot)
		end
	end
end

local function untrackPlot(plot)
	local connections = trackedPlots[plot]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	trackedPlots[plot] = nil
end

local function trackPlot(plot)
	if not plot:IsA("Model") or trackedPlots[plot] then
		return
	end

	local connections = {}
	trackedPlots[plot] = connections

	table.insert(connections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refreshPlot(plot)
	end))

	table.insert(connections, plot.DescendantAdded:Connect(function(descendant)
		if isPremiumBillboard(descendant) or descendant.Name == "PremiumPlateLock" or descendant.Name == "PremiumLockAnchor" then
			task.defer(refreshPlot, plot)
		end
	end))

	table.insert(connections, plot.AncestryChanged:Connect(function(_, parent)
		if not parent then
			untrackPlot(plot)
		end
	end))

	refreshPlot(plot)
end

local function bindPlayerData()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	local sync = remotes and remotes:WaitForChild("SyncPlayerData", 10)
	if not sync then
		return
	end

	sync.OnClientEvent:Connect(function(data)
		local upgrades = data and data.Upgrades
		ownedPlateCount = tonumber(upgrades and upgrades.Plates) or ownedPlateCount
		refreshAll()
	end)
end

local function bindPlots()
	local world = workspace:WaitForChild("GameWorld", 10)
	local plots = world and world:WaitForChild("Plots", 10)
	if not plots then
		return
	end

	for _, plot in ipairs(plots:GetChildren()) do
		trackPlot(plot)
	end

	plots.ChildAdded:Connect(trackPlot)
	refreshAll()

	task.spawn(function()
		while plots.Parent do
			refreshAll()
			task.wait(2)
		end
	end)
end

task.spawn(bindPlayerData)
task.spawn(bindPlots)
