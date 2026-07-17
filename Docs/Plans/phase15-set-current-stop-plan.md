# Phase 15 Implementation Plan - Set Current Stop Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `setCurrentStop` action for selected units.

## Scope

- Add guarded app-state action for `setCurrentStop unit=... index=...`.
- Add local mock fallback mutation for deterministic local behavior.
- Add unit-panel UI affordance to set current stop index.
- Add CLI regression coverage to verify `setCurrentStop` payload.

## Execution Steps

1. [x] Add local model helper to set unit current stop in mock mode.
2. [x] Add `setSelectedUnitCurrentStop(_:)` in `GameState` with legality checks.
3. [x] Add unit-panel controls for current stop index in `GameView`.
4. [x] Add CLI integration test to verify `setCurrentStop` send path.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

## Expected Result

For a selected unit, the app can send `setCurrentStop` with a numeric stop index, and regression coverage verifies payload correctness.
