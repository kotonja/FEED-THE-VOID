local Players = game:GetService("Players")

local PlotService = {}

local plots = {}
local playerPlots = {}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function getLabel(plot)
	local sign = plot and plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("OwnerBillboard")
	return gui and gui:FindFirstChild("OwnerLabel") or nil
end

local function inferPlotId(plot)
	local nameId = tonumber(tostring(plot.Name):match("^Plot(%d+)$"))
	if nameId then
		return nameId
	end
	return tonumber(plot:GetAttribute("PlotId"))
end

local function setEmptyLabel(plot)
	local label = getLabel(plot)
	if label and tonumber(plot:GetAttribute("OwnerUserId")) == 0 then
		label.Text = "Empty Lab"
	end
end

local function rebuildPlotCache(plotsFolder)
	plots = {}
	local staged = {}
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then
			local plotId = inferPlotId(plot)
			if plotId then
				table.insert(staged, {
					Id = plotId,
					Plot = plot,
				})
			end
		end
	end
	table.sort(staged, function(a, b)
		return a.Id < b.Id
	end)
	for _, entry in ipairs(staged) do
		if not plots[entry.Id] then
			entry.Plot:SetAttribute("PlotId", entry.Id)
			entry.Plot:SetAttribute("OwnerUserId", 0)
			plots[entry.Id] = entry.Plot
			setEmptyLabel(entry.Plot)
		else
			warn("[FEED THE VOID] Duplicate plot id " .. tostring(entry.Id) .. " on " .. entry.Plot:GetFullName())
		end
	end
end

local function orderedPlots()
	local ids = {}
	for plotId in pairs(plots) do
		table.insert(ids, plotId)
	end
	table.sort(ids)
	local result = {}
	for _, plotId in ipairs(ids) do
		table.insert(result, plots[plotId])
	end
	return result
end

function PlotService.Init(context)
	PlotService.Context = context
	local plotsFolder = getWorld():WaitForChild("Plots")
	rebuildPlotCache(plotsFolder)
end

function PlotService.Start() end

function PlotService.AssignPlot(player)
	if playerPlots[player] and playerPlots[player].Parent then
		return playerPlots[player]
	end
	for _, plot in ipairs(orderedPlots()) do
		if not plot:GetAttribute("OwnerUserId") or tonumber(plot:GetAttribute("OwnerUserId")) == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			playerPlots[player] = plot
			local label = getLabel(plot)
			if label then
				label.Text = player.DisplayName .. "'s Lab"
			end
			PlotService.Context.Services.EconomyService.Notify(player, "Your lab plot is ready.")
			if PlotService.Context.Services.TutorialService then
				PlotService.Context.Services.TutorialService.Advance(player, 2)
			end
			PlotService.TeleportToPlot(player)
			return plot
		end
	end
	PlotService.Context.Services.EconomyService.Notify(player, "No open plots yet. Try again in a moment.")
	return nil
end

function PlotService.TeleportToPlot(player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	local spawnPart = plot:FindFirstChild("PlotSpawn")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if spawnPart and root then
		root.CFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
	end
end

function PlotService.ReleasePlot(player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	plot:SetAttribute("OwnerUserId", 0)
	setEmptyLabel(plot)
	playerPlots[player] = nil
end

function PlotService.GetPlot(player)
	return playerPlots[player]
end

function PlotService.GetPlotOwner(plot)
	local ownerUserId = plot and tonumber(plot:GetAttribute("OwnerUserId"))
	return ownerUserId and ownerUserId > 0 and Players:GetPlayerByUserId(ownerUserId) or nil
end

function PlotService.FindPlotFromInstance(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and inferPlotId(current) then
			current:SetAttribute("PlotId", inferPlotId(current))
			return current
		end
		current = current.Parent
	end
	return nil
end

function PlotService.PlayerOwnsPlot(player, plot)
	return plot and tonumber(plot:GetAttribute("OwnerUserId")) == player.UserId
end

function PlotService.GetPlots()
	return plots
end

function PlotService.GetStation(player, stationName)
	local plot = PlotService.GetPlot(player)
	return plot and plot:FindFirstChild(stationName) or nil
end

return PlotService
