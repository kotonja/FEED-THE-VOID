local Players = game:GetService("Players")

local MapService = {}

local requiredFolders = {
	"CentralArena",
	"PlotIslands",
	"Bridges",
	"Stations",
	"Decorations",
	"EventObjects",
	"SpawnPoints",
}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder:SetAttribute("GeneratedByMapService", true)
		folder.Parent = parent
	end
	return folder
end

local function ownerLabel(plot)
	local sign = plot and plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("OwnerBillboard")
	return gui and gui:FindFirstChild("OwnerLabel") or nil
end

function MapService.Init(context)
	MapService.Context = context
end

function MapService.VerifyWorld()
	local world = getWorld()
	for _, folderName in ipairs(requiredFolders) do
		ensureFolder(world, folderName)
	end
	local plots = world:FindFirstChild("Plots")
	if not plots then
		warn("[FEED THE VOID] GameWorld.Plots is missing; the blueprint should place real plot islands in Studio.")
		return
	end
	for index = 1, 8 do
		local plot = plots:FindFirstChild("Plot" .. tostring(index))
		if plot then
			plot:SetAttribute("PlotId", index)
			if plot:GetAttribute("OwnerUserId") == nil then
				plot:SetAttribute("OwnerUserId", 0)
			end
			local label = ownerLabel(plot)
			if label and tonumber(plot:GetAttribute("OwnerUserId")) == 0 then
				label.Text = "Empty Lab"
			end
		end
	end
end

function MapService.GetCentralSpawnCFrame()
	local world = workspace:FindFirstChild("GameWorld")
	local spawn = world and world:FindFirstChild("SpawnPoints") and world.SpawnPoints:FindFirstChild("CentralSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 7, -36)
end

function MapService.TeleportPlayerSafe(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local plot = MapService.Context.Services.PlotService.GetPlot(player)
	local spawnPart = plot and plot:FindFirstChild("PlotSpawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		root.CFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
	else
		root.CFrame = MapService.GetCentralSpawnCFrame()
	end
end

function MapService.Start()
	MapService.VerifyWorld()
	task.spawn(function()
		while true do
			task.wait(1)
			local resetY = MapService.Context.Config.GameConfig.FallResetY or -45
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < resetY then
					MapService.TeleportPlayerSafe(player)
					MapService.Context.Services.EconomyService.Notify(player, "Back to solid ground.")
				end
			end
		end
	end)
end

return MapService
