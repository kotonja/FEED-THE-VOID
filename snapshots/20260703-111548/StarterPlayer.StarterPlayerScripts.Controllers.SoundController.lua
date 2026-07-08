local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local SoundController = {}

local muted = false
local buttonConnections = setmetatable({}, { __mode = "k" })

local function bindButton(button)
	if not button:IsA("GuiButton") or buttonConnections[button] then
		return
	end
	buttonConnections[button] = button.Activated:Connect(function()
		SoundController.Play("ButtonClick")
	end)
end

local function bindUiClicks(root)
	if typeof(root) ~= "Instance" then
		return
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		bindButton(descendant)
	end
	root.DescendantAdded:Connect(bindButton)
end

local effectSoundKeys = {
	Plant = "Plant",
	GrowthStage = "GrowthStage",
	GrowthReady = "GrowthReady",
	Harvest = "Harvest",
	Sell = "Sell",
	FeedVoid = "FeedVoid",
	Display = "DisplaySnack",
	VoidmiteSpawn = "VoidmiteSpawn",
	VoidmiteCleanse = "CleanseVoidmite",
	Rebirth = "Rebirth",
}

local aliases = {
	PhantomCaught = "CollectPhantom",
	VoidEventStart = "VoidEvent",
}

function SoundController.Init(uiRoot)
	bindUiClicks(uiRoot)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		muted = data.Settings and data.Settings.MuteSounds == true or false
	end)
	local playEffect = remotes:WaitForChild("PlayEffect", 10)
	if playEffect then
		playEffect.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			SoundController.Play(payload.SoundKey or effectSoundKeys[payload.Type])
		end)
	end
end

function SoundController.Play(soundKey)
	if muted or not soundKey then
		return
	end
	local soundConfig = GameConfig.SoundConfig or {}
	local id = soundConfig[soundKey]
	if (not id or id == 0) and aliases[soundKey] then
		id = soundConfig[aliases[soundKey]]
	end
	if not id or id == 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "FTV_" .. tostring(soundKey)
	sound.SoundId = "rbxassetid://" .. tostring(id)
	sound.Volume = 0.55
	sound.RollOffMaxDistance = 70
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

return SoundController
