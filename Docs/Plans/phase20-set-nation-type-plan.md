# Phase 20: Set NationType Action MVP Plan

## Goal

Close another concrete gap from "missing action messages and UI affordances" by adding the `setNationType` pre-game action in lobby state and UI.

## Scope

- [x] Add `setLocalPlayerNationType(_:)` action in `GameState` to send `setNationType` with `player` and `value`.
- [x] Expose a lobby UI affordance in `LoginView` to trigger nation-type changes after login.
- [x] Add CLI integration regression to verify outgoing `setNationType` payload.
- [x] Validate with build and CLI suite.

## Validation Checklist

- [x] `swift build --target FreeColApp`
- [x] `swift run FreeColProtocolCLI`
