local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mainUi = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local controllers = script.Parent:WaitForChild("Controllers")

local NotificationController = require(controllers:WaitForChild("NotificationController"))
local UIController = require(controllers:WaitForChild("UIController"))
local PromptController = require(controllers:WaitForChild("PromptController"))
local VFXController = require(controllers:WaitForChild("VFXController"))

NotificationController.Init(mainUi)
UIController.Init(mainUi, NotificationController)
PromptController.Init()
VFXController.Init(mainUi)

NotificationController.Show("FEED THE VOID Phase 3 loaded.")
