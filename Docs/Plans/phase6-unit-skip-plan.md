# Phase 6 Implementation Plan - Unit Skip Action MVP

## Objective

Close one concrete gap from "missing action messages and UI affordances" by adding a skip-turn action for selected units.

## Scope

- Extend GameState legality checks for `changeState` to include `SKIPPED`.
- Add a dedicated in-game UI affordance (button) to set selected unit to skipped.
- Extend CLI regression coverage for `changeState` with `SKIPPED`.

## Execution Steps

1. [x] Extend `GameState.canChangeSelectedUnitState(to:)` to allow `.skipped` under local legality checks.
2. [x] Add `Skip` action button in `GameView` unit-state controls.
3. [x] Extend `FreeColProtocolCLI` integration test to verify `changeState state="SKIPPED"` send path.
4. [x] Validate with build + CLI suite.

## Validation

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

## Expected Result

In in-game unit controls, local player can explicitly skip a selected unit turn, and protocol regression confirms correct message payload (`changeState` with `SKIPPED`).
