# FEED THE VOID Phase 7 Progression QA

## Bridge apply
- Apply `feed_the_void_phase7_progression_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Remotes` includes `RequestToggleItemLock`, `RequestClaimCollectionMilestone`, and `PlayEffect`.
- Confirm `ReplicatedStorage.Shared` contains `RarityConfig`.
- Confirm `ServerScriptService.Server.Services` contains `BalanceReportService`, `HealthCheckService`, and `ActivityFeedService`.
- Confirm `ServerScriptService.Server.Util` contains `CooldownUtil` and `ValidationUtil`.
- Confirm `StarterGui.MainUI.SeedShopPanel.SeedList` has buttons for all 15 configured snacks.
- Confirm `StarterGui.MainUI.InventoryPanel` has `SortButton`, `FilterButton`, `LockButton`, and `ConfirmPanel`.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID][Health]` with zero fatal failures and no script parse errors.
- Use Studio chat `!health` and confirm the player receives a health summary notification.
- Use `!balancereport` and confirm snack values print with no fatal warnings.
- Use `!unlockshop`, open the shop, and confirm starter seeds plus locked/unlocked higher-tier entries display cleanly.
- Buy seeds, plant, harvest, sort/filter inventory, lock an item, and confirm sell/feed/display reject while locked.
- Use `!giveitem MeteorMuffin Golden`; confirm valuable sell/feed shows confirmation before firing the remote.
- Claim a collection milestone when ready and confirm it cannot be claimed twice.
- Rebirth with debug coins; confirm the UI lists reset/stay rules and collections survive.

## Offline and events
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
- No sound work in Phase 7.
- No new Meshy assets or required imported models.
- No paid monetization, trading, stealing, pets, or second world.
- No Workspace map rebuild.
