# Phase 32: Set Stance Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `setStance` action in state and UI.

## Scope

- [x] Add `setStance(stance:targetPlayerId:)` action in `GameState` to send `setStance` with `stance`, `source`, and `target`.
- [x] Expose an in-game UI affordance in `GameView` to send stance changes for the local player.
- [x] Add CLI integration regression to verify outgoing `setStance` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`
