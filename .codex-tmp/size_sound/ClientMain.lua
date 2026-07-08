local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mainUi = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local controllers = script.Parent:WaitForChild("Controllers")

local NotificationController = require(controllers:WaitForChild("NotificationController"))
local UIController = require(controllers:WaitForChild("UIController"))
local PromptController = require(controllers:WaitForChild("PromptController"))
local SoundController = require(controllers:WaitForChild("SoundController"))
local EffectsController = require(controllers:WaitForChild("EffectsController"))

NotificationController.Init(mainUi)
SoundController.Init(mainUi)
UIController.Init(mainUi, NotificationController)
PromptController.Init()
EffectsController.Init(mainUi, SoundController)

NotificationController.Show("FEED THE VOID Phase 6 polish loaded.")
