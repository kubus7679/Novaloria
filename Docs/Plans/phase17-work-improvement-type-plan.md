# Phase 17 Implementation Plan - Work Improvement Type Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `changeWorkImprovementType` action for selected colony workers.

## Scope

- Ensure `workImprovementType` is parsed into the unit model.
- Add guarded app-state action for `changeWorkImprovementType unit=... improvementType=...`.
- Add local mock fallback mutation for deterministic local behavior.
- Add colony panel UI affordance for setting work improvement type.
- Add CLI regression coverage to verify `changeWorkImprovementType` payload.

## Execution Steps

1. [x] Parse/store `workImprovementType` in unit/game model and add local setter helper.
2. [x] Add `changeSelectedColonyWorkerWorkImprovementType(_:)` in `GameState`.
3. [x] Add colony panel controls for work improvement type.
4. [x] Add CLI integration test to verify `changeWorkImprovementType` send path.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

For selected colony workers, the client can set `workImprovementType`, local mock mode reflects it, and protocol regression verifies payload correctness.
