# FEED THE VOID Phase 13 Private Test QA

## Bridge apply
- Apply `feed_the_void_phase13_private_test_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Shared.GameConfig.BuildVersion` is `0.1.0-private`.
- Confirm `ReplicatedStorage.Shared.LaunchPageConfig`, `ServerScriptService.Server.Services.BugReportService`, and `Workspace.GameWorld.ScreenshotSpots` exist.
- Confirm `ReplicatedStorage.Remotes.PlaySound` and `ReplicatedStorage.Remotes.PlayEffect` each exist exactly once.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID HEALTH CHECK]` with zero fatal failures and no script parse errors.
- Run `!health`, `!smoketest`, `!first10check`, `!snapshot`, `!screenshotspots`, `!mixcheck`, `!vfxstatus`, and `!privatetestcheck`.
- Confirm health and smoke include FeatureFreeze, LaunchPageConfig, BugReportService, audio, VFX, and screenshot spots.

## Gameplay acceptance
- Plant, grow, ready, harvest, sell, feed, display, buy, upgrade, cleanse, catch phantom, claim rewards, and rebirth all show cosmetic VFX only after server validation.
- Rare harvest/feed effects are stronger than common effects without blinding the screen.
- Reward popups stack cleanly and passive income does not spam.
- Event starts show central bursts and event banners without hundreds of particles.

## UI and settings
- Panels slide/fade open and close without leaving invisible blockers.
- Buttons pulse on tap/click.
- Notifications slide/fade and stack at three visible messages.
- Coins, tokens, rebirths, and hunger pulse when values increase.
- ReduceEffects lowers burst intensity; LowDetailMode removes idle particle extras; HideExtraPopups suppresses non-critical popups.

## Guardrails
- No paid monetization, trading, stealing, pets, second world, new Meshy dependency, or client-authoritative rewards.
- Effects use temporary bursts and Debris cleanup; no server per-frame visual animation was added.
- Phase 13 adds debug/reporting/private-test polish only, not new gameplay systems.
