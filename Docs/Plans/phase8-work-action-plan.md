# Phase 8 Implementation Plan - Work Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `work` action to colony worker controls.

## Scope

- Add guarded app-state action for `work unit=... workLocation=...`.
- Add local mock fallback mutation for deterministic local behavior.
- Add colony panel UI affordance to submit a work-location ID.
- Extend CLI regression coverage to verify `work` payload.

## Execution Steps

1. [x] Add local model helper to update a unit work location in mock mode.
2. [x] Add `setSelectedColonyWorkerWorkLocation(_:)` in `GameState` with legality checks.
3. [x] Add colony panel input/button for `workLocation` action.
4. [x] Extend `FreeColProtocolCLI` colony action integration to verify `work` send.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

From colony controls, the client can send `work` for the selected worker with a specified `workLocation`, with deterministic local mock update and protocol regression coverage.
