const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "build", "feed_the_void_phase5_launch_ready");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase5_launch_ready_overlay.blueprint.json");
const testingPath = path.join(outDir, "PHASE5_LAUNCH_READY_TESTING.md");

const steps = [];

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
  steps.push(step("ensureInstance", studioPath, { className, properties: {} }));
  steps.push(step("writeScript", studioPath, {
    className,
    sourceFile: relSource(relPath),
    overwrite: true,
  }));
}

function luaFiles(dir) {
  if (!fs.existsSync(dir)) {
    return [];
  }
  return fs.readdirSync(dir).filter((fileName) => fileName.endsWith(".lua")).sort();
}

function writeAllScripts() {
  luaFiles(path.join(srcDir, "shared")).forEach((fileName) => {
    const moduleName = path.basename(fileName, ".lua");
    writeScript(`ReplicatedStorage.Shared.${moduleName}`, "ModuleScript", `shared/${fileName}`);
  });

  writeScript("ServerScriptService.Server.Main", "Script", "server/Main.server.lua");

  luaFiles(path.join(srcDir, "server", "Services")).forEach((fileName) => {
    const moduleName = path.basename(fileName, ".lua");
    writeScript(`ServerScriptService.Server.Services.${moduleName}`, "ModuleScript", `server/Services/${fileName}`);
  });

  luaFiles(path.join(srcDir, "server", "Util")).forEach((fileName) => {
    const moduleName = path.basename(fileName, ".lua");
    writeScript(`ServerScriptService.Server.Util.${moduleName}`, "ModuleScript", `server/Util/${fileName}`);
  });

  writeScript("StarterPlayer.StarterPlayerScripts.ClientMain", "LocalScript", "client/ClientMain.client.lua");

  luaFiles(path.join(srcDir, "client", "Controllers")).forEach((fileName) => {
    const moduleName = path.basename(fileName, ".lua");
    writeScript(`StarterPlayer.StarterPlayerScripts.Controllers.${moduleName}`, "ModuleScript", `client/Controllers/${fileName}`);
  });
}

function addRemotes() {
  [
    "RequestPlantSnack",
    "RequestHarvestSnack",
    "RequestSellSnack",
    "RequestFeedVoid",
    "RequestDisplaySnack",
    "RequestClearVoidmite",
    "RequestBuySeed",
    "RequestBuyUpgrade",
    "RequestRebirth",
    "RequestSkipTutorial",
    "RequestDebugCommand",
    "RequestClaimPlaytimeReward",
    "RequestClaimDailyReward",
    "RequestCatchPhantomSnack",
    "RequestUpdateSettings",
    "RequestCollectEventPickup",
    "NotifyClient",
    "SyncPlayerData",
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

function addLaunchReadyUi() {
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

  addPanelBase("StarterGui.MainUI.SettingsPanel", "SETTINGS", 330, -165);
  [
    ["ReduceEffectsButton", "Reduce Effects: OFF", 58],
    ["LowDetailModeButton", "Low Detail Mode: OFF", 104],
    ["MuteSoundsButton", "Mute Sounds: OFF", 150],
    ["HideExtraPopupsButton", "Hide Popups: OFF", 196],
    ["AutoClosePanelsButton", "Auto Close Panels: ON", 242],
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

function walkLuaFiles(dir, prefix = "") {
  const result = [];
  if (!fs.existsSync(dir)) {
    return result;
  }
  for (const fileName of fs.readdirSync(dir).sort()) {
    const abs = path.join(dir, fileName);
    const rel = prefix ? `${prefix}/${fileName}` : fileName;
    const stat = fs.statSync(abs);
    if (stat.isDirectory()) {
      result.push(...walkLuaFiles(abs, rel));
    } else if (fileName.endsWith(".lua")) {
      result.push(rel.replace(/\\/g, "/"));
    }
  }
  return result;
}

function writeTestingDoc() {
  fs.writeFileSync(testingPath, `# FEED THE VOID Phase 5 Launch-Ready Testing

## Bridge apply
- Apply only \`feed_the_void_phase5_launch_ready_overlay.blueprint.json\`; it is an overlay and does not rebuild \`Workspace.GameWorld\`.
- Confirm \`ReplicatedStorage.Remotes\` contains the full server-bound remote list, including \`RequestCollectEventPickup\`.
- Confirm \`ServerScriptService.Server.Services\` contains \`HealthCheckService\` and \`ActivityFeedService\`.
- Confirm \`ServerScriptService.Server.Util\` contains \`CooldownUtil\` and \`ValidationUtil\`.
- Confirm \`StarterGui.MainUI.SettingsPanel.LowDetailModeButton\` exists as a real StarterGui instance.

## Solo smoke
- Press Play and confirm Output prints \`[FEED THE VOID][Health]\` with zero fatal failures.
- Use Studio chat \`!health\` and confirm the player receives a health summary notification.
- Buy seeds, plant, harvest, sell/feed, display a snack, buy an upgrade, claim daily/playtime reward if ready, and confirm no fresh Output errors.
- Use Studio debug \`!event SnackRain\` and collect a crumb by prompt or touch. Confirm one reward per pickup.
- Use Studio debug \`!event PhantomSnackChase\` and catch a phantom. Confirm the activity feed announces the catch without duplicate reward spam.
- Toggle Low Detail Mode in Settings and confirm the setting persists in the next sync.

## Asset readiness
- Imported model keys are checked by \`HealthCheckService\`: missing assets warn and use fallbacks, but do not stop gameplay.
- Required model names are listed in \`ReplicatedStorage.Shared.AssetImportGuide\`.
- Map placement is intentionally not generated by this overlay; use your manually rebuilt map and keep prompts named \`PlatePrompt\`, \`SellPrompt\`, \`FeedPrompt\`, \`DisplayPrompt\`, \`BuySeedPrompt\`, \`UpgradePrompt\`, \`RebirthPrompt\`, and \`DailyRewardPrompt\`.

## Multiplayer-facing smoke
- Start a 2-player local server if available.
- Confirm each player receives a plot, their own synced data snapshot, and independent reward/settings state.
- Confirm shared events are visible to both players and event rewards are granted only to the player who collected/caught the object.
`, "utf8");
}

[
  "ReplicatedStorage.Shared",
  "ReplicatedStorage.Remotes",
  "ServerScriptService.Server",
  "ServerScriptService.Server.Services",
  "ServerScriptService.Server.Util",
  "StarterPlayer.StarterPlayerScripts",
  "StarterPlayer.StarterPlayerScripts.Controllers",
].forEach(ensureFolder);

addRemotes();
writeAllScripts();
addLaunchReadyUi();
writeTestingDoc();

const sourceHashes = {};
for (const relPath of walkLuaFiles(srcDir)) {
  sourceHashes[relPath] = sourceHash(relPath);
}

const blueprint = {
  name: "FEED THE VOID Phase 5 Launch-Ready Overlay",
  mode: "supervised",
  description: "Adds launch-readiness hardening, full imported asset key support, health checks, shared validation/cooldowns, activity feed, data migration, low-detail settings, and bound event pickup remotes without rebuilding Workspace.GameWorld.",
  steps,
  metadata: {
    phase: "5-launch-ready",
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
