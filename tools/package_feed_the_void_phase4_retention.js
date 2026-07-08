const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "build", "feed_the_void_phase4_retention");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase4_retention_overlay.blueprint.json");
const testingPath = path.join(outDir, "PHASE4_RETENTION_TESTING.md");

const steps = [];

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

function ensureFolder(pathName) {
  steps.push(step("ensureFolder", pathName));
}

function ensureRemote(name) {
  steps.push(step("ensureRemoteEvent", `ReplicatedStorage.Remotes.${name}`));
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

function relSource(relPath) {
  const filePath = path.join(srcDir, relPath);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing source file: ${filePath}`);
  }
  return path.relative(outDir, filePath).replace(/\\/g, "/");
}

function readSource(relPath) {
  return fs.readFileSync(path.join(srcDir, relPath), "utf8").replace(/\r\n/g, "\n").trimStart();
}

function sourceHash(relPath) {
  return "sha256:" + crypto.createHash("sha256").update(readSource(relPath)).digest("hex");
}

function writeScript(studioPath, className, relPath) {
  steps.push(step("writeScript", studioPath, {
    className,
    sourceFile: relSource(relPath),
    overwrite: true,
  }));
}

function writeAllScripts() {
  const sharedFiles = fs.readdirSync(path.join(srcDir, "shared"))
    .filter((fileName) => fileName.endsWith(".lua"))
    .sort();
  sharedFiles.forEach((fileName) => {
    const moduleName = path.basename(fileName, ".lua");
    writeScript(`ReplicatedStorage.Shared.${moduleName}`, "ModuleScript", `shared/${fileName}`);
  });

  writeScript("ServerScriptService.Server.Main", "Script", "server/Main.server.lua");

  const serviceFiles = fs.readdirSync(path.join(srcDir, "server", "Services"))
    .filter((fileName) => fileName.endsWith(".lua"))
    .sort();
  serviceFiles.forEach((fileName) => {
    const moduleName = path.basename(fileName, ".lua");
    writeScript(`ServerScriptService.Server.Services.${moduleName}`, "ModuleScript", `server/Services/${fileName}`);
  });

  writeScript("StarterPlayer.StarterPlayerScripts.ClientMain", "LocalScript", "client/ClientMain.client.lua");

  const controllerFiles = fs.readdirSync(path.join(srcDir, "client", "Controllers"))
    .filter((fileName) => fileName.endsWith(".lua"))
    .sort();
  controllerFiles.forEach((fileName) => {
    const moduleName = path.basename(fileName, ".lua");
    writeScript(`StarterPlayer.StarterPlayerScripts.Controllers.${moduleName}`, "ModuleScript", `client/Controllers/${fileName}`);
  });
}

function addRemotes() {
  [
    "RequestClaimPlaytimeReward",
    "RequestClaimDailyReward",
    "RequestCatchPhantomSnack",
    "RequestUpdateSettings",
  ].forEach(ensureRemote);
}

function addPanelBase(pathName, title, height, yOffset) {
  inst("Frame", pathName, {
    Visible: false,
    BackgroundColor3: c3(28, 31, 39),
    BackgroundTransparency: 0.04,
    BorderSizePixel: 0,
    Size: ud2(0, 340, 0, height),
    Position: ud2(0.5, -170, 0.5, yOffset),
  });
  inst("TextLabel", `${pathName}.Title`, {
    BackgroundTransparency: 1,
    Size: ud2(1, -58, 0, 34),
    Position: ud2(0, 12, 0, 8),
    Text: title,
    TextColor3: c3(255, 213, 105),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  inst("TextButton", `${pathName}.CloseButton`, {
    BackgroundColor3: c3(70, 70, 80),
    BorderSizePixel: 0,
    Size: ud2(0, 34, 0, 30),
    Position: ud2(1, -42, 0, 8),
    Text: "X",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    Font: "GothamBold",
  });
}

function addRetentionUi() {
  inst("Frame", "StarterGui.MainUI.NextGoalPanel", {
    BackgroundColor3: c3(42, 32, 58),
    BackgroundTransparency: 0.08,
    BorderSizePixel: 0,
    Size: ud2(0, 370, 0, 50),
    Position: ud2(0.5, -185, 1, -136),
    Visible: true,
  });
  inst("TextLabel", "StarterGui.MainUI.NextGoalPanel.NextGoalText", {
    BackgroundTransparency: 1,
    Size: ud2(1, -18, 1, -10),
    Position: ud2(0, 9, 0, 5),
    Text: "Next Goal: Grow a snack",
    TextColor3: c3(255, 246, 210),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });

  inst("Frame", "StarterGui.MainUI.QuickActions", {
    BackgroundTransparency: 1,
    Size: ud2(0, 176, 0, 42),
    Position: ud2(1, -188, 0, 108),
    Visible: true,
  });
  [
    ["PlaytimeButton", "TIME", c3(86, 154, 215), 0],
    ["DailyButton", "DAILY", c3(105, 190, 112), 58],
    ["SettingsButton", "SET", c3(92, 82, 122), 116],
  ].forEach(([name, text, color, x]) => {
    inst("TextButton", `StarterGui.MainUI.QuickActions.${name}`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(0, 54, 1, 0),
      Position: ud2(0, x, 0, 0),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBlack",
    });
  });

  addPanelBase("StarterGui.MainUI.PlaytimeRewardsPanel", "PLAYTIME", 210, -105);
  inst("TextLabel", "StarterGui.MainUI.PlaytimeRewardsPanel.RewardInfo", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 92),
    Position: ud2(0, 12, 0, 58),
    Text: "Next reward loading...",
    TextColor3: c3(238, 241, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("TextButton", "StarterGui.MainUI.PlaytimeRewardsPanel.ClaimButton", {
    BackgroundColor3: c3(86, 154, 215),
    BorderSizePixel: 0,
    Size: ud2(1, -24, 0, 44),
    Position: ud2(0, 12, 1, -56),
    Text: "CLAIM",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });

  addPanelBase("StarterGui.MainUI.DailyRewardPanel", "DAILY CHEST", 210, -105);
  inst("TextLabel", "StarterGui.MainUI.DailyRewardPanel.DailyInfo", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 92),
    Position: ud2(0, 12, 0, 58),
    Text: "Daily reward loading...",
    TextColor3: c3(238, 241, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("TextButton", "StarterGui.MainUI.DailyRewardPanel.ClaimButton", {
    BackgroundColor3: c3(105, 190, 112),
    BorderSizePixel: 0,
    Size: ud2(1, -24, 0, 44),
    Position: ud2(0, 12, 1, -56),
    Text: "CLAIM DAILY",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });

  addPanelBase("StarterGui.MainUI.SettingsPanel", "SETTINGS", 284, -142);
  [
    ["ReduceEffectsButton", "Reduce Effects: OFF", 58],
    ["MuteSoundsButton", "Mute Sounds: OFF", 104],
    ["HideExtraPopupsButton", "Hide Popups: OFF", 150],
    ["AutoClosePanelsButton", "Auto Close Panels: ON", 196],
  ].forEach(([name, text, y]) => {
    inst("TextButton", `StarterGui.MainUI.SettingsPanel.${name}`, {
      BackgroundColor3: c3(50, 57, 70),
      BorderSizePixel: 0,
      Size: ud2(1, -24, 0, 38),
      Position: ud2(0, 12, 0, y),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  });

  inst("TextLabel", "StarterGui.MainUI.SeedShopPanel.RestockLabel", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 28),
    Position: ud2(0, 12, 1, -40),
    Text: "Restock: loading...",
    TextColor3: c3(225, 232, 245),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
}

function addDailyChest() {
  ensureFolder("Workspace.GameWorld.Stations");
  model("Workspace.GameWorld.Stations.DailyRewardChest", { Phase4Retention: true });
  part("Workspace.GameWorld.Stations.DailyRewardChest.Base", {
    Anchored: true,
    CanCollide: true,
    Color: c3(96, 62, 42),
    Material: "WoodPlanks",
    Size: v3(5.2, 2, 4.2),
    Position: v3(24, 4.4, -24),
  }, { GameplayAnchor: "DailyRewardChest" });
  part("Workspace.GameWorld.Stations.DailyRewardChest.Lid", {
    Anchored: true,
    CanCollide: false,
    Color: c3(136, 86, 50),
    Material: "WoodPlanks",
    Size: v3(5.4, 1.1, 4.4),
    Position: v3(24, 5.95, -24),
  }, { DecorativeOnly: true });
  part("Workspace.GameWorld.Stations.DailyRewardChest.LockPlate", {
    Anchored: true,
    CanCollide: false,
    Color: c3(205, 170, 74),
    Material: "Metal",
    Size: v3(1.1, 1.1, 0.18),
    Position: v3(24, 5.45, -26.18),
  }, { DecorativeOnly: true });
  part("Workspace.GameWorld.Stations.DailyRewardChest.GlassRewardCore", {
    Anchored: true,
    CanCollide: false,
    Color: c3(116, 91, 176),
    Material: "Glass",
    Shape: "Ball",
    Size: v3(1.15, 1.15, 1.15),
    Position: v3(24, 6.82, -24),
    Transparency: 0.24,
  }, { DecorativeOnly: true });
  inst("ProximityPrompt", "Workspace.GameWorld.Stations.DailyRewardChest.Base.DailyRewardPrompt", {
    ActionText: "Claim Daily",
    ObjectText: "Daily Chest",
    HoldDuration: 0.25,
    MaxActivationDistance: 14,
  });
  part("Workspace.GameWorld.Stations.DailyRewardChest.SignPost", {
    Anchored: true,
    CanCollide: false,
    Color: c3(70, 48, 34),
    Material: "Wood",
    Size: v3(0.35, 3, 0.35),
    Position: v3(20.9, 4.8, -24),
  }, { DecorativeOnly: true });
  part("Workspace.GameWorld.Stations.DailyRewardChest.SignBoard", {
    Anchored: true,
    CanCollide: false,
    Color: c3(92, 63, 42),
    Material: "WoodPlanks",
    Size: v3(3.4, 1.3, 0.28),
    Position: v3(20.9, 6.2, -24),
  }, { DecorativeOnly: true });
  inst("BillboardGui", "Workspace.GameWorld.Stations.DailyRewardChest.SignBoard.DailyBillboard", {
    AlwaysOnTop: true,
    Size: ud2(0, 170, 0, 48),
    StudsOffset: v3(0, 1.1, 0),
  });
  inst("TextLabel", "Workspace.GameWorld.Stations.DailyRewardChest.SignBoard.DailyBillboard.Label", {
    BackgroundTransparency: 1,
    Size: ud2(1, 0, 1, 0),
    Text: "DAILY",
    TextColor3: c3(255, 232, 142),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
}

function writeTestingDoc() {
  fs.writeFileSync(testingPath, `# FEED THE VOID Phase 4 Retention Testing

## Bridge apply
- Apply only \`feed_the_void_phase4_retention_overlay.blueprint.json\`; it is an overlay and does not rebuild \`Workspace.GameWorld\`.
- Confirm \`ReplicatedStorage.Remotes\` contains \`RequestClaimPlaytimeReward\`, \`RequestClaimDailyReward\`, \`RequestCatchPhantomSnack\`, and \`RequestUpdateSettings\`.
- Confirm \`StarterGui.MainUI\` contains \`NextGoalPanel\`, \`QuickActions\`, \`PlaytimeRewardsPanel\`, \`DailyRewardPanel\`, \`SettingsPanel\`, and \`SeedShopPanel.RestockLabel\`.
- Confirm \`Workspace.GameWorld.Stations.DailyRewardChest.Base.DailyRewardPrompt\` exists.

## Solo smoke
- Press Play and confirm the first sync shows coins, quests, shop stock/restock, next goal, daily reward, and playtime reward state.
- Claim the daily reward from the panel or chest prompt, then confirm it cannot be claimed again immediately.
- Let the session run until the 2 minute playtime reward or use the panel to confirm the countdown is accurate.
- Buy starter seeds, plant, harvest, sell/feed, and confirm Next Goal advances.
- Use Studio debug \`!event PhantomSnackChase\` or display a rare snack to verify Phantom Snacks spawn with catch prompts.
- Check Output for fresh errors after each flow.

## Multiplayer-facing smoke
- Start a 2-player local server if available.
- Confirm each player receives a plot, their own data snapshot, their own daily/playtime state, and shared Phantom event visibility.
- Confirm catching a Phantom Snack rewards only the catching player while the event participation bonus can reward participants at event end.
`, "utf8");
}

[
  "ReplicatedStorage.Shared",
  "ReplicatedStorage.Remotes",
  "ServerScriptService.Server",
  "ServerScriptService.Server.Services",
  "StarterPlayer.StarterPlayerScripts",
  "StarterPlayer.StarterPlayerScripts.Controllers",
].forEach(ensureFolder);

addRemotes();
writeAllScripts();
addRetentionUi();
addDailyChest();
writeTestingDoc();

const sourceHashes = {};
for (const relPath of [
  "shared/GameConfig.lua",
  "shared/EventConfig.lua",
  "shared/AssetReferences.lua",
  "server/Main.server.lua",
  "server/Services/StatsService.lua",
  "server/Services/BadgeAwardService.lua",
  "server/Services/SettingsService.lua",
  "server/Services/PlaytimeRewardService.lua",
  "server/Services/DailyRewardService.lua",
  "server/Services/OnboardingService.lua",
  "server/Services/PhantomSnackService.lua",
  "client/ClientMain.client.lua",
  "client/Controllers/UIController.lua",
  "client/Controllers/SoundController.lua",
  "client/Controllers/EffectsController.lua",
]) {
  sourceHashes[relPath] = sourceHash(relPath);
}

const blueprint = {
  name: "FEED THE VOID Phase 4 Retention Overlay",
  mode: "supervised",
  description: "Adds first-10-minutes retention systems, server-authored progression UI, playtime/daily rewards, Phantom Snack Chase, settings, stats, badge-safe config, and a real Workspace daily chest without rebuilding the premium map.",
  steps,
  metadata: {
    phase: "4-retention",
    generatedAt: new Date().toISOString(),
    overlayOnly: true,
    noWorkspaceMapRebuild: true,
    noPaidMonetization: true,
    sourceHashes,
  },
};

fs.writeFileSync(blueprintPath, JSON.stringify(blueprint, null, 2), "utf8");

console.log(JSON.stringify({
  ok: true,
  blueprintPath,
  testingPath,
  stepCount: steps.length,
  sourceFileCount: steps.filter((item) => item.type === "writeScript").length,
}, null, 2));
