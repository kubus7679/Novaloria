# Phase 19: Set Nation Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `setNation` pre-game action in lobby state and UI.

## Scope

- [x] Add `setLocalPlayerNation(_:)` action in `GameState` to send `setNation` with `player` and `value`.
- [x] Expose a lobby UI affordance in `LoginView` to trigger nation changes after login.
- [x] Add CLI integration regression to verify outgoing `setNation` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target Novaloria`
- [x] `swift run FreeColProtocolCLI`
