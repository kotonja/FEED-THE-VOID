local Players = game:GetService("Players")

local PlotService = {}

local plots = {}
local playerPlots = {}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function truncateName(name)
	name = tostring(name or "Player")
	local maxLength = PlotService.Context and PlotService.Context.Config.GameConfig.OwnerSignMaxNameLength or 14
	if #name <= maxLength then
		return name
	end
	return string.sub(name, 1, math.max(1, maxLength - 1)) .. "."
end

local function getSignPart(plot)
	local sign = plot and plot:FindFirstChild("OwnerSign")
	if not sign then
		return nil
	end
	if sign:IsA("BasePart") then
		return sign
	end
	return sign:FindFirstChildWhichIsA("BasePart", true)
end

local function getLabel(plot)
	local signPart = getSignPart(plot)
	if not signPart then
		return nil
	end

	local preferredNames = {
		"OwnerLabel",
		"OwnerText",
		"NameLabel",
		"Label",
	}
	for _, gui in ipairs(signPart:GetDescendants()) do
		if gui:IsA("SurfaceGui") or gui:IsA("BillboardGui") then
			for _, labelName in ipairs(preferredNames) do
				local label = gui:FindFirstChild(labelName, true)
				if label and label:IsA("TextLabel") then
					return label
				end
			end
			local label = gui:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				return label
			end
		end
	end

	return nil
end

local function setOwnerLabel(plot, text)
	local label = getLabel(plot)
	if label then
		label.Text = string.upper(text)
	end
end

local function sortedPlotIds()
	local ids = {}
	for plotId in pairs(plots) do
		table.insert(ids, plotId)
	end
	table.sort(ids)
	return ids
end

local function claimPlot(player, plot)
	if not plot then
		return nil
	end
	plot:SetAttribute("OwnerUserId", player.UserId)
	playerPlots[player] = plot
	setOwnerLabel(plot, truncateName(player.DisplayName) .. "'s Lab")
	local data = PlotService.Context.Services.ProfileServiceWrapper.GetData(player)
	if data then
		data.AssignedPlotId = tonumber(plot:GetAttribute("PlotId")) or 0
		PlotService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
	return plot
end

function PlotService.Init(context)
	PlotService.Context = context
	local plotsFolder = getWorld():WaitForChild("Plots")
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then
			local plotId = tonumber(plot:GetAttribute("PlotId")) or tonumber(plot.Name:match("(%d+)"))
			if plotId then
				plot:SetAttribute("PlotId", plotId)
				plots[plotId] = plot
				if plot:GetAttribute("OwnerUserId") == nil then
					plot:SetAttribute("OwnerUserId", 0)
				end
				if tonumber(plot:GetAttribute("OwnerUserId")) == 0 then
					setOwnerLabel(plot, "Empty Lab")
				end
			end
		end
	end
end

function PlotService.Start() end

function PlotService.AssignPlot(player)
	if playerPlots[player] then
		return playerPlots[player]
	end
	for _, plot in pairs(plots) do
		if tonumber(plot:GetAttribute("OwnerUserId")) == player.UserId then
			return claimPlot(player, plot)
		end
	end
	local data = PlotService.Context.Services.ProfileServiceWrapper.GetData(player)
	local preferred = data and plots[tonumber(data.AssignedPlotId)]
	if preferred and (not preferred:GetAttribute("OwnerUserId") or tonumber(preferred:GetAttribute("OwnerUserId")) == 0) then
		local plot = claimPlot(player, preferred)
		PlotService.Context.Services.EconomyService.Notify(player, "Your lab plot is ready.")
		if PlotService.Context.Services.TutorialService then
			PlotService.Context.Services.TutorialService.Advance(player, 2)
		end
		PlotService.TeleportToPlot(player)
		return plot
	end
	for _, plotId in ipairs(sortedPlotIds()) do
		local plot = plots[plotId]
		if not plot:GetAttribute("OwnerUserId") or tonumber(plot:GetAttribute("OwnerUserId")) == 0 then
			plot = claimPlot(player, plot)
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
	local plot = playerPlots[player] or PlotService.AssignPlot(player)
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
	setOwnerLabel(plot, "Empty Lab")
	local data = PlotService.Context.Services.ProfileServiceWrapper.GetData(player)
	if data then
		data.AssignedPlotId = 0
		PlotService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
	playerPlots[player] = nil
end

function PlotService.GetPlot(player)
	return playerPlots[player]
end

function PlotService.GetPlotId(player)
	local plot = PlotService.GetPlot(player)
	return plot and tonumber(plot:GetAttribute("PlotId")) or 0
end

function PlotService.GetPlotOwner(plot)
	local ownerUserId = plot and tonumber(plot:GetAttribute("OwnerUserId"))
	return ownerUserId and ownerUserId > 0 and Players:GetPlayerByUserId(ownerUserId) or nil
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

function PlotService.GetStation(player, stationName)
	local plot = PlotService.GetPlot(player)
	return plot and plot:FindFirstChild(stationName) or nil
end

function PlotService.RefreshOwnerSigns()
	for _, plot in pairs(plots) do
		local owner = PlotService.GetPlotOwner(plot)
		setOwnerLabel(plot, owner and (truncateName(owner.DisplayName) .. "'s Lab") or "Empty Lab")
	end
end

return PlotService
