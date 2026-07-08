const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "build", "feed_the_void_phase16");
const sourcePath = path.join(outDir, "src", "shared", "SizeConfig.lua");
const repairPath = path.join(outDir, "phase16_sizeconfig_repair.blueprint.json");
const source = fs.readFileSync(sourcePath, "utf8").replace(/\r\n/g, "\n").trimStart();

const blueprint = {
  name: "FEED THE VOID Phase 16 SizeConfig Repair",
  mode: "supervised",
  description: "Writes the Phase 16 SizeConfig source after a new empty ModuleScript was created in Studio.",
  steps: [
    {
      type: "ensureFolder",
      path: "ReplicatedStorage.Shared",
    },
    {
      type: "ensureInstance",
      path: "ReplicatedStorage.Shared.SizeConfig",
      className: "ModuleScript",
      properties: {},
    },
    {
      type: "writeScript",
      path: "ReplicatedStorage.Shared.SizeConfig",
      className: "ModuleScript",
      sourceFile: "src/shared/SizeConfig.lua",
      source,
      overwrite: true,
    },
  ],
};

fs.writeFileSync(repairPath, `${JSON.stringify(blueprint, null, 2)}\n`);
console.log(JSON.stringify({ ok: true, repairPath, stepCount: blueprint.steps.length }, null, 2));
