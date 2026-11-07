# Phase 12 Implementation Plan - Set Goods Levels Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `setGoodsLevels` action for selected colonies.

## Scope

- Add guarded app-state action for `setGoodsLevels colony=...`.
- Add colony panel UI affordance to trigger the action.
- Extend CLI regression coverage to verify `setGoodsLevels` payload.

## Execution Steps

1. [x] Add `setSelectedColonyGoodsLevels()` in `GameState` with legality checks.
2. [x] Add `Set Goods Levels` button in colony panel wiring.
3. [x] Extend `FreeColProtocolCLI` colony action integration to verify `setGoodsLevels` send.
4. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

From colony controls, the client can send `setGoodsLevels` for the selected colony, and regression coverage verifies the protocol payload.
