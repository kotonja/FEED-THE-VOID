local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local VoidService = {}

local hunger = 0
local announced = {}
local charging = false
local chargeEndsAt = 0

local function centralVoidTarget()
	local world = workspace:FindFirstChild("GameWorld")
	local central = world and world:FindFirstChild("CentralVoid")
	return central and (central:FindFirstChild("VoidCore") or central:FindFirstChild("FeedStation") or central)
end

local function requiredHunger()
	local config = VoidService.Context.Config.GameConfig
	local override = VoidService.Context.RuntimeOverrides and tonumber(VoidService.Context.RuntimeOverrides.HungerRequired)
	if override then
		return math.max(1, math.floor(override))
	end
	if config.DebugFastVoid then
		return config.FastVoidHungerRequired
	end
	local activePlayers = math.max(1, #Players:GetPlayers())
	local dynamic = (tonumber(config.VoidHungerBase) or 45) + (activePlayers * (tonumber(config.VoidHungerPerPlayer) or 20))
	if VoidService.Context and VoidService.Context.Services.EventService then
		dynamic *= VoidService.Context.Services.EventService.GetPityMultiplier()
	end
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
		{ Key = 25, Text = "The Void is getting hungry...", VFX = "Void.Hunger25" },
		{ Key = 50, Text = "The Void is rumbling.", VFX = "Void.Hunger50" },
		{ Key = 75, Text = "The Void is almost awake!", VFX = "Void.Hunger75" },
	}
	for _, threshold in ipairs(thresholds) do
		if percent >= threshold.Key and not announced[threshold.Key] then
			announced[threshold.Key] = true
			context.Services.EconomyService.NotifyAll(threshold.Text)
			if context.Services.AudioService then
				context.Services.AudioService.PlayForAll("Void.Rumble", "World", centralVoidTarget(), { MinInterval = 0.6 })
			end
			if context.Services.VFXService then
				context.Services.VFXService.PlayForAll(threshold.VFX, {
					Mode = "World",
					Target = centralVoidTarget(),
					Text = threshold.Text,
					MinInterval = 0.6,
				})
			end
		end
	end
end

local function startEventCharge(context, player, item)
	if charging then
		return
	end
	charging = true
	local config = context.Config.GameConfig
	local duration = tonumber(config.VoidEventChargeDuration) or 4
	if config.DebugFastVoid then
		duration = math.min(duration, 1.5)
	end
	chargeEndsAt = os.time() + math.max(1, math.ceil(duration))
	local target = centralVoidTarget()
	local queuedEventName = context.Services.EventService.GetRandomEventName and context.Services.EventService.GetRandomEventName() or nil
	if context.Services.EventService.SetChargeState then
		context.Services.EventService.SetChargeState(true, queuedEventName, chargeEndsAt)
	end
	context.Services.EconomyService.NotifyAll("THE VOID IS WAKING UP...")
	if context.Services.AudioService then
		context.Services.AudioService.PlayForAll("Void.Rumble", "World", target, { NoThrottle = true })
	end
	if context.Services.VFXService then
		context.Services.VFXService.PlayForAll("Void.Charging", {
			Mode = "World",
			Target = target,
			Text = "THE VOID IS WAKING UP...",
			Player = player,
			ItemName = item and item.DisplayName or nil,
			NoThrottle = true,
		})
	end
	context.Services.EconomyService.SyncAll()
	task.delay(duration, function()
		if VoidService.Context ~= context or not charging then
			return
		end
		hunger = 0
		announced = {}
		charging = false
		chargeEndsAt = 0
		if context.Services.EventService.SetChargeState then
			context.Services.EventService.SetChargeState(false, nil, 0)
		end
		updateBillboard()
		if queuedEventName then
			context.Services.EventService.StartEvent(queuedEventName)
		else
			context.Services.EventService.StartRandomEvent()
		end
		context.Services.EconomyService.SyncAll()
	end)
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

function VoidService.IsCharging()
	return charging == true
end

function VoidService.GetChargeEndsAt()
	return chargeEndsAt
end

function VoidService.PlayReaction(percent, player)
	local context = VoidService.Context
	local thresholdPercent = math.clamp(tonumber(percent) or 50, 0, 100)
	local text = "The Void is rumbling."
	local vfxKey = "Void.Hunger50"
	if thresholdPercent >= 75 then
		text = "The Void is almost awake!"
		vfxKey = "Void.Hunger75"
	elseif thresholdPercent >= 25 then
		text = "The Void is getting hungry..."
		vfxKey = "Void.Hunger25"
	end
	context.Services.EconomyService.NotifyAll(text)
	if context.Services.VFXService then
		context.Services.VFXService.PlayForAll(vfxKey, {
			Mode = "World",
			Target = centralVoidTarget(),
			Text = text,
			NoThrottle = true,
		})
	end
	if player then
		context.Services.EconomyService.Notify(player, "Debug Void reaction at " .. tostring(math.floor(thresholdPercent)) .. "%.")
	end
end

function VoidService.AddHunger(player, amount, item)
	local context = VoidService.Context
	if charging then
		context.Services.EconomyService.Notify(player, "The Void is already charging.")
		return
	end
	local required = requiredHunger()
	amount = math.max(0, math.floor(amount or 0))
	hunger += amount
	context.Services.EventService.MarkParticipation(player, "FeedVoid")
	pulseVoid()
	if item and (item.MutationId == "Glitched" or item.MutationId == "VoidTouched") then
		context.Services.EconomyService.NotifyAll(player.Name .. " fed The Void a " .. item.DisplayName .. ". The Void is waking up...")
	elseif item and ((item.EstimatedVoidValue or amount) >= 90 or item.MutationId ~= "Normal") then
		context.Services.EconomyService.NotifyAll(player.Name .. " fed The Void a " .. item.DisplayName .. "!")
	else
		context.Services.EconomyService.Notify(player, "The Void loved that.")
	end
	if hunger >= required then
		hunger = required
		announceMilestones(context, 99)
		updateBillboard()
		startEventCharge(context, player, item)
	else
		announceMilestones(context, (hunger / required) * 100)
		updateBillboard()
	end
	context.Services.EconomyService.SyncAll()
end

return VoidService
