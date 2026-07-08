local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 15)
local mainUi = playerGui and playerGui:WaitForChild("MainUI", 15)
local controllers = script.Parent:WaitForChild("Controllers")

local NotificationController = require(controllers:WaitForChild("NotificationController"))
local UIController = require(controllers:WaitForChild("UIController"))
local PromptController = require(controllers:WaitForChild("PromptController"))
local SoundController = require(controllers:WaitForChild("SoundController"))
local EffectsController = require(controllers:WaitForChild("EffectsController"))
local GuidanceController = require(controllers:WaitForChild("GuidanceController"))

if not mainUi then
	warn("[FEED THE VOID] MainUI did not clone into PlayerGui; client UI controllers were not started.")
	return
end

NotificationController.Init(mainUi)
SoundController.Init(mainUi)
GuidanceController.Init(mainUi)
UIController.Init(mainUi, NotificationController, GuidanceController, SoundController)
PromptController.Init()
EffectsController.Init(mainUi, SoundController)

NotificationController.Show("FEED THE VOID Phase 12 VFX private test loaded.")
