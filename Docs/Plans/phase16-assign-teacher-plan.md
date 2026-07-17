# Phase 16 Implementation Plan - Assign Teacher Action MVP

## Objective

Close another concrete gap from "missing action messages and UI affordances" by adding the `assignTeacher` action for selected colony workers.

## Scope

- Add guarded app-state action for `assignTeacher student=... teacher=...`.
- Add local mock fallback mutation for deterministic local behavior.
- Add colony panel UI affordance to assign/clear teacher for selected worker.
- Extend CLI regression coverage to verify `assignTeacher` payload.

## Execution Steps

1. [x] Add local model helper to assign/clear teacher-student linkage in mock mode.
2. [x] Add `assignTeacherToSelectedColonyWorker(_:)` and clear method in `GameState`.
3. [x] Add colony panel controls for assign/clear teacher.
4. [x] Extend `FreeColProtocolCLI` colony action integration to verify `assignTeacher` send path.
5. [x] Validate with build + CLI suite.

## Validation

- swift build --target FreeColApp
- swift run FreeColProtocolCLI

## Expected Result

For selected colony workers, the app can assign and clear teacher linkage via `assignTeacher`, and regression coverage verifies payload correctness.
