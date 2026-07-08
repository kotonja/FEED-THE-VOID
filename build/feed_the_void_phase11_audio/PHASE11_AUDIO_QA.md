# FEED THE VOID Phase 11 Audio QA

## Bridge apply
- Apply `feed_the_void_phase11_audio_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Shared.GameConfig.BuildVersion` is `0.1.1-audio-private` and `LaunchMode = "PrivateTest"`.
- Confirm `ReplicatedStorage.Shared.FeatureFlags` exists and monetization, trading, stealing, pets, and second world are false.
- Confirm `ReplicatedStorage.Shared.SoundConfig` contains the Phase 11 nested audio config.
- Confirm `ServerScriptService.Server.Services` contains `AudioService`, `FeedbackService`, `SmokeTestService`, and `HealthCheckService`.
- Confirm `ServerScriptService.Server.Util` contains `CooldownUtil`, `ValidationUtil`, `Maid`, and `SafeCall`.
- Confirm `StarterPlayer.StarterPlayerScripts.Controllers.SoundController` exists.
- Confirm `ReplicatedStorage.Remotes.PlaySound` exists exactly once.
- Confirm `SoundService.Master`, `UI`, `SFX`, and `Ambience` exist as SoundGroups.
- Confirm `StarterGui.MainUI.LoadingPanel`, `FeedbackButton`, and `FeedbackPanel` exist in StarterGui.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID HEALTH CHECK]` with zero fatal failures and no script parse errors.
- Confirm the loading panel stays up until the first `SyncPlayerData` snapshot, then HUD/buttons appear.
- Use Studio chat `!health`, `!smoketest`, `!first10check`, and `!serverstatus`; confirm Output prints real Phase 11 counts.
- Confirm health/smoke prints audio counts like `Audio: 34 valid, 3 disabled, 0 malformed`.
- Use `!soundtest UI.Click`, `!soundtest Void.Feed`, `!soundtestall`, `!soundstatus`, and `!stopsounds`.
- Submit a feedback message from the Feedback button, then run `!feedback` and confirm it appears in Output.
- Use `!event SnackRain`, `!disableevent SnackRain`, `!enableevent SnackRain`, and `!endevent`; confirm disabled events do not start and cleanup leaves no stale event objects.
- Use `!sethungerrequired 25`, `!setgrowmultiplier 5`, `!setvoidmitespeed 3`, and `!resetserverbalances`; confirm `!serverstatus` reflects the overrides.

## Audio acceptance
- Click major buttons and open/close panels; UI sounds should be soft and not harsh.
- Toggle Settings > Mute Sounds on/off; sounds should silence immediately and return after unmute.
- Plant a snack, trigger growth with `!setgrowmultiplier 5`, wait for ready, and harvest. Confirm plant, growth, ready, and harvest sounds.
- Buy a seed, buy an upgrade, sell, feed The Void, and display a snack. Confirm success sounds wait for server confirmation.
- Feed The Void through milestone thresholds and confirm `Void.Rumble` plays once per threshold.
- Start SnackRain, MutationSurge, VoidInfestation, GoldenHunger, and PhantomSnackChase through debug; confirm event start sounds.
- Collect a SnackRain pickup and catch a Phantom Snack; confirm pickup/catch sounds.
- Spawn or wait for Voidmites, then cleanse one; confirm spawn/cleanse sounds without double spam.
- Confirm map ambience and central Void idle loop are quiet and do not stack after respawn.

## Private test guardrails
- No paid monetization prompts, trading, stealing, pets, second world, or new Meshy dependency.
- QuestComplete, DailyClaim, and PlaytimeClaim are intentionally `rbxassetid://0` and should skip silently.
- No runtime script-created owner signs, old generated world folders, or Workspace map rebuilds.
- Missing or failed sounds must never block gameplay, loading, rewards, health, or smoke checks.
