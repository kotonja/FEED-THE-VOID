const childProcess = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const phase3Generator = path.join(__dirname, "generate_feed_the_void_phase3.js");
const phase3Dir = path.join(root, "build", "feed_the_void_phase3");
const phase3BlueprintPath = path.join(phase3Dir, "feed_the_void_phase3.blueprint.json");
const outDir = path.join(root, "build", "feed_the_void_phase4_map");
const srcDir = path.join(outDir, "src");
const blueprintPath = path.join(outDir, "feed_the_void_phase4_map.blueprint.json");

childProcess.execFileSync(process.execPath, [phase3Generator], { cwd: root, stdio: "inherit" });
fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(srcDir, { recursive: true });
fs.cpSync(path.join(phase3Dir, "src"), srcDir, { recursive: true });

const baseBlueprint = JSON.parse(fs.readFileSync(phase3BlueprintPath, "utf8"));

const steps = baseBlueprint.steps
  .filter((baseStep) => !String(baseStep.path || "").startsWith("Workspace.GameWorld"))
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

function ensureFolder(pathName, attributes) {
  steps.push(step("ensureFolder", pathName, attributes ? { attributes } : {}));
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

function sourceHash(source) {
  return "sha256:" + crypto.createHash("sha256").update(source.replace(/\r\n/g, "\n").trimStart()).digest("hex");
}

const FTW_ASSETS = {
  FTW_TheVoid: {
    folder: "Void",
    meshId: "rbxassetid://129787785044052",
    textureId: "rbxassetid://116046015964595",
    librarySize: v3(42.0788, 37.1233, 33.1241),
  },
  FTW_Voidmite: {
    folder: "Creatures",
    meshId: "rbxassetid://124493656686403",
    textureId: "rbxassetid://107396355087618",
    librarySize: v3(66.7182, 48.3604, 59.1833),
  },
  FTW_Snack_RoundBase: {
    folder: "Snacks",
    meshId: "rbxassetid://130867519800531",
    textureId: "rbxassetid://96692301634422",
    librarySize: v3(45.7368, 31.15, 44.2311),
  },
  FTW_Snack_CubeBase: {
    folder: "Snacks",
    meshId: "rbxassetid://134201331743813",
    textureId: "rbxassetid://102933784035530",
    librarySize: v3(52.0041, 39.3228, 52.0041),
  },
  FTW_Snack_WrapBase: {
    folder: "Snacks",
    meshId: "rbxassetid://77397246619858",
    textureId: "rbxassetid://105078331770625",
    librarySize: v3(55.3281, 21.5448, 62.0847),
  },
  FTW_GrowPlate: {
    folder: "Plot",
    meshId: "rbxassetid://135575133920980",
    textureId: "rbxassetid://101267810957119",
    librarySize: v3(48.5863, 19.0554, 48.5863),
  },
  FTW_DisplayPedestal: {
    folder: "Plot",
    meshId: "rbxassetid://123299587184664",
    textureId: "rbxassetid://130573205894345",
    librarySize: v3(40.6189, 19.8507, 40.6189),
  },
  FTW_SeedShopMachine: {
    folder: "Stations",
    meshId: "rbxassetid://135445669394617",
    textureId: "rbxassetid://94702337681092",
    librarySize: v3(18.9419, 26.2066, 19.0496),
  },
  FTW_SellStation: {
    folder: "Stations",
    meshId: "rbxassetid://121638235202900",
    textureId: "rbxassetid://107221562683406",
    librarySize: v3(27.1035, 25.4131, 27.3289),
  },
  FTW_VoidCrumbPickup: {
    folder: "Pickups",
    meshId: "rbxassetid://96241619685668",
    textureId: "rbxassetid://73420263840261",
    librarySize: v3(34.4491, 32.5392, 11.5302),
  },
};

function meshPart(pathName, assetName, properties = {}, attributes) {
  const asset = FTW_ASSETS[assetName];
  if (!asset) {
    throw new Error(`Missing FTW asset: ${assetName}`);
  }
  inst("MeshPart", pathName, {
    Anchored: true,
    CanCollide: false,
    CanTouch: true,
    CanQuery: true,
    MeshId: asset.meshId,
    TextureID: asset.textureId,
    Color: c3(255, 255, 255),
    Material: "SmoothPlastic",
    Transparency: 0,
    ...properties,
  }, {
    FTWAsset: assetName,
    GeneratedByPhase4Map: true,
    ...(attributes || {}),
  });
}

const themes = [
  { id: "pizza", label: "Pepper Pizza", accent: c3(228, 72, 64), dark: c3(93, 35, 42), trim: c3(250, 194, 96), machine: c3(180, 58, 52) },
  { id: "cookie", label: "Cookie Furnace", accent: c3(238, 126, 52), dark: c3(90, 54, 36), trim: c3(250, 190, 108), machine: c3(202, 94, 46) },
  { id: "cheese", label: "Cheese Orbit", accent: c3(235, 204, 72), dark: c3(92, 72, 38), trim: c3(255, 229, 128), machine: c3(213, 166, 54) },
  { id: "melon", label: "Melon Reactor", accent: c3(100, 214, 91), dark: c3(38, 86, 49), trim: c3(170, 241, 111), machine: c3(75, 174, 73) },
  { id: "soda", label: "Soda Freeze", accent: c3(72, 205, 222), dark: c3(35, 78, 90), trim: c3(145, 238, 255), machine: c3(56, 164, 190) },
  { id: "slush", label: "Blue Slush", accent: c3(74, 128, 226), dark: c3(37, 52, 93), trim: c3(142, 182, 252), machine: c3(62, 118, 208) },
  { id: "cupcake", label: "Cupcake Lab", accent: c3(242, 95, 178), dark: c3(88, 42, 78), trim: c3(255, 169, 218), machine: c3(204, 74, 156) },
  { id: "voidgrape", label: "Void Grape", accent: c3(158, 102, 229), dark: c3(62, 42, 96), trim: c3(211, 164, 255), machine: c3(130, 83, 202) },
];

const stone = {
  deep: c3(28, 26, 36),
  mid: c3(44, 39, 56),
  high: c3(60, 53, 72),
  lip: c3(23, 22, 31),
  rail: c3(40, 34, 48),
  railCap: c3(82, 70, 94),
  wood: c3(103, 74, 46),
  grass: c3(49, 110, 71),
  glassPurple: c3(128, 84, 190),
};

function radial(index, count, radius, offset = 0) {
  const angle = ((index + offset) / count) * Math.PI * 2;
  return {
    angle,
    x: Math.cos(angle) * radius,
    z: Math.sin(angle) * radius,
    yaw: -angle * 180 / Math.PI + 90,
  };
}

function localToWorld(cx, cz, angle, lx, lz) {
  return {
    x: cx + Math.cos(angle) * lx - Math.sin(angle) * lz,
    z: cz + Math.sin(angle) * lx + Math.cos(angle) * lz,
  };
}

function ringSegment(prefix, index, count, radius, length, width, y, height, color, material, collidable = true, transparency = 0) {
  const p = radial(index, count, radius);
  part(`${prefix}${index + 1}`, {
    Anchored: true,
    CanCollide: collidable,
    Size: v3(length, height, width),
    Position: v3(p.x, y, p.z),
    Orientation: v3(0, p.yaw + 90, 0),
    Color: color,
    Material: material,
    Transparency: transparency,
  }, { GeneratedByPhase4Map: true });
}

function addAssetLibrary() {
  ensureFolder("ReplicatedStorage.Assets");
  ensureFolder("ReplicatedStorage.Assets.Models");
  ensureFolder("ReplicatedStorage.Assets.ImportedWorkspaceOriginals");
  ["Void", "Creatures", "Snacks", "Plot", "Stations", "Pickups"].forEach((folder) => {
    ensureFolder(`ReplicatedStorage.Assets.Models.${folder}`);
  });

  Object.entries(FTW_ASSETS).forEach(([name, asset]) => {
    const modelPath = `ReplicatedStorage.Assets.Models.${asset.folder}.${name}`;
    model(modelPath, {
      FTWAsset: name,
      Source: "Workspace import catalog",
      GeneratedByPhase4Map: true,
    });
    meshPart(`${modelPath}.Mesh`, name, {
      Size: asset.librarySize,
      Position: v3(0, -1000, 0),
      CanCollide: false,
      CanTouch: false,
      CanQuery: false,
    }, { LibraryAsset: true });
  });
}

function addLighting() {
  steps.push(step("setLighting", "Lighting", {
    properties: {
      ClockTime: 19.1,
      Brightness: 1.65,
      Ambient: c3(78, 60, 101),
      OutdoorAmbient: c3(84, 66, 112),
      FogColor: c3(45, 28, 72),
      FogStart: 160,
      FogEnd: 430,
    },
  }));
  inst("BloomEffect", "Lighting.FTV_Bloom", { Intensity: 0.08, Size: 18, Threshold: 1.4 });
  inst("ColorCorrectionEffect", "Lighting.FTV_Color", { Brightness: 0.01, Contrast: 0.08, Saturation: 0.08, TintColor: c3(230, 216, 255) });
  inst("Atmosphere", "Lighting.FTV_Atmosphere", { Density: 0.34, Offset: 0.08, Color: c3(126, 94, 170), Decay: c3(37, 24, 58), Glare: 0.05, Haze: 1.5 });

  setProps("Workspace.Baseplate", {
    Transparency: 1,
    CanCollide: false,
    CanTouch: false,
    CanQuery: false,
  });
  setProps("Workspace.SpawnLocation", {
    Transparency: 1,
    CanCollide: false,
    CanTouch: false,
    CanQuery: false,
  });
}

function addWorldRoots() {
  [
    "Workspace.GameWorld",
    "Workspace.GameWorld.Plots",
    "Workspace.GameWorld.CentralVoid",
    "Workspace.GameWorld.ActiveSnacks",
    "Workspace.GameWorld.ActiveVoidmites",
    "Workspace.GameWorld.EventObjects",
    "Workspace.GameWorld.CentralArena",
    "Workspace.GameWorld.PlotIslands",
    "Workspace.GameWorld.Bridges",
    "Workspace.GameWorld.Stations",
    "Workspace.GameWorld.Decorations",
    "Workspace.GameWorld.Decorations.FloatingRocks",
    "Workspace.GameWorld.Decorations.Crystals",
    "Workspace.GameWorld.Decorations.FoodProps",
    "Workspace.GameWorld.Decorations.OuterAsteroids",
    "Workspace.GameWorld.SpawnPoints",
    "Workspace.GameWorld.AssetVisuals",
  ].forEach(ensureFolder);

  part("Workspace.GameWorld.VoidLabFloor", {
    Anchored: true,
    CanCollide: false,
    CanTouch: false,
    CanQuery: false,
    Size: v3(350, 1, 350),
    Position: v3(0, -2, 0),
    Color: c3(18, 14, 26),
    Material: "Slate",
    Transparency: 1,
  }, { GeneratedByPhase4Map: true });
}

function addCentralArena() {
  part("Workspace.GameWorld.CentralArena.ArenaBase", {
    Anchored: true,
    CanCollide: true,
    Shape: "Cylinder",
    Size: v3(112, 3, 112),
    Position: v3(0, 0.5, 0),
    Orientation: v3(0, 0, 0),
    Color: stone.deep,
    Material: "Slate",
  }, { GeneratedByPhase4Map: true });

  part("Workspace.GameWorld.CentralArena.VoidBasin", {
    Anchored: true,
    CanCollide: false,
    Shape: "Cylinder",
    Size: v3(48, 0.55, 48),
    Position: v3(0, 2.35, 0),
    Orientation: v3(0, 0, 0),
    Color: c3(70, 42, 108),
    Material: "Glass",
    Transparency: 0.42,
  }, { GeneratedByPhase4Map: true });

  part("Workspace.GameWorld.CentralArena.InnerStoneLip", {
    Anchored: true,
    CanCollide: true,
    Shape: "Cylinder",
    Size: v3(58, 1.2, 58),
    Position: v3(0, 2.0, 0),
    Orientation: v3(0, 0, 0),
    Color: stone.mid,
    Material: "Concrete",
    Transparency: 0.08,
  }, { GeneratedByPhase4Map: true });

  part("Workspace.GameWorld.CentralArena.NebulaUnderlay", {
    Anchored: true,
    CanCollide: false,
    Shape: "Cylinder",
    Size: v3(245, 0.5, 245),
    Position: v3(0, -4.8, 0),
    Orientation: v3(0, 0, 0),
    Color: c3(50, 30, 82),
    Material: "SmoothPlastic",
    Transparency: 0.55,
  }, { GeneratedByPhase4Map: true });

  inst("PointLight", "Workspace.GameWorld.CentralArena.VoidBasin.SoftBasinLight", {
    Brightness: 0.65,
    Range: 78,
    Color: c3(138, 88, 210),
    Shadows: false,
  });
  inst("ParticleEmitter", "Workspace.GameWorld.CentralArena.VoidBasin.SlowVoidDust", {
    Rate: 3,
    Lifetime: nr(2.6, 4.8),
    Speed: nr(0.25, 0.9),
    Color: cs(c3(112, 76, 170), c3(80, 150, 180)),
    LightEmission: 0.05,
    Size: ns({ time: 0, value: 0.18 }, { time: 0.6, value: 0.32 }, { time: 1, value: 0 }),
    Transparency: ns({ time: 0, value: 0.35 }, { time: 1, value: 1 }),
  });

  for (let i = 0; i < 32; i += 1) {
    ringSegment("Workspace.GameWorld.CentralArena.OuterRingBlock", i, 32, 62, 11.6, 8.2, 2.65, 1.8, i % 2 === 0 ? stone.mid : stone.high, "Slate");
    ringSegment("Workspace.GameWorld.CentralArena.LowRailBlock", i, 32, 75, 8.2, 2.1, 4.25, 2.4, stone.rail, "Metal", true, 0);
  }

  for (let i = 0; i < 8; i += 1) {
    const p = radial(i, 8, 47);
    part(`Workspace.GameWorld.CentralArena.StairLanding${i + 1}`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(14, 0.6, 11),
      Position: v3(p.x, 2.75, p.z),
      Orientation: v3(0, p.yaw, 0),
      Color: stone.high,
      Material: "Concrete",
    }, { GeneratedByPhase4Map: true });
    for (let s = 1; s <= 3; s += 1) {
      const stepPos = radial(i, 8, 50 + s * 4);
      part(`Workspace.GameWorld.CentralArena.Stair${i + 1}_${s}`, {
        Anchored: true,
        CanCollide: true,
        Size: v3(12, 0.45 + s * 0.12, 4),
        Position: v3(stepPos.x, 2.28 - s * 0.2, stepPos.z),
        Orientation: v3(0, p.yaw, 0),
        Color: s % 2 === 0 ? stone.mid : stone.high,
        Material: "Concrete",
      }, { GeneratedByPhase4Map: true });
    }
  }

  model("Workspace.GameWorld.CentralVoid.VoidCreature", { GeneratedByPhase4Map: true });
  meshPart("Workspace.GameWorld.CentralVoid.VoidCreature.Mesh", "FTW_TheVoid", {
    Size: v3(38, 34, 32),
    Position: v3(0, 19.2, 0),
    Orientation: v3(0, 180, 0),
    CanCollide: false,
    CanQuery: false,
  });
  part("Workspace.GameWorld.CentralVoid.VoidCore", {
    Anchored: true,
    CanCollide: false,
    CanTouch: true,
    CanQuery: true,
    Shape: "Ball",
    Size: v3(22, 22, 22),
    Position: v3(0, 16, 0),
    Color: c3(21, 16, 30),
    Material: "SmoothPlastic",
    Transparency: 0.92,
  }, { GeneratedByPhase4Map: true });
  part("Workspace.GameWorld.CentralVoid.LeftEyeGlow", {
    Anchored: true,
    CanCollide: false,
    Shape: "Ball",
    Size: v3(4.2, 5.6, 1.1),
    Position: v3(-6.2, 23.3, -15.2),
    Color: c3(175, 114, 232),
    Material: "Glass",
    Transparency: 0.08,
  }, { GeneratedByPhase4Map: true });
  part("Workspace.GameWorld.CentralVoid.RightEyeGlow", {
    Anchored: true,
    CanCollide: false,
    Shape: "Ball",
    Size: v3(4.2, 5.6, 1.1),
    Position: v3(6.2, 23.3, -15.2),
    Color: c3(175, 114, 232),
    Material: "Glass",
    Transparency: 0.08,
  }, { GeneratedByPhase4Map: true });
  inst("PointLight", "Workspace.GameWorld.CentralVoid.LeftEyeGlow.EyeLight", {
    Brightness: 0.45,
    Range: 18,
    Color: c3(175, 114, 232),
    Shadows: false,
  });
  inst("PointLight", "Workspace.GameWorld.CentralVoid.RightEyeGlow.EyeLight", {
    Brightness: 0.45,
    Range: 18,
    Color: c3(175, 114, 232),
    Shadows: false,
  });
  part("Workspace.GameWorld.CentralVoid.FeedStation", {
    Anchored: true,
    CanCollide: true,
    Size: v3(16, 1.2, 12),
    Position: v3(0, 2.8, -39),
    Orientation: v3(0, 0, 0),
    Color: c3(87, 64, 124),
    Material: "Metal",
    Transparency: 0,
  }, { GeneratedByPhase4Map: true });
  inst("ProximityPrompt", "Workspace.GameWorld.CentralVoid.FeedStation.FeedPrompt", {
    ActionText: "Feed The Void",
    ObjectText: "The Void",
    HoldDuration: 0.2,
    MaxActivationDistance: 13,
  });
  part("Workspace.GameWorld.SpawnPoints.CentralSpawn", {
    Anchored: true,
    CanCollide: false,
    Size: v3(10, 0.65, 10),
    Position: v3(0, 3.05, -56),
    Color: c3(86, 72, 114),
    Material: "Glass",
    Transparency: 0.32,
  }, { GeneratedByPhase4Map: true });
}

function makeBridge(index, angle, theme) {
  const mid = radial(index, 8, 88);
  const yaw = mid.yaw;
  part(`Workspace.GameWorld.Bridges.Bridge${index + 1}`, {
    Anchored: true,
    CanCollide: true,
    Size: v3(12, 1.25, 62),
    Position: v3(mid.x, 1.4, mid.z),
    Orientation: v3(0, yaw, 0),
    Color: stone.mid,
    Material: "Slate",
  }, { PlotId: index + 1, GeneratedByPhase4Map: true });
  part(`Workspace.GameWorld.Bridges.Bridge${index + 1}Trim`, {
    Anchored: true,
    CanCollide: false,
    Size: v3(12.6, 0.24, 63.2),
    Position: v3(mid.x, 2.12, mid.z),
    Orientation: v3(0, yaw, 0),
    Color: theme.dark,
    Material: "Metal",
    Transparency: 0.08,
  }, { PlotId: index + 1, GeneratedByPhase4Map: true });

  for (let side = -1; side <= 1; side += 2) {
    for (let p = 0; p < 5; p += 1) {
      const localZ = -26 + p * 13;
      const pos = localToWorld(0, 0, angle, side * 7.2, 88 + localZ);
      part(`Workspace.GameWorld.Bridges.Bridge${index + 1}Post${side < 0 ? "L" : "R"}${p + 1}`, {
        Anchored: true,
        CanCollide: true,
        Size: v3(1.4, 4, 1.4),
        Position: v3(pos.x, 3.65, pos.z),
        Orientation: v3(0, yaw, 0),
        Color: stone.rail,
        Material: "Metal",
      }, { PlotId: index + 1, GeneratedByPhase4Map: true });
    }
    const rail = localToWorld(0, 0, angle, side * 7.2, 88);
    part(`Workspace.GameWorld.Bridges.Bridge${index + 1}Rail${side < 0 ? "L" : "R"}`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(1.2, 1.2, 61),
      Position: v3(rail.x, 5.4, rail.z),
      Orientation: v3(0, yaw, 0),
      Color: stone.railCap,
      Material: "Metal",
    }, { PlotId: index + 1, GeneratedByPhase4Map: true });
  }
}

function addBillboard(pathName, text, width, height, offset, bg, color = c3(255, 246, 218)) {
  inst("BillboardGui", pathName, {
    AlwaysOnTop: true,
    Size: ud2(0, width, 0, height),
    StudsOffset: offset,
  });
  inst("TextLabel", `${pathName}.Label`, {
    BackgroundTransparency: 0.16,
    BackgroundColor3: bg,
    Size: ud2(1, 0, 1, 0),
    Text: text,
    TextColor3: color,
    TextScaled: true,
    TextWrapped: true,
    Font: "GothamBold",
  });
}

function addMachineParts(prefix, cx, cz, angle, lx, lz, theme, variant) {
  const base = localToWorld(cx, cz, angle, lx, lz);
  const yaw = -angle * 180 / Math.PI + 90;
  model(prefix, { GeneratedByPhase4Map: true });
  part(`${prefix}.Body`, {
    Anchored: true,
    CanCollide: true,
    Size: v3(7.5, 10.5, 5.8),
    Position: v3(base.x, 8.2, base.z),
    Orientation: v3(0, yaw, 0),
    Color: variant === "tall" ? theme.machine : c3(70, 62, 86),
    Material: "SmoothPlastic",
  }, { GeneratedByPhase4Map: true });
  part(`${prefix}.Screen`, {
    Anchored: true,
    CanCollide: false,
    Size: v3(5.4, 3.2, 0.35),
    Position: v3(base.x - Math.sin(angle) * 3.1, 9.7, base.z + Math.cos(angle) * 3.1),
    Orientation: v3(0, yaw, 0),
    Color: theme.trim,
    Material: "Glass",
    Transparency: 0.18,
  }, { GeneratedByPhase4Map: true });
  part(`${prefix}.TopCap`, {
    Anchored: true,
    CanCollide: true,
    Size: v3(8.3, 1.2, 6.4),
    Position: v3(base.x, 14.1, base.z),
    Orientation: v3(0, yaw, 0),
    Color: theme.accent,
    Material: "Metal",
  }, { GeneratedByPhase4Map: true });
  part(`${prefix}.CoinSlot`, {
    Anchored: true,
    CanCollide: false,
    Size: v3(2.2, 0.5, 0.25),
    Position: v3(base.x - Math.sin(angle) * 3.35, 7.5, base.z + Math.cos(angle) * 3.35),
    Orientation: v3(0, yaw, 0),
    Color: c3(235, 212, 128),
    Material: "Metal",
  }, { GeneratedByPhase4Map: true });
}

function addPlotIsland(index) {
  const theme = themes[index];
  const plotNumber = index + 1;
  const p = radial(index, 8, 124);
  const angle = p.angle;
  const cx = p.x;
  const cz = p.z;
  const yaw = p.yaw;
  const plotPath = `Workspace.GameWorld.Plots.Plot${plotNumber}`;
  const visualPath = `${plotPath}.Visuals`;
  const propPath = `${plotPath}.SnackProps`;

  makeBridge(index, angle, theme);

  model(plotPath, { PlotId: plotNumber, OwnerUserId: 0, GeneratedByPhase4Map: true });
  ensureFolder(visualPath);
  ensureFolder(propPath);

  part(`Workspace.GameWorld.PlotIslands.Plot${plotNumber}Underside`, {
    Anchored: true,
    CanCollide: false,
    Shape: "Cylinder",
    Size: v3(75, 18, 62),
    Position: v3(cx, -5.8, cz),
    Orientation: v3(0, yaw, 0),
    Color: stone.lip,
    Material: "Rock",
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  part(`${plotPath}.Platform`, {
    Anchored: true,
    CanCollide: true,
    Shape: "Cylinder",
    Size: v3(68, 3, 56),
    Position: v3(cx, 1.2, cz),
    Orientation: v3(0, yaw, 0),
    Color: stone.mid,
    Material: "Slate",
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  part(`${visualPath}.TurfPatch`, {
    Anchored: true,
    CanCollide: false,
    Shape: "Cylinder",
    Size: v3(58, 0.45, 44),
    Position: v3(cx, 3.0, cz),
    Orientation: v3(0, yaw, 0),
    Color: stone.grass,
    Material: "Grass",
    Transparency: 0.08,
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  part(`${visualPath}.ThemeTrim`, {
    Anchored: true,
    CanCollide: false,
    Shape: "Cylinder",
    Size: v3(62, 0.28, 48),
    Position: v3(cx, 3.22, cz),
    Orientation: v3(0, yaw, 0),
    Color: theme.dark,
    Material: "Metal",
    Transparency: 0.18,
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });

  for (let e = 0; e < 16; e += 1) {
    const theta = (e / 16) * Math.PI * 2;
    const localX = Math.cos(theta) * (33 + (e % 2) * 3);
    const localZ = Math.sin(theta) * (26 + (e % 3) * 2);
    const pos = localToWorld(cx, cz, angle, localX, localZ);
    part(`${visualPath}.EdgeRock${e + 1}`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(8 + (e % 3) * 2, 4 + (e % 2), 5 + (e % 4)),
      Position: v3(pos.x, 1.1 - (e % 3) * 0.25, pos.z),
      Orientation: v3((e * 7) % 12, yaw + theta * 180 / Math.PI, (e * 11) % 9),
      Color: e % 2 === 0 ? stone.lip : stone.mid,
      Material: "Rock",
    }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  }

  const spawn = localToWorld(cx, cz, angle, -21, 0);
  part(`${plotPath}.PlotSpawn`, {
    Anchored: true,
    CanCollide: false,
    Size: v3(7, 0.5, 7),
    Position: v3(spawn.x, 3.45, spawn.z),
    Orientation: v3(0, yaw, 0),
    Color: theme.accent,
    Material: "Glass",
    Transparency: 0.46,
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });

  const sign = localToWorld(cx, cz, angle, -31, 0);
  part(`${plotPath}.OwnerSign`, {
    Anchored: true,
    CanCollide: true,
    Size: v3(17, 5.5, 0.8),
    Position: v3(sign.x, 7.0, sign.z),
    Orientation: v3(0, yaw, 0),
    Color: c3(32, 27, 39),
    Material: "WoodPlanks",
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  addBillboard(`${plotPath}.OwnerSign.OwnerBillboard`, "Empty Lab", 250, 64, v3(0, 4.5, 0), c3(28, 22, 36));

  const display = localToWorld(cx, cz, angle, 0, -21);
  part(`${plotPath}.DisplayShelf`, {
    Anchored: true,
    CanCollide: true,
    Size: v3(25, 2.2, 6),
    Position: v3(display.x, 4.0, display.z),
    Orientation: v3(0, yaw, 0),
    Color: stone.wood,
    Material: "WoodPlanks",
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  inst("ProximityPrompt", `${plotPath}.DisplayShelf.DisplayPrompt`, {
    ActionText: "Display Snack",
    ObjectText: "Display",
    HoldDuration: 0.2,
    MaxActivationDistance: 11,
  });
  addBillboard(`${plotPath}.DisplayShelf.DisplayBillboard`, "Display", 150, 42, v3(0, 3.2, 0), c3(24, 18, 34));
  meshPart(`${visualPath}.DisplayPedestalMesh`, "FTW_DisplayPedestal", {
    Size: v3(9.5, 4.5, 9.5),
    Position: v3(display.x, 6.1, display.z),
    Orientation: v3(0, yaw, 0),
    CanQuery: false,
  }, { PlotId: plotNumber });

  const seed = localToWorld(cx, cz, angle, 24, -17);
  part(`${plotPath}.SeedShopStation`, {
    Anchored: true,
    CanCollide: false,
    Size: v3(7, 8, 7),
    Position: v3(seed.x, 7.2, seed.z),
    Orientation: v3(0, yaw, 0),
    Color: theme.machine,
    Material: "SmoothPlastic",
    Transparency: 1,
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  inst("ProximityPrompt", `${plotPath}.SeedShopStation.BuySeedPrompt`, { ActionText: "Buy Seeds", ObjectText: "Seeds", HoldDuration: 0.2, MaxActivationDistance: 11 });
  addBillboard(`${plotPath}.SeedShopStation.SeedsBillboard`, "Seeds", 130, 38, v3(0, 5.2, 0), c3(38, 26, 14));
  meshPart(`${visualPath}.SeedShopMachineMesh`, "FTW_SeedShopMachine", {
    Size: v3(9.8, 13.5, 9.8),
    Position: v3(seed.x, 8.7, seed.z),
    Orientation: v3(0, yaw, 0),
    CanQuery: false,
  }, { PlotId: plotNumber });

  const sell = localToWorld(cx, cz, angle, 24, 17);
  part(`${plotPath}.SellStation`, {
    Anchored: true,
    CanCollide: false,
    Size: v3(7, 8, 7),
    Position: v3(sell.x, 7.2, sell.z),
    Orientation: v3(0, yaw, 0),
    Color: c3(67, 142, 92),
    Material: "SmoothPlastic",
    Transparency: 1,
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  inst("ProximityPrompt", `${plotPath}.SellStation.SellPrompt`, { ActionText: "Open Sell", ObjectText: "Sell", HoldDuration: 0.2, MaxActivationDistance: 11 });
  addBillboard(`${plotPath}.SellStation.SellBillboard`, "Sell", 120, 38, v3(0, 5.2, 0), c3(18, 32, 24));
  meshPart(`${visualPath}.SellStationMesh`, "FTW_SellStation", {
    Size: v3(10.5, 12.5, 10.5),
    Position: v3(sell.x, 8.3, sell.z),
    Orientation: v3(0, yaw, 0),
    Material: "SmoothPlastic",
    CanQuery: false,
  }, { PlotId: plotNumber });

  const upgrade = localToWorld(cx, cz, angle, 31, 0);
  part(`${plotPath}.UpgradeStation`, {
    Anchored: true,
    CanCollide: true,
    Size: v3(8, 6, 6),
    Position: v3(upgrade.x, 6.2, upgrade.z),
    Orientation: v3(0, yaw, 0),
    Color: c3(89, 72, 137),
    Material: "Metal",
    Transparency: 0.04,
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  inst("ProximityPrompt", `${plotPath}.UpgradeStation.UpgradePrompt`, { ActionText: "Open Upgrades", ObjectText: "Upgrades", HoldDuration: 0.2, MaxActivationDistance: 11 });
  addBillboard(`${plotPath}.UpgradeStation.UpgradeBillboard`, "Upgrades", 150, 38, v3(0, 4.2, 0), c3(26, 20, 42));
  addMachineParts(`${visualPath}.SnackMachineA`, cx, cz, angle, -23, -17, theme, "tall");
  addMachineParts(`${visualPath}.SnackMachineB`, cx, cz, angle, -23, 17, theme, "short");

  ensureFolder(`${plotPath}.Plates`);
  const plateLocals = [
    [-12, 6], [0, 6], [12, 6],
    [-12, -6], [0, -6], [12, -6],
    [-19, 0], [19, 0], [-6, -16], [6, -16],
  ];
  plateLocals.forEach(([lx, lz], pIndex) => {
    const plateNumber = pIndex + 1;
    const unlocked = plateNumber <= 6;
    const pos = localToWorld(cx, cz, angle, lx, lz);
    const platePath = `${plotPath}.Plates.Plate${plateNumber}`;
    part(platePath, {
      Anchored: true,
      CanCollide: false,
      Shape: "Cylinder",
      Size: unlocked ? v3(6.4, 0.55, 6.4) : v3(4.3, 0.42, 4.3),
      Position: v3(pos.x, 3.6, pos.z),
      Orientation: v3(0, 0, 0),
      Color: unlocked ? theme.accent : c3(67, 61, 78),
      Material: unlocked ? "Glass" : "SmoothPlastic",
      Transparency: unlocked ? 0.22 : 0.42,
    }, { PlotId: plotNumber, PlateIndex: plateNumber, Occupied: false, GrowthStage: 0, GeneratedByPhase4Map: true });
    inst("ProximityPrompt", `${platePath}.PlatePrompt`, {
      ActionText: unlocked ? "Plant Snack" : "Upgrade Plate",
      ObjectText: `Plate ${plateNumber}`,
      HoldDuration: 0.15,
      MaxActivationDistance: 9,
      Enabled: true,
    });
    if (unlocked) {
      meshPart(`${visualPath}.GrowPlateMesh${plateNumber}`, "FTW_GrowPlate", {
        Size: v3(8.9, 2.6, 8.9),
        Position: v3(pos.x, 4.35, pos.z),
        Orientation: v3(0, yaw, 0),
        Color: c3(255, 255, 255),
        CanQuery: false,
      }, { PlotId: plotNumber, PlateIndex: plateNumber });
      inst("PointLight", `${platePath}.PlateGlow`, {
        Brightness: 0.18,
        Range: 8,
        Color: theme.trim,
        Shadows: false,
      });
    }
  });

  for (let r = 1; r <= 4; r += 1) {
    const horizontal = r <= 2;
    const side = r === 1 || r === 3 ? -1 : 1;
    const pos = horizontal ? localToWorld(cx, cz, angle, 0, side * 25) : localToWorld(cx, cz, angle, side * 35, 0);
    part(`${plotPath}.Rail${r}`, {
      Anchored: true,
      CanCollide: true,
      Size: horizontal ? v3(56, 2.2, 1.1) : v3(1.1, 2.2, 42),
      Position: v3(pos.x, 5.1, pos.z),
      Orientation: v3(0, yaw, 0),
      Color: stone.rail,
      Material: "Metal",
      Transparency: 0,
    }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  }

  for (let post = 0; post < 10; post += 1) {
    const side = post < 5 ? -1 : 1;
    const t = (post % 5) / 4;
    const pos = localToWorld(cx, cz, angle, -26 + t * 52, side * 26);
    part(`${visualPath}.FencePost${post + 1}`, {
      Anchored: true,
      CanCollide: true,
      Size: v3(1.2, 3.2, 1.2),
      Position: v3(pos.x, 5.3, pos.z),
      Orientation: v3(0, yaw, 0),
      Color: stone.railCap,
      Material: "Metal",
    }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  }

  const snackAssets = ["FTW_Snack_RoundBase", "FTW_Snack_CubeBase", "FTW_Snack_WrapBase"];
  for (let s = 0; s < 5; s += 1) {
    const sx = -22 + s * 11;
    const sz = s % 2 === 0 ? -27.5 : 27.5;
    const pos = localToWorld(cx, cz, angle, sx, sz);
    meshPart(`${propPath}.SnackDisplay${s + 1}`, snackAssets[(s + index) % snackAssets.length], {
      Size: v3(4.6 + (s % 2), 3.2, 4.6 + ((s + 1) % 2)),
      Position: v3(pos.x, 5.0 + (s % 2) * 0.6, pos.z),
      Orientation: v3(0, yaw + s * 23, 0),
      CanQuery: false,
    }, { PlotId: plotNumber });
  }

  part(`${visualPath}.ThemeSignPost`, {
    Anchored: true,
    CanCollide: true,
    Size: v3(1.3, 5.2, 1.3),
    Position: v3(sign.x, 4.5, sign.z),
    Orientation: v3(0, yaw, 0),
    Color: stone.wood,
    Material: "WoodPlanks",
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  part(`${visualPath}.ThemeSignBoard`, {
    Anchored: true,
    CanCollide: false,
    Size: v3(15, 4, 0.45),
    Position: v3(sign.x, 8.5, sign.z),
    Orientation: v3(0, yaw, 0),
    Color: theme.dark,
    Material: "SmoothPlastic",
  }, { PlotId: plotNumber, GeneratedByPhase4Map: true });
  addBillboard(`${visualPath}.ThemeSignBoard.ThemeBillboard`, theme.label, 220, 52, v3(0, 1.8, 0), theme.dark);
}

function addDecorations() {
  for (let i = 0; i < 36; i += 1) {
    const p = radial(i, 36, 64 + (i % 5) * 18, 0.17);
    const height = 7 + (i % 7) * 2.6;
    const size = v3(5 + (i % 4) * 2.1, 3 + (i % 3) * 1.5, 4.5 + (i % 5));
    part(`Workspace.GameWorld.Decorations.FloatingRocks.Rock${i + 1}`, {
      Anchored: true,
      CanCollide: false,
      Size: size,
      Position: v3(p.x, height, p.z),
      Orientation: v3((i * 13) % 28, (i * 47) % 180, (i * 19) % 24),
      Color: i % 2 === 0 ? stone.mid : stone.lip,
      Material: "Rock",
    }, { GeneratedByPhase4Map: true });
  }

  for (let i = 0; i < 16; i += 1) {
    const p = radial(i, 16, 88 + (i % 4) * 18, 0.05);
    part(`Workspace.GameWorld.Decorations.OuterAsteroids.Asteroid${i + 1}`, {
      Anchored: true,
      CanCollide: false,
      Shape: "Ball",
      Size: v3(18 + (i % 4) * 7, 13 + (i % 3) * 5, 17 + (i % 5) * 4),
      Position: v3(p.x, -4 + (i % 6) * 5, p.z),
      Orientation: v3((i * 9) % 35, (i * 29) % 180, (i * 7) % 20),
      Color: i % 2 === 0 ? c3(33, 29, 43) : c3(44, 37, 55),
      Material: "Rock",
      Transparency: 0.02,
    }, { GeneratedByPhase4Map: true });
  }

  for (let i = 0; i < 24; i += 1) {
    const p = radial(i, 24, i % 2 === 0 ? 38 : 145, 0.11);
    const crystalColor = i % 2 === 0 ? c3(126, 93, 186) : c3(78, 151, 176);
    part(`Workspace.GameWorld.Decorations.Crystals.Crystal${i + 1}`, {
      Anchored: true,
      CanCollide: false,
      Shape: "Cylinder",
      Size: v3(2.2 + (i % 3) * 0.4, 5 + (i % 5), 2.2 + (i % 3) * 0.4),
      Position: v3(p.x, 4 + (i % 3) * 0.6, p.z),
      Orientation: v3(0, (i * 31) % 180, 8 + (i % 5)),
      Color: crystalColor,
      Material: "Glass",
      Transparency: 0.18,
    }, { GeneratedByPhase4Map: true });
  }

  const foodRingAssets = ["FTW_Snack_RoundBase", "FTW_Snack_CubeBase", "FTW_Snack_WrapBase", "FTW_VoidCrumbPickup"];
  for (let i = 0; i < 18; i += 1) {
    const p = radial(i, 18, 35 + (i % 4) * 10, 0.23);
    meshPart(`Workspace.GameWorld.Decorations.FoodProps.Prop${i + 1}`, foodRingAssets[i % foodRingAssets.length], {
      Size: v3(3.7 + (i % 3) * 0.8, 2.7 + (i % 2) * 0.5, 3.7 + (i % 4) * 0.6),
      Position: v3(p.x, 4.0 + (i % 2) * 0.35, p.z),
      Orientation: v3(0, (i * 37) % 180, 0),
      CanQuery: false,
    });
  }

  for (let i = 0; i < 8; i += 1) {
    const p = radial(i, 8, 158, 0.06);
    meshPart(`Workspace.GameWorld.Decorations.OuterAsteroids.VoidmiteStatue${i + 1}`, "FTW_Voidmite", {
      Size: v3(9, 6.5, 8),
      Position: v3(p.x, 6, p.z),
      Orientation: v3(0, p.yaw + 180, 0),
      CanQuery: false,
      Transparency: 0.08,
    }, { DecorativeOnly: true });
  }
}

function addPhase4Map() {
  addAssetLibrary();
  addLighting();
  addWorldRoots();
  addCentralArena();
  for (let i = 0; i < 8; i += 1) {
    addPlotIsland(i);
  }
  addDecorations();
}

const assetManifestSource = `
local FTWAssetManifest = {
\tPhase = "4-map",
\tNote = "Imported FTW mesh assets are cataloged here so map visuals can use real 3D assets while gameplay anchors remain stable.",
\tLibraryRoot = "ReplicatedStorage.Assets.Models",
\tImportedWorkspaceOriginals = "ReplicatedStorage.Assets.ImportedWorkspaceOriginals",
\tAssets = {
${Object.entries(FTW_ASSETS).map(([name, asset]) => `\t\t${name} = {
\t\t\tFolder = "${asset.folder}",
\t\t\tPath = "ReplicatedStorage.Assets.Models.${asset.folder}.${name}",
\t\t\tMeshId = "${asset.meshId}",
\t\t\tTextureID = "${asset.textureId}",
\t\t},`).join("\n")}
\t},
}

return FTWAssetManifest
`;

addPhase4Map();
writeScript("ReplicatedStorage.Shared.FTWAssetManifest", "ModuleScript", "shared/FTWAssetManifest.lua", assetManifestSource);

fs.writeFileSync(path.join(outDir, "PHASE4_MAP_TESTING.md"), `# FEED THE VOID Phase 4 Map Testing

## Visual target
- Confirm the old blocky/Neon-heavy map has been replaced by a floating snack-lab diorama.
- Confirm The Void is a large 3D mesh landmark in the center.
- Confirm every plot has a themed island, chunky stone edge, machines, six hero grow pads, rails, and snack props.
- Confirm loose top-level Workspace.FTW_* imports are moved into ReplicatedStorage.Assets.ImportedWorkspaceOriginals after live cleanup.

## Gameplay smoke
- Press Play and confirm spawn/plot assignment still works.
- Walk to at least two islands over the bridges.
- Trigger Seeds, Sell, Display, Upgrade, and Feed prompts.
- Plant on an unlocked grow plate and confirm the prompt/remote still works.
- Check Output for fresh actionable errors.

## Material check
- Static map parts should use Slate, Rock, Concrete, SmoothPlastic, Metal, Glass, WoodPlanks, and Grass.
- Neon should not be used for the rebuilt static map.
`, "utf8");

const blueprint = {
  ...baseBlueprint,
  name: "FEED THE VOID Phase 4 Premium Reference Map Rebuild",
  mode: "supervised",
  description: "Rebuilds Workspace.GameWorld as a premium floating snack-lab map inspired by the supplied reference, catalogs imported FTW mesh assets, removes bright Neon from the static map, and preserves all gameplay-critical prompt anchors.",
  steps,
  metadata: {
    phase: "4-map",
    generatedAt: new Date().toISOString(),
    baseBlueprint: path.relative(root, phase3BlueprintPath).replace(/\\/g, "/"),
    removedBasePathPrefixes: ["Workspace.GameWorld"],
    ftwAssets: Object.fromEntries(Object.entries(FTW_ASSETS).map(([name, asset]) => [name, {
      folder: asset.folder,
      meshId: asset.meshId,
      textureId: asset.textureId,
    }])),
    sourceHashes: {
      FTWAssetManifest: sourceHash(assetManifestSource),
    },
  },
};

fs.writeFileSync(blueprintPath, JSON.stringify(blueprint, null, 2), "utf8");

console.log(JSON.stringify({
  ok: true,
  blueprintPath,
  outDir,
  stepCount: steps.length,
  ftwAssetCount: Object.keys(FTW_ASSETS).length,
}, null, 2));
