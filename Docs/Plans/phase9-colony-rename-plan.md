# Phase 9 Implementation Plan - Colony Rename Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `rename` action for selected colonies.

## Scope

- Add guarded app-state action for `rename name=... nameable=...`.
- Add local mock fallback mutation for deterministic colony-name updates.
- Add colony panel UI affordance to edit and submit colony name.
- Extend CLI regression coverage to verify `rename` payload.

## Execution Steps

1. [x] Add local model helper to rename a colony in mock mode.
2. [x] Add `renameSelectedColony(to:)` in `GameState` with legality checks.
3. [x] Add colony panel input/button for rename action.
4. [x] Extend `FreeColProtocolCLI` colony action integration to verify `rename` send.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

From colony controls, the client can rename the selected colony by sending `rename` with `name` and `nameable` attributes, with deterministic local mock update and regression coverage.
