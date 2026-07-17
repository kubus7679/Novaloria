# Phase 14 Implementation Plan - Assign Trade Route Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `assignTradeRoute` action for selected units.

## Scope

- Add guarded app-state action for `assignTradeRoute unit=... tradeRoute=...`.
- Add local mock fallback mutation for deterministic local behavior.
- Add in-game UI affordance to assign/clear a selected unit trade route.
- Add CLI regression coverage to verify `assignTradeRoute` payload.

## Execution Steps

1. [x] Add local model helper to set/clear unit trade route in mock mode.
2. [x] Add `canAssignSelectedUnitTradeRoute`, `canClearSelectedUnitTradeRoute`, and send methods in `GameState`.
3. [x] Add unit-panel UI controls to assign/clear trade routes.
4. [x] Add CLI integration test to verify `assignTradeRoute` send path.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

## Expected Result

For a selected unit, the app can assign or clear a trade route via `assignTradeRoute`, and regression coverage verifies message payload correctness.
