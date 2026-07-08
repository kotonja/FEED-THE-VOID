local VoidService = {}

local hunger = 0

local function updateBillboard(context)
	local world = workspace:FindFirstChild("GameWorld")
	local central = world and world:FindFirstChild("CentralVoid")
	local core = central and central:FindFirstChild("VoidCore")
	local gui = core and core:FindFirstChild("VoidBillboard")
	local label = gui and gui:FindFirstChild("HungerLabel")
	local fill = gui and gui:FindFirstChild("MeterBack") and gui.MeterBack:FindFirstChild("MeterFill")
	local required = context.Config.GameConfig.VoidHungerRequired
	if label then
		label.Text = "THE VOID - " .. tostring(math.floor(hunger)) .. "/" .. tostring(required)
	end
	if fill then
		fill.Size = UDim2.new(math.clamp(hunger / required, 0, 1), 0, 1, 0)
	end
end

function VoidService.Init(context)
	VoidService.Context = context
	updateBillboard(context)
end

function VoidService.Start() end

function VoidService.GetHunger()
	return hunger
end

function VoidService.AddHunger(player, amount)
	local context = VoidService.Context
	local required = context.Config.GameConfig.VoidHungerRequired
	hunger += math.max(0, amount)
	context.Services.EconomyService.NotifyAll(player.Name .. " fed the Void. It rumbles happily.")
	if hunger >= required then
		hunger = 0
		updateBillboard(context)
		context.Services.EconomyService.NotifyAll("THE VOID IS FULL. Something strange begins.")
		context.Services.EventService.StartRandomEvent()
	else
		updateBillboard(context)
	end
	context.Services.EconomyService.SyncAll()
end

return VoidService
