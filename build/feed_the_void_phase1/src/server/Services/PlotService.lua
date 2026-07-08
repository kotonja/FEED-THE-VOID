local Players = game:GetService("Players")

local PlotService = {}

local plots = {}
local playerPlots = {}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function getLabel(plot)
	local sign = plot:FindFirstChild("OwnerSign")
	if not sign then
		return nil
	end
	local gui = sign:FindFirstChild("OwnerBillboard")
	return gui and gui:FindFirstChild("OwnerLabel") or nil
end

function PlotService.Init(context)
	PlotService.Context = context
	local plotsFolder = getWorld():WaitForChild("Plots")
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then
			local plotId = tonumber(plot:GetAttribute("PlotId"))
			if plotId then
				plots[plotId] = plot
				plot:SetAttribute("OwnerUserId", 0)
				local label = getLabel(plot)
				if label then
					label.Text = "EMPTY PLOT"
				end
			end
		end
	end
end

function PlotService.Start() end

function PlotService.AssignPlot(player)
	for plotId, plot in pairs(plots) do
		if not plot:GetAttribute("OwnerUserId") or plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			playerPlots[player] = plot
			local label = getLabel(plot)
			if label then
				label.Text = player.Name .. "'s Lab"
			end
			PlotService.Context.Services.EconomyService.Notify(player, "Your lab plot is ready. Find a plate and plant Cookie Rock.")
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
	local label = getLabel(plot)
	if label then
		label.Text = "EMPTY PLOT"
	end
	playerPlots[player] = nil
end

function PlotService.GetPlot(player)
	return playerPlots[player]
end

function PlotService.GetPlotOwner(plot)
	local ownerUserId = plot and tonumber(plot:GetAttribute("OwnerUserId"))
	if not ownerUserId or ownerUserId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(ownerUserId)
end

function PlotService.FindPlotFromInstance(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("PlotId") then
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

return PlotService
