# FEED THE VOID Phase 14 Imported Assets QA

## Bridge apply
- Apply `feed_the_void_phase14_imported_assets_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Shared.GameConfig.BuildVersion` is `0.1.0-private`.
- Confirm `ReplicatedStorage.Assets.Models.{Void,Creatures,Seeds,Growth,Snacks,Plot,Stations,Events,Pickups,Rewards}` and `ReplicatedStorage.Assets.Duplicates` exist.
- Confirm `ServerScriptService.Server.Services.AssetOrganizerService` exists.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID HEALTH CHECK]` with zero fatal failures and no script parse errors.
- Run `!assetcheck`, `!assetshowcase`, `!clearassetshowcase`, `!health`, `!smoketest`, and `!first10check`.
- Confirm health and smoke include asset organized/loose/missing counts.

## Gameplay acceptance
- Plant a snack and confirm Stage 1 uses sprout when imported, Stage 2 uses bud when imported, and Stage 3 prefers snack-specific assets.
- Confirm grown snack bottoms remain above the plate and do not sink through or cover the full plate.
- Start SnackRain, MutationSurge, VoidInfestation, GoldenHunger, and PhantomSnackChase with `!event <EventName>`; imported event props should appear when available.
- Confirm missing FTW_PlaytimeRewardClock, FTW_VoidShardPickup, FTW_UpgradeStation, FTW_RebirthPortal, and FTW_VoidlingPet use fallbacks/warnings only and never crash.

## Asset organization
- No top-level `Workspace.FTW_*` imports should remain after edit-time organization or first server start.
- If a duplicate exists, it should be under `ReplicatedStorage.Assets.Duplicates`, not disabled or destroyed.
- Imported MeshPart texture payloads must not be recolored by mutation styling.

## Guardrails
- No paid monetization, trading, stealing, pets, second world, new Meshy dependency, or client-authoritative rewards.
- Phase 14 integrates imported assets and organization only; it does not rebuild the user-made map.
