# Phase 53: Open Points Cleanup

## Objective

Resolve the remaining documented open points after Phases 1–52: local-game
(mock) coverage, native settlement UI surfacing, and the colony
availability/production approximations.

## Items

1. **Mock server coverage (plans.md "Current Gaps", phase-6 robustness)**
   - `GameState.startLocalServerLoop` answers post-login client messages for
     local games: `endTurn` advances the turn (`<newTurn>` +
     `<setCurrentPlayer>`) and `chat` is echoed back. This makes the local
     game's "End Turn" work instead of leaving it stuck.
2. **46C/46D UI surfacing**
   - `GameView.unitQuickActions` gains a **Native Settlement** menu (Trade,
     Deliver Gift, Demand Tribute, Spy, Scout Settlement, Incite) driven by the
     existing `GameState` actions and `nativeTradeTargetsForSelectedUnit`.
   - A **Cargo** list shows the selected carrier's embarked units and allows
     selecting them (enabling unload/disembark via the existing flow).
   - `GameState.directionToAdjacentSettlement(_:)` computes the compass
     direction for the tribute/scout actions.
3. **Colony build-queue availability (Phase 48 limitation)**
   - `GameState.buildableBuildingCandidates` (testable static) now also requires
     the `upgrades-from` predecessor to be present for upgrade buildings.
4. **Colony production estimate (Phase 50 limitation)**
   - `Specification.TileTypeInfo` parses `<tile-type>` unattended production;
     `estimatedProduction`/`estimatedBuildPerTurn`/`estimatedBuildTurns` accept
     an optional `centerTileType` and add the colony-center tile output.

## Validation

- `swift build`
- `swift test` (36)
- `swift run FreeColProtocolCLI` (129)

## Notes

- Phase 6 plan items 4 ("extend reconnect UX if needed") and 4 ("additional
  reject reconciliation if more shapes appear") are monitoring items with no
  concrete trigger; they remain documented rather than scheduled.
- A true right-click `TilePopup` is not feasible while the map NSView captures
  right-clicks; the same actions are exposed through the quick-actions panel and
  the info panel instead.

## Follow-up (second pass)

- **Financial report**: `ReportKind.financial` (gold, tax, arrears, purchases,
  sales, net balance).
- **Trade route editor**: stop reordering (up/down) and a "Current Stop" stepper
  for the unit assigned to the edited route.
- **Colony build list**: candidate labels include the construction-goods cost.
- **Analysis recommendation #3 (performance)**: assessed as non-critical at the
  current map sizes; lookups are built locally per render/report rather than as
  a persistent cache, which avoids stale-index bugs.
- Validation: `swift build`, `swift test` (36), `swift run FreeColProtocolCLI`
  (129).
