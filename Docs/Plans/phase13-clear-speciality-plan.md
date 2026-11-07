# Phase 13 Implementation Plan - Clear Speciality Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `clearSpeciality` action for selected colony workers.

## Scope

- Add guarded app-state action for `clearSpeciality unit=...`.
- Add colony panel UI affordance to trigger speciality reset for selected worker.
- Extend CLI regression coverage to verify `clearSpeciality` payload.

## Execution Steps

1. [x] Add `clearSelectedColonyWorkerSpeciality()` in `GameState` with legality checks.
2. [x] Add `Clear Speciality` button in colony panel wiring.
3. [x] Extend `FreeColProtocolCLI` colony action integration to verify `clearSpeciality` send.
4. [x] Validate with build + CLI suite.

## Validation

- swift build --target Novaloria
- swift run FreeColProtocolCLI

## Expected Result

From colony controls, the client can send `clearSpeciality` for the selected worker, and regression coverage verifies the protocol payload.
