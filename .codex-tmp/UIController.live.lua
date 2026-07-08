local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FormatNumbers = require(Shared:WaitForChild("FormatNumbers"))
local SnackConfig = require(Shared:WaitForChild("SnackConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local UIController = {}

local mainUi
local notificationController
local currentData = nil
local selectedItemId = nil
local selectedSeedId = "CookieRock"
local itemButtons = {}
local seedButtons = {}
local upgradeButtons = {}
local majorPanels = { "InventoryPanel", "SeedShopPanel", "UpgradePanel", "CollectionPanel", "RebirthPanel", "PlaytimeRewardsPanel", "DailyRewardPanel", "SettingsPanel" }
local player = Players.LocalPlayer
local remotesBound = false

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

local function showPanel(panelName)
	for _, name in ipairs(majorPanels) do
		local panel = mainUi:FindFirstChild(name)
		if panel then
			panel.Visible = name == panelName
		end
	end
end

local function selectItem(item)
	selectedItemId = item and item.UniqueId or nil
	local detail = mainUi.InventoryPanel:WaitForChild("SelectedDetail")
	if item then
		detail.Text = item.DisplayName .. "\nSell: " .. tostring(item.EstimatedSellValue or 0) .. "  Void: " .. tostring(item.EstimatedVoidValue or 0)
	else
		detail.Text = "Select a harvested snack."
	end
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
	panel.SeedsLabel.Text = "Seeds: " .. (#seedParts > 0 and table.concat(seedParts, "  ") or "none")
	for index, button in ipairs(itemButtons) do
		local item = inventory[index]
		button.Visible = item ~= nil
		if item then
			button.Text = item.DisplayName .. "\n" .. tostring(item.MutationName or item.MutationId or "Normal") .. " | Sell " .. tostring(item.EstimatedSellValue or 0)
			button:SetAttribute("UniqueId", item.UniqueId)
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
		selectItem(stillSelected or inventory[1])
	else
		selectItem(inventory[1])
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
		button.Text = snack.DisplayName .. "\n" .. state .. " | Cost " .. tostring(snack.SeedCost) .. " | Owned " .. tostring(seedCount(seedId))
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
			label.Text = entry and entry.Name or "???"
		end
	end
	for index = 1, 8 do
		local label = panel.MutationList:FindFirstChild("Mutation" .. tostring(index))
		local entry = collections.MutationList and collections.MutationList[index]
		if label then
			label.Text = entry and entry.Name or "???"
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
	local requirement = GameConfig.RebirthRequirement or GameConfig.RebirthCost or 5000
	local rebirths = data.Rebirths or 0
	panel.RebirthInfo.Text = "Requirement: " .. tostring(requirement) .. " coins\nCurrent: " .. tostring(data.Coins or 0)
		.. "\nPermanent boost after rebirth: +" .. tostring(math.floor((rebirths + 1) * (GameConfig.RebirthBoostPerRebirth or 0.15) * 100)) .. "%"
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
	else
		banner.Visible = false
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
	for _, key in ipairs({ "ReduceEffects", "LowDetailMode", "MuteSounds", "HideExtraPopups", "AutoClosePanels" }) do
		local button = panel:FindFirstChild(key .. "Button")
		if button then
			button.Text = key:gsub("(%u)", " %1"):gsub("^%s+", "") .. ": " .. (settings[key] and "ON" or "OFF")
			button:SetAttribute("SettingValue", settings[key] == true)
		end
	end
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
	end)
end

function UIController.Init(ui, notifications)
	mainUi = ui
	notificationController = notifications
	bindRemotes()
	local inventory = mainUi:WaitForChild("InventoryPanel")
	local itemList = inventory:WaitForChild("ItemList")
	for index = 1, 8 do
		local button = itemList:WaitForChild("Item" .. tostring(index))
		itemButtons[index] = button
		button.Activated:Connect(function()
			local uniqueId = button:GetAttribute("UniqueId")
			if not currentData or not uniqueId or uniqueId == "" then
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
		Remotes.RequestSellSnack:FireServer(selectedItemId)
	end)
	inventory.FeedButton.Activated:Connect(function()
		Remotes.RequestFeedVoid:FireServer(selectedItemId)
	end)
	inventory.DisplayButton.Activated:Connect(function()
		Remotes.RequestDisplaySnack:FireServer(selectedItemId)
	end)

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

	mainUi.RebirthPanel.RebirthButton.Activated:Connect(function()
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
		for _, key in ipairs({ "ReduceEffects", "LowDetailMode", "MuteSounds", "HideExtraPopups", "AutoClosePanels" }) do
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
	end
	nav.MobileActionButton.Activated:Connect(function()
		local action = getNearestAction()
		if action.Kind == "Harvest" then
			Remotes.RequestHarvestSnack:FireServer(action.Target)
		elseif action.Kind == "Cleanse" then
			Remotes.RequestClearVoidmite:FireServer(action.Target)
		elseif action.Kind == "Feed" then
			Remotes.RequestFeedVoid:FireServer(selectedItemId)
		elseif action.Kind == "Sell" then
			Remotes.RequestSellSnack:FireServer(selectedItemId)
		elseif action.Kind == "Display" then
			Remotes.RequestDisplaySnack:FireServer(selectedItemId)
		elseif action.Kind == "Shop" then
			showPanel("SeedShopPanel")
		elseif action.Kind == "Upgrade" then
			showPanel("UpgradePanel")
		elseif action.Kind == "Rebirth" then
			showPanel("RebirthPanel")
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
	for _, panelName in ipairs(majorPanels) do
		local panel = mainUi:FindFirstChild(panelName)
		local close = panel and panel:FindFirstChild("CloseButton")
		if close then
			close.Activated:Connect(function()
				showPanel(nil)
			end)
		end
	end

	showPanel("SeedShopPanel")
end

function UIController.ApplyData(data)
	currentData = data
	local top = mainUi:WaitForChild("TopStats")
	top.CoinsLabel.Text = "Coins: " .. FormatNumbers.Compact(data.Coins or 0)
	top.TokensLabel.Text = "Void Tokens: " .. FormatNumbers.Compact(data.VoidTokens or 0)
	top.RebirthsLabel.Text = "Rebirths: " .. tostring(data.Rebirths or 0)
	top.HungerLabel.Text = "Void Hunger: " .. tostring(math.floor(data.VoidHunger or 0)) .. "/" .. tostring(data.VoidHungerRequired or 100)
	top.HungerBarBack.HungerBarFill.Size = UDim2.new(math.clamp((data.VoidHunger or 0) / (data.VoidHungerRequired or 100), 0, 1), 0, 1, 0)
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
end

return UIController

