local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FormatNumbers = require(Shared:WaitForChild("FormatNumbers"))
local SnackConfig = require(Shared:WaitForChild("SnackConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

local UIController = {}

local mainUi
local notificationController
local guidanceController
local soundController
local currentData = nil
local selectedItemId = nil
local selectedSeedId = "CookieRock"
local itemButtons = {}
local seedButtons = {}
local upgradeButtons = {}
local milestoneButtons = {}
local majorPanels = { "InventoryPanel", "SeedShopPanel", "UpgradePanel", "CollectionPanel", "RebirthPanel", "PlaytimeRewardsPanel", "DailyRewardPanel", "SettingsPanel", "FeedbackPanel" }
local player = Players.LocalPlayer
local remotesBound = false
local uiReady = false
local currentMajorPanel = nil
local selectedFeedbackCategory = "Bug"
local sortModes = { "Newest", "Highest Value", "Rarity", "Mutation", "Snack Type" }
local filterModes = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret", "Locked only" }
local sortModeIndex = 1
local filterModeIndex = 1
local pendingConfirm = nil
local rebirthConfirmArmed = false
local warnedMissing = {}
local feedbackCategories = { "Bug", "Confusing", "TooSlow", "TooHard", "UIIssue", "MobileIssue", "SoundIssue", "VFXIssue", "Fun", "Other" }
local panelMotion = {}
local buttonMotionBound = {}
local previousStats = {}
local lastEventName = nil

local function warnOnce(key, message)
	if warnedMissing[key] then
		return
	end
	warnedMissing[key] = true
	warn("[FEED THE VOID][UI] " .. tostring(message))
end

local function playUiSound(key, options)
	if soundController and soundController.PlayUI then
		soundController.PlayUI(key, options)
	end
end

local function messageLooksLikeError(message)
	message = string.lower(tostring(message or ""))
	for _, token in ipairs({
		"not enough",
		"locked",
		"invalid",
		"full",
		"disabled",
		"move closer",
		"stand near",
		"select",
		"loading",
		"not ready",
		"requires",
		"missing",
		"try again",
		"unavailable",
	}) do
		if string.find(message, token, 1, true) then
			return true
		end
	end
	return false
end

local function formatSeconds(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	if minutes >= 60 then
		local hours = math.floor(minutes / 60)
		return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m"
	end
	return string.format("%d:%02d", minutes, secs)
end

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function distanceTo(instance)
	local root = getRoot()
	if not root or typeof(instance) ~= "Instance" then
		return math.huge
	end
	local position
	if instance:IsA("Model") then
		position = instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		position = instance.Position
	end
	return position and (root.Position - position).Magnitude or math.huge
end

local function nearestChild(folder, predicate, maxDistance)
	local best = nil
	local bestDistance = maxDistance or math.huge
	if not folder then
		return nil
	end
	for _, child in ipairs(folder:GetChildren()) do
		if not predicate or predicate(child) then
			local dist = distanceTo(child)
			if dist < bestDistance then
				best = child
				bestDistance = dist
			end
		end
	end
	return best
end

local function scanPlotsForStation(stationName, maxDistance)
	local world = workspace:FindFirstChild("GameWorld")
	local plots = world and world:FindFirstChild("Plots")
	local best = nil
	local bestDistance = maxDistance or math.huge
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local station = plot:FindFirstChild(stationName)
		local dist = station and distanceTo(station) or math.huge
		if dist < bestDistance then
			best = station
			bestDistance = dist
		end
	end
	return best
end

local function getNearestAction()
	local world = workspace:FindFirstChild("GameWorld")
	if not world then
		return { Label = "ACTION", Kind = "None" }
	end
	local voidmite = nearestChild(world:FindFirstChild("ActiveVoidmites"), nil, 16)
	if voidmite then
		return { Label = "CLEANSE", Kind = "Cleanse", Target = voidmite }
	end
	local plots = world:FindFirstChild("Plots")
	local bestPlate = nil
	local bestPlateDistance = 17
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local plates = plot:FindFirstChild("Plates")
			if plates then
				for _, plate in ipairs(plates:GetChildren()) do
					if plate:IsA("BasePart") then
						local dist = distanceTo(plate)
						if dist < bestPlateDistance then
							bestPlate = plate
							bestPlateDistance = dist
						end
					end
				end
			end
		end
	end
	if bestPlate and bestPlate:GetAttribute("Occupied") and tonumber(bestPlate:GetAttribute("GrowthStage")) == 3 then
		return { Label = "HARVEST", Kind = "Harvest", Target = bestPlate }
	end
	local central = world:FindFirstChild("CentralVoid")
	local feedStation = central and central:FindFirstChild("FeedStation")
	if selectedItemId and feedStation and distanceTo(feedStation) <= 30 then
		return { Label = "FEED", Kind = "Feed" }
	end
	local sellStation = selectedItemId and scanPlotsForStation("SellStation", 22)
	if sellStation then
		return { Label = "SELL", Kind = "Sell" }
	end
	local displayShelf = selectedItemId and scanPlotsForStation("DisplayShelf", 22)
	if displayShelf then
		return { Label = "DISPLAY", Kind = "Display" }
	end
	local shopStation = scanPlotsForStation("SeedShopStation", 18)
	if shopStation then
		return { Label = "SEEDS", Kind = "Shop" }
	end
	local upgradeStation = scanPlotsForStation("UpgradeStation", 18)
	if upgradeStation then
		return { Label = "UPGRADES", Kind = "Upgrade" }
	end
	local rebirthStation = scanPlotsForStation("RebirthStation", 18)
	if rebirthStation then
		return { Label = "REBIRTH", Kind = "Rebirth" }
	end
	if bestPlate and not bestPlate:GetAttribute("Occupied") then
		return { Label = "PLANT", Kind = "Plant", Target = bestPlate }
	end
	return { Label = selectedItemId and "FEED" or "PLANT", Kind = selectedItemId and "Feed" or "Plant" }
end

local function updateMobileActionButton(button)
	local action = getNearestAction()
	button.Text = action.Label or "ACTION"
	button:SetAttribute("ActionKind", action.Kind or "None")
end

local function seedCount(seedId)
	return currentData and currentData.Seeds and (currentData.Seeds[seedId] or 0) or 0
end

local function featureEnabled(name)
	local serverFlags = currentData and currentData.FeatureFlags or nil
	if type(serverFlags) == "table" and serverFlags[name] ~= nil then
		return serverFlags[name] ~= false
	end
	return FeatureFlags[name] ~= false
end

local function getDeviceType()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

local function applyPrivateTestLayout()
	if not mainUi then
		return
	end
	local camera = workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 1280
	local compact = UserInputService.TouchEnabled or width < 900
	local nextGoal = mainUi:FindFirstChild("NextGoalPanel")
	if nextGoal then
		nextGoal.Size = compact and UDim2.new(0.86, 0, 0, 42) or UDim2.new(0, 370, 0, 44)
		nextGoal.Position = compact and UDim2.new(0.07, 0, 1, -116) or UDim2.new(0.5, -185, 1, -130)
		local label = nextGoal:FindFirstChild("NextGoalText")
		if label then
			label.TextScaled = false
			label.TextSize = compact and 13 or 15
		end
	end
	local objectives = mainUi:FindFirstChild("ObjectivesPanel")
	if objectives then
		objectives.Size = compact and UDim2.new(0.56, 0, 0, 82) or UDim2.new(0, 300, 0, 92)
		objectives.Position = compact and UDim2.new(0, 10, 0, 166) or UDim2.new(0, 12, 0, 160)
		for index = 1, 3 do
			local label = objectives:FindFirstChild("Objective" .. tostring(index))
			if label then
				label.TextScaled = false
				label.TextSize = compact and 12 or 13
			end
		end
	end
	local eventBanner = mainUi:FindFirstChild("EventBanner")
	if eventBanner then
		eventBanner.Size = compact and UDim2.new(0.7, 0, 0, 34) or UDim2.new(0, 430, 0, 36)
		eventBanner.Position = compact and UDim2.new(0.15, 0, 0, 68) or UDim2.new(0.5, -215, 0, 76)
		local label = eventBanner:FindFirstChild("EventText")
		if label then
			label.TextScaled = false
			label.TextSize = compact and 13 or 15
		end
	end
	local nav = mainUi:FindFirstChild("BottomNav")
	if nav then
		nav.Size = compact and UDim2.new(0.96, 0, 0, 50) or UDim2.new(0, 530, 0, 54)
		nav.Position = compact and UDim2.new(0.02, 0, 1, -58) or UDim2.new(0.5, -265, 1, -66)
	end
	local feedbackButton = mainUi:FindFirstChild("FeedbackButton")
	if feedbackButton then
		feedbackButton.Size = compact and UDim2.new(0, 92, 0, 30) or UDim2.new(0, 108, 0, 32)
		feedbackButton.Position = compact and UDim2.new(1, -104, 0, 108) or UDim2.new(1, -124, 1, -176)
		feedbackButton.TextScaled = false
		feedbackButton.TextSize = compact and 12 or 13
	end
	local watermark = mainUi:FindFirstChild("PrivateTestWatermark")
	if watermark then
		watermark.Size = compact and UDim2.new(0, 188, 0, 20) or UDim2.new(0, 230, 0, 22)
		watermark.Position = UDim2.new(0, 10, 0, 10)
		watermark.TextScaled = false
		watermark.TextSize = compact and 10 or 12
	end
end

local function setLoadingVisible(visible, text)
	local panel = mainUi and mainUi:FindFirstChild("LoadingPanel")
	if not panel then
		return
	end
	panel.Visible = visible == true
	local label = panel:FindFirstChild("StatusLabel") or panel:FindFirstChild("LoadingText")
	if label and text then
		label.Text = text
	end
end

local function setUiReady(ready)
	uiReady = ready == true
	setLoadingVisible(not uiReady, uiReady and nil or "Loading your lab...")
	for _, name in ipairs({ "TopStats", "BottomNav", "QuickActions", "NextGoalPanel", "ObjectivesPanel" }) do
		local object = mainUi and mainUi:FindFirstChild(name)
		if object then
			object.Visible = uiReady
		end
	end
	local watermark = mainUi and mainUi:FindFirstChild("PrivateTestWatermark")
	if watermark then
		watermark.Visible = uiReady and GameConfig.LaunchMode ~= "Production" and (GameConfig.PrivateTest or {}).ShowDebugWatermark == true
	end
	local feedbackButton = mainUi and mainUi:FindFirstChild("FeedbackButton")
	if feedbackButton then
		feedbackButton.Visible = false
	end
	local tutorial = mainUi and mainUi:FindFirstChild("TutorialPanel")
	if tutorial and not uiReady then
		tutorial.Visible = false
	end
	local eventBanner = mainUi and mainUi:FindFirstChild("EventBanner")
	if eventBanner and not uiReady then
		eventBanner.Visible = false
	end
end

local function panelInfo(panel)
	local info = panelMotion[panel]
	if not info then
		info = {
			Position = panel.Position,
			BackgroundTransparency = panel.BackgroundTransparency,
			Tween = nil,
		}
		panelMotion[panel] = info
	end
	return info
end

local function animatePanel(panel, open)
	if not panel then
		return
	end
	local info = panelInfo(panel)
	if info.Tween then
		info.Tween:Cancel()
	end
	local duration = open and 0.18 or 0.13
	local closedPosition = info.Position + UDim2.new(0, 0, 0, 14)
	if open then
		panel.Visible = true
		panel.Position = closedPosition
		panel.BackgroundTransparency = math.min(1, info.BackgroundTransparency + 0.35)
		info.Tween = TweenService:Create(panel, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = info.Position,
			BackgroundTransparency = info.BackgroundTransparency,
		})
		info.Tween:Play()
	else
		info.Tween = TweenService:Create(panel, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = closedPosition,
			BackgroundTransparency = math.min(1, info.BackgroundTransparency + 0.35),
		})
		info.Tween:Play()
		info.Tween.Completed:Once(function()
			if currentMajorPanel ~= panel.Name and panel.Parent then
				panel.Visible = false
				panel.Position = info.Position
				panel.BackgroundTransparency = info.BackgroundTransparency
			end
		end)
	end
end

local function pulseGuiObject(object, strength)
	if not object or not object.Parent then
		return
	end
	local original = object.Size
	local grow = TweenService:Create(object, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(original.X.Scale, math.floor(original.X.Offset * (strength or 1.03)), original.Y.Scale, math.floor(original.Y.Offset * (strength or 1.03))),
	})
	local shrink = TweenService:Create(object, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = original,
	})
	grow:Play()
	grow.Completed:Once(function()
		if object.Parent then
			shrink:Play()
		end
	end)
end

local function bindButtonPulse(root)
	if not root then
		return
	end
	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA("TextButton") and not buttonMotionBound[object] then
			buttonMotionBound[object] = true
			object.Activated:Connect(function()
				pulseGuiObject(object, 1.025)
			end)
		end
	end
	root.DescendantAdded:Connect(function(object)
		if object:IsA("TextButton") and not buttonMotionBound[object] then
			buttonMotionBound[object] = true
			object.Activated:Connect(function()
				pulseGuiObject(object, 1.025)
			end)
		end
	end)
end

local function pulseOnIncrease(object, key, value)
	value = tonumber(value) or 0
	local previous = previousStats[key]
	if previous ~= nil and value > previous then
		pulseGuiObject(object, 1.025)
	end
	previousStats[key] = value
end

local function showPanel(panelName)
	if panelName and not uiReady then
		setLoadingVisible(true, "Loading your lab...")
		playUiSound("UI.Error")
		return
	end
	local previousPanel = currentMajorPanel
	currentMajorPanel = panelName
	for _, name in ipairs(majorPanels) do
		local panel = mainUi:FindFirstChild(name)
		if panel then
			if name == panelName then
				animatePanel(panel, true)
			elseif panel.Visible then
				animatePanel(panel, false)
			else
				panel.Visible = false
			end
		end
	end
	if previousPanel ~= panelName then
		if panelName then
			playUiSound("UI.OpenPanel", { MinInterval = 0.12 })
		elseif previousPanel then
			playUiSound("UI.ClosePanel", { MinInterval = 0.12 })
		end
	end
end

local function selectItem(item)
	selectedItemId = item and item.UniqueId or nil
	local detail = mainUi.InventoryPanel:WaitForChild("SelectedDetail")
	if item then
		local lockedText = item.Locked and " | LOCKED" or ""
		detail.Text = item.DisplayName .. lockedText .. "\n" .. tostring(item.Rarity or "Common") .. " | Sell: " .. tostring(item.EstimatedSellValue or 0) .. "  Void: " .. tostring(item.EstimatedVoidValue or 0)
	else
		detail.Text = "Harvest snacks to fill your inventory."
	end
	local lockButton = mainUi.InventoryPanel:FindFirstChild("LockButton")
	if lockButton then
		lockButton.Text = item and (item.Locked and "UNLOCK" or "LOCK") or "LOCK"
	end
	for _, buttonName in ipairs({ "SellButton", "FeedButton", "DisplayButton" }) do
		local button = mainUi.InventoryPanel:FindFirstChild(buttonName)
		if button and item then
			button.AutoButtonColor = item.Locked ~= true
			button.BackgroundTransparency = item.Locked and 0.35 or 0
		end
	end
end

local function selectedItem()
	if not currentData or not selectedItemId then
		return nil
	end
	for _, item in ipairs(currentData.Inventory or {}) do
		if item.UniqueId == selectedItemId then
			return item
		end
	end
	return nil
end

local function passesInventoryFilter(item)
	local mode = filterModes[filterModeIndex]
	if mode == "All" then
		return true
	end
	if mode == "Locked only" then
		return item.Locked == true
	end
	return item.Rarity == mode
end

local function inventoryView(inventory)
	local view = {}
	for _, item in ipairs(inventory or {}) do
		if passesInventoryFilter(item) then
			table.insert(view, item)
		end
	end
	local mode = sortModes[sortModeIndex]
	table.sort(view, function(a, b)
		if mode == "Highest Value" then
			return (a.EstimatedSellValue or 0) > (b.EstimatedSellValue or 0)
		elseif mode == "Rarity" then
			return (a.RaritySortOrder or RarityConfig.GetSortOrder(a.Rarity)) > (b.RaritySortOrder or RarityConfig.GetSortOrder(b.Rarity))
		elseif mode == "Mutation" then
			return tostring(a.MutationName or a.MutationId or "") < tostring(b.MutationName or b.MutationId or "")
		elseif mode == "Snack Type" then
			return tostring(a.SnackName or a.SnackId or "") < tostring(b.SnackName or b.SnackId or "")
		end
		return (a.CreatedAt or 0) > (b.CreatedAt or 0)
	end)
	return view
end

local function isValuable(item)
	if not item then
		return false
	end
	if (item.EstimatedSellValue or 0) >= (GameConfig.ValuableItemConfirmValue or 5000) then
		return true
	end
	if item.MutationId == "Rainbow" or item.MutationId == "VoidTouched" or item.MutationId == "Glitched" then
		return true
	end
	return RarityConfig.IsAtLeast(item.Rarity or "Common", GameConfig.ValuableItemConfirmRarity or "Epic")
end

local function hideConfirm()
	pendingConfirm = nil
	local panel = mainUi.InventoryPanel:FindFirstChild("ConfirmPanel")
	if panel then
		panel.Visible = false
	end
end

local function fireItemAction(actionName, itemId)
	if actionName == "Sell" then
		Remotes.RequestSellSnack:FireServer(itemId)
	elseif actionName == "Feed" then
		Remotes.RequestFeedVoid:FireServer(itemId)
	elseif actionName == "Display" then
		Remotes.RequestDisplaySnack:FireServer(itemId)
	end
end

local function requestItemAction(actionName)
	local item = selectedItem()
	if not item then
		if notificationController then
			notificationController.Show("Select a snack first.")
		end
		playUiSound("UI.Error")
		return
	end
	if item.Locked then
		if notificationController then
			notificationController.Show("Unlock this item before using it.")
		end
		playUiSound("UI.Error")
		return
	end
	if (actionName == "Sell" or actionName == "Feed") and isValuable(item) then
		local panel = mainUi.InventoryPanel:FindFirstChild("ConfirmPanel")
		if panel then
			pendingConfirm = { Action = actionName, ItemId = item.UniqueId }
			panel.Visible = true
			local label = panel:FindFirstChild("ConfirmText")
			if label then
				label.Text = "Are you sure you want to " .. string.lower(actionName) .. " " .. tostring(item.DisplayName) .. "?"
			end
			return
		end
	end
	fireItemAction(actionName, item.UniqueId)
end

local function updateInventory(data)
	local panel = mainUi:WaitForChild("InventoryPanel")
	local inventory = data.Inventory or {}
	panel.InventoryList.Text = "Inventory: " .. tostring(#inventory) .. " snacks"
	panel.DisplayedLabel.Text = "Displayed: " .. tostring(#(data.DisplayedSnacks or {}))
	local seedParts = {}
	for _, seedId in ipairs(SnackConfig.Order) do
		if seedCount(seedId) > 0 then
			table.insert(seedParts, (SnackConfig[seedId].DisplayName or seedId) .. ": " .. tostring(seedCount(seedId)))
		end
	end
	panel.SeedsLabel.Text = #seedParts > 0 and ("Seeds: " .. table.concat(seedParts, "  ")) or "You have no seeds. Visit the Seed Shop."
	local sortButton = panel:FindFirstChild("SortButton")
	if sortButton then
		sortButton.Text = "SORT: " .. string.upper(sortModes[sortModeIndex])
	end
	local filterButton = panel:FindFirstChild("FilterButton")
	if filterButton then
		filterButton.Text = "FILTER: " .. string.upper(filterModes[filterModeIndex])
	end
	local view = inventoryView(inventory)
	for index, button in ipairs(itemButtons) do
		local item = view[index]
		button.Visible = item ~= nil
		if item then
			local lockPrefix = item.Locked and "[L] " or ""
			button.Text = lockPrefix .. item.DisplayName .. "\n" .. tostring(item.Rarity or "Common") .. " | Sell " .. tostring(item.EstimatedSellValue or 0)
			button:SetAttribute("UniqueId", item.UniqueId)
			button.BackgroundTransparency = item.Locked and 0.18 or 0
		else
			button.Text = ""
			button:SetAttribute("UniqueId", "")
		end
	end
	if selectedItemId then
		local stillSelected = nil
		for _, item in ipairs(inventory) do
			if item.UniqueId == selectedItemId then
				stillSelected = item
				break
			end
		end
		selectItem(stillSelected or view[1])
	else
		selectItem(view[1])
	end
end

local function updateShop(data)
	local stockById = {}
	for _, entry in ipairs(data.ShopStock or {}) do
		stockById[entry.Id] = entry
	end
	for seedId, button in pairs(seedButtons) do
		local snack = SnackConfig[seedId]
		local entry = stockById[seedId] or {}
		local state = "In stock"
		if not entry.InStock then
			state = "Restocking"
		elseif not entry.Unlocked then
			state = entry.LockedReason or "Locked"
		end
		local costText = snack.SeedCost and tostring(snack.SeedCost) or "Locked"
		button.Text = snack.DisplayName .. "\n" .. state .. " | Cost " .. costText .. " | Owned " .. tostring(seedCount(seedId))
	end
	local panel = mainUi:FindFirstChild("SeedShopPanel")
	if panel and panel:FindFirstChild("RestockLabel") then
		panel.RestockLabel.Text = "Restock: " .. formatSeconds((data.ShopRestockEndsAt or 0) - os.time())
	end
end

local function updateUpgrades(data)
	local upgrades = data.Upgrades or {}
	for _, item in ipairs(upgrades.Items or {}) do
		local button = upgradeButtons[item.Id]
		if button then
			local levelText = tostring(item.Level) .. "/" .. tostring(item.MaxLevel)
			local costText = item.Level >= item.MaxLevel and "MAX" or ("Cost " .. tostring(item.Cost))
			button.Text = item.DisplayName .. "\nLv " .. levelText .. " | " .. costText
		end
	end
end

local function updateCollection(data)
	local panel = mainUi:WaitForChild("CollectionPanel")
	local collections = data.Collections or {}
	panel.CollectionSummary.Text = "Snacks " .. tostring(collections.SnacksDiscovered or 0) .. "/" .. tostring(collections.SnacksTotal or 0)
		.. "  Mutations " .. tostring(collections.MutationsDiscovered or 0) .. "/" .. tostring(collections.MutationsTotal or 0)
		.. "\nCombos " .. tostring(collections.CombosDiscovered or 0) .. "/" .. tostring(collections.CombosTotal or 0)
	for index = 1, 8 do
		local label = panel.SnackList:FindFirstChild("Snack" .. tostring(index))
		local entry = collections.SnackList and collections.SnackList[index]
		if label then
			label.Text = entry and entry.Name or (index == 1 and "Harvest snacks to discover them." or "???")
		end
	end
	for index = 1, 8 do
		local label = panel.MutationList:FindFirstChild("Mutation" .. tostring(index))
		local entry = collections.MutationList and collections.MutationList[index]
		if label then
			label.Text = entry and entry.Name or (index == 1 and "Mutations appear as snacks grow." or "???")
		end
	end
	for index, button in ipairs(milestoneButtons) do
		local entry = collections.Milestones and collections.Milestones[index]
		button.Visible = entry ~= nil
		if entry then
			button:SetAttribute("MilestoneId", entry.Id)
			local state = entry.Claimed and "CLAIMED" or (entry.Ready and "CLAIM" or (tostring(entry.Progress or 0) .. "/" .. tostring(entry.Target or 1)))
			button.Text = tostring(entry.Text) .. "\n" .. state .. " | " .. tostring(entry.RewardText or "Reward")
			button.AutoButtonColor = entry.Ready == true
			button.BackgroundTransparency = entry.Ready and 0 or 0.25
		end
	end
end

local function updateObjectives(data)
	local panel = mainUi:WaitForChild("ObjectivesPanel")
	local quests = data.Quests and data.Quests.Active or {}
	for index = 1, 3 do
		local label = panel:FindFirstChild("Objective" .. tostring(index))
		local quest = quests[index]
		if label then
			if quest then
				label.Text = quest.Text .. ": " .. tostring(quest.Progress or 0) .. "/" .. tostring(quest.Target or 1)
			else
				label.Text = "Objective loading..."
			end
		end
	end
end

local function updateRebirth(data)
	local panel = mainUi:WaitForChild("RebirthPanel")
	if not featureEnabled("Rebirth") then
		panel.RebirthInfo.Text = "Rebirth is disabled for this test."
		local button = panel:FindFirstChild("RebirthButton")
		if button then
			button.Text = "DISABLED"
		end
		return
	end
	local requirement = data.RebirthRequirement or GameConfig.RebirthRequirement or GameConfig.RebirthCost or 5000
	local rebirths = data.Rebirths or 0
	panel.RebirthInfo.Text = "Requirement: " .. tostring(requirement) .. " coins\nCurrent: " .. tostring(data.Coins or 0)
		.. "\nPermanent boost after rebirth: +" .. tostring(math.floor((rebirths + 1) * (GameConfig.RebirthBoostPerRebirth or 0.15) * 100)) .. "%"
		.. "\nResets: coins, seeds, inventory, displays, upgrades"
		.. "\nStays: rebirths, collections, discoveries, badges, lifetime stats"
	local button = panel:FindFirstChild("RebirthButton")
	if button and not rebirthConfirmArmed then
		button.Text = "REBIRTH"
	end
end

local function updateEventBanner(data)
	local banner = mainUi:WaitForChild("EventBanner")
	local activeName = data.ActiveEventName
	if activeName then
		local remaining = math.max(0, (data.ActiveEventEndsAt or 0) - os.time())
		banner.Visible = true
		local goldenText = data.GoldenHungerSnackId and SnackConfig[data.GoldenHungerSnackId] and (" | Wants " .. SnackConfig[data.GoldenHungerSnackId].DisplayName) or ""
		local eventText = activeName == "PhantomSnackChase" and "Catch the Phantom Snacks!" or (activeName .. " active")
		banner.EventText.Text = eventText .. " - " .. tostring(remaining) .. "s" .. goldenText
		if lastEventName ~= activeName then
			pulseGuiObject(banner, 1.025)
			lastEventName = activeName
		elseif remaining <= 5 then
			pulseGuiObject(banner.EventText, 1.02)
		end
	else
		banner.Visible = false
		lastEventName = nil
	end
end

local function updateNextGoal(data)
	local panel = mainUi:FindFirstChild("NextGoalPanel")
	local label = panel and panel:FindFirstChild("NextGoalText")
	if label then
		local goal = data.NextGoal
		label.Text = goal and ("Next Goal: " .. tostring(goal.Text)) or "Next Goal: Grow a snack"
	end
end

local function updatePlaytime(data)
	local panel = mainUi:FindFirstChild("PlaytimeRewardsPanel")
	if not panel then
		return
	end
	if not featureEnabled("PlaytimeRewards") or (data.PlaytimeRewards and data.PlaytimeRewards.Disabled) then
		panel.Visible = false
		local quick = mainUi:FindFirstChild("QuickActions")
		if quick and quick:FindFirstChild("PlaytimeButton") then
			quick.PlaytimeButton.Visible = false
		end
		return
	end
	local quick = mainUi:FindFirstChild("QuickActions")
	if quick and quick:FindFirstChild("PlaytimeButton") then
		quick.PlaytimeButton.Visible = uiReady
	end
	local playtime = data.PlaytimeRewards or {}
	local rewards = playtime.Rewards or {}
	local nextReward = nil
	for _, reward in ipairs(rewards) do
		if reward.Ready and not reward.Claimed then
			nextReward = reward
			break
		end
		if not reward.Claimed and not nextReward then
			nextReward = reward
		end
	end
	local info = panel:FindFirstChild("RewardInfo")
	if info then
		if nextReward then
			local waitText = nextReward.Ready and "Ready to claim" or ("Ready in " .. formatSeconds((nextReward.Seconds or 0) - (playtime.Elapsed or 0)))
			info.Text = tostring(nextReward.Label) .. "\n" .. waitText
		else
			info.Text = "All session rewards claimed. Keep feeding The Void."
		end
	end
	local button = panel:FindFirstChild("ClaimButton")
	if button then
		button:SetAttribute("RewardSeconds", nextReward and nextReward.Seconds or 0)
		button.Text = nextReward and nextReward.Ready and "CLAIM" or "WAIT"
	end
end

local function updateDaily(data)
	local panel = mainUi:FindFirstChild("DailyRewardPanel")
	if not panel then
		return
	end
	if not featureEnabled("DailyRewards") or (data.DailyReward and data.DailyReward.Disabled) then
		panel.Visible = false
		local quick = mainUi:FindFirstChild("QuickActions")
		if quick and quick:FindFirstChild("DailyButton") then
			quick.DailyButton.Visible = false
		end
		return
	end
	local quick = mainUi:FindFirstChild("QuickActions")
	if quick and quick:FindFirstChild("DailyButton") then
		quick.DailyButton.Visible = uiReady
	end
	local daily = data.DailyReward or {}
	local info = panel:FindFirstChild("DailyInfo")
	if info then
		local readyText = daily.CanClaim and "Ready now" or ("Ready in " .. formatSeconds(daily.RemainingSeconds or 0))
		info.Text = "Streak: " .. tostring(daily.Streak or 0) .. "/7\n" .. tostring(daily.NextReward or "Daily Reward") .. "\n" .. readyText
	end
	local button = panel:FindFirstChild("ClaimButton")
	if button then
		button.Text = daily.CanClaim and "CLAIM DAILY" or "COME BACK SOON"
	end
end

local function updateSettings(data)
	local panel = mainUi:FindFirstChild("SettingsPanel")
	if not panel then
		return
	end
	local settings = data.Settings or {}
	if soundController then
		if soundController.SetMuted then
			soundController.SetMuted(settings.MuteSounds == true)
		end
		if soundController.SetGroupVolume then
			soundController.SetGroupVolume("Ambience", settings.LowDetailMode and 0.07 or 0.16)
		end
	end
	for _, key in ipairs({ "ReduceEffects", "LowDetailMode", "MuteSounds", "HideExtraPopups", "AutoClosePanels", "ShowGuidance" }) do
		local button = panel:FindFirstChild(key .. "Button")
		if button then
			button.Text = key:gsub("(%u)", " %1"):gsub("^%s+", "") .. ": " .. (settings[key] and "ON" or "OFF")
			button:SetAttribute("SettingValue", settings[key] == true)
		end
	end
end

local function updateFeedbackVisibility(data)
	local enabled = (data and data.FeedbackEnabled == true) or (GameConfig.LaunchMode ~= "Production" and FeatureFlags.PrivateTestFeedback ~= false and (GameConfig.PrivateTest or {}).EnableFeedbackButton ~= false)
	local button = mainUi:FindFirstChild("FeedbackButton")
	if button then
		button.Visible = uiReady and enabled
	end
	local panel = mainUi:FindFirstChild("FeedbackPanel")
	if panel and not enabled then
		panel.Visible = false
	end
end

local function setFeedbackCategory(category)
	selectedFeedbackCategory = category
	local panel = mainUi and mainUi:FindFirstChild("FeedbackPanel")
	if not panel then
		return
	end
	local categoryFrame = panel:FindFirstChild("CategoryButtons")
	if not categoryFrame then
		return
	end
	for _, name in ipairs(feedbackCategories) do
		local button = categoryFrame:FindFirstChild(name .. "Button")
		if button then
			button.BackgroundTransparency = name == selectedFeedbackCategory and 0 or 0.24
		end
	end
end

local function bindFeedbackControls()
	local openButton = mainUi:FindFirstChild("FeedbackButton")
	local panel = mainUi:FindFirstChild("FeedbackPanel")
	if not openButton or not panel then
		return
	end
	openButton.Activated:Connect(function()
		showPanel("FeedbackPanel")
		setFeedbackCategory(selectedFeedbackCategory)
	end)
	local close = panel:FindFirstChild("CloseButton")
	if close then
		close.Activated:Connect(function()
			showPanel(nil)
		end)
	end
	local categoryFrame = panel:FindFirstChild("CategoryButtons")
	if categoryFrame then
		for _, category in ipairs(feedbackCategories) do
			local button = categoryFrame:FindFirstChild(category .. "Button")
			if button then
				button.Activated:Connect(function()
					setFeedbackCategory(category)
				end)
			end
		end
	end
	local submit = panel:FindFirstChild("SubmitButton")
	local box = panel:FindFirstChild("MessageBox")
	if submit and box then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > 200 then
				box.Text = box.Text:sub(1, 200)
			end
		end)
		submit.Activated:Connect(function()
			local remote = Remotes:FindFirstChild("RequestSubmitFeedback")
			if not remote then
				if notificationController then
					notificationController.Show("Feedback is not ready yet.")
				end
				playUiSound("UI.Error")
				return
			end
			local nextGoal = currentData and currentData.NextGoal and currentData.NextGoal.Text or nil
			remote:FireServer({
				Category = selectedFeedbackCategory,
				Message = box.Text,
				DeviceType = getDeviceType(),
				CurrentPanel = currentMajorPanel or "HUD",
				NextGoal = nextGoal,
			})
			box.Text = ""
			showPanel(nil)
		end)
	end
	setFeedbackCategory(selectedFeedbackCategory)
end

local function updateTutorial(data)
	local panel = mainUi:FindFirstChild("TutorialPanel")
	if not panel then
		return
	end
	local step = data.TutorialStep or 1
	if step > #GameConfig.TutorialMessages then
		panel.Visible = false
	else
		panel.Visible = true
		panel.TutorialText.Text = GameConfig.TutorialMessages[step] or "Follow the objectives."
	end
end

local function bindRemotes()
	if remotesBound then
		return
	end
	remotesBound = true
	Remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		UIController.ApplyData(data)
	end)
	Remotes.NotifyClient.OnClientEvent:Connect(function(message)
		if notificationController then
			notificationController.Show(message)
		end
		if messageLooksLikeError(message) then
			playUiSound("UI.Error")
		end
	end)
end

function UIController.Init(ui, notifications, guidance, sounds)
	mainUi = ui
	notificationController = notifications
	guidanceController = guidance
	soundController = sounds
	applyPrivateTestLayout()
	setUiReady(false)
	bindButtonPulse(mainUi)
	local watermark = mainUi:FindFirstChild("PrivateTestWatermark")
	if watermark then
		watermark.Visible = false
		watermark.Text = "PRIVATE TEST | " .. tostring(GameConfig.BuildVersion or GameConfig.Phase or "Phase 13")
	end
	bindRemotes()
	bindFeedbackControls()
	task.delay(15, function()
		if mainUi and mainUi.Parent and not uiReady then
			setLoadingVisible(true, "Still loading your lab...")
		end
	end)
	local inventory = mainUi:WaitForChild("InventoryPanel")
	local itemList = inventory:WaitForChild("ItemList")
	for index = 1, 8 do
		local button = itemList:WaitForChild("Item" .. tostring(index))
		itemButtons[index] = button
		button.Activated:Connect(function()
			local uniqueId = button:GetAttribute("UniqueId")
			if not currentData or not uniqueId or uniqueId == "" then
				playUiSound("UI.Error")
				return
			end
			for _, item in ipairs(currentData.Inventory or {}) do
				if item.UniqueId == uniqueId then
					selectItem(item)
					break
				end
			end
		end)
	end
	inventory.SellButton.Activated:Connect(function()
		requestItemAction("Sell")
	end)
	inventory.FeedButton.Activated:Connect(function()
		requestItemAction("Feed")
	end)
	inventory.DisplayButton.Activated:Connect(function()
		requestItemAction("Display")
	end)
	local lockButton = inventory:FindFirstChild("LockButton")
	if lockButton then
		lockButton.Activated:Connect(function()
			if selectedItemId then
				hideConfirm()
				Remotes.RequestToggleItemLock:FireServer(selectedItemId)
			else
				playUiSound("UI.Error")
			end
		end)
	end
	local sortButton = inventory:FindFirstChild("SortButton")
	if sortButton then
		sortButton.Activated:Connect(function()
			sortModeIndex = (sortModeIndex % #sortModes) + 1
			if currentData then
				updateInventory(currentData)
			end
		end)
	end
	local filterButton = inventory:FindFirstChild("FilterButton")
	if filterButton then
		filterButton.Activated:Connect(function()
			filterModeIndex = (filterModeIndex % #filterModes) + 1
			if currentData then
				updateInventory(currentData)
			end
		end)
	end
	local confirmPanel = inventory:FindFirstChild("ConfirmPanel")
	if confirmPanel then
		confirmPanel.ConfirmButton.Activated:Connect(function()
			if pendingConfirm then
				fireItemAction(pendingConfirm.Action, pendingConfirm.ItemId)
			end
			hideConfirm()
		end)
		confirmPanel.CancelButton.Activated:Connect(hideConfirm)
	end

	local shop = mainUi:WaitForChild("SeedShopPanel")
	for _, seedId in ipairs(SnackConfig.Order) do
		local button = shop.SeedList:FindFirstChild(seedId .. "Button")
		if button then
			seedButtons[seedId] = button
			button.Activated:Connect(function()
				selectedSeedId = seedId
				Remotes.RequestBuySeed:FireServer(seedId)
			end)
		end
	end

	local upgrades = mainUi:WaitForChild("UpgradePanel")
	for _, upgradeId in ipairs(GameConfig.UpgradeOrder) do
		local button = upgrades.UpgradeList:FindFirstChild(upgradeId .. "Button")
		if button then
			upgradeButtons[upgradeId] = button
			button.Activated:Connect(function()
				Remotes.RequestBuyUpgrade:FireServer(upgradeId)
			end)
		end
	end

	local collectionPanel = mainUi:WaitForChild("CollectionPanel")
	for index = 1, 3 do
		local button = collectionPanel:FindFirstChild("MilestoneButton" .. tostring(index))
		if button then
			milestoneButtons[index] = button
			button.Activated:Connect(function()
				local milestoneId = button:GetAttribute("MilestoneId")
				if milestoneId and milestoneId ~= "" then
					Remotes.RequestClaimCollectionMilestone:FireServer(milestoneId)
				end
			end)
		end
	end

	mainUi.RebirthPanel.RebirthButton.Activated:Connect(function()
		if not rebirthConfirmArmed then
			rebirthConfirmArmed = true
			mainUi.RebirthPanel.RebirthButton.Text = "CONFIRM"
			if notificationController then
				notificationController.Show("Rebirth will reset your lab but keep permanent progress.")
			end
			task.delay(5, function()
				rebirthConfirmArmed = false
				if mainUi and mainUi:FindFirstChild("RebirthPanel") then
					mainUi.RebirthPanel.RebirthButton.Text = "REBIRTH"
				end
			end)
			return
		end
		rebirthConfirmArmed = false
		Remotes.RequestRebirth:FireServer()
	end)
	mainUi.TutorialPanel.SkipTutorialButton.Activated:Connect(function()
		Remotes.RequestSkipTutorial:FireServer()
	end)
	local playtime = mainUi:FindFirstChild("PlaytimeRewardsPanel")
	if playtime and playtime:FindFirstChild("ClaimButton") then
		playtime.ClaimButton.Activated:Connect(function()
			Remotes.RequestClaimPlaytimeReward:FireServer(playtime.ClaimButton:GetAttribute("RewardSeconds"))
		end)
	end
	local daily = mainUi:FindFirstChild("DailyRewardPanel")
	if daily and daily:FindFirstChild("ClaimButton") then
		daily.ClaimButton.Activated:Connect(function()
			Remotes.RequestClaimDailyReward:FireServer()
		end)
	end
	local settings = mainUi:FindFirstChild("SettingsPanel")
	if settings then
		for _, key in ipairs({ "ReduceEffects", "LowDetailMode", "MuteSounds", "HideExtraPopups", "AutoClosePanels", "ShowGuidance" }) do
			local button = settings:FindFirstChild(key .. "Button")
			if button then
				button.Activated:Connect(function()
					Remotes.RequestUpdateSettings:FireServer(key, not button:GetAttribute("SettingValue"))
				end)
			end
		end
	end

	local nav = mainUi:WaitForChild("BottomNav")
	nav.InventoryButton.Activated:Connect(function() showPanel("InventoryPanel") end)
	local seedNavButton = nav:FindFirstChild("SeedsButton") or nav:FindFirstChild("ShopButton")
	if seedNavButton then
		seedNavButton.Activated:Connect(function() showPanel("SeedShopPanel") end)
	end
	nav.UpgradesButton.Activated:Connect(function() showPanel("UpgradePanel") end)
	nav.CollectionButton.Activated:Connect(function() showPanel("CollectionPanel") end)
	nav.RebirthButton.Activated:Connect(function() showPanel("RebirthPanel") end)
	local quick = mainUi:FindFirstChild("QuickActions")
	if quick then
		if quick:FindFirstChild("PlaytimeButton") then
			quick.PlaytimeButton.Activated:Connect(function() showPanel("PlaytimeRewardsPanel") end)
		end
		if quick:FindFirstChild("DailyButton") then
			quick.DailyButton.Activated:Connect(function() showPanel("DailyRewardPanel") end)
		end
		if quick:FindFirstChild("SettingsButton") then
			quick.SettingsButton.Activated:Connect(function() showPanel("SettingsPanel") end)
		end
		if quick:FindFirstChild("LabButton") then
			quick.LabButton.Activated:Connect(function()
				if guidanceController then
					guidanceController.SetGuidanceTarget({
						Id = "FindMyLab",
						Text = "Your lab",
						TargetType = "Plot",
						Priority = 999,
					})
				end
				local teleportRemote = Remotes:FindFirstChild("RequestTeleportToPlot")
				if teleportRemote then
					teleportRemote:FireServer()
				end
			end)
		end
	end
	if featureEnabled("ContextualActionButton") and nav:FindFirstChild("MobileActionButton") then
		nav.MobileActionButton.Activated:Connect(function()
			local action = getNearestAction()
			if action.Kind == "Harvest" then
				Remotes.RequestHarvestSnack:FireServer(action.Target)
			elseif action.Kind == "Cleanse" then
				Remotes.RequestClearVoidmite:FireServer(action.Target)
			elseif action.Kind == "Feed" then
				requestItemAction("Feed")
			elseif action.Kind == "Sell" then
				requestItemAction("Sell")
			elseif action.Kind == "Display" then
				requestItemAction("Display")
			elseif action.Kind == "Shop" then
				showPanel("SeedShopPanel")
			elseif action.Kind == "Upgrade" then
				showPanel("UpgradePanel")
			elseif action.Kind == "Rebirth" then
				showPanel("RebirthPanel")
			elseif not action.Target then
				playUiSound("UI.Error")
			else
				Remotes.RequestPlantSnack:FireServer(action.Target, selectedSeedId)
			end
		end)
		task.spawn(function()
			while mainUi and mainUi.Parent do
				updateMobileActionButton(nav.MobileActionButton)
				task.wait(0.35)
			end
		end)
	elseif nav:FindFirstChild("MobileActionButton") then
		nav.MobileActionButton.Visible = false
	end
	for _, panelName in ipairs(majorPanels) do
		local panel = mainUi:FindFirstChild(panelName)
		local close = panel and panel:FindFirstChild("CloseButton")
		if close then
			close.Activated:Connect(function()
				showPanel(nil)
			end)
		end
	end

	showPanel(nil)
end

function UIController.ApplyData(data)
	if type(data) ~= "table" then
		warnOnce("NilSnapshot", "Ignored empty SyncPlayerData snapshot.")
		return
	end
	currentData = data
	if not mainUi then
		warnOnce("MissingMainUi", "MainUI was not ready when data arrived.")
		return
	end
	setUiReady(true)
	updateFeedbackVisibility(data)
	local top = mainUi:FindFirstChild("TopStats")
	if not top then
		warnOnce("MissingTopStats", "TopStats missing.")
		return
	end
	top.CoinsLabel.Text = "Coins: " .. FormatNumbers.Compact(data.Coins or 0)
	top.TokensLabel.Text = "Void Tokens: " .. FormatNumbers.Compact(data.VoidTokens or 0)
	top.RebirthsLabel.Text = "Rebirths: " .. tostring(data.Rebirths or 0)
	top.HungerLabel.Text = "Void Hunger: " .. tostring(math.floor(data.VoidHunger or 0)) .. "/" .. tostring(data.VoidHungerRequired or 100)
	top.HungerBarBack.HungerBarFill.Size = UDim2.new(math.clamp((data.VoidHunger or 0) / (data.VoidHungerRequired or 100), 0, 1), 0, 1, 0)
	pulseOnIncrease(top.CoinsLabel, "Coins", data.Coins)
	pulseOnIncrease(top.TokensLabel, "VoidTokens", data.VoidTokens)
	pulseOnIncrease(top.RebirthsLabel, "Rebirths", data.Rebirths)
	pulseOnIncrease(top.HungerBarBack, "VoidHunger", data.VoidHunger)
	updateInventory(data)
	updateShop(data)
	updateUpgrades(data)
	updateCollection(data)
	updateObjectives(data)
	updateRebirth(data)
	updateEventBanner(data)
	updateTutorial(data)
	updateNextGoal(data)
	updatePlaytime(data)
	updateDaily(data)
	updateSettings(data)
	updateFeedbackVisibility(data)
	if guidanceController then
		guidanceController.ApplyData(data)
	end
end

return UIController
