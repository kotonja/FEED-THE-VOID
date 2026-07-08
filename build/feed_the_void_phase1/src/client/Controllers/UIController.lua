local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FormatNumbers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumbers"))

local UIController = {}

local mainUi
local selectedItemId

local function firstInventoryItem(data)
	return data.Inventory and data.Inventory[1] or nil
end

local function seedsText(seeds)
	local parts = {}
	for seedId, count in pairs(seeds or {}) do
		table.insert(parts, seedId .. ": " .. tostring(count))
	end
	table.sort(parts)
	return table.concat(parts, "  ")
end

function UIController.Init(ui, notificationController)
	mainUi = ui
	UIController.NotificationController = notificationController

	local inventoryPanel = mainUi:WaitForChild("InventoryPanel")
	inventoryPanel.SellButton.Activated:Connect(function()
		Remotes.RequestSellSnack:FireServer(selectedItemId)
	end)
	inventoryPanel.FeedButton.Activated:Connect(function()
		Remotes.RequestFeedVoid:FireServer(selectedItemId)
	end)
	inventoryPanel.DisplayButton.Activated:Connect(function()
		Remotes.RequestDisplaySnack:FireServer(selectedItemId)
	end)

	local shop = mainUi:WaitForChild("SeedShopPanel")
	shop.CookieButton.Activated:Connect(function()
		Remotes.RequestBuySeed:FireServer("CookieRock")
	end)
	shop.JellyButton.Activated:Connect(function()
		Remotes.RequestBuySeed:FireServer("JellyCube")
	end)
	shop.MeteorButton.Activated:Connect(function()
		Remotes.RequestBuySeed:FireServer("MeteorMuffin")
	end)
	shop.RebirthButton.Activated:Connect(function()
		Remotes.RequestRebirth:FireServer()
	end)

	Remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		UIController.ApplyData(data)
	end)
	Remotes.NotifyClient.OnClientEvent:Connect(function(message)
		notificationController.Show(message)
	end)
end

function UIController.ApplyData(data)
	local top = mainUi:WaitForChild("TopStats")
	top.CoinsLabel.Text = "Coins: " .. FormatNumbers.Compact(data.Coins or 0)
	top.TokensLabel.Text = "Void Tokens: " .. FormatNumbers.Compact(data.VoidTokens or 0)
	top.HungerLabel.Text = "Void Hunger: " .. tostring(math.floor(data.VoidHunger or 0)) .. "/" .. tostring(data.VoidHungerRequired or 100)
	local fill = top.HungerBarBack.HungerBarFill
	fill.Size = UDim2.new(math.clamp((data.VoidHunger or 0) / (data.VoidHungerRequired or 100), 0, 1), 0, 1, 0)

	local inventoryPanel = mainUi:WaitForChild("InventoryPanel")
	local first = firstInventoryItem(data)
	selectedItemId = first and first.UniqueId or nil
	inventoryPanel.FirstItemLabel.Text = first and ("Selected: " .. first.DisplayName) or "Selected: none"
	inventoryPanel.InventoryList.Text = "Inventory: " .. tostring(#(data.Inventory or {})) .. " snacks"
	inventoryPanel.SeedsLabel.Text = "Seeds: " .. seedsText(data.Seeds)
	inventoryPanel.DisplayedLabel.Text = "Displayed: " .. tostring(#(data.DisplayedSnacks or {}))
end

return UIController
