# FEED THE VOID Phase 8 Private Test QA

## Bridge apply
- Apply `feed_the_void_phase8_guidance_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Remotes` includes `RequestTeleportToPlot`.
- Confirm `ReplicatedStorage.Shared` contains `GuidanceConfig`.
- Confirm `ServerScriptService.Server.Services` contains `FailsafeService`, `HealthCheckService`, and `OnboardingService`.
- Confirm `ServerScriptService.Server.Util` contains `CooldownUtil` and `ValidationUtil`.
- Confirm `StarterPlayer.StarterPlayerScripts.Controllers` contains `GuidanceController`.
- Confirm `StarterGui.MainUI.QuickActions` has `LabButton`.
- Confirm `StarterGui.MainUI.SettingsPanel` has `ShowGuidanceButton`.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID][Health]` with zero fatal failures and no script parse errors.
- Use Studio chat `!health` and confirm the notification includes pass/warn/fail counts.
- Use Studio chat `!guidetest`; confirm the Next Goal text changes and a beam/arrow points to the player's lab.
- Toggle Settings -> Show Guidance off and on; confirm the beam hides and returns.
- Tap `LAB`; confirm the player is safely returned to their own lab and cooldown messaging prevents spam.
- Use Studio chat `!tutorialreset`; plant, harvest, feed, display, cleanse, upgrade, and complete one objective. Confirm tutorial only advances after real actions.
- Use Studio chat `!simulatefirstsession`; confirm the first-session route starts with a lab/plate goal.
- Remove seeds/coins/items in a debug session if needed and confirm the emergency CookieRock seed is granted only when truly stuck.

## Guidance targets
- First join: Next Goal should resolve to the player's own plot or first empty plate.
- Ready snack: Next Goal should target the ready plate.
- Inventory snack: Next Goal should target The Void or Display Shelf depending on tutorial/goal state.
- Active event: Next Goal should point toward central/event objects.
- Voidmite: Next Goal should point to the local player's Voidmite or display shelf fallback.

## Offline, data, and events
- Plant a snack, leave before it finishes, rejoin later, and confirm it can finish offline but is not auto-harvested.
- Display snacks, rejoin later, and confirm capped offline display income is server-calculated and notified.
- Fill The Void with `!voidfill`; confirm an event starts, ends, clears `ActiveEventName`, and cleans objects.
- Test `!event SnackRain`, `!event MutationSurge`, `!event VoidInfestation`, `!event GoldenHunger`, and `!event PhantomSnackChase`.

## Multiplayer-facing smoke
- Start a 2-player local server if available.
- Confirm each player receives a plot and independent inventory/seed/lock data.
- Confirm locked items, collection claims, and shop unlock checks are server-side.
- Confirm shared events are visible to both players and rewards are granted only to the player who collected/caught the object.

## Guardrails
- No sound work in Phase 8 except fixing missing-ID warnings from existing configured keys.
- No new Meshy assets or required imported models.
- No paid monetization, trading, stealing, pets, or second world.
- No Workspace map rebuild.
