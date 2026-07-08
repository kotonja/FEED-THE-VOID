# FEED THE VOID Phase 15 Private Test QA

## Bridge apply
- Apply `feed_the_void_phase15_private_test_qa_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Shared.GameConfig.BuildVersion` is `0.1.0-private`.
- Confirm `ReplicatedStorage.Shared.GameConfig.Phase` is `15-private-test-qa`.
- Confirm `ReplicatedStorage.Assets.Models.{Void,Creatures,Seeds,Growth,Snacks,Plot,Stations,Events,Pickups,Rewards}` and `ReplicatedStorage.Assets.Duplicates` exist.
- Confirm `ServerScriptService.Server.Services.AssetOrganizerService` exists.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID HEALTH CHECK]` with zero fatal failures and no script parse errors.
- Run `!health`, `!smoketest`, `!first10check`, `!privatetestcheck`, `!assetcheck`, `!assetshowcase`, and `!clearassetshowcase`.
- Confirm health, smoke, and private-test checks include first-session, mobile, and asset organized/loose/missing counts.

## Gameplay acceptance
- Plant a snack and confirm Stage 1 uses sprout when imported, Stage 2 uses bud when imported, and Stage 3 prefers snack-specific assets.
- Confirm grown snack bottoms remain above the plate and do not sink through or cover the full plate.
- Start SnackRain, MutationSurge, VoidInfestation, GoldenHunger, and PhantomSnackChase with `!event <EventName>`; imported event props should appear when available.
- Confirm missing FTW_PlaytimeRewardClock, FTW_VoidShardPickup, FTW_UpgradeStation, FTW_RebirthPortal, and FTW_VoidlingPet use fallbacks/warnings only and never crash.
- Confirm the mobile contextual action button only targets the local player's grow plates and lab stations.

## Asset organization
- No top-level `Workspace.FTW_*` imports should remain after edit-time organization or first server start.
- If a duplicate exists, it should be under `ReplicatedStorage.Assets.Duplicates`, not disabled or destroyed.
- Imported MeshPart texture payloads must not be recolored by mutation styling.

## Guardrails
- No paid monetization, unfinished social systems, companion systems, second world, new Meshy dependency, or client-authoritative rewards.
- Phase 15 is private-test stabilization only; it does not rebuild the user-made map.
