# Phase 18 Implementation Plan - Cash In Treasure Train Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `cashInTreasureTrain` action for selected units with treasure.

## Scope

- Add guarded app-state action for `cashInTreasureTrain unit=...`.
- Add local mock fallback mutation for deterministic local behavior.
- Add unit-panel UI affordance to trigger treasure cash-in.
- Add CLI regression coverage to verify `cashInTreasureTrain` payload.

## Execution Steps

1. [x] Add local model helper to clear treasure amount for a unit in mock mode.
2. [x] Add `canCashInSelectedTreasureTrain` and `cashInSelectedTreasureTrain()` in `GameState`.
3. [x] Add unit-panel button for treasure cash-in in `GameView`.
4. [x] Add CLI integration test to verify `cashInTreasureTrain` send path.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

## Expected Result

For a selected treasure-carrying unit, the client can send `cashInTreasureTrain`, local mock mode clears treasure amount, and regression coverage verifies payload correctness.
