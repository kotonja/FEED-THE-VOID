local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local VoidService = {}

local hunger = 0
local announced = {}

local function requiredHunger()
	local config = VoidService.Context.Config.GameConfig
	if config.DebugFastVoid then
		return config.FastVoidHungerRequired
	end
	local activePlayers = math.max(1, #Players:GetPlayers())
	local dynamic = (tonumber(config.VoidHungerBase) or 45) + (activePlayers * (tonumber(config.VoidHungerPerPlayer) or 20))
	return math.max(30, math.floor(dynamic))
end

local function updateBillboard()
	local world = workspace:FindFirstChild("GameWorld")
	local central = world and world:FindFirstChild("CentralVoid")
	local core = central and central:FindFirstChild("VoidCore")
	local gui = core and core:FindFirstChild("VoidBillboard")
	local label = gui and gui:FindFirstChild("HungerLabel")
	local fill = gui and gui:FindFirstChild("MeterBack") and gui.MeterBack:FindFirstChild("MeterFill")
	local required = requiredHunger()
	if label then
		label.Text = "THE VOID - " .. tostring(math.floor(hunger)) .. "/" .. tostring(required)
	end
	if fill then
		fill.Size = UDim2.new(math.clamp(hunger / required, 0, 1), 0, 1, 0)
	end
end

local function pulseVoid()
	local world = workspace:FindFirstChild("GameWorld")
	local core = world and world:FindFirstChild("CentralVoid") and world.CentralVoid:FindFirstChild("VoidCore")
	if not core or not core:IsA("BasePart") then
		return
	end
	local originalSize = core.Size
	local grow = TweenService:Create(core, TweenInfo.new(0.18), { Size = originalSize * 1.08 })
	local shrink = TweenService:Create(core, TweenInfo.new(0.22), { Size = originalSize })
	grow:Play()
	grow.Completed:Once(function()
		if core.Parent then
			shrink:Play()
		end
	end)
end

local function announceMilestones(context, percent)
	local thresholds = {
		{ Key = 25, Text = "The Void is getting hungry..." },
		{ Key = 50, Text = "The Void is rumbling." },
		{ Key = 75, Text = "The Void is almost awake!" },
	}
	for _, threshold in ipairs(thresholds) do
		if percent >= threshold.Key and not announced[threshold.Key] then
			announced[threshold.Key] = true
			context.Services.EconomyService.NotifyAll(threshold.Text)
		end
	end
end

function VoidService.Init(context)
	VoidService.Context = context
	updateBillboard()
end

function VoidService.Start() end

function VoidService.GetHunger()
	return hunger
end

function VoidService.GetRequired()
	return requiredHunger()
end

function VoidService.AddHunger(player, amount, item)
	local context = VoidService.Context
	local required = requiredHunger()
	amount = math.max(0, math.floor(amount or 0))
	hunger += amount
	pulseVoid()
	if item and (item.MutationId == "Glitched" or item.MutationId == "VoidTouched") then
		context.Services.EconomyService.NotifyAll(player.Name .. " fed The Void a " .. item.DisplayName .. ". The Void is waking up...")
	elseif item and ((item.EstimatedVoidValue or amount) >= 90 or item.MutationId ~= "Normal") then
		context.Services.EconomyService.NotifyAll(player.Name .. " fed The Void a " .. item.DisplayName .. "!")
	else
		context.Services.EconomyService.Notify(player, "The Void loved that.")
	end
	if hunger >= required then
		hunger = 0
		announced = {}
		updateBillboard()
		context.Services.EconomyService.NotifyAll("The Void is full. Something strange begins.")
		context.Services.EventService.StartRandomEvent()
	else
		announceMilestones(context, (hunger / required) * 100)
		updateBillboard()
	end
	context.Services.EconomyService.SyncAll()
end

return VoidService
