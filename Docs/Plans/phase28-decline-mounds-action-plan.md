# Phase 28: Decline Mounds Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `declineMounds` in-game action in state and UI.

## Scope

- [x] Add `declineMoundsForSelectedUnit()` action in `GameState` to send `declineMounds` with selected unit id.
- [x] Expose an in-game UI affordance in `GameView` to trigger decline mounds for selected unit.
- [x] Add CLI integration regression to verify outgoing `declineMounds` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`
