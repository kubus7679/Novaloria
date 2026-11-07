# Phase 11 Implementation Plan - Abandon Colony Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `abandonColony` action for selected colonies.

## Scope

- Add guarded app-state action for `abandonColony colony=...`.
- Add local mock fallback mutation for deterministic local behavior when legal.
- Add colony panel UI affordance to trigger colony abandonment.
- Extend CLI regression coverage to verify `abandonColony` payload.

## Execution Steps

1. [x] Add local model helper to abandon a colony in mock mode.
2. [x] Add `canAbandonSelectedColony` + `abandonSelectedColony()` in `GameState`.
3. [x] Add `Abandon Colony` button in colony panel wiring.
4. [x] Extend `FreeColProtocolCLI` colony action integration to verify `abandonColony` send.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

From colony controls, the client can send `abandonColony` for the selected colony; in mock mode the colony is removed locally when legal, and regression coverage verifies the protocol payload.
