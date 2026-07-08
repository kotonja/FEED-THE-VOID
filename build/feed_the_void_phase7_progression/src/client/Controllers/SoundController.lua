local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local SoundController = {}

local muted = false
local warned = {}

function SoundController.Init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		muted = data.Settings and data.Settings.MuteSounds == true or false
	end)
end

function SoundController.Play(soundKey)
	if muted then
		return
	end
	local id = GameConfig.SoundConfig and GameConfig.SoundConfig[soundKey]
	if (not id or id == 0) and soundKey == "PhantomCaught" then
		id = GameConfig.SoundConfig and GameConfig.SoundConfig.CollectPhantom
	end
	if (not id or id == 0) and soundKey == "VoidEventStart" then
		id = GameConfig.SoundConfig and GameConfig.SoundConfig.VoidEvent
	end
	if not id or id == 0 then
		if GameConfig.DebugMode and not warned[soundKey] then
			warned[soundKey] = true
			print("[FEED THE VOID] Sound " .. tostring(soundKey) .. " skipped; no asset id configured.")
		end
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "FTV_" .. tostring(soundKey)
	sound.SoundId = "rbxassetid://" .. tostring(id)
	sound.Volume = 0.6
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

return SoundController
