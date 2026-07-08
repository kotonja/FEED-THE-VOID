# FEED THE VOID Phase 4 Retention Testing

## Bridge apply
- Apply only `feed_the_void_phase4_retention_overlay.blueprint.json`; it is an overlay and does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Remotes` contains `RequestClaimPlaytimeReward`, `RequestClaimDailyReward`, `RequestCatchPhantomSnack`, and `RequestUpdateSettings`.
- Confirm `StarterGui.MainUI` contains `NextGoalPanel`, `QuickActions`, `PlaytimeRewardsPanel`, `DailyRewardPanel`, `SettingsPanel`, and `SeedShopPanel.RestockLabel`.
- Confirm `Workspace.GameWorld.Stations.DailyRewardChest.Base.DailyRewardPrompt` exists.

## Solo smoke
- Press Play and confirm the first sync shows coins, quests, shop stock/restock, next goal, daily reward, and playtime reward state.
- Claim the daily reward from the panel or chest prompt, then confirm it cannot be claimed again immediately.
- Let the session run until the 2 minute playtime reward or use the panel to confirm the countdown is accurate.
- Buy starter seeds, plant, harvest, sell/feed, and confirm Next Goal advances.
- Use Studio debug `!event PhantomSnackChase` or display a rare snack to verify Phantom Snacks spawn with catch prompts.
- Check Output for fresh errors after each flow.

## Multiplayer-facing smoke
- Start a 2-player local server if available.
- Confirm each player receives a plot, their own data snapshot, their own daily/playtime state, and shared Phantom event visibility.
- Confirm catching a Phantom Snack rewards only the catching player while the event participation bonus can reward participants at event end.
