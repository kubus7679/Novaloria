# Phase 21: Set Color Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `setColor` pre-game action in lobby state and UI.

## Scope

- [x] Add `setLocalPlayerColor(_:)` action in `GameState` to send `setColor` with `player` and `value`.
- [x] Expose a lobby UI affordance in `LoginView` to trigger player color changes after login.
- [x] Add CLI integration regression to verify outgoing `setColor` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`
