# Phase 26: Retire Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `retire` in-game action in state and UI.

## Scope

- [x] Add `retireGame()` action in `GameState` to send `retire`.
- [x] Expose an in-game UI affordance in `GameView` to trigger retire.
- [x] Add CLI integration regression to verify outgoing `retire` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`
