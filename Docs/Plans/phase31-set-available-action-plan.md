# Phase 31: Set Available Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `setAvailable` action in state and UI.

## Scope

- [x] Add `setLocalPlayerAvailable()` action in `GameState` to send `setAvailable` with `player`.
- [x] Expose a UI affordance in `GameView` to trigger setAvailable for the local player.
- [x] Add CLI integration regression to verify outgoing `setAvailable` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`
