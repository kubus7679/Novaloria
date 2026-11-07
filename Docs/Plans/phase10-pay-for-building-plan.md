# Phase 10 Implementation Plan - Pay For Building Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `payForBuilding` action for selected colonies.

## Scope

- Add guarded app-state action for `payForBuilding colony=...`.
- Add colony panel UI affordance to trigger the action.
- Extend CLI regression coverage to verify `payForBuilding` payload.

## Execution Steps

1. [x] Add `payForSelectedColonyBuilding()` in `GameState` with legality checks.
2. [x] Add `Pay For Building` button in colony panel wiring.
3. [x] Extend `FreeColProtocolCLI` colony action integration to verify `payForBuilding` send.
4. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

From colony controls, the client can send `payForBuilding` for the selected colony, and regression coverage verifies the protocol payload.
