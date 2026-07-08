# FEED THE VOID Phase 9 Private Test QA

## Bridge apply
- Apply `feed_the_void_phase9_hardening_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Shared.GameConfig` has `LaunchMode = "PrivateTest"`, `Performance`, `Limits`, `Security`, `InteractionDistances`, and `PrivateTest`.
- Confirm `ServerScriptService.Server.Services` contains `SecurityService`, `FailsafeService`, `HealthCheckService`, and `OnboardingService`.
- Confirm `ServerScriptService.Server.Util` contains `CooldownUtil`, `ValidationUtil`, and `Maid`.
- Confirm `StarterGui.MainUI.PrivateTestWatermark` exists and is small/non-blocking.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID][Health]` with zero fatal failures and no script parse errors.
- Use Studio chat `!health` and confirm the notification includes pass/warn/fail counts.
- Use Studio chat `!serverstatus`, `!plants`, `!inventorycheck`, `!voidmites`, and `!playerprogress`; confirm Output prints real counts.
- Use Studio chat `!eventstatus`, `!event SnackRain`, and `!endevent`; confirm event objects clean up.
- Tap `LAB`; confirm the player is safely returned to their own lab and cooldown messaging prevents spam.
- Use Studio chat `!tutorialreset`; plant, harvest, feed, display, cleanse, upgrade, and complete one objective. Confirm tutorial only advances after real actions.
- Fill inventory through `!giveitem` if needed; confirm harvesting is blocked before a ready snack is removed once the cap is reached.

## Security and lifecycle
- Fire malformed remotes only from Studio testing tools, never from client code, and confirm `[FEED THE VOID][Security]` warns without kicking.
- Respawn the player and confirm they return to their own plot without duplicate chat/respawn behavior.
- Leave and rejoin. Confirm planted/displayed snacks restore once, voidmites are cleaned for that player, and no duplicate prompts/remotes appear.
- Confirm display attempts are blocked at the Phase 9 display cap and do not delete the selected inventory item.
- Confirm distance checks reject plant/harvest/sell/feed/display/pickup/voidmite/phantom actions when far away.

## Offline, data, and events
- Plant a snack, leave before it finishes, rejoin later, and confirm it can finish offline but is not auto-harvested.
- Display snacks, rejoin later, and confirm capped offline display income is server-calculated and notified.
- Fill The Void with `!voidfill`; confirm an event starts, ends, clears `ActiveEventName`, and cleans objects.
- Test `!event SnackRain`, `!event MutationSurge`, `!event VoidInfestation`, `!event GoldenHunger`, and `!event PhantomSnackChase`.
- Confirm Snack Rain never exceeds `GameConfig.Limits.MaxSnackRainPickups`, Phantom Chase never exceeds `MaxPhantomSnacks`, and global voidmites never exceed `MaxVoidmitesGlobal`.

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
