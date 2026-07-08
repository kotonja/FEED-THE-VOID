# FEED THE VOID Phase 12 VFX QA

## Bridge apply
- Apply `feed_the_void_phase12_vfx_overlay.blueprint.json` as an overlay; it does not rebuild `Workspace.GameWorld`.
- Confirm `ReplicatedStorage.Shared.GameConfig.BuildVersion` is `0.1.2-vfx-private`.
- Confirm `ReplicatedStorage.Shared.VFXConfig`, `ServerScriptService.Server.Services.VFXService`, and `StarterPlayer.StarterPlayerScripts.Controllers.EffectsController` exist.
- Confirm `StarterPlayer.StarterPlayerScripts.Controllers.VFXController` is removed after the cleanup command.
- Confirm `ReplicatedStorage.Remotes.PlayEffect` exists exactly once and remains server-to-client cosmetic only.

## Solo smoke
- Press Play and confirm Output prints `[FEED THE VOID HEALTH CHECK]` with zero fatal failures and no script parse errors.
- Confirm health and smoke print `VFX: OK`, `cap=80`, and a sane particle budget.
- Use `!vfx Plant.Success`, `!vfx Harvest.Rare`, `!vfx Void.Feed`, `!vfx Void.EventStart`, `!vfxall`, `!clearvfx`, and `!vfxstatus`.
- Use `!soundstatus` too; Phase 12 should preserve the Phase 11 audio checks.

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
