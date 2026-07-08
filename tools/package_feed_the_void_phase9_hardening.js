const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "build", "feed_the_void_phase9_hardening");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase9_hardening_overlay.blueprint.json");
const testingPath = path.join(outDir, "PHASE9_PRIVATE_TEST_QA.md");

const steps = [];
const includeScriptWrites = true;

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
  if (includeScriptWrites) {
    steps.push(step("writeScript", studioPath, {
      className,
      sourceFile: relSource(relPath),
      overwrite: true,
    }));
  }
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
    "RequestToggleItemLock",
    "RequestClaimCollectionMilestone",
    "RequestTeleportToPlot",
    "PlayEffect",
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

  inst("TextLabel", "StarterGui.MainUI.PrivateTestWatermark", {
    BackgroundColor3: c3(18, 14, 26),
    BackgroundTransparency: 0.22,
    BorderSizePixel: 0,
    Size: ud2(0, 250, 0, 24),
    Position: ud2(0, 12, 0, 12),
    Text: "PRIVATE TEST | Phase 9",
    TextColor3: c3(222, 208, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
    Visible: true,
  });

  inst("Frame", "StarterGui.MainUI.QuickActions", {
    BackgroundTransparency: 1,
    Size: ud2(0, 234, 0, 42),
    Position: ud2(1, -246, 0, 108),
    Visible: true,
  });
  [
    ["PlaytimeButton", "TIME", c3(86, 154, 215), 0],
    ["DailyButton", "DAILY", c3(105, 190, 112), 58],
    ["SettingsButton", "SET", c3(92, 82, 122), 116],
    ["LabButton", "LAB", c3(145, 92, 205), 174],
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

  addPanelBase("StarterGui.MainUI.SettingsPanel", "SETTINGS", 376, -188);
  [
    ["ReduceEffectsButton", "Reduce Effects: OFF", 58],
    ["LowDetailModeButton", "Low Detail Mode: OFF", 104],
    ["MuteSoundsButton", "Mute Sounds: OFF", 150],
    ["HideExtraPopupsButton", "Hide Popups: OFF", 196],
    ["AutoClosePanelsButton", "Auto Close Panels: ON", 242],
    ["ShowGuidanceButton", "Show Guidance: ON", 288],
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

function addPhase7Ui() {
  inst("Frame", "StarterGui.MainUI.SeedShopPanel", {
    Size: ud2(0, 384, 0, 470),
    Position: ud2(1, -396, 1, -546),
  });
  inst("TextLabel", "StarterGui.MainUI.SeedShopPanel.ShopTitle", {
    Size: ud2(1, -58, 0, 34),
    Position: ud2(0, 12, 0, 8),
    Text: "SEED SHOP",
    TextColor3: c3(115, 226, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  inst("TextButton", "StarterGui.MainUI.SeedShopPanel.CloseButton", {
    BackgroundColor3: c3(70, 70, 80),
    BorderSizePixel: 0,
    Size: ud2(0, 34, 0, 30),
    Position: ud2(1, -42, 0, 8),
    Text: "X",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("Frame", "StarterGui.MainUI.SeedShopPanel.SeedList", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 376),
    Position: ud2(0, 12, 0, 50),
  });
  [
    ["CookieRock", c3(185, 164, 132)],
    ["MoonMarshmallow", c3(150, 165, 225)],
    ["BubbleBread", c3(225, 98, 175)],
    ["JellyCube", c3(92, 195, 205)],
    ["SlimePretzel", c3(80, 185, 92)],
    ["NeonToast", c3(225, 188, 70)],
    ["MeteorMuffin", c3(190, 70, 58)],
    ["CrystalDonut", c3(82, 175, 225)],
    ["GoblinSandwich", c3(98, 165, 78)],
    ["StarPancake", c3(235, 175, 74)],
    ["LavaNoodleWrap", c3(218, 76, 42)],
    ["VoidWaffle", c3(98, 70, 145)],
    ["BlackHoleBurrito", c3(56, 43, 76)],
    ["GoldenFridgeSnack", c3(220, 166, 44)],
    ["LivingSandwich", c3(94, 125, 92)],
  ].forEach(([id, color], index) => {
    const column = index % 2;
    const row = Math.floor(index / 2);
    inst("TextButton", `StarterGui.MainUI.SeedShopPanel.SeedList.${id}Button`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(0.5, -6, 0, 40),
      Position: ud2(column * 0.5, column === 0 ? 0 : 6, 0, row * 46),
      Text: id,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  });

  inst("Frame", "StarterGui.MainUI.InventoryPanel", {
    Size: ud2(0, 384, 0, 470),
    Position: ud2(0, 12, 1, -546),
  });
  inst("TextButton", "StarterGui.MainUI.InventoryPanel.SortButton", {
    BackgroundColor3: c3(46, 54, 70),
    BorderSizePixel: 0,
    Size: ud2(0.5, -16, 0, 32),
    Position: ud2(0, 10, 0, 116),
    Text: "SORT: NEWEST",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("TextButton", "StarterGui.MainUI.InventoryPanel.FilterButton", {
    BackgroundColor3: c3(46, 54, 70),
    BorderSizePixel: 0,
    Size: ud2(0.5, -16, 0, 32),
    Position: ud2(0.5, 6, 0, 116),
    Text: "FILTER: ALL",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("Frame", "StarterGui.MainUI.InventoryPanel.ItemList", {
    Position: ud2(0, 10, 0, 154),
    Size: ud2(1, -20, 0, 196),
  });
  inst("TextLabel", "StarterGui.MainUI.InventoryPanel.SelectedDetail", {
    Position: ud2(0, 10, 0, 354),
    Size: ud2(1, -20, 0, 54),
  });
  [
    ["SellButton", "SELL", c3(70, 165, 92), 10],
    ["FeedButton", "FEED", c3(130, 74, 190), 100],
    ["DisplayButton", "DISPLAY", c3(68, 128, 190), 190],
    ["LockButton", "LOCK", c3(92, 82, 122), 280],
  ].forEach(([name, text, color, x]) => {
    inst("TextButton", `StarterGui.MainUI.InventoryPanel.${name}`, {
      BackgroundColor3: color,
      BorderSizePixel: 0,
      Size: ud2(0, 82, 0, 42),
      Position: ud2(0, x, 1, -52),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  });
  inst("Frame", "StarterGui.MainUI.InventoryPanel.ConfirmPanel", {
    Visible: false,
    BackgroundColor3: c3(28, 22, 36),
    BackgroundTransparency: 0.03,
    BorderSizePixel: 0,
    Size: ud2(1, -20, 0, 92),
    Position: ud2(0, 10, 1, -148),
  });
  inst("TextLabel", "StarterGui.MainUI.InventoryPanel.ConfirmPanel.ConfirmText", {
    BackgroundTransparency: 1,
    Size: ud2(1, -12, 0, 44),
    Position: ud2(0, 6, 0, 6),
    Text: "Confirm valuable action?",
    TextColor3: c3(255, 235, 190),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  inst("TextButton", "StarterGui.MainUI.InventoryPanel.ConfirmPanel.ConfirmButton", {
    BackgroundColor3: c3(165, 78, 98),
    BorderSizePixel: 0,
    Size: ud2(0.5, -9, 0, 34),
    Position: ud2(0, 6, 1, -40),
    Text: "CONFIRM",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
  inst("TextButton", "StarterGui.MainUI.InventoryPanel.ConfirmPanel.CancelButton", {
    BackgroundColor3: c3(65, 65, 76),
    BorderSizePixel: 0,
    Size: ud2(0.5, -9, 0, 34),
    Position: ud2(0.5, 3, 1, -40),
    Text: "CANCEL",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });

  for (let index = 1; index <= 3; index += 1) {
    inst("TextButton", `StarterGui.MainUI.CollectionPanel.MilestoneButton${index}`, {
      BackgroundColor3: c3(52, 58, 78),
      BorderSizePixel: 0,
      Size: ud2(1, -24, 0, 32),
      Position: ud2(0, 12, 1, -118 + ((index - 1) * 36)),
      Text: "MILESTONE",
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
  }
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
  fs.writeFileSync(testingPath, `# FEED THE VOID Phase 9 Private Test QA

## Bridge apply
- Apply \`feed_the_void_phase9_hardening_overlay.blueprint.json\` as an overlay; it does not rebuild \`Workspace.GameWorld\`.
- Confirm \`ReplicatedStorage.Shared.GameConfig\` has \`LaunchMode = "PrivateTest"\`, \`Performance\`, \`Limits\`, \`Security\`, \`InteractionDistances\`, and \`PrivateTest\`.
- Confirm \`ServerScriptService.Server.Services\` contains \`SecurityService\`, \`FailsafeService\`, \`HealthCheckService\`, and \`OnboardingService\`.
- Confirm \`ServerScriptService.Server.Util\` contains \`CooldownUtil\`, \`ValidationUtil\`, and \`Maid\`.
- Confirm \`StarterGui.MainUI.PrivateTestWatermark\` exists and is small/non-blocking.

## Solo smoke
- Press Play and confirm Output prints \`[FEED THE VOID][Health]\` with zero fatal failures and no script parse errors.
- Use Studio chat \`!health\` and confirm the notification includes pass/warn/fail counts.
- Use Studio chat \`!serverstatus\`, \`!plants\`, \`!inventorycheck\`, \`!voidmites\`, and \`!playerprogress\`; confirm Output prints real counts.
- Use Studio chat \`!eventstatus\`, \`!event SnackRain\`, and \`!endevent\`; confirm event objects clean up.
- Tap \`LAB\`; confirm the player is safely returned to their own lab and cooldown messaging prevents spam.
- Use Studio chat \`!tutorialreset\`; plant, harvest, feed, display, cleanse, upgrade, and complete one objective. Confirm tutorial only advances after real actions.
- Fill inventory through \`!giveitem\` if needed; confirm harvesting is blocked before a ready snack is removed once the cap is reached.

## Security and lifecycle
- Fire malformed remotes only from Studio testing tools, never from client code, and confirm \`[FEED THE VOID][Security]\` warns without kicking.
- Respawn the player and confirm they return to their own plot without duplicate chat/respawn behavior.
- Leave and rejoin. Confirm planted/displayed snacks restore once, voidmites are cleaned for that player, and no duplicate prompts/remotes appear.
- Confirm display attempts are blocked at the Phase 9 display cap and do not delete the selected inventory item.
- Confirm distance checks reject plant/harvest/sell/feed/display/pickup/voidmite/phantom actions when far away.

## Offline, data, and events
- Plant a snack, leave before it finishes, rejoin later, and confirm it can finish offline but is not auto-harvested.
- Display snacks, rejoin later, and confirm capped offline display income is server-calculated and notified.
- Fill The Void with \`!voidfill\`; confirm an event starts, ends, clears \`ActiveEventName\`, and cleans objects.
- Test \`!event SnackRain\`, \`!event MutationSurge\`, \`!event VoidInfestation\`, \`!event GoldenHunger\`, and \`!event PhantomSnackChase\`.
- Confirm Snack Rain never exceeds \`GameConfig.Limits.MaxSnackRainPickups\`, Phantom Chase never exceeds \`MaxPhantomSnacks\`, and global voidmites never exceed \`MaxVoidmitesGlobal\`.

## Multiplayer-facing smoke
- Start a 2-player local server if available.
- Confirm each player receives a plot and independent inventory/seed/lock data.
- Confirm locked items, collection claims, and shop unlock checks are server-side.
- Confirm shared events are visible to both players and rewards are granted only to the player who collected/caught the object.

## Guardrails
- No sound work in Phase 9 except fixing missing-ID warnings from existing configured keys.
- No new Meshy assets or required imported models.
- No paid monetization, trading, stealing, pets, or second world.
- No Workspace map rebuild.
`, "utf8");
}

[
  "ReplicatedStorage.Shared",
  "ReplicatedStorage.Remotes",
  "ServerScriptService.Server",
  "ServerScriptService.Server.Services",
  "ServerScriptService.Server.Util",
  "StarterPlayer.StarterPlayerScripts.Controllers",
].forEach(ensureFolder);

addRemotes();
writeAllScripts();
addLaunchReadyUi();
addPhase7Ui();
writeTestingDoc();

const sourceHashes = {};
for (const relPath of walkLuaFiles(srcDir)) {
  sourceHashes[relPath] = sourceHash(relPath);
}

const blueprint = {
  name: "FEED THE VOID Phase 9 Hardening Overlay",
  mode: "supervised",
  description: "Adds Phase 9 private-test hardening: performance caps, Maid cleanup, remote security, lifecycle recovery, debug status commands, and health checks without rebuilding Workspace.GameWorld.",
  steps,
  metadata: {
    phase: "9-private-test-hardening",
    generatedAt: new Date().toISOString(),
    writesScriptSources: includeScriptWrites,
    overlayOnly: true,
    noWorkspaceMapRebuild: true,
    noPaidMonetization: true,
    noSounds: true,
    noNewMeshes: true,
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
