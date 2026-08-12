# Phase 7: Java-Client Parity Pass — Missing Message Handlers + Debug/UX Cleanup

## Objective

Close the server→client message-handling gaps identified against the Java client, fix outbound wire-shape mismatches (`setColor`, `setAvailable`), and remove leftover debug output / raw debug UI in the Swift client.

## Gap Analysis Summary

- Registry: 103 tags. Handled as receive-path: 20. Unhandled receive-path candidates: 31 (many are client→server-only in Java; those need no handler).
- FreeCol 1.x generalizes state changes into change records inside `<update>` (`ChangeSet.java`: `UpdateMessage`, `AddPlayerMessage`, `RemoveMessage`, `PartialMessage`, `SetStanceMessage`, `SetAIMessage`, `AttributeMessage`, `FeatureChangeMessage`, `SpySettlementMessage`).
- `applyUpdate` currently drops all nested change records except model children (`player`, `tile`, `unit`, `colony`, `game`) — nested `addPlayer`/`remove`/`partial`/`setStance`/`setAI`/`setDead` are silently lost.
- Real top-level server→client messages with no handler: `chat`, `gameEnded`, `logout`, `fountainOfYouth`, `indianDemand`, `lootCargo`, plus change-record forms of `setStance`, `setAI`, `setDead`, `setNation`, `setNationType`, `setColor`, `setAvailable` (wire shapes verified against Java source).
- Outbound parity bugs: `setColor` sends `player`/`value` but Java reads `nation`+`color` (RGB int); `setAvailable` sends `player` but Java reads `nation`+`state`.
- Debug leftovers: unconditional per-render `print` in `MapView.renderData`; always-visible `DEBUG phase=...` text in `LoginView`.

## Scope

- [x] **Model (`FreeColGame`)**: `Player.stances` dict + `<stance>` child parsing; `Game.nationColors` / `Game.nationStates`; shared player-mutation helpers (`applySetStance`, `applySetAI`, `applySetDead`, `applySetNation`, `applySetNationType`, `applySetColor`, `applySetAvailable`); nested change-record handling inside `<update>` (`addPlayer`, `remove`, `partial`, `setStance`, `setAI`, `setDead`, `setNation`, `setNationType`, `setColor`, `setAvailable`; log-ignore `attribute`/`featureChange`).
- [x] **GameStateManager**: top-level cases routing to the same helpers; `logout` removes the player and owned units.
- [x] **GameState / UI**:
  - [x] inbound `chat` → `incomingChatLog` (shown in GameView Chat box)
  - [x] `gameEnded` → game-over status + block of turn actions
  - [x] `logout` of the local player → status message
  - [x] `fountainOfYouth`, `indianDemand`, `lootCargo` → status placeholders (interactive dialogs deferred)
  - [x] outbound parity fixes: `setColor` (`nation` + `color` RGB int, hex→RGB conversion), `setAvailable` (`nation` + `state` toggle)
- [x] **Cleanup**: remove `MapView` per-render debug prints; remove `LoginView` DEBUG status line.
- [x] **CLI regressions**: unit tests for all new handlers + nested-record application; integration tests for inbound `setStance`/`logout`/`chat` and corrected outbound `setColor`/`setAvailable` shapes.

## Out of scope (deferred)

- Full dialog flows for `fountainOfYouth`, `indianDemand`, `lootCargo`, `diplomacy`, `nativeTrade`, `newLandName`/`newRegionName` prompts, `monarchAction` announcements (status placeholders only; prompts remain surfaced in the status bar).
- `highScores`/`nationSummary` display surfaces.

## Execution Steps

1. [x] `Player.stances: [String: Stance]` + `<stance player value>` parsing in `Player.init`.
2. [x] `Game`: `nationColors`, `nationStates` dicts; mutation helpers; extend `applyUpdate` for nested change records.
3. [x] `GameStateManager`: `setStance`, `setAI`, `setDead`, `setNation`, `setNationType`, `setColor`, `setAvailable`, `logout` cases.
4. [x] `GameState`: `incomingChatLog`, `isGameEnded`, status cases (`chat`, `gameEnded`, `logout`, `fountainOfYouth`, `indianDemand`, `lootCargo`); corrected `setLocalPlayerColor`/`setLocalPlayerAvailable` sends.
5. [x] `GameView`: incoming-chat display in the Chat box; disable turn actions when game ended.
6. [x] Remove `MapView` debug prints and `LoginView` DEBUG line.
7. [x] CLI regressions (unit + integration), update the two changed outbound-shape tests.
8. [x] Update `plans.md` + roadmap.

## Validation

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`
- [x] `swift test`

## Expected Result

Server-driven stance/AI/death/nation/color/availability changes land in the client model whether delivered top-level or nested in `<update>`; inbound chat, game-over and logout are visible in the UI; outbound lobby color/availability messages match the Java wire format; no per-render debug output or always-on DEBUG UI text remains.