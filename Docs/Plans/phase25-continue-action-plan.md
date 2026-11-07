# Phase 25: Continue Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `continue` in-game action in state and UI.

## Scope

- [x] Add `sendContinue()` action in `GameState` to send `continue`.
- [x] Expose an in-game UI affordance in `GameView` to trigger continue.
- [x] Add CLI integration regression to verify outgoing `continue` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`
