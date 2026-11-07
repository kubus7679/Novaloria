# Phase 7 Implementation Plan - Put Outside Colony Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `putOutsideColony` action to colony management.

## Scope

- Add guarded app-state action for `putOutsideColony` on selected colony worker.
- Add local mock fallback mutation for deterministic UI behavior.
- Add colony panel button to trigger action.
- Extend CLI regression coverage for `putOutsideColony` payload.

## Execution Steps

1. [x] Add local model helper to place a unit from colony interior to colony tile.
2. [x] Add `canPutSelectedColonyWorkerOutside` + `putSelectedColonyWorkerOutside()` in `GameState`.
3. [x] Add `Put Outside Colony` button in colony panel wiring.
4. [x] Extend `FreeColProtocolCLI` colony action integration to verify `putOutsideColony` send.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

When a colony worker is selected, the app can send `putOutsideColony unit=...` and move the worker to colony tile in local mock mode; regression coverage verifies protocol payload.
