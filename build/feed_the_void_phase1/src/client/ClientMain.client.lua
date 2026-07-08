local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mainUi = player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local controllers = script.Parent:WaitForChild("Controllers")

local NotificationController = require(controllers:WaitForChild("NotificationController"))
local UIController = require(controllers:WaitForChild("UIController"))
local PromptController = require(controllers:WaitForChild("PromptController"))

NotificationController.Init(mainUi)
UIController.Init(mainUi, NotificationController)
PromptController.Init()

NotificationController.Show("FEED THE VOID Phase 1 loaded.")
