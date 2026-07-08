# FEED THE VOID Phase 10 Private Test Freeze QA

## Bridge apply
- Apply `feed_the_void_phase10_private_freeze_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Shared.GameConfig.BuildVersion` is `0.1.0-private` and `LaunchMode = "PrivateTest"`.
- Confirm `ReplicatedStorage.Shared.FeatureFlags` exists and monetization, trading, stealing, pets, and second world are false.
- Confirm `ServerScriptService.Server.Services` contains `FeedbackService`, `SmokeTestService`, and `HealthCheckService`.
- Confirm `ServerScriptService.Server.Util` contains `CooldownUtil`, `ValidationUtil`, `Maid`, and `SafeCall`.
- Confirm `StarterGui.MainUI.LoadingPanel`, `FeedbackButton`, and `FeedbackPanel` exist in StarterGui.
- Confirm `Workspace.GameWorld.Stations.PrivateTestBoards` exists with How To Play, Private Test, and Changelog boards.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID HEALTH CHECK]` with zero fatal failures and no script parse errors.
- Confirm the loading panel stays up until the first `SyncPlayerData` snapshot, then HUD/buttons appear.
- Use Studio chat `!health`, `!smoketest`, `!first10check`, and `!serverstatus`; confirm Output prints real Phase 10 counts.
- Submit a feedback message from the Feedback button, then run `!feedback` and confirm it appears in Output.
- Use `!event SnackRain`, `!disableevent SnackRain`, `!enableevent SnackRain`, and `!endevent`; confirm disabled events do not start and cleanup leaves no stale event objects.
- Use `!sethungerrequired 25`, `!setgrowmultiplier 5`, `!setvoidmitespeed 3`, and `!resetserverbalances`; confirm `!serverstatus` reflects the overrides.

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
