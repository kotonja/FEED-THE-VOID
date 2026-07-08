const childProcess = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const phase15Generator = path.join(__dirname, "generate_feed_the_void_phase15.js");
const phase15Dir = path.join(root, "build", "feed_the_void_phase15");
const phase15BlueprintPath = path.join(phase15Dir, "feed_the_void_phase15.blueprint.json");
const outDir = path.join(root, "build", "feed_the_void_phase2");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase2.blueprint.json");

childProcess.execFileSync(process.execPath, [phase15Generator], { cwd: root, stdio: "inherit" });
fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(srcDir, { recursive: true });
fs.cpSync(path.join(phase15Dir, "src"), srcDir, { recursive: true });

const baseBlueprint = JSON.parse(fs.readFileSync(phase15BlueprintPath, "utf8"));
const phase2StalePaths = new Set([
  "StarterGui.MainUI.SeedShopPanel.CookieButton",
  "StarterGui.MainUI.SeedShopPanel.JellyButton",
  "StarterGui.MainUI.SeedShopPanel.MeteorButton",
  "StarterGui.MainUI.SeedShopPanel.RebirthButton",
  "StarterGui.MainUI.InventoryPanel.FirstItemLabel",
  "StarterGui.MainUI.Notifications.NotificationText",
]);
const phase2ScriptOverridePaths = new Set([
  "ReplicatedStorage.Shared.GameConfig",
  "ReplicatedStorage.Shared.SnackConfig",
  "ReplicatedStorage.Shared.MutationConfig",
  "ReplicatedStorage.Shared.EventConfig",
  "ServerScriptService.Server.Main",
  "ServerScriptService.Server.Services.ProfileServiceWrapper",
  "ServerScriptService.Server.Services.EconomyService",
  "ServerScriptService.Server.Services.InventoryService",
  "ServerScriptService.Server.Services.ShopService",
  "ServerScriptService.Server.Services.RebirthService",
  "ServerScriptService.Server.Services.EventService",
  "ServerScriptService.Server.Services.VoidService",
  "ServerScriptService.Server.Services.SnackService",
  "ServerScriptService.Server.Services.VoidmiteService",
  "StarterPlayer.StarterPlayerScripts.ClientMain",
  "StarterPlayer.StarterPlayerScripts.Controllers.UIController",
]);

function shouldDropBaseStep(baseStep) {
  const pathName = baseStep && baseStep.path;
  if (!pathName) return false;
  if (phase2StalePaths.has(pathName)) return true;
  if (pathName === "StarterPlayer.StarterPlayerScripts.ClientMain.Controllers") return true;
  if (pathName.startsWith("StarterPlayer.StarterPlayerScripts.ClientMain.Controllers.")) return true;
  return baseStep.type === "writeScript" && phase2ScriptOverridePaths.has(pathName);
}

const steps = baseBlueprint.steps
  .filter((baseStep) => !shouldDropBaseStep(baseStep))
  .map((baseStep) => ({ ...baseStep }));

const v3 = (x, y, z) => ({ __type: "Vector3", x, y, z });
const c3 = (r, g, b) => ({ __type: "Color3", mode: "rgb", r, g, b });
const ud2 = (xScale, xOffset, yScale, yOffset) => ({
  __type: "UDim2",
  xScale,
  xOffset,
  yScale,
  yOffset,
});

function step(type, pathName, extra = {}) {
  return { type, path: pathName, ...extra };
}

function writeSource(name, source) {
  const filePath = path.join(srcDir, name);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, source.replace(/\r\n/g, "\n").trimStart(), "utf8");
  return path.relative(outDir, filePath).replace(/\\/g, "/");
}

function writeScript(studioPath, className, sourceName, source) {
  steps.push(step("writeScript", studioPath, {
    className,
    sourceFile: writeSource(sourceName, source),
    overwrite: true,
  }));
}

function ensureFolder(pathName) {
  steps.push(step("ensureFolder", pathName));
}

function ensureRemote(name) {
  steps.push(step("ensureRemoteEvent", `ReplicatedStorage.Remotes.${name}`));
}

function inst(className, pathName, properties = {}) {
  steps.push(step("ensureInstance", pathName, { className, properties }));
  steps.push(step("setProperties", pathName, { properties }));
}

function sourceHash(source) {
  return "sha256:" + crypto.createHash("sha256").update(source.replace(/\r\n/g, "\n").trimStart()).digest("hex");
}

const gameConfigSource = `
local GameConfig = {
	StartingCoins = 100,
	StartingSeeds = {
		CookieRock = 3,
		MoonMarshmallow = 1,
	},
	MaxPlayersPerServerTarget = 8,
	PlateCount = 6,
	MaxPlateCount = 10,
	BaseDisplayIncomeInterval = 10,
	VoidHungerRequired = 100,
	RebirthRequirement = 5000,
	RebirthCost = 5000,
	RebirthBoostPerRebirth = 0.15,
	RemoteCooldown = 0.25,
	RemoteCooldowns = {
		RequestPlantSnack = 0.5,
		RequestHarvestSnack = 0.5,
		RequestClearVoidmite = 0.25,
		RequestBuySeed = 0.35,
		RequestBuyUpgrade = 0.35,
		RequestFeedVoid = 0.35,
		RequestSellSnack = 0.35,
		RequestDisplaySnack = 0.35,
		RequestRebirth = 2,
		RequestSkipTutorial = 1,
		RequestDebugCommand = 0.5,
	},
	MaxVoidmitesPerPlot = 8,
	BaseVoidmiteSpawnInterval = 25,
	MinVoidmiteSpawnInterval = 8,
	DebugMode = true,
	DebugFastGrowth = false,
	DebugFastVoid = false,
	DebugGiveCoins = true,
	DebugShortEvents = false,
	FastGrowthTime = 6,
	FastVoidHungerRequired = 30,
	UpgradeOrder = {
		"ExtraPlate",
		"GrowSpeed",
		"SellMultiplier",
		"VoidRewardMultiplier",
		"DisplayIncome",
		"VoidmiteReward",
	},
	UpgradeConfig = {
		ExtraPlate = {
			DisplayName = "Extra Plate",
			BaseCost = 250,
			MaxLevel = 4,
			Kind = "Plate",
			Description = "Unlock one more grow plate.",
		},
		GrowSpeed = {
			DisplayName = "Grow Speed",
			BaseCost = 150,
			MaxLevel = 10,
			PerLevel = 0.05,
			Description = "+5% grow speed per level.",
		},
		SellMultiplier = {
			DisplayName = "Sell Multiplier",
			BaseCost = 200,
			MaxLevel = 10,
			PerLevel = 0.10,
			Description = "+10% sell value per level.",
		},
		VoidRewardMultiplier = {
			DisplayName = "Void Reward",
			BaseCost = 220,
			MaxLevel = 10,
			PerLevel = 0.10,
			Description = "+10% Void rewards per level.",
		},
		DisplayIncome = {
			DisplayName = "Display Income",
			BaseCost = 180,
			MaxLevel = 10,
			PerLevel = 0.10,
			Description = "+10% passive income per level.",
		},
		VoidmiteReward = {
			DisplayName = "Voidmite Reward",
			BaseCost = 180,
			MaxLevel = 10,
			PerLevel = 0.10,
			Description = "+10% cleanse rewards per level.",
		},
	},
	TutorialMessages = {
		"Welcome to FEED THE VOID!",
		"Open the seed shop and plant a snack.",
		"Harvest snacks when they finish growing.",
		"Open inventory, then sell or feed a snack.",
		"Display snacks to earn passive coins.",
		"Cleanse Voidmites when they swarm displays.",
		"Feed The Void until the meter starts an event.",
		"Tutorial complete. Keep discovering snacks and mutations!",
	},
}

return GameConfig
`;

const snackConfigSource = `
local SnackConfig = {
	CookieRock = {
		DisplayName = "Cookie Rock",
		SeedCost = 10,
		GrowTime = 20,
		BaseSellValue = 25,
		BaseVoidValue = 10,
		Rarity = "Common",
		VisualType = "Round",
		Color = Color3.fromRGB(185, 164, 132),
	},
	JellyCube = {
		DisplayName = "Jelly Cube",
		SeedCost = 25,
		GrowTime = 35,
		BaseSellValue = 70,
		BaseVoidValue = 22,
		Rarity = "Uncommon",
		VisualType = "Cube",
		Color = Color3.fromRGB(92, 220, 225),
	},
	MeteorMuffin = {
		DisplayName = "Meteor Muffin",
		SeedCost = 100,
		GrowTime = 60,
		BaseSellValue = 250,
		BaseVoidValue = 60,
		Rarity = "Rare",
		VisualType = "Round",
		Color = Color3.fromRGB(220, 92, 76),
	},
	MoonMarshmallow = {
		DisplayName = "Moon Marshmallow",
		SeedCost = 15,
		GrowTime = 25,
		BaseSellValue = 40,
		BaseVoidValue = 14,
		Rarity = "Common",
		VisualType = "Round",
		Color = Color3.fromRGB(220, 224, 255),
	},
	BubbleBread = {
		DisplayName = "Bubble Bread",
		SeedCost = 40,
		GrowTime = 40,
		BaseSellValue = 110,
		BaseVoidValue = 30,
		Rarity = "Uncommon",
		VisualType = "Wrap",
		Color = Color3.fromRGB(255, 158, 204),
	},
	CrystalDonut = {
		DisplayName = "Crystal Donut",
		SeedCost = 180,
		GrowTime = 75,
		BaseSellValue = 450,
		BaseVoidValue = 90,
		Rarity = "Rare",
		VisualType = "Round",
		Color = Color3.fromRGB(119, 218, 255),
	},
	LavaNoodleWrap = {
		DisplayName = "Lava Noodle Wrap",
		SeedCost = 500,
		GrowTime = 120,
		BaseSellValue = 1400,
		BaseVoidValue = 220,
		Rarity = "Epic",
		VisualType = "Wrap",
		Color = Color3.fromRGB(255, 97, 48),
	},
	BlackHoleBurrito = {
		DisplayName = "Black Hole Burrito",
		SeedCost = 2500,
		GrowTime = 240,
		BaseSellValue = 9000,
		BaseVoidValue = 900,
		Rarity = "Legendary",
		VisualType = "Wrap",
		Color = Color3.fromRGB(48, 31, 70),
	},
}

local order = {
	"CookieRock",
	"MoonMarshmallow",
	"JellyCube",
	"BubbleBread",
	"MeteorMuffin",
	"CrystalDonut",
	"LavaNoodleWrap",
	"BlackHoleBurrito",
}

SnackConfig.Order = order

return SnackConfig
`;

const mutationConfigSource = `
local MutationConfig = {
	Normal = {
		DisplayName = "Normal",
		Weight = 700,
		ValueMultiplier = 1,
		ScaleMultiplier = 1,
		Visual = "Plain",
		Material = Enum.Material.SmoothPlastic,
	},
	Big = {
		DisplayName = "Big",
		Weight = 120,
		ValueMultiplier = 1.5,
		ScaleMultiplier = 1.35,
		Visual = "Scale",
		Material = Enum.Material.SmoothPlastic,
	},
	Tiny = {
		DisplayName = "Tiny",
		Weight = 100,
		ValueMultiplier = 1.25,
		ScaleMultiplier = 0.75,
		Visual = "Scale",
		Material = Enum.Material.SmoothPlastic,
	},
	Golden = {
		DisplayName = "Golden",
		Weight = 80,
		ValueMultiplier = 3,
		Color = Color3.fromRGB(255, 205, 58),
		ScaleMultiplier = 1.05,
		Visual = "Gold",
		Material = Enum.Material.Metal,
	},
	Frozen = {
		DisplayName = "Frozen",
		Weight = 50,
		ValueMultiplier = 2.25,
		Color = Color3.fromRGB(150, 230, 255),
		ScaleMultiplier = 1,
		Visual = "Ice",
		Material = Enum.Material.Glass,
	},
	Rainbow = {
		DisplayName = "Rainbow",
		Weight = 25,
		ValueMultiplier = 8,
		Color = Color3.fromRGB(255, 88, 205),
		ScaleMultiplier = 1.1,
		Visual = "Rainbow",
		Material = Enum.Material.Neon,
	},
	VoidTouched = {
		DisplayName = "Void Touched",
		Weight = 10,
		ValueMultiplier = 15,
		Color = Color3.fromRGB(64, 22, 104),
		ScaleMultiplier = 1.15,
		Visual = "VoidGlow",
		Material = Enum.Material.Neon,
	},
	Glitched = {
		DisplayName = "Glitched",
		Weight = 8,
		ValueMultiplier = 25,
		Color = Color3.fromRGB(80, 255, 190),
		ScaleMultiplier = 1.05,
		Visual = "Glitch",
		Material = Enum.Material.Neon,
	},
}

MutationConfig.Order = {
	"Normal",
	"Big",
	"Tiny",
	"Golden",
	"Frozen",
	"Rainbow",
	"VoidTouched",
	"Glitched",
}

return MutationConfig
`;

const eventConfigSource = `
local EventConfig = {
	SnackRain = {
		DisplayName = "Snack Rain",
		Duration = 45,
		DebugDuration = 20,
		CrumbCount = 20,
		MaxActivePickups = 24,
		CoinReward = 12,
		SeedChance = 0.25,
	},
	MutationSurge = {
		DisplayName = "Mutation Surge",
		Duration = 90,
		DebugDuration = 25,
		RareWeightMultiplier = 2.25,
	},
	VoidInfestation = {
		DisplayName = "Void Infestation",
		Duration = 45,
		DebugDuration = 20,
		RewardMultiplier = 1.35,
		ExtraSpawnPasses = 2,
	},
	GoldenHunger = {
		DisplayName = "Golden Hunger",
		Duration = 120,
		DebugDuration = 30,
		VoidValueMultiplier = 1.75,
		TokenBonus = 3,
		HungerBonus = 18,
	},
}

EventConfig.Order = { "SnackRain", "MutationSurge", "VoidInfestation", "GoldenHunger" }

return EventConfig
`;

const assetReferencesSource = `
local AssetReferences = {
	TheVoid = { "ReplicatedStorage", "Assets", "Models", "Void", "FTW_TheVoid" },
	Voidmite = { "ReplicatedStorage", "Assets", "Models", "Creatures", "FTW_Voidmite" },
	SnackRoundBase = { "ReplicatedStorage", "Assets", "Models", "Snacks", "FTW_Snack_RoundBase" },
	SnackCubeBase = { "ReplicatedStorage", "Assets", "Models", "Snacks", "FTW_Snack_CubeBase" },
	SnackWrapBase = { "ReplicatedStorage", "Assets", "Models", "Snacks", "FTW_Snack_WrapBase" },
	GrowPlate = { "ReplicatedStorage", "Assets", "Models", "Plot", "FTW_GrowPlate" },
	DisplayPedestal = { "ReplicatedStorage", "Assets", "Models", "Plot", "FTW_DisplayPedestal" },
	SeedShopMachine = { "ReplicatedStorage", "Assets", "Models", "Stations", "FTW_SeedShopMachine" },
	SellStation = { "ReplicatedStorage", "Assets", "Models", "Stations", "FTW_SellStation" },
	VoidCrumbPickup = { "ReplicatedStorage", "Assets", "Models", "Pickups", "FTW_VoidCrumbPickup" },
	VoidShardPickup = { "ReplicatedStorage", "Assets", "Models", "Pickups", "FTW_VoidShardPickup" },
}

return AssetReferences
`;

const assetServiceSource = `
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetReferences = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReferences"))

local AssetService = {}

local warnedMissing = {}

local fallback = {
	TheVoid = { Color = Color3.fromRGB(95, 45, 160), Size = Vector3.new(8, 8, 8), Shape = Enum.PartType.Ball, Material = Enum.Material.Neon },
	Voidmite = { Color = Color3.fromRGB(72, 24, 124), Size = Vector3.new(1.4, 1.1, 1.4), Shape = Enum.PartType.Ball, Material = Enum.Material.Neon },
	SnackRoundBase = { Color = Color3.fromRGB(185, 164, 132), Size = Vector3.new(2.6, 2.6, 2.6), Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic },
	SnackCubeBase = { Color = Color3.fromRGB(92, 220, 225), Size = Vector3.new(2.4, 2.4, 2.4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SnackWrapBase = { Color = Color3.fromRGB(255, 158, 204), Size = Vector3.new(3, 1.4, 1.6), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	GrowPlate = { Color = Color3.fromRGB(80, 92, 110), Size = Vector3.new(5, 0.4, 5), Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal },
	DisplayPedestal = { Color = Color3.fromRGB(70, 64, 90), Size = Vector3.new(4, 1.2, 4), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SeedShopMachine = { Color = Color3.fromRGB(56, 128, 84), Size = Vector3.new(5, 5, 3), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	SellStation = { Color = Color3.fromRGB(64, 118, 170), Size = Vector3.new(5, 4, 3), Shape = Enum.PartType.Block, Material = Enum.Material.SmoothPlastic },
	VoidCrumbPickup = { Color = Color3.fromRGB(255, 180, 80), Size = Vector3.new(1.3, 1.3, 1.3), Shape = Enum.PartType.Ball, Material = Enum.Material.Neon },
	VoidShardPickup = { Color = Color3.fromRGB(155, 105, 255), Size = Vector3.new(1.1, 1.6, 1.1), Shape = Enum.PartType.Block, Material = Enum.Material.Neon },
}

local function findByPath(pathParts)
	local current = game
	for _, partName in ipairs(pathParts or {}) do
		current = current:FindFirstChild(partName)
		if not current then
			return nil
		end
	end
	return current
end

local function largestBasePart(model)
	local best = nil
	local bestVolume = -1
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			local volume = child.Size.X * child.Size.Y * child.Size.Z
			if volume > bestVolume then
				best = child
				bestVolume = volume
			end
		end
	end
	return best
end

local function wrapBasePart(part, modelName)
	local model = Instance.new("Model")
	model.Name = modelName or part.Name
	part.Parent = model
	model.PrimaryPart = part
	return model
end

function AssetService.Init(context)
	AssetService.Context = context
end

function AssetService.Start()
	AssetService.MountImportedAsset("TheVoid", "Workspace.GameWorld.CentralVoid.VoidCore", 1)
end

function AssetService.HasAsset(assetKey)
	local ref = AssetReferences[assetKey]
	return ref and findByPath(ref) ~= nil or false
end

function AssetService.GetModel(assetKey)
	local ref = AssetReferences[assetKey]
	return ref and findByPath(ref) or nil
end

function AssetService.EnsurePrimaryPart(model)
	if model:IsA("BasePart") then
		return model
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best = largestBasePart(model)
	if best then
		model.PrimaryPart = best
	end
	return best
end

function AssetService.SetModelCFrame(model, cframe)
	if not model then
		return
	end
	if model:IsA("BasePart") then
		model.CFrame = cframe
		return
	end
	AssetService.EnsurePrimaryPart(model)
	model:PivotTo(cframe)
end

function AssetService.ScaleModelSafely(model, scale)
	scale = tonumber(scale) or 1
	if not model then
		return
	end
	if model:IsA("BasePart") then
		model.Size *= scale
		return
	end
	local ok = pcall(function()
		model:ScaleTo(scale)
	end)
	if not ok then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Size *= scale
			end
		end
	end
end

function AssetService.ApplyMutationVisual(model, mutationId, snackColor)
	local mutation = AssetService.Context and AssetService.Context.Config.MutationConfig[mutationId or "Normal"] or nil
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Color = (mutation and mutation.Color) or snackColor or child.Color
			child.Material = (mutation and mutation.Material) or child.Material
			if mutationId == "VoidTouched" then
				local light = Instance.new("PointLight")
				light.Name = "VoidSnackGlow"
				light.Brightness = 1
				light.Range = 10
				light.Color = Color3.fromRGB(170, 80, 255)
				light.Parent = child
			elseif mutationId == "Glitched" then
				local light = Instance.new("PointLight")
				light.Name = "GlitchGlow"
				light.Brightness = 0.7
				light.Range = 7
				light.Color = Color3.fromRGB(80, 255, 190)
				light.Parent = child
			elseif mutationId == "Rainbow" then
				child.Color = Color3.fromRGB(255, 90, 205)
			end
		end
	end
end

function AssetService.AddBillboard(model, text, studsOffset)
	local part = AssetService.EnsurePrimaryPart(model)
	if not part then
		return nil
	end
	local old = part:FindFirstChild("FTVBillboard")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "FTVBillboard"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 190, 0, 58)
	gui.StudsOffset = studsOffset or Vector3.new(0, 2.8, 0)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 0.18
	label.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.TextColor3 = Color3.fromRGB(255, 246, 210)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return gui
end

function AssetService.AddProximityPrompt(modelOrPart, promptText, actionText)
	local part = modelOrPart:IsA("BasePart") and modelOrPart or AssetService.EnsurePrimaryPart(modelOrPart)
	if not part then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = actionText:gsub("%s+", "") .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = promptText
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
	return prompt
end

function AssetService.CreateFallback(assetKey)
	local config = fallback[assetKey] or fallback.SnackRoundBase
	local part = Instance.new("Part")
	part.Name = assetKey .. "FallbackPart"
	part.Anchored = true
	part.CanCollide = false
	part.Shape = config.Shape or Enum.PartType.Block
	part.Material = config.Material or Enum.Material.SmoothPlastic
	part.Color = config.Color or Color3.fromRGB(180, 180, 180)
	part.Size = config.Size or Vector3.new(2, 2, 2)
	return wrapBasePart(part, assetKey .. "Fallback")
end

function AssetService.CloneModel(assetKey)
	local asset = AssetService.GetModel(assetKey)
	if asset then
		local clone = asset:Clone()
		if clone:IsA("BasePart") then
			clone.Anchored = true
			clone.CanCollide = false
			clone = wrapBasePart(clone, assetKey)
		end
		for _, child in ipairs(clone:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Anchored = true
				child.CanCollide = false
			end
		end
		AssetService.EnsurePrimaryPart(clone)
		return clone, true
	end
	if not warnedMissing[assetKey] then
		warnedMissing[assetKey] = true
		warn("[FEED THE VOID] Missing imported asset " .. tostring(assetKey) .. "; using fallback.")
	end
	return AssetService.CreateFallback(assetKey), false
end

function AssetService.MountImportedAsset(assetKey, anchorPath, scale)
	if not AssetService.HasAsset(assetKey) then
		return nil
	end
	local anchor = findByPath(string.split(anchorPath, "."))
	if not anchor then
		return nil
	end
	local parent = anchor.Parent
	local model = AssetService.CloneModel(assetKey)
	model.Name = assetKey .. "_Imported"
	model.Parent = parent
	AssetService.SetModelCFrame(model, anchor:IsA("BasePart") and anchor.CFrame or anchor:GetPivot())
	AssetService.ScaleModelSafely(model, scale or 1)
	if anchor:IsA("BasePart") then
		anchor.Transparency = 1
		anchor.CanCollide = false
	end
	return model
end

return AssetService
`;

const upgradeServiceSource = `
local UpgradeService = {}

local upgradeKeys = {
	ExtraPlate = "Plates",
	GrowSpeed = "GrowSpeed",
	SellMultiplier = "SellMultiplier",
	VoidRewardMultiplier = "VoidRewardMultiplier",
	DisplayIncome = "DisplayIncome",
	VoidmiteReward = "VoidmiteReward",
}

function UpgradeService.Init(context)
	UpgradeService.Context = context
end

function UpgradeService.Start() end

local function rawUpgradeData(player)
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	data.Upgrades = data.Upgrades or {}
	return data, data.Upgrades
end

function UpgradeService.GetDefinition(upgradeId)
	return UpgradeService.Context.Config.GameConfig.UpgradeConfig[upgradeId]
end

function UpgradeService.GetLevel(player, upgradeId)
	local data, upgrades = rawUpgradeData(player)
	if not data then
		return 0
	end
	if upgradeId == "ExtraPlate" then
		return math.max(0, (tonumber(upgrades.Plates) or UpgradeService.Context.Config.GameConfig.PlateCount) - UpgradeService.Context.Config.GameConfig.PlateCount)
	end
	return math.max(0, tonumber(upgrades[upgradeKeys[upgradeId] or upgradeId]) or 0)
end

function UpgradeService.GetPlateCount(player)
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	local count = data and data.Upgrades and tonumber(data.Upgrades.Plates) or UpgradeService.Context.Config.GameConfig.PlateCount
	return math.clamp(count, UpgradeService.Context.Config.GameConfig.PlateCount, UpgradeService.Context.Config.GameConfig.MaxPlateCount)
end

function UpgradeService.GetMultiplier(player, upgradeId)
	local definition = UpgradeService.GetDefinition(upgradeId)
	local level = UpgradeService.GetLevel(player, upgradeId)
	local rebirthBoost = 1
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	if upgradeId == "SellMultiplier" or upgradeId == "VoidRewardMultiplier" or upgradeId == "DisplayIncome" then
		rebirthBoost = 1 + ((data and tonumber(data.Rebirths) or 0) * UpgradeService.Context.Config.GameConfig.RebirthBoostPerRebirth)
	end
	if not definition then
		return rebirthBoost
	end
	return rebirthBoost * (1 + (level * (definition.PerLevel or 0)))
end

function UpgradeService.GetCost(player, upgradeId)
	local definition = UpgradeService.GetDefinition(upgradeId)
	if not definition then
		return 0
	end
	local level = UpgradeService.GetLevel(player, upgradeId)
	return math.floor(definition.BaseCost * ((level + 1) ^ 2))
end

function UpgradeService.Serialize(player)
	local config = UpgradeService.Context.Config.GameConfig
	local data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
	local upgrades = data and data.Upgrades or {}
	local result = {
		Plates = UpgradeService.GetPlateCount(player),
		GrowSpeed = tonumber(upgrades.GrowSpeed) or 0,
		SellMultiplier = tonumber(upgrades.SellMultiplier) or 0,
		VoidRewardMultiplier = tonumber(upgrades.VoidRewardMultiplier) or 0,
		DisplayIncome = tonumber(upgrades.DisplayIncome) or 0,
		VoidmiteReward = tonumber(upgrades.VoidmiteReward) or 0,
		Items = {},
	}
	for _, upgradeId in ipairs(config.UpgradeOrder) do
		local definition = config.UpgradeConfig[upgradeId]
		local level = UpgradeService.GetLevel(player, upgradeId)
		table.insert(result.Items, {
			Id = upgradeId,
			DisplayName = definition.DisplayName,
			Description = definition.Description,
			Level = level,
			MaxLevel = definition.MaxLevel,
			Cost = UpgradeService.GetCost(player, upgradeId),
			Multiplier = UpgradeService.GetMultiplier(player, upgradeId),
		})
	end
	return result
end

function UpgradeService.BuyUpgrade(player, upgradeId)
	local context = UpgradeService.Context
	local definition = UpgradeService.GetDefinition(upgradeId)
	if not definition then
		context.Services.EconomyService.Notify(player, "That upgrade is not available.")
		return false
	end
	local data, upgrades = rawUpgradeData(player)
	if not data then
		return false
	end
	local level = UpgradeService.GetLevel(player, upgradeId)
	if level >= definition.MaxLevel then
		context.Services.EconomyService.Notify(player, definition.DisplayName .. " is max level.")
		return false
	end
	local cost = UpgradeService.GetCost(player, upgradeId)
	if not context.Services.EconomyService.SpendCoins(player, cost) then
		context.Services.EconomyService.Notify(player, "Not enough coins for " .. definition.DisplayName .. ".")
		return false
	end
	if upgradeId == "ExtraPlate" then
		upgrades.Plates = math.min(context.Config.GameConfig.MaxPlateCount, UpgradeService.GetPlateCount(player) + 1)
	else
		upgrades[upgradeKeys[upgradeId] or upgradeId] = level + 1
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.QuestService.Record(player, "BuyUpgrade", 1)
	context.Services.EconomyService.Notify(player, "Upgrade bought: " .. definition.DisplayName .. "!")
	context.Services.EconomyService.Sync(player)
	return true
end

return UpgradeService
`;

const collectionServiceSource = `
local CollectionService = {}

local rareMutations = {
	Golden = true,
	Rainbow = true,
	VoidTouched = true,
	Glitched = true,
}

local function countKeys(map)
	local count = 0
	for _, unlocked in pairs(map or {}) do
		if unlocked then
			count += 1
		end
	end
	return count
end

local function ensure(data)
	data.Collections = data.Collections or {}
	data.Collections.Snacks = data.Collections.Snacks or {}
	data.Collections.Mutations = data.Collections.Mutations or {}
	data.Collections.Combos = data.Collections.Combos or {}
	data.Collections.RewardClaims = data.Collections.RewardClaims or {}
	return data.Collections
end

function CollectionService.Init(context)
	CollectionService.Context = context
end

function CollectionService.Start() end

function CollectionService.Ensure(player)
	local data = CollectionService.Context.Services.ProfileServiceWrapper.GetData(player)
	return data and ensure(data) or nil
end

function CollectionService.Serialize(player)
	local context = CollectionService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local collections = data and ensure(data) or { Snacks = {}, Mutations = {}, Combos = {} }
	local snackList = {}
	for _, snackId in ipairs(context.Config.SnackConfig.Order) do
		local snack = context.Config.SnackConfig[snackId]
		table.insert(snackList, {
			Id = snackId,
			Name = collections.Snacks[snackId] and snack.DisplayName or "???",
			Unlocked = collections.Snacks[snackId] == true,
		})
	end
	local mutationList = {}
	for _, mutationId in ipairs(context.Config.MutationConfig.Order) do
		local mutation = context.Config.MutationConfig[mutationId]
		table.insert(mutationList, {
			Id = mutationId,
			Name = collections.Mutations[mutationId] and mutation.DisplayName or "???",
			Unlocked = collections.Mutations[mutationId] == true,
		})
	end
	return {
		SnacksDiscovered = countKeys(collections.Snacks),
		SnacksTotal = #context.Config.SnackConfig.Order,
		MutationsDiscovered = countKeys(collections.Mutations),
		MutationsTotal = #context.Config.MutationConfig.Order,
		CombosDiscovered = countKeys(collections.Combos),
		CombosTotal = #context.Config.SnackConfig.Order * #context.Config.MutationConfig.Order,
		SnackList = snackList,
		MutationList = mutationList,
	}
end

local function claimMilestone(context, player, collections, key, condition, reward)
	if collections.RewardClaims[key] or not condition then
		return
	end
	collections.RewardClaims[key] = true
	if reward.Coins then
		context.Services.EconomyService.AddCoins(player, reward.Coins)
	end
	if reward.VoidTokens then
		context.Services.EconomyService.AddVoidTokens(player, reward.VoidTokens)
	end
	context.Services.EconomyService.Notify(player, reward.Message)
end

function CollectionService.MarkHarvest(player, item)
	local context = CollectionService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data or not item then
		return
	end
	local collections = ensure(data)
	local snackId = item.SnackId
	local mutationId = item.MutationId or "Normal"
	local comboId = snackId .. "_" .. mutationId
	local firstDiscovery = false
	if not collections.Snacks[snackId] then
		collections.Snacks[snackId] = true
		firstDiscovery = true
	end
	if not collections.Mutations[mutationId] then
		collections.Mutations[mutationId] = true
		firstDiscovery = true
		context.Services.QuestService.Record(player, "DiscoverMutation", 1)
	end
	if not collections.Combos[comboId] then
		collections.Combos[comboId] = true
		firstDiscovery = true
	end
	if firstDiscovery then
		context.Services.EconomyService.AddCoins(player, 20)
		if rareMutations[mutationId] then
			context.Services.EconomyService.AddVoidTokens(player, 1)
		end
		context.Services.EconomyService.Notify(player, "New discovery: " .. tostring(item.DisplayName) .. "!")
	end
	claimMilestone(context, player, collections, "Snacks3", countKeys(collections.Snacks) >= 3, { Coins = 100, Message = "Collection reward: 3 snack types discovered! +100 coins." })
	claimMilestone(context, player, collections, "Mutations5", countKeys(collections.Mutations) >= 5, { Coins = 250, Message = "Collection reward: 5 mutations discovered! +250 coins." })
	claimMilestone(context, player, collections, "Combos10", countKeys(collections.Combos) >= 10, { VoidTokens = 5, Message = "Collection reward: 10 combos discovered! +5 Void Tokens." })
	if mutationId == "VoidTouched" then
		context.Services.EconomyService.NotifyAll(player.Name .. " discovered a Void Touched snack!")
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
end

return CollectionService
`;

const questServiceSource = `
local HttpService = game:GetService("HttpService")

local QuestService = {}

local questDefinitions = {
	{ Type = "Plant", Text = "Plant snacks", Target = 3, Coins = 60 },
	{ Type = "Harvest", Text = "Harvest snacks", Target = 3, Coins = 90 },
	{ Type = "FeedVoid", Text = "Feed the Void", Target = 2, VoidTokens = 2 },
	{ Type = "Sell", Text = "Sell snacks", Target = 2, Coins = 80 },
	{ Type = "Display", Text = "Display a snack", Target = 1, Coins = 75 },
	{ Type = "CleanseVoidmite", Text = "Cleanse Voidmites", Target = 3, Coins = 120, VoidTokens = 1 },
	{ Type = "BuyUpgrade", Text = "Buy an upgrade", Target = 1, Coins = 100 },
	{ Type = "CollectCrumb", Text = "Collect SnackRain crumbs", Target = 5, Coins = 100, Seeds = { CookieRock = 1 } },
	{ Type = "DiscoverMutation", Text = "Discover a mutation", Target = 1, VoidTokens = 2 },
}

local function ensure(data)
	data.Quests = data.Quests or {}
	data.Quests.Active = data.Quests.Active or {}
	data.Quests.CompletedCount = tonumber(data.Quests.CompletedCount) or 0
	return data.Quests
end

local function cloneQuest(definition)
	return {
		Id = HttpService:GenerateGUID(false),
		Type = definition.Type,
		Text = definition.Text,
		Target = definition.Target,
		Progress = 0,
		Coins = definition.Coins or 0,
		VoidTokens = definition.VoidTokens or 0,
		Seeds = definition.Seeds,
	}
end

local function randomQuest(existing)
	local used = {}
	for _, quest in ipairs(existing or {}) do
		used[quest.Type] = true
	end
	local pool = {}
	for _, definition in ipairs(questDefinitions) do
		if not used[definition.Type] then
			table.insert(pool, definition)
		end
	end
	if #pool == 0 then
		pool = questDefinitions
	end
	return cloneQuest(pool[math.random(1, #pool)])
end

function QuestService.Init(context)
	QuestService.Context = context
end

function QuestService.Start() end

function QuestService.Ensure(player)
	local data = QuestService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return nil
	end
	local quests = ensure(data)
	while #quests.Active < 3 do
		table.insert(quests.Active, randomQuest(quests.Active))
	end
	return quests
end

function QuestService.Serialize(player)
	local quests = QuestService.Ensure(player)
	if not quests then
		return { Active = {}, CompletedCount = 0 }
	end
	local active = {}
	for _, quest in ipairs(quests.Active) do
		table.insert(active, {
			Id = quest.Id,
			Type = quest.Type,
			Text = quest.Text,
			Progress = math.min(quest.Progress or 0, quest.Target or 1),
			Target = quest.Target or 1,
		})
	end
	return {
		Active = active,
		CompletedCount = quests.CompletedCount or 0,
	}
end

function QuestService.Record(player, questType, amount)
	local context = QuestService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	local quests = QuestService.Ensure(player)
	local completedAny = false
	for index = #quests.Active, 1, -1 do
		local quest = quests.Active[index]
		if quest.Type == questType then
			quest.Progress = math.min((quest.Progress or 0) + (amount or 1), quest.Target or 1)
			if quest.Progress >= quest.Target then
				if quest.Coins and quest.Coins > 0 then
					context.Services.EconomyService.AddCoins(player, quest.Coins)
				end
				if quest.VoidTokens and quest.VoidTokens > 0 then
					context.Services.EconomyService.AddVoidTokens(player, quest.VoidTokens)
				end
				for seedId, count in pairs(quest.Seeds or {}) do
					context.Services.EconomyService.AddSeeds(player, seedId, count, false)
				end
				context.Services.EconomyService.Notify(player, "Objective complete: " .. quest.Text .. "!")
				table.remove(quests.Active, index)
				quests.CompletedCount = (quests.CompletedCount or 0) + 1
				completedAny = true
			end
		end
	end
	while #quests.Active < 3 do
		table.insert(quests.Active, randomQuest(quests.Active))
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Sync(player)
	return completedAny
end

return QuestService
`;

const tutorialServiceSource = `
local TutorialService = {}

local maxStep = 8

function TutorialService.Init(context)
	TutorialService.Context = context
end

function TutorialService.Start() end

function TutorialService.SendStep(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data or (data.TutorialStep or 1) > maxStep then
		return
	end
	local message = TutorialService.Context.Config.GameConfig.TutorialMessages[data.TutorialStep]
	if message then
		TutorialService.Context.Services.EconomyService.Notify(player, message)
	end
end

function TutorialService.Advance(player, targetStep)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data or (data.TutorialStep or 1) > maxStep then
		return
	end
	if targetStep and (data.TutorialStep or 1) < targetStep then
		data.TutorialStep = targetStep
	elseif not targetStep then
		data.TutorialStep += 1
	end
	if data.TutorialStep > maxStep then
		TutorialService.Context.Services.EconomyService.Notify(player, "Tutorial complete. Feed the Void your weirdest snacks.")
	else
		TutorialService.SendStep(player)
	end
	TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	TutorialService.Context.Services.EconomyService.Sync(player)
end

function TutorialService.RecordAction(player, action)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	local step = data.TutorialStep or 1
	if action == "Plant" and step <= 2 then
		TutorialService.Advance(player, 3)
	elseif action == "Harvest" and step <= 3 then
		TutorialService.Advance(player, 4)
	elseif (action == "Sell" or action == "FeedVoid") and step <= 5 then
		TutorialService.Advance(player, 6)
	elseif action == "Display" and step <= 6 then
		TutorialService.Advance(player, 7)
	elseif action == "CleanseVoidmite" and step <= 7 then
		TutorialService.Advance(player, 8)
	elseif action == "FeedVoid" and step <= 8 then
		TutorialService.Advance(player, 9)
	end
end

function TutorialService.Skip(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	data.TutorialStep = maxStep + 1
	TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	TutorialService.Context.Services.EconomyService.Notify(player, "Tutorial skipped.")
	TutorialService.Context.Services.EconomyService.Sync(player)
end

return TutorialService
`;

const profileServiceSource = `
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ProfileServiceWrapper = {}

local profiles = {}
local dirty = {}
local dataStore = nil
local warnedMemoryFallback = false

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function mergeDefaults(data, defaults)
	data = type(data) == "table" and data or {}
	for key, value in pairs(defaults) do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" then
			data[key] = mergeDefaults(data[key], value)
		end
	end
	return data
end

local function migrateUpgradeLevel(value, perLevel)
	value = tonumber(value) or 0
	if value <= 0 then
		return 0
	end
	if value > 0 and value <= 1 then
		return 0
	end
	if value > 1 and value < 4 then
		return math.clamp(math.floor(((value - 1) / perLevel) + 0.5), 0, 10)
	end
	return math.clamp(math.floor(value), 0, 10)
end

local function defaultData(context)
	local gameConfig = context.Config.GameConfig
	return {
		Coins = gameConfig.StartingCoins,
		VoidTokens = 0,
		Rebirths = 0,
		Seeds = deepCopy(gameConfig.StartingSeeds),
		Inventory = {},
		DisplayedSnacks = {},
		Upgrades = {
			Plates = gameConfig.PlateCount,
			GrowSpeed = 0,
			SellMultiplier = 0,
			VoidRewardMultiplier = 0,
			DisplayIncome = 0,
			VoidmiteReward = 0,
		},
		Collections = {
			Snacks = {},
			Mutations = {},
			Combos = {},
			RewardClaims = {},
		},
		Quests = {
			Active = {},
			CompletedCount = 0,
		},
		TutorialStep = 1,
		LastLogout = 0,
	}
end

local function migrateData(context, data)
	data = mergeDefaults(data, defaultData(context))
	local gameConfig = context.Config.GameConfig
	local old = type(data.Upgrades) == "table" and data.Upgrades or {}
	data.Upgrades = {
		Plates = math.clamp(tonumber(old.Plates) or gameConfig.PlateCount, gameConfig.PlateCount, gameConfig.MaxPlateCount),
		GrowSpeed = migrateUpgradeLevel(old.GrowSpeed, 0.05),
		SellMultiplier = migrateUpgradeLevel(old.SellMultiplier, 0.10),
		VoidRewardMultiplier = migrateUpgradeLevel(old.VoidRewardMultiplier, 0.10),
		DisplayIncome = migrateUpgradeLevel(old.DisplayIncome, 0.10),
		VoidmiteReward = migrateUpgradeLevel(old.VoidmiteReward, 0.10),
	}
	data.Collections = data.Collections or {}
	data.Collections.Snacks = data.Collections.Snacks or {}
	data.Collections.Mutations = data.Collections.Mutations or {}
	data.Collections.Combos = data.Collections.Combos or {}
	data.Collections.RewardClaims = data.Collections.RewardClaims or {}
	data.Quests = data.Quests or { Active = {}, CompletedCount = 0 }
	data.Quests.Active = type(data.Quests.Active) == "table" and data.Quests.Active or {}
	data.Quests.CompletedCount = tonumber(data.Quests.CompletedCount) or 0
	data.Inventory = type(data.Inventory) == "table" and data.Inventory or {}
	data.DisplayedSnacks = type(data.DisplayedSnacks) == "table" and data.DisplayedSnacks or {}
	data.Seeds = type(data.Seeds) == "table" and data.Seeds or deepCopy(gameConfig.StartingSeeds)
	data.TutorialStep = tonumber(data.TutorialStep) or 1
	data.LastLogout = tonumber(data.LastLogout) or 0
	return data
end

local function profileKey(player)
	return "player_" .. tostring(player.UserId)
end

function ProfileServiceWrapper.Init(context)
	ProfileServiceWrapper.Context = context
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore("FeedTheVoid_Phase15_v1")
	end)
	if ok then
		dataStore = storeOrError
	else
		warn("[FEED THE VOID] DataStore unavailable; using memory profiles. " .. tostring(storeOrError))
	end
end

function ProfileServiceWrapper.Start()
	task.spawn(function()
		while true do
			task.wait(60)
			ProfileServiceWrapper.SaveAll()
		end
	end)
	game:BindToClose(function()
		ProfileServiceWrapper.SaveAll()
	end)
end

function ProfileServiceWrapper.LoadPlayer(player)
	local data = nil
	if dataStore then
		local ok, result = pcall(function()
			return dataStore:GetAsync(profileKey(player))
		end)
		if ok then
			data = result
		else
			if not warnedMemoryFallback then
				print("[FEED THE VOID] DataStore load failed; continuing with memory data. Enable Studio API access to test persistence.", result)
				warnedMemoryFallback = true
			end
		end
	end
	data = migrateData(ProfileServiceWrapper.Context, data)
	data.LastLogout = os.time()
	profiles[player] = {
		Data = data,
		LoadedAt = os.time(),
	}
	dirty[player] = false
	return profiles[player]
end

function ProfileServiceWrapper.GetProfile(player)
	return profiles[player]
end

function ProfileServiceWrapper.GetData(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function ProfileServiceWrapper.MarkDirty(player)
	if profiles[player] then
		dirty[player] = true
	end
end

function ProfileServiceWrapper.SavePlayer(player)
	local profile = profiles[player]
	if not profile then
		return true
	end
	profile.Data.LastLogout = os.time()
	if not dataStore then
		dirty[player] = false
		return true
	end
	if not dirty[player] then
		return true
	end
	local ok, err = pcall(function()
		dataStore:SetAsync(profileKey(player), profile.Data)
	end)
	if ok then
		dirty[player] = false
		return true
	end
	print("[FEED THE VOID] DataStore save failed; session data remains in memory.", err)
	return false
end

function ProfileServiceWrapper.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		ProfileServiceWrapper.SavePlayer(player)
	end
end

function ProfileServiceWrapper.ReleasePlayer(player)
	ProfileServiceWrapper.SavePlayer(player)
	profiles[player] = nil
	dirty[player] = nil
end

return ProfileServiceWrapper
`;

const economyServiceSource = `
local Players = game:GetService("Players")

local EconomyService = {}

local function copyDictionary(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

function EconomyService.Init(context)
	EconomyService.Context = context
end

function EconomyService.Start() end

function EconomyService.GetData(player)
	return EconomyService.Context.Services.ProfileServiceWrapper.GetData(player)
end

function EconomyService.ComputeItemValues(player, item)
	if not item then
		return 0, 0, 0
	end
	local context = EconomyService.Context
	local snack = context.Config.SnackConfig[item.SnackId]
	local mutation = context.Config.MutationConfig[item.MutationId or "Normal"] or context.Config.MutationConfig.Normal
	if not snack or not mutation then
		return 0, 0, 0
	end
	local sellMultiplier = player and context.Services.UpgradeService.GetMultiplier(player, "SellMultiplier") or 1
	local voidMultiplier = player and context.Services.UpgradeService.GetMultiplier(player, "VoidRewardMultiplier") or 1
	local displayMultiplier = player and context.Services.UpgradeService.GetMultiplier(player, "DisplayIncome") or 1
	local mutationMultiplier = item.ValueMultiplier or mutation.ValueMultiplier or 1
	local sellValue = math.max(1, math.floor(snack.BaseSellValue * mutationMultiplier * sellMultiplier))
	local voidValue = math.max(1, math.floor(snack.BaseVoidValue * mutationMultiplier * voidMultiplier))
	local passiveIncome = math.max(1, math.floor((snack.BaseSellValue * mutationMultiplier * displayMultiplier) / 10))
	return sellValue, voidValue, passiveIncome
end

function EconomyService.SerializeItem(player, item)
	if not item then
		return nil
	end
	local sellValue, voidValue, passiveIncome = EconomyService.ComputeItemValues(player, item)
	local snack = EconomyService.Context.Config.SnackConfig[item.SnackId]
	local mutation = EconomyService.Context.Config.MutationConfig[item.MutationId or "Normal"]
	local copy = copyDictionary(item)
	copy.DisplayName = item.DisplayName or ((mutation and mutation.DisplayName ~= "Normal" and mutation.DisplayName .. " " or "") .. (snack and snack.DisplayName or item.SnackId))
	copy.SnackName = snack and snack.DisplayName or item.SnackId
	copy.MutationName = mutation and mutation.DisplayName or item.MutationId or "Normal"
	copy.EstimatedSellValue = sellValue
	copy.EstimatedVoidValue = voidValue
	copy.PassiveIncome = passiveIncome
	return copy
end

function EconomyService.BuildSnapshot(player)
	local data = EconomyService.GetData(player)
	if not data then
		return nil
	end
	local inventory = {}
	for _, item in ipairs(data.Inventory or {}) do
		table.insert(inventory, EconomyService.SerializeItem(player, item))
	end
	local displayed = {}
	for _, item in ipairs(data.DisplayedSnacks or {}) do
		table.insert(displayed, EconomyService.SerializeItem(player, item))
	end
	return {
		Coins = data.Coins or 0,
		VoidTokens = data.VoidTokens or 0,
		Rebirths = data.Rebirths or 0,
		Seeds = copyDictionary(data.Seeds or {}),
		Inventory = inventory,
		DisplayedSnacks = displayed,
		Upgrades = EconomyService.Context.Services.UpgradeService.Serialize(player),
		Collections = EconomyService.Context.Services.CollectionService.Serialize(player),
		Quests = EconomyService.Context.Services.QuestService.Serialize(player),
		TutorialStep = data.TutorialStep or 1,
		VoidHunger = EconomyService.Context.Services.VoidService.GetHunger(),
		VoidHungerRequired = EconomyService.Context.Services.VoidService.GetRequired(),
		ActiveEventName = EconomyService.Context.Services.EventService.GetActiveEventName(),
		ActiveEventEndsAt = EconomyService.Context.Services.EventService.GetActiveEventEndsAt(),
		GoldenHungerSnackId = EconomyService.Context.Services.EventService.GetGoldenHungerSnackId(),
	}
end

function EconomyService.Sync(player)
	local snapshot = EconomyService.BuildSnapshot(player)
	if snapshot then
		EconomyService.Context.Remotes.SyncPlayerData:FireClient(player, snapshot)
	end
end

function EconomyService.SyncAll()
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.Sync(player)
	end
end

function EconomyService.Notify(player, message)
	if player and message then
		EconomyService.Context.Remotes.NotifyClient:FireClient(player, tostring(message))
	end
end

function EconomyService.NotifyAll(message)
	if message then
		EconomyService.Context.Remotes.NotifyClient:FireAllClients(tostring(message))
	end
end

function EconomyService.AddCoins(player, amount)
	local data = EconomyService.GetData(player)
	if not data then
		return false
	end
	data.Coins += math.max(0, math.floor(amount or 0))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.SpendCoins(player, amount)
	local data = EconomyService.GetData(player)
	amount = math.max(0, math.floor(amount or 0))
	if not data or (data.Coins or 0) < amount then
		return false
	end
	data.Coins -= amount
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.AddVoidTokens(player, amount)
	local data = EconomyService.GetData(player)
	if not data then
		return false
	end
	data.VoidTokens += math.max(0, math.floor(amount or 0))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	EconomyService.Sync(player)
	return true
end

function EconomyService.AddSeeds(player, snackId, amount, notify)
	local data = EconomyService.GetData(player)
	local snack = EconomyService.Context.Config.SnackConfig[snackId]
	if not data or not snack then
		return false
	end
	data.Seeds[snackId] = (data.Seeds[snackId] or 0) + math.max(0, math.floor(amount or 0))
	EconomyService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	if notify ~= false then
		EconomyService.Notify(player, "+" .. tostring(amount) .. " " .. snack.DisplayName .. " seed.")
	end
	EconomyService.Sync(player)
	return true
end

return EconomyService
`;

const inventoryServiceSource = `
local HttpService = game:GetService("HttpService")

local InventoryService = {}

function InventoryService.Init(context)
	InventoryService.Context = context
end

function InventoryService.Start() end

function InventoryService.GetData(player)
	return InventoryService.Context.Services.ProfileServiceWrapper.GetData(player)
end

function InventoryService.AddItem(player, item)
	local data = InventoryService.GetData(player)
	if not data then
		return nil
	end
	item.UniqueId = item.UniqueId or HttpService:GenerateGUID(false)
	table.insert(data.Inventory, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.FindItem(player, itemId)
	local data = InventoryService.GetData(player)
	if not data then
		return nil, nil
	end
	if itemId == nil or itemId == "" then
		return data.Inventory[1], 1
	end
	for index, item in ipairs(data.Inventory) do
		if item.UniqueId == itemId then
			return item, index
		end
	end
	return nil, nil
end

function InventoryService.RemoveItem(player, itemId)
	local data = InventoryService.GetData(player)
	local item, index = InventoryService.FindItem(player, itemId)
	if not data or not item or not index then
		return nil
	end
	table.remove(data.Inventory, index)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.AddDisplayed(player, item)
	local data = InventoryService.GetData(player)
	if not data then
		return nil
	end
	item.UniqueId = item.UniqueId or HttpService:GenerateGUID(false)
	table.insert(data.DisplayedSnacks, item)
	InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	InventoryService.Context.Services.EconomyService.Sync(player)
	return item
end

function InventoryService.ClearInventory(player)
	local data = InventoryService.GetData(player)
	if data then
		data.Inventory = {}
		InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
end

function InventoryService.ClearDisplayed(player)
	local data = InventoryService.GetData(player)
	if data then
		data.DisplayedSnacks = {}
		InventoryService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	end
end

return InventoryService
`;

const shopServiceSource = `
local ShopService = {}

function ShopService.Init(context)
	ShopService.Context = context
end

function ShopService.Start() end

function ShopService.BuySeed(player, snackId)
	local context = ShopService.Context
	local okProfile, data = context.Services.ValidationService.ValidatePlayerProfile(player)
	local snack = context.Config.SnackConfig[snackId]
	if not okProfile or not snack then
		context.Services.EconomyService.Notify(player, "That seed is not available.")
		return false
	end
	local station = context.Services.PlotService.GetStation(player, "SeedShopStation")
	if station and not context.Services.ValidationService.ValidateDistance(player, station, 34) then
		context.Services.EconomyService.Notify(player, "Stand near your Seed Shop to buy seeds.")
		return false
	end
	if not context.Services.EconomyService.SpendCoins(player, snack.SeedCost) then
		context.Services.EconomyService.Notify(player, "Not enough coins for " .. snack.DisplayName .. ".")
		return false
	end
	data.Seeds[snackId] = (data.Seeds[snackId] or 0) + 1
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.QuestService.Record(player, "BuySeed", 1)
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "Bought 1 " .. snack.DisplayName .. " seed.")
	return true
end

return ShopService
`;

const rebirthServiceSource = `
local RebirthService = {}

function RebirthService.Init(context)
	RebirthService.Context = context
end

function RebirthService.Start() end

local function copyStartingSeeds(context)
	local seeds = {}
	for seedId, count in pairs(context.Config.GameConfig.StartingSeeds) do
		seeds[seedId] = count
	end
	return seeds
end

function RebirthService.TryRebirth(player)
	local context = RebirthService.Context
	local okProfile, data = context.Services.ValidationService.ValidatePlayerProfile(player)
	if not okProfile then
		return false
	end
	local cost = context.Config.GameConfig.RebirthRequirement or context.Config.GameConfig.RebirthCost
	if (data.Coins or 0) < cost then
		context.Services.EconomyService.Notify(player, "Rebirth requires " .. tostring(cost) .. " coins.")
		return false
	end
	context.Services.SnackService.ClearPlotVisuals(player)
	context.Services.VoidmiteService.ClearForPlayer(player)
	data.Rebirths = (data.Rebirths or 0) + 1
	data.Coins = context.Config.GameConfig.StartingCoins
	data.Seeds = copyStartingSeeds(context)
	data.Inventory = {}
	data.DisplayedSnacks = {}
	data.Upgrades = {
		Plates = context.Config.GameConfig.PlateCount,
		GrowSpeed = 0,
		SellMultiplier = 0,
		VoidRewardMultiplier = 0,
		DisplayIncome = 0,
		VoidmiteReward = 0,
	}
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.EconomyService.Notify(player, "Rebirth complete. Permanent boost is now +" .. tostring(math.floor(data.Rebirths * context.Config.GameConfig.RebirthBoostPerRebirth * 100)) .. "%.")
	context.Services.AnalyticsService.Rebirth(player, data.Rebirths)
	context.Services.EconomyService.Sync(player)
	return true
end

return RebirthService
`;

const eventServiceSource = `
local Players = game:GetService("Players")

local EventService = {}

local activeEventName = nil
local activeEventEndsAt = 0
local activeToken = 0
local goldenHungerSnackId = nil

local function eventDuration(config)
	if EventService.Context.Config.GameConfig.DebugShortEvents and config.DebugDuration then
		return config.DebugDuration
	end
	return config.Duration
end

local function clearEventObjects()
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end
end

local function collectCrumb(model, player)
	if not model.Parent then
		return
	end
	model:Destroy()
	local context = EventService.Context
	local config = context.Config.EventConfig.SnackRain
	context.Services.EconomyService.AddCoins(player, config.CoinReward)
	context.Services.QuestService.Record(player, "CollectCrumb", 1)
	if math.random() < config.SeedChance then
		local seedId = math.random() < 0.7 and "CookieRock" or "JellyCube"
		context.Services.EconomyService.AddSeeds(player, seedId, 1, false)
		context.Services.EconomyService.Notify(player, "Snack crumb: +" .. tostring(config.CoinReward) .. " coins and +1 " .. context.Config.SnackConfig[seedId].DisplayName .. " seed.")
	else
		context.Services.EconomyService.Notify(player, "Snack crumb collected: +" .. tostring(config.CoinReward) .. " coins.")
	end
	context.Services.EconomyService.Sync(player)
end

local function spawnSnackRainCrumb(index)
	local context = EventService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local folder = world and world:FindFirstChild("EventObjects")
	if not folder then
		return
	end
	local angle = (index / context.Config.EventConfig.SnackRain.CrumbCount) * math.pi * 2
	local radius = 16 + (index % 5) * 6
	local model = context.Services.AssetService.CloneModel("VoidCrumbPickup")
	model.Name = "SnackRainCrumb_" .. tostring(index)
	model.Parent = folder
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(math.cos(angle) * radius, 2.8, math.sin(angle) * radius))
	local prompt = context.Services.AssetService.AddProximityPrompt(model, "Snack Rain", "Collect Crumb")
	local collected = false
	local function tryCollect(player)
		if collected then
			return
		end
		collected = true
		collectCrumb(model, player)
	end
	if prompt then
		prompt.Triggered:Connect(tryCollect)
	end
	local primary = context.Services.AssetService.EnsurePrimaryPart(model)
	if primary then
		primary.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				tryCollect(player)
			end
		end)
	end
end

function EventService.Init(context)
	EventService.Context = context
end

function EventService.Start() end

function EventService.GetActiveEventName()
	return activeEventName
end

function EventService.GetActiveEventEndsAt()
	return activeEventEndsAt
end

function EventService.GetGoldenHungerSnackId()
	return goldenHungerSnackId
end

function EventService.GetMutationWeightMultiplier(mutationId)
	if activeEventName ~= "MutationSurge" or mutationId == "Normal" then
		return 1
	end
	local mutation = EventService.Context.Config.MutationConfig[mutationId]
	if not mutation or (mutation.ValueMultiplier or 1) < 2 then
		return 1.2
	end
	return EventService.Context.Config.EventConfig.MutationSurge.RareWeightMultiplier
end

function EventService.IsActive(eventName)
	return activeEventName == eventName
end

function EventService.EndEvent(token)
	if token and token ~= activeToken then
		return
	end
	local endedName = activeEventName
	activeEventName = nil
	activeEventEndsAt = 0
	goldenHungerSnackId = nil
	clearEventObjects()
	if endedName then
		EventService.Context.Services.EconomyService.NotifyAll((EventService.Context.Config.EventConfig[endedName].DisplayName or endedName) .. " ended.")
		EventService.Context.Services.EconomyService.SyncAll()
	end
end

function EventService.StartEvent(eventName)
	local context = EventService.Context
	local config = context.Config.EventConfig[eventName]
	if not config or activeEventName then
		return false
	end
	activeToken += 1
	local token = activeToken
	local duration = eventDuration(config)
	activeEventName = eventName
	activeEventEndsAt = os.time() + duration
	goldenHungerSnackId = nil
	context.Services.AnalyticsService.VoidEventStarted(eventName)
	context.Services.EconomyService.NotifyAll((config.DisplayName or eventName) .. " has started!")
	clearEventObjects()

	if eventName == "SnackRain" then
		for index = 1, math.min(config.CrumbCount, config.MaxActivePickups) do
			spawnSnackRainCrumb(index)
		end
	elseif eventName == "VoidInfestation" then
		context.Services.EconomyService.NotifyAll("The Voidmites are swarming the labs!")
		for _ = 1, config.ExtraSpawnPasses or 1 do
			context.Services.VoidmiteService.SpawnInfestation(true)
		end
	elseif eventName == "GoldenHunger" then
		local order = context.Config.SnackConfig.Order
		goldenHungerSnackId = order[math.random(1, math.min(#order, 6))]
		context.Services.EconomyService.NotifyAll("The Void wants " .. context.Config.SnackConfig[goldenHungerSnackId].DisplayName .. "!")
	elseif eventName == "MutationSurge" then
		context.Services.EconomyService.NotifyAll("Rare mutations are stirring, but they are still rare.")
	end

	context.Services.EconomyService.SyncAll()
	task.delay(duration, function()
		EventService.EndEvent(token)
	end)
	return true
end

function EventService.StartRandomEvent()
	local events = EventService.Context.Config.EventConfig.Order
	return EventService.StartEvent(events[math.random(1, #events)])
end

return EventService
`;

const voidServiceSource = `
local TweenService = game:GetService("TweenService")

local VoidService = {}

local hunger = 0
local announced = {}

local function requiredHunger()
	local config = VoidService.Context.Config.GameConfig
	if config.DebugFastVoid then
		return config.FastVoidHungerRequired
	end
	return config.VoidHungerRequired
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
		{ Key = 25, Text = "The Void is getting hungry..." },
		{ Key = 50, Text = "The Void is rumbling." },
		{ Key = 75, Text = "The Void is almost awake!" },
	}
	for _, threshold in ipairs(thresholds) do
		if percent >= threshold.Key and not announced[threshold.Key] then
			announced[threshold.Key] = true
			context.Services.EconomyService.NotifyAll(threshold.Text)
		end
	end
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

function VoidService.AddHunger(player, amount, item)
	local context = VoidService.Context
	local required = requiredHunger()
	amount = math.max(0, math.floor(amount or 0))
	hunger += amount
	pulseVoid()
	if item and (item.MutationId == "Glitched" or item.MutationId == "VoidTouched") then
		context.Services.EconomyService.NotifyAll(player.Name .. " fed The Void a " .. item.DisplayName .. ". The Void is waking up...")
	elseif item and ((item.EstimatedVoidValue or amount) >= 90 or item.MutationId ~= "Normal") then
		context.Services.EconomyService.NotifyAll(player.Name .. " fed The Void a " .. item.DisplayName .. "!")
	else
		context.Services.EconomyService.Notify(player, "The Void loved that.")
	end
	if hunger >= required then
		hunger = 0
		announced = {}
		updateBillboard()
		context.Services.EconomyService.NotifyAll("The Void is full. Something strange begins.")
		context.Services.EventService.StartRandomEvent()
	else
		announceMilestones(context, (hunger / required) * 100)
		updateBillboard()
	end
	context.Services.EconomyService.SyncAll()
end

return VoidService
`;

const snackServiceSource = `
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local SnackService = {}

local activeSnacks = {}
local displayedByWorldId = {}
local passiveNotifyAt = {}

local visualAssetByType = {
	Round = "SnackRoundBase",
	Cube = "SnackCubeBase",
	Wrap = "SnackWrapBase",
}

local function getWorld()
	return workspace:WaitForChild("GameWorld")
end

local function snackFolder()
	return getWorld():WaitForChild("ActiveSnacks")
end

local function getSnackConfig(snackId)
	return SnackService.Context.Config.SnackConfig[snackId]
end

local function getMutationConfig(mutationId)
	return SnackService.Context.Config.MutationConfig[mutationId or "Normal"]
end

local function itemDisplayName(snackId, mutationId)
	local snack = getSnackConfig(snackId)
	local mutation = getMutationConfig(mutationId)
	if not snack then
		return snackId
	end
	if not mutation or mutationId == "Normal" then
		return snack.DisplayName
	end
	return mutation.DisplayName .. " " .. snack.DisplayName
end

local function setPlatePrompt(plate, actionText, enabled)
	local prompt = plate and plate:FindFirstChild("PlatePrompt")
	if prompt then
		prompt.ActionText = actionText
		prompt.ObjectText = "Plate"
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 9
		prompt.Enabled = enabled
	end
end

local function clearPlate(plate)
	if plate then
		plate:SetAttribute("Occupied", false)
		plate:SetAttribute("SnackUid", "")
		plate:SetAttribute("SnackId", "")
		plate:SetAttribute("GrowthStage", 0)
		setPlatePrompt(plate, "Plant Snack", true)
	end
end

local function createSnackModel(name, position, snackId, mutationId, stage, displayScale)
	local context = SnackService.Context
	local snack = getSnackConfig(snackId)
	local mutation = getMutationConfig(mutationId)
	local assetKey = visualAssetByType[(snack and snack.VisualType) or "Round"] or "SnackRoundBase"
	local model = context.Services.AssetService.CloneModel(assetKey)
	model.Name = name
	model.Parent = snackFolder()
	local stageScale = ({ 0.45, 0.75, 1 })[stage or 3] or 1
	local mutationScale = mutation and mutation.ScaleMultiplier or 1
	context.Services.AssetService.ScaleModelSafely(model, stageScale * mutationScale * (displayScale or 1))
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(position))
	context.Services.AssetService.ApplyMutationVisual(model, mutationId, snack and snack.Color)
	model:SetAttribute("SnackId", snackId)
	model:SetAttribute("MutationId", mutationId or "Growing")
	return model
end

local function addDisplayLabel(model, text, passiveIncome)
	SnackService.Context.Services.AssetService.AddBillboard(model, text .. "\\n+" .. tostring(passiveIncome) .. " coins/tick", Vector3.new(0, 2.8, 0))
end

local function getPlateNumber(plate)
	local number = tostring(plate.Name):match("Plate(%d+)")
	return tonumber(number) or 1
end

local function getNearestPlate(player, predicate)
	local plot = SnackService.Context.Services.PlotService.GetPlot(player)
	local plates = plot and plot:FindFirstChild("Plates")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not plates or not root then
		return nil
	end
	local usablePlates = SnackService.Context.Services.UpgradeService.GetPlateCount(player)
	local bestPlate = nil
	local bestDistance = math.huge
	for _, plate in ipairs(plates:GetChildren()) do
		if plate:IsA("BasePart") and getPlateNumber(plate) <= usablePlates and (not predicate or predicate(plate)) then
			local distance = (root.Position - plate.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestPlate = plate
			end
		end
	end
	if bestPlate and bestDistance <= 18 then
		return bestPlate
	end
	return nil
end

local function displaySlotPosition(plot, shelfPart)
	local count = 0
	for _, model in pairs(displayedByWorldId) do
		if model and model.Parent and tonumber(model:GetAttribute("PlotId")) == tonumber(plot:GetAttribute("PlotId")) then
			count += 1
		end
	end
	local x = ((count % 5) - 2) * 3
	local z = math.floor(count / 5) * 2
	return shelfPart.Position + Vector3.new(x, 2.1, z)
end

function SnackService.Init(context)
	SnackService.Context = context
end

function SnackService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			SnackService.GrowthTick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SnackService.Context.Config.GameConfig.BaseDisplayIncomeInterval)
			SnackService.PayDisplayIncome()
		end
	end)
	SnackService.BindWorldPrompts()
end

function SnackService.BindWorldPrompts()
	local world = getWorld()
	for _, prompt in ipairs(world:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and not prompt:GetAttribute("FTVBound") then
			prompt:SetAttribute("FTVBound", true)
			if prompt.Name == "PlatePrompt" then
				local plate = prompt.Parent
				if plate and plate:GetAttribute("Occupied") then
					setPlatePrompt(plate, "Growing...", false)
				else
					setPlatePrompt(plate, "Plant Snack", true)
				end
				prompt.Triggered:Connect(function(player)
					local currentPlate = prompt.Parent
					if currentPlate and currentPlate:GetAttribute("Occupied") then
						SnackService.HarvestSnack(player, currentPlate)
					else
						SnackService.PlantSnack(player, currentPlate, "CookieRock")
					end
				end)
			elseif prompt.Name == "SellPrompt" then
				prompt.ActionText = "Open Inventory"
				prompt.ObjectText = "Sell Station"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Select an inventory snack, then tap SELL.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			elseif prompt.Name == "FeedPrompt" then
				prompt.ActionText = "Feed Void"
				prompt.ObjectText = "THE VOID"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Select an inventory snack, then tap FEED VOID.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			elseif prompt.Name == "DisplayPrompt" then
				prompt.ActionText = "Display Snack"
				prompt.ObjectText = "Display Shelf"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Select an inventory snack, then tap DISPLAY.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			elseif prompt.Name == "BuySeedPrompt" then
				prompt.ActionText = "Buy Seeds"
				prompt.ObjectText = "Seed Shop"
				prompt.Triggered:Connect(function(player)
					SnackService.Context.Services.EconomyService.Notify(player, "Open the shop panel to buy seeds.")
					SnackService.Context.Services.EconomyService.Sync(player)
				end)
			end
		end
	end
end

function SnackService.PlantSnack(player, plate, snackId)
	local context = SnackService.Context
	snackId = snackId or "CookieRock"
	if plate == nil then
		plate = getNearestPlate(player, function(candidate)
			return not candidate:GetAttribute("Occupied")
		end)
	end
	local validPlate = context.Services.ValidationService.ValidateWorldObject(plate, "BasePart")
	if not validPlate then
		context.Services.EconomyService.Notify(player, "Stand near an empty plate to plant.")
		return false
	end
	if getPlateNumber(plate) > context.Services.UpgradeService.GetPlateCount(player) then
		context.Services.EconomyService.Notify(player, "Buy Extra Plate to use this plate.")
		return false
	end
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can plant here.")
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, plate, 18) then
		context.Services.EconomyService.Notify(player, "Move closer to that plate.")
		return false
	end
	local hasSeed, snack = context.Services.ValidationService.ValidateSeed(player, snackId)
	if not hasSeed then
		context.Services.EconomyService.Notify(player, "You need a " .. (snack and snack.DisplayName or "snack") .. " seed.")
		return false
	end
	if plate:GetAttribute("Occupied") then
		context.Services.EconomyService.Notify(player, "That plate is busy.")
		return false
	end
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	data.Seeds[snackId] -= 1
	local uid = HttpService:GenerateGUID(false)
	plate:SetAttribute("Occupied", true)
	plate:SetAttribute("SnackUid", uid)
	plate:SetAttribute("SnackId", snackId)
	plate:SetAttribute("GrowthStage", 1)
	setPlatePrompt(plate, "Growing...", false)

	local model = createSnackModel("Growing_" .. uid, plate.Position + Vector3.new(0, 1.5, 0), snackId, "Normal", 1, 1)
	model:SetAttribute("WorldId", uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("GrowthStage", 1)
	activeSnacks[uid] = {
		Player = player,
		Plate = plate,
		Model = model,
		SnackId = snackId,
		PlantedAt = os.clock(),
		GrowTime = context.Config.GameConfig.DebugFastGrowth and context.Config.GameConfig.FastGrowthTime or (snack.GrowTime / math.max(0.1, context.Services.UpgradeService.GetMultiplier(player, "GrowSpeed"))),
		Stage = 1,
	}
	context.Services.ProfileServiceWrapper.MarkDirty(player)
	context.Services.QuestService.Record(player, "Plant", 1)
	context.Services.TutorialService.RecordAction(player, "Plant")
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "You planted " .. snack.DisplayName .. "!")
	context.Services.AnalyticsService.SnackPlanted(player, snackId)
	return true
end

function SnackService.GrowthTick()
	for uid, record in pairs(activeSnacks) do
		if record.Model and record.Model.Parent and record.Plate and record.Plate.Parent then
			local progress = math.clamp((os.clock() - record.PlantedAt) / record.GrowTime, 0, 1)
			local stage = 1
			if progress >= 1 then
				stage = 3
			elseif progress >= 0.5 then
				stage = 2
			end
			if stage ~= record.Stage then
				record.Stage = stage
				record.Plate:SetAttribute("GrowthStage", stage)
				record.Model:SetAttribute("GrowthStage", stage)
				SnackService.Context.Services.AssetService.SetModelCFrame(record.Model, CFrame.new(record.Plate.Position + Vector3.new(0, 1.5 + stage * 0.25, 0)))
				if stage >= 3 then
					setPlatePrompt(record.Plate, "Harvest", true)
				end
			end
		else
			activeSnacks[uid] = nil
		end
	end
end

function SnackService.RollMutation()
	local context = SnackService.Context
	local mutations = context.Config.MutationConfig
	local total = 0
	local weighted = {}
	for mutationId, config in pairs(mutations) do
		if type(config) == "table" and config.Weight then
			local weight = config.Weight * context.Services.EventService.GetMutationWeightMultiplier(mutationId)
			total += weight
			table.insert(weighted, { Id = mutationId, Weight = weight })
		end
	end
	local roll = math.random() * total
	local cursor = 0
	for _, entry in ipairs(weighted) do
		cursor += entry.Weight
		if roll <= cursor then
			return entry.Id
		end
	end
	return "Normal"
end

function SnackService.HarvestSnack(player, plate)
	local context = SnackService.Context
	if plate == nil then
		plate = getNearestPlate(player, function(candidate)
			local uid = candidate:GetAttribute("SnackUid")
			local record = uid and activeSnacks[uid]
			return record and record.Stage >= 3
		end)
	end
	local validPlate = context.Services.ValidationService.ValidateWorldObject(plate, "BasePart")
	if not validPlate then
		context.Services.EconomyService.Notify(player, "Stand near a grown snack to harvest.")
		return false
	end
	local plot = context.Services.PlotService.FindPlotFromInstance(plate)
	if not context.Services.PlotService.PlayerOwnsPlot(player, plot) then
		context.Services.EconomyService.Notify(player, "Only the plot owner can harvest here.")
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, plate, 18) then
		context.Services.EconomyService.Notify(player, "Move closer to harvest.")
		return false
	end
	local uid = plate:GetAttribute("SnackUid")
	local record = uid and activeSnacks[uid]
	if not record or record.Stage < 3 then
		context.Services.EconomyService.Notify(player, "This snack is not ready yet.")
		return false
	end
	local mutationId = SnackService.RollMutation()
	local mutation = getMutationConfig(mutationId)
	local item = {
		UniqueId = HttpService:GenerateGUID(false),
		SnackId = record.SnackId,
		MutationId = mutationId,
		CreatedAt = os.time(),
		ValueMultiplier = mutation.ValueMultiplier,
		DisplayName = itemDisplayName(record.SnackId, mutationId),
	}
	local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
	item.EstimatedSellValue = sellValue
	item.EstimatedVoidValue = voidValue
	item.PassiveIncome = passiveIncome
	context.Services.InventoryService.AddItem(player, item)
	context.Services.CollectionService.MarkHarvest(player, item)
	context.Services.QuestService.Record(player, "Harvest", 1)
	context.Services.TutorialService.RecordAction(player, "Harvest")
	if record.Model then
		record.Model:Destroy()
	end
	clearPlate(plate)
	activeSnacks[uid] = nil
	context.Services.EconomyService.Notify(player, "You harvested " .. item.DisplayName .. "!")
	context.Services.AnalyticsService.SnackHarvested(player, item)
	return true
end

function SnackService.SellSnack(player, itemId)
	local context = SnackService.Context
	local station = context.Services.PlotService.GetStation(player, "SellStation")
	if station and not context.Services.ValidationService.ValidateDistance(player, station, 24) then
		context.Services.EconomyService.Notify(player, "Stand near your Sell Station to sell.")
		return false
	end
	local okItem = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, "Select a snack to sell.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	local value = select(1, context.Services.EconomyService.ComputeItemValues(player, item))
	context.Services.EconomyService.AddCoins(player, value)
	context.Services.QuestService.Record(player, "Sell", 1)
	context.Services.TutorialService.RecordAction(player, "Sell")
	context.Services.EconomyService.Notify(player, "Sold " .. item.DisplayName .. " for " .. tostring(value) .. " coins.")
	context.Services.AnalyticsService.SnackSold(player, item, value)
	return true
end

function SnackService.FeedVoid(player, itemId)
	local context = SnackService.Context
	local world = workspace:FindFirstChild("GameWorld")
	local feedStation = world and world:FindFirstChild("CentralVoid") and world.CentralVoid:FindFirstChild("FeedStation")
	if feedStation and not context.Services.ValidationService.ValidateDistance(player, feedStation, 28) then
		context.Services.EconomyService.Notify(player, "Stand near THE VOID to feed it.")
		return false
	end
	local okItem = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, "Select a snack to feed.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	local _, voidValue = context.Services.EconomyService.ComputeItemValues(player, item)
	local golden = context.Services.EventService.GetGoldenHungerSnackId()
	if golden and item.SnackId == golden then
		local config = context.Config.EventConfig.GoldenHunger
		voidValue = math.floor(voidValue * config.VoidValueMultiplier) + config.HungerBonus
		context.Services.EconomyService.AddVoidTokens(player, config.TokenBonus)
		context.Services.EconomyService.Notify(player, "Golden Hunger match! The Void wanted that snack.")
	end
	item.EstimatedVoidValue = voidValue
	local tokenReward = math.max(1, math.floor(voidValue / 10))
	context.Services.EconomyService.AddVoidTokens(player, tokenReward)
	context.Services.VoidService.AddHunger(player, voidValue, item)
	context.Services.QuestService.Record(player, "FeedVoid", 1)
	context.Services.TutorialService.RecordAction(player, "FeedVoid")
	context.Services.EconomyService.Notify(player, "You fed the Void! +" .. tostring(tokenReward) .. " Void Tokens.")
	context.Services.AnalyticsService.SnackFed(player, item, voidValue)
	return true
end

function SnackService.DisplaySnack(player, itemId, shelf)
	local context = SnackService.Context
	local plot = context.Services.PlotService.GetPlot(player)
	local shelfPart = shelf or (plot and plot:FindFirstChild("DisplayShelf"))
	if not shelfPart or not plot then
		context.Services.EconomyService.Notify(player, "Display shelf missing.")
		return false
	end
	if not context.Services.ValidationService.ValidateDistance(player, shelfPart, 24) then
		context.Services.EconomyService.Notify(player, "Stand near your Display Shelf to display.")
		return false
	end
	local okItem = context.Services.ValidationService.ValidateInventoryItem(player, itemId)
	if not okItem then
		context.Services.EconomyService.Notify(player, "Select a snack to display.")
		return false
	end
	local item = context.Services.InventoryService.RemoveItem(player, itemId)
	local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
	item.EstimatedSellValue = sellValue
	item.EstimatedVoidValue = voidValue
	item.PassiveIncome = passiveIncome
	item.WorldId = item.WorldId or HttpService:GenerateGUID(false)
	local position = displaySlotPosition(plot, shelfPart)
	local model = createSnackModel("Displayed_" .. item.WorldId, position, item.SnackId, item.MutationId, 3, 0.9)
	model:SetAttribute("WorldId", item.WorldId)
	model:SetAttribute("Displayed", true)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
	model:SetAttribute("DisplayValue", sellValue)
	model:SetAttribute("DisplayName", item.DisplayName)
	addDisplayLabel(model, item.DisplayName, passiveIncome)
	displayedByWorldId[item.WorldId] = model
	context.Services.InventoryService.AddDisplayed(player, item)
	context.Services.QuestService.Record(player, "Display", 1)
	context.Services.TutorialService.RecordAction(player, "Display")
	context.Services.EconomyService.Notify(player, "Displayed " .. item.DisplayName .. ". It now earns passive coins.")
	context.Services.AnalyticsService.SnackDisplayed(player, item)
	return true
end

function SnackService.RestoreDisplayed(player)
	local context = SnackService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	local plot = context.Services.PlotService.GetPlot(player)
	local shelfPart = plot and plot:FindFirstChild("DisplayShelf")
	if not data or not plot or not shelfPart then
		return
	end
	for _, item in ipairs(data.DisplayedSnacks or {}) do
		if item and item.SnackId and context.Config.SnackConfig[item.SnackId] then
			item.WorldId = item.WorldId or HttpService:GenerateGUID(false)
			if not displayedByWorldId[item.WorldId] then
				local sellValue, voidValue, passiveIncome = context.Services.EconomyService.ComputeItemValues(player, item)
				item.EstimatedSellValue = sellValue
				item.EstimatedVoidValue = voidValue
				item.PassiveIncome = passiveIncome
				local model = createSnackModel("Displayed_" .. item.WorldId, displaySlotPosition(plot, shelfPart), item.SnackId, item.MutationId, 3, 0.9)
				model:SetAttribute("WorldId", item.WorldId)
				model:SetAttribute("Displayed", true)
				model:SetAttribute("OwnerUserId", player.UserId)
				model:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
				model:SetAttribute("DisplayValue", sellValue)
				model:SetAttribute("DisplayName", item.DisplayName)
				addDisplayLabel(model, item.DisplayName, passiveIncome)
				displayedByWorldId[item.WorldId] = model
			end
		else
			warn("[FEED THE VOID] Skipped malformed displayed snack during restore.")
		end
	end
	context.Services.ProfileServiceWrapper.MarkDirty(player)
end

function SnackService.ClearPlotVisuals(player)
	for uid, record in pairs(activeSnacks) do
		if record.Player == player then
			if record.Model then
				record.Model:Destroy()
			end
			clearPlate(record.Plate)
			activeSnacks[uid] = nil
		end
	end
	for worldId, model in pairs(displayedByWorldId) do
		if model and tonumber(model:GetAttribute("OwnerUserId")) == player.UserId then
			model:Destroy()
			displayedByWorldId[worldId] = nil
		end
	end
end

function SnackService.GetDisplayedModels()
	return displayedByWorldId
end

function SnackService.PayDisplayIncome()
	local context = SnackService.Context
	for worldId, model in pairs(displayedByWorldId) do
		if not model or not model.Parent then
			displayedByWorldId[worldId] = nil
		else
			local owner = Players:GetPlayerByUserId(tonumber(model:GetAttribute("OwnerUserId")) or 0)
			if owner then
				local income = math.max(1, math.floor((tonumber(model:GetAttribute("DisplayValue")) or 10) / 10))
				context.Services.EconomyService.AddCoins(owner, income)
				local last = passiveNotifyAt[owner] or 0
				if os.clock() - last > 28 then
					passiveNotifyAt[owner] = os.clock()
					context.Services.EconomyService.Notify(owner, "Displayed snacks earned +" .. tostring(income) .. " coins.")
				end
			end
		end
	end
end

return SnackService
`;

const voidmiteServiceSource = `
local Players = game:GetService("Players")

local VoidmiteService = {}

local nextSpawnCheck = {}
local clearCooldown = {}

local function getFolder()
	local world = workspace:FindFirstChild("GameWorld")
	return world and world:FindFirstChild("ActiveVoidmites")
end

local function ownerPlayerFromUserId(userId)
	userId = tonumber(userId)
	return userId and Players:GetPlayerByUserId(userId) or nil
end

local function countForPlot(plotId)
	local folder = getFolder()
	local count = 0
	if not folder then
		return 0
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("PlotId")) == tonumber(plotId) then
			count += 1
		end
	end
	return count
end

local function spawnVoidmiteForDisplay(displayModel, eventCreated)
	local context = VoidmiteService.Context
	local folder = getFolder()
	if not folder or not displayModel or not displayModel.Parent then
		return
	end
	local ownerUserId = tonumber(displayModel:GetAttribute("OwnerUserId"))
	local plotId = tonumber(displayModel:GetAttribute("PlotId"))
	if not ownerUserId or not plotId then
		return
	end
	if countForPlot(plotId) >= context.Config.GameConfig.MaxVoidmitesPerPlot then
		return
	end
	local reward = math.max(5, math.floor((tonumber(displayModel:GetAttribute("DisplayValue")) or 10) * 0.18))
	if context.Services.EventService.IsActive("VoidInfestation") then
		reward = math.floor(reward * context.Config.EventConfig.VoidInfestation.RewardMultiplier)
	end
	local origin = displayModel:GetPivot().Position
	local model = context.Services.AssetService.CloneModel("Voidmite")
	model.Name = "Voidmite_" .. tostring(os.clock()):gsub("%.", "_")
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("PlotId", plotId)
	model:SetAttribute("RewardValue", reward)
	model:SetAttribute("EventCreated", eventCreated == true)
	model.Parent = folder
	context.Services.AssetService.SetModelCFrame(model, CFrame.new(origin + Vector3.new(math.random(-5, 5), 1.1, math.random(-4, 4))))
	context.Services.AssetService.ApplyMutationVisual(model, "VoidTouched")
	context.Services.AssetService.AddBillboard(model, "Voidmite", Vector3.new(0, 2.1, 0))
	local prompt = context.Services.AssetService.AddProximityPrompt(model, "Voidmite", "Cleanse")
	if prompt then
		prompt.Triggered:Connect(function(player)
			VoidmiteService.ClearVoidmite(player, model)
		end)
	end
	return model
end

function VoidmiteService.Init(context)
	VoidmiteService.Context = context
end

function VoidmiteService.Start()
	task.spawn(function()
		while true do
			task.wait(5)
			VoidmiteService.SpawnTick()
		end
	end)
end

function VoidmiteService.SpawnTick()
	local context = VoidmiteService.Context
	for _, model in pairs(context.Services.SnackService.GetDisplayedModels()) do
		if model and model.Parent then
			local worldId = model:GetAttribute("WorldId")
			local value = tonumber(model:GetAttribute("DisplayValue")) or 10
			local interval = math.max(
				context.Config.GameConfig.MinVoidmiteSpawnInterval,
				context.Config.GameConfig.BaseVoidmiteSpawnInterval - math.clamp(value / 80, 0, 10)
			)
			local due = nextSpawnCheck[worldId] or (os.clock() + interval)
			if os.clock() >= due then
				nextSpawnCheck[worldId] = os.clock() + interval + math.random(0, 5)
				spawnVoidmiteForDisplay(model, false)
			else
				nextSpawnCheck[worldId] = due
			end
		end
	end
end

function VoidmiteService.SpawnInfestation(eventCreated)
	local context = VoidmiteService.Context
	for _, model in pairs(context.Services.SnackService.GetDisplayedModels()) do
		spawnVoidmiteForDisplay(model, eventCreated)
	end
end

function VoidmiteService.ClearForPlayer(player)
	local folder = getFolder()
	if not folder then
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("OwnerUserId")) == player.UserId then
			child:Destroy()
		end
	end
end

function VoidmiteService.ClearVoidmite(player, voidmite)
	local context = VoidmiteService.Context
	if typeof(voidmite) ~= "Instance" or not voidmite:IsDescendantOf(workspace) or not voidmite.Name:match("^Voidmite_") then
		context.Services.EconomyService.Notify(player, "That Voidmite is already gone.")
		return false
	end
	local now = os.clock()
	if (clearCooldown[player] or 0) > now then
		return false
	end
	clearCooldown[player] = now + 0.5
	if not context.Services.ValidationService.ValidateDistance(player, voidmite, 14) then
		context.Services.EconomyService.Notify(player, "Move closer to cleanse that Voidmite.")
		return false
	end
	if voidmite:GetAttribute("Cleared") then
		return false
	end
	voidmite:SetAttribute("Cleared", true)
	local reward = tonumber(voidmite:GetAttribute("RewardValue")) or 5
	reward = math.floor(reward * context.Services.UpgradeService.GetMultiplier(player, "VoidmiteReward"))
	local ownerUserId = tonumber(voidmite:GetAttribute("OwnerUserId"))
	local ownerPlayer = ownerPlayerFromUserId(ownerUserId)
	voidmite:Destroy()
	context.Services.EconomyService.AddCoins(player, reward)
	context.Services.EconomyService.AddVoidTokens(player, 1)
	context.Services.QuestService.Record(player, "CleanseVoidmite", 1)
	context.Services.TutorialService.RecordAction(player, "CleanseVoidmite")
	if ownerPlayer and ownerPlayer ~= player then
		local ownerReward = math.max(2, math.floor(reward * 0.5))
		context.Services.EconomyService.AddCoins(ownerPlayer, ownerReward)
		context.Services.EconomyService.Notify(ownerPlayer, player.Name .. " cleansed your Voidmite: +" .. tostring(ownerReward) .. " coins.")
		context.Services.EconomyService.Notify(player, "Co-op cleanse: +" .. tostring(reward) .. " coins and +1 Void Token.")
	else
		context.Services.EconomyService.Notify(player, "Voidmite cleansed: +" .. tostring(reward) .. " coins and +1 Void Token.")
	end
	context.Services.AnalyticsService.VoidmiteCleared(player, ownerPlayer, reward)
	return true
end

return VoidmiteService
`;

const mainSource = `
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerFolder = script.Parent
local ServicesFolder = ServerFolder:WaitForChild("Services")

local context = {
	Remotes = {
		RequestPlantSnack = Remotes:WaitForChild("RequestPlantSnack"),
		RequestHarvestSnack = Remotes:WaitForChild("RequestHarvestSnack"),
		RequestSellSnack = Remotes:WaitForChild("RequestSellSnack"),
		RequestFeedVoid = Remotes:WaitForChild("RequestFeedVoid"),
		RequestDisplaySnack = Remotes:WaitForChild("RequestDisplaySnack"),
		RequestClearVoidmite = Remotes:WaitForChild("RequestClearVoidmite"),
		RequestBuySeed = Remotes:WaitForChild("RequestBuySeed"),
		RequestBuyUpgrade = Remotes:WaitForChild("RequestBuyUpgrade"),
		RequestRebirth = Remotes:WaitForChild("RequestRebirth"),
		RequestSkipTutorial = Remotes:WaitForChild("RequestSkipTutorial"),
		RequestDebugCommand = Remotes:WaitForChild("RequestDebugCommand"),
		NotifyClient = Remotes:WaitForChild("NotifyClient"),
		SyncPlayerData = Remotes:WaitForChild("SyncPlayerData"),
	},
	Config = {
		GameConfig = require(Shared:WaitForChild("GameConfig")),
		SnackConfig = require(Shared:WaitForChild("SnackConfig")),
		MutationConfig = require(Shared:WaitForChild("MutationConfig")),
		EventConfig = require(Shared:WaitForChild("EventConfig")),
		FormatNumbers = require(Shared:WaitForChild("FormatNumbers")),
	},
	Services = {},
}

local serviceOrder = {
	"ProfileServiceWrapper",
	"AnalyticsService",
	"AssetService",
	"EconomyService",
	"InventoryService",
	"PlotService",
	"ValidationService",
	"CollectionService",
	"QuestService",
	"UpgradeService",
	"TutorialService",
	"EventService",
	"VoidService",
	"VoidmiteService",
	"ShopService",
	"RebirthService",
	"VisitRewardService",
	"SnackService",
}

for _, serviceName in ipairs(serviceOrder) do
	context.Services[serviceName] = require(ServicesFolder:WaitForChild(serviceName))
end

for _, serviceName in ipairs(serviceOrder) do
	local service = context.Services[serviceName]
	if service.Init then
		service.Init(context)
	end
end

for _, serviceName in ipairs(serviceOrder) do
	local service = context.Services[serviceName]
	if service.Start then
		service.Start()
	end
end

local lastRemoteUse = {}

local function passesCooldown(player, remoteName)
	local now = os.clock()
	lastRemoteUse[player] = lastRemoteUse[player] or {}
	local last = lastRemoteUse[player][remoteName] or 0
	local cooldown = context.Config.GameConfig.RemoteCooldowns[remoteName] or context.Config.GameConfig.RemoteCooldown
	if now - last < cooldown then
		return false
	end
	lastRemoteUse[player][remoteName] = now
	return true
end

local function bindRemote(remoteName, callback)
	context.Remotes[remoteName].OnServerEvent:Connect(function(player, ...)
		if not passesCooldown(player, remoteName) then
			return
		end
		local ok, err = pcall(callback, player, ...)
		if not ok then
			warn("[FEED THE VOID]", remoteName, err)
			context.Services.EconomyService.Notify(player, "That action fizzled. Try again.")
		end
	end)
end

bindRemote("RequestPlantSnack", function(player, plate, snackId)
	context.Services.SnackService.PlantSnack(player, plate, snackId)
end)

bindRemote("RequestHarvestSnack", function(player, plate)
	context.Services.SnackService.HarvestSnack(player, plate)
end)

bindRemote("RequestSellSnack", function(player, itemId)
	context.Services.SnackService.SellSnack(player, itemId)
end)

bindRemote("RequestFeedVoid", function(player, itemId)
	context.Services.SnackService.FeedVoid(player, itemId)
end)

bindRemote("RequestDisplaySnack", function(player, itemId)
	context.Services.SnackService.DisplaySnack(player, itemId)
end)

bindRemote("RequestClearVoidmite", function(player, voidmite)
	context.Services.VoidmiteService.ClearVoidmite(player, voidmite)
end)

bindRemote("RequestBuySeed", function(player, snackId)
	context.Services.ShopService.BuySeed(player, snackId)
end)

bindRemote("RequestBuyUpgrade", function(player, upgradeId)
	context.Services.UpgradeService.BuyUpgrade(player, upgradeId)
end)

bindRemote("RequestRebirth", function(player)
	context.Services.RebirthService.TryRebirth(player)
end)

bindRemote("RequestSkipTutorial", function(player)
	context.Services.TutorialService.Skip(player)
end)

local function runDebugCommand(player, commandText)
	if not context.Config.GameConfig.DebugMode then
		return
	end
	commandText = tostring(commandText or "")
	local command, a, b = commandText:match("^!(%S+)%s*(%S*)%s*(%S*)")
	if not command then
		return
	end
	if command == "coins" and context.Config.GameConfig.DebugGiveCoins then
		context.Services.EconomyService.AddCoins(player, tonumber(a) or 5000)
	elseif command == "seed" then
		context.Services.EconomyService.AddSeeds(player, a ~= "" and a or "CookieRock", tonumber(b) or 5)
	elseif command == "voidfill" then
		context.Services.VoidService.AddHunger(player, context.Services.VoidService.GetRequired(), { DisplayName = "debug snack", MutationId = "Normal" })
	elseif command == "event" and a ~= "" then
		context.Services.EventService.StartEvent(a)
	elseif command == "fastgrowth" then
		context.Config.GameConfig.DebugFastGrowth = (a == "on")
	end
end

bindRemote("RequestDebugCommand", runDebugCommand)

local function setupPlayer(player)
	context.Services.ProfileServiceWrapper.LoadPlayer(player)
	context.Services.AnalyticsService.PlayerJoined(player)
	context.Services.PlotService.AssignPlot(player)
	context.Services.QuestService.Ensure(player)
	context.Services.CollectionService.Ensure(player)
	context.Services.SnackService.RestoreDisplayed(player)
	context.Services.VisitRewardService.ApplyJoinReward(player)
	context.Services.TutorialService.SendStep(player)
	context.Services.EconomyService.Sync(player)
	player.Chatted:Connect(function(message)
		runDebugCommand(player, message)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		context.Services.PlotService.TeleportToPlot(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	context.Services.SnackService.ClearPlotVisuals(player)
	context.Services.VoidmiteService.ClearForPlayer(player)
	context.Services.PlotService.ReleasePlot(player)
	context.Services.ProfileServiceWrapper.ReleasePlayer(player)
	lastRemoteUse[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

print("[FEED THE VOID] Phase 2 server loaded.")
`;

const clientMainSource = `
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

NotificationController.Show("FEED THE VOID Phase 2 loaded.")
`;

const uiControllerSource = `
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
local majorPanels = { "InventoryPanel", "SeedShopPanel", "UpgradePanel", "CollectionPanel", "RebirthPanel" }

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
		detail.Text = item.DisplayName .. "\\nSell: " .. tostring(item.EstimatedSellValue or 0) .. "  Void: " .. tostring(item.EstimatedVoidValue or 0)
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
			button.Text = item.DisplayName .. "\\n" .. tostring(item.MutationName or item.MutationId or "Normal") .. " | Sell " .. tostring(item.EstimatedSellValue or 0)
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
	for seedId, button in pairs(seedButtons) do
		local snack = SnackConfig[seedId]
		button.Text = snack.DisplayName .. "\\nCost " .. tostring(snack.SeedCost) .. " | Owned " .. tostring(seedCount(seedId))
	end
end

local function updateUpgrades(data)
	local upgrades = data.Upgrades or {}
	for _, item in ipairs(upgrades.Items or {}) do
		local button = upgradeButtons[item.Id]
		if button then
			local levelText = tostring(item.Level) .. "/" .. tostring(item.MaxLevel)
			local costText = item.Level >= item.MaxLevel and "MAX" or ("Cost " .. tostring(item.Cost))
			button.Text = item.DisplayName .. "\\nLv " .. levelText .. " | " .. costText
		end
	end
end

local function updateCollection(data)
	local panel = mainUi:WaitForChild("CollectionPanel")
	local collections = data.Collections or {}
	panel.CollectionSummary.Text = "Snacks " .. tostring(collections.SnacksDiscovered or 0) .. "/" .. tostring(collections.SnacksTotal or 0)
		.. "  Mutations " .. tostring(collections.MutationsDiscovered or 0) .. "/" .. tostring(collections.MutationsTotal or 0)
		.. "\\nCombos " .. tostring(collections.CombosDiscovered or 0) .. "/" .. tostring(collections.CombosTotal or 0)
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
	panel.RebirthInfo.Text = "Requirement: " .. tostring(requirement) .. " coins\\nCurrent: " .. tostring(data.Coins or 0)
		.. "\\nPermanent boost after rebirth: +" .. tostring(math.floor((rebirths + 1) * (GameConfig.RebirthBoostPerRebirth or 0.15) * 100)) .. "%"
end

local function updateEventBanner(data)
	local banner = mainUi:WaitForChild("EventBanner")
	local activeName = data.ActiveEventName
	if activeName then
		local remaining = math.max(0, (data.ActiveEventEndsAt or 0) - os.time())
		banner.Visible = true
		local goldenText = data.GoldenHungerSnackId and SnackConfig[data.GoldenHungerSnackId] and (" | Wants " .. SnackConfig[data.GoldenHungerSnackId].DisplayName) or ""
		banner.EventText.Text = activeName .. " active - " .. tostring(remaining) .. "s" .. goldenText
	else
		banner.Visible = false
	end
end

local function updateTutorial(data)
	local panel = mainUi:WaitForChild("TutorialPanel")
	local step = data.TutorialStep or 1
	if step > #GameConfig.TutorialMessages then
		panel.Visible = false
	else
		panel.Visible = true
		panel.TutorialText.Text = GameConfig.TutorialMessages[step] or "Follow the objectives."
	end
end

function UIController.Init(ui, notifications)
	mainUi = ui
	notificationController = notifications
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

	local nav = mainUi:WaitForChild("BottomNav")
	nav.InventoryButton.Activated:Connect(function() showPanel("InventoryPanel") end)
	nav.ShopButton.Activated:Connect(function() showPanel("SeedShopPanel") end)
	nav.UpgradesButton.Activated:Connect(function() showPanel("UpgradePanel") end)
	nav.CollectionButton.Activated:Connect(function() showPanel("CollectionPanel") end)
	nav.RebirthButton.Activated:Connect(function() showPanel("RebirthPanel") end)
	nav.MobileActionButton.Activated:Connect(function()
		Remotes.RequestPlantSnack:FireServer(nil, selectedSeedId)
	end)
	for _, panelName in ipairs(majorPanels) do
		local panel = mainUi:FindFirstChild(panelName)
		local close = panel and panel:FindFirstChild("CloseButton")
		if close then
			close.Activated:Connect(function()
				showPanel("SeedShopPanel")
			end)
		end
	end

	showPanel("SeedShopPanel")

	Remotes.SyncPlayerData.OnClientEvent:Connect(function(data)
		UIController.ApplyData(data)
	end)
	Remotes.NotifyClient.OnClientEvent:Connect(function(message)
		notificationController.Show(message)
	end)
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
end

return UIController
`;

function addPhase2FoldersAndRemotes() {
  [
    "ReplicatedStorage.Assets",
    "ReplicatedStorage.Assets.Models",
    "ReplicatedStorage.Assets.Models.Void",
    "ReplicatedStorage.Assets.Models.Creatures",
    "ReplicatedStorage.Assets.Models.Snacks",
    "ReplicatedStorage.Assets.Models.Plot",
    "ReplicatedStorage.Assets.Models.Stations",
    "ReplicatedStorage.Assets.Models.Pickups",
  ].forEach(ensureFolder);
  ["RequestBuyUpgrade", "RequestSkipTutorial", "RequestDebugCommand"].forEach(ensureRemote);
}

function addPhase2Ui() {
  inst("Frame", "StarterGui.MainUI.ObjectivesPanel", {
    BackgroundColor3: c3(24, 27, 34),
    BackgroundTransparency: 0.08,
    BorderSizePixel: 0,
    Size: ud2(0, 330, 0, 122),
    Position: ud2(0, 12, 0, 108),
  });
  inst("TextLabel", "StarterGui.MainUI.ObjectivesPanel.Title", {
    BackgroundTransparency: 1,
    Size: ud2(1, -16, 0, 26),
    Position: ud2(0, 8, 0, 6),
    Text: "OBJECTIVES",
    TextColor3: c3(255, 213, 105),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  for (let i = 1; i <= 3; i += 1) {
    inst("TextLabel", `StarterGui.MainUI.ObjectivesPanel.Objective${i}`, {
      BackgroundTransparency: 1,
      Size: ud2(1, -16, 0, 26),
      Position: ud2(0, 8, 0, 30 + (i - 1) * 28),
      Text: "Objective loading...",
      TextColor3: c3(230, 235, 245),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  }

  inst("Frame", "StarterGui.MainUI.TutorialPanel", {
    BackgroundColor3: c3(42, 32, 58),
    BackgroundTransparency: 0.04,
    BorderSizePixel: 0,
    Size: ud2(0, 430, 0, 72),
    Position: ud2(0.5, -215, 0, 108),
    Visible: true,
  });
  inst("TextLabel", "StarterGui.MainUI.TutorialPanel.TutorialText", {
    BackgroundTransparency: 1,
    Size: ud2(1, -118, 1, -12),
    Position: ud2(0, 10, 0, 6),
    Text: "Welcome to FEED THE VOID!",
    TextColor3: c3(255, 246, 210),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("TextButton", "StarterGui.MainUI.TutorialPanel.SkipTutorialButton", {
    BackgroundColor3: c3(80, 64, 105),
    BorderSizePixel: 0,
    Size: ud2(0, 96, 0, 44),
    Position: ud2(1, -104, 0, 14),
    Text: "SKIP",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });

  inst("Frame", "StarterGui.MainUI.InventoryPanel", {
    Visible: false,
    BackgroundColor3: c3(28, 31, 39),
    BackgroundTransparency: 0.04,
    BorderSizePixel: 0,
    Size: ud2(0, 384, 0, 430),
    Position: ud2(0, 12, 1, -506),
  });
  inst("TextLabel", "StarterGui.MainUI.InventoryPanel.InventoryList", {
    BackgroundTransparency: 1,
    Size: ud2(1, -20, 0, 24),
    Position: ud2(0, 10, 0, 40),
    Text: "Inventory: 0 snacks",
    TextColor3: c3(245, 235, 230),
    TextScaled: true,
    TextWrapped: true,
    Font: "Gotham",
  });
  inst("TextLabel", "StarterGui.MainUI.InventoryPanel.SeedsLabel", {
    BackgroundTransparency: 1,
    Size: ud2(1, -20, 0, 24),
    Position: ud2(0, 10, 0, 64),
    Text: "Seeds: loading...",
    TextColor3: c3(245, 235, 230),
    TextScaled: true,
    TextWrapped: true,
    Font: "Gotham",
  });
  inst("TextLabel", "StarterGui.MainUI.InventoryPanel.DisplayedLabel", {
    BackgroundTransparency: 1,
    Size: ud2(1, -20, 0, 24),
    Position: ud2(0, 10, 0, 88),
    Text: "Displayed: 0",
    TextColor3: c3(245, 235, 230),
    TextScaled: true,
    TextWrapped: true,
    Font: "Gotham",
  });
  inst("Frame", "StarterGui.MainUI.InventoryPanel.ItemList", {
    BackgroundTransparency: 1,
    Size: ud2(1, -20, 0, 196),
    Position: ud2(0, 10, 0, 116),
  });
  for (let i = 1; i <= 8; i += 1) {
    const col = (i - 1) % 2;
    const row = Math.floor((i - 1) / 2);
    inst("TextButton", `StarterGui.MainUI.InventoryPanel.ItemList.Item${i}`, {
      BackgroundColor3: c3(46, 58, 78),
      BorderSizePixel: 0,
      Size: ud2(0.5, -6, 0, 42),
      Position: ud2(0.5 * col, col === 0 ? 0 : 6, 0, row * 48),
      Text: "",
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Visible: false,
      Font: "GothamBold",
    });
  }
  inst("TextButton", "StarterGui.MainUI.InventoryPanel.CloseButton", {
    BackgroundColor3: c3(70, 70, 80),
    BorderSizePixel: 0,
    Size: ud2(0, 34, 0, 30),
    Position: ud2(1, -42, 0, 8),
    Text: "X",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    Font: "GothamBold",
  });

  inst("Frame", "StarterGui.MainUI.SeedShopPanel.SeedList", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 240),
    Position: ud2(0, 12, 0, 48),
  });
  const snackOrder = [
    ["CookieRock", c3(155, 125, 90)],
    ["MoonMarshmallow", c3(140, 145, 210)],
    ["JellyCube", c3(60, 160, 190)],
    ["BubbleBread", c3(200, 92, 150)],
    ["MeteorMuffin", c3(190, 70, 64)],
    ["CrystalDonut", c3(65, 165, 220)],
    ["LavaNoodleWrap", c3(205, 82, 48)],
    ["BlackHoleBurrito", c3(75, 52, 105)],
  ];
  snackOrder.forEach(([id, color], index) => {
    const col = index % 2;
    const row = Math.floor(index / 2);
    inst("TextButton", `StarterGui.MainUI.SeedShopPanel.SeedList.${id}Button`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(0.5, -6, 0, 50),
      Position: ud2(0.5 * col, col === 0 ? 0 : 6, 0, row * 58),
      Text: id,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  });
  inst("TextButton", "StarterGui.MainUI.SeedShopPanel.CloseButton", {
    BackgroundColor3: c3(70, 70, 80),
    BorderSizePixel: 0,
    Size: ud2(0, 34, 0, 30),
    Position: ud2(1, -42, 0, 8),
    Text: "X",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    Font: "GothamBold",
  });

  inst("Frame", "StarterGui.MainUI.UpgradePanel", {
    Visible: false,
    BackgroundColor3: c3(28, 31, 39),
    BackgroundTransparency: 0.04,
    BorderSizePixel: 0,
    Size: ud2(0, 384, 0, 360),
    Position: ud2(1, -396, 1, -436),
  });
  inst("TextLabel", "StarterGui.MainUI.UpgradePanel.Title", {
    BackgroundTransparency: 1,
    Size: ud2(1, -56, 0, 34),
    Position: ud2(0, 12, 0, 8),
    Text: "UPGRADES",
    TextColor3: c3(255, 213, 105),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  inst("TextButton", "StarterGui.MainUI.UpgradePanel.CloseButton", {
    BackgroundColor3: c3(70, 70, 80),
    BorderSizePixel: 0,
    Size: ud2(0, 34, 0, 30),
    Position: ud2(1, -42, 0, 8),
    Text: "X",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    Font: "GothamBold",
  });
  inst("Frame", "StarterGui.MainUI.UpgradePanel.UpgradeList", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 1, -54),
    Position: ud2(0, 12, 0, 46),
  });
  [
    ["ExtraPlate", c3(85, 118, 164)],
    ["GrowSpeed", c3(80, 155, 105)],
    ["SellMultiplier", c3(185, 135, 60)],
    ["VoidRewardMultiplier", c3(126, 82, 190)],
    ["DisplayIncome", c3(70, 142, 160)],
    ["VoidmiteReward", c3(165, 76, 142)],
  ].forEach(([id, color], index) => {
    const col = index % 2;
    const row = Math.floor(index / 2);
    inst("TextButton", `StarterGui.MainUI.UpgradePanel.UpgradeList.${id}Button`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(0.5, -6, 0, 78),
      Position: ud2(0.5 * col, col === 0 ? 0 : 6, 0, row * 86),
      Text: id,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  });

  inst("Frame", "StarterGui.MainUI.CollectionPanel", {
    Visible: false,
    BackgroundColor3: c3(28, 31, 39),
    BackgroundTransparency: 0.04,
    BorderSizePixel: 0,
    Size: ud2(0, 384, 0, 360),
    Position: ud2(1, -396, 1, -436),
  });
  inst("TextLabel", "StarterGui.MainUI.CollectionPanel.Title", {
    BackgroundTransparency: 1,
    Size: ud2(1, -56, 0, 34),
    Position: ud2(0, 12, 0, 8),
    Text: "COLLECTION",
    TextColor3: c3(255, 213, 105),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  inst("TextButton", "StarterGui.MainUI.CollectionPanel.CloseButton", {
    BackgroundColor3: c3(70, 70, 80),
    BorderSizePixel: 0,
    Size: ud2(0, 34, 0, 30),
    Position: ud2(1, -42, 0, 8),
    Text: "X",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    Font: "GothamBold",
  });
  inst("TextLabel", "StarterGui.MainUI.CollectionPanel.CollectionSummary", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 58),
    Position: ud2(0, 12, 0, 44),
    Text: "Collection loading...",
    TextColor3: c3(230, 235, 245),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("Frame", "StarterGui.MainUI.CollectionPanel.SnackList", {
    BackgroundTransparency: 1,
    Size: ud2(0.5, -18, 0, 230),
    Position: ud2(0, 12, 0, 112),
  });
  inst("Frame", "StarterGui.MainUI.CollectionPanel.MutationList", {
    BackgroundTransparency: 1,
    Size: ud2(0.5, -18, 0, 230),
    Position: ud2(0.5, 6, 0, 112),
  });
  for (let i = 1; i <= 8; i += 1) {
    inst("TextLabel", `StarterGui.MainUI.CollectionPanel.SnackList.Snack${i}`, {
      BackgroundTransparency: 0.12,
      BackgroundColor3: c3(40, 48, 62),
      BorderSizePixel: 0,
      Size: ud2(1, 0, 0, 24),
      Position: ud2(0, 0, 0, (i - 1) * 28),
      Text: "???",
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "Gotham",
    });
    inst("TextLabel", `StarterGui.MainUI.CollectionPanel.MutationList.Mutation${i}`, {
      BackgroundTransparency: 0.12,
      BackgroundColor3: c3(42, 36, 58),
      BorderSizePixel: 0,
      Size: ud2(1, 0, 0, 24),
      Position: ud2(0, 0, 0, (i - 1) * 28),
      Text: "???",
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "Gotham",
    });
  }

  inst("Frame", "StarterGui.MainUI.RebirthPanel", {
    Visible: false,
    BackgroundColor3: c3(28, 31, 39),
    BackgroundTransparency: 0.04,
    BorderSizePixel: 0,
    Size: ud2(0, 384, 0, 260),
    Position: ud2(1, -396, 1, -336),
  });
  inst("TextLabel", "StarterGui.MainUI.RebirthPanel.Title", {
    BackgroundTransparency: 1,
    Size: ud2(1, -56, 0, 34),
    Position: ud2(0, 12, 0, 8),
    Text: "REBIRTH",
    TextColor3: c3(255, 213, 105),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  inst("TextButton", "StarterGui.MainUI.RebirthPanel.CloseButton", {
    BackgroundColor3: c3(70, 70, 80),
    BorderSizePixel: 0,
    Size: ud2(0, 34, 0, 30),
    Position: ud2(1, -42, 0, 8),
    Text: "X",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    Font: "GothamBold",
  });
  inst("TextLabel", "StarterGui.MainUI.RebirthPanel.RebirthInfo", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 124),
    Position: ud2(0, 12, 0, 54),
    Text: "Requirement: 5000 coins",
    TextColor3: c3(230, 235, 245),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("TextButton", "StarterGui.MainUI.RebirthPanel.RebirthButton", {
    BackgroundColor3: c3(126, 82, 190),
    BorderSizePixel: 0,
    Size: ud2(1, -24, 0, 56),
    Position: ud2(0, 12, 1, -68),
    Text: "REBIRTH",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });

  inst("Frame", "StarterGui.MainUI.BottomNav", {
    BackgroundTransparency: 1,
    Size: ud2(0, 744, 0, 66),
    Position: ud2(0.5, -372, 1, -72),
  });
  [
    ["InventoryButton", "INVENTORY", 0, c3(68, 128, 190), 112],
    ["ShopButton", "SHOP", 122, c3(70, 165, 92), 92],
    ["UpgradesButton", "UPGRADES", 224, c3(185, 135, 60), 112],
    ["CollectionButton", "INDEX", 346, c3(82, 150, 170), 92],
    ["RebirthButton", "REBIRTH", 448, c3(135, 78, 190), 102],
    ["MobileActionButton", "PLANT", 560, c3(190, 124, 50), 120],
  ].forEach(([name, text, x, color, width]) => {
    inst("TextButton", `StarterGui.MainUI.BottomNav.${name}`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(0, width, 0, 56),
      Position: ud2(0, x, 0, 4),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  });
}

function addPhase2Scripts() {
  writeScript("ReplicatedStorage.Shared.GameConfig", "ModuleScript", "shared/GameConfig.lua", gameConfigSource);
  writeScript("ReplicatedStorage.Shared.SnackConfig", "ModuleScript", "shared/SnackConfig.lua", snackConfigSource);
  writeScript("ReplicatedStorage.Shared.MutationConfig", "ModuleScript", "shared/MutationConfig.lua", mutationConfigSource);
  writeScript("ReplicatedStorage.Shared.EventConfig", "ModuleScript", "shared/EventConfig.lua", eventConfigSource);
  writeScript("ReplicatedStorage.Shared.AssetReferences", "ModuleScript", "shared/AssetReferences.lua", assetReferencesSource);
  writeScript("ServerScriptService.Server.Main", "Script", "server/Main.server.lua", mainSource);
  writeScript("ServerScriptService.Server.Services.ProfileServiceWrapper", "ModuleScript", "server/Services/ProfileServiceWrapper.lua", profileServiceSource);
  writeScript("ServerScriptService.Server.Services.AssetService", "ModuleScript", "server/Services/AssetService.lua", assetServiceSource);
  writeScript("ServerScriptService.Server.Services.EconomyService", "ModuleScript", "server/Services/EconomyService.lua", economyServiceSource);
  writeScript("ServerScriptService.Server.Services.InventoryService", "ModuleScript", "server/Services/InventoryService.lua", inventoryServiceSource);
  writeScript("ServerScriptService.Server.Services.CollectionService", "ModuleScript", "server/Services/CollectionService.lua", collectionServiceSource);
  writeScript("ServerScriptService.Server.Services.QuestService", "ModuleScript", "server/Services/QuestService.lua", questServiceSource);
  writeScript("ServerScriptService.Server.Services.UpgradeService", "ModuleScript", "server/Services/UpgradeService.lua", upgradeServiceSource);
  writeScript("ServerScriptService.Server.Services.TutorialService", "ModuleScript", "server/Services/TutorialService.lua", tutorialServiceSource);
  writeScript("ServerScriptService.Server.Services.ShopService", "ModuleScript", "server/Services/ShopService.lua", shopServiceSource);
  writeScript("ServerScriptService.Server.Services.RebirthService", "ModuleScript", "server/Services/RebirthService.lua", rebirthServiceSource);
  writeScript("ServerScriptService.Server.Services.EventService", "ModuleScript", "server/Services/EventService.lua", eventServiceSource);
  writeScript("ServerScriptService.Server.Services.VoidService", "ModuleScript", "server/Services/VoidService.lua", voidServiceSource);
  writeScript("ServerScriptService.Server.Services.SnackService", "ModuleScript", "server/Services/SnackService.lua", snackServiceSource);
  writeScript("ServerScriptService.Server.Services.VoidmiteService", "ModuleScript", "server/Services/VoidmiteService.lua", voidmiteServiceSource);
  writeScript("StarterPlayer.StarterPlayerScripts.ClientMain", "LocalScript", "client/ClientMain.client.lua", clientMainSource);
  writeScript("StarterPlayer.StarterPlayerScripts.Controllers.UIController", "ModuleScript", "client/Controllers/UIController.lua", uiControllerSource);
}

addPhase2FoldersAndRemotes();
addPhase2Ui();
addPhase2Scripts();

const blueprint = {
  ...baseBlueprint,
  name: "FEED THE VOID Phase 2 Asset-Ready Replayability",
  description: "Adds asset fallbacks, expanded snacks/mutations, server-owned collections, session objectives, upgrades, rebirth/event polish, and complete mobile UI panels without replacing the working Phase 1.5 foundation.",
  steps,
  metadata: {
    phase: "2",
    generatedAt: new Date().toISOString(),
    baseBlueprint: path.relative(root, phase15BlueprintPath).replace(/\\/g, "/"),
    sourceHashes: {
      GameConfig: sourceHash(gameConfigSource),
      SnackConfig: sourceHash(snackConfigSource),
      MutationConfig: sourceHash(mutationConfigSource),
      EventConfig: sourceHash(eventConfigSource),
      AssetService: sourceHash(assetServiceSource),
      Main: sourceHash(mainSource),
      UIController: sourceHash(uiControllerSource),
    },
  },
};

fs.writeFileSync(blueprintPath, JSON.stringify(blueprint, null, 2), "utf8");

console.log(JSON.stringify({
  ok: true,
  blueprintPath,
  outDir,
  stepCount: steps.length,
  sourceCount: Object.keys(blueprint.metadata.sourceHashes).length,
}, null, 2));
