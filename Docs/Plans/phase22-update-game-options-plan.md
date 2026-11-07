# Phase 22: Update GameOptions Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `updateGameOptions` pre-game action in lobby state and UI.

## Scope

- [x] Add `updateSingleGameOption(id:value:)` action in `GameState` to send `updateGameOptions` with one `<option/>` child.
- [x] Expose a lobby UI affordance in `LoginView` to submit one game option key/value pair.
- [x] Add CLI integration regression to verify outgoing `updateGameOptions` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`
