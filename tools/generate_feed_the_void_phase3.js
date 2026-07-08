const childProcess = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const phase2Generator = path.join(__dirname, "generate_feed_the_void_phase2.js");
const phase2Dir = path.join(root, "build", "feed_the_void_phase2");
const phase2BlueprintPath = path.join(phase2Dir, "feed_the_void_phase2.blueprint.json");
const outDir = path.join(root, "build", "feed_the_void_phase3");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase3.blueprint.json");

childProcess.execFileSync(process.execPath, [phase2Generator], { cwd: root, stdio: "inherit" });
fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(srcDir, { recursive: true });
fs.cpSync(path.join(phase2Dir, "src"), srcDir, { recursive: true });

const baseBlueprint = JSON.parse(fs.readFileSync(phase2BlueprintPath, "utf8"));

const scriptOverrides = new Set([
  "ReplicatedStorage.Shared.GameConfig",
  "ReplicatedStorage.Shared.SnackConfig",
  "ReplicatedStorage.Shared.AssetImportGuide",
  "ServerScriptService.Server.Main",
  "ServerScriptService.Server.Services.MapService",
  "ServerScriptService.Server.Services.PlotService",
  "ServerScriptService.Server.Services.EconomyService",
  "ServerScriptService.Server.Services.UpgradeService",
  "ServerScriptService.Server.Services.VoidService",
  "ServerScriptService.Server.Services.VoidmiteService",
  "ServerScriptService.Server.Services.EventService",
  "ServerScriptService.Server.Services.TutorialService",
  "ServerScriptService.Server.Services.VisitRewardService",
  "ServerScriptService.Server.Services.SnackService",
  "StarterPlayer.StarterPlayerScripts.ClientMain",
  "StarterPlayer.StarterPlayerScripts.Controllers.UIController",
  "StarterPlayer.StarterPlayerScripts.Controllers.VFXController",
]);

const removedInstancePathPrefixes = [
  "StarterGui.MainUI.BottomNav.ShopButton",
];

function isRemovedInheritedInstanceStep(baseStep) {
  const stepPath = String(baseStep.path || "");
  return removedInstancePathPrefixes.some((prefix) => stepPath === prefix || stepPath.startsWith(`${prefix}.`));
}

const steps = baseBlueprint.steps
  .filter((baseStep) => !isRemovedInheritedInstanceStep(baseStep))
  .filter((baseStep) => !(baseStep.type === "writeScript" && scriptOverrides.has(baseStep.path)))
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
const nr = (min, max) => ({ __type: "NumberRange", min, max });
const ns = (...keypoints) => ({ __type: "NumberSequence", keypoints });
const cs = (...colors) => ({ __type: "ColorSequence", colors });

function step(type, pathName, extra = {}) {
  return { type, path: pathName, ...extra };
}

function readSource(name) {
  return fs.readFileSync(path.join(srcDir, name), "utf8");
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

function replaceRequired(source, search, replacement, label) {
  if (!source.includes(search)) {
    throw new Error(`Missing patch anchor: ${label}`);
  }
  return source.replace(search, replacement);
}

function regexReplaceRequired(source, regex, replacement, label) {
  if (!regex.test(source)) {
    throw new Error(`Missing regex patch anchor: ${label}`);
  }
  return source.replace(regex, replacement);
}

function ensureFolder(pathName) {
  steps.push(step("ensureFolder", pathName));
}

function inst(className, pathName, properties = {}, attributes) {
  steps.push(step("ensureInstance", pathName, { className, properties, attributes }));
  steps.push(step("setProperties", pathName, { properties }));
}

function part(pathName, properties, attributes) {
  steps.push(step("createPart", pathName, { properties, attributes }));
  steps.push(step("setProperties", pathName, { properties }));
}

function model(pathName, attributes) {
  steps.push(step("createModel", pathName, { attributes }));
}

function setProps(pathName, properties) {
  steps.push(step("setProperties", pathName, { properties }));
}

function sourceHash(source) {
  return "sha256:" + crypto.createHash("sha256").update(source.replace(/\r\n/g, "\n").trimStart()).digest("hex");
}

function patchGameConfig(source) {
  source = replaceRequired(source, "\tVoidHungerRequired = 100,", "\tVoidHungerRequired = 70,\n\tVoidHungerBase = 45,\n\tVoidHungerPerPlayer = 20,\n\tFallResetY = -45,", "GameConfig hunger");
  source = replaceRequired(source, "\tBaseVoidmiteSpawnInterval = 25,", "\tBaseVoidmiteSpawnInterval = 14,", "GameConfig voidmite base");
  source = replaceRequired(source, "\tMinVoidmiteSpawnInterval = 8,", "\tMinVoidmiteSpawnInterval = 6,", "GameConfig voidmite min");
  source = replaceRequired(source, "\t\t\tBaseCost = 250,", "\t\t\tBaseCost = 90,", "ExtraPlate cost");
  source = replaceRequired(source, "\t\t\tBaseCost = 150,", "\t\t\tBaseCost = 75,", "GrowSpeed cost");
  source = replaceRequired(source, "\t\t\tBaseCost = 200,", "\t\t\tBaseCost = 90,", "SellMultiplier cost");
  source = replaceRequired(source, "\t\t\tBaseCost = 220,", "\t\t\tBaseCost = 95,", "VoidReward cost");
  source = replaceRequired(source, "\t\t\tBaseCost = 180,", "\t\t\tBaseCost = 85,", "DisplayIncome cost");
  source = replaceRequired(source, "\t\t\tBaseCost = 180,", "\t\t\tBaseCost = 85,", "VoidmiteReward cost");
  source = regexReplaceRequired(source, /\tTutorialMessages = \{[\s\S]*?\n\t\},/, `\tTutorialMessages = {
\t\t"Welcome to FEED THE VOID.",
\t\t"Go to your lab and find the glowing grow plates.",
\t\t"Plant a Cookie Rock seed.",
\t\t"Wait for the snack to grow, then harvest it.",
\t\t"Open inventory and pick your snack.",
\t\t"Feed your snack to The Void.",
\t\t"Display a snack on your shelf.",
\t\t"Cleanse a Voidmite when it appears.",
\t\t"Complete objectives and buy your first upgrade.",
\t\t"Keep feeding The Void to start server events.",
\t},`, "Tutorial messages");
  return source;
}

function patchSnackConfig(source) {
  source = replaceRequired(source, "\t\tGrowTime = 20,", "\t\tGrowTime = 14,", "Cookie grow");
  source = replaceRequired(source, "\t\tBaseVoidValue = 10,", "\t\tBaseVoidValue = 16,", "Cookie void");
  source = replaceRequired(source, "\t\tGrowTime = 35,", "\t\tGrowTime = 28,", "Jelly grow");
  source = replaceRequired(source, "\t\tBaseVoidValue = 22,", "\t\tBaseVoidValue = 34,", "Jelly void");
  source = replaceRequired(source, "\t\tGrowTime = 60,", "\t\tGrowTime = 52,", "Meteor grow");
  source = replaceRequired(source, "\t\tBaseVoidValue = 60,", "\t\tBaseVoidValue = 75,", "Meteor void");
  source = replaceRequired(source, "\t\tGrowTime = 25,", "\t\tGrowTime = 20,", "Moon grow");
  source = replaceRequired(source, "\t\tBaseVoidValue = 14,", "\t\tBaseVoidValue = 22,", "Moon void");
  source = replaceRequired(source, "\t\tGrowTime = 40,", "\t\tGrowTime = 34,", "Bubble grow");
  source = replaceRequired(source, "\t\tBaseVoidValue = 30,", "\t\tBaseVoidValue = 42,", "Bubble void");
  return source;
}

function patchMain(source) {
  source = replaceRequired(source, '\t"AssetService",\n\t"EconomyService",', '\t"AssetService",\n\t"MapService",\n\t"EconomyService",', "Main service order");
  source = replaceRequired(source, 'print("[FEED THE VOID] Phase 2 server loaded.")', 'print("[FEED THE VOID] Phase 3 server loaded.")', "Main print");
  source = replaceRequired(source, "\tcontext.Services.PlotService.AssignPlot(player)\n", "\tcontext.Services.PlotService.AssignPlot(player)\n\tcontext.Services.MapService.TeleportPlayerSafe(player)\n", "Main setup map safe");
  return source;
}

function patchPlotService(source) {
  source = replaceRequired(source, '\t\t\tPlotService.Context.Services.EconomyService.Notify(player, "Your lab plot is ready.")\n\t\t\tPlotService.TeleportToPlot(player)', '\t\t\tPlotService.Context.Services.EconomyService.Notify(player, "Your lab plot is ready.")\n\t\t\tif PlotService.Context.Services.TutorialService then\n\t\t\t\tPlotService.Context.Services.TutorialService.Advance(player, 2)\n\t\t\tend\n\t\t\tPlotService.TeleportToPlot(player)', "PlotService tutorial advance");
  source = source.replace(/"EMPTY LAB"/g, '"Empty Lab"');
  source = replaceRequired(source, '\t\t\t\tlabel.Text = player.Name .. "\'s Lab"', '\t\t\t\tlabel.Text = player.DisplayName .. "\'s Lab"', "PlotService owner display name");
  return source;
}

function patchEconomyService(source) {
  source = replaceRequired(source, "local EconomyService = {}\n", `local EconomyService = {}

local function ensureLeaderstats(player)
\tlocal folder = player:FindFirstChild("leaderstats")
\tif not folder then
\t\tfolder = Instance.new("Folder")
\t\tfolder.Name = "leaderstats"
\t\tfolder.Parent = player
\tend
\tfor _, statName in ipairs({ "Rebirths", "Coins", "VoidTokens" }) do
\t\tif not folder:FindFirstChild(statName) then
\t\t\tlocal value = Instance.new("IntValue")
\t\t\tvalue.Name = statName
\t\t\tvalue.Parent = folder
\t\tend
\tend
\treturn folder
end

local function updateLeaderstats(player, data)
\tif not player or not data then
\t\treturn
\tend
\tlocal folder = ensureLeaderstats(player)
\tfolder.Rebirths.Value = math.floor(tonumber(data.Rebirths) or 0)
\tfolder.Coins.Value = math.floor(tonumber(data.Coins) or 0)
\tfolder.VoidTokens.Value = math.floor(tonumber(data.VoidTokens) or 0)
end
`, "Economy leaderstats helpers");
  source = replaceRequired(source, "function EconomyService.Sync(player)\n\tlocal snapshot = EconomyService.BuildSnapshot(player)\n\tif snapshot then", "function EconomyService.Sync(player)\n\tlocal data = EconomyService.GetData(player)\n\tupdateLeaderstats(player, data)\n\tlocal snapshot = EconomyService.BuildSnapshot(player)\n\tif snapshot then", "Economy Sync leaderstats");
  return source;
}

function patchUpgradeService(source) {
  source = replaceRequired(source, `local function rawUpgradeData(player)
\tlocal data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
\tdata.Upgrades = data.Upgrades or {}
\treturn data, data.Upgrades
end`, `local function rawUpgradeData(player)
\tlocal data = UpgradeService.Context.Services.ProfileServiceWrapper.GetData(player)
\tif not data then
\t\treturn nil, {}
\tend
\tdata.Upgrades = data.Upgrades or {}
\treturn data, data.Upgrades
end`, "UpgradeService raw data guard");
  return source;
}

function patchVoidService(source) {
  source = replaceRequired(source, "local TweenService = game:GetService(\"TweenService\")", "local Players = game:GetService(\"Players\")\nlocal TweenService = game:GetService(\"TweenService\")", "VoidService players");
  source = regexReplaceRequired(source, /local function requiredHunger\(\)[\s\S]*?end\n\nlocal function updateBillboard/, `local function requiredHunger()
\tlocal config = VoidService.Context.Config.GameConfig
\tif config.DebugFastVoid then
\t\treturn config.FastVoidHungerRequired
\tend
\tlocal activePlayers = math.max(1, #Players:GetPlayers())
\tlocal dynamic = (tonumber(config.VoidHungerBase) or 45) + (activePlayers * (tonumber(config.VoidHungerPerPlayer) or 20))
\treturn math.max(30, math.floor(dynamic))
end

local function updateBillboard`, "VoidService dynamic hunger");
  source = replaceRequired(source, '\tlocal core = world and world:FindFirstChild("CentralVoid") and world.CentralVoid:FindFirstChild("VoidCore")', '\tlocal core = world and world:FindFirstChild("CentralVoid") and world.CentralVoid:FindFirstChild("VoidCore")', "VoidService pulse anchor");
  return source;
}

function patchVoidmiteService(source) {
  return source;
}

function patchEventService(source) {
  const helper = `
local function spawnEventVortex(labelText, color)
\tlocal world = workspace:FindFirstChild("GameWorld")
\tlocal folder = world and world:FindFirstChild("EventObjects")
\tif not folder then
\t\treturn
\tend
\tlocal vortex = Instance.new("Part")
\tvortex.Name = "EventVortex"
\tvortex.Anchored = true
\tvortex.CanCollide = false
\tvortex.Shape = Enum.PartType.Ball
\tvortex.Material = Enum.Material.Neon
\tvortex.Color = color or Color3.fromRGB(170, 70, 255)
\tvortex.Transparency = 0.28
\tvortex.Size = Vector3.new(18, 5, 18)
\tvortex.Position = Vector3.new(0, 22, 0)
\tvortex.Parent = folder
\tlocal light = Instance.new("PointLight")
\tlight.Name = "EventVortexLight"
\tlight.Color = vortex.Color
\tlight.Brightness = 2
\tlight.Range = 70
\tlight.Parent = vortex
\tlocal gui = Instance.new("BillboardGui")
\tgui.Name = "EventVortexBillboard"
\tgui.AlwaysOnTop = true
\tgui.Size = UDim2.new(0, 260, 0, 62)
\tgui.StudsOffset = Vector3.new(0, 5, 0)
\tgui.Parent = vortex
\tlocal label = Instance.new("TextLabel")
\tlabel.Name = "Label"
\tlabel.BackgroundTransparency = 0.2
\tlabel.BackgroundColor3 = Color3.fromRGB(25, 18, 34)
\tlabel.TextColor3 = Color3.fromRGB(255, 246, 210)
\tlabel.TextScaled = true
\tlabel.TextWrapped = true
\tlabel.Font = Enum.Font.GothamBlack
\tlabel.Text = labelText or "VOID EVENT"
\tlabel.Size = UDim2.new(1, 0, 1, 0)
\tlabel.Parent = gui
end
`;
  source = replaceRequired(source, "local function collectCrumb(model, player)", `${helper}\nlocal function collectCrumb(model, player)`, "EventService vortex helper");
  source = replaceRequired(source, "\tif eventName == \"SnackRain\" then\n\t\tfor index = 1, math.min(config.CrumbCount, config.MaxActivePickups) do", "\tif eventName == \"SnackRain\" then\n\t\tspawnEventVortex(\"SNACK RAIN\", Color3.fromRGB(255, 180, 80))\n\t\tfor index = 1, math.min(config.CrumbCount, config.MaxActivePickups) do", "SnackRain vortex");
  source = replaceRequired(source, "\telseif eventName == \"VoidInfestation\" then\n\t\tcontext.Services.EconomyService.NotifyAll(\"The Voidmites are swarming the labs!\")", "\telseif eventName == \"VoidInfestation\" then\n\t\tspawnEventVortex(\"VOIDMITES SWARM\", Color3.fromRGB(175, 75, 255))\n\t\tcontext.Services.EconomyService.NotifyAll(\"Voidmites are swarming the labs!\")", "Infestation vortex");
  source = replaceRequired(source, "\telseif eventName == \"GoldenHunger\" then", "\telseif eventName == \"GoldenHunger\" then\n\t\tspawnEventVortex(\"GOLDEN HUNGER\", Color3.fromRGB(255, 215, 80))", "Golden vortex");
  source = replaceRequired(source, "\telseif eventName == \"MutationSurge\" then\n\t\tcontext.Services.EconomyService.NotifyAll(\"Rare mutations are stirring, but they are still rare.\")", "\telseif eventName == \"MutationSurge\" then\n\t\tspawnEventVortex(\"MUTATION SURGE\", Color3.fromRGB(90, 255, 190))\n\t\tcontext.Services.EconomyService.NotifyAll(\"Rare mutations are stirring, but they are still rare.\")", "Mutation vortex");
  return source;
}

function patchTutorialService(source) {
  source = replaceRequired(source, "local maxStep = 8", "local maxStep = 10", "Tutorial max");
  source = replaceRequired(source, 'if action == "Plant" and step <= 2 then\n\t\tTutorialService.Advance(player, 3)\n\telseif action == "Harvest" and step <= 3 then\n\t\tTutorialService.Advance(player, 4)\n\telseif (action == "Sell" or action == "FeedVoid") and step <= 5 then\n\t\tTutorialService.Advance(player, 6)\n\telseif action == "Display" and step <= 6 then\n\t\tTutorialService.Advance(player, 7)\n\telseif action == "CleanseVoidmite" and step <= 7 then\n\t\tTutorialService.Advance(player, 8)\n\telseif action == "FeedVoid" and step <= 8 then\n\t\tTutorialService.Advance(player, 9)\n\tend', 'if action == "Plant" and step <= 3 then\n\t\tTutorialService.Advance(player, 4)\n\telseif action == "Harvest" and step <= 4 then\n\t\tTutorialService.Advance(player, 5)\n\telseif action == "FeedVoid" and step <= 6 then\n\t\tTutorialService.Advance(player, 7)\n\telseif action == "Display" and step <= 7 then\n\t\tTutorialService.Advance(player, 8)\n\telseif action == "CleanseVoidmite" and step <= 8 then\n\t\tTutorialService.Advance(player, 9)\n\telseif action == "BuyUpgrade" and step <= 9 then\n\t\tTutorialService.Advance(player, 10)\n\tend', "Tutorial actions");
  return source;
}

function patchSnackService(source) {
  source = replaceRequired(source, '\t\t\telseif prompt.Name == "BuySeedPrompt" then\n\t\t\t\tprompt.ActionText = "Buy Seeds"\n\t\t\t\tprompt.ObjectText = "Seed Shop"\n\t\t\t\tprompt.Triggered:Connect(function(player)\n\t\t\t\t\tSnackService.Context.Services.EconomyService.Notify(player, "Open the shop panel to buy seeds.")\n\t\t\t\t\tSnackService.Context.Services.EconomyService.Sync(player)\n\t\t\t\tend)\n\t\t\tend', '\t\t\telseif prompt.Name == "BuySeedPrompt" then\n\t\t\t\tprompt.ActionText = "Buy Seeds"\n\t\t\t\tprompt.ObjectText = "Seed Shop"\n\t\t\t\tprompt.Triggered:Connect(function(player)\n\t\t\t\t\tSnackService.Context.Services.EconomyService.Notify(player, "Open the shop panel to buy seeds.")\n\t\t\t\t\tSnackService.Context.Services.EconomyService.Sync(player)\n\t\t\t\tend)\n\t\t\telseif prompt.Name == "UpgradePrompt" then\n\t\t\t\tprompt.ActionText = "Open Upgrades"\n\t\t\t\tprompt.ObjectText = "Upgrade Terminal"\n\t\t\t\tprompt.Triggered:Connect(function(player)\n\t\t\t\t\tSnackService.Context.Services.EconomyService.Notify(player, "Open UPGRADES and buy your first lab boost.")\n\t\t\t\t\tSnackService.Context.Services.EconomyService.Sync(player)\n\t\t\t\tend)\n\t\t\tend', "SnackService upgrade prompt");
  return source;
}

function patchClientMain(source) {
  source = replaceRequired(source, 'local PromptController = require(controllers:WaitForChild("PromptController"))', 'local PromptController = require(controllers:WaitForChild("PromptController"))\nlocal VFXController = require(controllers:WaitForChild("VFXController"))', "ClientMain require VFX");
  source = replaceRequired(source, "PromptController.Init()\n\nNotificationController.Show(\"FEED THE VOID Phase 2 loaded.\")", "PromptController.Init()\nVFXController.Init(mainUi)\n\nNotificationController.Show(\"FEED THE VOID Phase 3 loaded.\")", "ClientMain init VFX");
  return source;
}

function patchUIController(source) {
  source = replaceRequired(source, 'local ReplicatedStorage = game:GetService("ReplicatedStorage")', 'local Players = game:GetService("Players")\nlocal ReplicatedStorage = game:GetService("ReplicatedStorage")', "UIController Players");
  source = replaceRequired(source, 'local majorPanels = { "InventoryPanel", "SeedShopPanel", "UpgradePanel", "CollectionPanel", "RebirthPanel" }\n', `local majorPanels = { "InventoryPanel", "SeedShopPanel", "UpgradePanel", "CollectionPanel", "RebirthPanel" }
local player = Players.LocalPlayer

local function getRoot()
\tlocal character = player.Character
\treturn character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function distanceTo(instance)
\tlocal root = getRoot()
\tif not root or typeof(instance) ~= "Instance" then
\t\treturn math.huge
\tend
\tlocal position
\tif instance:IsA("Model") then
\t\tposition = instance:GetPivot().Position
\telseif instance:IsA("BasePart") then
\t\tposition = instance.Position
\tend
\treturn position and (root.Position - position).Magnitude or math.huge
end

local function nearestChild(folder, predicate, maxDistance)
\tlocal best = nil
\tlocal bestDistance = maxDistance or math.huge
\tif not folder then
\t\treturn nil
\tend
\tfor _, child in ipairs(folder:GetChildren()) do
\t\tif not predicate or predicate(child) then
\t\t\tlocal dist = distanceTo(child)
\t\t\tif dist < bestDistance then
\t\t\t\tbest = child
\t\t\t\tbestDistance = dist
\t\t\tend
\t\tend
\tend
\treturn best
end

local function scanPlotsForStation(stationName, maxDistance)
\tlocal world = workspace:FindFirstChild("GameWorld")
\tlocal plots = world and world:FindFirstChild("Plots")
\tlocal best = nil
\tlocal bestDistance = maxDistance or math.huge
\tif not plots then
\t\treturn nil
\tend
\tfor _, plot in ipairs(plots:GetChildren()) do
\t\tlocal station = plot:FindFirstChild(stationName)
\t\tlocal dist = station and distanceTo(station) or math.huge
\t\tif dist < bestDistance then
\t\t\tbest = station
\t\t\tbestDistance = dist
\t\tend
\tend
\treturn best
end

local function getNearestAction()
\tlocal world = workspace:FindFirstChild("GameWorld")
\tif not world then
\t\treturn { Label = "ACTION", Kind = "None" }
\tend
\tlocal voidmite = nearestChild(world:FindFirstChild("ActiveVoidmites"), nil, 16)
\tif voidmite then
\t\treturn { Label = "CLEANSE", Kind = "Cleanse", Target = voidmite }
\tend
\tlocal plots = world:FindFirstChild("Plots")
\tlocal bestPlate = nil
\tlocal bestPlateDistance = 17
\tif plots then
\t\tfor _, plot in ipairs(plots:GetChildren()) do
\t\t\tlocal plates = plot:FindFirstChild("Plates")
\t\t\tif plates then
\t\t\t\tfor _, plate in ipairs(plates:GetChildren()) do
\t\t\t\t\tif plate:IsA("BasePart") then
\t\t\t\t\t\tlocal dist = distanceTo(plate)
\t\t\t\t\t\tif dist < bestPlateDistance then
\t\t\t\t\t\t\tbestPlate = plate
\t\t\t\t\t\t\tbestPlateDistance = dist
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\tend
\t\tend
\tend
\tif bestPlate and bestPlate:GetAttribute("Occupied") and tonumber(bestPlate:GetAttribute("GrowthStage")) == 3 then
\t\treturn { Label = "HARVEST", Kind = "Harvest", Target = bestPlate }
\tend
\tlocal central = world:FindFirstChild("CentralVoid")
\tlocal feedStation = central and central:FindFirstChild("FeedStation")
\tif selectedItemId and feedStation and distanceTo(feedStation) <= 30 then
\t\treturn { Label = "FEED", Kind = "Feed" }
\tend
\tlocal sellStation = selectedItemId and scanPlotsForStation("SellStation", 22)
\tif sellStation then
\t\treturn { Label = "SELL", Kind = "Sell" }
\tend
\tlocal displayShelf = selectedItemId and scanPlotsForStation("DisplayShelf", 22)
\tif displayShelf then
\t\treturn { Label = "DISPLAY", Kind = "Display" }
\tend
\tlocal shopStation = scanPlotsForStation("SeedShopStation", 18)
\tif shopStation then
\t\treturn { Label = "SEEDS", Kind = "Shop" }
\tend
\tif bestPlate and not bestPlate:GetAttribute("Occupied") then
\t\treturn { Label = "PLANT", Kind = "Plant", Target = bestPlate }
\tend
\treturn { Label = selectedItemId and "FEED" or "PLANT", Kind = selectedItemId and "Feed" or "Plant" }
end

local function updateMobileActionButton(button)
\tlocal action = getNearestAction()
\tbutton.Text = action.Label or "ACTION"
\tbutton:SetAttribute("ActionKind", action.Kind or "None")
end
`, "UIController action helpers");
  source = source.replace("\tnav.ShopButton.Activated:Connect(function() showPanel(\"SeedShopPanel\") end)", "\tlocal seedNavButton = nav:FindFirstChild(\"SeedsButton\") or nav:FindFirstChild(\"ShopButton\")\n\tif seedNavButton then\n\t\tseedNavButton.Activated:Connect(function() showPanel(\"SeedShopPanel\") end)\n\tend");
  source = replaceRequired(source, "\tnav.MobileActionButton.Activated:Connect(function()\n\t\tRemotes.RequestPlantSnack:FireServer(nil, selectedSeedId)\n\tend)", `\tnav.MobileActionButton.Activated:Connect(function()
\t\tlocal action = getNearestAction()
\t\tif action.Kind == "Harvest" then
\t\t\tRemotes.RequestHarvestSnack:FireServer(action.Target)
\t\telseif action.Kind == "Cleanse" then
\t\t\tRemotes.RequestClearVoidmite:FireServer(action.Target)
\t\telseif action.Kind == "Feed" then
\t\t\tRemotes.RequestFeedVoid:FireServer(selectedItemId)
\t\telseif action.Kind == "Sell" then
\t\t\tRemotes.RequestSellSnack:FireServer(selectedItemId)
\t\telseif action.Kind == "Display" then
\t\t\tRemotes.RequestDisplaySnack:FireServer(selectedItemId)
\t\telseif action.Kind == "Shop" then
\t\t\tshowPanel("SeedShopPanel")
\t\telse
\t\t\tRemotes.RequestPlantSnack:FireServer(action.Target, selectedSeedId)
\t\tend
\tend)
\ttask.spawn(function()
\t\twhile mainUi and mainUi.Parent do
\t\t\tupdateMobileActionButton(nav.MobileActionButton)
\t\t\ttask.wait(0.35)
\t\tend
\tend)`, "UIController mobile action");
  source = replaceRequired(source, '\t\t\tclose.Activated:Connect(function()\n\t\t\t\tshowPanel("SeedShopPanel")\n\t\t\tend)', '\t\t\tclose.Activated:Connect(function()\n\t\t\t\tshowPanel(nil)\n\t\t\tend)', "UIController close hides panels");
  return source;
}

const mapServiceSource = `
local Players = game:GetService("Players")

local MapService = {}

local requiredFolders = {
\t"CentralArena",
\t"PlotIslands",
\t"Bridges",
\t"Stations",
\t"Decorations",
\t"EventObjects",
\t"SpawnPoints",
}

local function getWorld()
\treturn workspace:WaitForChild("GameWorld")
end

local function ensureFolder(parent, name)
\tlocal folder = parent:FindFirstChild(name)
\tif not folder then
\t\tfolder = Instance.new("Folder")
\t\tfolder.Name = name
\t\tfolder:SetAttribute("GeneratedByMapService", true)
\t\tfolder.Parent = parent
\tend
\treturn folder
end

local function ownerLabel(plot)
\tlocal sign = plot and plot:FindFirstChild("OwnerSign")
\tlocal gui = sign and sign:FindFirstChild("OwnerBillboard")
\treturn gui and gui:FindFirstChild("OwnerLabel") or nil
end

function MapService.Init(context)
\tMapService.Context = context
end

function MapService.VerifyWorld()
\tlocal world = getWorld()
\tfor _, folderName in ipairs(requiredFolders) do
\t\tensureFolder(world, folderName)
\tend
\tlocal plots = world:FindFirstChild("Plots")
\tif not plots then
\t\twarn("[FEED THE VOID] GameWorld.Plots is missing; the blueprint should place real plot islands in Studio.")
\t\treturn
\tend
\tfor index = 1, 8 do
\t\tlocal plot = plots:FindFirstChild("Plot" .. tostring(index))
\t\tif plot then
\t\t\tplot:SetAttribute("PlotId", index)
\t\t\tif plot:GetAttribute("OwnerUserId") == nil then
\t\t\t\tplot:SetAttribute("OwnerUserId", 0)
\t\t\tend
\t\t\tlocal label = ownerLabel(plot)
\t\t\tif label and tonumber(plot:GetAttribute("OwnerUserId")) == 0 then
\t\t\t\tlabel.Text = "Empty Lab"
\t\t\tend
\t\tend
\tend
end

function MapService.GetCentralSpawnCFrame()
\tlocal world = workspace:FindFirstChild("GameWorld")
\tlocal spawn = world and world:FindFirstChild("SpawnPoints") and world.SpawnPoints:FindFirstChild("CentralSpawn")
\tif spawn and spawn:IsA("BasePart") then
\t\treturn spawn.CFrame + Vector3.new(0, 4, 0)
\tend
\treturn CFrame.new(0, 7, -36)
end

function MapService.TeleportPlayerSafe(player)
\tlocal character = player.Character
\tlocal root = character and character:FindFirstChild("HumanoidRootPart")
\tif not root then
\t\treturn
\tend
\tlocal plot = MapService.Context.Services.PlotService.GetPlot(player)
\tlocal spawnPart = plot and plot:FindFirstChild("PlotSpawn")
\tif spawnPart and spawnPart:IsA("BasePart") then
\t\troot.CFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
\telse
\t\troot.CFrame = MapService.GetCentralSpawnCFrame()
\tend
end

function MapService.Start()
\tMapService.VerifyWorld()
\ttask.spawn(function()
\t\twhile true do
\t\t\ttask.wait(1)
\t\t\tlocal resetY = MapService.Context.Config.GameConfig.FallResetY or -45
\t\t\tfor _, player in ipairs(Players:GetPlayers()) do
\t\t\t\tlocal character = player.Character
\t\t\t\tlocal root = character and character:FindFirstChild("HumanoidRootPart")
\t\t\t\tif root and root.Position.Y < resetY then
\t\t\t\t\tMapService.TeleportPlayerSafe(player)
\t\t\t\t\tMapService.Context.Services.EconomyService.Notify(player, "Back to solid ground.")
\t\t\t\tend
\t\t\tend
\t\tend
\tend)
end

return MapService
`;

const vfxControllerSource = `
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VFXController = {}

local mainUi
local rewardFrame
local rewardIndex = 1
local rewardLabels = {}

local function getPrimaryPart(model)
\tif model:IsA("BasePart") then
\t\treturn model
\tend
\tif model.PrimaryPart then
\t\treturn model.PrimaryPart
\tend
\tfor _, child in ipairs(model:GetDescendants()) do
\t\tif child:IsA("BasePart") then
\t\t\treturn child
\t\tend
\tend
\treturn nil
end

local function pulseModel(model)
\tfor _, child in ipairs(model:GetDescendants()) do
\t\tif child:IsA("BasePart") then
\t\t\tlocal original = child.Size
\t\t\tlocal grow = TweenService:Create(child, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original * 1.12 })
\t\t\tlocal shrink = TweenService:Create(child, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = original })
\t\t\tgrow:Play()
\t\t\tgrow.Completed:Once(function()
\t\t\t\tif child.Parent then
\t\t\t\t\tshrink:Play()
\t\t\t\tend
\t\t\tend)
\t\tend
\tend
end

local function popIn(model)
\tfor _, child in ipairs(model:GetDescendants()) do
\t\tif child:IsA("BasePart") then
\t\t\tlocal original = child.Size
\t\t\tchild.Size = original * 0.35
\t\t\tTweenService:Create(child, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = original }):Play()
\t\tend
\tend
end

local function sparkleAt(model, color)
\tlocal part = getPrimaryPart(model)
\tif not part then
\t\treturn
\tend
\tlocal light = Instance.new("PointLight")
\tlight.Name = "FTVLocalSparkle"
\tlight.Brightness = 1.6
\tlight.Range = 12
\tlight.Color = color or Color3.fromRGB(190, 90, 255)
\tlight.Parent = part
\tTweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
\tDebris:AddItem(light, 0.45)
end

local function showRewardText(message)
\tif not rewardFrame then
\t\treturn
\tend
\tlocal label = rewardLabels[rewardIndex]
\trewardIndex = (rewardIndex % #rewardLabels) + 1
\tif not label then
\t\treturn
\tend
\tlocal startY = 18 + ((rewardIndex - 1) * 8)
\tlabel.Text = message
\tlabel.Visible = true
\tlabel.TextTransparency = 0
\tlabel.BackgroundTransparency = 0.22
\tlabel.Position = UDim2.new(0.5, -150, 0, startY)
\tlocal tween = TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
\t\tPosition = UDim2.new(0.5, -150, 0, startY - 34),
\t\tTextTransparency = 1,
\t\tBackgroundTransparency = 1,
\t})
\ttween:Play()
\ttween.Completed:Once(function()
\t\tlabel.Visible = false
\tend)
end

local function watchModel(model)
\tpopIn(model)
\tmodel:GetAttributeChangedSignal("GrowthStage"):Connect(function()
\t\tpulseModel(model)
\tend)
end

local function attachWorldWatchers()
\tlocal world = workspace:WaitForChild("GameWorld", 10)
\tif not world then
\t\treturn
\tend
\tlocal snacks = world:WaitForChild("ActiveSnacks", 10)
\tif snacks then
\t\tfor _, child in ipairs(snacks:GetChildren()) do
\t\t\twatchModel(child)
\t\tend
\t\tsnacks.ChildAdded:Connect(watchModel)
\tend
\tlocal voidmites = world:WaitForChild("ActiveVoidmites", 10)
\tif voidmites then
\t\tvoidmites.ChildAdded:Connect(function(child)
\t\t\tpopIn(child)
\t\t\tsparkleAt(child, Color3.fromRGB(170, 80, 255))
\t\tend)
\tend
\tlocal events = world:WaitForChild("EventObjects", 10)
\tif events then
\t\tevents.ChildAdded:Connect(function(child)
\t\t\tsparkleAt(child, Color3.fromRGB(255, 180, 80))
\t\tend)
\tend
end

function VFXController.Init(ui)
\tmainUi = ui
\trewardFrame = mainUi:FindFirstChild("FloatingRewards")
\tif rewardFrame then
\t\tfor index = 1, 5 do
\t\t\trewardLabels[index] = rewardFrame:FindFirstChild("Reward" .. tostring(index))
\t\tend
\tend
\tlocal remotes = ReplicatedStorage:WaitForChild("Remotes")
\tremotes.NotifyClient.OnClientEvent:Connect(function(message)
\t\tmessage = tostring(message or "")
\t\tif message:find("%+") or message:find("complete") or message:find("harvest") or message:find("fed") or message:find("cleansed") then
\t\t\tshowRewardText(message)
\t\tend
\tend)
\ttask.spawn(attachWorldWatchers)
end

return VFXController
`;

const assetImportGuideSource = `
local AssetImportGuide = {
\tSummary = "Place imported Meshy models under ReplicatedStorage.Assets.Models using these exact names. Missing models are safe: AssetService will warn once and use placeholders.",
\tRequiredPaths = {
\t\t"The Void: ReplicatedStorage.Assets.Models.Void.FTW_TheVoid",
\t\t"Voidmite: ReplicatedStorage.Assets.Models.Creatures.FTW_Voidmite",
\t\t"Round snack: ReplicatedStorage.Assets.Models.Snacks.FTW_Snack_RoundBase",
\t\t"Cube snack: ReplicatedStorage.Assets.Models.Snacks.FTW_Snack_CubeBase",
\t\t"Wrap snack: ReplicatedStorage.Assets.Models.Snacks.FTW_Snack_WrapBase",
\t\t"Grow plate: ReplicatedStorage.Assets.Models.Plot.FTW_GrowPlate",
\t\t"Display pedestal: ReplicatedStorage.Assets.Models.Plot.FTW_DisplayPedestal",
\t\t"Seed machine: ReplicatedStorage.Assets.Models.Stations.FTW_SeedShopMachine",
\t\t"Sell station: ReplicatedStorage.Assets.Models.Stations.FTW_SellStation",
\t\t"Void crumb: ReplicatedStorage.Assets.Models.Pickups.FTW_VoidCrumbPickup",
\t\t"Void shard: ReplicatedStorage.Assets.Models.Pickups.FTW_VoidShardPickup",
\t},
}

return AssetImportGuide
`;

const visitRewardServiceSource = `
local VisitRewardService = {}

function VisitRewardService.Init(context)
\tVisitRewardService.Context = context
end

function VisitRewardService.Start() end

function VisitRewardService.ApplyJoinReward(player)
\tlocal context = VisitRewardService.Context
\tlocal data = context.Services.ProfileServiceWrapper.GetData(player)
\tif not data then
\t\treturn
\tend
\tdata.LastLogout = os.time()
\tcontext.Services.ProfileServiceWrapper.MarkDirty(player)
end

return VisitRewardService
`;

function addPhase3World() {
  [
    "Workspace.GameWorld.CentralArena",
    "Workspace.GameWorld.PlotIslands",
    "Workspace.GameWorld.Bridges",
    "Workspace.GameWorld.Stations",
    "Workspace.GameWorld.Decorations",
    "Workspace.GameWorld.SpawnPoints",
  ].forEach(ensureFolder);

  steps.push(step("setLighting", "Lighting", {
    properties: {
      ClockTime: 18.4,
      Brightness: 2.2,
      Ambient: c3(74, 54, 96),
      OutdoorAmbient: c3(98, 78, 128),
      FogColor: c3(62, 38, 86),
      FogStart: 140,
      FogEnd: 360,
    },
  }));
  inst("BloomEffect", "Lighting.FTV_Bloom", { Intensity: 0.35, Size: 28, Threshold: 1.2 });
  inst("ColorCorrectionEffect", "Lighting.FTV_Color", { Brightness: 0.02, Contrast: 0.12, Saturation: 0.12, TintColor: c3(225, 205, 255) });
  inst("Atmosphere", "Lighting.FTV_Atmosphere", { Density: 0.28, Offset: 0.1, Color: c3(126, 92, 170), Decay: c3(42, 24, 66), Glare: 0.12, Haze: 1.15 });

  setProps("Workspace.GameWorld.VoidLabFloor", {
    Transparency: 1,
    CanCollide: false,
    CanTouch: false,
    CanQuery: false,
  });

  part("Workspace.GameWorld.CentralArena.ArenaBase", {
    Anchored: true,
    CanCollide: true,
    Shape: "Cylinder",
    Size: v3(94, 2, 94),
    Position: v3(0, 0.4, 0),
    Orientation: v3(0, 0, 0),
    Color: c3(34, 30, 45),
    Material: "Slate",
  }, { GeneratedByMapService: true });
  part("Workspace.GameWorld.CentralArena.VoidPitGlow", {
    Anchored: true,
    CanCollide: false,
    Shape: "Cylinder",
    Size: v3(34, 0.35, 34),
    Position: v3(0, 1.6, 0),
    Color: c3(148, 58, 255),
    Material: "Neon",
    Transparency: 0.18,
  }, { GeneratedByMapService: true });
  part("Workspace.GameWorld.CentralArena.InnerRing", {
    Anchored: true,
    CanCollide: true,
    Shape: "Cylinder",
    Size: v3(52, 0.45, 52),
    Position: v3(0, 1.9, 0),
    Color: c3(50, 38, 72),
    Material: "Concrete",
    Transparency: 0.05,
  }, { GeneratedByMapService: true });
  part("Workspace.GameWorld.SpawnPoints.CentralSpawn", {
    Anchored: true,
    CanCollide: false,
    Size: v3(9, 1, 9),
    Position: v3(0, 3, -36),
    Color: c3(100, 235, 205),
    Material: "Neon",
    Transparency: 0.35,
  }, { GeneratedByMapService: true });
  setProps("Workspace.GameWorld.CentralVoid.VoidCore", {
    Size: v3(22, 22, 22),
    Position: v3(0, 15, 0),
    Color: c3(28, 8, 46),
    Material: "Neon",
  });
  setProps("Workspace.GameWorld.CentralVoid.FeedStation", {
    Size: v3(14, 1, 12),
    Position: v3(0, 2.4, -31),
    Color: c3(170, 74, 255),
    Material: "Neon",
  });
  inst("PointLight", "Workspace.GameWorld.CentralArena.VoidPitGlow.PitLight", {
    Brightness: 2.6,
    Range: 82,
    Color: c3(170, 74, 255),
    Shadows: false,
  });
  inst("ParticleEmitter", "Workspace.GameWorld.CentralVoid.VoidCore.VoidPulseParticles", {
    Rate: 7,
    Lifetime: nr(1.2, 2),
    Speed: nr(0.6, 1.8),
    Color: cs(c3(185, 80, 255), c3(90, 220, 255)),
    LightEmission: 0.45,
    Size: ns({ time: 0, value: 0.45 }, { time: 1, value: 0 }),
  });

  const accent = [
    c3(235, 75, 75),
    c3(245, 145, 50),
    c3(250, 220, 70),
    c3(85, 220, 105),
    c3(60, 220, 220),
    c3(85, 135, 255),
    c3(255, 100, 205),
    c3(180, 95, 255),
  ];
  const radius = 102;
  for (let i = 1; i <= 8; i += 1) {
    const angle = ((i - 1) / 8) * Math.PI * 2;
    const angleDeg = -angle * 180 / Math.PI + 90;
    const cx = Math.cos(angle) * radius;
    const cz = Math.sin(angle) * radius;
    const color = accent[i - 1];
    const plotPath = `Workspace.GameWorld.Plots.Plot${i}`;
    model(plotPath, { PlotId: i, OwnerUserId: 0, GeneratedByMapService: true });
    part(`Workspace.GameWorld.Bridges.Bridge${i}`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(16, 1.1, 78),
      Position: v3(Math.cos(angle) * 56, 0.9, Math.sin(angle) * 56),
      Orientation: v3(0, angleDeg, 0),
      Color: c3(38, 34, 52),
      Material: "Slate",
    }, { GeneratedByMapService: true, PlotId: i });
    part(`Workspace.GameWorld.Bridges.Bridge${i}Trim`, {
      Anchored: true,
      CanCollide: false,
      Size: v3(17, 0.25, 79),
      Position: v3(Math.cos(angle) * 56, 1.55, Math.sin(angle) * 56),
      Orientation: v3(0, angleDeg, 0),
      Color: color,
      Material: "Neon",
      Transparency: 0.45,
    }, { GeneratedByMapService: true, PlotId: i });
    part(`${plotPath}.Platform`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(48, 2, 40),
      Position: v3(cx, 1, cz),
      Orientation: v3(0, angleDeg, 0),
      Color: c3(39, 34, 49),
      Material: "Slate",
    }, { PlotId: i, GeneratedByMapService: true });
    part(`${plotPath}.AccentRing`, {
      Anchored: true,
      CanCollide: false,
      Size: v3(50, 0.35, 42),
      Position: v3(cx, 2.2, cz),
      Orientation: v3(0, angleDeg, 0),
      Color: color,
      Material: "Neon",
      Transparency: 0.65,
    }, { PlotId: i, GeneratedByMapService: true });
    part(`${plotPath}.PlotSpawn`, {
      Anchored: true,
      CanCollide: false,
      Size: v3(7, 1, 7),
      Position: v3(cx - Math.cos(angle) * 11, 3.1, cz - Math.sin(angle) * 11),
      Color: color,
      Material: "Neon",
      Transparency: 0.35,
    }, { PlotId: i, GeneratedByMapService: true });
    part(`${plotPath}.OwnerSign`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(15, 6, 0.8),
      Position: v3(cx - Math.cos(angle) * 22, 6, cz - Math.sin(angle) * 22),
      Orientation: v3(0, angleDeg, 0),
      Color: c3(28, 25, 36),
      Material: "SmoothPlastic",
    }, { PlotId: i, GeneratedByMapService: true });
    inst("BillboardGui", `${plotPath}.OwnerSign.OwnerBillboard`, {
      AlwaysOnTop: true,
      Size: ud2(0, 240, 0, 64),
      StudsOffset: v3(0, 4.5, 0),
    });
    inst("TextLabel", `${plotPath}.OwnerSign.OwnerBillboard.OwnerLabel`, {
      BackgroundTransparency: 0.18,
      BackgroundColor3: c3(24, 18, 34),
      Size: ud2(1, 0, 1, 0),
      Text: "Empty Lab",
      TextColor3: c3(255, 248, 220),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
    part(`${plotPath}.DisplayShelf`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(24, 2.2, 5),
      Position: v3(cx + Math.sin(angle) * 13, 3.1, cz - Math.cos(angle) * 13),
      Orientation: v3(0, angleDeg, 0),
      Color: c3(62, 48, 82),
      Material: "WoodPlanks",
    }, { PlotId: i, GeneratedByMapService: true });
    inst("ProximityPrompt", `${plotPath}.DisplayShelf.DisplayPrompt`, {
      ActionText: "Display Snack",
      ObjectText: "Display",
      HoldDuration: 0.2,
      MaxActivationDistance: 11,
    });
    inst("BillboardGui", `${plotPath}.DisplayShelf.DisplayBillboard`, { AlwaysOnTop: true, Size: ud2(0, 150, 0, 42), StudsOffset: v3(0, 3.2, 0) });
    inst("TextLabel", `${plotPath}.DisplayShelf.DisplayBillboard.Label`, { BackgroundTransparency: 0.2, BackgroundColor3: c3(24, 18, 34), Size: ud2(1, 0, 1, 0), Text: "Display", TextColor3: c3(255, 255, 255), TextScaled: true, Font: "GothamBold" });
    part(`${plotPath}.SellStation`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(6, 5, 5),
      Position: v3(cx - Math.sin(angle) * 18, 4.1, cz + Math.cos(angle) * 18),
      Orientation: v3(0, angleDeg, 0),
      Color: c3(65, 165, 105),
      Material: "Neon",
    }, { PlotId: i, GeneratedByMapService: true });
    inst("ProximityPrompt", `${plotPath}.SellStation.SellPrompt`, { ActionText: "Open Sell", ObjectText: "Sell", HoldDuration: 0.2, MaxActivationDistance: 11 });
    inst("BillboardGui", `${plotPath}.SellStation.SellBillboard`, { AlwaysOnTop: true, Size: ud2(0, 120, 0, 38), StudsOffset: v3(0, 4, 0) });
    inst("TextLabel", `${plotPath}.SellStation.SellBillboard.Label`, { BackgroundTransparency: 0.2, BackgroundColor3: c3(18, 32, 24), Size: ud2(1, 0, 1, 0), Text: "Sell", TextColor3: c3(255, 255, 255), TextScaled: true, Font: "GothamBold" });
    part(`${plotPath}.SeedShopStation`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(6, 5, 5),
      Position: v3(cx + Math.sin(angle) * 18, 4.1, cz - Math.cos(angle) * 18),
      Orientation: v3(0, angleDeg, 0),
      Color: c3(245, 170, 65),
      Material: "Neon",
    }, { PlotId: i, GeneratedByMapService: true });
    inst("ProximityPrompt", `${plotPath}.SeedShopStation.BuySeedPrompt`, { ActionText: "Buy Seeds", ObjectText: "Seeds", HoldDuration: 0.2, MaxActivationDistance: 11 });
    inst("BillboardGui", `${plotPath}.SeedShopStation.SeedsBillboard`, { AlwaysOnTop: true, Size: ud2(0, 130, 0, 38), StudsOffset: v3(0, 4, 0) });
    inst("TextLabel", `${plotPath}.SeedShopStation.SeedsBillboard.Label`, { BackgroundTransparency: 0.2, BackgroundColor3: c3(38, 26, 14), Size: ud2(1, 0, 1, 0), Text: "Seeds", TextColor3: c3(255, 255, 255), TextScaled: true, Font: "GothamBold" });
    part(`${plotPath}.UpgradeStation`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(6, 4.5, 5),
      Position: v3(cx + Math.cos(angle) * 16, 3.9, cz + Math.sin(angle) * 16),
      Orientation: v3(0, angleDeg, 0),
      Color: c3(120, 95, 215),
      Material: "Neon",
    }, { PlotId: i, GeneratedByMapService: true });
    inst("ProximityPrompt", `${plotPath}.UpgradeStation.UpgradePrompt`, { ActionText: "Open Upgrades", ObjectText: "Upgrades", HoldDuration: 0.2, MaxActivationDistance: 11 });
    inst("BillboardGui", `${plotPath}.UpgradeStation.UpgradeBillboard`, { AlwaysOnTop: true, Size: ud2(0, 150, 0, 38), StudsOffset: v3(0, 3.8, 0) });
    inst("TextLabel", `${plotPath}.UpgradeStation.UpgradeBillboard.Label`, { BackgroundTransparency: 0.2, BackgroundColor3: c3(26, 20, 42), Size: ud2(1, 0, 1, 0), Text: "Upgrades", TextColor3: c3(255, 255, 255), TextScaled: true, Font: "GothamBold" });
    inst("Folder", `${plotPath}.Plates`);
    for (let p = 1; p <= 10; p += 1) {
      const row = Math.floor((p - 1) / 5);
      const col = (p - 1) % 5;
      const localX = (col - 2) * 7;
      const localZ = row === 0 ? 3 : -5;
      const worldX = cx + Math.cos(angle) * localX - Math.sin(angle) * localZ;
      const worldZ = cz + Math.sin(angle) * localX + Math.cos(angle) * localZ;
      const unlocked = p <= 6;
      const platePath = `${plotPath}.Plates.Plate${p}`;
      part(platePath, {
        Anchored: true,
        CanCollide: true,
        Shape: "Cylinder",
        Size: v3(5.2, 0.45, 5.2),
        Position: v3(worldX, 2.6, worldZ),
        Orientation: v3(0, 0, 0),
        Color: unlocked ? color : c3(58, 52, 68),
        Material: unlocked ? "Neon" : "SmoothPlastic",
        Transparency: unlocked ? 0.15 : 0.38,
      }, { PlotId: i, PlateIndex: p, Occupied: false, GrowthStage: 0, GeneratedByMapService: true });
      inst("ProximityPrompt", `${platePath}.PlatePrompt`, {
        ActionText: unlocked ? "Plant Snack" : "Upgrade Plate",
        ObjectText: `Plate ${p}`,
        HoldDuration: 0.15,
        MaxActivationDistance: 9,
        Enabled: true,
      });
      inst("PointLight", `${platePath}.PlateGlow`, {
        Brightness: unlocked ? 0.8 : 0.25,
        Range: unlocked ? 11 : 6,
        Color: color,
        Shadows: false,
      });
    }
    for (let r = 1; r <= 4; r += 1) {
      const side = r <= 2 ? -1 : 1;
      const offset = r % 2 === 0 ? 17 : -17;
      part(`${plotPath}.Rail${r}`, {
        Anchored: true,
        CanCollide: true,
        Size: r <= 2 ? v3(44, 2.4, 0.8) : v3(0.8, 2.4, 36),
        Position: r <= 2 ? v3(cx + Math.cos(angle) * offset, 4.1, cz + Math.sin(angle) * offset) : v3(cx + Math.sin(angle) * side * 23, 4.1, cz - Math.cos(angle) * side * 23),
        Orientation: v3(0, angleDeg, 0),
        Color: color,
        Material: "Neon",
        Transparency: 0.45,
      }, { PlotId: i, GeneratedByMapService: true });
    }
  }

  for (let i = 1; i <= 16; i += 1) {
    const angle = (i / 16) * Math.PI * 2;
    const rockRadius = 60 + (i % 3) * 15;
    part(`Workspace.GameWorld.Decorations.FloatingRock${i}`, {
      Anchored: true,
      CanCollide: false,
      Size: v3(6 + (i % 3) * 2, 3 + (i % 2), 5 + (i % 4)),
      Position: v3(Math.cos(angle) * rockRadius, 6 + (i % 5) * 2, Math.sin(angle) * rockRadius),
      Orientation: v3((i * 13) % 25, (i * 41) % 180, (i * 17) % 20),
      Color: c3(48, 40, 62),
      Material: "Slate",
    }, { GeneratedByMapService: true });
  }
  for (let i = 1; i <= 12; i += 1) {
    const angle = (i / 12) * Math.PI * 2;
    const r = 30 + (i % 3) * 7;
    part(`Workspace.GameWorld.Decorations.VoidCrystal${i}`, {
      Anchored: true,
      CanCollide: false,
      Size: v3(2.4, 6 + (i % 4), 2.4),
      Position: v3(Math.cos(angle) * r, 4, Math.sin(angle) * r),
      Orientation: v3(0, (i * 33) % 180, 8),
      Color: i % 2 === 0 ? c3(175, 80, 255) : c3(70, 220, 255),
      Material: "Neon",
      Transparency: 0.18,
    }, { GeneratedByMapService: true });
  }
}

function addPhase3Ui() {
  inst("Frame", "StarterGui.MainUI.BottomNav", {
    BackgroundTransparency: 1,
    Size: ud2(1, -16, 0, 66),
    Position: ud2(0, 8, 1, -72),
  });
  [
    ["InventoryButton", "BAG", 0, c3(68, 128, 190)],
    ["SeedsButton", "SEEDS", 1, c3(70, 165, 92)],
    ["UpgradesButton", "UPGRADES", 2, c3(185, 135, 60)],
    ["CollectionButton", "INDEX", 3, c3(82, 150, 170)],
    ["RebirthButton", "REBIRTH", 4, c3(135, 78, 190)],
    ["MobileActionButton", "ACTION", 5, c3(205, 132, 55)],
  ].forEach(([name, text, index, color]) => {
    inst("TextButton", `StarterGui.MainUI.BottomNav.${name}`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(1 / 6, -6, 0, 56),
      Position: ud2(index / 6, 3, 0, 4),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  });
  inst("Frame", "StarterGui.MainUI.TutorialPanel", {
    BackgroundColor3: c3(42, 32, 58),
    BackgroundTransparency: 0.04,
    BorderSizePixel: 0,
    Size: ud2(0.9, 0, 0, 76),
    Position: ud2(0.05, 0, 0, 108),
    Visible: true,
  });
  inst("TextLabel", "StarterGui.MainUI.TutorialPanel.TutorialText", {
    BackgroundTransparency: 1,
    Size: ud2(1, -124, 1, -12),
    Position: ud2(0, 10, 0, 6),
    Text: "Welcome to FEED THE VOID.",
    TextColor3: c3(255, 246, 210),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("TextButton", "StarterGui.MainUI.TutorialPanel.SkipTutorialButton", {
    BackgroundColor3: c3(80, 64, 105),
    BorderSizePixel: 0,
    Size: ud2(0, 102, 0, 48),
    Position: ud2(1, -112, 0, 14),
    Text: "SKIP",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("Frame", "StarterGui.MainUI.FloatingRewards", {
    BackgroundTransparency: 1,
    Size: ud2(1, 0, 0, 160),
    Position: ud2(0, 0, 0, 184),
    Visible: true,
  });
  for (let i = 1; i <= 5; i += 1) {
    inst("TextLabel", `StarterGui.MainUI.FloatingRewards.Reward${i}`, {
      BackgroundTransparency: 0.22,
      BackgroundColor3: c3(24, 18, 34),
      BorderSizePixel: 0,
      Size: ud2(0, 300, 0, 34),
      Position: ud2(0.5, -150, 0, 18 + (i - 1) * 8),
      Visible: false,
      Text: "+25 Coins",
      TextColor3: c3(255, 235, 160),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBlack",
    });
  }
}

function addPhase3Scripts() {
  const gameConfig = patchGameConfig(readSource("shared/GameConfig.lua"));
  const snackConfig = patchSnackConfig(readSource("shared/SnackConfig.lua"));
  const main = patchMain(readSource("server/Main.server.lua"));
  const plot = patchPlotService(readSource("server/Services/PlotService.lua"));
  const economy = patchEconomyService(readSource("server/Services/EconomyService.lua"));
  const upgrade = patchUpgradeService(readSource("server/Services/UpgradeService.lua"));
  const voidService = patchVoidService(readSource("server/Services/VoidService.lua"));
  const voidmite = patchVoidmiteService(readSource("server/Services/VoidmiteService.lua"));
  const event = patchEventService(readSource("server/Services/EventService.lua"));
  const tutorial = patchTutorialService(readSource("server/Services/TutorialService.lua"));
  const snack = patchSnackService(readSource("server/Services/SnackService.lua"));
  const clientMain = patchClientMain(readSource("client/ClientMain.client.lua"));
  const ui = patchUIController(readSource("client/Controllers/UIController.lua"));

  writeScript("ReplicatedStorage.Shared.GameConfig", "ModuleScript", "shared/GameConfig.lua", gameConfig);
  writeScript("ReplicatedStorage.Shared.SnackConfig", "ModuleScript", "shared/SnackConfig.lua", snackConfig);
  writeScript("ReplicatedStorage.Shared.AssetImportGuide", "ModuleScript", "shared/AssetImportGuide.lua", assetImportGuideSource);
  writeScript("ServerScriptService.Server.Main", "Script", "server/Main.server.lua", main);
  writeScript("ServerScriptService.Server.Services.MapService", "ModuleScript", "server/Services/MapService.lua", mapServiceSource);
  writeScript("ServerScriptService.Server.Services.PlotService", "ModuleScript", "server/Services/PlotService.lua", plot);
  writeScript("ServerScriptService.Server.Services.EconomyService", "ModuleScript", "server/Services/EconomyService.lua", economy);
  writeScript("ServerScriptService.Server.Services.UpgradeService", "ModuleScript", "server/Services/UpgradeService.lua", upgrade);
  writeScript("ServerScriptService.Server.Services.VoidService", "ModuleScript", "server/Services/VoidService.lua", voidService);
  writeScript("ServerScriptService.Server.Services.VoidmiteService", "ModuleScript", "server/Services/VoidmiteService.lua", voidmite);
  writeScript("ServerScriptService.Server.Services.EventService", "ModuleScript", "server/Services/EventService.lua", event);
  writeScript("ServerScriptService.Server.Services.TutorialService", "ModuleScript", "server/Services/TutorialService.lua", tutorial);
  writeScript("ServerScriptService.Server.Services.VisitRewardService", "ModuleScript", "server/Services/VisitRewardService.lua", visitRewardServiceSource);
  writeScript("ServerScriptService.Server.Services.SnackService", "ModuleScript", "server/Services/SnackService.lua", snack);
  writeScript("StarterPlayer.StarterPlayerScripts.ClientMain", "LocalScript", "client/ClientMain.client.lua", clientMain);
  writeScript("StarterPlayer.StarterPlayerScripts.Controllers.UIController", "ModuleScript", "client/Controllers/UIController.lua", ui);
  writeScript("StarterPlayer.StarterPlayerScripts.Controllers.VFXController", "ModuleScript", "client/Controllers/VFXController.lua", vfxControllerSource);

  return { gameConfig, snackConfig, main, plot, economy, upgrade, voidService, voidmite, event, tutorial, visitRewardServiceSource, snack, clientMain, ui, mapServiceSource, vfxControllerSource };
}

addPhase3World();
addPhase3Ui();
const sources = addPhase3Scripts();

fs.writeFileSync(path.join(outDir, "PHASE3_TESTING.md"), `# FEED THE VOID Phase 3 Testing

## Solo visual smoke
- Press Play and confirm the map is a floating purple arena with 8 readable labs around The Void.
- Confirm the bottom nav fits the screen and the tutorial panel is readable.
- Confirm no duplicate old direct seed buttons appear; seed buttons should live under SeedList.

## Solo gameplay smoke
- Plant Cookie Rock, harvest it, open BAG, feed/sell/display it.
- Feed The Void until hunger moves and milestones announce once.
- Display a snack and wait for a Voidmite, then cleanse it.
- Buy one upgrade and complete one objective.
- Use !event SnackRain and confirm crumbs spawn/collect/cleanup.

## Asset import paths
See ReplicatedStorage.Shared.AssetImportGuide for exact Meshy model paths.
`, "utf8");

const blueprint = {
  ...baseBlueprint,
  name: "FEED THE VOID Phase 3 Map Feel Onboarding Polish",
  description: "Adds a floating purple arena map, 8 readable lab islands, map verification/fall safety, leaderstats, onboarding polish, mobile action behavior, early balance, and lightweight client-side feel without adding stealing/trading/pets.",
  steps,
  metadata: {
    phase: "3",
    generatedAt: new Date().toISOString(),
    baseBlueprint: path.relative(root, phase2BlueprintPath).replace(/\\/g, "/"),
    sourceHashes: Object.fromEntries(Object.entries(sources).map(([name, source]) => [name, sourceHash(source)])),
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
