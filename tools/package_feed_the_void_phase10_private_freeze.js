const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "build", "feed_the_void_phase10_private_freeze");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase10_private_freeze_overlay.blueprint.json");
const testingPath = path.join(outDir, "PHASE10_PRIVATE_TEST_QA.md");

const steps = [];
const includeScriptWrites = true;

const c3 = (r, g, b) => ({ __type: "Color3", mode: "rgb", r, g, b });
const v3 = (x, y, z) => ({ __type: "Vector3", x, y, z });
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

function forceSourceForNewPhase10Modules() {
  [
    ["ReplicatedStorage.Shared.FeatureFlags", "shared/FeatureFlags.lua"],
    ["ServerScriptService.Server.Services.FeedbackService", "server/Services/FeedbackService.lua"],
    ["ServerScriptService.Server.Services.SmokeTestService", "server/Services/SmokeTestService.lua"],
    ["ServerScriptService.Server.Util.SafeCall", "server/Util/SafeCall.lua"],
  ].forEach(([studioPath, relPath]) => {
    steps.push(step("setProperties", studioPath, {
      properties: {
        Source: readSource(relPath),
      },
    }));
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
    "RequestSubmitFeedback",
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
    Text: "PRIVATE TEST | v0.1.0-private",
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

function addPhase10PrivateTestUi() {
  inst("Frame", "StarterGui.MainUI.LoadingPanel", {
    BackgroundColor3: c3(12, 10, 18),
    BackgroundTransparency: 0.06,
    BorderSizePixel: 0,
    Size: ud2(1, 0, 1, 0),
    Position: ud2(0, 0, 0, 0),
    Visible: true,
    ZIndex: 50,
  });
  inst("TextLabel", "StarterGui.MainUI.LoadingPanel.LoadingText", {
    BackgroundTransparency: 1,
    Size: ud2(0, 420, 0, 56),
    Position: ud2(0.5, -210, 0.5, -44),
    Text: "Loading your lab...",
    TextColor3: c3(255, 246, 210),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
    ZIndex: 51,
  });
  inst("TextLabel", "StarterGui.MainUI.LoadingPanel.StatusLabel", {
    BackgroundTransparency: 1,
    Size: ud2(0, 420, 0, 34),
    Position: ud2(0.5, -210, 0.5, 18),
    Text: "Preparing plates, snacks, and The Void...",
    TextColor3: c3(211, 204, 235),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
    ZIndex: 51,
  });
  inst("TextButton", "StarterGui.MainUI.FeedbackButton", {
    BackgroundColor3: c3(68, 116, 173),
    BorderSizePixel: 0,
    Size: ud2(0, 118, 0, 34),
    Position: ud2(1, -132, 1, -184),
    Text: "FEEDBACK",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
    Visible: false,
  });
  addPanelBase("StarterGui.MainUI.FeedbackPanel", "FEEDBACK", 292, -146);
  inst("Frame", "StarterGui.MainUI.FeedbackPanel.CategoryButtons", {
    BackgroundTransparency: 1,
    Size: ud2(1, -24, 0, 86),
    Position: ud2(0, 12, 0, 48),
  });
  [
    ["Bug", "BUG", 0, 0, c3(197, 82, 92)],
    ["Confusing", "CONFUSING", 0.25, 0, c3(199, 151, 69)],
    ["TooSlow", "SLOW", 0.5, 0, c3(95, 130, 195)],
    ["TooHard", "HARD", 0.75, 0, c3(132, 96, 198)],
    ["UIIssue", "UI", 0, 0.5, c3(88, 155, 175)],
    ["MobileIssue", "MOBILE", 0.25, 0.5, c3(91, 166, 111)],
    ["Fun", "FUN", 0.5, 0.5, c3(220, 111, 167)],
    ["Other", "OTHER", 0.75, 0.5, c3(108, 112, 128)],
  ].forEach(([name, text, x, y, color]) => {
    inst("TextButton", `StarterGui.MainUI.FeedbackPanel.CategoryButtons.${name}Button`, {
      BackgroundColor3: color,
      BackgroundTransparency: name === "Bug" ? 0 : 0.24,
      BorderSizePixel: 0,
      Size: ud2(0.25, -6, 0.5, -5),
      Position: ud2(x, 3, y, y === 0 ? 0 : 5),
      Text: text,
      TextColor3: c3(255, 255, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBlack",
    });
  });
  inst("TextBox", "StarterGui.MainUI.FeedbackPanel.MessageBox", {
    BackgroundColor3: c3(18, 21, 30),
    BackgroundTransparency: 0.02,
    BorderSizePixel: 0,
    ClearTextOnFocus: false,
    MultiLine: true,
    PlaceholderText: "What felt broken, slow, confusing, or fun?",
    Size: ud2(1, -24, 0, 92),
    Position: ud2(0, 12, 0, 144),
    Text: "",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
  inst("TextButton", "StarterGui.MainUI.FeedbackPanel.SubmitButton", {
    BackgroundColor3: c3(72, 145, 116),
    BorderSizePixel: 0,
    Size: ud2(1, -24, 0, 40),
    Position: ud2(0, 12, 1, -52),
    Text: "SEND",
    TextColor3: c3(255, 255, 255),
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBlack",
  });
}

function addPrivateTestBoards() {
  ensureFolder("Workspace.GameWorld.Stations.PrivateTestBoards");
  const boards = [
    {
      key: "HowToPlayBoard",
      title: "HOW TO PLAY",
      text: "Plant seeds on plates. Harvest snacks. Sell for coins or feed The Void.",
      position: v3(-280, 61, -176),
      color: c3(42, 48, 62),
      yaw: -12,
    },
    {
      key: "PrivateTestBoard",
      title: "PRIVATE TEST",
      text: "Report bugs, confusing moments, slow pacing, and mobile issues with Feedback.",
      position: v3(-304, 61, -174),
      color: c3(48, 39, 66),
      yaw: 0,
    },
    {
      key: "ChangelogBoard",
      title: "BUILD v0.1.0",
      text: "Phase 10: safe loading, feature flags, feedback, health checks, and first-10 smoke.",
      position: v3(-256, 61, -174),
      color: c3(39, 58, 64),
      yaw: 12,
    },
  ];
  boards.forEach((board) => {
    const basePath = `Workspace.GameWorld.Stations.PrivateTestBoards.${board.key}`;
    inst("Part", basePath, {
      Anchored: true,
      CanCollide: false,
      Color: board.color,
      Material: "Slate",
      Size: v3(18, 9, 0.6),
      Position: board.position,
      Orientation: v3(0, board.yaw, 0),
    });
    inst("SurfaceGui", `${basePath}.BoardSurface`, {
      Face: "Front",
      SizingMode: "PixelsPerStud",
      PixelsPerStud: 45,
      AlwaysOnTop: false,
    });
    inst("TextLabel", `${basePath}.BoardSurface.Title`, {
      BackgroundTransparency: 1,
      Size: ud2(1, -20, 0, 92),
      Position: ud2(0, 10, 0, 12),
      Text: board.title,
      TextColor3: c3(255, 229, 132),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBlack",
    });
    inst("TextLabel", `${basePath}.BoardSurface.Body`, {
      BackgroundTransparency: 1,
      Size: ud2(1, -28, 1, -122),
      Position: ud2(0, 14, 0, 106),
      Text: board.text,
      TextColor3: c3(238, 241, 255),
      TextScaled: true,
      TextWrapped: true,
      Font: "GothamBold",
    });
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
  fs.writeFileSync(testingPath, `# FEED THE VOID Phase 10 Private Test Freeze QA

## Bridge apply
- Apply \`feed_the_void_phase10_private_freeze_overlay.blueprint.json\` as an overlay; it does not rebuild \`Workspace.GameWorld\`.
- Confirm \`ReplicatedStorage.Shared.GameConfig.BuildVersion\` is \`0.1.0-private\` and \`LaunchMode = "PrivateTest"\`.
- Confirm \`ReplicatedStorage.Shared.FeatureFlags\` exists and monetization, trading, stealing, pets, and second world are false.
- Confirm \`ServerScriptService.Server.Services\` contains \`FeedbackService\`, \`SmokeTestService\`, and \`HealthCheckService\`.
- Confirm \`ServerScriptService.Server.Util\` contains \`CooldownUtil\`, \`ValidationUtil\`, \`Maid\`, and \`SafeCall\`.
- Confirm \`StarterGui.MainUI.LoadingPanel\`, \`FeedbackButton\`, and \`FeedbackPanel\` exist in StarterGui.
- Confirm \`Workspace.GameWorld.Stations.PrivateTestBoards\` exists with How To Play, Private Test, and Changelog boards.

## Solo smoke
- Press Play and confirm Output prints \`[FEED THE VOID HEALTH CHECK]\` with zero fatal failures and no script parse errors.
- Confirm the loading panel stays up until the first \`SyncPlayerData\` snapshot, then HUD/buttons appear.
- Use Studio chat \`!health\`, \`!smoketest\`, \`!first10check\`, and \`!serverstatus\`; confirm Output prints real Phase 10 counts.
- Submit a feedback message from the Feedback button, then run \`!feedback\` and confirm it appears in Output.
- Use \`!event SnackRain\`, \`!disableevent SnackRain\`, \`!enableevent SnackRain\`, and \`!endevent\`; confirm disabled events do not start and cleanup leaves no stale event objects.
- Use \`!sethungerrequired 25\`, \`!setgrowmultiplier 5\`, \`!setvoidmitespeed 3\`, and \`!resetserverbalances\`; confirm \`!serverstatus\` reflects the overrides.

## First 10 minutes
- New player: confirm assigned plot, starter seeds, visible loading recovery, tutorial goal, seed shop path, and plate planting.
- Plant, harvest, sell, feed, display, cleanse, upgrade, and claim one available reward. Confirm tutorial and objectives advance only after real actions.
- Run out of seeds with debug testing if needed and confirm the UI says to visit the Seed Shop.
- Confirm empty inventory text says to harvest snacks and collection text explains discoveries.

## Private test guardrails
- No paid monetization prompts, trading, stealing, pets, second world, or new Meshy dependency.
- No new sound IDs were added by this phase.
- No runtime script-created owner signs, old generated world folders, or Workspace map rebuilds.
- Missing imported assets must fall back without blocking health/smoke checks.
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
forceSourceForNewPhase10Modules();
addLaunchReadyUi();
addPhase10PrivateTestUi();
addPhase7Ui();
addPrivateTestBoards();
writeTestingDoc();

const sourceHashes = {};
for (const relPath of walkLuaFiles(srcDir)) {
  sourceHashes[relPath] = sourceHash(relPath);
}

const blueprint = {
  name: "FEED THE VOID Phase 10 Private Test Freeze Overlay",
  mode: "supervised",
  description: "Adds Phase 10 private-test freeze systems: feature flags, loading/profile safety, feedback, smoke tests, health checks, event recovery, tuning commands, UI states, and private-test boards without rebuilding Workspace.GameWorld.",
  steps,
  metadata: {
    phase: "10-private-test-freeze",
    buildVersion: "0.1.0-private",
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
